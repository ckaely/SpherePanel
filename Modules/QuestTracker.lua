-- ============================================================
-- Module : QuestTracker — traqueur de quêtes (suivies) + filtres + couleurs
-- ============================================================
-- Étape 4 + Phase 3. Masque ObjectiveTrackerFrame, liste les quêtes SUIVIES,
-- toolbar de filtres par type, coloration de titre par type, compteur dans le bandeau.
local ADDON_NAME, SP = ...

local M = {
    name          = "QuestTracker",
    label         = "Quêtes",
    defaultHeight = 300,
}

local QUEST_EVENTS = {
    "QUEST_LOG_UPDATE", "QUEST_WATCH_LIST_CHANGED", "QUEST_ACCEPTED",
    "QUEST_REMOVED", "QUEST_TURNED_IN", "UNIT_QUEST_LOG_CHANGED",
    "SUPER_TRACKING_CHANGED", "ZONE_CHANGED_NEW_AREA", "PLAYER_ENTERING_WORLD",
}

local TOOLBAR_H = 20
local FBTN = 18

-- Filtres (= catégories primaires). tex = icône ; atlas optionnel prioritaire.
local FILTERS = {
    { key = "classic",    tip = "Classiques",        tex = "Interface\\GossipFrame\\AvailableQuestIcon" },
    { key = "daily",      tip = "Journalières",      tex = "Interface\\GossipFrame\\DailyQuestIcon" },
    { key = "weekly",     tip = "Hebdomadaires",     tex = "Interface\\GossipFrame\\DailyActiveQuestIcon" },
    { key = "campaign",   tip = "Campagne",          tex = "Interface\\Icons\\INV_Misc_Book_09" },
    { key = "dungeon",    tip = "Donjon",            tex = "Interface\\LFGFrame\\LFGIcon-Dungeon" },
    { key = "raid",       tip = "Raid",              tex = "Interface\\LFGFrame\\LFGIcon-Raid" },
    { key = "pvp",        tip = "JcJ",               tex = "Interface\\Icons\\Achievement_PVP_A_A" },
    { key = "account",    tip = "Compte / Bataillon", tex = "Interface\\FriendsFrame\\UI-Toast-FriendOnlineIcon" },
    { key = "worldquest", tip = "Quêtes de monde",   tex = "Interface\\Icons\\INV_Misc_Map_01" },
}

-- Couleurs de titre par catégorie (hex sans |cFF).
local CAT_COLOR = {
    classic = "FFD200", daily = "3FC7EB", weekly = "A335EE", campaign = "E6A02C",
    dungeon = "FF8000", raid = "FF4040", pvp = "FFD200", account = "FFD200", worldquest = "33CCFF",
}
local PVP_ICON     = "|TInterface\\Icons\\Achievement_PVP_A_A:13:13|t "
local ACCOUNT_ICON = "|TInterface\\FriendsFrame\\UI-Toast-FriendOnlineIcon:13:13|t "

-- ordre + libellé des sections (séparateurs visuels)
local CAT_ORDER = { "campaign", "worldquest", "weekly", "daily", "dungeon", "raid", "pvp", "account", "classic" }
local CAT_LABEL = {
    campaign = "Campagne", worldquest = "Expéditions", weekly = "Hebdomadaire", daily = "Journalières",
    dungeon = "Donjon", raid = "Raid", pvp = "JcJ", account = "Compte", classic = "Quêtes",
}

local function safeBool(fn, ...)
    if type(fn) ~= "function" then return false end
    local ok, v = pcall(fn, ...)
    return (ok and v) and true or false
end

