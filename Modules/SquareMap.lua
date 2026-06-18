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
    pcall(mm.SetArchBlobRingScalar, mm, 0)
    pcall(mm.SetQuestBlobRingScalar, mm, 0)
    pcall(mm.SetTaskBlobRingScalar, mm, 0)
    if mm.SetHitRectInsets then pcall(mm.SetHitRectInsets, mm, 0, 0, 0, 0) end

    local cfg = SP:GetModuleConfig(self.name)
    local needed = side + 8
    if cfg and not cfg.fixedHeight and math.abs((cfg.height or 0) - needed) > 1 then
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
    local coords = ""
    if C_Map and C_Map.GetBestMapForUnit then
        local mid = C_Map.GetBestMapForUnit("player")
        if mid then
            local pos = C_Map.GetPlayerMapPosition(mid, "player")
            if pos then
                local x, y = pos:GetXY()
                if x and y and (x > 0 or y > 0) then
                    coords = ("  |cFFAAAAAA%.1f, %.1f|r"):format(x * 100, y * 100)
                end
            end
        end
    end
    SP:SetModuleHeaderText(self, z .. coords)
end

-- Masque + VERROUILLE (hook Show) une frame parasite : si l'addon la re-montre, on la re-cache.
function M:Suppress(f)
    if not f then return end
    if self._hiddenDecor[f] then
        -- déjà suivi mais re-visible (SetShown contourne le hook Show) → re-cache
        if f.IsShown and f:IsShown() and not f._spH then pcall(f.Hide, f) end
        return
    end
    self._hiddenDecor[f] = true
    pcall(f.Hide, f)
    if not f._spMapHook and f.HookScript then
        f._spMapHook = true
        local mod = self
        local function rehide(s)
            -- ne pas re-cacher un bouton capturé par l'onglet Addons de Menus (s._spH)
            if mod._enabled and mod._hiddenDecor and mod._hiddenDecor[s] and not s._spH then pcall(s.Hide, s) end
        end
        pcall(hooksecurefunc, f, "Show", rehide)
        pcall(hooksecurefunc, f, "SetShown", function(s, shown) if shown then rehide(s) end end)
    end
end

