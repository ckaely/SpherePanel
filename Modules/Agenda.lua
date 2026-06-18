-- ============================================================
-- Module : Agenda - calendrier + evenements locaux
-- ============================================================
local ADDON_NAME, SP = ...

local M = {
    name          = "Agenda",
    label         = "Agenda",
    defaultHeight = 180,
    headerHeight  = 38,
}

local DAYS = { "Dim", "Lun", "Mar", "Mer", "Jeu", "Ven", "Sam" }
local ROW_H, SECTION_H, GAP = 46, 22, 5
local ICON_UNKNOWN = "Interface\\Icons\\INV_Misc_QuestionMark"
local ICON_CALENDAR = "Interface\\Icons\\INV_Misc_Note_01"
local ICON_WORLD = "Interface\\Icons\\INV_Misc_Map_01"
local ICON_ABUNDANCE = "Interface\\Icons\\INV_10_DungeonJewelry_Titan_Trinket_1"

-- Programme local connu. Blizzard expose certains evenements via AreaPOI,
-- mais pas toujours le planning complet dans une API stable.
local LOCAL_PROGRAM = {
    { title = "Abondance : grotte d'herboristerie", zone = "Harandar", hour = 6,  minute = 0, duration = 4 * 3600, icon = ICON_ABUNDANCE },
    { title = "Abondance : crypte d'enchantement", zone = "Bois des Chants eternels", hour = 14, minute = 0, duration = 4 * 3600, icon = ICON_ABUNDANCE },
    { title = "Abondance : taniere de depecage", zone = "Zul'Aman", hour = 22, minute = 0, duration = 4 * 3600, icon = ICON_ABUNDANCE },
}

local function Clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

local function FormatClock(hour, minute)
    return ("%02d:%02d"):format(hour or 0, minute or 0)
end

local function FormatRemaining(sec)
    sec = tonumber(sec)
    if not sec or sec <= 0 then return nil end
    local h = math.floor(sec / 3600)
    local m = math.floor((sec % 3600) / 60)
    if h > 0 then return ("%dh%02d"):format(h, m) end
    return ("%dm"):format(m)
end

local function TodayStamp(hour, minute, dayOffset)
    local now = time()
    local d = date("*t", now + (dayOffset or 0) * 86400)
    d.hour, d.min, d.sec = hour or 0, minute or 0, 0
    return time(d)
end

local function MonthDay(dayOffset)
    local d = date("*t", time() + (dayOffset or 0) * 86400)
    return d.day, d.month
end

local function PaintIcon(tex, item)
    tex:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    if item and item.atlas and tex.SetAtlas then
        local ok = pcall(tex.SetAtlas, tex, item.atlas, true)
        if ok then return end
    end
    if item and item.icon then
        local ok = pcall(tex.SetTexture, tex, item.icon)
        if ok then return end
    end
    tex:SetTexture(ICON_UNKNOWN)
end

local function LowerText(s)
    s = tostring(s or "")
    return string.lower(s:gsub("['’]", "'"))
end