-- Catégorie primaire + marqueurs (pvp / compte).
local function Classify(qid)
    local idx  = C_QuestLog.GetLogIndexForQuestID and C_QuestLog.GetLogIndexForQuestID(qid)
    local info = idx and C_QuestLog.GetInfo(idx)
    local QF   = Enum and Enum.QuestFrequency
    local isDaily    = info and QF and info.frequency == QF.Daily
    local isWeekly   = info and QF and info.frequency == QF.Weekly
    local isCampaign = info and info.campaignID and info.campaignID ~= 0
    local isWQ       = safeBool(C_QuestLog.IsWorldQuest, qid) or (info and (info.isTask or info.isBounty)) or false

    local tagID
    do local ok, t = pcall(C_QuestLog.GetQuestTagInfo, qid); if ok and t then tagID = t.tagID end end
    local QT = Enum and Enum.QuestTag or {}
    local isPvp     = tagID and tagID == QT.PvP
    local isDungeon = tagID and tagID == QT.Dungeon
    local isRaid    = tagID and tagID == QT.Raid
    local isAccount = safeBool(C_QuestLog.IsAccountQuest, qid)

    local cat
    if isWQ then cat = "worldquest"
    elseif isDaily then cat = "daily"
    elseif isWeekly then cat = "weekly"
    elseif isPvp then cat = "pvp"
    elseif isDungeon then cat = "dungeon"
    elseif isRaid then cat = "raid"
    elseif isCampaign then cat = "campaign"
    elseif isAccount then cat = "account"
    else cat = "classic" end

    return cat, (isPvp and true or false), isAccount
end

local function ApplyIcon(tex, item)
    if item.atlas and pcall(tex.SetAtlas, tex, item.atlas, true) then return end
    tex:SetTexture(item.tex or "Interface\\Icons\\INV_Misc_QuestionMark")
end

-- ------------------------------------------------------------
-- Lignes de quête (pool)
-- ------------------------------------------------------------
local function CreateEntry(self)
    local row = CreateFrame("Frame", nil, self.list)
    row:Hide()
    row.watch = CreateFrame("Button", nil, row)
    row.watch:SetSize(14, 14)
    row.watch:SetPoint("TOPLEFT", row, "TOPLEFT", 0, -1)
    row.watch.text = row.watch:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.watch.text:SetPoint("CENTER")
    row.watch.icon = row.watch:CreateTexture(nil, "ARTWORK"); row.watch.icon:SetAllPoints(row.watch)
    row.watch.hasIcon = (pcall(row.watch.icon.SetAtlas, row.watch.icon, "PetJournal-FavoritesIcon", true) and row.watch.icon:GetAtlas() ~= nil) or false
    if not row.watch.hasIcon then row.watch.icon:Hide() end
    row.watch:SetScript("OnClick", function() self:OnWatchClick(row) end)

    row.hl = row:CreateTexture(nil, "BACKGROUND")
    row.hl:SetAllPoints(row)
    row.hl:SetColorTexture(1, 1, 1, 0.10)
    row.hl:Hide()

    row.title = CreateFrame("Button", nil, row)
    row.title:SetHeight(14)
    row.title:SetPoint("TOPLEFT", row, "TOPLEFT", 16, 0)
    row.title:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, 0)
    row.title:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row.title.text = row.title:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.title.text:SetAllPoints(row.title)
    row.title.text:SetJustifyH("LEFT")
    row.title.text:SetWordWrap(false)
    row.title:SetScript("OnClick", function(_, button) self:OnTitleClick(row, button) end)
    row.title:SetScript("OnEnter", function() row.hl:Show() end)
    row.title:SetScript("OnLeave", function()
        if self._pinnedHL ~= row.questID then row.hl:Hide() end
    end)

    row.objs = {}
    return row
end

local function GetObjLine(row, idx)
    local fs = row.objs[idx]
    if not fs then
        fs = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        fs:SetJustifyH("LEFT")
        fs:SetWordWrap(true)
        row.objs[idx] = fs
    end
    return fs
end

