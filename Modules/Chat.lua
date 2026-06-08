-- ============================================================
-- Module : Chat — fenêtre de chat compacte intégrée au panneau
-- ============================================================
-- Étape 9. Réancre ChatFrame1 dans le module. Restaure exactement à Disable.
-- Reparenting runtime → /reload rétablit l'ancrage natif si besoin.
local ADDON_NAME, SP = ...

local M = {
    name          = "Chat",
    label         = "Chat",
    defaultHeight = 200,
}

local function SaveChatState(cf)
    local pts = {}
    for i = 1, cf:GetNumPoints() do pts[i] = { cf:GetPoint(i) } end
    local w, h = cf:GetSize()
    return {
        parent  = cf:GetParent(),
        points  = pts,
        width   = w,
        height  = h,
        movable = cf:IsMovable(),
        userPlaced = cf:IsUserPlaced(),
    }
end

function M:Init(body)
    self.body = body
end

function M:Enable()
    self._enabled = true
    if InCombatLockdown() then return end
    local cf = _G.ChatFrame1
    if not cf then return end

    if not self.saved then self.saved = SaveChatState(cf) end

    if self._placeholder then self._placeholder:Hide() end

    -- Empêche FCF de repositionner pendant qu'on le tient
    pcall(function() cf:SetUserPlaced(true) end)
    cf:SetParent(self.body)
    cf:ClearAllPoints()
    cf:SetPoint("TOPLEFT", self.body, "TOPLEFT", 4, -4)
    cf:SetPoint("BOTTOMRIGHT", self.body, "BOTTOMRIGHT", -4, 4)

    -- Onglet : on le masque (le module fait office de conteneur unique).
    local tab = _G.ChatFrame1Tab
    if tab then self._tabWasShown = tab:IsShown(); tab:Hide() end
end

function M:Disable()
    self._enabled = false
    local cf = _G.ChatFrame1
    if cf and self.saved then
        pcall(function()
            cf:SetParent(self.saved.parent or UIParent)
            cf:ClearAllPoints()
            if self.saved.points and #self.saved.points > 0 then
                for _, p in ipairs(self.saved.points) do cf:SetPoint(unpack(p)) end
            else
                cf:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 35, 35)
            end
            if self.saved.width and self.saved.height then cf:SetSize(self.saved.width, self.saved.height) end
            cf:SetUserPlaced(self.saved.userPlaced and true or false)
        end)
    end
    local tab = _G.ChatFrame1Tab
    if tab and self._tabWasShown then tab:Show() end
end

function M:OnResize(w, h)
    -- ChatFrame1 suit les ancres TOPLEFT/BOTTOMRIGHT du body : rien à recalculer.
end

SP:RegisterModule(M)
