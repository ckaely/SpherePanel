-- ============================================================
-- Core.lua — Namespace, events, initialisation
-- ============================================================
-- Pattern namespace : table privée passée en vararg (best practice WoW).
-- On N'UTILISE PAS un global `SP` nu : SphereNameplates occupe déjà ce nom
-- global → collision garantie si les deux addons chargent. Voir BROKER.md DEC-001.
local ADDON_NAME, SP = ...

SP.version  = "0.1.0"
SP.modules  = {}          -- liste ordonnée des modules enregistrés (ordre d'enregistrement)
SP.modulesByName = {}     -- index nom -> module
SP.loaded   = false
SP.LOGO_TEXTURE = "Interface\\AddOns\\SpherePanel\\Media\\SPAN.png"

-- Exposé en global uniquement pour debug / commandes slash, jamais comme source de vérité interne.
_G["SpherePanel"] = SP

-- ------------------------------------------------------------
-- Frame d'événements principal
-- ------------------------------------------------------------
SP.eventFrame = CreateFrame("Frame")
SP.eventFrame:RegisterEvent("ADDON_LOADED")
SP.eventFrame:RegisterEvent("PLAYER_LOGIN")
SP.eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
-- conditions d'affichage par module (zone / combat / groupe)
SP.eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
SP.eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
SP.eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
SP.eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
SP.eventFrame:SetScript("OnEvent", function(_, event, ...)
    SP:OnEvent(event, ...)
end)

local CONDITION_EVENTS = {
    PLAYER_REGEN_ENABLED = true, PLAYER_REGEN_DISABLED = true,
    ZONE_CHANGED_NEW_AREA = true, GROUP_ROSTER_UPDATE = true,
}

function SP:OnEvent(event, arg1, ...)
    if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
        SP:Init()
    elseif event == "PLAYER_LOGIN" then
        SP:OnLogin()
    elseif event == "PLAYER_ENTERING_WORLD" then
        SP:OnEnteringWorld()
        if SP.loaded and SP.panel then SP:RebuildLayout() end
    elseif CONDITION_EVENTS[event] then
        if SP.loaded and SP.panel then SP:RebuildLayout() end
    end
end

-- ------------------------------------------------------------
-- Cycle de vie
-- ------------------------------------------------------------

-- Init : SavedVariables disponibles. Pas encore de frames de jeu garanties.
function SP:Init()
    if SP.loaded then return end
    SP:LoadConfig()          -- Config.lua : remplit SPDB depuis defaults (deep merge)
    SP.loaded = true
end

-- OnLogin : UI prête. C'est ici qu'on construit le panneau et qu'on active les modules.
function SP:OnLogin()
    SP:CreatePanel()      -- PanelFrame.lua : frame déplaçable + resize
    SP:BuildModules()     -- ModuleSystem.lua : header + content par module (appelle RebuildLayout)
    SP:ApplyPanelBehavior()  -- comportement 1/2/3 (magnétisation + bord déclencheur)
    SP:ApplyPanel2()         -- second panneau (option)
    SP:ApplyAppearance()     -- couleur/transparence du fond
    SP:CreateMinimapButton()
    if SP.db.panel.fx and UIFrameFadeIn and SP.panel then
        UIFrameFadeIn(SP.panel, 0.6, 0, 1)   -- apparition stylée
    end
    SP:SetupSlash()
    -- RÈGLE : ObjectiveTrackerFrame:Hide() sera déclenché par QuestTracker (étape 4),
    --         UNIQUEMENT à partir d'ici (PLAYER_LOGIN), jamais au chargement du fichier.
end

-- OnEnteringWorld : hors-combat garanti au tout premier login → moment idéal pour
-- préchauffer les pools de frames (Pattern H SNP : jamais de CreateFrame en combat).
function SP:CreateMinimapButton()
    if SP.minimapButton or not Minimap then return end
    local cfg = SP.db and SP.db.panel
    if not cfg then return end
    cfg.minimap = cfg.minimap or { shown = true, angle = 225 }
    if cfg.minimap.shown == false then return end

    local b = CreateFrame("Button", "SpherePanelMinimapButton", Minimap)
    b:SetSize(31, 31)
    b:SetFrameStrata("MEDIUM")
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:RegisterForDrag("LeftButton")
    b.bg = b:CreateTexture(nil, "BACKGROUND")
    b.bg:SetAllPoints(b)
    b.bg:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetSize(22, 22)
    b.icon:SetPoint("CENTER")
    b.icon:SetTexture(SP.LOGO_TEXTURE)
    b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    b.glow = b:CreateTexture(nil, "OVERLAY")
    b.glow:SetAllPoints(b.icon)
    b.glow:SetTexture("Interface\\Cooldown\\ping4")
    b.glow:SetBlendMode("ADD")
    b.glow:SetVertexColor(0.29, 0.64, 1, 0.45)

    local function place(angle)
        cfg.minimap.angle = angle or cfg.minimap.angle or 225
        local rad = math.rad(cfg.minimap.angle)
        b:ClearAllPoints()
        b:SetPoint("CENTER", Minimap, "CENTER", math.cos(rad) * 82, math.sin(rad) * 82)
    end
    local atan2 = math.atan2 or function(y, x)
        if x > 0 then return math.atan(y / x)
        elseif x < 0 then return math.atan(y / x) + (y >= 0 and math.pi or -math.pi)
        elseif y > 0 then return math.pi / 2
        else return -math.pi / 2 end
    end
    b:SetScript("OnDragStart", function(s)
        s:SetScript("OnUpdate", function()
            local scale = Minimap:GetEffectiveScale()
            local cx, cy = Minimap:GetCenter()
            local x, y = GetCursorPosition()
            x, y = x / scale, y / scale
            place(math.deg(atan2(y - cy, x - cx)))
        end)
    end)
    b:SetScript("OnDragStop", function(s) s:SetScript("OnUpdate", nil) end)
    b:SetScript("OnClick", function(_, button)
        if button == "RightButton" then
            if SP.OpenConfig then SP:OpenConfig() end
        elseif SP.panel then
            SP.panel:SetShown(not SP.panel:IsShown())
        end
    end)
    b:SetScript("OnEnter", function(s)
        GameTooltip:SetOwner(s, "ANCHOR_LEFT")
        GameTooltip:SetText("|cFF4AA3FFSphere|rPanel")
        GameTooltip:AddLine("Clic gauche : afficher/masquer", 1, 1, 1)
        GameTooltip:AddLine("Clic droit : options", 1, 1, 1)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    place(cfg.minimap.angle)
    SP.minimapButton = b
end

function SP:OnEnteringWorld()
    -- TODO(dev) : préchauffer pools (Raid bars, Auras icons, etc.) hors combat.
end

-- ------------------------------------------------------------
-- Helpers
-- ------------------------------------------------------------

-- Applique une icône de l'atlas Media/wow_ico.tga (via Media/IconAtlas.lua) sur une texture.
function SP:SetIcon(tex, index)
    local c = SP.ICONS and SP.ICONS[index]
    if not (c and SP.ICON_TEXTURE) then return false end
    tex:SetTexture(SP.ICON_TEXTURE)
    tex:SetTexCoord(c[1], c[2], c[3], c[4])
    return true
end

-- Règle globale : ancrer un tooltip À L'EXTÉRIEUR du panneau, jamais par-dessus.
-- Choisit le côté selon la position écran du propriétaire (moitié droite → tooltip à gauche,
-- et inversement). `preferredSide` ("LEFT"/"RIGHT") force le côté. GameTooltip reste clampé à l'écran.
function SP:AnchorTooltipOutsidePanel(tooltip, owner, preferredSide)
    tooltip = tooltip or GameTooltip
    local side = preferredSide
    if not side then
        local ox = owner and owner.GetCenter and select(1, owner:GetCenter())
        local sw = UIParent:GetWidth() or 1920
        side = (ox and ox > sw * 0.5) and "LEFT" or "RIGHT"
    end
    tooltip:SetOwner(owner, "ANCHOR_" .. side)
    return tooltip
end

-- ------------------------------------------------------------
-- Pilule arrondie (stadium) réutilisable — ChatFollow + Chat.
-- 3-slice horizontal : 2 embouts demi-cercle (textures) + milieu étirable (WHITE8x8).
-- L'embout, dimensionné à largeur = hauteur/2, reste un demi-cercle parfait à toute taille
-- → pas de déformation des coins, contrairement à un edgeFile Backdrop (coins carrés)
-- ou à AddMaskTexture (muet en 12.x, cf. AP-15).
-- ------------------------------------------------------------
local PILL_DIR  = "Interface\\AddOns\\SpherePanel\\Media\\"
local PILL_CAP  = PILL_DIR .. "pill_cap"        -- embout rempli
local PILL_GLOW = PILL_DIR .. "pill_cap_glow"   -- embout glow flou
local PILL_DOT  = PILL_DIR .. "pill_dot"        -- point indicateur
local PILL_WHITE = "Interface\\Buttons\\WHITE8x8"
local PILL_TEX_H = 128
-- Famille de liserés (arcs) par épaisseur 1..5 ; épaisseur d'arc en px-texture (réf 128).
local PILL_RINGS  = { PILL_DIR.."pill_cap_ring1", PILL_DIR.."pill_cap_ring2", PILL_DIR.."pill_cap_ring3", PILL_DIR.."pill_cap_ring4", PILL_DIR.."pill_cap_ring5" }
local PILL_RING_TT = { 3, 6, 9, 12, 15 }

-- Crée les couches de la pilule sur `frame`. Idempotent (renvoie frame.pill).
function SP:BuildPill(frame)
    if frame.pill then return frame.pill end
    local p = {}
    -- GLOW (le plus bas, ADD) — déborde du cadre
    p.glowL = frame:CreateTexture(nil, "BACKGROUND", nil, -3)
    p.glowR = frame:CreateTexture(nil, "BACKGROUND", nil, -3)
    p.glowM = frame:CreateTexture(nil, "BACKGROUND", nil, -3)
    p.glowL:SetTexture(PILL_GLOW); p.glowR:SetTexture(PILL_GLOW); p.glowM:SetTexture(PILL_GLOW)
    p.glowR:SetTexCoord(1, 0, 0, 1)
    for _, t in ipairs({ p.glowL, p.glowR, p.glowM }) do t:SetBlendMode("ADD") end
    -- FILL (fond transparent)
    p.fillL = frame:CreateTexture(nil, "BACKGROUND", nil, 0)
    p.fillR = frame:CreateTexture(nil, "BACKGROUND", nil, 0)
    p.fillM = frame:CreateTexture(nil, "BACKGROUND", nil, 0)
    p.fillL:SetTexture(PILL_CAP); p.fillR:SetTexture(PILL_CAP); p.fillM:SetTexture(PILL_WHITE)
    p.fillR:SetTexCoord(1, 0, 0, 1)
    -- OMBRE INTÉRIEURE (dégradé sombre en haut = creusé)
    p.shadow = frame:CreateTexture(nil, "ARTWORK", nil, -1)
    p.shadow:SetTexture(PILL_WHITE)
    -- LISERÉ (arc + lignes haut/bas) — texture d'arc choisie par LayoutPill selon l'épaisseur
    p.ringL = frame:CreateTexture(nil, "ARTWORK", nil, 1)
    p.ringR = frame:CreateTexture(nil, "ARTWORK", nil, 1)
    p.lineT = frame:CreateTexture(nil, "ARTWORK", nil, 1)
    p.lineB = frame:CreateTexture(nil, "ARTWORK", nil, 1)
    p.ringL:SetTexture(PILL_RINGS[2]); p.ringR:SetTexture(PILL_RINGS[2])
    p.ringR:SetTexCoord(1, 0, 0, 1)
    p.lineT:SetTexture(PILL_WHITE); p.lineB:SetTexture(PILL_WHITE)
    -- POINT indicateur (gauche)
    p.dot = frame:CreateTexture(nil, "OVERLAY", nil, 1)
    p.dot:SetTexture(PILL_DOT)
    frame.pill = p
    return p
end

-- Positionne les couches selon la taille courante de `frame` (à rappeler après tout SetSize).
-- `bt` = épaisseur de bordure 1..5 (choisit la texture d'arc + l'épaisseur des lignes).
function SP:LayoutPill(frame, bt)
    local p = frame.pill; if not p then return end
    local h = frame:GetHeight() or 40
    local capW = h / 2
    bt = math.max(1, math.min(5, math.floor((tonumber(bt) or 2) + 0.5)))
    p.ringL:SetTexture(PILL_RINGS[bt]); p.ringR:SetTexture(PILL_RINGS[bt])
    p.ringR:SetTexCoord(1, 0, 0, 1)   -- SetTexture réinitialise le TexCoord → re-flip
    local lw = math.max(1.5, PILL_RING_TT[bt] * h / PILL_TEX_H)  -- épaisseur ligne = arc au seam
    local g = math.max(4, h * 0.14)                              -- débord du glow
    -- FILL
    p.fillL:ClearAllPoints(); p.fillL:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0);  p.fillL:SetSize(capW, h)
    p.fillR:ClearAllPoints(); p.fillR:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0); p.fillR:SetSize(capW, h)
    p.fillM:ClearAllPoints()
    p.fillM:SetPoint("TOPLEFT", p.fillL, "TOPRIGHT", 0, 0)
    p.fillM:SetPoint("BOTTOMRIGHT", p.fillR, "BOTTOMLEFT", 0, 0)
    -- GLOW (embouts +g, ratio 1:2 conservé)
    p.glowL:ClearAllPoints(); p.glowL:SetPoint("TOPLEFT", frame, "TOPLEFT", -g, g);  p.glowL:SetSize(capW + g, h + 2*g)
    p.glowR:ClearAllPoints(); p.glowR:SetPoint("TOPRIGHT", frame, "TOPRIGHT", g, g);  p.glowR:SetSize(capW + g, h + 2*g)
    p.glowM:ClearAllPoints()
    p.glowM:SetTexture(PILL_WHITE)   -- milieu du glow = strip plein
    p.glowM:SetPoint("TOPLEFT", p.glowL, "TOPRIGHT", 0, 0)
    p.glowM:SetPoint("BOTTOMRIGHT", p.glowR, "BOTTOMLEFT", 0, 0)
    -- LISERÉ
    p.ringL:ClearAllPoints(); p.ringL:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0);  p.ringL:SetSize(capW, h)
    p.ringR:ClearAllPoints(); p.ringR:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0); p.ringR:SetSize(capW, h)
    p.lineT:ClearAllPoints(); p.lineT:SetPoint("TOPLEFT", p.ringL, "TOPRIGHT", 0, 0);    p.lineT:SetPoint("TOPRIGHT", p.ringR, "TOPLEFT", 0, 0);    p.lineT:SetHeight(lw)
    p.lineB:ClearAllPoints(); p.lineB:SetPoint("BOTTOMLEFT", p.ringL, "BOTTOMRIGHT", 0, 0); p.lineB:SetPoint("BOTTOMRIGHT", p.ringR, "BOTTOMLEFT", 0, 0); p.lineB:SetHeight(lw)
    -- OMBRE INTÉRIEURE (zone à sommet plat uniquement → inset horizontal)
    p.shadow:ClearAllPoints()
    p.shadow:SetPoint("TOPLEFT",  frame, "TOPLEFT",  capW * 0.6, -lw)
    p.shadow:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -capW * 0.6, -lw)
    p.shadow:SetHeight(math.max(6, h * 0.42))
    -- POINT
    local ds = math.max(6, h * 0.20)
    p.dot:ClearAllPoints(); p.dot:SetPoint("LEFT", frame, "LEFT", capW * 0.55, 0); p.dot:SetSize(ds, ds)
