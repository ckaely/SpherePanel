-- ============================================================
-- Module : GameMenu ("Menus") — raccourcis + onglet Addons (icônes minimap)
-- ============================================================
-- Onglets [Menus | Addons] (molette pour switcher). Horloge + FPS dans le bandeau.
-- Onglet Addons : collecte les boutons LibDBIcon (propres) → exclut les parasites non-LibDBIcon.
local ADDON_NAME, SP = ...

local M = {
    name          = "GameMenu",
    label         = "Menus",
    defaultHeight = 64,
}

local FALLBACK_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"
local BTN, GAP, PER_ROW = 30, 6, 6
local TAB_H = 16
local ICON, IGAP = 26, 4   -- onglet addons

local ITEMS = {
    { "Personnage",    micro = "CharacterMicroButton",    tex = "Interface\\Icons\\Achievement_Character_Human_Male",
      fn = function() ToggleCharacter("PaperDollFrame") end },
    { "Sorts/Talents", micro = "PlayerSpellsMicroButton", tex = "Interface\\Icons\\INV_Misc_Book_09",
      fn = function()
        if PlayerSpellsUtil and PlayerSpellsUtil.ToggleSpellBookFrame then PlayerSpellsUtil.ToggleSpellBookFrame()
        elseif ToggleTalentFrame then ToggleTalentFrame() end
      end },
    { "Sacs",          tex = "Interface\\Buttons\\Button-Backpack-Up",
      fn = function() if ToggleAllBags then ToggleAllBags() else ToggleBag(0) end end },
    { "Carte",         tex = "Interface\\Icons\\INV_Misc_Map_01",
      fn = function() ToggleWorldMap() end },
    { "Quêtes",        micro = "QuestLogMicroButton",      tex = "Interface\\Icons\\INV_Misc_Book_07",
      fn = function() if ToggleQuestLog then ToggleQuestLog() end end },
    { "Hauts faits",   micro = "AchievementMicroButton",   tex = "Interface\\Icons\\Achievement_Quests_Completed_08",
      fn = function() if ToggleAchievementFrame then ToggleAchievementFrame() end end },
    { "Collections",   micro = "CollectionsMicroButton",   tex = "Interface\\Icons\\MountJournalPortrait",
      fn = function() if ToggleCollectionsJournal then ToggleCollectionsJournal() end end },
    { "Aventures",     micro = "EJMicroButton",            tex = "Interface\\Icons\\INV_Misc_Map02",
      fn = function() if ToggleEncounterJournal then ToggleEncounterJournal() end end },
    { "Groupe",        micro = "LFDMicroButton",           tex = "Interface\\Icons\\INV_Helmet_08",
      fn = function() if PVEFrame_ToggleFrame then PVEFrame_ToggleFrame() elseif ToggleLFDParentFrame then ToggleLFDParentFrame() end end },
    { "Guilde",        micro = "GuildMicroButton",         tex = "Interface\\Icons\\Achievement_GuildPerk_EverybodysFriend",
      fn = function() if ToggleGuildFrame then ToggleGuildFrame() end end },
    { "JcJ",           tex = "Interface\\Icons\\Achievement_PVP_A_A",
      fn = function() if TogglePVPUI then TogglePVPUI() end end },
    { "Menu",          micro = "MainMenuMicroButton",      tex = "Interface\\Icons\\INV_Misc_Gear_01",
      fn = function() ToggleGameMenu() end },
}

local function ApplyIcon(tex, item)
    if item.micro then
        local mb = _G[item.micro]
        local nt = mb and mb.GetNormalTexture and mb:GetNormalTexture()
        if nt then
            local atlas = nt.GetAtlas and nt:GetAtlas()
            if atlas and atlas ~= "" and pcall(tex.SetAtlas, tex, atlas, true) then return end
        end
    end
    tex:SetTexture(item.tex or FALLBACK_ICON)
end

local function HasClick(f)
    if not f.GetScript then return false end
    return (f:GetScript("OnClick") or f:GetScript("OnMouseUp") or f:GetScript("OnMouseDown")) and true or false
end

