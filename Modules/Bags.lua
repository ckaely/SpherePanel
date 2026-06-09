-- ============================================================
-- Module : Bags — sac catégorisé (méthode inspirée de Baganator)
-- ============================================================
-- Vue par catégories pliables (Camelote, Équipement, Artisanat, Utilisable, Quêtes, Divers, Vide).
-- Catégories configurables (activation / ordre / filtre custom par nom) dans les options.
-- Boutons SÉCURISÉS → l'usage/équipement des objets fonctionne (clic droit), clic gauche = déplacer.
-- Touche B → affiche le sac (réduit les autres modules ; restaure à la fermeture).
local ADDON_NAME, SP = ...

local M = {
    name          = "Bags",
    label         = "Sac",
    defaultHeight = 240,
}

local BAGS = { 0, 1, 2, 3, 4, 5 }
local GAP, HDR_H = 2, 18

local function BagCfg(key, default)
    local c = _G.BAGANATOR_CONFIG
    if c and c[key] ~= nil then return c[key] end
    return default
end
local function Ct() return C_Container end

-- Clé de catégorie "built-in" d'un objet (classID Blizzard + camelote).
local function ClassKey(info)
    if (info.quality or 1) == 0 then return "junk" end
    local _, _, _, _, _, classID = C_Item.GetItemInfoInstant(info.itemID)
    if classID == 2 or classID == 4 then return "equipment"
    elseif classID == 7 then return "trade"
    elseif classID == 0 then return "consumable"
    elseif classID == 12 then return "quest"
    else return "misc" end
end

-- Catégorie d'un objet : filtres custom (par nom) prioritaires, sinon built-in.
local function CategoryForItem(info, cats, enabledSet)
    local name = info.hyperlink and (GetItemInfo(info.hyperlink))
    if name then
        local low = name:lower()
        for _, c in ipairs(cats) do
            if c.enabled and c.search and c.search ~= "" and low:find(c.search:lower(), 1, true) then
                return c.key
            end
        end
    end
    local k = ClassKey(info)
    if enabledSet[k] then return k end
    return "misc"
end