end

-- Colore/opacité de la pilule. opts: bgAlpha, borderAlpha, light, glow, glowAlpha, innerShadow, dot.
function SP:StylePill(frame, r, g, b, opts)
    opts = opts or {}
    local p = frame.pill; if not p then return end
    local bgA = tonumber(opts.bgAlpha) or 0.5
    local bdA = tonumber(opts.borderAlpha) or 0.95
    local fr, fg, fb = 0, 0, 0
    if opts.light then fr, fg, fb = 0.95, 0.97, 1 end
    for _, t in ipairs({ p.fillL, p.fillR, p.fillM }) do t:SetVertexColor(fr, fg, fb, bgA) end
    for _, t in ipairs({ p.ringL, p.ringR, p.lineT, p.lineB }) do t:SetVertexColor(r, g, b, bdA) end
    local gA = opts.glow and (tonumber(opts.glowAlpha) or 0.35) or 0
    for _, t in ipairs({ p.glowL, p.glowR, p.glowM }) do t:SetVertexColor(r, g, b, gA) end
    p._glowBase = gA
    -- Ombre intérieure : sombre en haut → transparent en bas
    if p.shadow then
        if opts.innerShadow ~= false and p.shadow.SetGradient and CreateColor then
            p.shadow:SetColorTexture(1, 1, 1, 1)
            pcall(p.shadow.SetGradient, p.shadow, "VERTICAL",
                CreateColor(0, 0, 0, 0), CreateColor(0, 0, 0, 0.5))
        else
            p.shadow:SetColorTexture(0, 0, 0, 0)
        end
    end
    if p.dot then p.dot:SetVertexColor(r, g, b, opts.dot and 1 or 0) end
