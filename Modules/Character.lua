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

local ROW = 30   -- ligne d'équipement (2 lignes de texte)

-- slot Blizzard, libellé FR, et "peut être enchanté" (gate l'alerte « ✗ enchant »)
local SLOTS = {
    { "HEADSLOT", "Tête", true },        { "NECKSLOT", "Cou", false },
    { "SHOULDERSLOT", "Épaules", true }, { "BACKSLOT", "Dos", false },
    { "CHESTSLOT", "Torse", true },      { "WRISTSLOT", "Poignets", false },
    { "HANDSSLOT", "Mains", false },     { "WAISTSLOT", "Taille", false },
    { "LEGSSLOT", "Jambes", true },      { "FEETSLOT", "Pieds", true },
    { "FINGER0SLOT", "Anneau 1", true }, { "FINGER1SLOT", "Anneau 2", true },
    { "TRINKET0SLOT", "Bijou 1", false },{ "TRINKET1SLOT", "Bijou 2", false },
    { "MAINHANDSLOT", "Arme princ.", true }, { "SECONDARYHANDSLOT", "Arme sec.", true },
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
        for _, d in ipairs({ { "stats", "Stats" }, { "gear", "Équip." } }) do
            local b = CreateFrame("Button", nil, self.header)
            b:SetSize(44, 16)
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
        self.header:SetScript("OnMouseWheel", function()
            self:SetTab(self.tab == "gear" and "stats" or "gear")
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

    self.ev = CreateFrame("Frame")
    self.ev:SetScript("OnEvent", function(_, e)
        if e == "PLAYER_REGEN_ENABLED" then self:ApplyKeyOverride() end
        if e == "CURSOR_CHANGED" then self:UpdateSlotHighlights(); return end
        self:RequestRefresh()
    end)
end

-- ============================================================
-- Case PaperDoll : icône + drag/équip natif + highlight de compatibilité.
function M:_GearRow(i)
    local r = self.rows[i]
    if not r then
        r = CreateFrame("Frame", nil, self.gear)
        r:SetHeight(ROW)

        -- bouton de slot (comportement PaperDoll câblé manuellement)
        local slot = CreateFrame("Button", nil, r)
        slot:SetSize(ROW - 6, ROW - 6)
        slot:SetPoint("LEFT", r, "LEFT", 2, 0)
        slot:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        slot:RegisterForDrag("LeftButton")
        slot.icon = slot:CreateTexture(nil, "ARTWORK"); slot.icon:SetAllPoints(slot); slot.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        slot.border = slot:CreateTexture(nil, "BACKGROUND")
        slot.border:SetPoint("TOPLEFT", slot.icon, "TOPLEFT", -1, 1); slot.border:SetPoint("BOTTOMRIGHT", slot.icon, "BOTTOMRIGHT", 1, -1)
        slot.glow = slot:CreateTexture(nil, "OVERLAY")
        slot.glow:SetPoint("TOPLEFT", slot, "TOPLEFT", -3, 3); slot.glow:SetPoint("BOTTOMRIGHT", slot, "BOTTOMRIGHT", 3, -3)
        slot.glow:SetColorTexture(1, 0.82, 0.2, 0.55); slot.glow:SetBlendMode("ADD"); slot.glow:Hide()
        slot:SetScript("OnEnter", function(s)
            if s.slotId then SP:AnchorTooltipOutsidePanel(GameTooltip, s); pcall(GameTooltip.SetInventoryItem, GameTooltip, "player", s.slotId); GameTooltip:Show() end
        end)
        slot:SetScript("OnLeave", function() GameTooltip:Hide() end)
        slot:SetScript("OnDragStart", function(s)
            if not InCombatLockdown() and s.slotId then PickupInventoryItem(s.slotId) end
        end)
        slot:SetScript("OnReceiveDrag", function(s)
            if not InCombatLockdown() and s.slotId then
                if CursorHasItem() then EquipCursorItem(s.slotId) else PickupInventoryItem(s.slotId) end
            end
        end)
        slot:SetScript("OnClick", function(s, button)
            if InCombatLockdown() or not s.slotId then return end
            if CursorHasItem() then EquipCursorItem(s.slotId)
            else PickupInventoryItem(s.slotId) end
        end)
        r.slot = slot

        r.name = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        r.name:SetPoint("TOPLEFT", slot, "TOPRIGHT", 5, -1); r.name:SetJustifyH("LEFT"); r.name:SetWordWrap(false)
        r.ilvl = r:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        r.ilvl:SetPoint("TOPRIGHT", r, "TOPRIGHT", -2, -1); r.ilvl:SetJustifyH("RIGHT")
        r.name:SetPoint("RIGHT", r.ilvl, "LEFT", -4, 0)
        r.detail = r:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        r.detail:SetPoint("TOPLEFT", slot, "TOPRIGHT", 5, -13)
        r.detail:SetPoint("RIGHT", r, "RIGHT", -2, 0); r.detail:SetJustifyH("LEFT"); r.detail:SetWordWrap(false)
        self.rows[i] = r
        self.slotBtns[#self.slotBtns + 1] = slot
    end
    return r
end

-- highlight des slots où l'objet du curseur peut aller (feedback de drop)
function M:UpdateSlotHighlights()
    local hasCursor = CursorHasItem and CursorHasItem()
    for _, s in ipairs(self.slotBtns) do
        if s.slotId and hasCursor and CursorCanGoInSlot and CursorCanGoInSlot(s.slotId) then
            s.glow:Show(); s:SetScale(1.07)
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

-- ============================================================
function M:Refresh()
    if not self._enabled then return end
    if self.tab == "stats" then self:RefreshStats() else self:RefreshGear() end
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
    local y = 42   -- sous le résumé
    local totalEnch, okEnch = 0, 0
    local totalSock, okSock = 0, 0
    local optimized, totalItems = 0, 0

    for i, d in ipairs(SLOTS) do
        local slotName, label, canEnch = d[1], d[2], d[3]
        local slotId = GetInventorySlotInfo and select(1, GetInventorySlotInfo(slotName))
        local r = self:_GearRow(i)
        r.slot.slotId = slotId
        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", self.gear, "TOPLEFT", 2, -y)
        r:SetPoint("RIGHT", self.gear, "RIGHT", -2, 0)

        local a = AuditSlot(slotId)
        if a.has then
            totalItems = totalItems + 1
            r.slot.icon:SetTexture(a.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
            r.slot.icon:SetAlpha((slotId and IsInventoryItemLocked(slotId)) and 0.35 or 1)  -- "en déplacement"
            local qc = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[a.quality]
            r.slot.border:SetColorTexture(qc and qc.r or 0.3, qc and qc.g or 0.3, qc and qc.b or 0.3, 1)
            r.name:SetText(qhex(a.quality) .. (a.name or "?") .. "|r")
            r.ilvl:SetText(qhex(a.quality) .. tostring(a.ilvl) .. "|r")

            -- détail : upgrade · enchant · gemmes
            local parts = {}
            if a.upTrack then
                local maxed = a.upLevel and a.upMax and a.upLevel >= a.upMax
                parts[#parts + 1] = (maxed and "|cFF40FF40" or "|cFF999999") .. ("%s %s/%s"):format(a.upTrack, a.upLevel or 0, a.upMax or 0) .. "|r"
            end
            -- enchant
            local slotOK = true
            if a.enchanted then
                parts[#parts + 1] = "|cFF40FF40✦ ench.|r"
            elseif canEnch then
                parts[#parts + 1] = "|cFFFF4040✗ enchant|r"; slotOK = false
            end
            if canEnch then totalEnch = totalEnch + 1; if a.enchanted then okEnch = okEnch + 1 end end
            -- gemmes (vraies icônes)
            if a.sockets > 0 then
                totalSock = totalSock + a.sockets
                okSock = okSock + a.gemsFilled
                local gtxt = ""
                for _, g in ipairs(a.gemIcons) do
                    if g then gtxt = gtxt .. ("|T%d:12:12:0:0|t"):format(g)
                    else gtxt = gtxt .. "|cFFFF4040◆|r"; slotOK = false end
                end
                parts[#parts + 1] = gtxt
            end
            r.detail:SetText(table.concat(parts, "  "))
            if slotOK then optimized = optimized + 1 end
        else
            r.slot.icon:SetTexture("Interface\\PaperDoll\\UI-Backpack-EmptySlot")
            r.slot.icon:SetAlpha(1)
            r.slot.border:SetColorTexture(0.5, 0.1, 0.1, 1)
            r.name:SetText("|cFF888888" .. label .. "|r")
            r.ilvl:SetText("|cFFFF4040—|r")
            r.detail:SetText("|cFFFF4040emplacement vide|r")
        end
        r:Show()
        y = y + ROW
    end
    for i = #SLOTS + 1, #self.rows do self.rows[i]:Hide() end
    self:UpdateSlotHighlights()

    -- résumé global premium
    local overall, equipped = GetAverageItemLevel()
    local missEnch = totalEnch - okEnch
    local missSock = totalSock - okSock
    local missOpt  = totalItems - optimized
    self.sumTop:SetText(("|cFFFFFFFFiLvl|r |cFFFFD200%.0f|r  |cFF888888(équipé %.0f)|r"):format(overall or 0, equipped or overall or 0))
    self.sumBot:SetText(("|c%sEnch %d/%d|r   |c%sGemmes %d/%d|r   |c%sSlots %d/%d|r"):format(
        statusHex(missEnch), okEnch, totalEnch,
        statusHex(missSock), okSock, totalSock,
        statusHex(missOpt), optimized, totalItems))
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
