-- ============================================================
-- Module : Agenda — widget calendrier (événements du jour + 7 jours)
-- ============================================================
-- Remplace le bouton calendrier/horloge de la minimap (masqués par le module Carte).
-- Bandeau = date + heure. Body = événements d'aujourd'hui et de la semaine.
-- Boutons : 📅 ouvre le calendrier Blizzard ; 🔍 menu de pistage minimap.
local ADDON_NAME, SP = ...

local M = {
    name          = "Agenda",
    label         = "Agenda",
    defaultHeight = 120,
}

local ROW_H = 16
local DAYS = { "Dim", "Lun", "Mar", "Mer", "Jeu", "Ven", "Sam" }

function M:Init(body)
    self.body = body
    self.rows = {}

    -- barre d'actions (ouvrir calendrier / pistage)
    self.bar = CreateFrame("Frame", nil, body)
    self.bar:SetPoint("TOPLEFT", body, "TOPLEFT", 4, -2)
    self.bar:SetPoint("TOPRIGHT", body, "TOPRIGHT", -4, -2)
    self.bar:SetHeight(18)

    self.calBtn = CreateFrame("Button", nil, self.bar, "UIPanelButtonTemplate")
    self.calBtn:SetSize(90, 18)
    self.calBtn:SetPoint("LEFT", self.bar, "LEFT", 0, 0)
    self.calBtn:SetText("Calendrier")
    self.calBtn:SetScript("OnClick", function()
        if ToggleCalendar then pcall(ToggleCalendar)
        elseif GameTimeFrame and GameTimeFrame.Click then pcall(GameTimeFrame.Click, GameTimeFrame) end
    end)

    self.trackBtn = CreateFrame("Button", nil, self.bar, "UIPanelButtonTemplate")
    self.trackBtn:SetSize(80, 18)
    self.trackBtn:SetPoint("LEFT", self.calBtn, "RIGHT", 6, 0)
    self.trackBtn:SetText("Pistage")
    self.trackBtn:SetScript("OnClick", function(s)
        -- réutilise le dropdown du bouton de pistage natif (même masqué)
        local t = (_G.MinimapCluster and _G.MinimapCluster.Tracking and _G.MinimapCluster.Tracking.Button)
            or _G.MiniMapTrackingButton or _G.MiniMapTracking
        if t then
            if t.OpenMenu then pcall(t.OpenMenu, t)
            elseif t.GetScript and t:GetScript("OnMouseDown") then pcall(t:GetScript("OnMouseDown"), t, "LeftButton")
            elseif t.Click then pcall(t.Click, t) end
        end
    end)

    self.list = CreateFrame("Frame", nil, body)
    self.list:SetPoint("TOPLEFT", self.bar, "BOTTOMLEFT", 0, -4)
    self.list:SetPoint("BOTTOMRIGHT", body, "BOTTOMRIGHT", -4, 2)
    self.list:SetClipsChildren(true)

    self.empty = self.list:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    self.empty:SetPoint("TOP", self.list, "TOP", 0, -6)
    self.empty:SetText("Aucun événement cette semaine")
    self.empty:Hide()

    self.ev = CreateFrame("Frame")
    self.ev:SetScript("OnEvent", function(_, e)
        if e == "CALENDAR_UPDATE_EVENT_LIST" or e == "PLAYER_ENTERING_WORLD" then
            self:RequestRefresh()
        end
    end)
end

function M:Enable()
    self._enabled = true
    if self._placeholder then self._placeholder:Hide() end
    pcall(self.ev.RegisterEvent, self.ev, "CALENDAR_UPDATE_EVENT_LIST")
    pcall(self.ev.RegisterEvent, self.ev, "PLAYER_ENTERING_WORLD")
    if C_Calendar and C_Calendar.OpenCalendar then pcall(C_Calendar.OpenCalendar) end  -- demande les données
    -- horloge du bandeau (refresh 30 s)
    if not self._clock then
        self._clock = C_Timer.NewTicker(30, function() self:UpdateHeader() end)
    end
    self:UpdateHeader()
    self:RequestRefresh()
