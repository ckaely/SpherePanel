-- ============================================================
-- Module : Character ("Personnage") — feuille de perso premium (remplace C)
-- ============================================================
-- Onglet ÉQUIPEMENT : résumé global (iLvl/enchants/gemmes/slots optimisés, code couleur)
--   + 16 lignes enrichies. Chaque ligne = case PaperDoll (drag pour équiper, highlight
--   des slots compatibles quand un objet est sur le curseur) + nom, iLvl coloré,
--   upgrade track, enchant (atlas+nom ou « ✗ »), gemmes (vraies icônes ou « ✗ »).
-- Onglet STATS : sections PRIMAIRES / SECONDAIRES / TERTIAIRES / DÉFENSE,
--   couleurs intelligentes (relatives) + tooltips enrichis (%, rating, impact).
-- Détection via Enum.TooltipDataLineType (méthode AlterEgo, robuste/multilingue).
-- MOLETTE sur le bandeau (ou clic onglets) = bascule. Touche C = ce module (option).
local ADDON_NAME, SP = ...

local M = { name = "Character", label = "Personnage", defaultHeight = 300 }

local CELL = 28    -- taille d'une case d'équipement (plus petite)
local CELL_H = 34  -- hauteur de rangée colonne (espacée)

-- libellé FR + "peut être enchanté" (gate l'alerte « ✗ enchant »)
local LABEL = {
    HEADSLOT = "Tête", NECKSLOT = "Cou", SHOULDERSLOT = "Épaules", BACKSLOT = "Cape",
    CHESTSLOT = "Torse", WRISTSLOT = "Poignets", HANDSSLOT = "Mains", WAISTSLOT = "Ceinture",
    LEGSSLOT = "Jambes", FEETSLOT = "Pieds", FINGER0SLOT = "Anneau 1", FINGER1SLOT = "Anneau 2",
    TRINKET0SLOT = "Bijou 1", TRINKET1SLOT = "Bijou 2", MAINHANDSLOT = "Arme princ.", SECONDARYHANDSLOT = "Arme sec.",
}
local CANENCH = {
    CHESTSLOT = true, WRISTSLOT = true, LEGSSLOT = true, FEETSLOT = true, BACKSLOT = true,
    FINGER0SLOT = true, FINGER1SLOT = true, MAINHANDSLOT = true, SECONDARYHANDSLOT = true,
    HEADSLOT = true, SHOULDERSLOT = true,
}
-- disposition en ZIGZAG (schéma utilisateur) : UN seul item par ligne, alternance gauche/droite.
-- L'item de droite est décalé d'une ligne sous celui de gauche → les textes ne se touchent jamais.
local COLUMN = {
    { "HEADSLOT", "L" },   { "HANDSSLOT", "R" },
    { "SHOULDERSLOT", "L" }, { "WRISTSLOT", "R" },
    { "CHESTSLOT", "L" },  { "WAISTSLOT", "R" },
    { "LEGSSLOT", "L" },   { "FEETSLOT", "R" },
}
-- rangée du bas : paires regroupées en colonnes de 2 (armes / collier+cape / bagues / bijoux / chemise+tabard)
local BOTTOM_PAIRS = {
    { "MAINHANDSLOT", "SECONDARYHANDSLOT" }, -- armes
    { "NECKSLOT", "BACKSLOT" },              -- collier / cape
    { "FINGER0SLOT", "FINGER1SLOT" },        -- bagues
    { "TRINKET0SLOT", "TRINKET1SLOT" },      -- bijoux
    { "SHIRTSLOT", "TABARDSLOT" },           -- chemise / tabard
}

local ENCH_TYPE = Enum and Enum.TooltipDataLineType and Enum.TooltipDataLineType.ItemEnchantmentPermanent
local GEM_TYPE  = Enum and Enum.TooltipDataLineType and Enum.TooltipDataLineType.GemSocket
local UP_PAT
do
    local s = _G.ITEM_UPGRADE_TOOLTIP_FORMAT_STRING
    if s then UP_PAT = s:gsub("%%d", "%%s"):format("(.+)", "(%d+)", "(%d+)") end
end

-- ============================================================
-- Audit d'un emplacement (iLvl, upgrade, enchant, gemmes) — méthode tooltip structurée.
local function AuditSlot(slotId)
    local a = { has = false, sockets = 0, gemsFilled = 0, gemIcons = {} }
    local link = slotId and GetInventoryItemLink("player", slotId)
    if not link then return a end
    a.has, a.link = true, link
    a.quality = GetInventoryItemQuality("player", slotId) or 1
    a.icon = GetInventoryItemTexture("player", slotId)
    a.ilvl = GetDetailedItemLevelInfo(link) or 0
    a.name = (link:match("%[(.-)%]")) or (C_Item.GetItemInfo and select(1, C_Item.GetItemInfo(link))) or "?"

    local data = C_TooltipInfo and C_TooltipInfo.GetInventoryItem and C_TooltipInfo.GetInventoryItem("player", slotId)
    if data then
        if TooltipUtil and TooltipUtil.SurfaceArgs then pcall(TooltipUtil.SurfaceArgs, data) end
        for _, line in ipairs(data.lines or {}) do
            if TooltipUtil and TooltipUtil.SurfaceArgs then pcall(TooltipUtil.SurfaceArgs, line) end
            local lt = line.leftText
            if UP_PAT and lt and not a.upTrack then
                local m1, _, track, lvl, mx = lt:find(UP_PAT)
                if m1 then a.upTrack, a.upLevel, a.upMax = track, tonumber(lvl), tonumber(mx) end
            end
            if ENCH_TYPE and line.type == ENCH_TYPE then
                a.enchanted = true
                a.enchantText = lt
                -- nom court : retire le préfixe "Enchanté : " et un éventuel atlas
                local short = lt:gsub("|A:.-|a", "")
                -- garde UNIQUEMENT le nom : retire tout préfixe "Xxx : " (Enchantement d'arme/de cape/Enchanté…)
                local afterColon = short:match(".*[:：]%s*(.+)$")
                if afterColon then short = afterColon end
                a.enchShort = short:gsub("^%s+", ""):gsub("%s+$", "")
            end
            if GEM_TYPE and line.type == GEM_TYPE then
                a.sockets = a.sockets + 1
                if line.gemIcon then
                    a.gemsFilled = a.gemsFilled + 1
                    a.gemIcons[#a.gemIcons + 1] = line.gemIcon
                else
                    a.gemIcons[#a.gemIcons + 1] = false
                end
            end
        end
    end
    return a
end

-- ============================================================
function M:Init(body)
    self.body = body
    self.tab = "gear"
    self.rows = {}
    self.slotBtns = {}
    self.statLines = {}

    -- onglets sur le bandeau (à gauche du cadenas) — sans chevaucher le suffixe
    if self.header then
        if self.suffixFS then self.suffixFS:Hide() end   -- évite la collision constatée
        self.tabBtns = {}
        local anchor = self.lock or self.header
        local prev
        for _, d in ipairs({ { "alts", "Alters" }, { "stats", "Stats" }, { "gear", "Équip." } }) do
            local b = CreateFrame("Button", nil, self.header)
            b:SetSize(42, 16)
            if prev then b:SetPoint("RIGHT", prev, "LEFT", -3, 0)
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
        self.header:EnableMouseWheel(true)
        local CYCLE = { "gear", "stats", "alts" }
        self.header:SetScript("OnMouseWheel", function(_, delta)
            local idx = 1
            for i, t in ipairs(CYCLE) do if t == self.tab then idx = i break end end
            idx = ((idx - 1 - delta) % #CYCLE) + 1
            self:SetTab(CYCLE[idx])
        end)
    end

    -- ===== conteneur ÉQUIPEMENT =====
    self.gear = CreateFrame("Frame", nil, body)
    self.gear:SetPoint("TOPLEFT", body, "TOPLEFT", 2, -2)
    self.gear:SetPoint("TOPRIGHT", body, "TOPRIGHT", -2, 0)
    self.gear:SetHeight(1)

    -- résumé global (premium) : 2 lignes
    self.sumFrame = CreateFrame("Frame", nil, self.gear)
    self.sumFrame:SetPoint("TOPLEFT", self.gear, "TOPLEFT", 2, -2)
    self.sumFrame:SetPoint("TOPRIGHT", self.gear, "TOPRIGHT", -2, 0)
    self.sumFrame:SetHeight(38)
    self.sumFrame.bg = self.sumFrame:CreateTexture(nil, "BACKGROUND")
    self.sumFrame.bg:SetAllPoints(self.sumFrame); self.sumFrame.bg:SetColorTexture(0.10, 0.12, 0.18, 0.6)
    self.sumTop = self.sumFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    self.sumTop:SetPoint("TOPLEFT", self.sumFrame, "TOPLEFT", 6, -3)
    self.sumTop:SetPoint("RIGHT", self.sumFrame, "RIGHT", -60, 0); self.sumTop:SetJustifyH("LEFT")
    self.sumBot = self.sumFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    self.sumBot:SetPoint("TOPLEFT", self.sumTop, "BOTTOMLEFT", 0, -2)
    self.sumBot:SetPoint("RIGHT", self.sumFrame, "RIGHT", -6, 0); self.sumBot:SetJustifyH("LEFT")

    self.charBtn = CreateFrame("Button", nil, self.sumFrame, "UIPanelButtonTemplate")
    self.charBtn:SetSize(54, 18); self.charBtn:SetPoint("RIGHT", self.sumFrame, "RIGHT", -3, 0)
    self.charBtn:SetText("Blizz")
    self.charBtn:SetScript("OnClick", function() if ToggleCharacter then pcall(ToggleCharacter, "PaperDollFrame") end end)
    self.charBtn:SetScript("OnEnter", function(s)
        SP:AnchorTooltipOutsidePanel(GameTooltip, s); GameTooltip:SetText("Feuille Blizzard (transmo, titres)"); GameTooltip:Show()
    end)
    self.charBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- ===== conteneur STATS =====
    self.stats = CreateFrame("Frame", nil, body)
    self.stats:SetPoint("TOPLEFT", body, "TOPLEFT", 4, -2)
    self.stats:SetPoint("TOPRIGHT", body, "TOPRIGHT", -4, 0)
    self.stats:SetHeight(1); self.stats:Hide()

    -- ===== conteneur ALTERS (ex-module Personnages / AlterEgo) =====
    self.alts = CreateFrame("Frame", nil, body)
    self.alts:SetPoint("TOPLEFT", body, "TOPLEFT", 4, -2)
    self.alts:SetPoint("TOPRIGHT", body, "TOPRIGHT", -4, 0)
    self.alts:SetHeight(1); self.alts:Hide()
    self.altRows = {}

    self.ev = CreateFrame("Frame")
    self.ev:SetScript("OnEvent", function(_, e)
        if e == "PLAYER_REGEN_ENABLED" then self:ApplyKeyOverride() end
        if e == "CURSOR_CHANGED" then self:UpdateSlotHighlights(); return end
        self:RequestRefresh()
    end)
end

-- ============================================================
-- Bouton de slot PaperDoll : icône + iLvl SUR l'icône + drag/équip natif +
-- highlight de compatibilité + contrôles souris Blizzard.
local function MakeSlotButton(self, parent)
    local slot = CreateFrame("Button", nil, parent)
    slot:SetSize(CELL, CELL)
    slot:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    slot:RegisterForDrag("LeftButton")
    slot.icon = slot:CreateTexture(nil, "ARTWORK"); slot.icon:SetAllPoints(slot); slot.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    slot.border = slot:CreateTexture(nil, "BACKGROUND")
    slot.border:SetPoint("TOPLEFT", slot, "TOPLEFT", -1, 1); slot.border:SetPoint("BOTTOMRIGHT", slot, "BOTTOMRIGHT", 1, -1)
    slot.glow = slot:CreateTexture(nil, "OVERLAY")
    slot.glow:SetPoint("TOPLEFT", slot, "TOPLEFT", -3, 3); slot.glow:SetPoint("BOTTOMRIGHT", slot, "BOTTOMRIGHT", 3, -3)
    slot.glow:SetColorTexture(1, 0.82, 0.2, 0.55); slot.glow:SetBlendMode("ADD"); slot.glow:Hide()
    -- iLvl directement sur l'icône (coin bas-droit)
    slot.ilvlFS = slot:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    slot.ilvlFS:SetPoint("BOTTOMRIGHT", slot, "BOTTOMRIGHT", 0, 1)
    slot.ilvlFS:SetDrawLayer("OVERLAY", 7)
    slot:SetScript("OnEnter", function(s)
        if s.slotId then SP:AnchorTooltipOutsidePanel(GameTooltip, s); pcall(GameTooltip.SetInventoryItem, GameTooltip, "player", s.slotId); GameTooltip:Show() end
    end)
    slot:SetScript("OnLeave", function() GameTooltip:Hide() end)
    slot:SetScript("OnDragStart", function(s)
        if not InCombatLockdown() and s.slotId then PickupInventoryItem(s.slotId); SP:PlayItemSound("pickup") end
    end)
    slot:SetScript("OnReceiveDrag", function(s)
        if not InCombatLockdown() and s.slotId then
            if CursorHasItem() then EquipCursorItem(s.slotId); SP:PlayItemSound("drop")
            else PickupInventoryItem(s.slotId); SP:PlayItemSound("pickup") end
        end
    end)
    -- contrôles souris Blizzard : G=prise/équip ; D=natif ; Ctrl+D=cabine ; Maj+D=gemmes
    slot:SetScript("OnClick", function(s, button)
        if not s.slotId then return end
        local link = GetInventoryItemLink("player", s.slotId)
        if button == "RightButton" then
            if IsControlKeyDown() and link then
                if DressUpItemLink then DressUpItemLink(link) end
            elseif IsShiftKeyDown() then
                if SocketInventoryItem and not InCombatLockdown() then pcall(SocketInventoryItem, s.slotId) end
            elseif link and HandleModifiedItemClick then
                HandleModifiedItemClick(link)
            end
        else
            if InCombatLockdown() then return end
            if CursorHasItem() then EquipCursorItem(s.slotId); SP:PlayItemSound("drop")
            else PickupInventoryItem(s.slotId); SP:PlayItemSound("pickup") end
        end
    end)
    self.slotBtns[#self.slotBtns + 1] = slot
    return slot
end

-- Case = stripe de contraste + bouton de slot + NOM d'objet (ligne 1) + enchant (ligne 2).
function M:_Cell(key, side)
    self.cells = self.cells or {}
    local c = self.cells[key]
    if not c then
        c = { side = side }
        c.frame = CreateFrame("Frame", nil, self.gear); c.frame:SetHeight(CELL_H)
        c.stripe = c.frame:CreateTexture(nil, "BACKGROUND"); c.stripe:SetAllPoints(c.frame)
        c.slot = MakeSlotButton(self, c.frame)
        c.name = c.frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); c.name:SetWordWrap(false)
        c.ench = c.frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall"); c.ench:SetWordWrap(false)
        if side == "R" then
            c.slot:SetPoint("RIGHT", c.frame, "RIGHT", -2, 0)
            c.name:SetPoint("TOPRIGHT", c.slot, "TOPLEFT", -5, -1);  c.name:SetPoint("LEFT", c.frame, "LEFT", 2, 0); c.name:SetJustifyH("RIGHT")
            c.ench:SetPoint("BOTTOMRIGHT", c.slot, "BOTTOMLEFT", -5, 1); c.ench:SetPoint("LEFT", c.frame, "LEFT", 2, 0); c.ench:SetJustifyH("RIGHT")
        elseif side == "L" then
            c.slot:SetPoint("LEFT", c.frame, "LEFT", 2, 0)
            c.name:SetPoint("TOPLEFT", c.slot, "TOPRIGHT", 5, -1);  c.name:SetPoint("RIGHT", c.frame, "RIGHT", -2, 0); c.name:SetJustifyH("LEFT")
            c.ench:SetPoint("BOTTOMLEFT", c.slot, "BOTTOMRIGHT", 5, 1); c.ench:SetPoint("RIGHT", c.frame, "RIGHT", -2, 0); c.ench:SetJustifyH("LEFT")
        else
            c.slot:SetPoint("CENTER", c.frame, "CENTER", 0, 0)
            c.name:Hide(); c.ench:Hide()
        end
        self.cells[key] = c
    end
    return c
end

-- highlight des slots où l'objet du curseur peut aller (feedback de drop)
function M:UpdateSlotHighlights()
    local hasCursor = CursorHasItem and CursorHasItem()
    for _, s in ipairs(self.slotBtns) do
        if s.slotId and hasCursor and CursorCanGoInSlot and CursorCanGoInSlot(s.slotId) then
            s.glow:Show(); s:SetScale(1.08)
        else
            s.glow:Hide(); s:SetScale(1)
        end
    end
end

function M:_StatLine(i)
    local fs = self.statLines[i]
    if not fs then
        fs = CreateFrame("Frame", nil, self.stats)
        fs:SetHeight(15)
        fs.l = fs:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        fs.l:SetPoint("LEFT", fs, "LEFT", 6, 0); fs.l:SetJustifyH("LEFT")
        fs.r = fs:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fs.r:SetPoint("RIGHT", fs, "RIGHT", -6, 0); fs.r:SetJustifyH("RIGHT")
        fs.stripe = fs:CreateTexture(nil, "BACKGROUND"); fs.stripe:SetAllPoints(fs)
        self.statLines[i] = fs
    end
    return fs
end

function M:SetTab(tab)
    self.tab = tab
    if self.tabBtns then for k, b in pairs(self.tabBtns) do b.hl:SetShown(k == tab) end end
    self.gear:SetShown(tab == "gear")
    self.stats:SetShown(tab == "stats")
    if self.alts then self.alts:SetShown(tab == "alts") end
    self:Refresh()
end

function M:Enable()
    self._enabled = true
    if self._placeholder then self._placeholder:Hide() end
    for _, e in ipairs({ "PLAYER_EQUIPMENT_CHANGED", "UNIT_INVENTORY_CHANGED", "COMBAT_RATING_UPDATE",
                         "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED", "CURSOR_CHANGED", "ITEM_LOCK_CHANGED" }) do
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

-- ===== touche C → ce module =====
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

-- Bandeau : nom du personnage (couleur de classe) + niveau.
function M:UpdateTitle()
    if not self.labelFS then return end
    local n = UnitName("player") or "Personnage"
    local lvl = UnitLevel("player") or 0
    local _, classFile = UnitClass("player")
    local cc = classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]
    local hex = cc and ("ff%02x%02x%02x"):format(cc.r * 255, cc.g * 255, cc.b * 255) or "ffffffff"
    self.labelFS:SetText(("|c%s%s|r |cFFAAAAAAniv. %d|r"):format(hex, n, lvl))
end

-- ============================================================
function M:Refresh()
    if not self._enabled then return end
    self:UpdateTitle()
    if self.tab == "stats" then self:RefreshStats()
    elseif self.tab == "alts" then self:RefreshAlts()
    else self:RefreshGear() end
end

-- ===== Onglet ALTERS (lecture d'AlterEgoDB) =====
local function altClassHex(c)
    local file = c.info and c.info.class and c.info.class.file
    local col = file and RAID_CLASS_COLORS and RAID_CLASS_COLORS[file]
    if col then return ("|cff%02x%02x%02x"):format(col.r * 255, col.g * 255, col.b * 255) end
    return "|cffffffff"
end

local function altRatingHex(r)
    local col = C_ChallengeMode and C_ChallengeMode.GetDungeonScoreRarityColor and C_ChallengeMode.GetDungeonScoreRarityColor(r or 0)
    if col then return ("|cff%02x%02x%02x"):format(col.r * 255, col.g * 255, col.b * 255) end
    return "|cffffffff"
end

local function GetAltChars()
    local db = _G.AlterEgoDB
    local chars = db and db.global and db.global.characters
    if not chars then return {} end
    local list = {}
    for _, c in pairs(chars) do
        if c.info and c.info.name and c.info.name ~= "" then list[#list + 1] = c end
    end
    table.sort(list, function(a, b)
        local ia = a.info.ilvl and (a.info.ilvl.equipped or a.info.ilvl.level) or 0
        local ib = b.info.ilvl and (b.info.ilvl.equipped or b.info.ilvl.level) or 0
        return ia > ib
    end)
    return list
end

function M:_AltRow(i)
    local r = self.altRows[i]
    if not r then
        r = CreateFrame("Frame", nil, self.alts); r:SetHeight(16)
        r.stripe = r:CreateTexture(nil, "BACKGROUND"); r.stripe:SetAllPoints(r)
        r.l = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        r.l:SetPoint("LEFT", r, "LEFT", 4, 0); r.l:SetJustifyH("LEFT")
        r.r = r:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        r.r:SetPoint("RIGHT", r, "RIGHT", -4, 0); r.r:SetJustifyH("RIGHT")
        self.altRows[i] = r
    end
    return r
end

function M:RefreshAlts()
    local chars = GetAltChars()
    local y, i = 2, 0
    local function row(left, right, header)
        i = i + 1
        local r = self:_AltRow(i)
        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", self.alts, "TOPLEFT", 0, -y)
        r:SetPoint("TOPRIGHT", self.alts, "TOPRIGHT", 0, -y)
        r.stripe:SetColorTexture(0.29, 0.64, 1, header and 0.12 or (i % 2 == 0 and 0.04 or 0))
        r.l:SetText(left or ""); r.r:SetText(right or "")
        r:Show()
        y = y + 16
    end

    if #chars == 0 then
        row("|cFFFF7777Requiert : AlterEgo|r", "")
    else
        row("|cFF8FC4FFPersonnage|r", "|cFF8FC4FFiLvl · Cote · Clé|r", true)
        for _, c in ipairs(chars) do
            local hex = altClassHex(c)
            local ilvl = c.info.ilvl and (c.info.ilvl.equipped or c.info.ilvl.level) or 0
            local mp = c.mythicplus or {}
            local ks = mp.keystone
            local keyTxt = (ks and (ks.level or 0) > 0) and ("|cFFA335EE+%d|r"):format(ks.level) or "|cFF666666—|r"
            row(("%s%s|r |cFF888888%s|r"):format(hex, c.info.name, c.info.realm or ""),
                ("|cFFFFFFFF%.0f|r · %s%d|r · %s"):format(ilvl, altRatingHex(mp.rating), mp.rating or 0, keyTxt))
        end
    end
    for j = i + 1, #self.altRows do self.altRows[j]:Hide() end
    self.alts:SetHeight(y)
    SP:SetAutoHeight(self, y + 4)
end

local function qhex(q)
    local c = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q or 1]
    return c and c.hex or "|cFFFFFFFF"
end

-- pastille d'état : vert (0 manque), orange (1-2), rouge (3+)
local function statusHex(missing)
    if missing == 0 then return "FF40FF40" elseif missing <= 2 then return "FFFFC020" else return "FFFF4040" end
end

function M:RefreshGear()
    local W = self.gear:GetWidth(); if not W or W < 60 then W = (SP.db.panel.width or 280) - 8 end
    local half = math.floor(W / 2)
    local tot = { ench = 0, okEnch = 0, sock = 0, okSock = 0, opt = 0, items = 0 }

    -- remplit une case + cumule le récap. stripeOn = contraste de ligne (colonnes).
    local function fill(key, side, x, y, w, stripeOn)
        local c = self:_Cell(key, side)
        c.frame:ClearAllPoints()
        c.frame:SetPoint("TOPLEFT", self.gear, "TOPLEFT", x, -y)
        c.frame:SetWidth(w); c.frame:Show()
        if c.stripe then c.stripe:SetColorTexture(1, 1, 1, (side ~= "B" and stripeOn) and 0.05 or 0) end
        local slotId = select(1, GetInventorySlotInfo(key))
        c.slot.slotId = slotId
        local a = AuditSlot(slotId)
        local canEnch = CANENCH[key]
        local function setCol(fs, txt) if fs then if side == "B" then fs:Hide() else fs:Show(); fs:SetText(txt or "") end end end
        if a.has then
            tot.items = tot.items + 1
            c.slot.icon:SetTexture(a.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
            c.slot.icon:SetAlpha((slotId and IsInventoryItemLocked(slotId)) and 0.35 or 1)
            local qc = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[a.quality]
            c.slot.border:SetColorTexture(qc and qc.r or 0.3, qc and qc.g or 0.3, qc and qc.b or 0.3, 1)
            c.slot.ilvlFS:SetText(tostring(a.ilvl))
            c.slot.ilvlFS:SetTextColor(qc and qc.r or 1, qc and qc.g or 0.82, qc and qc.b or 0)
            local slotOK = true
            if canEnch then
                tot.ench = tot.ench + 1
                if a.enchanted then tot.okEnch = tot.okEnch + 1 else slotOK = false end
            end
            if a.sockets > 0 then
                tot.sock = tot.sock + a.sockets; tot.okSock = tot.okSock + a.gemsFilled
                if a.gemsFilled < a.sockets then slotOK = false end
            end
            -- ligne 1 : NOM de l'objet (couleur de rareté) ; ligne 2 : enchant
            setCol(c.name, qhex(a.quality) .. (a.name or "?") .. "|r")
            local enchTxt
            if a.enchanted then enchTxt = "|cFF40FF40" .. (a.enchShort or "Enchanté") .. "|r"
            elseif canEnch then enchTxt = "|cFFFF4040|A:common-icon-redx:11:11:0:0|a Manque|r"
            else enchTxt = "" end
            setCol(c.ench, enchTxt)
            if slotOK then tot.opt = tot.opt + 1 end
        else
            c.slot.icon:SetTexture("Interface\\PaperDoll\\UI-Backpack-EmptySlot")
            c.slot.icon:SetAlpha(1)
            c.slot.border:SetColorTexture(0.45, 0.12, 0.12, 1)
            c.slot.ilvlFS:SetText("")
            setCol(c.name, "|cFF888888" .. (LABEL[key] or "") .. "|r")
            setCol(c.ench, "|cFF666666vide|r")
        end
    end

    -- zigzag : un item par ligne, pleine largeur, côté alterné (icône gauche/droite)
    local topY = 44
    local y = topY
    for idx, e in ipairs(COLUMN) do
        fill(e[1], e[2], 2, y, W - 4, idx % 2 == 0)
        y = y + CELL_H
    end
    y = y + 4

    -- rangée du bas : 5 colonnes de paires verticales (2 lignes chacune)
    local cols = #BOTTOM_PAIRS
    local colW = math.floor(W / cols)
    for p, pair in ipairs(BOTTOM_PAIRS) do
        local x = 2 + (p - 1) * colW
        fill(pair[1], "B", x, y, colW)              -- ligne du haut
        fill(pair[2], "B", x, y + CELL + 4, colW)   -- ligne du bas
    end
    y = y + 2 * (CELL + 4) + 4

    self:UpdateSlotHighlights()

    -- résumé global premium
    local overall, equipped = GetAverageItemLevel()
    self.sumTop:SetText(("|cFFFFFFFFiLvl|r |cFFFFD200%.0f|r  |cFF888888(équipé %.0f)|r"):format(overall or 0, equipped or overall or 0))
    self.sumBot:SetText(("|c%sEnch %d/%d|r   |c%sGemmes %d/%d|r   |c%sSlots %d/%d|r"):format(
        statusHex(tot.ench - tot.okEnch), tot.okEnch, tot.ench,
        statusHex(tot.sock - tot.okSock), tot.okSock, tot.sock,
        statusHex(tot.items - tot.opt), tot.opt, tot.items))
    SP:SetModuleHeaderText(self, "")

    self.gear:SetHeight(y)
    SP:SetAutoHeight(self, y + 4)
end

-- ============================================================
-- STATS : sections + couleurs intelligentes + tooltips
local function pctStr(v) return v and ("%.2f%%"):format(v) or "—" end

function M:RefreshStats()
    local rows = {}   -- { kind="header"/"stat", label, value, color, tip={...} }
    local function header(t) rows[#rows + 1] = { kind = "header", label = t } end
    local function stat(label, value, color, tip) rows[#rows + 1] = { kind = "stat", label = label, value = value, color = color, tip = tip } end

    local overall, equipped = GetAverageItemLevel()
    header("PRIMAIRES")
    local _, str = UnitStat("player", 1)
    local _, agi = UnitStat("player", 2)
    local _, sta = UnitStat("player", 3)
    local _, int = UnitStat("player", 4)
    local prim = { { "Force", str }, { "Agilité", agi }, { "Intelligence", int } }
    local hi = 1; for k = 2, 3 do if prim[k][2] > prim[hi][2] then hi = k end end
    for k, p in ipairs(prim) do
        stat(p[1], tostring(p[2]), (k == hi) and "FF4AA3FF" or "FFBBBBBB",
            { p[1], "Attribut principal — augmente la puissance de sort/d'attaque." })
    end
    stat("Endurance", tostring(sta), "FF66CCFF", { "Endurance", "Augmente vos points de vie maximum." })

    -- secondaires : couleur RELATIVE (la plus haute = vert, la plus basse = orange)
    header("SECONDAIRES")
    local crit = GetCritChance and GetCritChance() or 0
    local haste = GetHaste and GetHaste() or 0
    local mast = GetMasteryEffect and GetMasteryEffect() or 0
    local vers = 0
    if GetCombatRatingBonus and CR_VERSATILITY_DAMAGE_DONE then
        vers = (GetCombatRatingBonus(CR_VERSATILITY_DAMAGE_DONE) or 0) + (GetVersatilityBonus and GetVersatilityBonus(CR_VERSATILITY_DAMAGE_DONE) or 0)
    end
    local sec = {
        { "Critique", crit, CR_CRIT_MELEE, "Chance d'infliger un coup critique (×2 dégâts/soins)." },
        { "Hâte", haste, CR_HASTE_MELEE, "Accélère lancers, attaques et régénération de ressource." },
        { "Maîtrise", mast, CR_MASTERY, "Bonus propre à votre spécialisation." },
        { "Polyvalence", vers, CR_VERSATILITY_DAMAGE_DONE, "Augmente les dégâts/soins et réduit les dégâts subis." },
    }
    local maxv, minv = -1, 1e9
    for _, s in ipairs(sec) do maxv = math.max(maxv, s[2]); minv = math.min(minv, s[2]) end
    for _, s in ipairs(sec) do
        local col = "FFFFFFFF"
        if s[2] < 5 then col = "FFFF6040"
        elseif maxv > minv then col = (s[2] == maxv) and "FF40FF40" or (s[2] == minv) and "FFFFC020" or "FFFFFFFF" end
        local rating = s[3] and GetCombatRating and GetCombatRating(s[3])
        stat(s[1], pctStr(s[2]), col, { s[1], s[4], rating and ("Rating : %d"):format(rating) or nil })
    end

    -- tertiaires (si > 0)
    local tert = {}
    local function tadd(label, v, tip) if v and v > 0 then tert[#tert + 1] = { label, v, tip } end end
    tadd("Vélocité", GetSpeed and GetSpeed(), "Augmente la vitesse de déplacement.")
    tadd("Vol de vie", GetLifesteal and GetLifesteal(), "Soigne d'une partie des dégâts infligés.")
    tadd("Évitement", GetAvoidance and GetAvoidance(), "Réduit les dégâts de zone subis.")
    if #tert > 0 then
        header("TERTIAIRES")
        for _, t in ipairs(tert) do stat(t[1], pctStr(t[2]), "FF40D0C0", { t[1], t[3] }) end
    end

    header("DÉFENSE")
    local _, armor = UnitArmor("player")
    stat("Armure", tostring(armor or 0), "FFFFAA40", { "Armure", "Réduit les dégâts physiques subis." })
    local dodge = GetDodgeChance and GetDodgeChance()
    local parry = GetParryChance and GetParryChance()
    local block = GetBlockChance and GetBlockChance()
    if dodge and dodge > 0 then stat("Esquive", pctStr(dodge), "FFFFAA40", { "Esquive", "Chance d'esquiver une attaque de mêlée." }) end
    if parry and parry > 0 then stat("Parade", pctStr(parry), "FFFFAA40", { "Parade", "Chance de parer une attaque de mêlée frontale." }) end
    if block and block > 0 then stat("Blocage", pctStr(block), "FFFFAA40", { "Blocage", "Chance de bloquer une partie des dégâts au bouclier." }) end

    -- rendu
    local y = 2
    for i, d in ipairs(rows) do
        local fs = self:_StatLine(i)
        fs:ClearAllPoints()
        fs:SetPoint("TOPLEFT", self.stats, "TOPLEFT", 0, -y)
        fs:SetPoint("RIGHT", self.stats, "RIGHT", 0, 0)
        if d.kind == "header" then
            fs:SetHeight(16)
            fs.stripe:SetColorTexture(0.29, 0.64, 1, 0.14)
            fs.l:SetText("|cFF8FC4FF" .. d.label .. "|r"); fs.r:SetText("")
            fs:SetScript("OnEnter", nil); fs:EnableMouse(false)
            y = y + 17
        else
            fs:SetHeight(15)
            fs.stripe:SetColorTexture(0, 0, 0, (i % 2 == 0) and 0.20 or 0)
            fs.l:SetText("|cFFCCCCCC" .. d.label .. "|r")
            fs.r:SetText("|c" .. (d.color or "FFFFFFFF") .. d.value .. "|r")
            fs:EnableMouse(true)
            fs._tip = d.tip
            fs:SetScript("OnEnter", function(s)
                if not s._tip then return end
                SP:AnchorTooltipOutsidePanel(GameTooltip, s)
                GameTooltip:SetText(s._tip[1], 1, 0.82, 0)
                for k = 2, #s._tip do if s._tip[k] then GameTooltip:AddLine(s._tip[k], 1, 1, 1, true) end end
                GameTooltip:Show()
            end)
            fs:SetScript("OnLeave", function() GameTooltip:Hide() end)
            y = y + 16
        end
        fs:Show()
    end
    for i = #rows + 1, #self.statLines do self.statLines[i]:Hide() end

    self.stats:SetHeight(y)
    SP:SetAutoHeight(self, y + 4)
end

SP:RegisterModule(M)