function M:Init(body)
    self.body = body
    self.rows = {}
    self.scroll = 0

    -- Onglets directement dans le bandeau du module.
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
        self.tabBtns = {}
        local prev = nil
        for _, d in ipairs({ { "events", "Evenements", 74 }, { "calendar", "Calendrier", 78 } }) do
            local b = CreateFrame("Button", nil, self.header)
            b:SetSize(d[3], 16)
            b:SetFrameLevel((self.header:GetFrameLevel() or 1) + 3)
            if prev then b:SetPoint("LEFT", prev, "RIGHT", 5, 0)
            else b:SetPoint("BOTTOMLEFT", self.header, "BOTTOMLEFT", 8, 2) end
            b.hl = b:CreateTexture(nil, "BACKGROUND")
            b.hl:SetAllPoints(b)
            b.hl:SetColorTexture(0.30, 0.55, 0.95, 0.30)
            b.hl:Hide()
            b.fs = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            b.fs:SetAllPoints(b)
            b.fs:SetText(d[2])
            b.tab = d[1]
            b:SetScript("OnClick", function(s, button)
                if button == "RightButton" and s.tab == "calendar" then
                    if ToggleCalendar then pcall(ToggleCalendar) end
                    return
                end
                self:SetAgendaTab(s.tab)
            end)
            b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            self.tabBtns[d[1]] = b
            prev = b
        end
        self.header:EnableMouseWheel(true)
        self.header:SetScript("OnMouseWheel", function(_, delta)
            self:SetAgendaTab(delta > 0 and "calendar" or "events")
        end)
    end

    self.list = CreateFrame("Frame", nil, body)
    self.list:SetPoint("TOPLEFT", body, "TOPLEFT", 4, -3)
    self.list:SetPoint("BOTTOMRIGHT", body, "BOTTOMRIGHT", -10, 3)
    self.list:SetClipsChildren(true)
    self.list:EnableMouseWheel(true)
    self.list:SetScript("OnMouseWheel", function(_, delta)
        self:SetScroll((self.scroll or 0) - delta * 34)
    end)

    self.scrollTrack = CreateFrame("Frame", nil, body)
    self.scrollTrack:SetPoint("TOPRIGHT", body, "TOPRIGHT", -3, -5)
    self.scrollTrack:SetPoint("BOTTOMRIGHT", body, "BOTTOMRIGHT", -3, 5)
    self.scrollTrack:SetWidth(3)
    self.scrollTrack.bg = self.scrollTrack:CreateTexture(nil, "BACKGROUND")
    self.scrollTrack.bg:SetAllPoints(self.scrollTrack)
    self.scrollTrack.bg:SetColorTexture(1, 1, 1, 0.07)
    self.scrollThumb = self.scrollTrack:CreateTexture(nil, "ARTWORK")
    self.scrollThumb:SetColorTexture(0.85, 0.85, 0.85, 0.38)

    self.empty = self.list:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    self.empty:SetPoint("TOP", self.list, "TOP", 0, -10)
    self.empty:SetText("Aucun evenement")
    self.empty:Hide()

    self.ev = CreateFrame("Frame")
    self.ev:SetScript("OnEvent", function(_, event)
        if event == "CALENDAR_UPDATE_EVENT_LIST"
            or event == "PLAYER_ENTERING_WORLD"
            or event == "ZONE_CHANGED_NEW_AREA"
            or event == "ZONE_CHANGED"
            or event == "QUEST_LOG_UPDATE" then
            self:RequestRefresh()
        end
    end)
end

function M:Enable()
    self._enabled = true
    if self._placeholder then self._placeholder:Hide() end
    pcall(self.ev.RegisterEvent, self.ev, "CALENDAR_UPDATE_EVENT_LIST")
    pcall(self.ev.RegisterEvent, self.ev, "PLAYER_ENTERING_WORLD")
    pcall(self.ev.RegisterEvent, self.ev, "ZONE_CHANGED_NEW_AREA")
    pcall(self.ev.RegisterEvent, self.ev, "ZONE_CHANGED")
    pcall(self.ev.RegisterEvent, self.ev, "QUEST_LOG_UPDATE")
    if C_Calendar and C_Calendar.OpenCalendar then pcall(C_Calendar.OpenCalendar) end
    if not self._clock then
        self._clock = C_Timer.NewTicker(30, function()
            self:UpdateHeader()
            if (SP:GetModuleConfig(self.name) or {}).activeTab == "events" then self:RequestRefresh() end
        end)
    end
    self:UpdateHeader()
    self:SetAgendaTab((SP:GetModuleConfig(self.name) or {}).activeTab or "events")
    self:RequestRefresh()
end

function M:Disable()
    self._enabled = false
    if self.ev then self.ev:UnregisterAllEvents() end
    if self._clock then self._clock:Cancel(); self._clock = nil end
    for _, r in ipairs(self.rows) do r:Hide() end
    SP:SetModuleHeaderText(self, "")
end

function M:OnResize(w, h)
    self:UpdateScrollBar()
end

function M:SetAgendaTab(tab)
    local cfg = SP:GetModuleConfig(self.name)
    cfg.activeTab = (tab == "calendar") and "calendar" or "events"
    for k, b in pairs(self.tabBtns or {}) do
        if b.hl then b.hl:SetShown(k == cfg.activeTab) end
    end
    self.scroll = 0
    self:RequestRefresh()
