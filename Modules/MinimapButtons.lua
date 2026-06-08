-- ============================================================
-- Module : MinimapButtons — collecteur d'icônes minimap d'addons
-- ============================================================
-- Étape 6. "Vole" les boutons d'addons, les range en grille centrée.
-- Neutralise leur auto-repositionnement (sinon ils se replacent sur la minimap → chevauchement).
-- Restaure exactement à Disable. Reparenting runtime → /reload rétablit le natif.
local ADDON_NAME, SP = ...

local M = {
    name          = "MinimapButtons",
    label         = "Icônes addons",
    defaultHeight = 40,
}

local ICON, GAP = 28, 4   -- taille de cellule (les boutons sont centrés dedans)

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

-- Un frame est-il réellement interactif (clic) ? Les sphères décoratives (ex : Profession Todo)
-- n'ont en général aucun handler de clic → on les exclut.
local function HasClick(f)
    if not f.GetScript then return false end
    return (f:GetScript("OnClick") or f:GetScript("OnMouseUp") or f:GetScript("OnMouseDown")) and true or false
end

local function IsAddonButton(child, blacklist)
    if not child then return false end
    local name = child:GetName()
    if not name or BLIZZARD[name] then return false end
    if blacklist then
        for _, pat in ipairs(blacklist) do
            if name:find(pat) then return false end
        end
    end
    local otype = child:GetObjectType()
    if otype ~= "Button" and otype ~= "Frame" then return false end
    local w = child:GetWidth() or 0
    if w == 0 or w > 44 then return false end
    if name:match("^Minimap") or name:match("^MiniMap") then return false end
    if name:match("^LibDBIcon") then return true end
    return HasClick(child)   -- exclut les icônes parasites non-cliquables
end

function M:Init(body)
    self.body = body
    self.stolen = {}   -- [button] = origin
    self.order  = {}   -- liste ordonnée (stable)
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

-- Sauvegarde l'état d'origine + neutralise l'auto-positionnement.
local function StealButton(self, button)
    local pts = {}
    for i = 1, button:GetNumPoints() do pts[i] = { button:GetPoint(i) } end
    self.stolen[button] = {
        parent      = button:GetParent(),
        points      = pts,
        scale       = button:GetScale(),
        onUpdate    = button:GetScript("OnUpdate"),
        onDragStart = button:GetScript("OnDragStart"),
        onDragStop  = button:GetScript("OnDragStop"),
        movable     = button:IsMovable(),
    }
    -- coupe le repositionnement automatique (radius minimap) qui causerait des chevauchements
    pcall(function() button:SetScript("OnUpdate", nil) end)
    pcall(function() button:SetScript("OnDragStart", nil) end)
    pcall(function() button:SetScript("OnDragStop", nil) end)
    pcall(function() button:SetMovable(false) end)
    button:SetParent(self.body)
    button:SetScale(1)
end

function M:Collect()
    if not self._enabled or not self.body then return end
    if InCombatLockdown() then return end
    local cfg = SP:GetModuleConfig(self.name)
    local blacklist = (cfg and cfg.blacklist) or {}
    local children = { Minimap:GetChildren() }
    table.sort(children, function(a, b)
        return (a:GetName() or "") < (b:GetName() or "")
    end)
    for _, child in ipairs(children) do
        if IsAddonButton(child, blacklist) and not self.stolen[child] then
            StealButton(self, child)
            self.order[#self.order + 1] = child
        end
    end
    self:Layout()
end

-- /sp mbscan : liste tous les enfants de la minimap (pour identifier les parasites à blacklister).
function M:Scan()
    SP:Print("Enfants de la minimap (nom [type] largeur clic) :")
    local children = { Minimap:GetChildren() }
    table.sort(children, function(a, b) return (a:GetName() or "") < (b:GetName() or "") end)
    for _, c in ipairs(children) do
        local n = c:GetName() or "<anon>"
        local w = math.floor((c:GetWidth() or 0) + 0.5)
        SP:Print(("  %s [%s] w=%d %s"):format(n, c:GetObjectType(), w, HasClick(c) and "|cFF40FF40clic|r" or "|cFF888888-|r"))
    end
    SP:Print("Pour exclure un parasite : ajoute un motif de son nom dans SPDB.modules.MinimapButtons.blacklist.")
end

function M:Layout()
    if not self.body then return end
    local w = self.body:GetWidth()
    if not w or w < 1 then w = SP.db.panel.width or 280 end
    local count = #self.order
    if count == 0 then return end
    local perRow = math.max(1, math.floor((w - GAP) / (ICON + GAP)))
    if perRow > count then perRow = count end
    local rowW = perRow * (ICON + GAP) - GAP
    local cfg = SP:GetModuleConfig(self.name)
    local align = (cfg and cfg.align) or "left"
    local leftPad = (align == "center") and math.max(GAP, (w - rowW) / 2) or GAP

    for i, button in ipairs(self.order) do
        local col = (i - 1) % perRow
        local rowN = math.floor((i - 1) / perRow)
        -- ancrage CENTER de chaque bouton au centre de sa cellule → alignement propre
        local cx = leftPad + col * (ICON + GAP) + ICON / 2
        local cy = -(GAP + rowN * (ICON + GAP) + ICON / 2)
        button:ClearAllPoints()
        button:SetPoint("CENTER", self.body, "TOPLEFT", cx, cy)
        button:Show()
    end

    local rows = math.ceil(count / perRow)
    local needed = GAP + rows * (ICON + GAP)
    local cfg = SP:GetModuleConfig(self.name)
    if cfg and cfg.height ~= needed then
        cfg.height = needed
        SP:RebuildLayout()
    end
end

function M:RestoreAll()
    for button, origin in pairs(self.stolen) do
        pcall(function()
            button:SetParent(origin.parent or Minimap)
            button:SetScale(origin.scale or 1)
            button:SetMovable(origin.movable and true or false)
            button:SetScript("OnUpdate", origin.onUpdate)
            button:SetScript("OnDragStart", origin.onDragStart)
            button:SetScript("OnDragStop", origin.onDragStop)
            button:ClearAllPoints()
            if origin.points and #origin.points > 0 then
                for _, p in ipairs(origin.points) do button:SetPoint(unpack(p)) end
            else
                button:SetPoint("CENTER", Minimap, "CENTER", 0, 0)
            end
        end)
    end
    wipe(self.stolen)
    wipe(self.order)
end

function M:OnResize(w, h)
    self:Layout()
end

SP:RegisterModule(M)
