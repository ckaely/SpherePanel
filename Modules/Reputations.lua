-- ============================================================
-- Module : Reputations ("Réputations") — barres de faction (réputation/renommée)
-- ============================================================
-- Liste scrollable des factions (hors en-têtes), barre colorée par palier.
local ADDON_NAME, SP = ...

local M = { name = "Reputations", label = "Réputations", defaultHeight = 150 }

local ROW = 15

local function CreateRow(self, i)
    local r = CreateFrame("Frame", nil, self.list)
    r:SetHeight(ROW)
    r.bar = CreateFrame("StatusBar", nil, r)
    r.bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    r.bar:SetPoint("TOPLEFT", r, "TOPLEFT", 0, -1)
    r.bar:SetPoint("BOTTOMRIGHT", r, "BOTTOMRIGHT", 0, 1)
    local bg = r.bar:CreateTexture(nil, "BACKGROUND"); bg:SetAllPoints(r.bar); bg:SetColorTexture(0, 0, 0, 0.55)
    r.fs = r.bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    r.fs:SetPoint("LEFT", r.bar, "LEFT", 4, 0); r.fs:SetPoint("RIGHT", r.bar, "RIGHT", -4, 0)
    r.fs:SetJustifyH("LEFT"); r.fs:SetWordWrap(false)
    self.rows[i] = r
    return r
end

function M:Init(body)
    self.body = body
    self.rows = {}
    self.list = CreateFrame("Frame", nil, body)
    self.list:SetPoint("TOPLEFT", body, "TOPLEFT", 2, -2)
    self.list:SetPoint("BOTTOMRIGHT", body, "BOTTOMRIGHT", -2, 2)
    self.list:SetClipsChildren(true)
    self.scroll = 0
    self.list:EnableMouseWheel(true)
    self.list:SetScript("OnMouseWheel", function(_, d)
        local vis = self.list:GetHeight() or 1
        local maxS = math.max(0, (self._contentH or 0) - vis)
        self.scroll = math.min(maxS, math.max(0, self.scroll - d * ROW * 2))
        self:Refresh()
    end)
    self.ev = CreateFrame("Frame")
    self.ev:SetScript("OnEvent", function() self:RequestRefresh() end)
end

function M:Enable()
    self._enabled = true
    if self._placeholder then self._placeholder:Hide() end
    pcall(self.ev.RegisterEvent, self.ev, "UPDATE_FACTION")
    pcall(self.ev.RegisterEvent, self.ev, "MAJOR_FACTION_RENOWN_LEVEL_CHANGED")
    self:RequestRefresh()
end

function M:Disable()
    self._enabled = false
    if self.ev then self.ev:UnregisterAllEvents() end
    for _, r in ipairs(self.rows) do r:Hide() end
end

function M:OnResize(w, h) self:RequestRefresh() end

function M:RequestRefresh()
    if not self._enabled or self._pending then return end
    self._pending = true
    C_Timer.After(0.3, function() self._pending = false; self:Refresh() end)
end

function M:Refresh()
    if not self._enabled or not (C_Reputation and C_Reputation.GetNumFactions) then return end
    local y, shown = 0, 0
    local n = C_Reputation.GetNumFactions() or 0
    for i = 1, n do
        local ok, f = pcall(C_Reputation.GetFactionDataByIndex, i)
        if ok and f and not f.isHeader and f.name then
            shown = shown + 1
            local r = self.rows[shown] or CreateRow(self, shown)
            local minV = f.currentReactionThreshold or 0
            local maxV = f.nextReactionThreshold or 1
            local cur = f.currentStanding or 0
            local label
            -- renommée (factions majeures) prioritaire
            local mf = C_MajorFactions and f.factionID and C_MajorFactions.GetMajorFactionData
                and select(2, pcall(C_MajorFactions.GetMajorFactionData, f.factionID))
            if mf and mf.renownLevel then
                minV, maxV = 0, mf.renownLevelThreshold or 1
                cur = mf.renownReputationEarned or 0
                label = ("%s |cFF82C5FFRenom %d|r"):format(f.name, mf.renownLevel)
                r.bar:SetStatusBarColor(0.31, 0.62, 1.0)
            else
                local rc = FACTION_BAR_COLORS and FACTION_BAR_COLORS[f.reaction or 4] or { r = 0.6, g = 0.6, b = 0.2 }
                r.bar:SetStatusBarColor(rc.r, rc.g, rc.b)
                label = f.name
            end
            if maxV <= minV then maxV = minV + 1 end
            r.bar:SetMinMaxValues(minV, maxV)
            r.bar:SetValue(cur)
            r.fs:SetText(("%s  |cFFAAAAAA%d / %d|r"):format(label, cur - minV, maxV - minV))
            r:ClearAllPoints()
            r:SetPoint("TOPLEFT", self.list, "TOPLEFT", 0, -(y - self.scroll))
            r:SetPoint("TOPRIGHT", self.list, "TOPRIGHT", 0, -(y - self.scroll))
            r:Show()
            y = y + ROW + 1
        end
    end
    for i = shown + 1, #self.rows do self.rows[i]:Hide() end
    self._contentH = y
end

SP:RegisterModule(M)
