-- ============================================================
-- Module : SilverDragon — affichage enrichi des alertes de rares
-- ============================================================
-- Écoute le callback "Seen" de SilverDragon, affiche des alertes lisibles.
--   clic GAUCHE = supprime l'alerte ; clic DROIT = affiche le butin ; 📌 = épingle (pas d'expiration).
-- Auto-expiration 60 s (sauf épinglé). Masque l'alerte visuelle native de SilverDragon (flash) seulement.
local ADDON_NAME, SP = ...

local M = {
    name          = "SilverDragon",
    label         = "Rares",
    defaultHeight = 60,
}

local ROW_H, GAP = 30, 2
local EXPIRE = 60
local RARE_ICON = "Interface\\Icons\\INV_Misc_Head_Dragon_01"

local function HasSD() return _G.SilverDragon and true or false end

local function ItemID(item)
    if type(item) == "number" then return item end
    if type(item) == "table" then return item.id or item.itemID or item.item end
end

-- Masque (false) / restaure (true) le flash écran natif de SilverDragon.
function M:SetNativeFlash(enabled)
    local sd = _G.SilverDragon
    local mod = sd and sd.GetModule and sd:GetModule("Announce", true)
    if not (mod and mod.db and mod.db.profile) then return end
    if enabled == false then
        if self._savedFlash == nil then self._savedFlash = mod.db.profile.flash end
        mod.db.profile.flash = false
    elseif self._savedFlash ~= nil then
        mod.db.profile.flash = self._savedFlash
        self._savedFlash = nil
    end
end

-- ============================================================
local function CreateRow(self)
    local row = CreateFrame("Button", nil, self.list)
    row:SetHeight(ROW_H)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    local bg = row:CreateTexture(nil, "BACKGROUND"); bg:SetAllPoints(row); bg:SetColorTexture(0.12, 0.10, 0.04, 0.6)
    local hl = row:CreateTexture(nil, "HIGHLIGHT"); hl:SetAllPoints(row); hl:SetColorTexture(1, 1, 1, 0.08)

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(ROW_H - 6, ROW_H - 6)
    row.icon:SetPoint("LEFT", row, "LEFT", 3, 0)
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    row.pin = CreateFrame("Button", nil, row)
    row.pin:SetSize(14, 14)
    row.pin:SetPoint("RIGHT", row, "RIGHT", -2, 0)
    row.pin.fs = row.pin:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.pin.fs:SetAllPoints(row.pin)
    row.pin:SetScript("OnClick", function() self:TogglePin(row) end)

    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.name:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 5, -1)
    row.name:SetPoint("RIGHT", row.pin, "LEFT", -4, 0)
    row.name:SetJustifyH("LEFT"); row.name:SetWordWrap(false)

    row.sub = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.sub:SetPoint("BOTTOMLEFT", row.icon, "BOTTOMRIGHT", 5, 1)
    row.sub:SetPoint("RIGHT", row.pin, "LEFT", -4, 0)
    row.sub:SetJustifyH("LEFT"); row.sub:SetWordWrap(false)

    row:SetScript("OnClick", function(_, button) self:OnRowClick(row, button) end)
    return row
end

function M:Init(body)
    self.body = body
    self.alerts = {}    -- liste {id,name,zone,x,y,dead,t,pinned,showLoot,row}
    self.rows = {}
    self.lootRows = {}  -- pool lignes de butin (inline)
    self.models = {}    -- pool PlayerModel (modèle 3D du rare)

    self.info = body:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    self.info:SetPoint("TOP", body, "TOP", 0, -8)

    self.list = CreateFrame("Frame", nil, body)
    self.list:SetPoint("TOPLEFT", body, "TOPLEFT", 2, -2)
    self.list:SetPoint("BOTTOMRIGHT", body, "BOTTOMRIGHT", -2, 2)
    self.list:SetClipsChildren(true)

    -- items non encore en cache → refresh quand les infos arrivent
    self.iev = CreateFrame("Frame")
    self.iev:RegisterEvent("GET_ITEM_INFO_RECEIVED")
    self.iev:SetScript("OnEvent", function()
        if self._enabled and self._anyLootShown then self:RequestRefresh() end
    end)
end

function M:RequestRefresh()
    if self._pending then return end
    self._pending = true
    C_Timer.After(0.2, function() self._pending = false; self:Refresh() end)
end

