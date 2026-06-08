-- ============================================================
-- Module : QuestTracker — remplace le traqueur de quêtes natif
-- ============================================================
-- Étape 4 — core. Masque ObjectiveTrackerFrame, liste les quêtes via C_QuestLog.
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

-- ------------------------------------------------------------
-- Création d'une ligne de quête (frame + bouton titre + toggle montre).
-- Appelé UNIQUEMENT hors combat (prewarm ou AcquireEntry guardé).
-- ------------------------------------------------------------
local function CreateEntry(self)
    local row = CreateFrame("Frame", nil, self.body)
    row:Hide()

    -- Toggle montre (★)
    row.watch = CreateFrame("Button", nil, row)
    row.watch:SetSize(14, 14)
    row.watch:SetPoint("TOPLEFT", row, "TOPLEFT", 0, -1)
    row.watch.text = row.watch:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.watch.text:SetPoint("CENTER")
    row.watch:SetScript("OnClick", function() self:OnWatchClick(row) end)

    -- Titre cliquable
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

-- FontString d'objectif (région : création en combat autorisée).
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

-- Rendu d'une ligne. Retourne sa hauteur. Encapsulé sous pcall par l'appelant.
local function RenderRow(self, row, info)
    local qid = info.questID
    row.questID = qid

    local title = info.title
    if not title or title == "" then
        local ok, t = pcall(C_QuestLog.GetTitleForQuestID, qid)
        if ok and type(t) == "string" then title = t end
    end
    title = title or ("Quête " .. tostring(qid))

    local complete = false
    pcall(function() complete = C_QuestLog.IsComplete(qid) and true or false end)
    local col = complete and "|cFF40FF40" or "|cFFFFD200"
    row.title.text:SetText(col .. title .. "|r")

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
            local done = obj.finished and true or false
            local oc = done and "|cFF40FF40" or "|cFFCCCCCC"
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
    for j = oi + 1, #row.objs do
        if row.objs[j] then row.objs[j]:Hide() end
    end

    if y < 15 then y = 15 end
    row:SetHeight(y)
    return y
end

-- ============================================================
-- Interface module
-- ============================================================
function M:Init(body)
    self.body = body
    body:SetClipsChildren(true)
    self._pool = {}
    self._usedCount = 0

    self.emptyText = body:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    self.emptyText:SetPoint("TOP", body, "TOP", 0, -8)
    self.emptyText:SetText("Aucune quête active")
    self.emptyText:Hide()

    self.ev = CreateFrame("Frame")
    self.ev:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_ENTERING_WORLD" then self:PrewarmPool(30) end
        self:RequestRefresh()
    end)
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
    self:RestoreBlizzard()
end

function M:OnResize(w, h)
    self:RequestRefresh()
end

-- ============================================================
-- ObjectiveTrackerFrame natif
-- ============================================================
function M:HideBlizzard()
    local otf = _G.ObjectiveTrackerFrame
    if not otf then return end
    if self._otfHidden == nil then
        -- capture l'état d'origine une seule fois (pour restauration à Disable)
        self._otfWasShown = otf:IsShown() and true or false
    end
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
-- Pool de lignes
-- ============================================================
function M:PrewarmPool(count)
    if InCombatLockdown() then return end
    for i = #self._pool + 1, count do
        self._pool[i] = CreateEntry(self)
    end
end

function M:AcquireEntry()
    self._usedCount = self._usedCount + 1
    local row = self._pool[self._usedCount]
    if not row then
        if InCombatLockdown() then
            self._usedCount = self._usedCount - 1
            return nil
        end
        row = CreateEntry(self)
        self._pool[self._usedCount] = row
    end
    return row
end

function M:ReleaseAll()
    for i = 1, self._usedCount do
        local row = self._pool[i]
        if row then row:Hide() end
    end
    self._usedCount = 0
end

-- ============================================================
-- Refresh (débounced)
-- ============================================================
function M:RequestRefresh()
    if not self._enabled then return end
    if self._pending then return end
    self._pending = true
    C_Timer.After(0.1, function()
        self._pending = false
        self:Refresh()
    end)
end

function M:Refresh()
    if not self._enabled or not self.body then return end
    self:HideBlizzard()
    self:ReleaseAll()

    local n = C_QuestLog.GetNumQuestLogEntries() or 0
    local y = 4
    local count = 0
    for i = 1, n do
        local info = C_QuestLog.GetInfo(i)
        if info and not info.isHeader and not info.isHidden then
            local row = self:AcquireEntry()
            if not row then break end   -- pool épuisé en combat → on s'arrête proprement
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT",  self.body, "TOPLEFT",  2, -y)
            row:SetPoint("TOPRIGHT", self.body, "TOPRIGHT", -2, -y)
            local ok, h = pcall(RenderRow, self, row, info)
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
    if QuestMapFrame_OpenToQuestDetails then
        pcall(QuestMapFrame_OpenToQuestDetails, qid)
    end
end

function M:OnWatchClick(row)
    local qid = row.questID
    if not qid then return end
    local watched = false
    pcall(function()
        watched = (C_QuestLog.GetQuestWatchType and C_QuestLog.GetQuestWatchType(qid) ~= nil) or false
    end)
    if watched then
        pcall(C_QuestLog.RemoveQuestWatch, qid)
    else
        pcall(C_QuestLog.AddQuestWatch, qid)
    end
    self:RequestRefresh()
end

SP:RegisterModule(M)