-- Masque les décorations Blizzard (anneau, boussole, zoom, texte de zone, calendrier, pistage)
-- et les icônes d'addons restées sur la minimap (BtWQuests, Narcissus, SNP, Details, KeystoneLoots...).
function M:CleanMinimap()
    if InCombatLockdown() then return end
    self._hiddenDecor = self._hiddenDecor or {}
    for _, nm in ipairs({
        "MinimapBorder", "MinimapBorderTop", "MinimapCompassTexture", "MinimapNorthTag",
        "MinimapZoomIn", "MinimapZoomOut", "Minimap_ZoomIn", "Minimap_ZoomOut",
        "MiniMapWorldMapButton", "MinimapZoneTextButton", "MiniMapTracking", "MinimapBackdrop",
        "GameTimeFrame", "TimeManagerClockButton", "MiniMapMailFrame", "MiniMapTrackingButton",
        "QueueStatusMinimapButton", "GarrisonLandingPageMinimapButton", "ExpansionLandingPageMinimapButton",
        "MiniMapBattlefieldFrame", "MiniMapLFGFrame", "MinimapClusterTracking",
    }) do
        if _G[nm] then self:Suppress(_G[nm]) end
    end
    if _G.MinimapZoneText then self:Suppress(_G.MinimapZoneText) end
    -- décorations du cluster individuellement (le cluster entier est géré par EditMode → Hide combattu) :
    -- zone / heure / calendrier / pistage / courrier / barre du haut.
    local mc = _G.MinimapCluster
    if mc then
        self:Suppress(mc.BorderTop)
        self:Suppress(mc.ZoneTextButton)
        self:Suppress(mc.InstanceDifficulty)
        self:Suppress(mc.TrackingFrame)
        self:Suppress(mc.Tracking)
        self:Suppress(mc.IndicatorFrame)   -- contient courrier / ordres d'artisanat (12.x)
    end
    self:Suppress(_G.GameTimeFrame)         -- calendrier
    self:Suppress(_G.TimeManagerClockButton) -- horloge
    self:Suppress(_G.MiniMapMailFrame)      -- courrier (legacy)
    -- boutons +/- de zoom et hitareas (enfants keyed de Minimap en retail moderne)
    for _, key in ipairs({ "ZoomIn", "ZoomOut", "ZoomHitArea" }) do
        if Minimap[key] then self:Suppress(Minimap[key]) end
    end
    for _, key in ipairs({
        "Border", "BorderTop", "CompassTexture", "NorthTag", "ZoneTextButton", "Tracking",
        "TrackingFrame", "Backdrop", "ClockFrame", "MailFrame", "WorldMapButton",
    }) do
        if Minimap[key] then self:Suppress(Minimap[key]) end
    end
    -- scan récursif (2 niveaux) : attrape les boutons d'addons même imbriqués
    local function scan(parent, depth)
        if not parent or not parent.GetChildren then return end
        for _, c in ipairs({ parent:GetChildren() }) do
            local n = c:GetName()
            local w = c:GetWidth() or 0
            local keep = n and n:match("^SpherePanel")
            if c:IsShown() and not keep and not c._spH
                and (c:GetObjectType() == "Button" or c:GetObjectType() == "Frame")
                and w >= 0 and w < 80 then
                self:Suppress(c)
            elseif depth > 0 and not keep then
                scan(c, depth - 1)
            end
        end
    end
    scan(Minimap, 1)
    scan(_G.MinimapCluster, 1)
    scan(_G.MinimapBackdrop, 1)
    -- catch-all POSITIONNEL : toute petite frame dont le centre est DANS le rectangle
    -- de la minimap est un bouton d'addon (peu importe parent/ancrage) → supprimée.
    local mL, mR, mT, mB = Minimap:GetLeft(), Minimap:GetRight(), Minimap:GetTop(), Minimap:GetBottom()
    if mL and mR and mT and mB then
        for _, c in ipairs({ UIParent:GetChildren() }) do
            if not self._hiddenDecor[c] and not c._spH and c.GetObjectType
                and (c:GetObjectType() == "Button" or c:GetObjectType() == "Frame") and c:IsShown() then
                local w = c:GetWidth() or 0
                local n = c:GetName()
                if w > 4 and w < 60
                    and not (n and (n:match("^SpherePanel") or n:match("^GameTooltip"))) then
                    local cx, cy = c:GetCenter()
                    if cx and cy and cx >= mL - 20 and cx <= mR + 20 and cy >= mB - 20 and cy <= mT + 20 then
                        self:Suppress(c)
                    end
                end
            end
        end
    end
    -- boutons parentés ailleurs (UIParent…) mais ANCRÉS sur la minimap (Narcissus, etc.)
    for _, c in ipairs({ UIParent:GetChildren() }) do
        if not self._hiddenDecor[c] and c.GetObjectType
            and (c:GetObjectType() == "Button" or c:GetObjectType() == "Frame") and c:IsShown() then
            local w = c:GetWidth() or 0
            local n = c:GetName()
            if w > 8 and w < 56 and not (n and n:match("^SpherePanel")) then
                local okN, np = pcall(c.GetNumPoints, c)
                if okN and np then
                    for i = 1, np do
                        local ok, _, rel = pcall(c.GetPoint, c, i)
                        if ok and rel and (rel == Minimap or rel == _G.MinimapCluster or rel == _G.MinimapBackdrop) then
                            self:Suppress(c)
                            break
                        end
                    end
                end
            end
        end
    end
end

function M:RestoreMinimapDecor()
    if self._hiddenDecor then
        for f in pairs(self._hiddenDecor) do pcall(f.Show, f) end
        wipe(self._hiddenDecor)
    end
end

