-- ============================================================
-- Module : DamageMeter — compteur de dégâts/soins (moteur interne)
-- ============================================================
-- SKELETON.
local ADDON_NAME, SP = ...

local M = {
    name          = "DamageMeter",
    label         = "Dégâts",
    defaultHeight = 150,
}

-- TODO(dev étape 8) :
--   • COMBAT_LOG_EVENT_UNFILTERED → CombatLogGetCurrentEventInfo()
--   • Agréger dégâts/soins par joueur sur le combat actif (PLAYER_REGEN_DISABLED/ENABLED)
--   ⚠ Midnight : certaines valeurs du combat log peuvent être secret. Ne pas faire
--     d'arithmétique Lua aveugle sur des montants tainted ; valider/normaliser (cf. SNP _SafeNumber).
--   • Barres triées par DPS/HPS (réutiliser le pool de barres, pas de CreateFrame en combat).
--   • Dépendance optionnelle : si Details!/Skada chargé, afficher leurs données via leur API.
--   • Options : mode (DPS/HPS/both), reset auto, affichage noms/valeurs.
function M:Init(content)
    self.content = content
end

function M:Enable()  end
function M:Disable() end
function M:OnResize(w, h) end

SP:RegisterModule(M)