end

function M:Disable()
    self._enabled = false
    if self.ev then self.ev:UnregisterAllEvents() end
    if self._clock then self._clock:Cancel(); self._clock = nil end
    for _, r in ipairs(self.rows) do r:Hide() end
    SP:SetModuleHeaderText(self, "")
end

function M:OnResize(w, h) end

function M:UpdateHeader()
    local t = C_DateAndTime and C_DateAndTime.GetCurrentCalendarTime and C_DateAndTime.GetCurrentCalendarTime()
    if t then
        SP:SetModuleHeaderText(self, ("%s %02d/%02d  %02d:%02d")
            :format(DAYS[(t.weekday or 1)], t.monthDay or 0, t.month or 0, t.hour or 0, t.minute or 0))
    else
        SP:SetModuleHeaderText(self, date("%d/%m %H:%M"))
    end
end

function M:RequestRefresh()
    if not self._enabled then return end
    if self._pending then return end
    self._pending = true
    C_Timer.After(0.3, function() self._pending = false; self:Refresh() end)
end

local function GetRow(self, i)
    local r = self.rows[i]
    if not r then
        r = CreateFrame("Frame", nil, self.list)
        r:SetHeight(ROW_H)
        r.day = r:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        r.day:SetPoint("LEFT", r, "LEFT", 2, 0); r.day:SetWidth(58); r.day:SetJustifyH("LEFT")
        r.fs = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        r.fs:SetPoint("LEFT", r.day, "RIGHT", 4, 0); r.fs:SetPoint("RIGHT", r, "RIGHT", -2, 0)
        r.fs:SetJustifyH("LEFT"); r.fs:SetWordWrap(false)
        self.rows[i] = r
    end
    return r
end

function M:Refresh()
    if not self._enabled or not self.list then return end
    if not (C_Calendar and C_Calendar.GetNumDayEvents) then
        self.empty:SetText("API calendrier indisponible"); self.empty:Show()
        return
    end
    local now = C_DateAndTime.GetCurrentCalendarTime()
    local ri, y = 0, 2

    for offset = 0, 6 do
        local n = 0
        pcall(function() n = C_Calendar.GetNumDayEvents(0, (now.monthDay or 1) + offset) or 0 end)
        for ei = 1, n do
            local ok, evt = pcall(C_Calendar.GetDayEvent, 0, (now.monthDay or 1) + offset, ei)
            if ok and evt and evt.title and evt.title ~= "" then
                ri = ri + 1
                local r = GetRow(self, ri)
                r:ClearAllPoints()
                r:SetPoint("TOPLEFT", self.list, "TOPLEFT", 0, -y)
                r:SetPoint("TOPRIGHT", self.list, "TOPRIGHT", 0, -y)
                local wd = ((now.weekday or 1) - 1 + offset) % 7 + 1
                local dayTxt = (offset == 0) and "|cFF40FF40Auj.|r"
                    or ("|cFFAAAAAA%s %d|r"):format(DAYS[wd], (now.monthDay or 1) + offset)
                r.day:SetText(dayTxt)
                local hh = evt.startTime and ("%02d:%02d "):format(evt.startTime.hour or 0, evt.startTime.minute or 0) or ""
                local color = (evt.calendarType == "HOLIDAY") and "FFD200" or "FFFFFF"
                r.fs:SetText(("|cFF888888%s|r|cFF%s%s|r"):format(hh, color, evt.title))
                r:Show()
                y = y + ROW_H
                if ri >= 14 then break end
            end
        end
        if ri >= 14 then break end
    end

    for i = ri + 1, #self.rows do self.rows[i]:Hide() end
    self.empty:SetShown(ri == 0)

    local needed = 26 + math.max(ROW_H, y)
    local cfg = SP:GetModuleConfig(self.name)
    SP:SetAutoHeight(self, needed)
end

SP:RegisterModule(M)
