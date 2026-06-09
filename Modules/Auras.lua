-- ============================================================
-- Module : Auras — buffs / débuffs du joueur, onglets Tout / Buff / Débuff
-- ============================================================
local ADDON_NAME, SP = ...

local M = {
    name          = "Auras",
    label         = "Auras",
    defaultHeight = 90,
}

local TAB_H, GAP = 16, 3

local TABS = { { "all", "Tout" }, { "buff", "Buff" }, { "debuff", "Débuff" } }

-- Récupère les auras d'un filtre dans `out` (packed aura tables).
local function Gather(filter, out)
    if AuraUtil and AuraUtil.ForEachAura then
        local ok = pcall(AuraUtil.ForEachAura, "player", filter, nil, function(aura)
            if aura and aura.icon then out[#out + 1] = aura end
        end, true)
        if ok then return end
    end
    if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
        for i = 1, 40 do
            local a = C_UnitAuras.GetAuraDataByIndex("player", i, filter)
            if not a then break end
            if a.icon then out[#out + 1] = a end
        end
    end
end

local function CreateIcon(self)
    local f = CreateFrame("Frame", nil, self.grid)
    f:Hide()
    f.tex = f:CreateTexture(nil, "ARTWORK")
    f.tex:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
    f.tex:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -1, 1)
    f.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    f.border = f:CreateTexture(nil, "BACKGROUND")
    f.border:SetPoint("TOPLEFT", f, "TOPLEFT", -1, 1)
    f.border:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 1, -1)
    f.cd = CreateFrame("Cooldown", nil, f, "CooldownFrameTemplate")
    f.cd:SetAllPoints(f.tex)
    f.cd:SetDrawEdge(false)
    f.cd:EnableMouse(false)
    f.count = f:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    f.count:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -1, 1)

    f:EnableMouse(true)
    f:SetScript("OnEnter", function(s)
        GameTooltip:SetOwner(s, "ANCHOR_LEFT")
        local ok = false
        if s.auraInstanceID then
            if s.isHarmful and GameTooltip.SetUnitDebuffByAuraInstanceID then
                ok = pcall(GameTooltip.SetUnitDebuffByAuraInstanceID, GameTooltip, "player", s.auraInstanceID)
            elseif GameTooltip.SetUnitBuffByAuraInstanceID then
                ok = pcall(GameTooltip.SetUnitBuffByAuraInstanceID, GameTooltip, "player", s.auraInstanceID)
            end
        end
        if not ok and s.spellId then pcall(GameTooltip.SetSpellByID, GameTooltip, s.spellId) end
        GameTooltip:Show()
    end)
    f:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return f
end

function M:Init(body)
    self.body = body
    self.icons = {}

    -- Onglets Tout/Buff/Débuff dans le bandeau (à côté du titre), avec highlight.
    self.tabBtns = {}
    local host = self.header or body          -- self.header = bandeau du module
    local parentLevel = (host.GetFrameLevel and host:GetFrameLevel() or 0) + 3
    local prev = self.lock
    for i = #TABS, 1, -1 do
        local d = TABS[i]
        local b = CreateFrame("Button", nil, host)
        b:SetHeight(16); b:SetFrameLevel(parentLevel)
        b.sel = b:CreateTexture(nil, "BACKGROUND"); b.sel:SetAllPoints(b); b.sel:SetColorTexture(0.29, 0.64, 1, 0.30); b.sel:Hide()
        b.fs = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); b.fs:SetAllPoints(b); b.fs:SetText(d[2])
        b:SetWidth((b.fs:GetStringWidth() or 30) + 10)
        if prev then b:SetPoint("RIGHT", prev, "LEFT", -3, 0) else b:SetPoint("RIGHT", host, "RIGHT", -3, 0) end
        b.tab = d[1]
        b:SetScript("OnClick", function(s) self:SetTab(s.tab) end)
        self.tabBtns[d[1]] = b
        prev = b
    end

    self.grid = CreateFrame("Frame", nil, body)
    self.grid:SetPoint("TOPLEFT", body, "TOPLEFT", 4, -2)
    self.grid:SetPoint("BOTTOMRIGHT", body, "BOTTOMRIGHT", -4, 0)
    self.grid:SetClipsChildren(true)

    self.ev = CreateFrame("Frame")
    self.ev:SetScript("OnEvent", function(_, _, unit)
        if unit == nil or unit == "player" then self:RequestRefresh() end
    end)
