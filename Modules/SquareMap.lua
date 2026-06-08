-- ============================================================
-- Module : SquareMap — minimap carrée + réancrage dans le module
-- ============================================================
-- Étape 10. Masque carré + (optionnel) Minimap réancrée dans le body.
-- Reparenting runtime → /reload rétablit la minimap native.
local ADDON_NAME, SP = ...

local M = {
    name          = "SquareMap",
    label         = "Carte",
    defaultHeight = 200,
}

local ROUND_MASK  = "Textures\\MinimapMask"                 -- masque rond natif
local SQUARE_MASK = "Interface\\Buttons\\WHITE8x8"          -- masque carré plein

local function SaveMapState()
    local mm = Minimap
    local pts = {}
    for i = 1, mm:GetNumPoints() do pts[i] = { mm:GetPoint(i) } end
    return {
        parent = mm:GetParent(),
        points = pts,
        w      = mm:GetWidth(),
        h      = mm:GetHeight(),
        scale  = mm:GetScale(),
    }
end

function M:Init(body)
    self.body = body
end

function M:Enable()
    self._enabled = true
    if InCombatLockdown() then return end
    local mm = Minimap
    if not mm then return end

    if not self.saved then self.saved = SaveMapState() end
    if self._placeholder then self._placeholder:Hide() end

    -- Masque carré
    pcall(function() mm:SetMaskTexture(SQUARE_MASK) end)

    -- Réancrage dans le module (carré côté = largeur du body)
    local side = math.max(40, (self.body:GetWidth() or 200) - 8)
    pcall(function()
        mm:SetParent(self.body)
        mm:ClearAllPoints()
        mm:SetPoint("TOP", self.body, "TOP", 0, -4)
        mm:SetSize(side, side)
    end)

    -- ajuste la hauteur du module au côté de la carte
    local cfg = SP:GetModuleConfig(self.name)
    local needed = side + 8
    if cfg and cfg.height ~= needed then
        cfg.height = needed
        SP:RebuildLayout()
    end
end

function M:Disable()
    self._enabled = false
    local mm = Minimap
    if mm and self.saved then
        pcall(function()
            mm:SetMaskTexture(ROUND_MASK)
            mm:SetParent(self.saved.parent or _G.MinimapCluster or UIParent)
            mm:ClearAllPoints()
            if self.saved.points and #self.saved.points > 0 then
                for _, p in ipairs(self.saved.points) do mm:SetPoint(unpack(p)) end
            end
            if self.saved.w and self.saved.h then mm:SetSize(self.saved.w, self.saved.h) end
            mm:SetScale(self.saved.scale or 1)
        end)
    end
end

function M:OnResize(w, h)
    if not self._enabled or InCombatLockdown() then return end
    local mm = Minimap
    if not mm or mm:GetParent() ~= self.body then return end
    local side = math.max(40, (self.body:GetWidth() or 200) - 8)
    pcall(function() mm:SetSize(side, side) end)
    local cfg = SP:GetModuleConfig(self.name)
    local needed = side + 8
    if cfg and cfg.height ~= needed then
        cfg.height = needed
        SP:RebuildLayout()
    end
end

SP:RegisterModule(M)