function M:Enable()
    self._enabled = true
    if self._placeholder then self._placeholder:Hide() end
    if not HasSD() then
        self.info:SetText("|cFF888888SilverDragon non installé — module en veille.|r")
        self.info:Show()
        return
    end
    self.info:Hide()
    self:SetNativeFlash(false)  -- masque le flash natif (rien d'autre)
    if not self._hooked then
        self._hooked = true
        _G.SilverDragon.RegisterCallback(self, "Seen", function(_, id, zone, x, y, is_dead, source, unit, GUID)
            self:OnSeen(id, zone, x, y, is_dead)
        end)
    end
    if not self._ticker then
        self._ticker = C_Timer.NewTicker(1, function() self:Tick() end)
    end
    self:Refresh()
end

function M:Disable()
    self._enabled = false
    self:SetNativeFlash(true)  -- restaure le flash natif
    if self._ticker then self._ticker:Cancel(); self._ticker = nil end
    for _, r in ipairs(self.rows) do r:Hide() end
    SP:SetModuleHeaderText(self, "")
end

function M:OnResize(w, h) self:Refresh() end

-- ============================================================
function M:OnSeen(id, zone, x, y, is_dead)
    if not self._enabled or not id then return end
    -- déduplique : remplace l'alerte existante du même mob
    for i, a in ipairs(self.alerts) do
        if a.id == id then table.remove(self.alerts, i); break end
    end
    local name = id
    local sd = _G.SilverDragon
    if sd.GetMobInfo then local ok, n = pcall(sd.GetMobInfo, sd, id); if ok and n then name = n end end
    table.insert(self.alerts, 1, {
        id = id, name = name or ("PNJ " .. tostring(id)),
        zone = zone, x = x, y = y, dead = is_dead and true or false,
        t = GetTime(), pinned = false, showLoot = false,
    })
    while #self.alerts > 10 do table.remove(self.alerts) end
    if not self.alerts[1].dead then
        PlaySound(SOUNDKIT and SOUNDKIT.RAID_WARNING or 8959, "Master")
    end
    -- une alerte DOIT se voir : déplie le module et sort de l'estompage/réduction
    local cfg = SP:GetModuleConfig(self.name)
    if cfg and cfg.collapsed then cfg.collapsed = false; SP:UpdateCollapseVisual(self) end
    self._forceReveal = true
    self:Refresh()
end

function M:Tick()
    local now = GetTime()
    local changed = false
    for i = #self.alerts, 1, -1 do
        local a = self.alerts[i]
        if not a.pinned and (now - a.t) > EXPIRE then
            table.remove(self.alerts, i); changed = true
        end
    end
    self._forceReveal = #self.alerts > 0   -- plus d'alerte = retour au comportement normal
    if changed then self:Refresh() else self:RefreshTimers() end
end

local function ZoneName(uiMapID)
    if uiMapID and C_Map and C_Map.GetMapInfo then
        local info = C_Map.GetMapInfo(uiMapID)
        if info and info.name then return info.name end
    end
    return tostring(uiMapID or "?")
end

-- ligne de butin inline (icône + nom coloré + iLvl, tooltip au survol)
function M:_AcquireLootRow(i)
    local r = self.lootRows[i]
    if not r then
        r = CreateFrame("Button", nil, self.list)
        r:SetHeight(17)
        r.icon = r:CreateTexture(nil, "ARTWORK"); r.icon:SetSize(15, 15); r.icon:SetPoint("LEFT", r, "LEFT", 0, 0)
        r.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        r.fs = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        r.fs:SetPoint("LEFT", r.icon, "RIGHT", 4, 0); r.fs:SetPoint("RIGHT", r, "RIGHT", -2, 0)
        r.fs:SetJustifyH("LEFT"); r.fs:SetWordWrap(false)
        local hl = r:CreateTexture(nil, "HIGHLIGHT"); hl:SetAllPoints(r); hl:SetColorTexture(1, 1, 1, 0.08)
        r:SetScript("OnEnter", function(s)
            if s.itemID then GameTooltip:SetOwner(s, "ANCHOR_LEFT"); pcall(GameTooltip.SetItemByID, GameTooltip, s.itemID); GameTooltip:Show() end
        end)
        r:SetScript("OnLeave", function() GameTooltip:Hide() end)
        self.lootRows[i] = r
    end
    return r
end

function M:_AcquireModel(i)
    local m = self.models[i]
    if not m then
        m = CreateFrame("PlayerModel", nil, self.list)
        m:SetSize(72, 92)
        self.models[i] = m
    end
    return m
end

function M:Refresh()
    if not self.body then return end
    local y = 2
    local li, mi = 0, 0
    self._anyLootShown = false
    local sd = _G.SilverDragon
    local nsSD = sd and sd.NAMESPACE

    for i, a in ipairs(self.alerts) do
        local row = self.rows[i]
        if not row then
            if InCombatLockdown() then break end
            row = CreateRow(self); self.rows[i] = row
        end
        a.row = row
        row.alert = a
        row.icon:SetTexture(RARE_ICON)
        local status = a.dead and "|cFFFF5555(mort)|r" or "|cFF55FF55(vivant)|r"
        row.name:SetText(("|cFFFFD200%s|r %s"):format(tostring(a.name), status))
        local coords = (a.x and a.y and (a.x > 0 or a.y > 0)) and (("  %.1f, %.1f"):format(a.x * 100, a.y * 100)) or ""
        row._zoneText = ZoneName(a.zone) .. coords
        row.pin.fs:SetText(a.pinned and "|cFFFFD200P|r" or "|cFF777777P|r")
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", self.list, "TOPLEFT", 2, -y)
        row:SetPoint("TOPRIGHT", self.list, "TOPRIGHT", -2, -y)
        row:Show()
        y = y + ROW_H + GAP

        -- expansion inline : modèle 3D + butin
        if a.showLoot then
            self._anyLootShown = true
            mi = mi + 1
            local mdl = self:_AcquireModel(mi)
            mdl:ClearAllPoints()
            mdl:SetPoint("TOPLEFT", self.list, "TOPLEFT", 2, -y)
            pcall(mdl.SetCreature, mdl, a.id)
            pcall(mdl.SetCamDistanceScale, mdl, 1.6)
            mdl:Show()

            local loot = nsSD and nsSD.Loot and nsSD.Loot.GetLootTable and nsSD.Loot.GetLootTable(a.id)
            local ly = y
            local shownLoot = 0
            if loot then
                for _, item in ipairs(loot) do
                    local iid = ItemID(item)
                    if iid then
                        shownLoot = shownLoot + 1
                        li = li + 1
                        local lr = self:_AcquireLootRow(li)
                        lr.itemID = iid
                        local name, _, quality, _, _, _, _, _, _, icon = GetItemInfo(iid)
                        if not name then
                            pcall(C_Item.RequestLoadItemDataByID, iid)
                            lr.fs:SetText("|cFF888888Chargement…|r")
                            lr.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
                        else
                            local qc = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality or 1]
                            local hex = qc and qc.hex or "|cFFFFFFFF"
                            local _, _, _, _, _, classID = C_Item.GetItemInfoInstant(iid)
                            local ilvlTxt = ""
                            if classID == 2 or classID == 4 then
                                local ilvl = GetDetailedItemLevelInfo(iid)
                                if ilvl and ilvl > 1 then ilvlTxt = ("  |cFFFFD200%d|r"):format(ilvl) end
                            end
                            lr.fs:SetText(hex .. name .. "|r" .. ilvlTxt)
                            lr.icon:SetTexture(icon or "Interface\\Icons\\INV_Misc_QuestionMark")
                        end
                        lr:ClearAllPoints()
                        lr:SetPoint("TOPLEFT", self.list, "TOPLEFT", 80, -ly)
                        lr:SetPoint("TOPRIGHT", self.list, "TOPRIGHT", -2, -ly)
                        lr:Show()
                        ly = ly + 17
                        if shownLoot >= 10 then break end
                    end
                end
            end
            if shownLoot == 0 then
                li = li + 1
                local lr = self:_AcquireLootRow(li)
                lr.itemID = nil
                lr.icon:SetTexture(nil)
                lr.fs:SetText("|cFF888888Aucun butin connu.|r")
                lr:ClearAllPoints()
                lr:SetPoint("TOPLEFT", self.list, "TOPLEFT", 80, -ly)
                lr:SetPoint("TOPRIGHT", self.list, "TOPRIGHT", -2, -ly)
                lr:Show()
                ly = ly + 17
            end
            y = math.max(y + 94, ly) + GAP   -- hauteur = max(modèle, butin)
        end
    end
    for i = #self.alerts + 1, #self.rows do self.rows[i]:Hide() end
    for i = li + 1, #self.lootRows do self.lootRows[i]:Hide() end
    for i = mi + 1, #self.models do self.models[i]:Hide() end

    self.info:SetShown(#self.alerts == 0 and HasSD())
    if #self.alerts == 0 and HasSD() then self.info:SetText("|cFF888888En attente d'un rare…|r") end

    self:RefreshTimers()
    SP:SetModuleHeaderText(self, #self.alerts > 0 and ("%d"):format(#self.alerts) or "")

    local needed = math.max(ROW_H, 4 + #self.alerts * (ROW_H + GAP))
    local cfg = SP:GetModuleConfig(self.name)
    SP:SetAutoHeight(self, needed)
end

-- Met à jour le compte à rebours dans le sous-texte (sans tout reconstruire).
function M:RefreshTimers()
    local now = GetTime()
    for _, a in ipairs(self.alerts) do
        if a.row and a.row:IsShown() then
            local timer = a.pinned and "|cFFFFD200épinglé|r"
                or ("|cFFAAAAAA%ds|r"):format(math.max(0, math.ceil(EXPIRE - (now - a.t))))
            a.row.sub:SetText((a.row._zoneText or "") .. "  " .. timer)
        end
    end
end

-- ============================================================
function M:TogglePin(row)
    local a = row.alert
    if not a then return end
    a.pinned = not a.pinned
    a.t = GetTime()
    row.pin.fs:SetText(a.pinned and "|cFFFFD200P|r" or "|cFF777777P|r")
    self:RefreshTimers()
end

function M:OnRowClick(row, button)
    local a = row.alert
    if not a then return end
    if button == "RightButton" then
        -- développe/replie la liste de butin + modèle 3D sous l'alerte
        a.showLoot = not a.showLoot
        self:Refresh()
    else
        for i, x in ipairs(self.alerts) do if x == a then table.remove(self.alerts, i); break end end
        GameTooltip:Hide()
        self._forceReveal = #self.alerts > 0
        self:Refresh()
    end
end

SP:RegisterModule(M)
