-- ============================================================
-- Config.lua — SavedVariables (SPDB), defaults, deep merge
-- ============================================================
local ADDON_NAME, SP = ...

-- ------------------------------------------------------------
-- Valeurs par défaut
-- ------------------------------------------------------------
SP.defaults = {
    panel = {
        x       = -20,        -- ancrage TOPRIGHT de UIParent
        y       = -200,
        width   = 280,
        locked  = false,
    },
    modules = {
        -- Ordre initial. Le drag-to-reorder réécrit cette liste dans SPDB.
        order = {
            "QuestTracker", "Chat", "DamageMeter", "Raid",
            "SilverDragon", "GameMenu", "MinimapButtons", "SquareMap",
        },
        -- Config par module : enabled / collapsed / height.
        QuestTracker   = { enabled = true,  collapsed = false, height = 300 },
        Chat           = { enabled = true,  collapsed = false, height = 200 },
        DamageMeter    = { enabled = true,  collapsed = false, height = 150 },
        Raid           = { enabled = true,  collapsed = false, height = 180 },
        SilverDragon   = { enabled = true,  collapsed = false, height = 80  },
        GameMenu       = { enabled = true,  collapsed = false, height = 60  },
        MinimapButtons = { enabled = true,  collapsed = false, height = 40  },
        SquareMap      = { enabled = true,  collapsed = false, height = 200 },
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
