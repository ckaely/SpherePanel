-- ============================================================
-- Module : MinimapButtons — collecteur d'icônes minimap d'addons
-- ============================================================
-- Étape 6. "Vole" les boutons d'addons de la minimap, les range en grille.
-- Restaure exactement à Disable. Reparenting runtime → /reload rétablit l'état natif.
local ADDON_NAME, SP = ...

local M = {
    name          = "MinimapButtons",
    label         = "Icônes addons",
    defaultHeight = 40,
}

local ICON, GAP = 24, 4

-- Frames Blizzard de la minimap à NE JAMAIS déplacer.
local BLIZZARD = {
    MinimapBackdrop = true, MinimapCluster = true, MiniMapMailFrame = true,
    MiniMapMailIcon = true, MinimapZoneTextButton = true, MinimapZoomIn = true,
    MinimapZoomOut = true, MiniMapTracking = true, MiniMapTrackingButton = true,
    MiniMapTrackingIcon = true, GameTimeFrame = true, TimeManagerClockButton = true,
    MiniMapWorldMapButton = true, MinimapNorthTag = true, MinimapCompassTexture = true,
    QueueStatusButton = true, QueueStatusMinimapButton = true,
    ExpansionLandingPageMinimapButton = true, GarrisonLandingPageMinimapButton = true,
    MiniMapInstanceDifficulty = true, GuildInstanceDifficulty = true,
    MiniMapChallengeMode = true, MawBuffsBelowMinimapFrame = true,
    Minimap = true, MinimapBackdropFrame = true,
}

-- Un bouton ressemble-t-il à une icône d'addon volable ?
local function IsAddonButton(child)
    if not child or BLIZZARD[child:GetName() or ""] then return false end
    local otype = child:GetObjectType()
    if otype ~= "Button" and otype ~= "Frame" then return false end
    local name = child:GetName()
    if not name then return false end
    -- heuristique : petit, possède un script clic ou une texture, nom non-Blizzard
    local w = child:GetWidth() or 0
    if w == 0 or w > 40 then return false end
    if name:match("^LibDBIcon") then return true end
    -- évite les régions internes Blizzard nommées "Minimap..."
    if name:match("^Minimap") or name:match("^MiniMap") then return false end
    return true
end

function M:Init(body)
    self.body = body
    self.stolen = {}   -- [button] = { parent, p1..pN, scale }
end

function M:Enable()
    self._enabled = true
    if self._placeholder then self._placeholder:Hide() end
    self:Collect()
end

function M:Disable()
    self._enabled = false
    self:RestoreAll()
end

-- Sauvegarde l'état d'origine d'un bouton avant de le voler.
local function SaveOrigin(button)
    local pts = {}
    for i = 1, button:GetNumPoints() do
        pts[i] = { button:GetPoint(i) }
    end
    return {
        parent = button:GetParent(),
        points = pts,
        scale  = button:GetScale(),
    }
end

function M:Collect()
    if not self._enabled or not self.body then return end
    if InCombatLockdown() then return end   -- reparenting protégé interdit en combat
    local children = { Minimap:GetChildren() }
    for _, child in ipairs(children) do
        if IsAddonButton(child) and not self.stolen[child] then
            self.stolen[child] = SaveOrigin(child)
            child:SetParent(self.body)
            child:SetScale(1)
        end
    end
    self:Layout()
end

function M:Layout()
    if not self.body then return end
    local w = self.body:GetWidth()
    if not w or w < 1 then w = SP.db.panel.width or 280 end
    local perRow = math.max(1, math.floor((w - GAP) / (ICON + GAP)))
    local i = 0
    for button in pairs(self.stolen) do
        if button:GetParent() == self.body then
            local col = i % perRow
            local rowN = math.floor(i / perRow)
            button:ClearAllPoints()
            button:SetPoint("TOPLEFT", self.body, "TOPLEFT", GAP + col * (ICON + GAP), -(GAP + rowN * (ICON + GAP)))
            button:Show()
            i = i + 1
        end
    end
    local count = i
    local rows = math.max(1, math.ceil(count / perRow))
    local needed = GAP + rows * (ICON + GAP)
    local cfg = SP:GetModuleConfig(self.name)
    if cfg and cfg.height ~= needed then
        cfg.height = needed
        SP:RebuildLayout()
    end
end

function M:RestoreAll()
    for button, origin in pairs(self.stolen) do
        if origin then
            pcall(function()
                button:SetParent(origin.parent or Minimap)
                button:SetScale(origin.scale or 1)
                button:ClearAllPoints()
                if origin.points and #origin.points > 0 then
                    for _, p in ipairs(origin.points) do button:SetPoint(unpack(p)) end
                else
                    button:SetPoint("CENTER", Minimap, "CENTER", 0, 0)
                end
            end)
        end
    end
    wipe(self.stolen)
end

function M:OnResize(w, h)
    self:Layout()
end

SP:RegisterModule(M)
