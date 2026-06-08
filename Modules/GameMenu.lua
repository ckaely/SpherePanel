-- ============================================================
-- Module : GameMenu — raccourcis vers les menus principaux du jeu
-- ============================================================
-- Étape 5. Grille 6×2 centrée. Icônes copiées des micro-boutons Blizzard natifs.
local ADDON_NAME, SP = ...

local M = {
    name          = "GameMenu",
    label         = "Menus",
    defaultHeight = 76,
}

local FALLBACK_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"
local BTN, GAP = 30, 6
local PER_ROW = 6   -- 6 icônes par ligne → 6/6 pour 12 entrées

-- 12 entrées (6 haut + 6 bas). micro = nom du micro-bouton Blizzard à copier ; tex = fallback.
local ITEMS = {
    { "Personnage",   micro = "CharacterMicroButton",    tex = "Interface\\Icons\\Achievement_Character_Human_Male",
      fn = function() ToggleCharacter("PaperDollFrame") end },
    { "Sorts/Talents", micro = "PlayerSpellsMicroButton", tex = "Interface\\Icons\\INV_Misc_Book_09",
      fn = function()
        if PlayerSpellsUtil and PlayerSpellsUtil.ToggleSpellBookFrame then PlayerSpellsUtil.ToggleSpellBookFrame()
        elseif ToggleTalentFrame then ToggleTalentFrame() end
      end },
    { "Sacs",         tex = "Interface\\Buttons\\Button-Backpack-Up",
      fn = function() if ToggleAllBags then ToggleAllBags() else ToggleBag(0) end end },
    { "Carte",        tex = "Interface\\Icons\\INV_Misc_Map_01",
      fn = function() ToggleWorldMap() end },
    { "Quêtes",       micro = "QuestLogMicroButton",      tex = "Interface\\Icons\\INV_Misc_Book_07",
      fn = function() if ToggleQuestLog then ToggleQuestLog() end end },
    { "Hauts faits",  micro = "AchievementMicroButton",   tex = "Interface\\Icons\\Achievement_Quests_Completed_08",
      fn = function() if ToggleAchievementFrame then ToggleAchievementFrame() end end },
    { "Collections",  micro = "CollectionsMicroButton",   tex = "Interface\\Icons\\MountJournalPortrait",
      fn = function() if ToggleCollectionsJournal then ToggleCollectionsJournal() end end },
    { "Aventures",    micro = "EJMicroButton",            tex = "Interface\\Icons\\INV_Misc_Map02",
      fn = function() if ToggleEncounterJournal then ToggleEncounterJournal() end end },
    { "Groupe",       micro = "LFDMicroButton",           tex = "Interface\\Icons\\INV_Helmet_08",
      fn = function() if PVEFrame_ToggleFrame then PVEFrame_ToggleFrame() elseif ToggleLFDParentFrame then ToggleLFDParentFrame() end end },
    { "Guilde",       micro = "GuildMicroButton",         tex = "Interface\\Icons\\Achievement_GuildPerk_EverybodysFriend",
      fn = function() if ToggleGuildFrame then ToggleGuildFrame() end end },
    { "JcJ",          tex = "Interface\\Icons\\Achievement_PVP_A_A",
      fn = function() if TogglePVPUI then TogglePVPUI() end end },
    { "Menu",         micro = "MainMenuMicroButton",      tex = "Interface\\Icons\\INV_Misc_Gear_01",
      fn = function() ToggleGameMenu() end },
}

-- Copie l'icône d'un micro-bouton Blizzard (atlas natif) ; sinon texture fallback.
local function ApplyIcon(tex, item)
    if item.micro then
        local mb = _G[item.micro]
        local nt = mb and mb.GetNormalTexture and mb:GetNormalTexture()
        if nt then
            local atlas = nt.GetAtlas and nt:GetAtlas()
            if atlas and atlas ~= "" then
                if pcall(tex.SetAtlas, tex, atlas, true) then return end
            end
        end
    end
    tex:SetTexture(item.tex or FALLBACK_ICON)
end

function M:Init(body)
    self.body = body
    self.buttons = {}
end

function M:Enable()
    if not self._built then
        if InCombatLockdown() then return end
        for i, item in ipairs(ITEMS) do
            local b = CreateFrame("Button", nil, self.body)
            b:SetSize(BTN, BTN)
            local tex = b:CreateTexture(nil, "ARTWORK")
            tex:SetPoint("TOPLEFT", b, "TOPLEFT", 2, -2)
            tex:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -2, 2)
            ApplyIcon(tex, item)
            b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
            b.label, b.action = item[1], item.fn
            b:SetScript("OnClick", function(s) pcall(s.action) end)
            b:SetScript("OnEnter", function(s)
                GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
                GameTooltip:SetText(s.label)
                GameTooltip:Show()
            end)
            b:SetScript("OnLeave", function() GameTooltip:Hide() end)
            self.buttons[i] = b
        end
        self._built = true
        if self._placeholder then self._placeholder:Hide() end
    end
    self:Layout()
end

function M:Disable()
    for _, b in ipairs(self.buttons) do b:Hide() end
end

function M:Layout()
    if not self._built then return end
    local w = self.body:GetWidth()
    if not w or w < 1 then w = SP.db.panel.width or 280 end
    local rowW = PER_ROW * (BTN + GAP) - GAP
    local leftPad = math.max(GAP, (w - rowW) / 2)   -- centrage horizontal
    for i, b in ipairs(self.buttons) do
        local col = (i - 1) % PER_ROW
        local rowN = math.floor((i - 1) / PER_ROW)
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", self.body, "TOPLEFT", leftPad + col * (BTN + GAP), -(GAP + rowN * (BTN + GAP)))
        b:Show()
    end
    local rows = math.ceil(#self.buttons / PER_ROW)
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
