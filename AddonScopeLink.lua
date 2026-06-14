-- ============================================================
-- SpherePanel · AddonScopeLink (additif, non destructif)
--   Branche SpherePanel sur AddonScope. SpherePanel n'a pas de profileur
--   par module -> AUCUNE fausse mesure CPU n'est remontée (honnêteté).
--   Apport : addon enregistré + forward des activations/désactivations de
--   modules dans les logs AddonScope (post-hook non destructif).
--   File d'attente si AddonScope charge après. Chargé en dernier dans le .toc.
-- ============================================================
local SP = _G["SpherePanel"]
if not SP then return end

local NAME = "SpherePanel"

local function enqueue(method, ...)
    if AddonScope and AddonScope[method] then return AddonScope[method](...) end
    AddonScopeQueue = AddonScopeQueue or {}
    table.insert(AddonScopeQueue, { method, ... })
end

-- liste documentaire des modules (pas de CPU : SpherePanel n'instrumente pas)
local function moduleList()
    local t = {}
    if type(SP.modules) == "table" then
        for _, m in ipairs(SP.modules) do if m and m.name then t[#t + 1] = m.label or m.name end end
    end
    return t
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function()
    enqueue("RegisterAddon", NAME, { modules = moduleList() })
    enqueue("Log", NAME, "Core", "INFO", "SpherePanel branché sur AddonScope")

    if not SP._asHooked then
        SP._asHooked = true
        if SP.EnableModule then
            hooksecurefunc(SP, "EnableModule", function(_, name)
                enqueue("Log", NAME, tostring(name or ""), "INFO", "module activé")
            end)
        end
        if SP.DisableModuleUI then
            hooksecurefunc(SP, "DisableModuleUI", function(_, m)
                enqueue("Log", NAME, (m and m.name) or "", "INFO", "module désactivé")
            end)
        end
    end
end)
