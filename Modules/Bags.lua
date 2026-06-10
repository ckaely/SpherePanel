-- ============================================================
-- Module : Bags — sac catégorisé (méthode inspirée de Baganator)
-- ============================================================
-- Sections pliables + couleurs par section + sous-catégories (par sous-type) + section "Récent"
-- (items pas vus depuis la dernière ouverture). Catégories configurables (ordre/couleur/filtre).
-- Boutons SÉCURISÉS : clic droit = utiliser/équiper, clic gauche = déplacer.
local ADDON_NAME, SP = ...

local M = {
    name          = "Bags",
    label         = "Sac",
    defaultHeight = 240,
}

local BAGS = { 0, 1, 2, 3, 4, 5 }
local GAP, HDR_H, SUB_H = 2, 18, 15
local SUB_COLOR = { 0.45, 0.75, 0.95 }

local function BagCfg(key, default)
    local c = _G.BAGANATOR_CONFIG
    if c and c[key] ~= nil then return c[key] end
    return default
end
local function Ct() return C_Container end

local function ClassKey(info)
    if (info.quality or 1) == 0 then return "junk" end
    local _, _, _, _, _, classID = C_Item.GetItemInfoInstant(info.itemID)
    if classID == 2 or classID == 4 then return "equipment"
    elseif classID == 7 then return "trade"
    elseif classID == 0 then return "consumable"
    elseif classID == 12 then return "quest"
    else return "misc" end
end

