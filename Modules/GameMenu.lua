-- ============================================================
-- Module : GameMenu — raccourcis vers les menus principaux du jeu
-- ============================================================
-- Étape 5. Grille de boutons-icônes. Chaque action sous pcall.
local ADDON_NAME, SP = ...

local M = {
    name          = "GameMenu",
    label         = "Menus",
    defaultHeight = 64,
}

local FALLBACK_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"

-- { label, atlas (micro-menu), action }
local ITEMS = {
    { "Personnage",   "UI-HUD-MicroMenu-Character-Up",            function() ToggleCharacter("PaperDollFrame") end },
    { "Sorts/Talents","UI-HUD-MicroMenu-SpellbookAbilities-Up",   function()
        if PlayerSpellsUtil and PlayerSpellsUtil.ToggleSpellBookFrame then PlayerSpellsUtil.ToggleSpellBookFrame()
        elseif ToggleTalentFrame then ToggleTalentFrame() end
    end },
    { "Sacs",         "UI-HUD-MicroMenu-Bags-Up",                 function() if ToggleAllBags then ToggleAllBags() else ToggleBag(0) end end },
    { "Carte",        "UI-HUD-MicroMenu-Map-Up",                  function() ToggleWorldMap() end },
    { "Quêtes",       "UI-HUD-MicroMenu-Questlog-Up",             function() if ToggleQuestLog then ToggleQuestLog() end end },
    { "Hauts faits",  "UI-HUD-MicroMenu-Achievements-Up",         function() if ToggleAchievementFrame then ToggleAchievementFrame() end end },
    { "Collections",  "UI-HUD-MicroMenu-Collections-Up",          function() if ToggleCollectionsJournal then ToggleCollectionsJournal() end end },
    { "Aventures",    "UI-HUD-MicroMenu-AdventureGuide-Up",       function() if ToggleEncounterJournal then ToggleEncounterJournal() end end },
    { "Groupe",       "UI-HUD-MicroMenu-GroupFinder-Up",          function() if PVEFrame_ToggleFrame then PVEFrame_ToggleFrame() elseif ToggleLFDParentFrame then ToggleLFDParentFrame() end end },
    { "Guilde",       "UI-HUD-MicroMenu-GuildCommunities-Up",     function() if ToggleGuildFrame then ToggleGuildFrame() end end },
    { "JcJ",          "UI-HUD-MicroMenu-GroupFinder-Up",          function() if TogglePVPUI then TogglePVPUI() end end },
    { "Menu",         "UI-HUD-MicroMenu-GameMenu-Up",             function() ToggleGameMenu() end },
}

local BTN, GAP = 30, 4

local function SetIcon(tex, atlas)
    local ok = pcall(tex.SetAtlas, tex, atlas, true)
    if not ok then tex:SetTexture(FALLBACK_ICON) end
end

function M:Init(body)
    self.body = body
    self.buttons = {}
end

function M:Enable()
    if self._built then self:Layout(); return end
    if InCombatLockdown() then return end  -- création différée si on entre déjà en combat
    for i, item in ipairs(ITEMS) do
        local b = CreateFrame("Button", nil, self.body)
        b:SetSize(BTN, BTN)
        local tex = b:CreateTexture(nil, "ARTWORK")
        tex:SetAllPoints(b)
        SetIcon(tex, item[2])
        b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
        b.label = item[1]
        b.action = item[3]
        b:SetScript("OnClick", function(self2) pcall(self2.action) end)
        b:SetScript("OnEnter", function(self2)
            GameTooltip:SetOwner(self2, "ANCHOR_RIGHT")
            GameTooltip:SetText(self2.label)
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        self.buttons[i] = b
    end
    self._built = true
    if self._placeholder then self._placeholder:Hide() end
    self:Layout()
end

function M:Disable()
    for _, b in ipairs(self.buttons) do b:Hide() end
end

function M:Layout()
    if not self._built then return end
    local w = self.body:GetWidth()
    if not w or w < 1 then w = SP.db.panel.width or 280 end
    local perRow = math.max(1, math.floor((w - GAP) / (BTN + GAP)))
    for i, b in ipairs(self.buttons) do
        local col = (i - 1) % perRow
        local rowN = math.floor((i - 1) / perRow)
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", self.body, "TOPLEFT", GAP + col * (BTN + GAP), -(GAP + rowN * (BTN + GAP)))
        b:Show()
    end
    -- ajuste la hauteur du module au nombre de lignes
    local rows = math.ceil(#self.buttons / perRow)
    local needed = GAP + rows * (BTN + GAP)
    local cfg = SP:GetModuleConfig(self.name)
    if cfg and cfg.height ~= needed then
        cfg.height = needed
        SP:RebuildLayout()
    end
end

function M:OnResize(w, h)
    self:Layout()
end

SP:RegisterModule(M)
