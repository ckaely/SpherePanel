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
        for _, d in ipairs({ { "top", "Top" }, { "perf", "Perf" } }) do
            local b = CreateFrame("Button", nil, self.header); b:SetSize(40, 16)
            if prev then b:SetPoint("RIGHT", prev, "LEFT", -3, 0) else b:SetPoint("RIGHT", anchor, "LEFT", -6, 0) end
            b.fs = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); b.fs:SetAllPoints(b); b.fs:SetText(d[2])
            b.hl = b:CreateTexture(nil, "BACKGROUND"); b.hl:SetAllPoints(b); b.hl:SetColorTexture(0.30, 0.55, 0.95, 0.30); b.hl:Hide()
            b.tab = d[1]; b:SetScript("OnClick", function(s) self:SetTab(s.tab) end)
            self.tabBtns[d[1]] = b; prev = b
        end
        self.header:EnableMouseWheel(true)
        self.header:SetScript("OnMouseWheel", function() self:SetTab(self.tab == "perf" and "top" or "perf") end)
    end

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
end

function M:_MakeGraph(title, color)
    local g = CreateFrame("Frame", nil, self.perf)
    g:SetHeight(GRAPH_H)
    g.bg = g:CreateTexture(nil, "BACKGROUND"); g.bg:SetAllPoints(g); g.bg:SetColorTexture(0, 0, 0, 0.35)
    g.title = g:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    g.title:SetPoint("TOPLEFT", g, "TOPLEFT", 4, -2); g.title:SetText("|cFFAAAAAA" .. title .. "|r")
    g.val = g:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    g.val:SetPoint("TOPRIGHT", g, "TOPRIGHT", -4, -2)
    g.lines = {}; g.color = color
    return g
end

function M:_DrawGraph(g, data, fmt)
    local n = #data
    if n < 2 then
        for _, l in ipairs(g.lines) do l:Hide() end
        g.val:SetText(n == 1 and fmt(data[1]) or "—")
        return
    end
    local mn, mx = math.huge, -math.huge
    for _, v in ipairs(data) do if v < mn then mn = v end; if v > mx then mx = v end end
    if mn == math.huge then mn, mx = 0, 1 end
    if mx <= mn then mx = mn + 1 end
    local w = g:GetWidth(); if not w or w < 10 then w = (SP.db.panel.width or 280) - 8 end
    local h = (g:GetHeight() or GRAPH_H)
    local pad = 3
    local plotW, plotH = w - 2 * pad, h - 2 * pad - 10  -- -10 : place pour le titre
    local function px(i) return pad + (i - 1) / (n - 1) * plotW end
    local function py(v) return pad + (v - mn) / (mx - mn) * plotH end
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
    g.val:SetText(fmt(data[n]))
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
    if self.tab == "top" then self:RefreshTop() else self:RefreshPerf() end
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
    local s = a.GetSeries(SAMPLES) or { fps = {}, mem = {}, cpu = {} }

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
    place(self.gLat); self:_DrawGraph(self.gLat, self.latBuf, function(v) return ("%d ms"):format(v) end)

    local fps = a.GetFPS()
    local tot = a.GetTotals()
    SP:SetModuleHeaderText(self, ("%d ips · %.0f Mo"):format(fps or 0, (tot and tot.mem or 0)))
    self.perf:SetHeight(y)
    SP:SetAutoHeight(self, y + 2)
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
