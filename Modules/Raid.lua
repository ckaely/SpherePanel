-- ============================================================
-- Module : Raid — barres de vie du groupe/raid
-- ============================================================
-- Étape 7. Barre par membre. HP piloté par C-API (jamais d'arithmétique Lua — AP-01).
local ADDON_NAME, SP = ...

local M = {
    name          = "Raid",
    label         = "Groupe",
    defaultHeight = 180,
}

local BAR_H, GAP = 18, 2
local STATUSBAR_TEX = "Interface\\TargetingFrame\\UI-StatusBar"

local ROSTER_EVENTS = {
    "GROUP_ROSTER_UPDATE", "PLAYER_ENTERING_WORLD",
    "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_CONNECTION", "PLAYER_REGEN_ENABLED",
}

-- Création d'une barre (hors combat).
local function CreateBar(self)
    local bar = CreateFrame("StatusBar", nil, self.body)
    bar:SetStatusBarTexture(STATUSBAR_TEX)
    bar:SetMinMaxValues(0, 1)
    bar:Hide()
    local bg = bar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(bar)
    bg:SetColorTexture(0, 0, 0, 0.6)
    bar.name = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    bar.name:SetPoint("LEFT", bar, "LEFT", 4, 0)
    bar.name:SetPoint("RIGHT", bar, "RIGHT", -4, 0)
    bar.name:SetJustifyH("LEFT")
    return bar
end

local function UpdateBar(bar)
    local u = bar.unit
    if not u or not UnitExists(u) then bar:Hide(); return end
    bar:Show()
    local name = UnitName(u) or u
    local _, class = UnitClass(u)
    local c = (class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]) or { r = 0.7, g = 0.7, b = 0.7 }
    -- HP via C-API (accepte les valeurs secret/tainted, contrairement à l'arithmétique Lua)
    pcall(function()
        bar:SetStatusBarColor(c.r, c.g, c.b)
        bar:SetMinMaxValues(0, UnitHealthMax(u))
        bar:SetValue(UnitHealth(u))
    end)
    if UnitIsDeadOrGhost(u) then
        bar.name:SetText("|cFFBBBBBB" .. name .. " (mort)|r")
        bar:SetStatusBarColor(0.3, 0.3, 0.3)
    elseif not UnitIsConnected(u) then
        bar.name:SetText("|cFF888888" .. name .. " (hors ligne)|r")
    else
        bar.name:SetText(name)
    end
end

function M:Init(body)
    self.body = body
    self.bars = {}          -- pool
    self.unitToBar = {}     -- unit -> bar (refresh ciblé sur UNIT_HEALTH)
    self.ev = CreateFrame("Frame")
    self.ev:SetScript("OnEvent", function(_, event, unit)
        if event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" then
            local bar = unit and self.unitToBar[unit]
            if bar then UpdateBar(bar) end
        else
            self:Rebuild()
        end
    end)
end

function M:Enable()
    self._enabled = true
    self:Prewarm(40)
    for _, e in ipairs(ROSTER_EVENTS) do pcall(self.ev.RegisterEvent, self.ev, e) end
    if self._placeholder then self._placeholder:Hide() end
    self:Rebuild()
end

function M:Disable()
    self._enabled = false
    if self.ev then self.ev:UnregisterAllEvents() end
    for _, b in ipairs(self.bars) do b:Hide() end
end

function M:Prewarm(n)
    if InCombatLockdown() then return end
    for i = #self.bars + 1, n do self.bars[i] = CreateBar(self) end
end

-- Liste des unités du groupe (joueur inclus).
local function BuildUnitList()
    local units = {}
    local n = GetNumGroupMembers() or 0
    if IsInRaid() then
        for i = 1, n do units[#units + 1] = "raid" .. i end
    else
        units[#units + 1] = "player"
        for i = 1, n - 1 do units[#units + 1] = "party" .. i end
        if n == 0 then units = { "player" } end
    end
    return units
end

function M:Rebuild()
    if not self._enabled or not self.body then return end
    wipe(self.unitToBar)
    local units = BuildUnitList()
    local twoCol = IsInRaid() and #units > 5
    local colW = twoCol and (self.body:GetWidth() / 2 - 2) or self.body:GetWidth()

    local used = 0
    for idx, u in ipairs(units) do
        used = used + 1
        local bar = self.bars[used]
        if not bar then
            if InCombatLockdown() then break end
            bar = CreateBar(self)
            self.bars[used] = bar
        end
        bar.unit = u
        self.unitToBar[u] = bar
        bar:ClearAllPoints()
        bar:SetHeight(BAR_H)
        if twoCol then
            local col = (idx - 1) % 2
            local rowN = math.floor((idx - 1) / 2)
            bar:SetWidth(colW)
            bar:SetPoint("TOPLEFT", self.body, "TOPLEFT", col * (colW + 4) + 2, -(2 + rowN * (BAR_H + GAP)))
        else
            bar:SetPoint("TOPLEFT", self.body, "TOPLEFT", 2, -(2 + (idx - 1) * (BAR_H + GAP)))
            bar:SetPoint("RIGHT", self.body, "RIGHT", -2, 0)
        end
        UpdateBar(bar)
    end
    -- masquer les barres en trop
    for i = used + 1, #self.bars do self.bars[i]:Hide() end

    -- ajuste la hauteur du module
    local rows = twoCol and math.ceil(#units / 2) or #units
    local needed = math.max(BAR_H, 4 + rows * (BAR_H + GAP))
    local cfg = SP:GetModuleConfig(self.name)
    if cfg and cfg.height ~= needed then
        cfg.height = needed
        SP:RebuildLayout()
    end
end

function M:OnResize(w, h)
    self:Rebuild()
end

SP:RegisterModule(M)
