-- ============================================================
-- ModuleSystem.lua — Moteur de modules
--   • Registre + validation d'interface
--   • Bandeaux collapsibles (header + content)
--   • Drag-to-reorder (fantôme + RebuildLayout)
-- ============================================================
-- SKELETON : seul le registre/validation est implémenté (sûr, sans frame).
-- Les bandeaux et le drag-to-reorder sont les étapes 2-3 du dev.
local ADDON_NAME, SP = ...

-- Interface obligatoire que tout module DOIT exposer.
local REQUIRED = { "name", "label" }
local REQUIRED_FN = { "Init", "Enable", "Disable", "OnResize" }

-- ------------------------------------------------------------
-- A) Enregistrement
-- ------------------------------------------------------------
function SP:RegisterModule(module)
    if type(module) ~= "table" then
        SP:Print("|cFFFF5555RegisterModule|r : argument non-table ignoré")
        return false
    end
    for _, key in ipairs(REQUIRED) do
        if type(module[key]) ~= "string" then
            SP:Print(("|cFFFF5555RegisterModule|r : champ '%s' manquant"):format(key))
            return false
        end
    end
    for _, fn in ipairs(REQUIRED_FN) do
        if type(module[fn]) ~= "function" then
            SP:Print(("|cFFFF5555RegisterModule|r [%s] : méthode '%s' manquante")
                :format(module.name, fn))
            return false
        end
    end
    if SP.modulesByName[module.name] then
        SP:Print(("|cFFFF5555RegisterModule|r : doublon '%s' ignoré"):format(module.name))
        return false
    end

    SP.modulesByName[module.name] = module
    table.insert(SP.modules, module)
    return true
end

-- ------------------------------------------------------------
-- Ordre d'affichage : suit SPDB.modules.order, ignore les noms non enregistrés,
-- puis ajoute en fin les modules enregistrés mais absents de `order`.
-- ------------------------------------------------------------
function SP:GetOrderedModules()
    local result, seen = {}, {}
    local order = (SP.db and SP.db.modules and SP.db.modules.order) or {}
    for _, name in ipairs(order) do
        local m = SP.modulesByName[name]
        if m then
            result[#result + 1] = m
            seen[name] = true
        end
    end
    for _, m in ipairs(SP.modules) do
        if not seen[m.name] then result[#result + 1] = m end
    end
    return result
end

-- ------------------------------------------------------------
-- B) Construction visuelle : un bandeau par module.
--   Header :  [▶/▼] Label                 [⚙] [✕]
--   Content : frame du module (hauteur = SPDB.modules[name].height)
-- TODO(dev étape 2) :
--   • Préallouer header + content par module (hors combat)
--   • Clic gauche titre / bouton ▶ → toggle collapsed (sauve dans SPDB)
--   • ⚙ → options inline ; ✕ → désactiver (Disable + masquer)
--   • Appeler module:Init() une seule fois, puis module:Enable()
-- ------------------------------------------------------------
function SP:BuildModules()
    -- TODO(dev étape 2)
end

-- ------------------------------------------------------------
-- C) Drag-to-reorder
-- TODO(dev étape 3) :
--   • DragStart header → fantôme translucide qui suit la souris
--   • Calcul du slot cible par position Y (coordonnées de layout stockées, PAS GetCenter — AP-09)
--   • DragStop → réécrire SPDB.modules.order, puis RebuildLayout()
-- ------------------------------------------------------------

-- RebuildLayout : ré-ancre tous les modules de haut en bas selon GetOrderedModules.
-- TODO(dev étape 2-3).
function SP:RebuildLayout()
    -- for i, m in ipairs(SP:GetOrderedModules()) do ... anchor TOP->BOTTOM ... end
    -- Sauvegarder l'ordre courant dans SPDB.modules.order.
end
