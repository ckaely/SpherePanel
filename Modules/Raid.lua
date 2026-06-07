-- ============================================================
-- Module : Raid — barres de vie du groupe/raid
-- ============================================================
-- SKELETON.
local ADDON_NAME, SP = ...

local M = {
    name          = "Raid",
    label         = "Groupe",
    defaultHeight = 180,
}

-- TODO(dev étape 7) :
--   • Events : GROUP_ROSTER_UPDATE, UNIT_HEALTH, UNIT_MAXHEALTH
--   • Une barre par membre : nom + % vie + couleur de classe
--   • Layout : grille 2 colonnes en raid, 1 colonne en groupe
--   ⚠ AP-01 : JAMAIS d'arithmétique Lua sur UnitHealth/UnitHealthMax (secret tainted Midnight).
--       Piloter la barre par C-API : bar:SetMinMaxValues(0, max) / bar:SetValue(hp),
--       ou UnitHealthPercent(unit, false, CurveConstants.ScaleTo100) sur 0..100.
--   • Pool de barres préchauffé hors combat (Pattern H) ; pas de CreateFrame en combat.
--   • Options : taille des barres, afficher/masquer mana, couleur par classe.
function M:Init(content)
    self.content = content
end

function M:Enable()  end
function M:Disable() end
function M:OnResize(w, h) end

SP:RegisterModule(M)
