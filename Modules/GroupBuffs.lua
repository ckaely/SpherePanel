-- ============================================================
-- Module : GroupBuffs ("Buffs") — buffs de raid manquants dans le groupe
-- ============================================================
-- Une icône par buff de classe : vert = tout le monde l'a, rouge = N manquants
-- (survol = liste des absents). + Bien nourri (soi-même). Visible en groupe.
local ADDON_NAME, SP = ...

local M = {
    name = "GroupBuffs", label = "Buffs", defaultHeight = 40,
}

local ICON, GAP = 26, 4

-- buffs de raid : { spellID, classe source }
local BUFFS = {
    { id = 1459,   who = "Mage" },        -- Intelligence des arcanes
    { id = 21562,  who = "Prêtre" },      -- Mot de pouvoir : Robustesse
    { id = 6673,   who = "Guerrier" },    -- Cri de bataille
    { id = 1126,   who = "Druide" },      -- Marque du fauve
    { id = 462854, who = "Chaman" },      -- Furie-des-cieux
}

local function UnitsInGroup()
    local units = {}
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do units[#units + 1] = "raid" .. i end
    elseif IsInGroup() then
        units[#units + 1] = "player"
        for i = 1, GetNumGroupMembers() - 1 do units[#units + 1] = "party" .. i end
    else
        units[#units + 1] = "player"
    end
    return units
end

local function HasBuff(unit, spellName)
    if not spellName then return true end
    local ok, aura = pcall(AuraUtil.FindAuraByName, spellName, unit, "HELPFUL")
    return ok and aura ~= nil
end

function M:Init(body)
    self.body = body
    self.btns = {}
    for i, b in ipairs(BUFFS) do
        local f = CreateFrame("Frame", nil, body)
        f:SetSize(ICON, ICON)
        f:SetPoint("TOPLEFT", body, "TOPLEFT", 6 + (i - 1) * (ICON + GAP), -6)
        f.icon = f:CreateTexture(nil, "ARTWORK"); f.icon:SetAllPoints(f); f.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        f.border = f:CreateTexture(nil, "BACKGROUND")
        f.border:SetPoint("TOPLEFT", -2, 2); f.border:SetPoint("BOTTOMRIGHT", 2, -2)
        f.count = f:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
        f.count:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 1, 0)
        f:EnableMouse(true)
        f:SetScript("OnEnter", function(s)
            GameTooltip:SetOwner(s, "ANCHOR_TOP")
            GameTooltip:SetText(s.buffName or "?")
            GameTooltip:AddLine("Source : " .. b.who, 0.7, 0.7, 0.7)
            if s.missing and #s.missing > 0 then
                GameTooltip:AddLine("Manque :", 1, 0.4, 0.4)
                for _, n in ipairs(s.missing) do GameTooltip:AddLine("  " .. n, 1, 1, 1) end
            else
                GameTooltip:AddLine("Tout le monde l'a.", 0.4, 1, 0.4)
            end
            GameTooltip:Show()
        end)
        f:SetScript("OnLeave", function() GameTooltip:Hide() end)
        f.def = b
        self.btns[i] = f
    end
    -- Bien nourri (soi)
    local wf = CreateFrame("Frame", nil, body)
    wf:SetSize(ICON, ICON)
    wf:SetPoint("TOPLEFT", body, "TOPLEFT", 6 + #BUFFS * (ICON + GAP) + 8, -6)
    wf.icon = wf:CreateTexture(nil, "ARTWORK"); wf.icon:SetAllPoints(wf); wf.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    wf.icon:SetTexture("Interface\\Icons\\Spell_Misc_Food")
    wf.border = wf:CreateTexture(nil, "BACKGROUND")
    wf.border:SetPoint("TOPLEFT", -2, 2); wf.border:SetPoint("BOTTOMRIGHT", 2, -2)
    wf:EnableMouse(true)
    wf:SetScript("OnEnter", function(s)
        GameTooltip:SetOwner(s, "ANCHOR_TOP")
        GameTooltip:SetText("Bien nourri (vous)")
        GameTooltip:Show()
    end)
    wf:SetScript("OnLeave", function() GameTooltip:Hide() end)
    self.wellFed = wf

    self.ev = CreateFrame("Frame")
    self.ev:SetScript("OnEvent", function() self:RequestRefresh() end)
end

function M:Enable()
    self._enabled = true
    if self._placeholder then self._placeholder:Hide() end
    pcall(self.ev.RegisterEvent, self.ev, "GROUP_ROSTER_UPDATE")
    pcall(self.ev.RegisterEvent, self.ev, "PLAYER_ENTERING_WORLD")
    if not self._ticker then
        self._ticker = C_Timer.NewTicker(3, function() self:Refresh() end)  -- UNIT_AURA groupé serait trop bavard
    end
    self:Refresh()
end

function M:Disable()
    self._enabled = false
    if self.ev then self.ev:UnregisterAllEvents() end
    if self._ticker then self._ticker:Cancel(); self._ticker = nil end
end

function M:OnResize(w, h) end

function M:RequestRefresh()
    if not self._enabled or self._pending then return end
    self._pending = true
    C_Timer.After(0.5, function() self._pending = false; self:Refresh() end)
end

function M:Refresh()
    if not self._enabled then return end
    local units = UnitsInGroup()
    local missTotal = 0
    for _, f in ipairs(self.btns) do
        local sid = f.def.id
        local name = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(sid)
        local tex = C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(sid)
        f.buffName = name
        f.icon:SetTexture(tex or "Interface\\Icons\\INV_Misc_QuestionMark")
        f.missing = {}
        if name then
            for _, u in ipairs(units) do
                if UnitExists(u) and UnitIsConnected(u) and not UnitIsDeadOrGhost(u) and not HasBuff(u, name) then
                    f.missing[#f.missing + 1] = UnitName(u) or u
                end
            end
        end
        local n = #f.missing
        missTotal = missTotal + n
        if n == 0 then
            f.border:SetColorTexture(0.2, 0.8, 0.3, 1)
            f.icon:SetDesaturated(false)
            f.count:SetText("")
        else
            f.border:SetColorTexture(0.85, 0.25, 0.25, 1)
            f.icon:SetDesaturated(true)
            f.count:SetText("|cFFFF6666" .. n .. "|r")
        end
    end
    -- Bien nourri (soi)
    local fed = HasBuff("player", C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(19705) or "Bien nourri")
    self.wellFed.border:SetColorTexture(fed and 0.2 or 0.85, fed and 0.8 or 0.25, fed and 0.3 or 0.25, 1)
    self.wellFed.icon:SetDesaturated(not fed)

    SP:SetModuleHeaderText(self, missTotal > 0 and ("|cFFFF6666%d manquants|r"):format(missTotal) or "|cFF40FF40OK|r")
end

SP:RegisterModule(M)
