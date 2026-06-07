-- ============================================================
-- Module : GameMenu — raccourcis vers les menus principaux du jeu
-- ============================================================
-- SKELETON. Bon premier test du système de modules (simple, sans event).
local ADDON_NAME, SP = ...

local M = {
    name          = "GameMenu",
    label         = "Menus",
    defaultHeight = 60,
}

-- TODO(dev étape 5) :
--   • Grille de boutons-icônes : Perso, Talents, Sac, Carte, Journal de quêtes,
--     Compétences, Guide, Collections, Commanderie, Récompenses PvP.
--   • Fonctions natives : ToggleCharacter("PaperDollFrame"), ToggleBag(0),
--     ToggleWorldMap(), ToggleQuestLog(), ToggleSpellBook(...), ToggleCollectionsJournal(), etc.
--   ⚠ Préallouer les boutons (pas de CreateFrame au survol). Certaines bascules
--     d'UI peuvent être protégées en combat → guard InCombatLockdown() si besoin.
--   • Icônes : textures Blizzard natives (atlas ou chemins).
function M:Init(content)
    self.content = content
end

function M:Enable()  end
function M:Disable() end
function M:OnResize(w, h) end

SP:RegisterModule(M)
