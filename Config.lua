-- ============================================================
-- Config.lua — SavedVariables (SPDB), defaults, deep merge
-- ============================================================
local ADDON_NAME, SP = ...

-- ------------------------------------------------------------
-- Constantes de layout (partagées PanelFrame / ModuleSystem)
-- ------------------------------------------------------------
SP.UI = {
    TITLE_H  = 22,    -- hauteur de la barre de titre du panneau
    HEADER_H = 20,    -- hauteur du bandeau header d'un module
    GAP      = 2,     -- espace vertical entre modules
    MIN_W    = 180,   -- largeur min du panneau
    MAX_W    = 600,   -- largeur max du panneau
}

-- ------------------------------------------------------------
-- Valeurs par défaut
-- ------------------------------------------------------------
SP.defaults = {
    panel = {
        x       = -20,        -- ancrage TOPRIGHT de UIParent
        y       = -200,
        width   = 280,
        locked  = false,
        behavior = 3,         -- 1 = panneau magnétisé glissant ; 2 = modules individuels ; 3 = libre
        side     = "right",   -- "right" ou "left" : bord d'aimantation
        vpos     = "top",     -- "top" ou "bottom" : ancrage vertical en mode magnétisé
        fx       = true,      -- effets visuels (orbe pulsant + shimmer + intro)
        bgColor  = { r = 0.05, g = 0.05, b = 0.07, a = 0.85 },  -- fond du panneau (Apparence)
        autofade = {          -- estompage automatique (comportement 3)
            enabled      = false,
            delay        = 5,     -- secondes d'inactivité avant fade
            alpha        = 0.25,  -- opacité en mode estompé
            fadeDuration = 0.35,  -- durée de transition
        },
    },
    modules = {
        -- Ordre initial. Le drag-to-reorder réécrit cette liste dans SPDB.
        order = {
            "QuestTracker", "Chat", "DamageMeter", "Raid", "Auras", "Bags",
            "Knowledge", "SilverDragon", "GameMenu", "Agenda", "SquareMap",
        },
        -- Config par module : enabled / collapsed / height.
        QuestTracker   = { enabled = true,  collapsed = false, height = 300,
            filters = {  -- catégories affichées (phase 3) ; false = masquée
                classic = true, daily = true, weekly = true, campaign = true,
                dungeon = true, raid = true, pvp = true, account = true, worldquest = true,
            },
        },
        Chat           = { enabled = true,  collapsed = false, height = 200,
            font = STANDARD_TEXT_FONT, fontSize = 12, classColorNames = true,
            channels = {  -- ordre + activation + couleur (personnalisable dans les options)
                { key = "A", label = "A", enabled = true,  r = 1.0, g = 1.0, b = 1.0 },
                { key = "W", label = "W", enabled = true,  r = 1.0, g = 0.5, b = 1.0 },
                { key = "I", label = "I", enabled = true,  r = 1.0, g = 0.5, b = 0.4 },
                { key = "M", label = "M", enabled = true,  r = 0.5, g = 1.0, b = 0.5 },  -- Market = vert clair
                { key = "G", label = "G", enabled = false, r = 0.25, g = 1.0, b = 0.25 },
                { key = "S", label = "S", enabled = false, r = 1.0, g = 1.0, b = 1.0 },
            },
        },
        DamageMeter    = { enabled = true,  collapsed = false, height = 150 },
        Raid           = { enabled = true,  collapsed = false, height = 180 },
        Auras          = { enabled = true,  collapsed = false, height = 90, tab = "all", iconSize = 26 },
        Bags           = { enabled = true,  collapsed = true,  height = 240,
            showIlvl = true, showUpgrade = true,   -- iLvl + flèche upgrade (Pawn) sur l'équipement
            known = {},   -- snapshot itemID connus (pour la section Récent)
            -- color = couleur du titre ; group/groupPrefix = sous-catégories par sous-type ; search = filtre nom
            categories = {
                { key = "recent",     label = "Récent",     enabled = true,  collapsed = false, color = { 0.40, 0.90, 0.40 } },
                { key = "junk",       label = "Camelote",   enabled = true,  collapsed = false, color = { 0.62, 0.62, 0.62 } },
                { key = "equipment",  label = "Stuff",      enabled = true,  collapsed = false, color = { 0.70, 0.40, 0.95 }, group = true },
                { key = "trade",      label = "Artisanat",  enabled = true,  collapsed = false, color = { 1.00, 0.55, 0.25 }, group = true, groupPrefix = "Composant" },
                { key = "consumable", label = "Utilisable", enabled = true,  collapsed = false, color = { 1.00, 0.70, 0.25 }, group = true, groupPrefix = "Conso" },
                { key = "quest",      label = "Quêtes",     enabled = true,  collapsed = false, color = { 1.00, 0.82, 0.00 } },
                { key = "misc",       label = "Divers",     enabled = true,  collapsed = false, color = { 0.90, 0.85, 0.45 } },
                { key = "empty",      label = "Vide",       enabled = true,  collapsed = true,  color = { 0.50, 0.50, 0.50 } },
            },
        },
        Knowledge      = { enabled = true,  collapsed = true,  height = 220 },
        Agenda         = { enabled = true,  collapsed = false, height = 120 },
        SilverDragon   = { enabled = true,  collapsed = false, height = 80  },
        GameMenu       = { enabled = true,  collapsed = false, height = 64,
            activeTab = "menus",     -- "menus" ou "addons"
            showClock = true, clock24h = true, showFPS = true,
            addonAlign = "left",
            addonBlacklist = { "ProfessionTodo", "ProfessionsTodo", "ProfTodo" },
        },
        SquareMap      = { enabled = true,  collapsed = false, height = 200, hideWhenDisabled = false },
    },
}

-- ------------------------------------------------------------
-- Deep merge : remplit uniquement les clés manquantes de dst depuis src.
-- Préserve toutes les valeurs déjà choisies par l'utilisateur.
-- ------------------------------------------------------------
local function deepMerge(dst, src)
    for k, v in pairs(src) do
        if type(v) == "table" then
            if type(dst[k]) ~= "table" then dst[k] = {} end
            deepMerge(dst[k], v)
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
    return dst
end
SP.deepMerge = deepMerge

-- ------------------------------------------------------------
-- Chargement de la config. Appelé depuis Core:Init (ADDON_LOADED).
-- ------------------------------------------------------------
function SP:LoadConfig()
    SPDB = SPDB or {}
    deepMerge(SPDB, SP.defaults)
    SP.db = SPDB

    -- NOTE : on ne supprime PAS les clés inconnues de SPDB (profils legacy).
    -- Si un module défaut disparaît de `order` mais reste dans SPDB.modules,
    -- ModuleSystem:GetOrderedModules ignorera simplement les noms non enregistrés.
end

-- Accès config d'un module (toujours non nil après LoadConfig).
function SP:GetModuleConfig(name)
    if not SP.db or not SP.db.modules then return nil end
    return SP.db.modules[name]
end
