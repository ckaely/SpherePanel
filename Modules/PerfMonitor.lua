-- ============================================================
-- Module : PerfMonitor ("Perf") — moniteur de ressources via AddonScope
-- ============================================================
-- Onglet PERF : graphes temps réel (FPS, Mémoire, CPU, Latence) lus depuis AddonScope.
-- Onglet TOP  : addons les plus gourmands (CPU/Mémoire), liste scrollable.
-- MOLETTE sur le bandeau = bascule d'onglet. Requiert : AddonScope.
-- (GPU non lisible côté WoW — limite de l'API, comme documenté dans AddonScope.)
local ADDON_NAME, SP = ...

local M = { name = "PerfMonitor", label = "Perf", defaultHeight = 220 }

local GRAPH_H = 44
local GAPV = 4
local SAMPLES = 120   -- points affichés par graphe

local function AS() return _G.AddonScope end
local function hasAS() local a = AS(); return a and a.GetSeries and true or false end

-- ============================================================
function M:Init(body)
    self.body = body
    self.tab = "perf"
    self.latBuf = {}   -- historique latence (propre au module)

    -- onglets sur le bandeau
    if self.header then
        if self.suffixFS then self.suffixFS:Hide() end
        self.tabBtns = {}
        local anchor, prev = self.lock or self.header, nil
        for _, d in ipairs({ { "alertes", "Alertes" }, { "top", "Top" }, { "perf", "Perf" } }) do
            local b = CreateFrame("Button", nil, self.header); b:SetSize(44, 16)
            if prev then b:SetPoint("RIGHT", prev, "LEFT", -3, 0) else b:SetPoint("RIGHT", anchor, "LEFT", -6, 0) end
            b.fs = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); b.fs:SetAllPoints(b); b.fs:SetText(d[2])
            b.hl = b:CreateTexture(nil, "BACKGROUND"); b.hl:SetAllPoints(b); b.hl:SetColorTexture(0.30, 0.55, 0.95, 0.30); b.hl:Hide()
            b.tab = d[1]; b:SetScript("OnClick", function(s) self:SetTab(s.tab) end)
            self.tabBtns[d[1]] = b; prev = b
        end
        self.header:EnableMouseWheel(true)
        local CYCLE = { "perf", "top", "alertes" }
        self.header:SetScript("OnMouseWheel", function(_, delta)
            local idx = 1; for k, t in ipairs(CYCLE) do if t == self.tab then idx = k break end end
            idx = ((idx - 1 - delta) % #CYCLE) + 1
            self:SetTab(CYCLE[idx])
        end)
    end
    self.window = SAMPLES

    -- conteneur PERF (graphes empilés)
    self.perf = CreateFrame("Frame", nil, body)
    self.perf:SetPoint("TOPLEFT", body, "TOPLEFT", 2, -2)
    self.perf:SetPoint("TOPRIGHT", body, "TOPRIGHT", -2, 0)
    self.perf:SetHeight(1)
    self.gFps = self:_MakeGraph("FPS", { 0.4, 0.9, 0.4 })
    self.gMem = self:_MakeGraph("Mémoire", { 0.4, 0.7, 1.0 })
    self.gCpu = self:_MakeGraph("CPU addons", { 1.0, 0.7, 0.3 })
    self.gLat = self:_MakeGraph("Latence", { 0.9, 0.4, 0.9 })
    self.info = self.perf:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    self.info:SetPoint("TOPLEFT", self.perf, "TOPLEFT", 4, -4)

    -- conteneur TOP (liste scrollable)
    self.top = CreateFrame("Frame", nil, body)
    self.top:SetPoint("TOPLEFT", body, "TOPLEFT", 2, -2)
    self.top:SetPoint("BOTTOMRIGHT", body, "BOTTOMRIGHT", -2, 2)
    self.top:SetClipsChildren(true); self.top:Hide()
    self.topRows = {}; self.topScroll = 0
    self.top:EnableMouseWheel(true)
    self.top:SetScript("OnMouseWheel", function(_, d)
        local vis = self.top:GetHeight() or 1
        local maxS = math.max(0, (self._topH or 0) - vis)
        self.topScroll = math.min(maxS, math.max(0, self.topScroll - d * 28))
        self:RefreshTop()
    end)

    -- molette sur les graphes = fenêtre temporelle (zoom)
    self.perf:EnableMouseWheel(true)
    self.perf:SetScript("OnMouseWheel", function(_, d)
        self.window = math.max(20, math.min(SAMPLES, (self.window or SAMPLES) - d * 15))
        self:RefreshPerf()
    end)

    -- conteneur ALERTES (alertes + logs récents d'AddonScope)
    self.alertes = CreateFrame("Frame", nil, body)
    self.alertes:SetPoint("TOPLEFT", body, "TOPLEFT", 2, -2)
    self.alertes:SetPoint("BOTTOMRIGHT", body, "BOTTOMRIGHT", -2, 2)
    self.alertes:SetClipsChildren(true); self.alertes:Hide()
    self.alRows = {}; self.alScroll = 0
    self.alertes:EnableMouseWheel(true)
    self.alertes:SetScript("OnMouseWheel", function(_, d)
        local vis = self.alertes:GetHeight() or 1
        local maxS = math.max(0, (self._alH or 0) - vis)
        self.alScroll = math.min(maxS, math.max(0, self.alScroll - d * 28))
        self:RefreshAlertes()
    end)
end

function M:_MakeGraph(title, color)
    local g = CreateFrame("Frame", nil, self.perf)
    g:SetHeight(GRAPH_H)
    g.bg = g:CreateTexture(nil, "BACKGROUND"); g.bg:SetAllPoints(g); g.bg:SetColorTexture(0, 0, 0, 0.35)
    -- grille horizontale (3 lignes)
    g.grid = {}
    for k = 1, 3 do
        local t = g:CreateTexture(nil, "ARTWORK"); t:SetHeight(1)
        t:SetColorTexture(1, 1, 1, 0.07); g.grid[k] = t
    end
    g.title = g:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    g.title:SetPoint("TOPLEFT", g, "TOPLEFT", 4, -2); g.title:SetText("|cFFAAAAAA" .. title .. "|r")
    g.val = g:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    g.val:SetPoint("TOPRIGHT", g, "TOPRIGHT", -4, -2)
    -- labels min/max/moy
    g.maxLbl = g:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    g.maxLbl:SetPoint("BOTTOMLEFT", g, "TOPLEFT", 4, -14)
    g.minLbl = g:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    g.minLbl:SetPoint("BOTTOMLEFT", g, "BOTTOMLEFT", 4, 1)
    -- curseur de survol + valeur au point
    g.cursor = g:CreateTexture(nil, "OVERLAY"); g.cursor:SetWidth(1); g.cursor:SetColorTexture(1, 1, 1, 0.45); g.cursor:Hide()
    g.color = color; g.lines = {}
    g:EnableMouse(true)
    g:SetScript("OnEnter", function(s) s._hover = true end)
    g:SetScript("OnLeave", function(s) s._hover = false; s.cursor:Hide(); GameTooltip:Hide() end)
    g:SetScript("OnUpdate", function(s)
        if not s._hover or not s._data or #s._data < 2 then return end
        local scale = s:GetEffectiveScale()
        local cx = (GetCursorPosition()) / scale
        local left, w = s:GetLeft(), s:GetWidth()
        if not left or not w or w < 1 then return end
        local rel = math.max(0, math.min(w, cx - left))
        local idx = math.floor(rel / w * (#s._data - 1) + 0.5) + 1
        idx = math.max(1, math.min(#s._data, idx))
        s.cursor:ClearAllPoints()
        s.cursor:SetPoint("TOP", s, "TOPLEFT", rel, 0)
        s.cursor:SetPoint("BOTTOM", s, "BOTTOMLEFT", rel, 0)
        s.cursor:Show()
        SP:AnchorTooltipOutsidePanel(GameTooltip, s)
        GameTooltip:SetText(s._fmt and s._fmt(s._data[idx] or 0) or tostring(s._data[idx]))
        GameTooltip:Show()
    end)
    return g
end

function M:_DrawGraph(g, data, fmt)
    g._data, g._fmt = data, fmt
    local n = #data
    if n < 2 then
        for _, l in ipairs(g.lines) do l:Hide() end
        for _, t in ipairs(g.grid) do t:Hide() end
        g.minLbl:SetText(""); g.maxLbl:SetText("")
        g.val:SetText(n == 1 and fmt(data[1]) or "—")
        return
    end
    local mn, mx, sum = math.huge, -math.huge, 0
    for _, v in ipairs(data) do if v < mn then mn = v end; if v > mx then mx = v end; sum = sum + v end
    if mn == math.huge then mn, mx = 0, 1 end
    if mx <= mn then mx = mn + 1 end
    local w = g:GetWidth(); if not w or w < 10 then w = (SP.db.panel.width or 280) - 8 end
    local h = (g:GetHeight() or GRAPH_H)
    local pad = 3
    local plotW, plotH = w - 2 * pad, h - 2 * pad - 10
    local function px(i) return pad + (i - 1) / (n - 1) * plotW end
    local function py(v) return pad + (v - mn) / (mx - mn) * plotH end
    -- grille
    for k, t in ipairs(g.grid) do
        local yy = pad + (k / 4) * plotH
        t:ClearAllPoints()
        t:SetPoint("BOTTOMLEFT", g, "BOTTOMLEFT", pad, yy)
        t:SetPoint("BOTTOMRIGHT", g, "BOTTOMRIGHT", -pad, yy)
        t:Show()
    end
    -- polyligne
    local li = 0
    for i = 2, n do
        li = li + 1
        local line = g.lines[li]
        if not line then line = g:CreateLine(nil, "ARTWORK"); line:SetThickness(1.5); g.lines[li] = line end
        line:SetColorTexture(g.color[1], g.color[2], g.color[3], 0.9)
        line:SetStartPoint("BOTTOMLEFT", px(i - 1), py(data[i - 1]))
        line:SetEndPoint("BOTTOMLEFT", px(i), py(data[i]))
        line:Show()
    end
    for j = li + 1, #g.lines do g.lines[j]:Hide() end
    g.maxLbl:SetText(("|cFF777777%s|r"):format(fmt(mx)))
    g.minLbl:SetText(("|cFF777777%s|r"):format(fmt(mn)))
    g.val:SetText(("%s |cFF888888moy %s|r"):format(fmt(data[n]), fmt(sum / n)))
end

function M:_TopRow(i)
    local r = self.topRows[i]
    if not r then
        r = CreateFrame("Frame", nil, self.top); r:SetHeight(15)
        r.stripe = r:CreateTexture(nil, "BACKGROUND"); r.stripe:SetAllPoints(r)
        r.name = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        r.name:SetPoint("LEFT", r, "LEFT", 4, 0); r.name:SetWidth(120); r.name:SetJustifyH("LEFT"); r.name:SetWordWrap(false)
        r.cpu = r:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        r.cpu:SetPoint("RIGHT", r, "RIGHT", -4, 0); r.cpu:SetWidth(60); r.cpu:SetJustifyH("RIGHT")
        r.mem = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        r.mem:SetPoint("RIGHT", r.cpu, "LEFT", -6, 0); r.mem:SetWidth(64); r.mem:SetJustifyH("RIGHT")
        self.topRows[i] = r
    end
    return r
end

-- ============================================================
function M:SetTab(tab)
    self.tab = tab
    if self.tabBtns then for k, b in pairs(self.tabBtns) do b.hl:SetShown(k == tab) end end
    self.perf:SetShown(tab == "perf")
    self.top:SetShown(tab == "top")
    if self.alertes then self.alertes:SetShown(tab == "alertes") end
    self:Refresh()
end

function M:Enable()
    self._enabled = true
    if self._placeholder then self._placeholder:Hide() end
    if not self._ticker then
        self._ticker = C_Timer.NewTicker(1, function() if self._enabled then self:Refresh() end end)
    end
    self:SetTab(self.tab or "perf")
end

function M:Disable()
    self._enabled = false
    if self._ticker then self._ticker:Cancel(); self._ticker = nil end
    SP:SetModuleHeaderText(self, "")
end

function M:OnResize(w, h) self:Refresh() end

function M:Refresh()
    if not self._enabled then return end
    if self.tab == "top" then self:RefreshTop()
    elseif self.tab == "alertes" then self:RefreshAlertes()
    else self:RefreshPerf() end
end

function M:RefreshPerf()
    if not hasAS() then
        self.info:Show(); self.info:SetText("|cFFFF7777Requiert : AddonScope|r |cFF888888(addon non chargé)|r")
        for _, g in ipairs({ self.gFps, self.gMem, self.gCpu, self.gLat }) do g:Hide() end
        SP:SetModuleHeaderText(self, "|cFFFF7777AddonScope|r")
        SP:SetAutoHeight(self, 30)
        return
    end
    self.info:Hide()
    local a = AS()
    local s = a.GetSeries(self.window or SAMPLES) or { fps = {}, mem = {}, cpu = {} }

    -- latence : historique propre (GetNetStats)
    local _, _, lh, lw = GetNetStats()
    local lat = math.max(lh or 0, lw or 0)
    self.latBuf[#self.latBuf + 1] = lat
    while #self.latBuf > SAMPLES do table.remove(self.latBuf, 1) end

    local y = 4
    local function place(g)
        g:ClearAllPoints()
        g:SetPoint("TOPLEFT", self.perf, "TOPLEFT", 2, -y)
        g:SetPoint("TOPRIGHT", self.perf, "TOPRIGHT", -2, -y)
        g:Show()
        y = y + GRAPH_H + GAPV
    end
    place(self.gFps); self:_DrawGraph(self.gFps, s.fps, function(v) return ("%d ips"):format(v) end)
    place(self.gMem); self:_DrawGraph(self.gMem, s.mem, function(v) return ("%.0f Mo"):format(v) end)
    place(self.gCpu); self:_DrawGraph(self.gCpu, s.cpu, function(v) return ("%.1f ms"):format(v) end)
    -- latence : fenêtre identique aux séries
    local win = self.window or SAMPLES
    local lw, from = {}, math.max(1, #self.latBuf - win + 1)
    for i = from, #self.latBuf do lw[#lw + 1] = self.latBuf[i] end
    place(self.gLat); self:_DrawGraph(self.gLat, lw, function(v) return ("%d ms"):format(v) end)

    local fps = a.GetFPS()
    local tot = a.GetTotals()
    SP:SetModuleHeaderText(self, ("%d ips · %.0f Mo · %ds"):format(fps or 0, (tot and tot.mem or 0), win))
    self.perf:SetHeight(y)
    SP:SetAutoHeight(self, y + 2)
end

-- ===== Onglet ALERTES (alertes + logs récents d'AddonScope) =====
local SEV_COLOR = { red = "FFFF4040", orange = "FFFFC020", yellow = "FFFFFF40", green = "FF40FF40" }
local LVL_COLOR = { ERROR = "FFFF4040", WARN = "FFFFC020", PERF = "FF40D0C0", INFO = "FF999999" }

function M:_AlRow(i)
    local r = self.alRows[i]
    if not r then
        r = self.alertes:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        r:SetJustifyH("LEFT"); r:SetWordWrap(false)
        self.alRows[i] = r
    end
    return r
end

function M:RefreshAlertes()
    if not hasAS() then
        local r = self:_AlRow(1); r:ClearAllPoints(); r:SetPoint("TOPLEFT", self.alertes, "TOPLEFT", 4, -2)
        r:SetText("|cFFFF7777Requiert : AddonScope|r"); r:Show()
        for j = 2, #self.alRows do self.alRows[j]:Hide() end
        return
    end
    local a = AS()
    local y, i = 0, 0
    local function line(txt)
        i = i + 1
        local r = self:_AlRow(i)
        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", self.alertes, "TOPLEFT", 4, -(y - self.alScroll))
        r:SetPoint("RIGHT", self.alertes, "RIGHT", -4, 0)
        r:SetText(txt or ""); r:Show()
        y = y + 14
    end

    line("|cFF8FC4FF— Alertes —|r")
    local alerts = a.GetAlerts and a.GetAlerts(20) or {}
    if #alerts == 0 then line("|cFF666666aucune alerte récente|r") end
    for _, al in ipairs(alerts) do
        line(("|cFF888888%s|r |c%s%s|r"):format(al.clock or "", SEV_COLOR[al.severity] or "FFFFFFFF", al.msg or ""))
    end
    line(" ")
    line("|cFF8FC4FF— Journal —|r")
    local logs = a.GetLogs and a.GetLogs(40) or {}
    for _, lg in ipairs(logs) do
        line(("|c%s[%s]|r |cFFBBBBBB%s|r %s"):format(LVL_COLOR[lg.level] or "FF999999", lg.level or "?", lg.addon or "", lg.msg or ""))
    end
    for j = i + 1, #self.alRows do self.alRows[j]:Hide() end
    self._alH = y
    SP:SetModuleHeaderText(self, ("%d alertes"):format(#alerts))
end

function M:RefreshTop()
    if not hasAS() then
        SP:SetModuleHeaderText(self, "|cFFFF7777AddonScope|r")
        return
    end
    local a = AS()
    local list = a.GetTop("cpu", 40) or {}
    local y, i = 0, 0
    -- en-tête
    i = i + 1
    local hd = self:_TopRow(i)
    hd:ClearAllPoints(); hd:SetPoint("TOPLEFT", self.top, "TOPLEFT", 0, -(y - self.topScroll)); hd:SetPoint("TOPRIGHT", self.top, "TOPRIGHT", 0, -(y - self.topScroll))
    hd.stripe:SetColorTexture(0.29, 0.64, 1, 0.12)
    hd.name:SetText("|cFF8FC4FFAddon|r"); hd.mem:SetText("|cFF8FC4FFMém|r"); hd.cpu:SetText("|cFF8FC4FFCPU|r")
    hd:Show(); y = y + 15

    for _, r in ipairs(list) do
        i = i + 1
        local row = self:_TopRow(i)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", self.top, "TOPLEFT", 0, -(y - self.topScroll))
        row:SetPoint("TOPRIGHT", self.top, "TOPRIGHT", 0, -(y - self.topScroll))
        row.stripe:SetColorTexture(0, 0, 0, (i % 2 == 0) and 0.18 or 0)
        row.name:SetText(r.name or "?")
        row.mem:SetText(("|cFFFFFFFF%.1f Mo|r"):format((r.mem or 0) / 1024))
        local cpu = r.cpuRecent or 0
        local col = cpu > 5 and "FFFF5555" or cpu > 1 and "FFFFC020" or "FF40FF40"
        row.cpu:SetText(("|c%s%.1f ms|r"):format(col, cpu))
        row:Show()
        y = y + 15
    end
    for j = i + 1, #self.topRows do self.topRows[j]:Hide() end
    self._topH = y
    local fps = a.GetFPS()
    SP:SetModuleHeaderText(self, ("%d ips"):format(fps or 0))
end

SP:RegisterModule(M)
