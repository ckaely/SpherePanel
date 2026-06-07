-- ============================================================
-- Module : Chat — fenêtre de chat compacte intégrée au panneau
-- ============================================================
-- SKELETON.
local ADDON_NAME, SP = ...

local M = {
    name          = "Chat",
    label         = "Chat",
    defaultHeight = 200,
}

-- TODO(dev étape 9) :
--   • Option A : détacher/réancrer ChatFrame1 dans self.content (réversible à Disable).
--   • Option B : FCF_OpenNewWindow() pour une fenêtre dédiée.
--   ⚠ Reparenter une ChatFrame Blizzard peut casser le redimensionnement natif et
--     le menu d'onglets ; toujours restaurer l'ancrage d'origine dans Disable().
--   • Champ de saisie en bas du module.
--   • Options : canal affiché, taille de police, timestamps.
function M:Init(content)
    self.content = content
end

function M:Enable()  end
function M:Disable() end
function M:OnResize(w, h) end

SP:RegisterModule(M)
