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
    headerHeight  = 38,
    secureChildren = true,
}

local BAGS = { 0, 1, 2, 3, 4, 5 }
local GAP, HDR_H, SUB_H = 2, 18, 15
local CURRENCY_ROW = 17
local SUB_COLOR = { 0.45, 0.75, 0.95 }

local function CompactNumber(v)
    v = tonumber(v) or 0
    if BreakUpLargeNumbers then return BreakUpLargeNumbers(v) end
    if v >= 1000000 then return ("%.1fm"):format(v / 1000000):gsub("%.0m", "m") end
    if v >= 10000 then return ("%.1fk"):format(v / 1000):gsub("%.0k", "k") end
    return tostring(v)
end

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

-- Patterns de butin « pour SOI » uniquement (multi-locale) — construits depuis les
-- chaînes globales Blizzard. Sert à n'historiser QUE les objets RÉELLEMENT acquis
-- (butin/quête/achat), jamais un objet qui entre dans le sac par déséquipement,
-- retrait de banque, courrier ou échange (lesquels ne déclenchent pas CHAT_MSG_LOOT).
local LOOT_SELF_PATTERNS
local function BuildLootPatterns()
    if LOOT_SELF_PATTERNS then return LOOT_SELF_PATTERNS end
    LOOT_SELF_PATTERNS = {}
    local function toPattern(fmt)
        if not fmt then return nil end
        local p = fmt
        p = p:gsub("%%%d?%$?s", "\1")                                  -- %s / %1$s → lien
        p = p:gsub("%%%d?%$?d", "\2")                                  -- %d / %2$d → quantité
        p = p:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")             -- échappe les magiques restants
        p = p:gsub("\1", "(.+)")
        p = p:gsub("\2", "(%%d+)")
        return "^" .. p
    end
    -- _MULTIPLE en premier (plus spécifique : capture le compteur)
    for _, g in ipairs({ "LOOT_ITEM_SELF_MULTIPLE", "LOOT_ITEM_PUSHED_SELF_MULTIPLE" }) do
        local pat = toPattern(_G[g])
        if pat then LOOT_SELF_PATTERNS[#LOOT_SELF_PATTERNS + 1] = { pat = pat, hasCount = true } end
    end
    for _, g in ipairs({ "LOOT_ITEM_SELF", "LOOT_ITEM_PUSHED_SELF" }) do
        local pat = toPattern(_G[g])
        if pat then LOOT_SELF_PATTERNS[#LOOT_SELF_PATTERNS + 1] = { pat = pat, hasCount = false } end
    end
    return LOOT_SELF_PATTERNS
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
    -- labels simplifiés (plus de préfixe « Composant: » / « Conso: ») : juste le sous-type
    if classID == 4 then return isub or itype or "Armure" end   -- armure : sous-type
    return isub or itype or "Autres"                            -- conso/artisanat/armes : sous-type
end

-- ===== Évaluateur de tokens de catégorie (logique reprise de Syndicator/Baganator) =====
-- Recherche = tokens séparés par espace, TOUS requis (ET). Un token est soit un mot-clé
-- (type/emplacement/qualité/liaison via classID/subClassID/invType/bindType), soit un
-- fragment de NOM. Classification basée sur la vraie « base de données » de l'item, pas
-- un simple substring → sorting de qualité.
local IC = Enum and Enum.ItemClass or {}
local CL_ARMOR, CL_WEAPON = IC.Armor or 4, IC.Weapon or 2
local CL_CONSUM, CL_TRADE = IC.Consumable or 0, IC.Tradegoods or 7
local CL_QUEST, CL_GEM = IC.Questitem or 12, IC.Gem or 3

local function ItemMeta(info)
    if info._meta then return info._meta end
    local _, _, _, invType, _, classID, subClassID = C_Item.GetItemInfoInstant(info.itemID)
    local bindType, isReagent = select(14, GetItemInfo(info.hyperlink or info.itemID))
    local m = { classID = classID, subClassID = subClassID, invType = invType or "NONE",
                quality = info.quality, bindType = bindType, reagent = isReagent and true or false }
    info._meta = m
    return m
end

local TOKEN_FN = {
    arme = function(m) return m.classID == CL_WEAPON end, weapon = function(m) return m.classID == CL_WEAPON end,
    armure = function(m) return m.classID == CL_ARMOR end, armor = function(m) return m.classID == CL_ARMOR end,
    equipement = function(m) return m.classID == CL_WEAPON or m.classID == CL_ARMOR end,
    equipment = function(m) return m.classID == CL_WEAPON or m.classID == CL_ARMOR end,
    stuff = function(m) return m.classID == CL_WEAPON or m.classID == CL_ARMOR end,
    consommable = function(m) return m.classID == CL_CONSUM end, consumable = function(m) return m.classID == CL_CONSUM end,
    potion = function(m) return m.classID == CL_CONSUM and (m.subClassID == 1 or m.subClassID == 2 or m.subClassID == 3) end,
    nourriture = function(m) return m.classID == CL_CONSUM and m.subClassID == 5 end,
    food = function(m) return m.classID == CL_CONSUM and m.subClassID == 5 end,
    artisanat = function(m) return m.classID == CL_TRADE or m.reagent end,
    reagent = function(m) return m.classID == CL_TRADE or m.reagent end,
    composant = function(m) return m.classID == CL_TRADE or m.reagent end,
    quete = function(m) return m.classID == CL_QUEST end, quest = function(m) return m.classID == CL_QUEST end,
    gemme = function(m) return m.classID == CL_GEM end, gem = function(m) return m.classID == CL_GEM end,
    tete = function(m) return m.invType == "INVTYPE_HEAD" end, epaules = function(m) return m.invType == "INVTYPE_SHOULDER" end,
    torse = function(m) return m.invType == "INVTYPE_CHEST" or m.invType == "INVTYPE_ROBE" end,
    jambes = function(m) return m.invType == "INVTYPE_LEGS" end, pieds = function(m) return m.invType == "INVTYPE_FEET" end,
    mains = function(m) return m.invType == "INVTYPE_HAND" end, ceinture = function(m) return m.invType == "INVTYPE_WAIST" end,
    poignets = function(m) return m.invType == "INVTYPE_WRIST" end,
    anneau = function(m) return m.invType == "INVTYPE_FINGER" end, ring = function(m) return m.invType == "INVTYPE_FINGER" end,
    bijou = function(m) return m.invType == "INVTYPE_TRINKET" end, trinket = function(m) return m.invType == "INVTYPE_TRINKET" end,
    cape = function(m) return m.invType == "INVTYPE_CLOAK" end, cloak = function(m) return m.invType == "INVTYPE_CLOAK" end,
    commun = function(m) return m.quality == 1 end, inhabituel = function(m) return m.quality == 2 end,
    uncommon = function(m) return m.quality == 2 end, rare = function(m) return m.quality == 3 end,
    epique = function(m) return m.quality == 4 end, epic = function(m) return m.quality == 4 end,
    legendaire = function(m) return m.quality == 5 end, legendary = function(m) return m.quality == 5 end,
    camelote = function(m) return m.quality == 0 end, junk = function(m) return m.quality == 0 end,
    boe = function(m) return m.bindType == 2 end, bop = function(m) return m.bindType == 1 end,
}
M.CATEGORY_KEYWORDS = TOKEN_FN   -- exposé pour l'aide du panneau de config

local function MatchSearch(info, search, lowName)
    for token in search:gmatch("%S+") do
        local fn = TOKEN_FN[token]
        if fn then
            if not fn(ItemMeta(info)) then return false end
        elseif not (lowName and lowName:find(token, 1, true)) then
            return false
        end
    end
    return true
end

function M:CategoryForItem(info, cats, enabledSet)
    if self.recentSet and self.recentSet[info.itemID] and enabledSet["recent"] then return "recent" end
    info._meta = nil   -- meta recalculée à la demande pour cet item
    local name = info.hyperlink and (GetItemInfo(info.hyperlink))
    local low = name and name:lower()
    for _, c in ipairs(cats) do
        if c.enabled and c.search and c.search ~= "" and MatchSearch(info, c.search:lower(), low) then
            return c.key
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
    b:EnableMouseWheel(true)
    b:SetScript("OnMouseWheel", function(_, delta) self:ScrollBag(delta) end)
    b:SetScript("OnEnter", function(s)
        if s.bag and s.slot then SP:AnchorTooltipOutsidePanel(GameTooltip, s); pcall(GameTooltip.SetBagItem, GameTooltip, s.bag, s.slot); GameTooltip:Show() end
        self:DimOthers(s)
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide(); self:UndimAll() end)
    b.SplitStack = function(s, split)
        if s.bag and s.slot and C_Container and C_Container.SplitContainerItem then
            C_Container.SplitContainerItem(s.bag, s.slot, split)
        end
    end
    b:SetScript("PreClick", function(s, btn)
        if not (s.bag and s.slot) then return end
        local link = C_Container and C_Container.GetContainerItemLink and C_Container.GetContainerItemLink(s.bag, s.slot)
        if link and HandleModifiedItemClick and HandleModifiedItemClick(link) then return end
        if btn == "LeftButton" and not InCombatLockdown() then
            if IsModifiedClick and IsModifiedClick("SPLITSTACK") and not (CursorHasItem and CursorHasItem()) then
                local info = C_Container and C_Container.GetContainerItemInfo and C_Container.GetContainerItemInfo(s.bag, s.slot)
                local count = info and info.stackCount or 0
                if count and count > 1 and StackSplitFrame then
                    StackSplitFrame:OpenStackSplitFrame(count, s, "BOTTOMLEFT", "TOPLEFT")
                    return
                end
            end
            local had = CursorHasItem and CursorHasItem()
            if C_Container and C_Container.PickupContainerItem then C_Container.PickupContainerItem(s.bag, s.slot) end
            SP:PlayItemSound(had and "drop" or "pickup")
        elseif btn == "RightButton" and not InCombatLockdown() and C_Container and C_Container.UseContainerItem then
            pcall(C_Container.UseContainerItem, s.bag, s.slot)
            SP:PlayItemSound("drop")
        end
    end)
    -- vrai drag & drop (+ son de prise/dépôt)
    b:RegisterForDrag("LeftButton")
    b:SetScript("OnDragStart", function(s)
        if s.bag and not InCombatLockdown() then C_Container.PickupContainerItem(s.bag, s.slot); SP:PlayItemSound("pickup") end
    end)
    b:SetScript("OnReceiveDrag", function(s)
        if s.bag and not InCombatLockdown() then
            local had = CursorHasItem and CursorHasItem()
            C_Container.PickupContainerItem(s.bag, s.slot)
            SP:PlayItemSound(had and "drop" or "pickup")
        end
    end)
    return b
end

local function CreateHeader(self, i)
    local h = CreateFrame("Button", nil, self.list)
    h:SetHeight(HDR_H)
    h:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    h:EnableMouseWheel(true)
    h:SetScript("OnMouseWheel", function(_, delta) self:ScrollBag(delta) end)
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

local function CreateCurrencyRow(self, i)
    local r = CreateFrame("Frame", nil, self.list)
    r:SetHeight(CURRENCY_ROW)
    r.bg = r:CreateTexture(nil, "BACKGROUND")
    r.bg:SetAllPoints(r)
    r.bg:SetColorTexture(0, 0, 0, 0.18)
    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.icon:SetSize(14, 14)
    r.icon:SetPoint("LEFT", r, "LEFT", 4, 0)
    r.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    r.fs = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    r.fs._spFontRole = "secondary"
    r.fs:SetPoint("LEFT", r.icon, "RIGHT", 5, 0)
    r.fs:SetPoint("RIGHT", r, "RIGHT", -5, 0)
    r.fs:SetJustifyH("LEFT")
    r.fs:SetWordWrap(false)
    r:EnableMouse(true)
    r:EnableMouseWheel(true)
    r:SetScript("OnMouseWheel", function(_, delta) self:ScrollBag(delta) end)
    r:SetScript("OnEnter", function(s)
        if s.currencyID then
            SP:AnchorTooltipOutsidePanel(GameTooltip, s)
            pcall(GameTooltip.SetCurrencyByID, GameTooltip, s.currencyID)
            GameTooltip:Show()
        end
    end)
    r:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return r
end

-- ===== cycle de vie =========================================================
function M:Init(body)
    self.body = body
    self.slots, self.headers, self.subs, self.currencyRows = {}, {}, {}, {}
    self.histRows = {}
    self.histDateCollapsed = {}
    self.tabBtns = {}

    if self.header then
        if self.labelFS then
            self.labelFS:ClearAllPoints()
            self.labelFS:SetPoint("TOPLEFT", self.header, "TOPLEFT", 8, -3)
        end
        if self.suffixFS then
            self.suffixFS:ClearAllPoints()
            self.suffixFS:SetPoint("TOPRIGHT", self.lock or self.header, "TOPLEFT", -6, -3)
            self.suffixFS:SetJustifyH("RIGHT")
        end
    end

    local tabParent = self.header or body
    self.tabBar = CreateFrame("Frame", nil, tabParent)
    if self.header then
        self.tabBar:SetPoint("BOTTOMLEFT", self.header, "BOTTOMLEFT", 8, 2)
        self.tabBar:SetPoint("BOTTOMRIGHT", self.lock or self.header, "BOTTOMLEFT", -6, 2)
    else
        self.tabBar:SetPoint("TOPLEFT", body, "TOPLEFT", 2, -2)
        self.tabBar:SetPoint("TOPRIGHT", body, "TOPRIGHT", -2, -2)
    end
    self.tabBar:SetHeight(18)
    self.tabBar:EnableMouseWheel(true)
    self.tabBar:SetScript("OnMouseWheel", function(_, delta)
        self:CycleBagTab(delta)
    end)
    for i, d in ipairs({ { "bags", "Sac" }, { "history", "Historique" } }) do
        local b = CreateFrame("Button", nil, self.tabBar)
        b:SetSize(i == 1 and 42 or 78, 16)
        b:SetPoint("LEFT", self.tabBar, "LEFT", (i == 1) and 0 or 46, 0)
        b.bg = b:CreateTexture(nil, "BACKGROUND"); b.bg:SetAllPoints(b)
        b.fs = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); b.fs:SetAllPoints(b); b.fs:SetText(d[2])
        b.tab = d[1]
        b:SetScript("OnClick", function(s) self:SetBagTab(s.tab) end)
        self.tabBtns[d[1]] = b
    end

    if self.header then
        self.header:EnableMouseWheel(true)
        self.header:SetScript("OnMouseWheel", function(_, delta) self:CycleBagTab(delta) end)
    end

    self.list = CreateFrame("Frame", nil, body)
    self.list:SetPoint("TOPLEFT", body, "TOPLEFT", 2, -2)
    self.list:SetPoint("BOTTOMRIGHT", body, "BOTTOMRIGHT", -2, 2)
    self.list:SetClipsChildren(true)
    self.list:EnableMouseWheel(true)
    self.list:SetScript("OnMouseWheel", function(_, delta) self:ScrollBag(delta) end)

    self.history = CreateFrame("Frame", nil, body)
    self.history:SetPoint("TOPLEFT", self.list, "TOPLEFT", 0, 0)
    self.history:SetPoint("BOTTOMRIGHT", self.list, "BOTTOMRIGHT", 0, 0)
    self.history:SetClipsChildren(true)
    self.history:EnableMouseWheel(true)
    self.history:SetScript("OnMouseWheel", function(_, delta) self:ScrollBag(delta) end)
    self.history:Hide()

    self.ev = CreateFrame("Frame")
    self.ev:SetScript("OnEvent", function(_, e, ...)
        if e == "PLAYER_REGEN_ENABLED" then
            if self._dirty then self:RequestRefresh() end
        elseif e == "MERCHANT_SHOW" then
            local cfg = SP:GetModuleConfig(self.name)
            if not cfg or cfg.autoOpenAtNpc ~= false then self:OpenBags("merchant") end
            self:AutoSellJunk()
        elseif e == "BANKFRAME_OPENED" or e == "MAIL_SHOW" or e == "AUCTION_HOUSE_SHOW" or e == "TRADE_SHOW" then
            local cfg = SP:GetModuleConfig(self.name)
            if not cfg or cfg.autoOpenAtNpc ~= false then self:OpenBags(e) end
        elseif e == "CHAT_MSG_LOOT" then
            self:LogLootMessage(...)
        elseif e == "CHAT_MSG_MONEY" or e == "CHAT_MSG_CURRENCY" then
            self:LogHistory("money", ...)
        elseif e == "GET_ITEM_INFO_RECEIVED" then
            if self.history and self.history:IsShown() then self:RefreshHistory() end
        else
            -- BAG_UPDATE_DELAYED / ITEM_LOCK_CHANGED / etc. : rafraîchit la GRILLE seulement.
            -- L'historique n'est PLUS alimenté par diff de sac (faux positifs : déséquipement,
            -- banque, courrier). Il se construit uniquement via CHAT_MSG_LOOT/MONEY/CURRENCY.
            self:RequestRefresh()
        end
    end)

    self.toggle = CreateFrame("Button", "SpherePanelBagToggle", UIParent)
    self.toggle:SetScript("OnClick", function() self:ToggleBags() end)

    -- Boutons dans le BANDEAU (tri natif + vue des sacs équipés)
    if self.header then
        local anchor = self.lock or self.header
        local function headerBtn(atlas, fallbackIcon, tip, onClick)
            local btn = CreateFrame("Button", nil, self.header)
            btn:SetSize(18, 18)
            btn.tex = btn:CreateTexture(nil, "ARTWORK"); btn.tex:SetAllPoints(btn)
            if not pcall(function() btn.tex:SetAtlas(atlas, true) end) or not btn.tex:GetAtlas() then
                btn.tex:SetTexture(fallbackIcon); btn.tex:SetTexCoord(0.1, 0.9, 0.1, 0.9)
            end
            btn:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
            btn:SetScript("OnClick", onClick)
            btn:SetScript("OnEnter", function(s) SP:AnchorTooltipOutsidePanel(GameTooltip, s); GameTooltip:SetText(tip); GameTooltip:Show() end)
            btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
            return btn
        end
        self.bagsBtn = headerBtn("bags-button-bag-default", "Interface\\Icons\\INV_Misc_Bag_08",
            "Sacs équipés", function() self:ToggleBagSlotsPanel() end)
        self.bagsBtn:SetPoint("TOPRIGHT", anchor, "TOPLEFT", -6, -2)
        self.sortBtn = headerBtn("bags-button-autosort-up", "Interface\\Icons\\INV_Misc_Broom_01",
            "Trier le sac", function() self:SortBags() end)
        self.sortBtn:SetPoint("RIGHT", self.bagsBtn, "LEFT", -3, 0)
    end
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
    for _, e in ipairs({
        "BAG_UPDATE_DELAYED", "ITEM_LOCK_CHANGED", "PLAYER_REGEN_ENABLED",
        "CURRENCY_DISPLAY_UPDATE", "PLAYER_MONEY", "PLAYER_ENTERING_WORLD",
        "MERCHANT_SHOW", "BANKFRAME_OPENED", "MAIL_SHOW", "AUCTION_HOUSE_SHOW", "TRADE_SHOW",
        "CHAT_MSG_LOOT", "CHAT_MSG_MONEY", "CHAT_MSG_CURRENCY", "GET_ITEM_INFO_RECEIVED",
    }) do
        pcall(self.ev.RegisterEvent, self.ev, e)
    end
    self:InstallBagHooks()
    self:SetBagTab((SP:GetModuleConfig(self.name) or {}).activeTab or "bags")
    if not InCombatLockdown() then
        ClearOverrideBindings(self.toggle)
        SetOverrideBindingClick(self.toggle, true, "B", "SpherePanelBagToggle")
        SetOverrideBindingClick(self.toggle, true, "SHIFT-B", "SpherePanelBagToggle")
        SetOverrideBindingClick(self.toggle, true, "TOGGLEBACKPACK", "SpherePanelBagToggle")
        SetOverrideBindingClick(self.toggle, true, "OPENALLBAGS", "SpherePanelBagToggle")
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
    for _, r in ipairs(self.currencyRows) do r:Hide() end
    for _, r in ipairs(self.histRows or {}) do r:Hide() end
    SP:SetModuleHeaderText(self, "")
end

function M:OnResize(w, h) self:RequestRefresh() end

function M:CycleBagTab(delta)
    local cfg = SP:GetModuleConfig(self.name)
    local nextTab = ((cfg and cfg.activeTab) == "history") and "bags" or "history"
    self:SetBagTab(nextTab)
end

function M:ScrollBag(delta)
    local cfg = SP:GetModuleConfig(self.name)
    if cfg and cfg.activeTab == "history" then
        local visible = self.history and (self.history:GetHeight() or 1) or 1
        local maxS = math.max(0, (self._histContentH or 0) - visible)
        self.histScroll = math.min(maxS, math.max(0, (self.histScroll or 0) - (delta or 0) * 28))
        self:RefreshHistory()
        return
    end
    local visible = self.list and (self.list:GetHeight() or 1) or 1
    local maxS = math.max(0, (self._bagContentH or 0) - visible)
    self.bagScroll = math.min(maxS, math.max(0, (self.bagScroll or 0) - (delta or 0) * 32))
    self:Refresh()
end

-- Estompage/désaturation des icônes NON survolées (niveau réglable en config).
function M:DimOthers(active)
    local cfg = SP:GetModuleConfig(self.name)
    if not cfg or cfg.hoverDim ~= true then return end
    local lvl = cfg.hoverSaturation or 0.35
    for _, b in ipairs(self.slots or {}) do
        if b ~= active and b:IsShown() and b.icon then
            b.icon:SetDesaturated(true)
            b.icon:SetAlpha((b._baseAlpha or 1) * lvl)
        end
    end
end

function M:UndimAll()
    for _, b in ipairs(self.slots or {}) do
        if b:IsShown() and b.icon then
            b.icon:SetDesaturated(b._baseDesat or false)
            b.icon:SetAlpha(b._baseAlpha or 1)
        end
    end
end

-- Tri natif du sac (guard combat).
function M:SortBags()
    if InCombatLockdown() then return end
    if C_Container and C_Container.SortBags then pcall(C_Container.SortBags)
    elseif SortBags then pcall(SortBags) end
end

-- ===== Panneau latéral des sacs équipés : boutons natifs (changer + menu Blizzard) ====
local BAG_NAMES = { [0] = "Sac à dos" }
local function BagInvSlot(bagID) return ContainerIDToInventoryID and ContainerIDToInventoryID(bagID) end

-- Menu contextuel natif d'un sac : assignation de filtre + nettoyage (logique Blizzard).
local function ShowBagFilterMenu(anchor, bagID)
    if not (MenuUtil and MenuUtil.CreateContextMenu and C_Container and C_Container.GetBagSlotFlag) then return end
    pcall(MenuUtil.CreateContextMenu, anchor, function(_, root)
        root:CreateTitle(BAG_FILTER_TITLE_SORTING or "Tri")
        if ContainerFrame_CanContainerUseFilterMenu and ContainerFrame_CanContainerUseFilterMenu(bagID)
           and ContainerFrameUtil_EnumerateBagGearFilters and BAG_FILTER_LABELS then
            root:CreateTitle(BAG_FILTER_ASSIGN_TO or "Assigner à")
            for _, flag in ContainerFrameUtil_EnumerateBagGearFilters() do
                local cb = root:CreateCheckbox(BAG_FILTER_LABELS[flag],
                    function() return C_Container.GetBagSlotFlag(bagID, flag) end,
                    function() C_Container.SetBagSlotFlag(bagID, flag, not C_Container.GetBagSlotFlag(bagID, flag)) end)
                if cb and cb.SetResponse and MenuResponse then cb:SetResponse(MenuResponse.Close) end
            end
        end
        root:CreateTitle(BAG_FILTER_IGNORE or "Ignorer")
        local DSORT = Enum and Enum.BagSlotFlags and Enum.BagSlotFlags.DisableAutoSort
        local isBackpack = (bagID == (Enum and Enum.BagIndex and Enum.BagIndex.Backpack or 0))
        root:CreateCheckbox(BAG_FILTER_CLEANUP or "Ignorer ce sac au tri",
            function()
                if isBackpack and C_Container.GetBackpackAutosortDisabled then return C_Container.GetBackpackAutosortDisabled() end
                return DSORT and C_Container.GetBagSlotFlag(bagID, DSORT)
            end,
            function()
                if isBackpack and C_Container.SetBackpackAutosortDisabled then
                    C_Container.SetBackpackAutosortDisabled(not C_Container.GetBackpackAutosortDisabled())
                elseif DSORT then
                    C_Container.SetBagSlotFlag(bagID, DSORT, not C_Container.GetBagSlotFlag(bagID, DSORT))
                end
            end)
    end)
end

function M:_BagRow(i)
    local p = self.bagSlotsPanel
    local r = p.rows[i]
    if not r then
        r = CreateFrame("Frame", nil, p); r:SetSize(170, 30)
        r.stripe = r:CreateTexture(nil, "BACKGROUND"); r.stripe:SetAllPoints(r)
        r.btn = CreateFrame("Button", nil, r); r.btn:SetSize(26, 26); r.btn:SetPoint("LEFT", r, "LEFT", 3, 0)
        r.btn:RegisterForClicks("AnyUp"); r.btn:RegisterForDrag("LeftButton")
        r.btn.bgs = r.btn:CreateTexture(nil, "BACKGROUND"); r.btn.bgs:SetAllPoints(r.btn); r.btn.bgs:SetColorTexture(0, 0, 0, 0.5)
        r.icon = r.btn:CreateTexture(nil, "ARTWORK"); r.icon:SetPoint("TOPLEFT", 2, -2); r.icon:SetPoint("BOTTOMRIGHT", -2, 2); r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        r.btn:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
        r.name = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); r.name:SetPoint("LEFT", r.btn, "RIGHT", 6, 0); r.name:SetPoint("RIGHT", r, "RIGHT", -44, 0); r.name:SetJustifyH("LEFT"); r.name:SetWordWrap(false)
        r.slots = r:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall"); r.slots:SetPoint("RIGHT", r, "RIGHT", -4, 0); r.slots:SetJustifyH("RIGHT")
        r.btn:SetScript("OnClick", function(s, btn)
            local inv = BagInvSlot(s.bagID)
            if btn == "RightButton" then ShowBagFilterMenu(s, s.bagID)
            elseif InCombatLockdown() then return
            elseif IsModifiedClick and IsModifiedClick("PICKUPITEM") then if inv and PickupBagFromSlot then PickupBagFromSlot(inv) end
            elseif inv then
                if CursorHasItem and CursorHasItem() then if PutItemInBag then PutItemInBag(inv) end
                elseif PickupBagFromSlot then PickupBagFromSlot(inv) end
            end
            C_Timer.After(0.3, function() if self.bagSlotsPanel and self.bagSlotsPanel:IsShown() then self:RefreshBagSlots() end end)
        end)
        r.btn:SetScript("OnDragStart", function(s) local inv = BagInvSlot(s.bagID); if inv and PickupBagFromSlot and not InCombatLockdown() then PickupBagFromSlot(inv) end end)
        r.btn:SetScript("OnReceiveDrag", function(s) local inv = BagInvSlot(s.bagID); if inv and PutItemInBag and not InCombatLockdown() then PutItemInBag(inv) end end)
        r.btn:SetScript("OnEnter", function(s)
            local inv = BagInvSlot(s.bagID)
            SP:AnchorTooltipOutsidePanel(GameTooltip, s)
            if inv then pcall(GameTooltip.SetInventoryItem, GameTooltip, "player", inv) else GameTooltip:SetText(BAG_NAMES[0] or "Sac à dos") end
            GameTooltip:AddLine("|cFF888888Clic = changer · Clic droit = trier/filtrer|r")
            GameTooltip:Show()
        end)
        r.btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
        p.rows[i] = r
    end
    return r
