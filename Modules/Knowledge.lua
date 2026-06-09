-- ============================================================
-- Module : Knowledge — intègre Myu's Knowledge Points Tracker dans le panneau
-- ============================================================
-- Reparente la fenêtre MKPT_Frame dans le module (toutes ses infos). Restauré à Disable.
local ADDON_NAME, SP = ...

local M = {
    name          = "Knowledge",
    label         = "Métiers",
    defaultHeight = 220,
}

local function HasMKPT()
    return (C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("MyusKnowledgePointsTracker"))
        and _G.MKPT_Frame and true or false
end

function M:Init(body)
    self.body = body
    self.info = body:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    self.info:SetPoint("TOP", body, "TOP", 0, -8)
    self.info:Hide()
end

function M:Enable()
    self._enabled = true
    if self._placeholder then self._placeholder:Hide() end
    if not HasMKPT() then
        self.info:SetText("|cFF888888Myu's Knowledge Points Tracker non chargé.|r")
        self.info:Show()
        return
    end
    self.info:Hide()
    if InCombatLockdown() then return end
    local f = _G.MKPT_Frame
    if not self.saved then
        local pts = {}
        for i = 1, f:GetNumPoints() do pts[i] = { f:GetPoint(i) } end
        self.saved = {
            parent = f:GetParent(), points = pts, w = f:GetWidth(), h = f:GetHeight(),
            scale = f:GetScale(), movable = f:IsMovable(),
            closeShown = f.closeButton and f.closeButton:IsShown(),
            hideShown = f.hideButton and f.hideButton:IsShown(),
        }
    end
    pcall(function()
        f:SetMovable(false)
        if f.closeButton then f.closeButton:Hide() end
        if f.hideButton then f.hideButton:Hide() end
        f:SetParent(self.body)
        f:ClearAllPoints()
        f:SetPoint("TOPLEFT", self.body, "TOPLEFT", 2, -2)
        f:SetPoint("BOTTOMRIGHT", self.body, "BOTTOMRIGHT", -2, 2)
        f:Show()
    end)
end

function M:Disable()
    self._enabled = false
    if self.info then self.info:Hide() end
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
            if f.closeButton and self.saved.closeShown then f.closeButton:Show() end
            if f.hideButton and self.saved.hideShown then f.hideButton:Show() end
        end)
    end
end

function M:OnResize(w, h) end

SP:RegisterModule(M)
