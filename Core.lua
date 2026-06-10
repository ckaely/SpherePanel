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
-- conditions d'affichage par module (zone / combat / groupe)
SP.eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
SP.eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
SP.eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
SP.eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
SP.eventFrame:SetScript("OnEvent", function(_, event, ...)
    SP:OnEvent(event, ...)
end)

local CONDITION_EVENTS = {
    PLAYER_REGEN_ENABLED = true, PLAYER_REGEN_DISABLED = true,
    ZONE_CHANGED_NEW_AREA = true, GROUP_ROSTER_UPDATE = true,
}

function SP:OnEvent(event, arg1, ...)
    if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
        SP:Init()
    elseif event == "PLAYER_LOGIN" then
        SP:OnLogin()
    elseif event == "PLAYER_ENTERING_WORLD" then
        SP:OnEnteringWorld()
        if SP.loaded and SP.panel then SP:RebuildLayout() end
    elseif CONDITION_EVENTS[event] then
        if SP.loaded and SP.panel then SP:RebuildLayout() end
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
    SP:CreatePanel()      -- PanelFrame.lua : frame déplaçable + resize
    SP:BuildModules()     -- ModuleSystem.lua : header + content par module (appelle RebuildLayout)
    SP:ApplyPanelBehavior()  -- comportement 1/2/3 (magnétisation + bord déclencheur)
    SP:ApplyPanel2()         -- second panneau (option)
    SP:ApplyAppearance()     -- couleur/transparence du fond
    if SP.db.panel.fx and UIFrameFadeIn and SP.panel then
        UIFrameFadeIn(SP.panel, 0.6, 0, 1)   -- apparition stylée
    end
    SP:SetupSlash()
    -- RÈGLE : ObjectiveTrackerFrame:Hide() sera déclenché par QuestTracker (étape 4),
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

-- Applique une icône de l'atlas Media/wow_ico.tga (via Media/IconAtlas.lua) sur une texture.
function SP:SetIcon(tex, index)
    local c = SP.ICONS and SP.ICONS[index]
    if not (c and SP.ICON_TEXTURE) then return false end
    tex:SetTexture(SP.ICON_TEXTURE)
    tex:SetTexCoord(c[1], c[2], c[3], c[4])
    return true
end

-- Log console simple, throttle-able plus tard. Préfixe coloré.
function SP:Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cFF4AA3FFSpherePanel|r " .. tostring(msg))
end

-- ------------------------------------------------------------
-- Commandes slash : /sp et /spanel
-- ------------------------------------------------------------
function SP:SetupSlash()
    if SP._slashReady then return end
    SP._slashReady = true
    SLASH_SPHEREPANEL1 = "/sp"
    SLASH_SPHEREPANEL2 = "/spanel"
    SlashCmdList["SPHEREPANEL"] = function(msg) SP:HandleSlash(msg or "") end
end

function SP:HandleSlash(msg)
    msg = msg:gsub("^%s+", ""):gsub("%s+$", "")
    local cmd, rest = msg:match("^(%S*)%s*(.-)$")
    cmd = (cmd or ""):lower()

    if cmd == "lock" then
        SP:SetPanelLocked(not SP.db.panel.locked)
        SP:Print("Panneau " .. (SP.db.panel.locked and "verrouillé." or "déverrouillé."))
    elseif cmd == "reset" then
        SP:ResetPanel()
        SP:Print("Position et largeur réinitialisées.")
    elseif cmd == "show" then
        if SP.panel then SP.panel:Show() end
    elseif cmd == "hide" then
        if SP.panel then SP.panel:Hide() end
    elseif cmd == "config" or cmd == "options" then
        if SP.OpenConfig then SP:OpenConfig() else SP:Print("Panneau d'options indisponible.") end
    elseif cmd == "mbscan" then
        local mb = SP.modulesByName and SP.modulesByName["GameMenu"]
        if mb and mb.Scan then mb:Scan() else SP:Print("Module Menus indisponible.") end
    elseif cmd == "raretest" then
        -- alerte factice pour valider le module Rares (32491 = Proto-drake perdu dans le temps)
        local rm = SP.modulesByName and SP.modulesByName["SilverDragon"]
        if rm and rm.OnSeen then
            rm._enabled = true
            local mapID = (C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")) or 0
            rm:OnSeen(32491, mapID, 0.5, 0.5, false)
            SP:Print("Alerte de test envoyée au module Rares (clic droit = butin + modèle 3D).")
        else
            SP:Print("Module Rares indisponible.")
        end
    elseif cmd == "enable" and rest ~= "" then
        SP:EnableModule(rest)
    elseif cmd == "modules" then
        SP:Print("Modules :")
        for _, m in ipairs(SP:GetOrderedModules()) do
            local cfg = SP:GetModuleConfig(m.name)
            local state = (cfg and cfg.enabled) and "|cFF55FF55on|r" or "|cFFFF5555off|r"
            SP:Print(("  %s (%s) — %s"):format(m.name, m.label, state))
        end
    else
        SP:Print("Commandes : |cFFFFFFFF/sp|r config | mbscan | lock | reset | show | hide | modules | enable <Nom>")
    end
end