function M:Enable()
    self._enabled = true
    for _, e in ipairs({ "ZONE_CHANGED", "ZONE_CHANGED_INDOORS", "ZONE_CHANGED_NEW_AREA", "PLAYER_ENTERING_WORLD" }) do
        pcall(self.ev.RegisterEvent, self.ev, e)
    end
    -- bouton Pistage sur le bandeau du module Carte (le pistage minimap natif est masqué)
    if not self.trackBtn and self.header then
        local tb = CreateFrame("Button", nil, self.header)
        tb:SetSize(16, 16)
        tb:SetPoint("RIGHT", self.lock or self.header, self.lock and "LEFT" or "RIGHT", -4, 0)
        tb:SetFrameLevel(self.header:GetFrameLevel() + 3)
        tb.icon = tb:CreateTexture(nil, "ARTWORK"); tb.icon:SetAllPoints(tb)
        if not (pcall(tb.icon.SetAtlas, tb.icon, "Minimap-Tracking-Button", true) and tb.icon:GetAtlas()) then
            tb.icon:SetTexture("Interface\\Minimap\\Tracking\\None")
        end
        tb:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
        tb:SetScript("OnEnter", function(s)
            GameTooltip:SetOwner(s, "ANCHOR_LEFT"); GameTooltip:SetText("Pistage"); GameTooltip:Show()
        end)
        tb:SetScript("OnLeave", function() GameTooltip:Hide() end)
        tb:SetScript("OnClick", function()
            local t = (_G.MinimapCluster and _G.MinimapCluster.Tracking and _G.MinimapCluster.Tracking.Button)
                or _G.MiniMapTrackingButton or _G.MiniMapTracking
            if t then
                if t.OpenMenu then pcall(t.OpenMenu, t)
                elseif t.GetScript and t:GetScript("OnMouseDown") then pcall(t:GetScript("OnMouseDown"), t, "LeftButton")
                elseif t.Click then pcall(t.Click, t) end
            end
        end)
        self.trackBtn = tb
        -- décale le texte de zone à gauche du bouton pistage
        if self.suffixFS then
            self.suffixFS:ClearAllPoints()
            self.suffixFS:SetPoint("RIGHT", tb, "LEFT", -6, 0)
        end
    end
    self:UpdateZone()
    if InCombatLockdown() then return end
    if not Minimap then return end
    if not self.saved then self.saved = SaveMapState() end
    if self._placeholder then self._placeholder:Hide() end

    Apply(self)
    self:CleanMinimap()
    -- ré-application différée : GW2UI peut repositionner après nous au login
    C_Timer.After(0.2, function() Apply(self); self:CleanMinimap() end)
    C_Timer.After(1.0, function() Apply(self); self:CleanMinimap() end)
    -- ticker d'enforcement : on garde la main face aux autres addons + coords live
    if not self._ticker then
        self._ticker = C_Timer.NewTicker(0.5, function() Apply(self); self:CleanMinimap(); self:UpdateZone() end)
    end
end

function M:Disable()
    self._enabled = false
    if self.ev then self.ev:UnregisterAllEvents() end
    SP:SetModuleHeaderText(self, "")
    if self._ticker then self._ticker:Cancel(); self._ticker = nil end
    if InCombatLockdown() then return end

    local cfg = SP:GetModuleConfig(self.name)
    local mm = Minimap
    if mm and self.saved then
        pcall(function()
            mm:SetParent(self.saved.parent or _G.MinimapCluster or UIParent)
            mm:ClearAllPoints()
            if self.saved.points and #self.saved.points > 0 then
                for _, p in ipairs(self.saved.points) do mm:SetPoint(unpack(p)) end
            elseif _G.MinimapCluster then
                mm:SetPoint("TOPRIGHT", _G.MinimapCluster, "TOPRIGHT", 0, 0)
            end
            mm:SetScale(self.saved.scale or 1)
            if self.saved.w and self.saved.h then mm:SetSize(self.saved.w, self.saved.h) end
            mm:SetMaskTexture(ROUND_MASK)
            mm:SetZoom(mm:GetZoom())   -- force un rafraîchissement du rendu/blips
        end)
    end

    if cfg and cfg.hideWhenDisabled then
        -- option : garder la minimap masquée même module désactivé
        if _G.MinimapCluster then pcall(_G.MinimapCluster.Hide, _G.MinimapCluster) end
    else
        self:RestoreMinimapDecor()
        if _G.MinimapCluster then pcall(_G.MinimapCluster.Show, _G.MinimapCluster) end
    end
end

function M:OnResize(w, h)
    Apply(self)
end

SP:RegisterModule(M)
