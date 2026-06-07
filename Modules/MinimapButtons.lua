-- ============================================================
-- Module : MinimapButtons — collecteur d'icônes minimap d'addons
-- ============================================================
-- SKELETON.
local ADDON_NAME, SP = ...

local M = {
    name          = "MinimapButtons",
    label         = "Icônes addons",
    defaultHeight = 40,
}

-- TODO(dev étape 6) :
--   • Scanner Minimap:GetChildren() pour repérer les boutons d'addons (heuristique : nom/texture).
--   • Les reparenter dans self.content via button:SetParent(content) + ré-ancrage en grille.
--   ⚠ Mémoriser parent + points D'ORIGINE de chaque bouton volé → restaurer EXACTEMENT à Disable().
--   ⚠ Guard InCombatLockdown() : reparenter une frame protégée en combat lève ADDON_ACTION_BLOCKED.
--   • Compat LibDBIcon-1.0 : préférer son API (LibStub("LibDBIcon-1.0")) si présent,
--     plutôt que de voler les frames qu'il gère.
--   • Options : taille des icônes, nombre par ligne.
function M:Init(content)
    self.content = content
    self.stolen = {}   -- [button] = { parent=..., points={...} } pour restauration
end

function M:Enable()  end
function M:Disable() end   -- DOIT restaurer tous les boutons de self.stolen
function M:OnResize(w, h) end

SP:RegisterModule(M)