end

-- Son de déplacement d'objet (prise/dépôt). Le moteur en joue déjà un sur Pickup*/Equip* ;
-- ce helper garantit un retour audible même si ce n'est pas le cas. kind = "pickup" | "drop".
function SP:PlayItemSound(kind)
    local k = SOUNDKIT
    if not (k and PlaySound) then return end
    local id = (kind == "pickup") and (k.IG_PICK_UP or k.IG_BACKPACK_OPEN)
        or (k.IG_PUT_DOWN or k.IG_BACKPACK_CLOSE)
    if id then pcall(PlaySound, id) end
end

-- Log console simple, throttle-able plus tard. Préfixe coloré.
function SP:Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cFF4AA3FFSpherePanel|r " .. tostring(msg))
end

-- ------------------------------------------------------------
-- Commandes slash : /sp et /spanel
-- ------------------------------------------------------------
function SP:SetupSlash()
    if SP._slashReady then return end
    SP._slashReady = true
    -- /sp est déjà pris par WoW (et d'autres addons) → commande principale = /span
    SLASH_SPHEREPANEL1 = "/span"
    SLASH_SPHEREPANEL2 = "/spanel"
    SlashCmdList["SPHEREPANEL"] = function(msg) SP:HandleSlash(msg or "") end
end

function SP:HandleSlash(msg)
    msg = msg:gsub("^%s+", ""):gsub("%s+$", "")
    local cmd, rest = msg:match("^(%S*)%s*(.-)$")
    cmd = (cmd or ""):lower()

    if cmd == "lock" then
        SP:SetPanelLocked(not SP.db.panel.locked)
        SP:Print("Panneau " .. (SP.db.panel.locked and "verrouillé." or "déverrouillé."))
    elseif cmd == "reset" then
        SP:ResetPanel()
        SP:Print("Position et largeur réinitialisées.")
    elseif cmd == "show" then
        if SP.panel then SP.panel:Show() end
    elseif cmd == "hide" then
        if SP.panel then SP.panel:Hide() end
    elseif cmd == "config" or cmd == "options" then
        if SP.OpenConfig then SP:OpenConfig() else SP:Print("Panneau d'options indisponible.") end
    elseif cmd == "mbscan" then
        local mb = SP.modulesByName and SP.modulesByName["GameMenu"]
        if mb and mb.Scan then mb:Scan() else SP:Print("Module Menus indisponible.") end
    elseif cmd == "raretest" then
        -- alerte factice pour valider le module Rares (32491 = Proto-drake perdu dans le temps)
        local rm = SP.modulesByName and SP.modulesByName["SilverDragon"]
        if rm and rm.OnSeen then
            rm._enabled = true
            local mapID = (C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")) or 0
            rm:OnSeen(32491, mapID, 0.5, 0.5, false)
            SP:Print("Alerte de test envoyée au module Rares (clic droit = butin).")
        else
            SP:Print("Module Rares indisponible.")
        end
    elseif cmd == "enable" and rest ~= "" then
        SP:EnableModule(rest)
    elseif cmd == "modules" then
        SP:Print("Modules :")
        for _, m in ipairs(SP:GetOrderedModules()) do
            local cfg = SP:GetModuleConfig(m.name)
            local state = (cfg and cfg.enabled) and "|cFF55FF55on|r" or "|cFFFF5555off|r"
            SP:Print(("  %s (%s) — %s"):format(m.name, m.label, state))
        end
    else
        SP:Print("Commandes : |cFFFFFFFF/span|r config | mbscan | lock | reset | show | hide | modules | enable <Nom>")
    end
end
