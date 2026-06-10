-- ============================================================
-- Module : Knowledge ("Métiers") — icônes des métiers + Myu's Knowledge Points Tracker intégré
-- ============================================================
-- Rangée d'icônes des métiers du personnage (tooltip compétence) + fenêtre MKPT en dessous,
-- mise à l'échelle pour tenir dans le module et VERROUILLÉE dedans (pas d'affichage libre).
-- Requiert : MyusKnowledgePointsTracker (indiqué si absent).
local ADDON_NAME, SP = ...

local M = {
    name          = "Knowledge",
    label         = "Métiers",
    defaultHeight = 240,
}

local PROF_H = 26

local function HasMKPT()
    return (C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("MyusKnowledgePointsTracker"))
        and _G.MKPT_Frame and true or false
end

function M:Init(body)
    self.body = body
    self.profBtns = {}

    -- rangée d'icônes des métiers du personnage
    self.profRow = CreateFrame("Frame", nil, body)
    self.profRow:SetPoint("TOPLEFT", body, "TOPLEFT", 4, -2)
    self.profRow:SetPoint("TOPRIGHT", body, "TOPRIGHT", -4, -2)
    self.profRow:SetHeight(PROF_H)

    -- conteneur MKPT
    self.host = CreateFrame("Frame", nil, body)
    self.host:SetPoint("TOPLEFT", self.profRow, "BOTTOMLEFT", 0, -2)
    self.host:SetPoint("BOTTOMRIGHT", body, "BOTTOMRIGHT", -2, 2)
    self.host:SetClipsChildren(true)

    self.info = body:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    self.info:SetPoint("TOP", self.host, "TOP", 0, -8)
    self.info:Hide()

    self.ev = CreateFrame("Frame")
    self.ev:SetScript("OnEvent", function() self:RefreshProfessions() end)
end

-- Icônes des métiers connus (GetProfessions), tooltip nom + compétence.
function M:RefreshProfessions()
    local ids = { GetProfessions() }
    local x, shown = 0, 0
    for i = 1, 5 do
        local idx = ids[i]
        if idx then
            shown = shown + 1
            local b = self.profBtns[shown]
            if not b then
                b = CreateFrame("Button", nil, self.profRow)
                b:SetSize(PROF_H - 2, PROF_H - 2)
                b.icon = b:CreateTexture(nil, "ARTWORK"); b.icon:SetAllPoints(b)
                b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
                local bd = b:CreateTexture(nil, "BACKGROUND")
                bd:SetPoint("TOPLEFT", b, "TOPLEFT", -1, 1); bd:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 1, -1)
                bd:SetColorTexture(0.30, 0.30, 0.38, 1)
                b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
                b:SetScript("OnLeave", function() GameTooltip:Hide() end)
                b:SetScript("OnClick", function()
                    if ToggleProfessionsBook then pcall(ToggleProfessionsBook)
                    elseif ToggleSpellBook then pcall(ToggleSpellBook, "professions") end
                end)
                self.profBtns[shown] = b
            end
            local name, icon, skill, maxSkill = GetProfessionInfo(idx)
            b.icon:SetTexture(icon or "Interface\\Icons\\INV_Misc_QuestionMark")
            b._tip = ("%s  |cFFFFFFFF%d / %d|r"):format(name or "?", skill or 0, maxSkill or 0)
            b:SetScript("OnEnter", function(s)
                GameTooltip:SetOwner(s, "ANCHOR_RIGHT"); GameTooltip:SetText(s._tip); GameTooltip:Show()
            end)
            b:ClearAllPoints()
            b:SetPoint("LEFT", self.profRow, "LEFT", x, 0)
            b:Show()
            x = x + PROF_H + 4
        end
    end
    for i = shown + 1, #self.profBtns do self.profBtns[i]:Hide() end
end

