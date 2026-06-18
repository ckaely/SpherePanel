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

local function ShortEnchantText(text)
    local short = tostring(text or ""):gsub("|A:.-|a", ""):gsub("|T.-|t", ""):gsub("^%s+", ""):gsub("%s+$", "")
    for _ = 1, 3 do short = short:gsub("^%s*[\194-\244][\128-\191]*%s*", "") end
    local afterColon = short:match(".*[:：]%s*(.+)$")
    if afterColon then short = afterColon end
    short = short:gsub("^Enchantement%s+d['’][^%-–—:]+%s*[%-%–%—:]%s*", "")
    short = short:gsub("^Enchantement%s+de%s+[^%-–—:]+%s*[%-%–%—:]%s*", "")
    short = short:gsub("^Enchantement%s+du%s+[^%-–—:]+%s*[%-%–%—:]%s*", "")
    short = short:gsub("^Enchantement%s+des%s+[^%-–—:]+%s*[%-%–%—:]%s*", "")
    short = short:gsub("^Enchantement%s+pour%s+[^%-–—:]+%s*[%-%–%—:]%s*", "")
    short = short:gsub("^Enchantement%s+[^%-–—:]+%s*[%-%–%—:]%s*", "")
    return short:gsub("^%s+", ""):gsub("%s+$", "")
end