local function RenderRow(self, row, qid, cat, isPvp, isAccount)
    row.questID = qid

    local title
    local okt, t = pcall(C_QuestLog.GetTitleForQuestID, qid)
    if okt and type(t) == "string" and t ~= "" then title = t end
    title = title or ("Quête " .. tostring(qid))

    local complete = false
    pcall(function() complete = C_QuestLog.IsComplete(qid) and true or false end)
    local color = complete and "40FF40" or (CAT_COLOR[cat] or "FFD200")

    -- niveau de quête en préfixe, coloré par difficulté : [80] Titre
    local lvlPrefix = ""
    if C_QuestLog.GetQuestDifficultyLevel then
        local okl, lvl = pcall(C_QuestLog.GetQuestDifficultyLevel, qid)
        if okl and type(lvl) == "number" and lvl > 0 then
            local dc = GetQuestDifficultyColor and GetQuestDifficultyColor(lvl)
            local lhex = dc and ("%02x%02x%02x"):format(dc.r * 255, dc.g * 255, dc.b * 255) or "BBBBBB"
            lvlPrefix = ("|cFF%s[%d]|r "):format(lhex, lvl)
        end
    end

    local prefix = ""
    if isPvp then prefix = prefix .. PVP_ICON end
    if isAccount then prefix = prefix .. ACCOUNT_ICON end
    row.title.text:SetText(prefix .. lvlPrefix .. "|cFF" .. color .. title .. "|r")

    local watched = false
    pcall(function()
        watched = (C_QuestLog.GetQuestWatchType and C_QuestLog.GetQuestWatchType(qid) ~= nil) or false
    end)
    if cat == "worldquest" then
        -- expédition : icône dédiée à la place de l'étoile
        local okA = pcall(row.watch.icon.SetAtlas, row.watch.icon, "worldquest-tracker-questmarker", true)
        if okA and row.watch.icon:GetAtlas() then
            row.watch.icon:Show(); row.watch.icon:SetDesaturated(false); row.watch.icon:SetAlpha(1)
            row.watch.text:SetText("")
        else
            row.watch.text:SetText("|cFF33CCFF!|r")
        end
    elseif row.watch.hasIcon then
        pcall(row.watch.icon.SetAtlas, row.watch.icon, "PetJournal-FavoritesIcon", true)
        row.watch.icon:Show()
        row.watch.icon:SetDesaturated(not watched)
        row.watch.icon:SetAlpha(watched and 1 or 0.4)
        row.watch.text:SetText("")
    else
        row.watch.icon:Hide()
        row.watch.text:SetText(watched and "|cFFFFD200*|r" or "|cFF777777*|r")
    end

    if row.hl then
        -- expédition active (joueur dans la zone de réalisation) = highlight cyan persistant
        local inArea = false
        if cat == "worldquest" and C_TaskQuest and C_TaskQuest.IsActive then
            local okT, act = pcall(C_TaskQuest.IsActive, qid)
            inArea = okT and act or false
        end
        if inArea then
            row.hl:SetColorTexture(0.2, 0.8, 1, 0.14)
            row.hl:Show()
        else
            row.hl:SetColorTexture(1, 1, 1, 0.10)
            row.hl:SetShown(self._pinnedHL == qid)
        end
    end

    local y = 15
    local objectives
    pcall(function() objectives = C_QuestLog.GetQuestObjectives(qid) end)
    objectives = objectives or {}
    local oi = 0
    for _, obj in ipairs(objectives) do
        local otext = obj and obj.text
        if type(otext) == "string" and otext ~= "" then
            oi = oi + 1
            local fs = GetObjLine(row, oi)
            local oc = (obj.finished and "|cFF40FF40" or "|cFFCCCCCC")
            fs:SetText(oc .. "- " .. otext .. "|r")
            fs:ClearAllPoints()
            fs:SetPoint("TOPLEFT", row, "TOPLEFT", 20, -y)
            fs:SetPoint("RIGHT", row, "RIGHT", -2, 0)
            fs:Show()
            local sh = fs:GetStringHeight()
            if type(sh) ~= "number" or sh < 8 then sh = 11 end
            y = y + sh + 2
        end
    end
    for j = oi + 1, #row.objs do if row.objs[j] then row.objs[j]:Hide() end end
    if y < 15 then y = 15 end
    row:SetHeight(y)
    return y
end

