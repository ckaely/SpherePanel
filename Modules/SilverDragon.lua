-- ============================================================
-- Module : SilverDragon — intégration alertes de rares (dépendance optionnelle)
-- ============================================================
-- SKELETON.
local ADDON_NAME, SP = ...

local M = {
    name          = "SilverDragon",
    label         = "Rares",
    defaultHeight = 80,
}

-- TODO(dev étape 11) :
--   • Détection : C_AddOns.IsAddOnLoaded("SilverDragon")
--   • Présent : hooker SilverDragon:OnSeeUnit() ou écouter ses events custom (callback registry).
--   • Absent : afficher "SilverDragon non installé — module désactivé" (pas de carré vide).
--   • Affichage : nom du rare, zone, dernière détection, bouton "Ping carte".
--   • Options : son d'alerte, durée d'affichage.
function M:Init(content)
    self.content = content
    self.available = C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("SilverDragon")
end

function M:Enable()  end
function M:Disable() end
function M:OnResize(w, h) end

SP:RegisterModule(M)