end

function M:Enable()
    self._enabled = true
    self:Prewarm(32)
    self.ev:RegisterUnitEvent("UNIT_AURA", "player")
    if self._placeholder then self._placeholder:Hide() end
    self:SetTab(SP:GetModuleConfig(self.name).tab or "all")
end

function M:Disable()
    self._enabled = false
    if self.ev then self.ev:UnregisterAllEvents() end
    for _, ic in ipairs(self.icons) do ic:Hide() end
end

function M:OnResize(w, h) self:RequestRefresh() end

function M:SetTab(tab)
    SP:GetModuleConfig(self.name).tab = tab
    for t, b in pairs(self.tabBtns) do b.sel:SetShown(t == tab) end
    self:Refresh()
end

function M:Prewarm(n)
    if InCombatLockdown() then return end
    for i = #self.icons + 1, n do self.icons[i] = CreateIcon(self) end
end

function M:Acquire(i)
    local ic = self.icons[i]
    if not ic then
        if InCombatLockdown() then return nil end
        ic = CreateIcon(self); self.icons[i] = ic
    end
    return ic
end

function M:RequestRefresh()
    if not self._enabled then return end
    if self._pending then return end
    self._pending = true
    C_Timer.After(0.1, function() self._pending = false; self:Refresh() end)
end

function M:Refresh()
    if not self._enabled or not self.grid then return end
    local cfg = SP:GetModuleConfig(self.name)
    local tab = cfg.tab or "all"
    local size = cfg.iconSize or 26

    local list = {}
    if tab == "all" or tab == "buff" then Gather("HELPFUL", list) end
    local debuffStart = #list + 1
    if tab == "all" or tab == "debuff" then Gather("HARMFUL", list) end

    local w = self.grid:GetWidth()
    if not w or w < 1 then w = SP.db.panel.width or 280 end
    local perRow = math.max(1, math.floor((w - GAP) / (size + GAP)))

    local shown = 0
    for idx, aura in ipairs(list) do
        local ic = self:Acquire(idx)
        if not ic then break end
        shown = shown + 1
        ic:SetSize(size, size)
        local col, rowN = (idx - 1) % perRow, math.floor((idx - 1) / perRow)
        ic:ClearAllPoints()
        ic:SetPoint("TOPLEFT", self.grid, "TOPLEFT", GAP + col * (size + GAP), -(GAP + rowN * (size + GAP)))
        ic.tex:SetTexture(aura.icon)
        ic.auraInstanceID = aura.auraInstanceID
        ic.spellId = aura.spellId
        ic.isHarmful = (idx >= debuffStart and tab ~= "buff")

        -- bordure : rouge (débuff) selon type, sinon discrète
        local isDebuff = idx >= debuffStart and (tab ~= "buff")
        if isDebuff then
            local c = aura.dispelName and DebuffTypeColor and DebuffTypeColor[aura.dispelName] or { r = 0.8, g = 0.1, b = 0.1 }
            ic.border:SetColorTexture(c.r, c.g, c.b, 1)
        else
            ic.border:SetColorTexture(0, 0, 0, 0.8)
        end

        -- cooldown
        if aura.duration and aura.duration > 0 and aura.expirationTime then
            pcall(function() ic.cd:SetCooldown(aura.expirationTime - aura.duration, aura.duration) end)
        else
            ic.cd:Clear()
        end

        local n = aura.applications or aura.charges
        ic.count:SetText((n and n > 1) and tostring(n) or "")
        ic:Show()
    end
    for i = shown + 1, #self.icons do self.icons[i]:Hide() end

    -- hauteur dynamique
    local rows = math.max(1, math.ceil(shown / perRow))
    local needed = 4 + GAP + rows * (size + GAP)
    if cfg.height ~= needed then cfg.height = needed; SP:RebuildLayout() end
end

SP:RegisterModule(M)