-- ============================================================
-- Interface module
-- ============================================================
function M:Init(body)
    self.body = body
    self._pool = {}
    self._usedCount = 0

    -- Toolbar de filtres (haut du module)
    self.toolbar = CreateFrame("Frame", nil, body)
    self.toolbar:SetPoint("TOPLEFT", body, "TOPLEFT", 2, -2)
    self.toolbar:SetPoint("TOPRIGHT", body, "TOPRIGHT", -2, -2)
    self.toolbar:SetHeight(TOOLBAR_H)
    self.filterBtns = {}
    local x = 0
    for _, item in ipairs(FILTERS) do
        local b = CreateFrame("Button", nil, self.toolbar)
        b:SetSize(FBTN, FBTN)
        b:SetPoint("LEFT", self.toolbar, "LEFT", x, 0)
        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.icon:SetAllPoints(b)
        ApplyIcon(b.icon, item)
        b.fkey, b.tip = item.key, item.tip
        b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        b:SetScript("OnClick", function(s, mouse)
            if mouse == "RightButton" then self:IsolateFilter(s.fkey) else self:ToggleFilter(s.fkey) end
        end)
        b:SetScript("OnEnter", function(s)
            SP:AnchorTooltipOutsidePanel(GameTooltip, s)
            local f = SP:GetModuleConfig(self.name).filters
            GameTooltip:SetText(s.tip .. (f[s.fkey] and " |cFF40FF40(affiché)|r" or " |cFFFF5555(masqué)|r"))
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        self.filterBtns[item.key] = b
        x = x + FBTN + 2
    end

    -- Conteneur de la liste (sous la toolbar, clippé)
    self.list = CreateFrame("Frame", nil, body)
    self.list:SetPoint("TOPLEFT", self.toolbar, "BOTTOMLEFT", -2, -2)
    self.list:SetPoint("BOTTOMRIGHT", body, "BOTTOMRIGHT", 0, 0)
    self.list:SetClipsChildren(true)
    self.scroll = 0
    self.list:EnableMouseWheel(true)
    self.list:SetScript("OnMouseWheel", function(_, delta)
        local visible = self.list:GetHeight() or 1
        local maxS = math.max(0, (self._contentH or 0) - visible)
        self.scroll = math.min(maxS, math.max(0, self.scroll - delta * 24))
        self:Refresh()
    end)

    self.emptyText = self.list:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    self.emptyText:SetPoint("TOP", self.list, "TOP", 0, -8)
    self.emptyText:SetText("Aucune quête suivie")
    self.emptyText:Hide()

    self.ev = CreateFrame("Frame")
    self.ev:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_ENTERING_WORLD" then self:PrewarmPool(30) end
        if event == "QUEST_ACCEPTED" and self._loginDone then SP:RevealModule(self, 6) end  -- notif nouvelle quête
        self:HideBlizzard()
        self:RequestRefresh()
    end)

    self:UpdateFilterVisuals()
end

function M:Enable()
    self._enabled = true
    self:PrewarmPool(30)
    self:HideBlizzard()
    for _, e in ipairs(QUEST_EVENTS) do pcall(self.ev.RegisterEvent, self.ev, e) end
    if self._placeholder then self._placeholder:Hide() end
    self:RequestRefresh()
end

function M:Disable()
    self._enabled = false
    if self.ev then self.ev:UnregisterAllEvents() end
    self:ReleaseAll()
    if self.emptyText then self.emptyText:Hide() end
    SP:SetModuleHeaderText(self, "")
    self:RestoreBlizzard()
end

function M:OnResize(w, h) self:RequestRefresh() end

-- ------------------------------------------------------------
-- Filtres
-- ------------------------------------------------------------
function M:ToggleFilter(key)
    local f = SP:GetModuleConfig(self.name).filters
    f[key] = not f[key]
    self._isolated = nil   -- un toggle manuel sort du mode isolé
    self:UpdateFilterVisuals()
    self:RequestRefresh()
end

-- Clic droit : n'afficher QUE cette catégorie ; reclic = restaure l'état précédent.
function M:IsolateFilter(key)
    local f = SP:GetModuleConfig(self.name).filters
    if self._isolated == key then
        if self._savedFilters then for k, v in pairs(self._savedFilters) do f[k] = v end end
        self._isolated, self._savedFilters = nil, nil
    else
        if not self._savedFilters then
            self._savedFilters = {}
            for k, v in pairs(f) do self._savedFilters[k] = v end
        end
        for k in pairs(f) do f[k] = (k == key) end
        self._isolated = key
    end
    self:UpdateFilterVisuals()
    self:RequestRefresh()
end

function M:UpdateFilterVisuals()
    local f = SP:GetModuleConfig(self.name).filters
    for key, b in pairs(self.filterBtns) do
        local active = f[key]
        b.icon:SetDesaturated(not active)
        b:SetAlpha(active and 1 or 0.35)
    end
end

-- ============================================================
-- ObjectiveTrackerFrame natif
-- ============================================================
function M:HideBlizzard()
    local otf = _G.ObjectiveTrackerFrame
    if not otf then return end
    if self._otfHidden == nil then self._otfWasShown = otf:IsShown() and true or false end
    self._otfHidden = true
    -- Post-hook sécurisé : re-masque dès que Blizzard tente de le ré-afficher
    -- (fin de combat / Edit Mode / updates internes ne passent pas par nos events).
    if not self._otfShowHook then
        self._otfShowHook = true
        hooksecurefunc(otf, "Show", function(s)
            if self._enabled then pcall(s.Hide, s) end
        end)
    end
    if otf:IsShown() then pcall(otf.Hide, otf) end