-- ===== iLvl + upgrade (Pawn si présent, sinon comparaison à l'équipé) =======
local EQUIP_SLOT = {
    INVTYPE_HEAD = 1, INVTYPE_NECK = 2, INVTYPE_SHOULDER = 3, INVTYPE_CHEST = 5, INVTYPE_ROBE = 5,
    INVTYPE_WAIST = 6, INVTYPE_LEGS = 7, INVTYPE_FEET = 8, INVTYPE_WRIST = 9, INVTYPE_HAND = 10,
    INVTYPE_CLOAK = 15, INVTYPE_2HWEAPON = 16, INVTYPE_WEAPON = 16, INVTYPE_WEAPONMAINHAND = 16,
    INVTYPE_RANGED = 16, INVTYPE_RANGEDRIGHT = 16, INVTYPE_SHIELD = 17, INVTYPE_WEAPONOFFHAND = 17, INVTYPE_HOLDABLE = 17,
}
local MULTI_SLOT = { INVTYPE_FINGER = { 11, 12 }, INVTYPE_TRINKET = { 13, 14 } }

local function NativeUpgrade(link, equipLoc)
    local ilvl = link and GetDetailedItemLevelInfo(link)
    if not ilvl then return false end
    if MULTI_SLOT[equipLoc] then
        local worst
        for _, s in ipairs(MULTI_SLOT[equipLoc]) do
            local el = GetInventoryItemLink("player", s)
            local eil = el and GetDetailedItemLevelInfo(el) or 0
            if not worst or eil < worst then worst = eil end
        end
        return ilvl > (worst or 0)
    end
    local slot = EQUIP_SLOT[equipLoc]
    if not slot then return false end
    local el = GetInventoryItemLink("player", slot)
    if not el then return true end   -- slot vide → upgrade
    return ilvl > (GetDetailedItemLevelInfo(el) or 0)
end

-- Upgrade ? Pawn prioritaire (poids de stats), sinon fallback ilvl natif.
local function IsUpgrade(link, equipLoc)
    if _G.PawnShouldItemLinkHaveUpgradeArrow then
        local ok, res = pcall(_G.PawnShouldItemLinkHaveUpgradeArrow, link, true)
        if ok then return res and true or false end
    end
    if _G.PawnShouldItemLinkHaveUpgradeArrowUnbudgeted then
        local ok, res = pcall(_G.PawnShouldItemLinkHaveUpgradeArrowUnbudgeted, link, true)
        if ok then return res and true or false end
    end
    return NativeUpgrade(link, equipLoc)
end

-- Libellé de sous-catégorie (sous-type d'objet).
local function GroupLabel(info, cat)
    local _, itype, isub, _, _, classID = C_Item.GetItemInfoInstant(info.itemID)
    if cat.groupPrefix and cat.groupPrefix ~= "" then
        return cat.groupPrefix .. ": " .. (isub or itype or "Autres")
    end
    if classID == 4 then return (itype or "Armure") .. (isub and (": " .. isub) or "") end  -- armure
    return itype or "Autres"  -- armes / autres par type
end

function M:CategoryForItem(info, cats, enabledSet)
    if self.recentSet and self.recentSet[info.itemID] and enabledSet["recent"] then return "recent" end
    local name = info.hyperlink and (GetItemInfo(info.hyperlink))
    if name then
        local low = name:lower()
        for _, c in ipairs(cats) do
            if c.enabled and c.search and c.search ~= "" and low:find(c.search:lower(), 1, true) then return c.key end
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
    b.icon:SetPoint("TOPLEFT", b, "TOPLEFT", 2, -2); b.icon:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -2, 2)
    b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    b.count = b:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    b.count:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -1, 1)
    b.ilvl = b:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    b.ilvl:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 1, 1)
    b.ilvl:SetTextColor(1, 0.82, 0)
    b.upg = b:CreateTexture(nil, "OVERLAY"); b.upg:SetSize(13, 13); b.upg:SetPoint("TOPLEFT", b, "TOPLEFT", 0, 0); b.upg:Hide()
    if not pcall(function() b.upg:SetAtlas("bags-greenarrow") end) or not b.upg:GetAtlas() then
        b.upg:SetTexture("Interface\\Buttons\\UI-MicroStream-Green")
    end
    b.hl = b:CreateTexture(nil, "HIGHLIGHT"); b.hl:SetAllPoints(b); b.hl:SetColorTexture(1, 1, 1, 0.2)
    b:SetScript("OnEnter", function(s)
        if s.bag and s.slot then GameTooltip:SetOwner(s, "ANCHOR_LEFT"); pcall(GameTooltip.SetBagItem, GameTooltip, s.bag, s.slot); GameTooltip:Show() end
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    b:SetScript("PreClick", function(s, btn)
        if btn == "LeftButton" and s.bag and not InCombatLockdown() then C_Container.PickupContainerItem(s.bag, s.slot) end
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

local function CreateSub(self, i)
    local s = self.list:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    s:SetJustifyH("LEFT")
    return s
end

-- ===== cycle de vie =========================================================
function M:Init(body)
    self.body = body
    self.slots, self.headers, self.subs = {}, {}, {}
    self.list = CreateFrame("Frame", nil, body)
    self.list:SetPoint("TOPLEFT", body, "TOPLEFT", 2, -2)
    self.list:SetPoint("BOTTOMRIGHT", body, "BOTTOMRIGHT", -2, 2)
    self.list:SetClipsChildren(true)

    self.ev = CreateFrame("Frame")
    self.ev:SetScript("OnEvent", function(_, e)
        if e == "PLAYER_REGEN_ENABLED" then if self._dirty then self:RequestRefresh() end else self:RequestRefresh() end
    end)

    self.toggle = CreateFrame("Button", "SpherePanelBagToggle", UIParent)
    self.toggle:SetScript("OnClick", function() self:ToggleBags() end)
end

-- Déduplique les catégories par clé (un deepMerge legacy peut dupliquer ex. "empty").
function M:SanitizeCategories()
    local cfg = SP:GetModuleConfig(self.name)
    if not (cfg and cfg.categories) then return end
    local seen, out = {}, {}
    for _, c in ipairs(cfg.categories) do
        if c.key and not seen[c.key] then seen[c.key] = true; out[#out + 1] = c end
    end
    cfg.categories = out
end

function M:Enable()
    self._enabled = true
    self:SanitizeCategories()
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
    for _, s in ipairs(self.subs) do s:Hide() end
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

-- "Récent" : items pas vus depuis la dernière ouverture (diff de snapshot).
function M:SnapshotOnOpen()
    local cfg = SP:GetModuleConfig(self.name)
    cfg.known = cfg.known or {}
    local current = {}
    for _, bag in ipairs(BAGS) do
        local n = Ct().GetContainerNumSlots(bag) or 0
        for slot = 1, n do
            local info = Ct().GetContainerItemInfo(bag, slot)
            if info and info.itemID then current[info.itemID] = true end
        end
    end
    self.recentSet = {}
    if next(cfg.known) ~= nil then
        for id in pairs(current) do if not cfg.known[id] then self.recentSet[id] = true end end
    end
    cfg.known = current
end

function M:ToggleBags()
    if CloseAllBags then pcall(CloseAllBags) end
    local cfg = SP:GetModuleConfig(self.name)
    if not cfg.enabled then SP:EnableModule(self.name) end
    if SP.panel then SP.panel:Show() end
    cfg.collapsed = not cfg.collapsed
    -- tant que le sac est ouvert : ignore estompage ET réduction magnétisée (forceReveal)
    self._forceReveal = not cfg.collapsed
    SP:UpdateCollapseVisual(self)
    self:CollapseOthers(not cfg.collapsed)
    if not cfg.collapsed and not InCombatLockdown() then self:SnapshotOnOpen() end
    SP:RebuildLayout()
    if not cfg.collapsed then self:RequestRefresh() end
end

function M:RequestRefresh()
    if not self._enabled then return end
    if self._pending then return end
    self._pending = true
    C_Timer.After(0.1, function() self._pending = false; self:Refresh() end)
end

-- ===== rendu ================================================================
function M:_AcquireSlot(i) local b = self.slots[i] or CreateSlot(self, i); self.slots[i] = b; return b end
function M:_AcquireHeader(i) local h = self.headers[i] or CreateHeader(self, i); self.headers[i] = h; return h end
function M:_AcquireSub(i) local s = self.subs[i] or CreateSub(self, i); self.subs[i] = s; return s end

function M:Refresh()
    if not self._enabled or not self.body or not C_Container then return end
    if InCombatLockdown() then self._dirty = true; return end
    self._dirty = false

    local cfg = SP:GetModuleConfig(self.name)
    local cats = cfg.categories or {}
    local enabledSet = {}
    for _, c in ipairs(cats) do if c.enabled then enabledSet[c.key] = true end end

    local buckets, total, free = {}, 0, 0
    for _, c in ipairs(cats) do buckets[c.key] = {} end
    for _, bag in ipairs(BAGS) do
        local n = Ct().GetContainerNumSlots(bag) or 0
        total = total + n
        for slot = 1, n do
            local info = Ct().GetContainerItemInfo(bag, slot)
            if info and info.itemID then
                local key = self:CategoryForItem(info, cats, enabledSet)
                if not buckets[key] then key = "misc"; buckets[key] = buckets[key] or {} end
                buckets[key][#buckets[key] + 1] = { bag = bag, slot = slot, info = info }
            else
                free = free + 1
            end
        end
    end

    local size = BagCfg("bag_icon_size", 30)
    local greyJunk = BagCfg("icon_grey_junk", true)
    local w = self.list:GetWidth(); if not w or w < 1 then w = (SP.db.panel.width or 280) - 4 end
    local perRow = math.max(1, math.floor((w + GAP) / (size + GAP)))
    local si, hi, subi, y = 0, 0, 0, 2

    local function placeItem(it, col, rowN, baseY)
        si = si + 1
        local b = self:_AcquireSlot(si)
        b:SetSize(size, size); b:ClearAllPoints()
        b:SetPoint("TOPLEFT", self.list, "TOPLEFT", col * (size + GAP), -(baseY + rowN * (size + GAP)))
        b.bag, b.slot = it.bag, it.slot
        b.icon:SetTexture(it.info.iconFileID)
        local q = it.info.quality or 1
        b.icon:SetDesaturated((q == 0) and greyJunk or false)
        local qc = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q]
        if qc then b.border:SetColorTexture(qc.r, qc.g, qc.b, 1) else b.border:SetColorTexture(0.3, 0.3, 0.3, 1) end
        b.ilvl:SetTextColor((qc and qc.r) or 1, (qc and qc.g) or 0.82, (qc and qc.b) or 0)
        local cnt = it.info.stackCount or 1
        b.count:SetText(cnt > 1 and tostring(cnt) or "")
        -- iLvl + flèche d'upgrade (équipement uniquement)
        local link = it.info.hyperlink
        local _, _, _, equipLoc, _, classID = C_Item.GetItemInfoInstant(it.info.itemID)
        if (classID == 2 or classID == 4) and link then
            if cfg.showIlvl ~= false then
                local ilvl = GetDetailedItemLevelInfo(link)
                b.ilvl:SetText(ilvl and tostring(ilvl) or "")
            else
                b.ilvl:SetText("")
            end
            b.upg:SetShown((cfg.showUpgrade ~= false) and IsUpgrade(link, equipLoc) or false)
        else
            b.ilvl:SetText(""); b.upg:Hide()
        end
        pcall(function() b:SetAttribute("type2", "item"); b:SetAttribute("bag", it.bag); b:SetAttribute("slot", it.slot) end)
        b:Show()
    end

    local function grid(items, baseY)
        for j, it in ipairs(items) do
            placeItem(it, (j - 1) % perRow, math.floor((j - 1) / perRow), baseY)
        end
        return math.ceil(#items / perRow) * (size + GAP)
    end

    for _, c in ipairs(cats) do
        if c.enabled then
            local items = buckets[c.key] or {}
            local count = (c.key == "empty") and free or #items
            if count > 0 then
                hi = hi + 1
                local hdr = self:_AcquireHeader(hi)
                hdr.arrow:SetText(c.collapsed and "|cFFFFFFFF+|r" or "|cFFFFFFFF-|r")
                local col = c.color or { 1, 0.82, 0 }
                hdr.fs:SetText(("%s  |cFF888888%d|r"):format(c.label, count))
                hdr.fs:SetTextColor(col[1], col[2], col[3])
                hdr:ClearAllPoints()
                hdr:SetPoint("TOPLEFT", self.list, "TOPLEFT", 0, -y)
                hdr:SetPoint("TOPRIGHT", self.list, "TOPRIGHT", 0, -y)
                hdr:SetScript("OnClick", function()
                    if c.key == "recent" then self.recentSet = {} else c.collapsed = not c.collapsed end
                    self:RequestRefresh()
                end)
                hdr:Show()
                y = y + HDR_H + 1

                if not c.collapsed then
                    if c.key == "empty" then
                        si = si + 1
                        local b = self:_AcquireSlot(si)
                        b.bag, b.slot = nil, nil
                        b:SetSize(size, size); b:ClearAllPoints(); b:SetPoint("TOPLEFT", self.list, "TOPLEFT", 0, -y)
                        b.icon:SetTexture(nil); b.icon:SetDesaturated(false); b.border:SetColorTexture(0.2, 0.2, 0.2, 1)
                        b.count:SetText(tostring(free)); b.ilvl:SetText(""); b.upg:Hide()
                        pcall(function() b:SetAttribute("type2", nil) end)
                        b:Show()
                        y = y + size + GAP
                    elseif c.group then
                        -- sous-catégories par sous-type
                        local groups, order = {}, {}
                        for _, it in ipairs(items) do
                            local gl = GroupLabel(it.info, c)
                            if not groups[gl] then groups[gl] = {}; order[#order + 1] = gl end
                            local g = groups[gl]; g[#g + 1] = it
                        end
                        table.sort(order)
                        for _, gl in ipairs(order) do
                            subi = subi + 1
                            local sf = self:_AcquireSub(subi)
                            sf:ClearAllPoints(); sf:SetPoint("TOPLEFT", self.list, "TOPLEFT", 4, -y)
                            sf:SetText(gl); sf:SetTextColor(SUB_COLOR[1], SUB_COLOR[2], SUB_COLOR[3])
                            sf:Show()
                            y = y + SUB_H
                            y = y + grid(groups[gl], y)
                            y = y + 2
                        end
                    else
                        y = y + grid(items, y)
                        y = y + 2
                    end
                end
            end
        end
    end

    for i = si + 1, #self.slots do self.slots[i]:Hide() end
    for i = hi + 1, #self.headers do self.headers[i]:Hide() end
    for i = subi + 1, #self.subs do self.subs[i]:Hide() end

    SP:SetModuleHeaderText(self, ("%d / %d"):format(free, total))
    local needed = math.max(HDR_H, y)
    SP:SetAutoHeight(self, needed)
end

SP:RegisterModule(M)