-- ============================================================
function M:Init(body)
    self.body = body
    self.buttons = {}
    self.stolen = {}
    self.order = {}

    -- Barre d'onglets
    self.tabs = CreateFrame("Frame", nil, body)
    self.tabs:SetPoint("TOPLEFT", body, "TOPLEFT", 4, -2)
    self.tabs:SetPoint("TOPRIGHT", body, "TOPRIGHT", -4, -2)
    self.tabs:SetHeight(TAB_H)
    self.tabBtns = {}
    local defs = { { "menus", "Menus" }, { "addons", "Addons" } }
    local x = 0
    for _, d in ipairs(defs) do
        local b = CreateFrame("Button", nil, self.tabs)
        b:SetSize(58, TAB_H)
        b:SetPoint("LEFT", self.tabs, "LEFT", x, 0)
        local sel = b:CreateTexture(nil, "BACKGROUND"); sel:SetAllPoints(b); sel:SetColorTexture(1,1,1,0.16); sel:Hide()
        b.sel = sel
        b.fs = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); b.fs:SetAllPoints(b); b.fs:SetText(d[2])
        b.tab = d[1]
        b:SetScript("OnClick", function(s) self:SetTab(s.tab) end)
        self.tabBtns[d[1]] = b
        x = x + 60
    end

    -- Pages
    self.menusPage = CreateFrame("Frame", nil, body)
    self.menusPage:SetPoint("TOPLEFT", self.tabs, "BOTTOMLEFT", 0, -2)
    self.menusPage:SetPoint("BOTTOMRIGHT", body, "BOTTOMRIGHT", -4, 0)
    self.addonsPage = CreateFrame("Frame", nil, body)
    self.addonsPage:SetPoint("TOPLEFT", self.tabs, "BOTTOMLEFT", 0, -2)
    self.addonsPage:SetPoint("BOTTOMRIGHT", body, "BOTTOMRIGHT", -4, 0)
    self.addonsPage:Hide()

    -- Molette = switch d'onglet
    body:EnableMouseWheel(true)
    body:SetScript("OnMouseWheel", function()
        local cur = SP:GetModuleConfig(self.name).activeTab
        self:SetTab(cur == "menus" and "addons" or "menus")
    end)

    -- Horloge / FPS dans le bandeau
    self._accum = 1
    body:SetScript("OnUpdate", function(_, e)
        self._accum = self._accum + e
        if self._accum >= 1 then self._accum = 0; self:UpdateHeaderInfo() end
    end)
end

function M:Enable()
    if not self._built then
        if InCombatLockdown() then return end
        for i, item in ipairs(ITEMS) do
            local b = CreateFrame("Button", nil, self.menusPage)
            b:SetSize(BTN, BTN)
            local tex = b:CreateTexture(nil, "ARTWORK")
            tex:SetPoint("TOPLEFT", b, "TOPLEFT", 2, -2)
            tex:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -2, 2)
            ApplyIcon(tex, item)
            b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
            b.label, b.action = item[1], item.fn
            b:SetScript("OnClick", function(s) pcall(s.action) end)
            b:SetScript("OnEnter", function(s) GameTooltip:SetOwner(s, "ANCHOR_RIGHT"); GameTooltip:SetText(s.label); GameTooltip:Show() end)
            b:SetScript("OnLeave", function() GameTooltip:Hide() end)
            self.buttons[i] = b
        end
        self._built = true
        if self._placeholder then self._placeholder:Hide() end
    end
    self:CollectAddons()
    self:SetTab(SP:GetModuleConfig(self.name).activeTab or "menus")
    self:UpdateHeaderInfo()
end

function M:Disable()
    for _, b in ipairs(self.buttons) do b:Hide() end
    self:RestoreAddons()
    SP:SetModuleHeaderText(self, "")
end

-- ------------------------------------------------------------
-- Onglets
-- ------------------------------------------------------------
function M:SetTab(tab)
    local cfg = SP:GetModuleConfig(self.name)
    cfg.activeTab = tab
    self.menusPage:SetShown(tab == "menus")
    self.addonsPage:SetShown(tab == "addons")
    for t, b in pairs(self.tabBtns) do b.sel:SetShown(t == tab) end
    self:Layout()
end