end

function M:RestoreBlizzard()
    local otf = _G.ObjectiveTrackerFrame
    if not otf then return end
    if self._otfHidden and self._otfWasShown then pcall(otf.Show, otf) end
    self._otfHidden = nil
end

-- ============================================================
-- Pool
-- ============================================================
function M:PrewarmPool(count)
    if InCombatLockdown() then return end
    for i = #self._pool + 1, count do self._pool[i] = CreateEntry(self) end
end

function M:AcquireEntry()
    self._usedCount = self._usedCount + 1
    local row = self._pool[self._usedCount]
    if not row then
        if InCombatLockdown() then self._usedCount = self._usedCount - 1; return nil end
        row = CreateEntry(self)
        self._pool[self._usedCount] = row
    end
    return row
end

-- Séparateur de section : libellé + trait.
function M:AcquireSep()
    self._seps = self._seps or {}
    self._sepUsed = (self._sepUsed or 0) + 1
    local s = self._seps[self._sepUsed]
    if not s then
        s = CreateFrame("Frame", nil, self.list); s:SetHeight(14)
        s.fs = s:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        s.fs:SetPoint("LEFT", s, "LEFT", 2, 0)
        s.line = s:CreateTexture(nil, "ARTWORK"); s.line:SetHeight(1)
        s.line:SetPoint("RIGHT", s, "RIGHT", -2, 0)
        s.line:SetPoint("LEFT", s.fs, "RIGHT", 6, 0)
        self._seps[self._sepUsed] = s
    end
    return s
end

function M:ReleaseAll()
    for i = 1, self._usedCount do if self._pool[i] then self._pool[i]:Hide() end end
    self._usedCount = 0
end

