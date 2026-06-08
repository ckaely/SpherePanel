-- ============================================================
-- Module : SquareMap — minimap carrée réancrée dans le module
-- ============================================================
-- Étape 10. Masque carré + Minimap ajustée à la largeur du panneau.
-- Ticker d'enforcement : reprend la main sur les addons qui pilotent la minimap (ex : GW2UI).
-- Reparenting runtime → /reload rétablit la minimap native.
local ADDON_NAME, SP = ...

local M = {
    name          = "SquareMap",
    label         = "Carte",
    defaultHeight = 200,
}

local ROUND_MASK  = "Textures\\MinimapMask"
local SQUARE_MASK = "Interface\\Buttons\\WHITE8x8"

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

-- Cible de côté = largeur du body (carré ajusté à l'addon).
local function TargetSide(self)
    local w = self.body:GetWidth()
    if not w or w < 1 then w = SP.db.panel.width or 280 end
    return math.max(40, w - 8)
end

-- Impose notre mise en forme (appelé à Enable + par le ticker, prioritaire sur GW2UI).
local function Apply(self)
    local mm = Minimap
    if not mm or not self._enabled or InCombatLockdown() then return end
    local side = TargetSide(self)

    if mm:GetParent() ~= self.body then mm:SetParent(self.body) end
    mm:ClearAllPoints()
    mm:SetPoint("TOP", self.body, "TOP", 0, -4)
    if math.abs((mm:GetScale() or 1) - 1) > 0.01 then mm:SetScale(1) end
    if math.abs((mm:GetWidth() or 0) - side) > 1 then mm:SetSize(side, side) end
    pcall(mm.SetMaskTexture, mm, SQUARE_MASK)

    local cfg = SP:GetModuleConfig(self.name)
    local needed = side + 8
    if cfg and math.abs((cfg.height or 0) - needed) > 1 then
        cfg.height = needed
        SP:RebuildLayout()
    end
end

function M:Init(body)
    self.body = body
    self.ev = CreateFrame("Frame")
    self.ev:SetScript("OnEvent", function() self:UpdateZone() end)
end

function M:UpdateZone()
    local z = (GetMinimapZoneText and GetMinimapZoneText()) or (GetZoneText and GetZoneText()) or ""
    SP:SetModuleHeaderText(self, z)
end

function M:Enable()
    self._enabled = true
    for _, e in ipairs({ "ZONE_CHANGED", "ZONE_CHANGED_INDOORS", "ZONE_CHANGED_NEW_AREA", "PLAYER_ENTERING_WORLD" }) do
        pcall(self.ev.RegisterEvent, self.ev, e)
    end
    self:UpdateZone()
    if InCombatLockdown() then return end
    if not Minimap then return end
    if not self.saved then self.saved = SaveMapState() end
    if self._placeholder then self._placeholder:Hide() end

    Apply(self)
    -- ré-application différée : GW2UI peut repositionner après nous au login
    C_Timer.After(0.2, function() Apply(self) end)
    C_Timer.After(1.0, function() Apply(self) end)
    -- ticker d'enforcement : on garde la main face aux autres addons
    if not self._ticker then
        self._ticker = C_Timer.NewTicker(0.5, function() Apply(self) end)
    end
end

function M:Disable()
    self._enabled = false
    if self.ev then self.ev:UnregisterAllEvents() end
    SP:SetModuleHeaderText(self, "")
    if self._ticker then self._ticker:Cancel(); self._ticker = nil end
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
    Apply(self)
end

SP:RegisterModule(M)