-- ===== boutons sécurisés ====================================================
local function CreateSlot(self, i)
    local b = CreateFrame("Button", "SpherePanelBagSlot" .. i, self.list, "SecureActionButtonTemplate")
    b:RegisterForClicks("AnyUp")
    b.border = b:CreateTexture(nil, "BACKGROUND"); b.border:SetAllPoints(b)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetPoint("TOPLEFT", b, "TOPLEFT", 1, -1); b.icon:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -1, 1)
    b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    b.count = b:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    b.count:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -1, 1)
    b.hl = b:CreateTexture(nil, "HIGHLIGHT"); b.hl:SetAllPoints(b); b.hl:SetColorTexture(1, 1, 1, 0.2)
    b:SetScript("OnEnter", function(s)
        if s.bag and s.slot then GameTooltip:SetOwner(s, "ANCHOR_LEFT"); pcall(GameTooltip.SetBagItem, GameTooltip, s.bag, s.slot); GameTooltip:Show() end
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    -- clic gauche = ramasser/déposer (insécurisé, OK hors combat) ; clic droit = usage (sécurisé)
    b:SetScript("PreClick", function(s, btn)
        if btn == "LeftButton" and s.bag and not InCombatLockdown() then
            C_Container.PickupContainerItem(s.bag, s.slot)
        end
    end)
    return b
end

local function CreateHeader(self, i)
    local h = CreateFrame("Button", nil, self.list)
    h:SetHeight(HDR_H)
    h.arrow = h:CreateFontString(nil, "OVERLAY", "GameFontNormal"); h.arrow:SetPoint("LEFT", h, "LEFT", 2, 0)
    h.fs = h:CreateFontString(nil, "OVERLAY", "GameFontNormal"); h.fs:SetPoint("LEFT", h.arrow, "RIGHT", 4, 0)
    local hl = h:CreateTexture(nil, "HIGHLIGHT"); hl:SetAllPoints(h); hl:SetColorTexture(1, 1, 1, 0.08)
    return h
end

-- ===== cycle de vie =========================================================
function M:Init(body)
    self.body = body
    self.slots = {}
    self.headers = {}
    self.list = CreateFrame("Frame", nil, body)
    self.list:SetPoint("TOPLEFT", body, "TOPLEFT", 2, -2)
    self.list:SetPoint("BOTTOMRIGHT", body, "BOTTOMRIGHT", -2, 2)
    self.list:SetClipsChildren(true)

    self.ev = CreateFrame("Frame")
    self.ev:SetScript("OnEvent", function(_, e)
        if e == "PLAYER_REGEN_ENABLED" and self._dirty then self:RequestRefresh() end
        if e ~= "PLAYER_REGEN_ENABLED" then self:RequestRefresh() end
    end)

    self.toggle = CreateFrame("Button", "SpherePanelBagToggle", UIParent)
    self.toggle:SetScript("OnClick", function() self:ToggleBags() end)
end

function M:Enable()
    self._enabled = true
    if self._placeholder then self._placeholder:Hide() end
    for _, e in ipairs({ "BAG_UPDATE_DELAYED", "ITEM_LOCK_CHANGED", "PLAYER_REGEN_ENABLED" }) do
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
    for _, h in ipairs(self.headers) do h:Hide() end
    SP:SetModuleHeaderText(self, "")
end

function M:OnResize(w, h) self:RequestRefresh() end

function M:CollapseOthers(collapse)
    if collapse then
        self._savedStates = {}
        for _, m in ipairs(SP.modules) do
            if m.name ~= self.name then
                local c = SP:GetModuleConfig(m.name)
                if c then self._savedStates[m.name] = c.collapsed; c.collapsed = true; SP:UpdateCollapseVisual(m) end
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

function M:ToggleBags()
    if CloseAllBags then pcall(CloseAllBags) end
    local cfg = SP:GetModuleConfig(self.name)
    if not cfg.enabled then SP:EnableModule(self.name) end
    if SP.panel then SP.panel:Show() end
    cfg.collapsed = not cfg.collapsed
    SP:UpdateCollapseVisual(self)
    self:CollapseOthers(not cfg.collapsed)
    SP:RebuildLayout()
    if not cfg.collapsed then self:RequestRefresh() end
end

function M:RequestRefresh()
    if not self._enabled then return end
    if self._pending then return end
    self._pending = true
    C_Timer.After(0.1, function() self._pending = false; self:Refresh() end)
end

-- ===== rendu catégorisé =====================================================
function M:Refresh()
    if not self._enabled or not self.body or not C_Container then return end
    if InCombatLockdown() then self._dirty = true; return end   -- attributs sécurisés non modifiables en combat
    self._dirty = false

    local cfg = SP:GetModuleConfig(self.name)
    local cats = cfg.categories or {}
    local enabledSet = {}
    for _, c in ipairs(cats) do if c.enabled then enabledSet[c.key] = true end end

    -- collecte par catégorie
    local buckets, total, free = {}, 0, 0
    for _, c in ipairs(cats) do buckets[c.key] = {} end
    for _, bag in ipairs(BAGS) do
        local n = Ct().GetContainerNumSlots(bag) or 0
        total = total + n
        for slot = 1, n do
            local info = Ct().GetContainerItemInfo(bag, slot)
            if info and info.itemID then
                local key = CategoryForItem(info, cats, enabledSet)
                if not buckets[key] then key = "misc"; buckets[key] = buckets[key] or {} end
                buckets[key][#buckets[key] + 1] = { bag = bag, slot = slot, info = info }
            else
                free = free + 1
            end
        end
    end

    local size = BagCfg("bag_icon_size", 30)
    local w = self.list:GetWidth(); if not w or w < 1 then w = (SP.db.panel.width or 280) - 4 end
    local perRow = math.max(1, math.floor((w + GAP) / (size + GAP)))

    local si, hi, y = 0, 0, 2
    for _, c in ipairs(cats) do
        if c.enabled then
            local items = buckets[c.key] or {}
            local count = (c.key == "empty") and free or #items
            if count > 0 then
                -- header pliable
                hi = hi + 1
                local hdr = self.headers[hi] or CreateHeader(self, hi)
                self.headers[hi] = hdr
                hdr.cat = c
                hdr.arrow:SetText(c.collapsed and "|cFFFFFFFF+|r" or "|cFFFFFFFF-|r")
                hdr.fs:SetText(("|cFFFFD200%s|r  |cFF888888%d|r"):format(c.label, count))
                hdr:ClearAllPoints()
                hdr:SetPoint("TOPLEFT", self.list, "TOPLEFT", 0, -y)
                hdr:SetPoint("TOPRIGHT", self.list, "TOPRIGHT", 0, -y)
                hdr:SetScript("OnClick", function() c.collapsed = not c.collapsed; self:RequestRefresh() end)
                hdr:Show()
                y = y + HDR_H + 1

                if not c.collapsed then
                    if c.key == "empty" then
                        si = si + 1
                        local b = self.slots[si] or CreateSlot(self, si); self.slots[si] = b
                        b.bag, b.slot = nil, nil
                        b:SetSize(size, size); b:ClearAllPoints()
                        b:SetPoint("TOPLEFT", self.list, "TOPLEFT", 0, -y)
                        b.icon:SetTexture(nil); b.border:SetColorTexture(0.2, 0.2, 0.2, 1)
                        b.icon:SetDesaturated(false)
                        b.count:SetText(tostring(free))
                        pcall(function() b:SetAttribute("type2", nil) end)
                        b:Show()
                        y = y + size + GAP
                    else
                        for j, it in ipairs(items) do
                            si = si + 1
                            local b = self.slots[si] or CreateSlot(self, si); self.slots[si] = b
                            local col, rowN = (j - 1) % perRow, math.floor((j - 1) / perRow)
                            b:SetSize(size, size); b:ClearAllPoints()
                            b:SetPoint("TOPLEFT", self.list, "TOPLEFT", col * (size + GAP), -(y + rowN * (size + GAP)))
                            b.bag, b.slot = it.bag, it.slot
                            b.icon:SetTexture(it.info.iconFileID)
                            local q = it.info.quality or 1
                            b.icon:SetDesaturated((q == 0) and BagCfg("icon_grey_junk", true) or false)
                            local qc = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q]
                            if qc then b.border:SetColorTexture(qc.r, qc.g, qc.b, 1) else b.border:SetColorTexture(0.3, 0.3, 0.3, 1) end
                            local cnt = it.info.stackCount or 1
                            b.count:SetText(cnt > 1 and tostring(cnt) or "")
                            pcall(function()
                                b:SetAttribute("type2", "item"); b:SetAttribute("bag", it.bag); b:SetAttribute("slot", it.slot)
                            end)
                            b:Show()
                        end
                        local rows = math.ceil(#items / perRow)
                        y = y + rows * (size + GAP)
                    end
                    y = y + 4
                end
            end
        end
    end

    for i = si + 1, #self.slots do self.slots[i]:Hide() end
    for i = hi + 1, #self.headers do self.headers[i]:Hide() end

    SP:SetModuleHeaderText(self, ("%d / %d"):format(free, total))
    local needed = math.max(HDR_H, y)
    if cfg.height ~= needed then cfg.height = needed; SP:RebuildLayout() end
end

SP:RegisterModule(M)