-- ============================================================
-- Quêtes suivies
-- ============================================================
function M:GetTrackedQuestIDs()
    local ids, seen = {}, {}
    local function add(qid)
        if type(qid) == "number" and qid ~= 0 and not seen[qid] then
            seen[qid] = true; ids[#ids + 1] = qid
        end
    end
    if C_SuperTrack and C_SuperTrack.GetSuperTrackedQuestID then
        local ok, sq = pcall(C_SuperTrack.GetSuperTrackedQuestID); if ok then add(sq) end
    end
    local nw = 0
    pcall(function() nw = C_QuestLog.GetNumQuestWatches() or 0 end)
    for i = 1, nw do
        local ok, qid = pcall(C_QuestLog.GetQuestIDForQuestWatchIndex, i); if ok then add(qid) end
    end
    if C_QuestLog.GetNumWorldQuestWatches then
        local nww = 0
        pcall(function() nww = C_QuestLog.GetNumWorldQuestWatches() or 0 end)
        for i = 1, nww do
            local ok, qid = pcall(C_QuestLog.GetQuestIDForWorldQuestWatchIndex, i); if ok then add(qid) end
        end
    end
    -- expéditions / quêtes mondiales / objectifs bonus de la ZONE COURANTE
    -- (méthode du suivi Blizzard : les tâches sont attachées à la carte, pas au journal)
    if C_TaskQuest and C_TaskQuest.GetQuestsForPlayerByMapID and C_Map and C_Map.GetBestMapForUnit then
        local mapID = C_Map.GetBestMapForUnit("player")
        if mapID then
            local ok, tasks = pcall(C_TaskQuest.GetQuestsForPlayerByMapID, mapID)
            if ok and type(tasks) == "table" then
                for _, t in ipairs(tasks) do
                    add(t.questID or t.questId)
                end
            end
        end
    end
    return ids
end

-- Compteur bandeau : quêtes AFFICHÉES (suivies) / total du journal.
function M:UpdateCounter()
    local shown = #self:GetTrackedQuestIDs()
    local total = 0
    local n = C_QuestLog.GetNumQuestLogEntries() or 0
    for i = 1, n do
        local info = C_QuestLog.GetInfo(i)
        if info and not info.isHeader then total = total + 1 end
    end
    SP:SetModuleHeaderText(self, ("%d / %d"):format(shown, total))
end

-- ============================================================
-- Refresh
-- ============================================================
function M:RequestRefresh()
    if not self._enabled then return end
    if self._pending then return end
    self._pending = true
    C_Timer.After(0.1, function() self._pending = false; self:Refresh() end)
end

function M:Refresh()
    if not self._enabled or not self.body then return end
    self:HideBlizzard()
    self:ReleaseAll()
    self:UpdateCounter()

    local filters = SP:GetModuleConfig(self.name).filters
    local ids = self:GetTrackedQuestIDs()
    self._sepUsed = 0

    -- regroupe par catégorie
    local buckets = {}
    for _, qid in ipairs(ids) do
        local cat, isPvp, isAccount = Classify(qid)
        if filters[cat] ~= false then
            buckets[cat] = buckets[cat] or {}
            table.insert(buckets[cat], { qid = qid, pvp = isPvp, acc = isAccount })
        end
    end

    -- auto-ouverture si une NOUVELLE expédition apparaît
    self._seenWQ = self._seenWQ or {}
    if buckets.worldquest then
        for _, e in ipairs(buckets.worldquest) do
            if not self._seenWQ[e.qid] then
                self._seenWQ[e.qid] = true
                if self._loginDone then SP:RevealModule(self, 6) end
            end
        end
    end
    self._loginDone = true

    local y = 4
    local count = 0
    for _, cat in ipairs(CAT_ORDER) do
        local list = buckets[cat]
        if list and #list > 0 then
            -- séparateur de section
            local sep = self:AcquireSep()
            local hex = CAT_COLOR[cat] or "FFD200"
            sep.fs:SetText("|cFF" .. hex .. (CAT_LABEL[cat] or cat) .. "|r")
            local r, g, b = tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255
            sep.line:SetColorTexture(r, g, b, 0.35)
            sep:ClearAllPoints()
            sep:SetPoint("TOPLEFT", self.list, "TOPLEFT", 2, -(y - self.scroll))
            sep:SetPoint("TOPRIGHT", self.list, "TOPRIGHT", -2, -(y - self.scroll))
            sep:Show()
            y = y + 16

            for _, e in ipairs(list) do
                local row = self:AcquireEntry()
                if not row then break end
                row:ClearAllPoints()
                row:SetPoint("TOPLEFT",  self.list, "TOPLEFT",  2, -(y - self.scroll))
                row:SetPoint("TOPRIGHT", self.list, "TOPRIGHT", -2, -(y - self.scroll))
                local ok, h = pcall(RenderRow, self, row, e.qid, cat, e.pvp, e.acc)
                if not ok or type(h) ~= "number" then h = 15 end
                row:Show()
                y = y + h + 4
                count = count + 1
            end
        end
    end
    -- masque les séparateurs inutilisés
    if self._seps then for i = self._sepUsed + 1, #self._seps do self._seps[i]:Hide() end end
    self._contentH = y
    local visible = self.list:GetHeight() or 1
    if self.scroll > math.max(0, y - visible) then self.scroll = math.max(0, y - visible) end
    self.emptyText:SetShown(count == 0)
    if self._placeholder then self._placeholder:Hide() end
end

-- ============================================================
-- Actions
-- ============================================================
function M:OnTitleClick(row, button)
    local qid = row.questID
    if not qid then return end
    if button == "RightButton" then
        -- suivi principal + highlight persistant, SANS ouvrir la carte ; reclic = retire
        if self._pinnedHL == qid then
            self._pinnedHL = nil
        else
            self._pinnedHL = qid
            if C_SuperTrack and C_SuperTrack.SetSuperTrackedQuestID then
                pcall(C_SuperTrack.SetSuperTrackedQuestID, qid)
            end
        end
        self:RequestRefresh()
    else
        -- clic gauche : ouvre le journal de quête sur cette quête
        if QuestMapFrame_OpenToQuestDetails then pcall(QuestMapFrame_OpenToQuestDetails, qid) end
    end
end

function M:OnWatchClick(row)
    local qid = row.questID
    if not qid then return end
    local watched = false
    pcall(function()
        watched = (C_QuestLog.GetQuestWatchType and C_QuestLog.GetQuestWatchType(qid) ~= nil) or false
    end)
    if watched then pcall(C_QuestLog.RemoveQuestWatch, qid)
    else pcall(C_QuestLog.AddQuestWatch, qid) end
    self:RequestRefresh()
end

SP:RegisterModule(M)
