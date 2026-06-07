-- ============================================================
-- PanelFrame.lua — Frame principal (déplaçable, redimensionnable)
-- ============================================================
-- SKELETON : la création réelle du panneau est l'étape 1 du dev.
-- Ce fichier définit le contrat et un squelette de frame non destructif.
local ADDON_NAME, SP = ...

-- Crée le conteneur principal du panneau. Idempotent.
-- TODO(dev étape 1) :
--   • CreateFrame("Frame", "SpherePanelMain", UIParent)
--   • Ancrage TOPRIGHT depuis SPDB.panel.x/y, largeur SPDB.panel.width
--   • SetMovable(true) + handle de drag sur une barre de titre (hors combat)
--   • SetClampedToScreen(true) pour ne jamais sortir de l'écran
--   • Sauvegarde position dans SPDB.panel.x/y sur DragStop (via points relatifs, PAS GetCenter — AP-09)
--   • Resize handle bas pour SPDB.panel.width → appeler OnResize de chaque module
function SP:CreatePanel()
    if SP.panel then return SP.panel end

    local p = CreateFrame("Frame", "SpherePanelMain", UIParent)
    p:SetSize(SP.db.panel.width or 280, 600)
    p:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", SP.db.panel.x or -20, SP.db.panel.y or -200)
    p:SetClampedToScreen(true)

    SP.panel = p
    return p
end

-- Verrouille / déverrouille le déplacement. TODO(dev étape 1).
function SP:SetPanelLocked(locked)
    SP.db.panel.locked = locked and true or false
    -- TODO : activer/désactiver le mouse / le handle de drag.
end