end

function M:RefreshBagSlots()
    local p = self.bagSlotsPanel; if not p then return end
    local i = 0
    for bagID = 0, 5 do
        if bagID == 0 or BagInvSlot(bagID) then
            i = i + 1
            local total = (C_Container and C_Container.GetContainerNumSlots and C_Container.GetContainerNumSlots(bagID)) or 0
            local r = self:_BagRow(i)
            r:ClearAllPoints(); r:SetPoint("TOPLEFT", p, "TOPLEFT", 6, -28 - (i - 1) * 31); r:SetPoint("RIGHT", p, "RIGHT", -6, 0)
            r.btn.bagID = bagID
            local icon, name
            if bagID == 0 then
                icon = "Interface\\Buttons\\Button-Backpack-Up"; name = BAG_NAMES[0]
            else
                local inv = BagInvSlot(bagID)
                icon = inv and GetInventoryItemTexture("player", inv)
                local link = inv and GetInventoryItemLink("player", inv)
                name = (link and link:match("%[(.-)%]")) or (total > 0 and ("Sac " .. bagID) or "(emplacement vide)")
            end
            r.icon:SetTexture(icon or "Interface\\PaperDoll\\UI-PaperDoll-Slot-Bag")
            local free = (C_Container and C_Container.GetContainerNumFreeSlots and C_Container.GetContainerNumFreeSlots(bagID)) or 0
            r.name:SetText(name)
            r.slots:SetText(total > 0 and ("%d/%d"):format(total - free, total) or "")
            r.stripe:SetColorTexture(0, 0, 0, (i % 2 == 0) and 0.22 or 0.10)
            r:Show()
        end
    end
    for j = i + 1, #p.rows do p.rows[j]:Hide() end
    p._rowCount = i
    p.note:SetText("|cFF888888Clic = changer le sac · Clic droit = tri/filtre Blizzard.|r")