end

function M:UpdateHeader()
    local t = C_DateAndTime and C_DateAndTime.GetCurrentCalendarTime and C_DateAndTime.GetCurrentCalendarTime()
    if t then
        SP:SetModuleHeaderText(self, ("%s %02d/%02d  %02d:%02d")
            :format(DAYS[(t.weekday or 1)] or "", t.monthDay or 0, t.month or 0, t.hour or 0, t.minute or 0))
    else
        SP:SetModuleHeaderText(self, date("%d/%m %H:%M"))
    end
end

function M:RequestRefresh()
    if not self._enabled or self._pending then return end
    self._pending = true
    C_Timer.After(0.2, function()
        self._pending = false
        if self._enabled then self:Refresh() end
    end)
end

function M:SetScroll(v)
    local visible = self.list and (self.list:GetHeight() or 1) or 1
    local maxS = math.max(0, (self._contentH or 0) - visible)
    self.scroll = Clamp(v or 0, 0, maxS)
    self:Refresh()
end

function M:UpdateScrollBar()
    if not (self.scrollTrack and self.scrollThumb and self.list) then return end
    local visible = self.list:GetHeight() or 1
    local total = math.max(visible, self._contentH or 0)
    local trackH = self.scrollTrack:GetHeight() or visible
    local thumbH = Clamp(trackH * (visible / total), 16, trackH)
    local maxS = math.max(0, total - visible)
    local frac = (maxS > 0) and ((self.scroll or 0) / maxS) or 0
    self.scrollThumb:ClearAllPoints()
    self.scrollThumb:SetHeight(thumbH)
    self.scrollThumb:SetPoint("TOPLEFT", self.scrollTrack, "TOPLEFT", 0, -((trackH - thumbH) * frac))
    self.scrollThumb:SetPoint("TOPRIGHT", self.scrollTrack, "TOPRIGHT", 0, -((trackH - thumbH) * frac))
    self.scrollTrack:SetShown(maxS > 0)
end

local function GetRow(self, i)
    local r = self.rows[i]
    if not r then
        r = CreateFrame("Frame", nil, self.list)
        r.bg = r:CreateTexture(nil, "BACKGROUND")
        r.bg:SetAllPoints(r)
        r.bg:SetColorTexture(0.08, 0.07, 0.06, 0.58)
        r.line = r:CreateTexture(nil, "ARTWORK")
        r.line:SetPoint("BOTTOMLEFT", r, "BOTTOMLEFT", 0, 0)
        r.line:SetPoint("BOTTOMRIGHT", r, "BOTTOMRIGHT", 0, 0)
        r.line:SetHeight(1)
        r.line:SetColorTexture(1, 1, 1, 0.06)
        r.icon = r:CreateTexture(nil, "OVERLAY")
        r.icon:SetSize(28, 28)
        r.icon:SetPoint("LEFT", r, "LEFT", 6, 0)
        r.tag = r:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        r.tag._spFontRole = "secondary"
        r.tag:SetPoint("TOPLEFT", r.icon, "TOPRIGHT", 8, -4)
        r.tag:SetPoint("RIGHT", r, "RIGHT", -6, 0)
        r.tag:SetJustifyH("LEFT")
        r.title = r:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        r.title:SetPoint("TOPLEFT", r.icon, "TOPRIGHT", 8, -18)
        r.title:SetPoint("RIGHT", r, "RIGHT", -6, 0)
        r.title:SetJustifyH("LEFT")
        r.title:SetWordWrap(false)
        r.header = r:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        r.header:SetPoint("LEFT", r, "LEFT", 6, 0)
        r.header:SetPoint("RIGHT", r, "RIGHT", -6, 0)
        r.header:SetJustifyH("LEFT")
        self.rows[i] = r
    end
    return r
end