function M:UpdateHeaderInfo()
    local cfg = SP:GetModuleConfig(self.name)
    local parts = {}
    if cfg.showClock then
        parts[#parts + 1] = cfg.clock24h and date("%H:%M") or date("%I:%M %p")
    end
    if cfg.showFPS then
        parts[#parts + 1] = ("%d fps"):format(math.floor(GetFramerate() + 0.5))
    end
    SP:SetModuleHeaderText(self, table.concat(parts, "  "))
end

-- ------------------------------------------------------------
-- Layout
-- ------------------------------------------------------------
function M:Layout()
    if not self._built then return end
    local cfg = SP:GetModuleConfig(self.name)
    local w = self.body:GetWidth()
    if not w or w < 1 then w = SP.db.panel.width or 280 end
    local needed

    if cfg.activeTab == "addons" then
        needed = self:LayoutAddons(w)
    else
        local rowW = PER_ROW * (BTN + GAP) - GAP
        local leftPad = math.max(GAP, (w - rowW) / 2)
        for i, b in ipairs(self.buttons) do
            local col, rowN = (i - 1) % PER_ROW, math.floor((i - 1) / PER_ROW)
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", self.menusPage, "TOPLEFT", leftPad + col * (BTN + GAP), -(GAP + rowN * (BTN + GAP)))
            b:Show()
        end
        local rows = math.ceil(#self.buttons / PER_ROW)
        needed = GAP + rows * (BTN + GAP)
    end

    needed = (needed or 40) + TAB_H + 4
    if cfg.height ~= needed then cfg.height = needed; SP:RebuildLayout() end
end

function M:LayoutAddons(w)
    local cfg = SP:GetModuleConfig(self.name)
    local count = #self.order
    if count == 0 then return 30 end
    local perRow = math.max(1, math.floor((w - IGAP) / (ICON + IGAP)))
    if perRow > count then perRow = count end
    local rowW = perRow * (ICON + IGAP) - IGAP
    local leftPad = (cfg.addonAlign == "center") and math.max(IGAP, (w - rowW) / 2) or IGAP
    for i, button in ipairs(self.order) do
        local col, rowN = (i - 1) % perRow, math.floor((i - 1) / perRow)
        local cx = leftPad + col * (ICON + IGAP) + ICON / 2
        local cy = -(IGAP + rowN * (ICON + IGAP) + ICON / 2)
        button:ClearAllPoints()
        button:SetPoint("CENTER", self.addonsPage, "TOPLEFT", cx, cy)
        button:Show()
    end
    local rows = math.ceil(count / perRow)
    return IGAP + rows * (ICON + IGAP)
end

function M:OnResize(w, h) self:Layout() end

-- ------------------------------------------------------------
-- Onglet Addons : collecte LibDBIcon (propre, exclut les parasites non-LibDBIcon)
-- ------------------------------------------------------------
local function Blacklisted(name, list)
    if not name then return true end
    if list then for _, pat in ipairs(list) do if name:find(pat) then return true end end end
    return false
end

function M:StealOne(button)
    if not button or self.stolen[button] then return end
    local pts = {}
    for i = 1, button:GetNumPoints() do pts[i] = { button:GetPoint(i) } end
    self.stolen[button] = {
        parent = button:GetParent(), points = pts, scale = button:GetScale(),
        onUpdate = button:GetScript("OnUpdate"),
        onDragStart = button:GetScript("OnDragStart"),
        onDragStop = button:GetScript("OnDragStop"),
        movable = button:IsMovable(),
    }
    pcall(function() button:SetScript("OnUpdate", nil) end)
    pcall(function() button:SetScript("OnDragStart", nil) end)
    pcall(function() button:SetScript("OnDragStop", nil) end)
    pcall(function() button:SetMovable(false) end)
    button:SetParent(self.addonsPage)
    button:SetScale(1)
    self.order[#self.order + 1] = button
end

function M:CollectAddons()
    if InCombatLockdown() then return end
    local cfg = SP:GetModuleConfig(self.name)
    local bl = cfg.addonBlacklist

    -- 1) via LibDBIcon (source propre : un bouton par addon)
    local LDB = LibStub and LibStub("LibDBIcon-1.0", true)
    if LDB and LDB.GetButtonList then
        for _, key in ipairs(LDB:GetButtonList()) do
            local b = (LDB.GetMinimapButton and LDB:GetMinimapButton(key)) or _G["LibDBIcon10_" .. key]
            if b and not Blacklisted(b:GetName() or key, bl) then self:StealOne(b) end
        end
    end
    -- 2) enfants minimap nommés LibDBIcon* (au cas où la lib n'expose pas tout)
    local children = { Minimap:GetChildren() }
    for _, c in ipairs(children) do
        local n = c:GetName()
        if n and n:match("^LibDBIcon") and not Blacklisted(n, bl) and not self.stolen[c] then
            self:StealOne(c)
        end
    end
    table.sort(self.order, function(a, b) return (a:GetName() or "") < (b:GetName() or "") end)
end

function M:RestoreAddons()
    for button, o in pairs(self.stolen) do
        pcall(function()
            button:SetParent(o.parent or Minimap)
            button:SetScale(o.scale or 1)
            button:SetMovable(o.movable and true or false)
            button:SetScript("OnUpdate", o.onUpdate)
            button:SetScript("OnDragStart", o.onDragStart)
            button:SetScript("OnDragStop", o.onDragStop)
            button:ClearAllPoints()
            if o.points and #o.points > 0 then for _, p in ipairs(o.points) do button:SetPoint(unpack(p)) end
            else button:SetPoint("CENTER", Minimap, "CENTER", 0, 0) end
        end)
    end
    wipe(self.stolen); wipe(self.order)
end

-- /sp mbscan : diagnostic des boutons minimap
function M:Scan()
    SP:Print("Boutons minimap détectés (LibDBIcon) :")
    local LDB = LibStub and LibStub("LibDBIcon-1.0", true)
    if LDB and LDB.GetButtonList then
        for _, key in ipairs(LDB:GetButtonList()) do SP:Print("  " .. tostring(key)) end
    else
        SP:Print("  LibDBIcon non chargé.")
    end
    SP:Print("Enfants minimap (nom [type] clic) :")
    for _, c in ipairs({ Minimap:GetChildren() }) do
        SP:Print(("  %s [%s] %s"):format(c:GetName() or "<anon>", c:GetObjectType(), HasClick(c) and "clic" or "-"))
    end
    SP:Print("Exclure un parasite : SPDB.modules.GameMenu.addonBlacklist (motif du nom).")
end

SP:RegisterModule(M)