local function MakePanelButton(parent, text, w, h)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(w or 54, h or 18)
    b.bg = b:CreateTexture(nil, "BACKGROUND")
    b.bg:SetAllPoints(b)
    b.bg:SetColorTexture(0.10, 0.12, 0.18, 0.82)
    b.line = b:CreateTexture(nil, "OVERLAY")
    b.line:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 1, 0)
    b.line:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -1, 0)
    b.line:SetHeight(1)
    b.line:SetColorTexture(0.29, 0.64, 1, 0.65)
    b.fs = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    b.fs:SetAllPoints(b)
    b.fs:SetText(text or "")
    b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    b.SetText = function(self, v) self.fs:SetText(v or "") end
    return b
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
                a.enchantAtlas = lt and lt:match("|A:([^:|]+)")
                a.enchantIcon = lt and lt:match("|T([^:|]+)")
                -- nom court : retire le préfixe "Enchanté : " et un éventuel atlas
                local short = lt:gsub("|A:.-|a", ""):gsub("|T.-|t", "")
                -- garde UNIQUEMENT le nom : retire tout préfixe "Xxx : " (Enchantement d'arme/de cape/Enchanté…)
                local afterColon = short:match(".*[:：]%s*(.+)$")
                if afterColon then short = afterColon end
                a.enchShort = ShortEnchantText(lt)
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

    self.charBtn = MakePanelButton(self.sumFrame, "Blizz", 54, 18)
    self.charBtn:SetSize(54, 18); self.charBtn:SetPoint("RIGHT", self.sumFrame, "RIGHT", -3, 0)
    self.charBtn:SetText("Blizz")
    self.charBtn:SetScript("OnClick", function() if ToggleCharacter then pcall(ToggleCharacter, "PaperDollFrame") end end)
    self.charBtn:SetScript("OnEnter", function(s)
        SP:AnchorTooltipOutsidePanel(GameTooltip, s); GameTooltip:SetText("Feuille Blizzard (transmo, titres)"); GameTooltip:Show()
    end)
    self.charBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    self:CreateEquipManager()

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
        c.ench._spFontRole = "secondary"
        c.enchIcon = c.frame:CreateTexture(nil, "OVERLAY")
        c.enchIcon:SetSize(12, 12)
        c.enchIcon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        c.enchIcon:Hide()
        c.gemTex = {}
        for i = 1, 3 do
            local gt = c.frame:CreateTexture(nil, "OVERLAY")
            gt:SetSize(10, 10)
            gt:SetTexCoord(0.07, 0.93, 0.07, 0.93)
            gt:Hide()
            c.gemTex[i] = gt
        end
        if side == "R" then
            c.slot:SetPoint("RIGHT", c.frame, "RIGHT", -2, 0)
            c.name:SetPoint("TOPRIGHT", c.slot, "TOPLEFT", -5, -1);  c.name:SetPoint("LEFT", c.frame, "LEFT", 2, 0); c.name:SetJustifyH("RIGHT")
            c.enchIcon:SetPoint("BOTTOMRIGHT", c.slot, "BOTTOMLEFT", -5, 1)
            c.ench:SetPoint("BOTTOMRIGHT", c.enchIcon, "BOTTOMLEFT", -3, 0); c.ench:SetPoint("LEFT", c.frame, "LEFT", 34, 0); c.ench:SetJustifyH("RIGHT")
            for i, gt in ipairs(c.gemTex) do gt:SetPoint("BOTTOMLEFT", c.frame, "BOTTOMLEFT", 2 + (i - 1) * 12, 3) end
        elseif side == "L" then
            c.slot:SetPoint("LEFT", c.frame, "LEFT", 2, 0)
            c.name:SetPoint("TOPLEFT", c.slot, "TOPRIGHT", 5, -1);  c.name:SetPoint("RIGHT", c.frame, "RIGHT", -2, 0); c.name:SetJustifyH("LEFT")
            c.enchIcon:SetPoint("BOTTOMLEFT", c.slot, "BOTTOMRIGHT", 5, 1)
            c.ench:SetPoint("BOTTOMLEFT", c.enchIcon, "BOTTOMRIGHT", 3, 0); c.ench:SetPoint("RIGHT", c.frame, "RIGHT", -34, 0); c.ench:SetJustifyH("LEFT")
            for i, gt in ipairs(c.gemTex) do gt:SetPoint("BOTTOMRIGHT", c.frame, "BOTTOMRIGHT", -2 - (i - 1) * 12, 3) end
        else
            c.slot:SetPoint("CENTER", c.frame, "CENTER", 0, 0)
            c.name:Hide(); c.ench:Hide(); c.enchIcon:Hide()
            for _, gt in ipairs(c.gemTex) do gt:Hide() end
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
    if self.equipMgr then self.equipMgr:SetShown((self.equipOpen == true) and tab == "gear") end
    if self.equipTab then self.equipTab:SetShown(tab == "gear") end
    self:Refresh()
end

local function GetEquipmentSets()
    local out = {}
    if C_EquipmentSet and C_EquipmentSet.GetEquipmentSetIDs then
        local ids = C_EquipmentSet.GetEquipmentSetIDs() or {}
        for _, id in ipairs(ids) do
            local ok, name, icon, _, isEquipped = pcall(C_EquipmentSet.GetEquipmentSetInfo, id)
            if ok and name and name ~= "" then out[#out + 1] = { id = id, name = name, icon = icon, equipped = isEquipped } end
        end
    elseif GetNumEquipmentSets and GetEquipmentSetInfo then
        for i = 1, GetNumEquipmentSets() do
            local name, icon, _, isEquipped = GetEquipmentSetInfo(i)
            if name and name ~= "" then out[#out + 1] = { id = i, name = name, icon = icon, equipped = isEquipped } end
        end
    end
    table.sort(out, function(a, b) return (a.name or "") < (b.name or "") end)
    return out
end

local function UseEquipSet(set)
    if InCombatLockdown and InCombatLockdown() then return false, "combat" end
    if C_EquipmentSet and C_EquipmentSet.UseEquipmentSet and set.id then
        local ok = pcall(C_EquipmentSet.UseEquipmentSet, set.id)
        if ok then return true end
    end
    if UseEquipmentSet and set.name then
        local ok = pcall(UseEquipmentSet, set.name)
        if ok then return true end
    end
    return false
end

local function SaveEquipSet(set)
    if InCombatLockdown and InCombatLockdown() then return false, "combat" end
    if C_EquipmentSet and C_EquipmentSet.SaveEquipmentSet and set.id then
        local ok = pcall(C_EquipmentSet.SaveEquipmentSet, set.id)
        if ok then return true end
    end
    if SaveEquipmentSet and set.name then
        local ok = pcall(SaveEquipmentSet, set.name, set.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
        if ok then return true end
    end
    return false
end

local function DeleteEquipSet(set)
    if InCombatLockdown and InCombatLockdown() then return false, "combat" end
    if C_EquipmentSet and C_EquipmentSet.DeleteEquipmentSet and set.id then
        local ok = pcall(C_EquipmentSet.DeleteEquipmentSet, set.id)
        if ok then return true end
    end
    if DeleteEquipmentSet and set.name then
        local ok = pcall(DeleteEquipmentSet, set.name)
        if ok then return true end
    end
    return false
end

function M:CreateEquipSet(name)
    name = tostring(name or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if name == "" or (InCombatLockdown and InCombatLockdown()) then return end
    if C_EquipmentSet and C_EquipmentSet.CreateEquipmentSet then
        pcall(C_EquipmentSet.CreateEquipmentSet, name, "Interface\\Icons\\INV_Misc_QuestionMark")
    elseif SaveEquipmentSet then
        pcall(SaveEquipmentSet, name, "Interface\\Icons\\INV_Misc_QuestionMark")
    end
    C_Timer.After(0.2, function() if self.RefreshEquipManager then self:RefreshEquipManager() end end)
end

function M:CreateEquipManager()
    if self.equipMgr then return end
    local tab = MakePanelButton(self.body, "Sets", 34, 58)
    tab:SetPoint("RIGHT", self.body, "RIGHT", 0, 0)
    tab:SetFrameLevel((self.body:GetFrameLevel() or 1) + 8)
    tab:SetScript("OnClick", function() self.equipOpen = not self.equipOpen; self:SetTab("gear") end)
    self.equipTab = tab

    local p = CreateFrame("Frame", nil, self.body)
    p:SetSize(198, 236)
    p:SetPoint("TOPLEFT", self.body, "TOPRIGHT", 4, 0)
    p:SetFrameStrata("DIALOG")
    p:SetFrameLevel((self.body:GetFrameLevel() or 1) + 10)
    p.bg = p:CreateTexture(nil, "BACKGROUND"); p.bg:SetAllPoints(p); p.bg:SetColorTexture(0.04, 0.05, 0.08, 0.94)
    p.line = p:CreateTexture(nil, "OVERLAY"); p.line:SetPoint("TOPLEFT"); p.line:SetPoint("BOTTOMLEFT"); p.line:SetWidth(2); p.line:SetColorTexture(0.29, 0.64, 1, 0.75)
    p.title = p:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    p.title:SetPoint("TOPLEFT", p, "TOPLEFT", 8, -8); p.title:SetText("Gestionnaire d'equipement")
    p.nameBox = CreateFrame("EditBox", nil, p, "InputBoxTemplate")
    p.nameBox:SetSize(110, 18); p.nameBox:SetPoint("TOPLEFT", p, "TOPLEFT", 10, -30)
    p.nameBox:SetAutoFocus(false)
    p.nameBox:SetScript("OnEnterPressed", function(s) self:CreateEquipSet(s:GetText()); s:SetText(""); s:ClearFocus() end)
    p.newBtn = MakePanelButton(p, "+", 24, 18); p.newBtn:SetPoint("LEFT", p.nameBox, "RIGHT", 8, 0)
    p.newBtn:SetScript("OnClick", function() self:CreateEquipSet(p.nameBox:GetText()); p.nameBox:SetText("") end)
    p.openBtn = MakePanelButton(p, "Blizz", 44, 18); p.openBtn:SetPoint("LEFT", p.newBtn, "RIGHT", 6, 0)
    p.openBtn:SetScript("OnClick", function()
        if ToggleCharacter then pcall(ToggleCharacter, "PaperDollFrame") end
        if ToggleEquipmentManager then pcall(ToggleEquipmentManager) end
    end)
    p.rows = {}
    p:Hide()
    self.equipMgr = p
end

function M:_EquipRow(i)
    local p = self.equipMgr
    local r = p.rows[i]
    if not r then
        r = CreateFrame("Frame", nil, p); r:SetSize(184, 25)
        r.bg = r:CreateTexture(nil, "BACKGROUND"); r.bg:SetAllPoints(r)
        r.icon = r:CreateTexture(nil, "ARTWORK"); r.icon:SetSize(18, 18); r.icon:SetPoint("LEFT", r, "LEFT", 3, 0)
        r.name = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); r.name:SetPoint("LEFT", r.icon, "RIGHT", 5, 0); r.name:SetPoint("RIGHT", r, "RIGHT", -58, 0); r.name:SetJustifyH("LEFT"); r.name:SetWordWrap(false)
        r.use = MakePanelButton(r, "Use", 32, 17); r.use:SetPoint("RIGHT", r, "RIGHT", -48, 0)
        r.save = MakePanelButton(r, "S", 18, 17); r.save:SetPoint("LEFT", r.use, "RIGHT", 3, 0)
        r.del = MakePanelButton(r, "X", 18, 17); r.del:SetPoint("LEFT", r.save, "RIGHT", 3, 0)
        p.rows[i] = r
    end
    return r
end

function M:RefreshEquipManager()
    if not self.equipMgr then return end
    local sets = GetEquipmentSets()
    local y = 56
    for i, set in ipairs(sets) do
        local r = self:_EquipRow(i)
        r:SetPoint("TOPLEFT", self.equipMgr, "TOPLEFT", 7, -y)
        r.bg:SetColorTexture(set.equipped and 0.10 or 1, set.equipped and 0.30 or 1, set.equipped and 0.18 or 1, set.equipped and 0.55 or ((i % 2 == 0) and 0.06 or 0.03))
        r.icon:SetTexture(set.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
        r.name:SetText((set.equipped and "|cFF40FF40" or "|cFFFFFFFF") .. (set.name or "?") .. "|r")
        r.use:SetScript("OnClick", function() UseEquipSet(set); C_Timer.After(0.4, function() self:RefreshEquipManager() end) end)
        r.save:SetScript("OnClick", function() SaveEquipSet(set); C_Timer.After(0.4, function() self:RefreshEquipManager() end) end)
        r.del:SetScript("OnClick", function() DeleteEquipSet(set); C_Timer.After(0.4, function() self:RefreshEquipManager() end) end)
        r:Show()
        y = y + 27
    end
    for i = #sets + 1, #self.equipMgr.rows do self.equipMgr.rows[i]:Hide() end
    if #sets == 0 then
        if not self.equipMgr.empty then
            self.equipMgr.empty = self.equipMgr:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
            self.equipMgr.empty:SetPoint("TOPLEFT", self.equipMgr, "TOPLEFT", 10, -60)
            self.equipMgr.empty:SetPoint("RIGHT", self.equipMgr, "RIGHT", -10, 0)
            self.equipMgr.empty:SetJustifyH("LEFT")
        end
        self.equipMgr.empty:SetText("Aucun set. Entre un nom puis clique + pour sauvegarder l'equipement actuel.")
        self.equipMgr.empty:Show()
    elseif self.equipMgr.empty then
        self.equipMgr.empty:Hide()
    end
end

function M:Enable()
    self._enabled = true
    if self._placeholder then self._placeholder:Hide() end
    for _, e in ipairs({ "PLAYER_EQUIPMENT_CHANGED", "UNIT_INVENTORY_CHANGED", "COMBAT_RATING_UPDATE",
                         "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED", "CURSOR_CHANGED", "ITEM_LOCK_CHANGED",
                         "EQUIPMENT_SETS_CHANGED", "EQUIPMENT_SWAP_FINISHED" }) do
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
    self:RefreshEquipManager()
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
        local function setEnchantIcon(audit)
            if not c.enchIcon then return end
            if side == "B" or not (audit and audit.enchanted) then c.enchIcon:Hide(); return end
            if audit.enchantAtlas and c.enchIcon.SetAtlas and pcall(c.enchIcon.SetAtlas, c.enchIcon, audit.enchantAtlas, true) then
                c.enchIcon:Show()
            else
                c.enchIcon:SetTexture(audit.enchantIcon or "Interface\\ItemSocketingFrame\\UI-EmptySocket-Prismatic")
                c.enchIcon:Show()
            end
        end
        local function setGemIcons(audit)
            for i, gt in ipairs(c.gemTex or {}) do
                local icon = audit and audit.gemIcons and audit.gemIcons[i]
                if side ~= "B" and icon then
                    gt:SetTexture(icon)
                    gt:Show()
                else
                    gt:Hide()
                end
            end
        end
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
            setEnchantIcon(a)
            setGemIcons(a)
            if slotOK then tot.opt = tot.opt + 1 end
        else
            c.slot.icon:SetTexture("Interface\\PaperDoll\\UI-Backpack-EmptySlot")
            c.slot.icon:SetAlpha(1)
            c.slot.border:SetColorTexture(0.45, 0.12, 0.12, 1)
            c.slot.ilvlFS:SetText("")
            setCol(c.name, "|cFF888888" .. (LABEL[key] or "") .. "|r")
            setCol(c.ench, "|cFF666666vide|r")
            setEnchantIcon(nil)
            setGemIcons(nil)
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
