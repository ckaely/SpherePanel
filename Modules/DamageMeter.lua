-- ============================================================
-- Module : DamageMeter — compteur de dégâts (moteur interne, combat log)
-- ============================================================
-- Étape 8. Agrège les dégâts par source du groupe sur le combat actif.
local ADDON_NAME, SP = ...

local M = {
    name          = "DamageMeter",
    label         = "Dégâts",
    defaultHeight = 150,
}

local BAR_H, GAP = 16, 2
local STATUSBAR_TEX = "Interface\\TargetingFrame\\UI-StatusBar"
local REFRESH = 0.5

local bit_band = bit.band
local MINE_OR_GROUP = bit.bor(
    COMBATLOG_OBJECT_AFFILIATION_MINE or 0x1,
    COMBATLOG_OBJECT_AFFILIATION_PARTY or 0x2,
    COMBATLOG_OBJECT_AFFILIATION_RAID or 0x4
)

local DAMAGE_SUB = {
    SWING_DAMAGE          = 12,
    SPELL_DAMAGE          = 15,
    SPELL_PERIODIC_DAMAGE = 15,
    RANGE_DAMAGE          = 15,
    SPELL_BUILDING_DAMAGE = 15,
}

local function ShortNum(v)
    if v >= 1e6 then return ("%.1fM"):format(v / 1e6)
    elseif v >= 1e3 then return ("%.1fk"):format(v / 1e3)
    else return ("%d"):format(v) end
end

local function CreateBar(self)
    local bar = CreateFrame("StatusBar", nil, self.body)
    bar:SetStatusBarTexture(STATUSBAR_TEX)
    bar:SetMinMaxValues(0, 1)
    bar:Hide()
    local bg = bar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(bar); bg:SetColorTexture(0, 0, 0, 0.6)
    bar.left = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    bar.left:SetPoint("LEFT", bar, "LEFT", 4, 0)
    bar.right = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    bar.right:SetPoint("RIGHT", bar, "RIGHT", -4, 0)
    return bar
end

function M:Init(body)
    self.body = body
    self.bars = {}
    self.data = {}          -- name -> total damage
    self.combatStart = nil
    self.combatEnd = nil
    self._accum = 0

    self.ev = CreateFrame("Frame")
    self.ev:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_REGEN_DISABLED" then
            self.data = {}
            self.combatStart = GetTime()
            self.combatEnd = nil
        elseif event == "PLAYER_REGEN_ENABLED" then
            self.combatEnd = GetTime()
        elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
            self:OnCombatLog()
        end
    end)
end

function M:Enable()
    self._enabled = true
    self:Prewarm(12)
    self.ev:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    self.ev:RegisterEvent("PLAYER_REGEN_DISABLED")
    self.ev:RegisterEvent("PLAYER_REGEN_ENABLED")
    if self._placeholder then self._placeholder:Hide() end
    self.body:SetScript("OnUpdate", function(_, elapsed)
        self._accum = self._accum + elapsed
        if self._accum >= REFRESH then
            self._accum = 0
            self:Refresh()
        end
    end)
    self:Refresh()
end

function M:Disable()
    self._enabled = false
    if self.ev then self.ev:UnregisterAllEvents() end
    if self.body then self.body:SetScript("OnUpdate", nil) end
    for _, b in ipairs(self.bars) do b:Hide() end
end

function M:Prewarm(n)
    if InCombatLockdown() then return end
    for i = #self.bars + 1, n do self.bars[i] = CreateBar(self) end
end

function M:OnCombatLog()
    local _, sub, _, _, srcName, srcFlags = CombatLogGetCurrentEventInfo()
    local idx = DAMAGE_SUB[sub]
    if not idx or not srcName then return end
    if bit_band(srcFlags or 0, MINE_OR_GROUP) == 0 then return end
    -- récupère le montant à la bonne position selon le sous-event
    local amount = select(idx, CombatLogGetCurrentEventInfo())
    if type(amount) ~= "number" then return end
    self.data[srcName] = (self.data[srcName] or 0) + amount
end

function M:Refresh()
    if not self._enabled or not self.body then return end

    -- tri décroissant
    local list = {}
    for name, total in pairs(self.data) do list[#list + 1] = { name = name, total = total } end
    table.sort(list, function(a, b) return a.total > b.total end)

    local elapsed = 1
    if self.combatStart then
        elapsed = (self.combatEnd or GetTime()) - self.combatStart
        if elapsed < 1 then elapsed = 1 end
    end

    local maxTotal = list[1] and list[1].total or 1
    local fit = math.floor((self.body:GetHeight() - 2) / (BAR_H + GAP))
    if fit < 1 then fit = 1 end

    local shown = 0
    for i = 1, math.min(#list, fit) do
        local e = list[i]
        local bar = self.bars[i]
        if not bar then
            if InCombatLockdown() then break end
            bar = CreateBar(self); self.bars[i] = bar
        end
        shown = shown + 1
        bar:ClearAllPoints()
        bar:SetHeight(BAR_H)
        bar:SetPoint("TOPLEFT", self.body, "TOPLEFT", 2, -(2 + (i - 1) * (BAR_H + GAP)))
        bar:SetPoint("RIGHT", self.body, "RIGHT", -2, 0)
        bar:SetMinMaxValues(0, maxTotal)
        bar:SetValue(e.total)
        bar:SetStatusBarColor(0.8, 0.3, 0.25)
        bar.left:SetText(e.name)
        local dps = e.total / elapsed
        bar.right:SetText(("%s  (%s)"):format(ShortNum(e.total), ShortNum(dps)))
        bar:Show()
    end
    for i = shown + 1, #self.bars do self.bars[i]:Hide() end
end

function M:OnResize(w, h)
    self:Refresh()
end

SP:RegisterModule(M)