end

function M:ToggleBagSlotsPanel()
    if self.bagSlotsPanel and self.bagSlotsPanel:IsShown() then self.bagSlotsPanel:Hide(); return end
    if not self.bagSlotsPanel then
        local p = CreateFrame("Frame", nil, self.body)
        p:SetFrameStrata("DIALOG"); p:SetFrameLevel((self.body:GetFrameLevel() or 1) + 15)
        p:SetSize(190, 6 * 31 + 50)
        p.bg = p:CreateTexture(nil, "BACKGROUND"); p.bg:SetAllPoints(p); p.bg:SetColorTexture(0.04, 0.05, 0.08, 0.96)
        p.title = p:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); p.title:SetPoint("TOPLEFT", p, "TOPLEFT", 8, -7); p.title:SetText("Sacs équipés")
        p.note = p:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall"); p.note:SetPoint("BOTTOMLEFT", p, "BOTTOMLEFT", 8, 6); p.note:SetPoint("RIGHT", p, "RIGHT", -6, 0); p.note:SetJustifyH("LEFT"); p.note:SetWordWrap(true)
        p.rows = {}
        self.bagSlotsPanel = p
    end
    self:RefreshBagSlots()
    local p = self.bagSlotsPanel
    p:SetHeight((p._rowCount or 6) * 31 + 52)
    local onRight = (SP.db.panel.side ~= "left")
    p:ClearAllPoints()
    if onRight then p:SetPoint("TOPRIGHT", self.body, "TOPLEFT", -4, 6)
    else p:SetPoint("TOPLEFT", self.body, "TOPRIGHT", 4, 6) end
    p:Show()
