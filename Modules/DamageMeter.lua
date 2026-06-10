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

-- Embarque la fenêtre Details (instance 1) dans le module si Details est chargé.
function M:EmbedDetails()
    local D = _G.Details
    if not (C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("Details")) then return false end
    if not (D and D.GetInstance) then return false end
    local inst = D:GetInstance(1)
    local frame = inst and (inst.baseframe or (inst.GetBaseFrame and inst:GetBaseFrame()))
    if not frame then return false end
    if not self._detSaved then
        local pts = {}
        for i = 1, frame:GetNumPoints() do pts[i] = { frame:GetPoint(i) } end
        self._detSaved = { parent = frame:GetParent(), points = pts, w = frame:GetWidth(), h = frame:GetHeight(), scale = frame:GetScale() }
    end
    pcall(function()
        if inst.UnlockInstance then inst:UnlockInstance() end
        frame:SetParent(self.body)
        frame:SetScale(1)
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", self.body, "TOPLEFT", 0, 0)
        frame:SetPoint("BOTTOMRIGHT", self.body, "BOTTOMRIGHT", 0, 0)
        frame:Show()
    end)
    self._detEmbedded = true
    return true
end

function M:RestoreDetails()
    local D = _G.Details
    local inst = D and D.GetInstance and D:GetInstance(1)
    local frame = inst and (inst.baseframe or (inst.GetBaseFrame and inst:GetBaseFrame()))
    if frame and self._detSaved then
        pcall(function()
            frame:SetParent(self._detSaved.parent or UIParent)
            frame:ClearAllPoints()
            if self._detSaved.points and #self._detSaved.points > 0 then
                for _, p in ipairs(self._detSaved.points) do frame:SetPoint(unpack(p)) end
            end
            if self._detSaved.w then frame:SetSize(self._detSaved.w, self._detSaved.h) end
            frame:SetScale(self._detSaved.scale or 1)
        end)
    end
    self._detEmbedded = false
end

function M:_UseDetails()
    if self.body then self.body:SetScript("OnUpdate", nil) end
    for _, b in ipairs(self.bars) do b:Hide() end
    if self.info then self.info:Hide() end
    SP:SetModuleHeaderText(self, "|cFF888888Details|r")
end

function M:Enable()
    self._enabled = true
    if self._placeholder then self._placeholder:Hide() end
    if not self.info then
        self.info = self.body:CreateFontString(nil, "OVERLAY", "GameFontDisable")
        self.info:SetPoint("TOP", self.body, "TOP", 0, -8)
        self.info:Hide()
    end

    -- Si Details est présent : on force sa fenêtre dans le module, et on n'utilise pas le moteur interne.
    if not InCombatLockdown() and self:EmbedDetails() then
        self:_UseDetails()
        return
    end
    -- Details crée ses fenêtres après le login → re-tente en différé.
    C_Timer.After(2, function()
        if self._enabled and not self._detEmbedded and not InCombatLockdown() and self:EmbedDetails() then
            self:_UseDetails()
        end
    end)

    -- Moteur interne (fallback). ⚠ Midnight 12.x : COMBAT_LOG_EVENT_UNFILTERED est PROTÉGÉ
    -- pour les addons → RegisterEvent lève ADDON_ACTION_FORBIDDEN. On tente sous pcall ;
    -- si refusé, le module requiert Details.
    local okCLEU = pcall(self.ev.RegisterEvent, self.ev, "COMBAT_LOG_EVENT_UNFILTERED")
    if not okCLEU then
        self.info:SetText("|cFFFF7777Requiert : Details!|r\n|cFF888888(combat log restreint en Midnight — moteur interne indisponible)|r")
        self.info:Show()
        SP:SetModuleHeaderText(self, "|cFFFF7777Details requis|r")
        return
    end
    self:Prewarm(12)
    pcall(self.ev.RegisterEvent, self.ev, "PLAYER_REGEN_DISABLED")
    pcall(self.ev.RegisterEvent, self.ev, "PLAYER_REGEN_ENABLED")
    self.body:SetScript("OnUpdate", function(_, elapsed)
        self._accum = self._accum + elapsed
        if self._accum >= REFRESH then self._accum = 0; self:Refresh() end
    end)
    self:Refresh()
end

function M:Disable()
    self._enabled = false
    if self.ev then self.ev:UnregisterAllEvents() end
    if self.body then self.body:SetScript("OnUpdate", nil) end
    for _, b in ipairs(self.bars) do b:Hide() end
    if self._detEmbedded then self:RestoreDetails() end
    SP:SetModuleHeaderText(self, "")
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
