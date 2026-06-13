-- ============================================================
-- Module : Character ("Personnage") — remplace la feuille de perso (C)
-- ============================================================
-- Onglet ÉQUIPEMENT : modèle 3D + récap + 16 emplacements (icône, iLvl coloré,
--   alerte enchantement manquant / châsse vide).
-- Onglet STATS : attributs, secondaires, tertiaires, défenses.
-- MOLETTE sur le bandeau (ou clic sur les onglets) = bascule Équipement/Stats.
-- Option : remplacer la touche C par ce module (feuille Blizzard accessible via bouton).
local ADDON_NAME, SP = ...

local M = { name = "Character", label = "Personnage", defaultHeight = 300 }

local ROW = 18

-- Emplacements (nom de slot Blizzard -> libellé FR)
local SLOTS = {
    { "HEADSLOT", "Tête" },        { "NECKSLOT", "Cou" },         { "SHOULDERSLOT", "Épaules" },
    { "BACKSLOT", "Dos" },         { "CHESTSLOT", "Torse" },      { "WRISTSLOT", "Poignets" },
    { "HANDSSLOT", "Mains" },      { "WAISTSLOT", "Taille" },     { "LEGSSLOT", "Jambes" },
    { "FEETSLOT", "Pieds" },       { "FINGER0SLOT", "Anneau 1" }, { "FINGER1SLOT", "Anneau 2" },
    { "TRINKET0SLOT", "Bijou 1" }, { "TRINKET1SLOT", "Bijou 2" }, { "MAINHANDSLOT", "Arme princ." },
    { "SECONDARYHANDSLOT", "Arme sec." },
}

-- Slots qui DOIVENT porter un enchantement (set conservateur Midnight)
local ENCHANTABLE = {
    CHESTSLOT = true, WRISTSLOT = true, LEGSSLOT = true, FEETSLOT = true, BACKSLOT = true,
    FINGER0SLOT = true, FINGER1SLOT = true, MAINHANDSLOT = true, SECONDARYHANDSLOT = true,
}

