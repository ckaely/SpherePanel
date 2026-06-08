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
    local isWQ       = safeBool(C_QuestLog.IsWorldQuest, qid)

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
    row.watch:SetScript("OnClick", function() self:OnWatchClick(row) end)

    row.title = CreateFrame("Button", nil, row)
    row.title:SetHeight(14)
    row.title:SetPoint("TOPLEFT", row, "TOPLEFT", 16, 0)
    row.title:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, 0)
    row.title.text = row.title:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.title.text:SetAllPoints(row.title)
    row.title.text:SetJustifyH("LEFT")
    row.title.text:SetWordWrap(false)
    row.title:SetScript("OnClick", function() self:OnTitleClick(row) end)

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

    local prefix = ""
    if isPvp then prefix = prefix .. PVP_ICON end
    if isAccount then prefix = prefix .. ACCOUNT_ICON end
    row.title.text:SetText(prefix .. "|cFF" .. color .. title .. "|r")

    local watched = false
    pcall(function()
        watched = (C_QuestLog.GetQuestWatchType and C_QuestLog.GetQuestWatchType(qid) ~= nil) or false
    end)
    row.watch.text:SetText(watched and "|cFFFFD200*|r" or "|cFF777777*|r")

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
        b:SetScript("OnClick", function(s) self:ToggleFilter(s.fkey) end)
        b:SetScript("OnEnter", function(s)
            GameTooltip:SetOwner(s, "ANCHOR_BOTTOM")
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

    self.emptyText = self.list:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    self.emptyText:SetPoint("TOP", self.list, "TOP", 0, -8)
    self.emptyText:SetText("Aucune quête suivie")
    self.emptyText:Hide()

    self.ev = CreateFrame("Frame")
    self.ev:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_ENTERING_WORLD" then self:PrewarmPool(30) end
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
    return ids
end

-- Compteur total/max pour le bandeau.
function M:UpdateCounter()
    local total = 0
    local n = C_QuestLog.GetNumQuestLogEntries() or 0
    for i = 1, n do
        local info = C_QuestLog.GetInfo(i)
        if info and not info.isHeader then total = total + 1 end
    end
    local max = (C_QuestLog.GetMaxNumQuests and C_QuestLog.GetMaxNumQuests()) or 35
    SP:SetModuleHeaderText(self, ("%d / %d"):format(total, max))
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
    local y = 4
    local count = 0
    for _, qid in ipairs(ids) do
        local cat, isPvp, isAccount = Classify(qid)
        if filters[cat] ~= false then
            local row = self:AcquireEntry()
            if not row then break end
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT",  self.list, "TOPLEFT",  2, -y)
            row:SetPoint("TOPRIGHT", self.list, "TOPRIGHT", -2, -y)
            local ok, h = pcall(RenderRow, self, row, qid, cat, isPvp, isAccount)
            if not ok or type(h) ~= "number" then h = 15 end
            row:Show()
            y = y + h + 4
            count = count + 1
        end
    end
    self.emptyText:SetShown(count == 0)
    if self._placeholder then self._placeholder:Hide() end
end

-- ============================================================
-- Actions
-- ============================================================
function M:OnTitleClick(row)
    local qid = row.questID
    if not qid then return end
    if C_SuperTrack and C_SuperTrack.SetSuperTrackedQuestID then
        pcall(C_SuperTrack.SetSuperTrackedQuestID, qid)
    end
    if QuestMapFrame_OpenToQuestDetails then pcall(QuestMapFrame_OpenToQuestDetails, qid) end
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
