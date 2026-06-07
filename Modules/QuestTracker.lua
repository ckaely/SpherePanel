-- ============================================================
-- Module : QuestTracker — remplace le traqueur de quêtes natif
-- ============================================================
-- SKELETON. Module CORE : doit fonctionner avant les autres.
local ADDON_NAME, SP = ...

local M = {
    name          = "QuestTracker",
    label         = "Quêtes",
    defaultHeight = 300,
}

-- TODO(dev étape 4) :
--   • ObjectiveTrackerFrame:Hide() — UNIQUEMENT au PLAYER_LOGIN (jamais au load).
--     ⚠ Masquer/parenter ObjectiveTrackerFrame peut tainter l'auto-watch des quêtes.
--       Préférer Hide() simple + guard InCombatLockdown() ; ne pas reparenter.
--   • Lister quêtes : C_QuestLog.GetNumQuestLogEntries / GetInfo(index) / GetQuestObjectives(questID)
--   • Titre cliquable, objectifs + barres de progression
--   • Toggle WATCHED : C_QuestLog.AddQuestWatch / RemoveQuestWatch (protégé en combat → guard)
--   • Scénario / Delves / M+ : C_Scenario.* (à câbler en second temps)
function M:Init(content)
    self.content = content
end

function M:Enable()  end
function M:Disable() end
function M:OnResize(w, h) end

SP:RegisterModule(M)