local function PutSection(self, rows, text)
    rows[#rows + 1] = { kind = "section", text = text }
end

local function PutEntry(rows, item)
    rows[#rows + 1] = item
end

function M:CollectZoneEvents()
    local out, seen = {}, {}
    local mapID = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
    if mapID and C_AreaPoiInfo and C_AreaPoiInfo.GetAreaPOIForMap and C_AreaPoiInfo.GetAreaPOIInfo then
        local ok, pois = pcall(C_AreaPoiInfo.GetAreaPOIForMap, mapID)
        if ok and pois then
            for _, poiID in ipairs(pois) do
                local okInfo, info = pcall(C_AreaPoiInfo.GetAreaPOIInfo, mapID, poiID)
                if okInfo and info and info.name and not seen["poi" .. tostring(poiID)] then
                    seen["poi" .. tostring(poiID)] = true
                    local left = FormatRemaining(info.secondsRemaining or info.timeLeft)
                    out[#out + 1] = {
                        title = info.name,
                        detail = info.description or (left and ("Encore " .. left) or "Evenement local"),
                        tag = left or "En cours",
                        icon = info.icon or info.texture or info.textureIndex or ICON_WORLD,
                        atlas = info.atlasName,
                        color = "FFD200",
                    }
                end
            end
        end
    end
    if mapID and C_TaskQuest and C_TaskQuest.GetQuestsOnMap then
        local ok, quests = pcall(C_TaskQuest.GetQuestsOnMap, mapID)
        if ok and quests then
            for _, q in ipairs(quests) do
                local qid = q.questID
                if qid and not seen["q" .. qid] then
                    seen["q" .. qid] = true
                    local title = (C_QuestLog and C_QuestLog.GetTitleForQuestID and C_QuestLog.GetTitleForQuestID(qid)) or ("Expedition " .. qid)
                    local left = C_TaskQuest.GetQuestTimeLeftMinutes and C_TaskQuest.GetQuestTimeLeftMinutes(qid)
                    local tag = left and (left >= 60 and ("%dh%02d"):format(math.floor(left / 60), left % 60) or (left .. "m")) or "Exped."
                    out[#out + 1] = { tag = tag, title = title, detail = "Carte locale", icon = ICON_WORLD, color = "40FF80" }
                end
            end
        end
    end
    table.sort(out, function(a, b) return (a.title or "") < (b.title or "") end)
    return out
end

function M:CollectProgram()
    local now = time()
    local active, upcoming = {}, {}
    for day = 0, 2 do
        for _, e in ipairs(LOCAL_PROGRAM) do
            local start = TodayStamp(e.hour, e.minute, day)
            local finish = start + (e.duration or 3600)
            local copy = {
                title = e.title,
                detail = FormatClock(e.hour, e.minute) .. " - " .. e.zone,
                tag = day == 0 and "Aujourd'hui" or (("%02d/%02d"):format(MonthDay(day))),
                icon = self._programIcon or e.icon,
                color = "FFD200",
                start = start,
            }
            if now >= start and now < finish then
                copy.tag = "En cours"
                copy.detail = e.zone .. " - reste " .. (FormatRemaining(finish - now) or "")
                active[#active + 1] = copy
            elseif start >= now then
                upcoming[#upcoming + 1] = copy
            end
        end
    end
    table.sort(upcoming, function(a, b) return (a.start or 0) < (b.start or 0) end)
    return active, upcoming
end

function M:RenderRows(rows)
    local ri, y = 0, 2
    local w = (self.list:GetWidth() or 260)
    for _, item in ipairs(rows) do
        ri = ri + 1
        local r = GetRow(self, ri)
        local h = (item.kind == "section") and SECTION_H or ROW_H
        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", self.list, "TOPLEFT", 0, -(y - (self.scroll or 0)))
        r:SetWidth(w)
        r:SetHeight(h)
        if item.kind == "section" then
            r.bg:SetColorTexture(0.12, 0.10, 0.09, 0.74)
            r.icon:Hide(); r.tag:Hide(); r.title:Hide()
            r.header:SetText("|cFFAAAAAA" .. (item.text or "") .. "|r")
            r.header:Show()
        else
            r.bg:SetColorTexture(0.08, 0.07, 0.06, 0.58)
            r.header:Hide(); r.icon:Show(); r.tag:Show(); r.title:Show()
            PaintIcon(r.icon, item)
            r.tag:SetText("|cFFAAAAAA" .. (item.tag or "") .. "|r")
            r.title:SetText(("|cFF%s%s|r%s"):format(item.color or "FFFFFF", item.title or "?", item.detail and (" |cFFFFD200" .. item.detail .. "|r") or ""))
        end
        r:Show()
        y = y + h + GAP
    end
    for i = ri + 1, #self.rows do self.rows[i]:Hide() end
    self.empty:SetShown(ri == 0)
    self._contentH = y
    local visible = self.list:GetHeight() or 1
    if (self.scroll or 0) > math.max(0, y - visible) then self.scroll = math.max(0, y - visible) end
    self:UpdateScrollBar()
end

function M:RefreshEvents()
    local rows = {}
    local zoneEvents = self:CollectZoneEvents()
    self._programIcon = nil
    for _, e in ipairs(zoneEvents) do
        if e.icon and LowerText(e.title):find("abondance", 1, true) then
            self._programIcon = e.icon
            break
        end
    end
    local active, upcoming = self:CollectProgram()
    PutSection(self, rows, "Evenements en cours")
    for _, e in ipairs(zoneEvents) do PutEntry(rows, e) end
    for _, e in ipairs(active) do PutEntry(rows, e) end
    if #zoneEvents == 0 and #active == 0 then
        PutEntry(rows, { tag = "Zone", title = "Aucun evenement local detecte", detail = "Le programme reste affiche ci-dessous", icon = ICON_WORLD, color = "AAAAAA" })
    end
    PutSection(self, rows, "Programme")
    for i = 1, math.min(#upcoming, 12) do PutEntry(rows, upcoming[i]) end
    self:RenderRows(rows)
    SP:SetAutoHeight(self, math.max(120, math.min(260, (self._contentH or 0) + 8)))
end

function M:RefreshCalendar()
    local rows = {}
    if not (C_Calendar and C_Calendar.GetNumDayEvents) then
        PutEntry(rows, { tag = "API", title = "Calendrier indisponible", icon = ICON_CALENDAR, color = "AAAAAA" })
        self:RenderRows(rows)
        return
    end
    local now = C_DateAndTime and C_DateAndTime.GetCurrentCalendarTime and C_DateAndTime.GetCurrentCalendarTime()
    if not now then
        local d = date("*t")
        now = { monthDay = d.day, weekday = d.wday }
    end
    PutSection(self, rows, "Calendrier")
    for offset = 0, 6 do
        local n = 0
        pcall(function() n = C_Calendar.GetNumDayEvents(0, (now.monthDay or 1) + offset) or 0 end)
        for ei = 1, n do
            local ok, evt = pcall(C_Calendar.GetDayEvent, 0, (now.monthDay or 1) + offset, ei)
            if ok and evt and evt.title and evt.title ~= "" then
                local wd = ((now.weekday or 1) - 1 + offset) % 7 + 1
                local dayTxt = (offset == 0) and "Aujourd'hui" or ("%s %d"):format(DAYS[wd] or "", (now.monthDay or 1) + offset)
                local hh = evt.startTime and ("%02d:%02d"):format(evt.startTime.hour or 0, evt.startTime.minute or 0) or ""
                PutEntry(rows, {
                    tag = dayTxt,
                    title = evt.title,
                    detail = hh,
                    icon = ICON_CALENDAR,
                    color = (evt.calendarType == "HOLIDAY") and "FFD200" or "FFFFFF",
                })
                if #rows >= 16 then break end
            end
        end
        if #rows >= 16 then break end
    end
    if #rows == 1 then
        PutEntry(rows, { tag = "Semaine", title = "Aucun evenement calendrier", icon = ICON_CALENDAR, color = "AAAAAA" })
    end
    self:RenderRows(rows)
    SP:SetAutoHeight(self, math.max(120, math.min(260, (self._contentH or 0) + 8)))
end

function M:Refresh()
    if not self._enabled or not self.list then return end
    local cfg = SP:GetModuleConfig(self.name)
    if cfg and cfg.activeTab == "calendar" then self:RefreshCalendar() else self:RefreshEvents() end
end

SP:RegisterModule(M)