end

function M:SetBagTab(tab)
    local cfg = SP:GetModuleConfig(self.name)
    cfg.activeTab = (tab == "history") and "history" or "bags"
    if self.list then self.list:SetShown(cfg.activeTab ~= "history") end
    if self.history then self.history:SetShown(cfg.activeTab == "history") end
    for k, b in pairs(self.tabBtns or {}) do
        b.bg:SetColorTexture(0.30, 0.55, 0.95, (k == cfg.activeTab) and 0.32 or 0.10)
    end
    if cfg.activeTab == "history" then self:RefreshHistory() else self:RequestRefresh() end
end

function M:HistoryColor(kind)
    if kind == "loot" then return 0.40, 0.90, 0.40
    elseif kind == "sold" then return 0.62, 0.62, 0.62
    elseif kind == "money" then return 1.00, 0.82, 0.00
    elseif kind == "removed" then return 1.00, 0.35, 0.25
    else return 0.90, 0.85, 0.45 end
end

function M:CategoryColor(key)
    local cfg = SP:GetModuleConfig(self.name)
    for _, c in ipairs((cfg and cfg.categories) or {}) do
        if c.key == key and c.color then return c.color[1] or 1, c.color[2] or 1, c.color[3] or 1 end
    end
    return nil
end

function M:LogHistory(kind, text, itemID, count)
    local cfg = SP:GetModuleConfig(self.name)
    cfg.history = cfg.history or {}
    local label = text
    local cat
    if itemID then
        if C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, itemID) end
        local name, link, quality = GetItemInfo(itemID)
        label = (link or name or ("item:" .. tostring(itemID))) .. ((count and count > 1) and (" x" .. count) or "")
        if kind == "sold" then cat = "junk"
        else cat = ClassKey({ itemID = itemID, quality = quality or 1 }) end
    end
    cfg.history[#cfg.history + 1] = { t = time(), kind = kind or "misc", text = label or "?", itemID = itemID, count = count, cat = cat }
    while #cfg.history > 250 do table.remove(cfg.history, 1) end
    if self.history and self.history:IsShown() then self:RefreshHistory() end
end

-- Historise un objet RÉELLEMENT acquis depuis un message CHAT_MSG_LOOT pour soi.
-- (Le déséquipement / retrait banque / courrier ne déclenche pas cet évènement.)
function M:LogLootMessage(msg)
    if not msg or msg == "" then return end
    local pats = BuildLootPatterns()
    for _, entry in ipairs(pats) do
        local a, b = msg:match(entry.pat)
        local linkChunk, countStr
        if entry.hasCount then linkChunk, countStr = a, b else linkChunk = a end
        if linkChunk then
            local itemID = tonumber(linkChunk:match("|Hitem:(%d+)"))
            if itemID then
                local count = tonumber(countStr) or 1
                self:LogHistory("loot", nil, itemID, count)
            end
            return
        end
    end
end

function M:_AcquireHistoryRow(i)
    local r = self.histRows[i]
    if not r then
        r = CreateFrame("Button", nil, self.history)
        r:SetHeight(18)
        r.bg = r:CreateTexture(nil, "BACKGROUND")
        r.bg:SetAllPoints(r)
        r.arrow = r:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        r.arrow:SetPoint("LEFT", r, "LEFT", 3, 0); r.arrow:SetWidth(12); r.arrow:SetJustifyH("LEFT")
        r.time = r:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        r.time._spFontRole = "secondary"
        r.time:SetPoint("LEFT", r, "LEFT", 2, 0); r.time:SetWidth(36); r.time:SetJustifyH("LEFT")
        r.icon = r:CreateTexture(nil, "ARTWORK")
        r.icon:SetSize(14, 14)
        r.icon:SetPoint("LEFT", r.time, "RIGHT", 4, 0)
        r.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        r.text = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        r.text:SetPoint("LEFT", r.icon, "RIGHT", 5, 0); r.text:SetPoint("RIGHT", r, "RIGHT", -2, 0)
        r.text:SetJustifyH("LEFT"); r.text:SetWordWrap(false)
        r:SetScript("OnClick", function(s)
            if s.dateKey then
                self.histDateCollapsed[s.dateKey] = not self.histDateCollapsed[s.dateKey]
                self:RefreshHistory()
            end
        end)
        r:EnableMouseWheel(true)
        r:SetScript("OnMouseWheel", function(_, delta) self:ScrollBag(delta) end)
        self.histRows[i] = r
    end
    return r
end

function M:ResolveHistoryEntry(e)
    if not e then return "?", nil, nil end
    if e.itemID then
        if C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, e.itemID) end
        local name, link, quality, _, _, _, _, _, _, icon = GetItemInfo(e.itemID)
        icon = icon or (C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(e.itemID))
        local label = (link or name or ("item:" .. tostring(e.itemID))) .. ((e.count and e.count > 1) and (" x" .. e.count) or "")
        return label, icon, quality
    end
    return e.text or "?", nil, nil