-- Chaînes "châsse vide" connues (certaines peuvent être nil selon le client)
local EMPTY_SOCKETS = {}
for _, s in ipairs({
    "EMPTY_SOCKET_PRISMATIC", "EMPTY_SOCKET_RED", "EMPTY_SOCKET_BLUE", "EMPTY_SOCKET_YELLOW",
    "EMPTY_SOCKET_META", "EMPTY_SOCKET_COGWHEEL", "EMPTY_SOCKET_HYDRAULIC", "EMPTY_SOCKET_DOMINATION",
    "EMPTY_SOCKET_CYPHER", "EMPTY_SOCKET_TINKER", "EMPTY_SOCKET_PRIMORDIAL",
    "EMPTY_SOCKET_SINGINGTHUNDER", "EMPTY_SOCKET_SINGINGSEA", "EMPTY_SOCKET_SINGINGWIND",
}) do
    if _G[s] then EMPTY_SOCKETS[#EMPTY_SOCKETS + 1] = _G[s] end
end

-- enchant (champ 3 du lien item) ; renvoie enchantID (0 = aucun)
local function GetEnchant(itemLink)
    if not itemLink then return 0 end
    local parts = { strsplit(":", itemLink) }
    return tonumber(parts[3]) or 0
end

-- nombre de châsses vides via C_TooltipInfo (12.x-safe, pas de scan tainté)
local function CountEmptySockets(slotId)
    if not (C_TooltipInfo and C_TooltipInfo.GetInventoryItem) then return 0 end
    local data = C_TooltipInfo.GetInventoryItem("player", slotId)
    if not data then return 0 end
    if TooltipUtil and TooltipUtil.SurfaceArgs then pcall(TooltipUtil.SurfaceArgs, data) end
    local n = 0
    for _, line in ipairs(data.lines or {}) do
        if TooltipUtil and TooltipUtil.SurfaceArgs then pcall(TooltipUtil.SurfaceArgs, line) end
        local t = line.leftText
        if t then
            for _, empty in ipairs(EMPTY_SOCKETS) do
                if t:find(empty, 1, true) then n = n + 1; break end
            end
        end
    end
    return n
end

-- ============================================================
function M:Init(body)
    self.body = body
    self.tab = "gear"
    self.rows = {}
    self.statLines = {}

    -- onglets sur le bandeau (à gauche du cadenas), façon module Auras
    if self.header then
        self.tabBtns = {}
        local anchor = self.lock or self.header
        local prev
        for _, d in ipairs({ { "stats", "Stats" }, { "gear", "Équip." } }) do
            local b = CreateFrame("Button", nil, self.header)
            b:SetSize(46, 16)
            if prev then b:SetPoint("RIGHT", prev, "LEFT", -4, 0)
            else b:SetPoint("RIGHT", anchor, "LEFT", -6, 0) end
            b.fs = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            b.fs:SetAllPoints(b); b.fs:SetText(d[2])
            b.hl = b:CreateTexture(nil, "BACKGROUND"); b.hl:SetAllPoints(b)
            b.hl:SetColorTexture(0.30, 0.55, 0.95, 0.30); b.hl:Hide()
            b.tab = d[1]
            b:SetScript("OnClick", function(s) self:SetTab(s.tab) end)
            self.tabBtns[d[1]] = b
            prev = b
        end
        -- molette sur le bandeau = bascule d'onglet
        self.header:EnableMouseWheel(true)
        self.header:SetScript("OnMouseWheel", function()
            self:SetTab(self.tab == "gear" and "stats" or "gear")
        end)
    end

    -- ===== conteneur ÉQUIPEMENT =====
    self.gear = CreateFrame("Frame", nil, body)
    self.gear:SetPoint("TOPLEFT", body, "TOPLEFT", 2, -2)
    self.gear:SetPoint("TOPRIGHT", body, "TOPRIGHT", -2, 0)
    self.gear:SetHeight(1)

    self.model = CreateFrame("PlayerModel", nil, self.gear)
    self.model:SetSize(82, 108)
    self.model:SetPoint("TOPLEFT", self.gear, "TOPLEFT", 2, -2)
    pcall(self.model.SetUnit, self.model, "player")

    self.summary = self.gear:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    self.summary:SetPoint("TOPLEFT", self.model, "TOPRIGHT", 8, -4)
    self.summary:SetPoint("RIGHT", self.gear, "RIGHT", -4, 0)
    self.summary:SetJustifyH("LEFT"); self.summary:SetJustifyV("TOP")

    self.charBtn = CreateFrame("Button", nil, self.gear, "UIPanelButtonTemplate")
    self.charBtn:SetSize(120, 18)
    self.charBtn:SetPoint("TOPLEFT", self.model, "BOTTOMRIGHT", 8, -2)
    self.charBtn:SetText("Feuille Blizzard")
    self.charBtn:SetScript("OnClick", function()
        if ToggleCharacter then pcall(ToggleCharacter, "PaperDollFrame") end
    end)

    -- ===== conteneur STATS =====
    self.stats = CreateFrame("Frame", nil, body)
    self.stats:SetPoint("TOPLEFT", body, "TOPLEFT", 4, -2)
    self.stats:SetPoint("TOPRIGHT", body, "TOPRIGHT", -4, 0)
    self.stats:SetHeight(1)
    self.stats:Hide()

    self.ev = CreateFrame("Frame")
    self.ev:SetScript("OnEvent", function(_, e)
        if e == "PLAYER_REGEN_ENABLED" then self:ApplyKeyOverride() end
        self:RequestRefresh()
    end)
end

function M:_GearRow(i)
    local r = self.rows[i]
    if not r then
        r = CreateFrame("Button", nil, self.gear)
        r:SetHeight(ROW)
        r.icon = r:CreateTexture(nil, "ARTWORK"); r.icon:SetSize(ROW - 2, ROW - 2)
        r.icon:SetPoint("LEFT", r, "LEFT", 2, 0); r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        r.border = r:CreateTexture(nil, "BACKGROUND")
        r.border:SetPoint("TOPLEFT", r.icon, "TOPLEFT", -1, 1); r.border:SetPoint("BOTTOMRIGHT", r.icon, "BOTTOMRIGHT", 1, -1)
        r.slot = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        r.slot:SetPoint("LEFT", r.icon, "RIGHT", 5, 0); r.slot:SetJustifyH("LEFT")
        r.right = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        r.right:SetPoint("RIGHT", r, "RIGHT", -2, 0); r.right:SetJustifyH("RIGHT")
        local hl = r:CreateTexture(nil, "HIGHLIGHT"); hl:SetAllPoints(r); hl:SetColorTexture(1, 1, 1, 0.07)
        r:SetScript("OnEnter", function(s)
            if s.slotId then GameTooltip:SetOwner(s, "ANCHOR_LEFT"); pcall(GameTooltip.SetInventoryItem, GameTooltip, "player", s.slotId); GameTooltip:Show() end
        end)
        r:SetScript("OnLeave", function() GameTooltip:Hide() end)
        r:SetScript("OnClick", function(s)
            -- clic = ouvre le gestionnaire d'enchantement/châsse via la feuille Blizzard
            if ToggleCharacter then pcall(ToggleCharacter, "PaperDollFrame") end
        end)
        self.rows[i] = r
    end
    return r
end

function M:_StatLine(i)
    local fs = self.statLines[i]
    if not fs then
        fs = self.stats:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        fs:SetJustifyH("LEFT")
        self.statLines[i] = fs
    end
    return fs
end

function M:SetTab(tab)
    self.tab = tab
    if self.tabBtns then
        for k, b in pairs(self.tabBtns) do b.hl:SetShown(k == tab) end
    end
    self.gear:SetShown(tab == "gear")
    self.stats:SetShown(tab == "stats")
    SP:SetModuleHeaderText(self, tab == "gear" and "|cFF888888Équipement|r" or "|cFF888888Stats|r")
    self:Refresh()
end

function M:Enable()
    self._enabled = true
    if self._placeholder then self._placeholder:Hide() end
    for _, e in ipairs({ "PLAYER_EQUIPMENT_CHANGED", "UNIT_INVENTORY_CHANGED", "COMBAT_RATING_UPDATE",
                         "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED" }) do
        pcall(self.ev.RegisterEvent, self.ev, e)
    end
    self:ApplyKeyOverride()
    self:SetTab(self.tab or "gear")
end

function M:Disable()
    self._enabled = false
    if self.ev then self.ev:UnregisterAllEvents() end
    if self._keyBtn and not InCombatLockdown() then ClearOverrideBindings(self._keyBtn) end
    for _, r in ipairs(self.rows) do r:Hide() end
    SP:SetModuleHeaderText(self, "")
end

function M:OnResize(w, h) self:RequestRefresh() end

function M:RequestRefresh()
    if not self._enabled or self._pending then return end
    self._pending = true
    C_Timer.After(0.2, function() self._pending = false; self:Refresh() end)
end

-- ===== touche C → ce module (option) =====
function M:ToggleSelf()
    local cfg = SP:GetModuleConfig(self.name)
    if not cfg.enabled then SP:EnableModule(self.name) end
    if SP.panel then SP.panel:Show() end
    cfg.collapsed = not cfg.collapsed
    self._forceReveal = not cfg.collapsed
    SP:UpdateCollapseVisual(self)
    SP:RebuildLayout()
    if not cfg.collapsed then self:RequestRefresh() end
end

function M:ApplyKeyOverride()
    if InCombatLockdown() then return end
    local cfg = SP:GetModuleConfig(self.name)
    if not self._keyBtn then
        self._keyBtn = CreateFrame("Button", "SpherePanelCharKey", UIParent)
        self._keyBtn:SetScript("OnClick", function() self:ToggleSelf() end)
    end
    ClearOverrideBindings(self._keyBtn)
    if cfg.replaceCharSheet then
        local k1, k2 = GetBindingKey("TOGGLECHARACTER0")
        if k1 then SetOverrideBindingClick(self._keyBtn, true, k1, "SpherePanelCharKey") end
        if k2 then SetOverrideBindingClick(self._keyBtn, true, k2, "SpherePanelCharKey") end
    end
end

-- ============================================================
function M:Refresh()
    if not self._enabled then return end
    if self.tab == "stats" then self:RefreshStats() else self:RefreshGear() end
end

function M:RefreshGear()
    local y = 116   -- sous le modèle 3D
    local missEnch, emptySock = 0, 0

    for i, d in ipairs(SLOTS) do
        local slotName, label = d[1], d[2]
        local slotId = GetInventorySlotInfo and select(1, GetInventorySlotInfo(slotName))
        local r = self:_GearRow(i)
        r.slotId = slotId
        r.slot:SetText(label)
        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", self.gear, "TOPLEFT", 2, -y)
        r:SetPoint("RIGHT", self.gear, "RIGHT", -2, 0)

        local link = slotId and GetInventoryItemLink("player", slotId)
        if link then
            local tex = GetInventoryItemTexture("player", slotId)
            r.icon:SetTexture(tex or "Interface\\Icons\\INV_Misc_QuestionMark")
            local q = GetInventoryItemQuality("player", slotId) or 1
            local qc = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q]
            if qc then r.border:SetColorTexture(qc.r, qc.g, qc.b, 1) else r.border:SetColorTexture(0.3, 0.3, 0.3, 1) end
            local ilvl = GetDetailedItemLevelInfo(link) or 0
            local hex = qc and qc.hex or "|cFFFFFFFF"
            local warn = ""
            if ENCHANTABLE[slotName] and GetEnchant(link) == 0 then warn = warn .. " |cFFFF4040Ench✗|r"; missEnch = missEnch + 1 end
            local sock = CountEmptySockets(slotId)
            if sock > 0 then warn = warn .. (" |cFFFF4040◆%d|r"):format(sock); emptySock = emptySock + sock end
            r.right:SetText(("%s%d|r%s"):format(hex, ilvl, warn))
        else
            r.icon:SetTexture("Interface\\PaperDoll\\UI-Backpack-EmptySlot")
            r.border:SetColorTexture(0.5, 0.1, 0.1, 1)
            r.right:SetText("|cFFFF4040vide|r")
        end
        r:Show()
        y = y + ROW
    end
    for i = #SLOTS + 1, #self.rows do self.rows[i]:Hide() end

    -- récap à côté du modèle
    local overall, equipped = GetAverageItemLevel()
    local parts = {
        ("|cFFFFD200iLvl|r %.0f |cFF888888(équipé %.0f)|r"):format(overall or 0, equipped or overall or 0),
    }
    parts[#parts + 1] = (missEnch > 0) and ("|cFFFF4040%d ench. manquant(s)|r"):format(missEnch) or "|cFF40FF40Enchant. OK|r"
    parts[#parts + 1] = (emptySock > 0) and ("|cFFFF4040%d châsse(s) vide(s)|r"):format(emptySock) or "|cFF40FF40Châsses OK|r"
    self.summary:SetText(table.concat(parts, "\n"))

    self.gear:SetHeight(y)
    SP:SetAutoHeight(self, y + 4)
end

local function pct(v) return v and ("%.2f%%"):format(v) or "—" end

function M:RefreshStats()
    local L = {}
    local function add(label, val, color)
        L[#L + 1] = ("|cFF%s%s|r  |cFFFFFFFF%s|r"):format(color or "FFD200", label, tostring(val))
    end

    local overall, equipped = GetAverageItemLevel()
    add("Niveau d'objet", ("%.1f (équipé %.1f)"):format(overall or 0, equipped or 0))

    -- attribut principal (le plus haut de Force/Agi/Intel) + Endurance
    local names = { "Force", "Agilité", "Endurance", "Intelligence" }
    local _, str = UnitStat("player", 1)
    local _, agi = UnitStat("player", 2)
    local _, sta = UnitStat("player", 3)
    local _, int = UnitStat("player", 4)
    local primaryIdx, primaryVal = 1, str
    if agi > primaryVal then primaryIdx, primaryVal = 2, agi end
    if int > primaryVal then primaryIdx, primaryVal = 4, int end
    add(names[primaryIdx], primaryVal, "4AA3FF")
    add("Endurance", sta, "4AA3FF")

    L[#L + 1] = "|cFF888888— Secondaires —|r"
    add("Critique", pct(GetCritChance and GetCritChance()))
    add("Hâte", pct(GetHaste and GetHaste()))
    add("Maîtrise", pct(GetMasteryEffect and GetMasteryEffect()))
    local vers = 0
    if GetCombatRatingBonus and CR_VERSATILITY_DAMAGE_DONE then
        vers = (GetCombatRatingBonus(CR_VERSATILITY_DAMAGE_DONE) or 0)
            + (GetVersatilityBonus and GetVersatilityBonus(CR_VERSATILITY_DAMAGE_DONE) or 0)
    end
    add("Polyvalence", pct(vers))

    -- tertiaires (affichés seulement si > 0)
    local tert = {}
    local function tadd(label, v) if v and v > 0 then tert[#tert + 1] = { label, v } end end
    tadd("Vol de vie", GetLifesteal and GetLifesteal())
    tadd("Évitement", GetAvoidance and GetAvoidance())
    tadd("Vélocité", GetSpeed and GetSpeed())
    if #tert > 0 then
        L[#L + 1] = "|cFF888888— Tertiaires —|r"
        for _, t in ipairs(tert) do add(t[1], pct(t[2])) end
    end

    L[#L + 1] = "|cFF888888— Défenses —|r"
    local _, armor = UnitArmor("player")
    add("Armure", armor or 0)
    local dodge = GetDodgeChance and GetDodgeChance()
    local parry = GetParryChance and GetParryChance()
    local block = GetBlockChance and GetBlockChance()
    if dodge and dodge > 0 then add("Esquive", pct(dodge)) end
    if parry and parry > 0 then add("Parade", pct(parry)) end
    if block and block > 0 then add("Blocage", pct(block)) end

    local y = 4
    for i, txt in ipairs(L) do
        local fs = self:_StatLine(i)
        fs:ClearAllPoints()
        fs:SetPoint("TOPLEFT", self.stats, "TOPLEFT", 4, -y)
        fs:SetPoint("RIGHT", self.stats, "RIGHT", -4, 0)
        fs:SetText(txt)
        fs:Show()
        y = y + 16
    end
    for i = #L + 1, #self.statLines do self.statLines[i]:Hide() end

    self.stats:SetHeight(y)
    SP:SetAutoHeight(self, y + 4)
end

SP:RegisterModule(M)