-- Ajuste MKPT à la largeur du module (échelle) et le maintient ancré dedans.
function M:FitMKPT()
    local f = _G.MKPT_Frame
    if not f or not self._embedded then return end
    local hostW = self.host:GetWidth()
    if not hostW or hostW < 50 then hostW = (SP.db.panel.width or 280) - 8 end
    local fw = f:GetWidth() or 300
    local scale = math.min(1, hostW / fw)
    pcall(function()
        if f:GetParent() ~= self.host then f:SetParent(self.host) end
        f:SetScale(scale)
        f:ClearAllPoints()
        f:SetPoint("TOPLEFT", self.host, "TOPLEFT", 0, 0)
        f:Show()
    end)
    local fh = (f:GetHeight() or 200) * scale
    SP:SetAutoHeight(self, PROF_H + 8 + fh)
end

function M:Enable()
    self._enabled = true
    if self._placeholder then self._placeholder:Hide() end
    pcall(self.ev.RegisterEvent, self.ev, "SKILL_LINES_CHANGED")
    pcall(self.ev.RegisterEvent, self.ev, "PLAYER_ENTERING_WORLD")
    self:RefreshProfessions()

    if not HasMKPT() then
        self.info:SetText("|cFFFF7777Requiert : Myu's Knowledge Points Tracker|r\n|cFF888888(addon non chargé)|r")
        self.info:Show()
        SP:SetModuleHeaderText(self, "|cFFFF7777MKPT requis|r")
        return
    end
    self.info:Hide()
    SP:SetModuleHeaderText(self, "|cFF888888MKPT|r")
    if InCombatLockdown() then return end

    local f = _G.MKPT_Frame
    if not self.saved then
        local pts = {}
        for i = 1, f:GetNumPoints() do pts[i] = { f:GetPoint(i) } end
        self.saved = {
            parent = f:GetParent(), points = pts, w = f:GetWidth(), h = f:GetHeight(),
            scale = f:GetScale(), movable = f:IsMovable(),
            onDragStart = f:GetScript("OnDragStart"), onDragStop = f:GetScript("OnDragStop"),
            closeShown = f.closeButton and f.closeButton:IsShown(),
            hideShown = f.hideButton and f.hideButton:IsShown(),
        }
    end
    -- verrouille : plus d'affichage libre (drag coupé, boutons close/hide masqués)
    pcall(function()
        f:SetMovable(false)
        f:SetScript("OnDragStart", nil)
        f:SetScript("OnDragStop", nil)
        if f.closeButton then f.closeButton:Hide() end
        if f.hideButton then f.hideButton:Hide() end
    end)
    self._embedded = true
    self:FitMKPT()
    -- enforcement léger : si MKPT se repositionne/réaffiche librement, on le ramène
    if not self._ticker then
        self._ticker = C_Timer.NewTicker(1, function() self:FitMKPT() end)
    end
end

function M:Disable()
    self._enabled = false
    if self.ev then self.ev:UnregisterAllEvents() end
    if self._ticker then self._ticker:Cancel(); self._ticker = nil end
    if self.info then self.info:Hide() end
    SP:SetModuleHeaderText(self, "")
    local f = _G.MKPT_Frame
    if f and self.saved then
        pcall(function()
            f:SetParent(self.saved.parent or UIParent)
            f:ClearAllPoints()
            if self.saved.points and #self.saved.points > 0 then
                for _, p in ipairs(self.saved.points) do f:SetPoint(unpack(p)) end
            else
                f:SetPoint("CENTER")
            end
            if self.saved.w and self.saved.h then f:SetSize(self.saved.w, self.saved.h) end
            f:SetScale(self.saved.scale or 1)
            f:SetMovable(self.saved.movable and true or false)
            f:SetScript("OnDragStart", self.saved.onDragStart)
            f:SetScript("OnDragStop", self.saved.onDragStop)
            if f.closeButton and self.saved.closeShown then f.closeButton:Show() end
            if f.hideButton and self.saved.hideShown then f.hideButton:Show() end
        end)
    end
    self._embedded = false
end

function M:OnResize(w, h)
    self:FitMKPT()
end

SP:RegisterModule(M)
