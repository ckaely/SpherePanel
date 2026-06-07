-- ============================================================
-- Core.lua — Namespace, events, initialisation
-- ============================================================
-- Pattern namespace : table privée passée en vararg (best practice WoW).
-- On N'UTILISE PAS un global `SP` nu : SphereNameplates occupe déjà ce nom
-- global → collision garantie si les deux addons chargent. Voir BROKER.md DEC-001.
local ADDON_NAME, SP = ...

SP.version  = "0.1.0"
SP.modules  = {}          -- liste ordonnée des modules enregistrés (ordre d'enregistrement)
SP.modulesByName = {}     -- index nom -> module
SP.loaded   = false

-- Exposé en global uniquement pour debug / commandes slash, jamais comme source de vérité interne.
_G["SpherePanel"] = SP

-- ------------------------------------------------------------
-- Frame d'événements principal
-- ------------------------------------------------------------
SP.eventFrame = CreateFrame("Frame")
SP.eventFrame:RegisterEvent("ADDON_LOADED")
SP.eventFrame:RegisterEvent("PLAYER_LOGIN")
SP.eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
SP.eventFrame:SetScript("OnEvent", function(_, event, ...)
    SP:OnEvent(event, ...)
end)

function SP:OnEvent(event, arg1, ...)
    if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
        SP:Init()
    elseif event == "PLAYER_LOGIN" then
        SP:OnLogin()
    elseif event == "PLAYER_ENTERING_WORLD" then
        SP:OnEnteringWorld()
    end
end

-- ------------------------------------------------------------
-- Cycle de vie
-- ------------------------------------------------------------

-- Init : SavedVariables disponibles. Pas encore de frames de jeu garanties.
function SP:Init()
    if SP.loaded then return end
    SP:LoadConfig()          -- Config.lua : remplit SPDB depuis defaults (deep merge)
    SP.loaded = true
end

-- OnLogin : UI prête. C'est ici qu'on construit le panneau et qu'on active les modules.
function SP:OnLogin()
    -- TODO(dev étape 1) : SP:CreatePanel()  -- PanelFrame.lua
    -- TODO(dev étape 2) : SP:BuildModules()  -- ModuleSystem.lua : header + content par module
    -- TODO(dev étape 2) : SP:RebuildLayout()
    -- RÈGLE : ObjectiveTrackerFrame:Hide() doit être déclenché par QuestTracker
    --         UNIQUEMENT à partir d'ici (PLAYER_LOGIN), jamais au chargement du fichier.
end

-- OnEnteringWorld : hors-combat garanti au tout premier login → moment idéal pour
-- préchauffer les pools de frames (Pattern H SNP : jamais de CreateFrame en combat).
function SP:OnEnteringWorld()
    -- TODO(dev) : préchauffer pools (Raid bars, Auras icons, etc.) hors combat.
end

-- ------------------------------------------------------------
-- Helpers
-- ------------------------------------------------------------

-- Log console simple, throttle-able plus tard. Préfixe coloré.
function SP:Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cFF4AA3FFSpherePanel|r " .. tostring(msg))
end
