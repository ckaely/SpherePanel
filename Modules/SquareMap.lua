-- ============================================================
-- Module : SquareMap — minimap carrée (supprime le masque circulaire)
-- ============================================================
-- SKELETON.
local ADDON_NAME, SP = ...

local M = {
    name          = "SquareMap",
    label         = "Carte",
    defaultHeight = 200,
}

-- TODO(dev étape 10) :
--   • Masque carré : Minimap:SetMaskTexture("Interface\\Buttons\\WHITE8x8")
--     (chaîne vide non fiable selon build → préférer une texture carrée pleine).
--   • Optionnel : reparenter la Minimap dans self.content + ancrer + redimensionner.
--   ⚠ Mémoriser parent/points/masque/échelle D'ORIGINE → restaurer à Disable().
--   ⚠ Faire ces opérations hors combat (login / sortie de combat). La Minimap est
--     une frame sensible : guard InCombatLockdown().
--   • Options : zoom, afficher/masquer le bouton zoom, bordure.
function M:Init(content)
    self.content = content
    self.saved = {}    -- parent/points/mask/scale d'origine pour restauration
end

function M:Enable()  end
function M:Disable() end   -- DOIT restaurer la Minimap dans son état natif
function M:OnResize(w, h) end

SP:RegisterModule(M)