end

-- Regroupe l'historique (le plus récent en premier) sous un séparateur par jour.
function M:_BuildHistoryRows()
    local cfg = SP:GetModuleConfig(self.name)
    local hist = cfg.history or {}
    self.histDateCollapsed = self.histDateCollapsed or {}
    local rows, lastKey = {}, nil
    for i = #hist, 1, -1 do
        local e = hist[i]
        local t = e.t or time()
        local dkey = date("%Y%m%d", t)
        if dkey ~= lastKey then
            rows[#rows + 1] = { sep = true, key = dkey, label = date("%d/%m/%Y", t) }
            lastKey = dkey
        end
        if not self.histDateCollapsed[dkey] then rows[#rows + 1] = { e = e } end
    end
    return rows
end

function M:RefreshHistory()
    if not self.history then return end
    local rows = self:_BuildHistoryRows()
    local visible = self.history:GetHeight() or 1
    self.histScroll = math.min(math.max(0, (#rows * 18 + 2) - visible), math.max(0, self.histScroll or 0))
    local y = 2
    for ri, row in ipairs(rows) do
        local r = self:_AcquireHistoryRow(ri)
        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", self.history, "TOPLEFT", 0, -(y - (self.histScroll or 0)))
        r:SetPoint("TOPRIGHT", self.history, "TOPRIGHT", 0, -(y - (self.histScroll or 0)))
        r.text:ClearAllPoints()
        if row.sep then
            r.dateKey = row.key
            r:EnableMouse(true)
            r.bg:SetColorTexture(0.35, 0.55, 0.95, 0.16)
            r.time:Hide(); r.icon:Hide()
            r.arrow:Show(); r.arrow:SetText(self.histDateCollapsed[row.key] and "|cFFFFFFFF+|r" or "|cFFFFFFFF-|r")
            r.text:SetPoint("LEFT", r.arrow, "RIGHT", 3, 0); r.text:SetPoint("RIGHT", r, "RIGHT", -2, 0)
            r.text:SetText(row.label)
            r.text:SetTextColor(0.85, 0.88, 1.0)
        else
            local e = row.e
            r.dateKey = nil
            r:EnableMouse(true)
            r.arrow:Hide()
            local cr, cg, cb
            if e.cat then cr, cg, cb = self:CategoryColor(e.cat) end
            if not cr then cr, cg, cb = self:HistoryColor(e.kind) end
            local text, icon = self:ResolveHistoryEntry(e)
            r.bg:SetColorTexture(0, 0, 0, (ri % 2 == 0) and 0.28 or 0.12)
            r.time:Show(); r.time:SetText(date("%H:%M", e.t or time()))
            if icon then r.icon:SetTexture(icon); r.icon:Show() else r.icon:Hide() end
            r.text:SetPoint("LEFT", r.icon, "RIGHT", 5, 0); r.text:SetPoint("RIGHT", r, "RIGHT", -2, 0)
            r.text:SetText(text)
            r.text:SetTextColor(cr, cg, cb)
        end
        r:Show()
        y = y + 18
    end
    for i = #rows + 1, #self.histRows do self.histRows[i]:Hide() end
    self._histContentH = y
    local maxS = math.max(0, y - visible)
    if (self.histScroll or 0) > maxS then self.histScroll = maxS end
    if #rows == 0 then
        local r = self:_AcquireHistoryRow(1)
        r.dateKey = nil; r:EnableMouse(true)
        r.bg:SetColorTexture(0, 0, 0, 0.14)
        r.time:Hide(); r.arrow:Hide(); r.icon:Hide()
        r.text:ClearAllPoints(); r.text:SetPoint("LEFT", r, "LEFT", 4, 0); r.text:SetPoint("RIGHT", r, "RIGHT", -4, 0)
        r.text:SetText("Aucun historique")
        r.text:SetTextColor(0.7, 0.7, 0.7)
        r:ClearAllPoints(); r:SetPoint("TOPLEFT", self.history, "TOPLEFT", 4, -4); r:SetPoint("TOPRIGHT", self.history, "TOPRIGHT", -4, -4); r:Show()
    end
end

function M:CollapseOthers(collapse)
    -- DEC-026 : la réduction de bandeau a été retirée (plus de bouton ▶/▼). Réduire les
    -- autres modules les laisserait inaccessibles (surtout après /reload). No-op conservé
    -- pour la compatibilité d'appel — le sac garde sa propre ouverture/fermeture via B.
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

function M:IsReplacementEnabled()
    local cfg = SP:GetModuleConfig(self.name)
    return cfg and cfg.replaceBlizzardBags ~= false
end

function M:OpenBags(reason)
    local cfg = SP:GetModuleConfig(self.name)
    if not cfg then return end
    if not cfg.enabled then SP:EnableModule(self.name) end
    if reason ~= "internal" and CloseAllBags then pcall(CloseAllBags) end
    if SP.panel then SP.panel:Show() end
    cfg.collapsed = false
    self._forceReveal = true
    SP:UpdateCollapseVisual(self)
    if not InCombatLockdown() then self:SnapshotOnOpen() end
    SP:RebuildLayout()
    self:RequestRefresh()
end

function M:CloseBags()
    local cfg = SP:GetModuleConfig(self.name)
    if not cfg then return end
    cfg.collapsed = true
    self._forceReveal = false
    SP:UpdateCollapseVisual(self)
    SP:RebuildLayout()
end

function M:InstallBagHooks()
    if self._bagHooksInstalled or not hooksecurefunc then return end
    self._bagHooksInstalled = true
    local function replaceOpen()
        if not self._enabled or not self:IsReplacementEnabled() then return end
        self:OpenBags("hook")
    end
    local function replaceToggle()
        if not self._enabled or not self:IsReplacementEnabled() then return end
        self:ToggleBags()
    end
    for _, fn in ipairs({ "OpenAllBags", "OpenBackpack", "OpenBag" }) do
        if _G[fn] then pcall(hooksecurefunc, fn, replaceOpen) end
    end
    for _, fn in ipairs({ "ToggleAllBags", "ToggleBackpack", "ToggleBag" }) do
        if _G[fn] then pcall(hooksecurefunc, fn, replaceToggle) end
    end
end

function M:AutoSellJunk()
    local cfg = SP:GetModuleConfig(self.name)
    if not (cfg and cfg.autoSellJunk ~= false) then return end
    if InCombatLockdown() or not (MerchantFrame and MerchantFrame:IsShown()) then return end
    if not (C_Container and C_Container.GetContainerNumSlots and C_Container.UseContainerItem) then return end

    local sold, total = 0, 0
    for _, bag in ipairs(BAGS) do
        local n = Ct().GetContainerNumSlots(bag) or 0
        for slot = 1, n do
            local info = Ct().GetContainerItemInfo(bag, slot)
            if info and info.itemID and (info.quality or 1) == 0 and not info.isLocked then
                local ok, price = pcall(function() return select(11, GetItemInfo(info.hyperlink or info.itemID)) end)
                price = ok and tonumber(price) or 0
                if price and price > 0 then
                    total = total + price * (info.stackCount or 1)
                    sold = sold + 1
                    pcall(C_Container.UseContainerItem, bag, slot)
                end
            end
        end
    end
    if sold > 0 then
        C_Timer.After(0.4, function() self:RequestRefresh() end)
        if SP.Print then
            local money = GetMoneyString and GetMoneyString(total, true) or tostring(total)
            SP:Print(("Camelote vendue : %d pile(s), %s."):format(sold, money))
        end
    end
end

function M:ToggleBags()
    do
    if CloseAllBags then pcall(CloseAllBags) end
    local c = SP:GetModuleConfig(self.name)
    if c and c.collapsed then self:OpenBags("internal") else self:CloseBags() end
        return
    end
--[[
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
]]
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
function M:_AcquireCurrencyRow(i) local r = self.currencyRows[i] or CreateCurrencyRow(self, i); self.currencyRows[i] = r; return r end

function M:_CollectCurrencies()
    local rows = {}
    local cfg = SP:GetModuleConfig(self.name)
    local tracked = (cfg and cfg.trackedCurrencies) or {}
    local hidden = (cfg and cfg.hiddenCurrencies) or {}
    local money = GetMoney and GetMoney() or 0
    rows[#rows + 1] = {
        icon = "Interface\\MoneyFrame\\UI-GoldIcon",
        text = CompactNumber(math.floor(money / 10000)),
    }

    if C_CurrencyInfo and C_CurrencyInfo.GetCurrencyListSize then
        local n = C_CurrencyInfo.GetCurrencyListSize() or 0
        for i = 1, n do
            local ok, info = pcall(C_CurrencyInfo.GetCurrencyListInfo, i)
            local okLink, link = pcall(C_CurrencyInfo.GetCurrencyListLink, i)
            local id = okLink and link and tonumber(link:match("Hcurrency:(%d+)")) or nil
            if ok and info and not info.isHeader and id and not hidden[id] and (info.isShowInBackpack or info.isWatched or tracked[id]) then
                local qty = info.quantity or 0
                local text = CompactNumber(qty)
                rows[#rows + 1] = {
                    currencyID = id,
                    icon = info.iconFileID or "Interface\\Icons\\INV_Misc_QuestionMark",
                    text = text,
                }
            end
        end
    end

    return rows
end

function M:_CurrencyChoices()
    local rows = {}
    if not (C_CurrencyInfo and C_CurrencyInfo.GetCurrencyListSize and C_CurrencyInfo.GetCurrencyListInfo) then return rows end
    local n = C_CurrencyInfo.GetCurrencyListSize() or 0
    for i = 1, n do
        local ok, info = pcall(C_CurrencyInfo.GetCurrencyListInfo, i)
        if ok and info and not info.isHeader then
            local okLink, link = pcall(C_CurrencyInfo.GetCurrencyListLink, i)
            local id = okLink and link and tonumber(link:match("Hcurrency:(%d+)")) or nil
            if id and info.name and info.name ~= "" then
                rows[#rows + 1] = { id = id, name = info.name, icon = info.iconFileID or "Interface\\Icons\\INV_Misc_QuestionMark", quantity = info.quantity or 0, watched = info.isShowInBackpack or info.isWatched }
            end
        end
    end
    table.sort(rows, function(a, b) return (a.name or "") < (b.name or "") end)
    return rows
end

function M:ToggleCurrencyPicker(anchor)
    if self.currencyPicker and self.currencyPicker:IsShown() then self.currencyPicker:Hide(); return end
    local f = self.currencyPicker
    if not f then
        f = CreateFrame("Frame", "SpherePanelCurrencyPicker", UIParent)
        f:SetSize(260, 286)
        f:SetFrameStrata("DIALOG")
        f.bg = f:CreateTexture(nil, "BACKGROUND"); f.bg:SetAllPoints(f); f.bg:SetColorTexture(0.02, 0.025, 0.035, 0.96)
        f.line = f:CreateTexture(nil, "OVERLAY"); f.line:SetPoint("BOTTOMLEFT"); f.line:SetPoint("BOTTOMRIGHT"); f.line:SetHeight(1); f.line:SetColorTexture(0.29, 0.64, 1, 0.7)
        f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        f.title:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -8)
        f.title:SetText("Monnaies a afficher")
        f.close = CreateFrame("Button", nil, f)
        f.close:SetSize(18, 18); f.close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -6, -6)
        f.close.fs = f.close:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); f.close.fs:SetAllPoints(f.close); f.close.fs:SetText("x")
        f.close:SetScript("OnClick", function() f:Hide() end)
        f.rows = {}
        f.scroll = 0
        f.visibleRows = 10
        f:EnableMouseWheel(true)
        f:SetScript("OnMouseWheel", function(_, delta)
            f.scroll = math.max(0, math.min(math.max(0, #(f.choices or {}) - f.visibleRows), (f.scroll or 0) - delta))
            self:RefreshCurrencyPicker()
        end)
        self.currencyPicker = f
    end
    f:ClearAllPoints()
    if anchor then f:SetPoint("TOPRIGHT", anchor, "TOPLEFT", -8, 0) else f:SetPoint("CENTER", UIParent, "CENTER", 0, 0) end
    f.choices = self:_CurrencyChoices()
    f.scroll = 0
    f:Show()
    self:RefreshCurrencyPicker()
end

function M:RefreshCurrencyPicker()
    local f = self.currencyPicker
    if not f or not f:IsShown() then return end
    local cfg = SP:GetModuleConfig(self.name)
    cfg.trackedCurrencies = cfg.trackedCurrencies or {}
    cfg.hiddenCurrencies = cfg.hiddenCurrencies or {}
    local choices = f.choices or {}
    for i = 1, f.visibleRows do
        local row = f.rows[i]
        if not row then
            row = CreateFrame("Frame", nil, f)
            row:SetSize(240, 22)
            row:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -34 - (i - 1) * 24)
            row.bg = row:CreateTexture(nil, "BACKGROUND"); row.bg:SetAllPoints(row)
            row.check = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
            row.check:SetSize(20, 20); row.check:SetPoint("LEFT", row, "LEFT", -2, 0)
            row.icon = row:CreateTexture(nil, "ARTWORK"); row.icon:SetSize(16, 16); row.icon:SetPoint("LEFT", row.check, "RIGHT", 2, 0); row.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
            row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            row.text:SetPoint("LEFT", row.icon, "RIGHT", 6, 0); row.text:SetPoint("RIGHT", row, "RIGHT", -4, 0); row.text:SetJustifyH("LEFT")
            f.rows[i] = row
        end
        local choice = choices[(f.scroll or 0) + i]
        if choice then
            row.choice = choice
            row.bg:SetColorTexture(1, 1, 1, (i % 2 == 0) and 0.05 or 0.02)
            row.icon:SetTexture(choice.icon)
            row.text:SetText(("%s  |cFF888888%d|r"):format(choice.name, choice.quantity or 0))
            row.check:SetChecked((choice.watched or cfg.trackedCurrencies[choice.id]) and not cfg.hiddenCurrencies[choice.id])
            row.check:SetScript("OnClick", function(s)
                if s:GetChecked() then
                    cfg.trackedCurrencies[choice.id] = true
                    cfg.hiddenCurrencies[choice.id] = nil
                else
                    cfg.trackedCurrencies[choice.id] = nil
                    cfg.hiddenCurrencies[choice.id] = true
                end
                self:RequestRefresh()
            end)
            row:Show()
        else
            row.choice = nil
            row:Hide()
        end
    end
end

function M:Refresh()
    if not self._enabled or not self.body or not C_Container then return end
    if InCombatLockdown() then self._dirty = true; return end
    self._dirty = false

    local cfg = SP:GetModuleConfig(self.name)
    if cfg.activeTab == "history" then self:RefreshHistory(); return end
    local mode = cfg.displayMode or "categorized"
    if mode ~= "onebag" and mode ~= "split" then mode = "categorized" end
    local cats = cfg.categories or {}
    local enabledSet = {}
    for _, c in ipairs(cats) do if c.enabled then enabledSet[c.key] = true end end

    local buckets, allSlots, byBag, bagStats, total, free = {}, {}, {}, {}, 0, 0
    for _, c in ipairs(cats) do buckets[c.key] = {} end
    for _, bag in ipairs(BAGS) do
        local bagItems, bagFree = {}, 0
        byBag[bag] = bagItems
        local n = Ct().GetContainerNumSlots(bag) or 0
        total = total + n
        for slot = 1, n do
            local info = Ct().GetContainerItemInfo(bag, slot)
            local entry = { bag = bag, slot = slot, info = info }
            bagItems[#bagItems + 1] = entry
            allSlots[#allSlots + 1] = entry
            if info and info.itemID then
                local key = self:CategoryForItem(info, cats, enabledSet)
                if not buckets[key] then key = "misc"; buckets[key] = buckets[key] or {} end
                buckets[key][#buckets[key] + 1] = entry
            else
                free = free + 1
                bagFree = bagFree + 1
            end
        end
        bagStats[bag] = { total = n, free = bagFree }
    end

    local size = BagCfg("bag_icon_size", 30)
    local greyJunk = BagCfg("icon_grey_junk", true)
    local w = self.list:GetWidth(); if not w or w < 1 then w = (SP.db.panel.width or 280) - 4 end
    local perRow = math.max(1, math.floor((w + GAP) / (size + GAP)))
    local si, hi, subi, y = 0, 0, 0, 2
    local visibleH = self.list:GetHeight() or 1
    self.bagScroll = math.min(math.max(0, ((self._bagContentH or 0) - visibleH)), math.max(0, self.bagScroll or 0))
    local scroll = self.bagScroll or 0
    local function Y(v) return -(v - scroll) end

    local function placeItem(it, col, rowN, baseY)
        si = si + 1
        local b = self:_AcquireSlot(si)
        b:SetSize(size, size); b:ClearAllPoints()
        b:SetPoint("TOPLEFT", self.list, "TOPLEFT", col * (size + GAP), Y(baseY + rowN * (size + GAP)))
        b.bag, b.slot = it.bag, it.slot
        -- épaisseur de bordure configurable = inset de l'icône (la bordure = fond visible)
        local bth = cfg.iconBorderThickness or 2
        if b._bth ~= bth then
            b._bth = bth
            b.icon:ClearAllPoints()
            b.icon:SetPoint("TOPLEFT", b, "TOPLEFT", bth, -bth)
            b.icon:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -bth, bth)
        end
        if not (it.info and it.info.itemID) then
            b._baseDesat, b._baseAlpha = false, 1
            b.icon:SetTexture(nil)
            b.icon:SetDesaturated(false)
            b.icon:SetAlpha(1)
            b.border:SetColorTexture(0.18, 0.18, 0.18, 0.65)
            b.count:SetText(it.emptyCount and tostring(it.emptyCount) or "")
            b.ilvl:SetText("")
            b.upg:Hide()
            pcall(function() b:SetAttribute("type2", nil); b:SetAttribute("item2", nil); b:SetAttribute("bag", nil); b:SetAttribute("slot", nil) end)
            b:Show()
            return
        end
        b.icon:SetTexture(it.info.iconFileID)
        local q = it.info.quality or 1
        b._baseAlpha = it.info.isLocked and 0.35 or 1
        b._baseDesat = (q == 0) and greyJunk or false
        b.icon:SetAlpha(b._baseAlpha)   -- "en déplacement" pendant le drag
        b.icon:SetDesaturated(b._baseDesat)
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
        pcall(function()
            b:SetAttribute("type1", nil)
            b:SetAttribute("type2", nil)
            b:SetAttribute("item2", nil)
            b:SetAttribute("bag", it.bag)
            b:SetAttribute("slot", it.slot)
        end)
        b:Show()
    end

    local function grid(items, baseY)
        for j, it in ipairs(items) do
            placeItem(it, (j - 1) % perRow, math.floor((j - 1) / perRow), baseY)
        end
        return math.ceil(#items / perRow) * (size + GAP)
    end

    local currencyShown = 0
    if cfg.showCurrencies ~= false then
        local currencies = self:_CollectCurrencies()
        if #currencies > 0 then
            hi = hi + 1
            local hdr = self:_AcquireHeader(hi)
            hdr.arrow:SetText("")
            hdr.fs:SetText(("Monnaies  |cFF888888%d|r"):format(#currencies))
            hdr.fs:SetTextColor(1, 0.82, 0)
            hdr:ClearAllPoints()
            hdr:SetPoint("TOPLEFT", self.list, "TOPLEFT", 0, Y(y))
            hdr:SetPoint("TOPRIGHT", self.list, "TOPRIGHT", 0, Y(y))
            hdr:SetScript("OnClick", function(_, button)
                if button == "RightButton" then self:ToggleCurrencyPicker(hdr) end
            end)
            hdr:Show()
            y = y + HDR_H + 1

            local pillW = 58
            local curPerRow = math.max(1, math.floor((w + GAP) / (pillW + GAP)))
            pillW = math.max(44, math.floor((w - (curPerRow - 1) * GAP) / curPerRow))
            for idx, cur in ipairs(currencies) do
                currencyShown = currencyShown + 1
                local r = self:_AcquireCurrencyRow(currencyShown)
                r.currencyID = cur.currencyID
                r.icon:SetTexture(cur.icon)
                r.fs:SetText(cur.text)
                r:ClearAllPoints()
                r:SetSize(pillW, CURRENCY_ROW)
                local col = (idx - 1) % curPerRow
                local rowN = math.floor((idx - 1) / curPerRow)
                r:SetPoint("TOPLEFT", self.list, "TOPLEFT", col * (pillW + GAP), Y(y + rowN * (CURRENCY_ROW + GAP)))
                r:Show()
            end
            y = y + math.ceil(#currencies / curPerRow) * (CURRENCY_ROW + GAP)
            y = y + 3
        end
    end

    if mode == "onebag" then
        y = y + grid(allSlots, y) + 2
    elseif mode == "split" then
        for _, bag in ipairs(BAGS) do
            local items = byBag[bag] or {}
            if #items > 0 then
                hi = hi + 1
                local hdr = self:_AcquireHeader(hi)
                local stats = bagStats[bag] or { total = #items, free = 0 }
                local label = (bag == 0) and "Sac a dos" or ("Sac " .. bag)
                hdr.arrow:SetText("")
                hdr.fs:SetText(("%s  |cFF888888%d / %d|r"):format(label, stats.free or 0, stats.total or #items))
                hdr.fs:SetTextColor(1, 0.82, 0)
                hdr:ClearAllPoints()
                hdr:SetPoint("TOPLEFT", self.list, "TOPLEFT", 0, Y(y))
                hdr:SetPoint("TOPRIGHT", self.list, "TOPRIGHT", 0, Y(y))
                hdr:SetScript("OnClick", nil)
                hdr:Show()
                y = y + HDR_H + 1
                y = y + grid(items, y) + 2
            end
        end
    else
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
                hdr:SetPoint("TOPLEFT", self.list, "TOPLEFT", 0, Y(y))
                hdr:SetPoint("TOPRIGHT", self.list, "TOPRIGHT", 0, Y(y))
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
                        b:SetSize(size, size); b:ClearAllPoints(); b:SetPoint("TOPLEFT", self.list, "TOPLEFT", 0, Y(y))
                        b.icon:SetTexture(nil); b.icon:SetDesaturated(false); b.border:SetColorTexture(0.2, 0.2, 0.2, 1)
                        b.count:SetText(tostring(free)); b.ilvl:SetText(""); b.upg:Hide()
                        pcall(function() b:SetAttribute("type2", nil); b:SetAttribute("item2", nil); b:SetAttribute("bag", nil); b:SetAttribute("slot", nil) end)
                        b:Show()
                        y = y + size + GAP
                    elseif c.group then
                        -- groupées par sous-type MAIS en UNE grille continue (compact, zéro ligne
                        -- perdue) : on trie par sous-type pour garder les mêmes types adjacents.
                        local sorted = {}
                        for _, it in ipairs(items) do sorted[#sorted + 1] = it end
                        table.sort(sorted, function(p, q)
                            local gp = GroupLabel(p.info, c) or ""
                            local gq = GroupLabel(q.info, c) or ""
                            if gp ~= gq then return gp < gq end
                            return (p.info.itemID or 0) < (q.info.itemID or 0)
                        end)
                        y = y + grid(sorted, y)
                        y = y + 2
                    else
                        y = y + grid(items, y)
                        y = y + 2
                    end
                end
            end
        end
    end
    end

    for i = si + 1, #self.slots do self.slots[i]:Hide() end
    for i = hi + 1, #self.headers do self.headers[i]:Hide() end
    for i = subi + 1, #self.subs do self.subs[i]:Hide() end
    for i = currencyShown + 1, #self.currencyRows do self.currencyRows[i]:Hide() end

    SP:SetModuleHeaderText(self, ("%d / %d"):format(free, total))
    local needed = math.max(HDR_H, y)
    self._bagContentH = needed
    local maxS = math.max(0, needed - (self.list:GetHeight() or 1))
    if (self.bagScroll or 0) > maxS then self.bagScroll = maxS end
    SP:SetAutoHeight(self, math.min(needed, cfg.maxAutoHeight or 320))
end

SP:RegisterModule(M)
