-- ============================================================
-- Module : Bags — sac intégré (inspiré de la config Baganator de Blàcky-Hyjal)
-- ============================================================
-- Touche B → affiche le sac dans le panneau (remplace l'ouverture native).
-- Reprend les réglages Baganator lisibles (bag_icon_size, grey_junk, quality colors, tri type).
-- Colonnes ajustées à la largeur du panneau. Clic = déplacer/ramasser, clic droit = utiliser.
local ADDON_NAME, SP = ...

local M = {
    name          = "Bags",
    label         = "Sac",
    defaultHeight = 220,
}

local BAGS = { 0, 1, 2, 3, 4, 5 }   -- sac à dos + 4 sacs + sac à composants
local GAP = 2

-- Lit la config Baganator (account-wide) si présente.
local function BagCfg(key, default)
    local c = _G.BAGANATOR_CONFIG
    if c and c[key] ~= nil then return c[key] end
    return default
end

local function Ct() return C_Container end

local function CreateSlot(self, i)
    local b = CreateFrame("Button", "SpherePanelBagSlot" .. i, self.list)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b.border = b:CreateTexture(nil, "BACKGROUND"); b.border:SetAllPoints(b)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetPoint("TOPLEFT", b, "TOPLEFT", 1, -1); b.icon:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -1, 1)
    b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    b.count = b:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    b.count:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -1, 1)
    b.hl = b:CreateTexture(nil, "HIGHLIGHT"); b.hl:SetAllPoints(b); b.hl:SetColorTexture(1, 1, 1, 0.2)
    b:SetScript("OnEnter", function(s)
        if s.bag and s.slot then
            GameTooltip:SetOwner(s, "ANCHOR_LEFT")
            pcall(GameTooltip.SetBagItem, GameTooltip, s.bag, s.slot)
            GameTooltip:Show()
        end
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    b:SetScript("OnClick", function(s, btn)
        if not (s.bag and s.slot) then return end
        if btn == "RightButton" then pcall(Ct().UseContainerItem, s.bag, s.slot)
        else pcall(Ct().PickupContainerItem, s.bag, s.slot) end
        self:RequestRefresh()
    end)
    return b
end

function M:Init(body)
    self.body = body
    self.slots = {}

    self.list = CreateFrame("Frame", nil, body)
    self.list:SetPoint("TOPLEFT", body, "TOPLEFT", 2, -2)
    self.list:SetPoint("BOTTOMRIGHT", body, "BOTTOMRIGHT", -2, 2)
    self.list:SetClipsChildren(true)

    self.ev = CreateFrame("Frame")
    self.ev:SetScript("OnEvent", function() self:RequestRefresh() end)

    -- bouton invisible cliqué par la touche B (override binding)
    self.toggle = CreateFrame("Button", "SpherePanelBagToggle", UIParent)
    self.toggle:SetScript("OnClick", function() self:ToggleBags() end)
end

function M:Enable()
    self._enabled = true
    if self._placeholder then self._placeholder:Hide() end
    for _, e in ipairs({ "BAG_UPDATE_DELAYED", "BAG_UPDATE", "ITEM_LOCK_CHANGED" }) do
        pcall(self.ev.RegisterEvent, self.ev, e)
    end
    if not InCombatLockdown() then
        ClearOverrideBindings(self.toggle)
        SetOverrideBindingClick(self.toggle, true, "B", "SpherePanelBagToggle")
        SetOverrideBindingClick(self.toggle, true, "TOGGLEBACKPACK", "SpherePanelBagToggle")
    end
    self:RequestRefresh()
end

function M:Disable()
    self._enabled = false
    if self.ev then self.ev:UnregisterAllEvents() end
    if not InCombatLockdown() then pcall(ClearOverrideBindings, self.toggle) end
    for _, b in ipairs(self.slots) do b:Hide() end
    SP:SetModuleHeaderText(self, "")
end

function M:OnResize(w, h) self:RequestRefresh() end

-- Réduit (collapse=true) tous les autres modules pour donner l'espace au sac, ou restaure leur état.
function M:CollapseOthers(collapse)
    if collapse then
        self._savedStates = {}
        for _, m in ipairs(SP.modules) do
            if m.name ~= self.name then
                local c = SP:GetModuleConfig(m.name)
                if c then
                    self._savedStates[m.name] = c.collapsed
                    c.collapsed = true
                    SP:UpdateCollapseVisual(m)
                end
            end
        end
    elseif self._savedStates then
        for name, st in pairs(self._savedStates) do
            local c, m = SP:GetModuleConfig(name), SP.modulesByName[name]
            if c and m then c.collapsed = st; SP:UpdateCollapseVisual(m) end
        end
        self._savedStates = nil
    end
end

-- B : affiche le sac dans le panneau (réduit les autres modules ; restaure à la fermeture).
function M:ToggleBags()
    if CloseAllBags then pcall(CloseAllBags) end
    local cfg = SP:GetModuleConfig(self.name)
    if not cfg.enabled then SP:EnableModule(self.name) end
    if SP.panel then SP.panel:Show() end
    cfg.collapsed = not cfg.collapsed
    SP:UpdateCollapseVisual(self)
    self:CollapseOthers(not cfg.collapsed)   -- ouverture → réduit les autres ; fermeture → restaure
    SP:RebuildLayout()
    if not cfg.collapsed then self:RequestRefresh() end
end

function M:RequestRefresh()
    if not self._enabled then return end
    if self._pending then return end
    self._pending = true
    C_Timer.After(0.1, function() self._pending = false; self:Refresh() end)
end

function M:Refresh()
    if not self._enabled or not self.body or not C_Container then return end
    local greyJunk = BagCfg("icon_grey_junk", true)

    -- collecte
    local items, free, total = {}, 0, 0
    for _, bag in ipairs(BAGS) do
        local n = Ct().GetContainerNumSlots(bag) or 0
        total = total + n
        for slot = 1, n do
            local info = Ct().GetContainerItemInfo(bag, slot)
            if info and info.itemID then
                items[#items + 1] = { bag = bag, slot = slot, info = info }
            else
                free = free + 1
            end
        end
    end
    -- tri "type" approximé : qualité desc puis itemID
    table.sort(items, function(a, b)
        local qa, qb = a.info.quality or 1, b.info.quality or 1
        if qa ~= qb then return qa > qb end
        return (a.info.itemID or 0) < (b.info.itemID or 0)
    end)

    -- layout : icône 30px (config), colonnes ajustées à la largeur
    local size = BagCfg("bag_icon_size", 30)
    local w = self.list:GetWidth(); if not w or w < 1 then w = (SP.db.panel.width or 280) - 4 end
    local perRow = math.max(1, math.floor((w + GAP) / (size + GAP)))

    for i, it in ipairs(items) do
        local b = self.slots[i]
        if not b then
            if InCombatLockdown() then break end
            b = CreateSlot(self, i); self.slots[i] = b
        end
        local col, rowN = (i - 1) % perRow, math.floor((i - 1) / perRow)
        b:SetSize(size, size)
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", self.list, "TOPLEFT", col * (size + GAP), -(rowN * (size + GAP)))
        b.bag, b.slot = it.bag, it.slot
        b.icon:SetTexture(it.info.iconFileID)
        local q = it.info.quality or 1
        local junk = (q == 0)
        b.icon:SetDesaturated(junk and greyJunk or false)
        local c = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q]
        if c then b.border:SetColorTexture(c.r, c.g, c.b, 1) else b.border:SetColorTexture(0.3, 0.3, 0.3, 1) end
        local cnt = it.info.stackCount or 1
        b.count:SetText(cnt > 1 and tostring(cnt) or "")
        b:Show()
    end
    for i = #items + 1, #self.slots do self.slots[i]:Hide() end

    SP:SetModuleHeaderText(self, ("%d / %d"):format(free, total))

    -- hauteur dynamique
    local rows = math.max(1, math.ceil(#items / perRow))
    local needed = 4 + rows * (size + GAP)
    local cfg = SP:GetModuleConfig(self.name)
    if cfg and cfg.height ~= needed then cfg.height = needed; SP:RebuildLayout() end
end

SP:RegisterModule(M)
