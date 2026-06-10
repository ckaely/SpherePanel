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
    headerless    = true,   -- fusionné avec le bandeau SpherePanel (pas de bandeau "Menus")
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
    self.order = {}      -- holders affichés
    self.holders = {}    -- pool de cases carrées

    -- Barre d'onglets
    self.tabs = CreateFrame("Frame", nil, body)
    self.tabs:SetPoint("TOPLEFT", body, "TOPLEFT", 4, -2)
    self.tabs:SetPoint("TOPRIGHT", body, "TOPRIGHT", -4, -2)
    self.tabs:SetHeight(TAB_H)
    self.tabBtns = {}
    local defs = { { "menus", "Menus" }, { "addons", "Addons" }, { "modules", "Modules" } }
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

    -- bouton "Gérer" (onglet Addons) : active le mode exclusion d'icônes
    local mg = CreateFrame("Button", nil, self.tabs)
    mg:SetSize(50, TAB_H)
    mg:SetPoint("RIGHT", self.tabs, "RIGHT", 0, 0)
    mg.fs = mg:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    mg.fs:SetAllPoints(mg); mg.fs:SetText("Gérer"); mg.fs:SetTextColor(0.7, 0.7, 0.7)
    mg:SetScript("OnClick", function() self:SetManage(not self._manage) end)
    mg:SetScript("OnEnter", function(s)
        GameTooltip:SetOwner(s, "ANCHOR_BOTTOM")
        GameTooltip:SetText("Mode gestion : clic sur une icône = exclure définitivement")
        GameTooltip:Show()
    end)
    mg:SetScript("OnLeave", function() GameTooltip:Hide() end)
    self.manageBtn = mg

    -- Pages
    self.menusPage = CreateFrame("Frame", nil, body)
    self.menusPage:SetPoint("TOPLEFT", self.tabs, "BOTTOMLEFT", 0, -2)
    self.menusPage:SetPoint("BOTTOMRIGHT", body, "BOTTOMRIGHT", -4, 0)
    self.addonsPage = CreateFrame("Frame", nil, body)
    self.addonsPage:SetPoint("TOPLEFT", self.tabs, "BOTTOMLEFT", 0, -2)
    self.addonsPage:SetPoint("BOTTOMRIGHT", body, "BOTTOMRIGHT", -4, 0)
    self.addonsPage:Hide()

    self.modulesPage = CreateFrame("Frame", nil, body)
    self.modulesPage:SetPoint("TOPLEFT", self.tabs, "BOTTOMLEFT", 0, -2)
    self.modulesPage:SetPoint("BOTTOMRIGHT", body, "BOTTOMRIGHT", -4, 0)
    self.modulesPage:Hide()
    self.modRows = {}

    -- Molette = switch d'onglet (cycle menus → addons → modules)
    local ORDER = { menus = "addons", addons = "modules", modules = "menus" }
    body:EnableMouseWheel(true)
    body:SetScript("OnMouseWheel", function()
        local cur = SP:GetModuleConfig(self.name).activeTab or "menus"
        self:SetTab(ORDER[cur] or "menus")
    end)

    -- Horloge / FPS dans le bandeau
    self._accum = 1
    body:SetScript("OnUpdate", function(_, e)
        self._accum = self._accum + e
        if self._accum >= 1 then self._accum = 0; self:UpdateHeaderInfo() end
    end)
end

-- Construction des boutons-icônes maison (fallback si le vrai micro-menu est indisponible).
function M:BuildCustomMenus()
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
end

function M:Enable()
    if not self._built then
        if InCombatLockdown() then return end
        if not self:EmbedMicroMenu() then self:BuildCustomMenus() end  -- vrai micro-menu Blizzard en priorité
        self._built = true
        if self._placeholder then self._placeholder:Hide() end
    end
    self._enabled = true
    self:CollectAddons()
    -- certains addons créent leur bouton après le login → re-collecte différée
    C_Timer.After(3, function()
        if self._enabled and not InCombatLockdown() then self:CollectAddons(); self:Layout() end
    end)
    C_Timer.After(8, function()
        if self._enabled and not InCombatLockdown() then self:CollectAddons(); self:Layout() end
    end)
    self:SetTab(SP:GetModuleConfig(self.name).activeTab or "menus")
    self:UpdateHeaderInfo()
end

function M:Disable()
    self._enabled = false
    for _, b in ipairs(self.buttons) do b:Hide() end
    self:RestoreAddons()
    self:RestoreMicroMenu()
    SP:SetModuleHeaderText(self, "")
end

-- ------------------------------------------------------------
-- Vrai micro-menu Blizzard intégré dans l'onglet Menus
-- ------------------------------------------------------------
function M:EmbedMicroMenu()
    local names = _G.MICRO_BUTTONS
    if type(names) ~= "table" then return false end
    self.microButtons = self.microButtons or {}
    self.microSaved = self.microSaved or {}
    local got = false
    for _, name in ipairs(names) do
        local b = _G[name]
        if b and not self.microSaved[b] then
            local pts = {}
            for i = 1, b:GetNumPoints() do pts[i] = { b:GetPoint(i) } end
            self.microSaved[b] = { parent = b:GetParent(), points = pts, scale = b:GetScale() }
            b:SetParent(self.menusPage)
            b:SetScale(1)
            self.microButtons[#self.microButtons + 1] = b
            got = true
        end
    end
    if got and not self._microHooked then
        self._microHooked = true
        if _G.UpdateMicroButtons then
            hooksecurefunc("UpdateMicroButtons", function()
                if self._microEmbedded and not InCombatLockdown()
                    and SP:GetModuleConfig(self.name).activeTab == "menus" then
                    self:LayoutMicroMenu()
                end
            end)
        end
    end
    self._microEmbedded = got
    return got
end

function M:LayoutMicroMenu()
    if not self.microButtons then return 40 end
    local w = self.menusPage:GetWidth()
    if not w or w < 1 then w = (SP.db.panel.width or 280) - 8 end
    local x, y, rowH = 0, 0, 0
    for _, b in ipairs(self.microButtons) do
        if b:GetParent() ~= self.menusPage then pcall(b.SetParent, b, self.menusPage) end
        local bw, bh = b:GetWidth() or 24, b:GetHeight() or 30
        if x + bw > w then x = 0; y = y + rowH + 2; rowH = 0 end
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", self.menusPage, "TOPLEFT", x, -y)
        b:Show()
        x = x + bw + 2
        if bh > rowH then rowH = bh end
    end
    return y + rowH
end

function M:RestoreMicroMenu()
    if not self.microSaved then return end
    for b, o in pairs(self.microSaved) do
        pcall(function()
            b:SetParent(o.parent or _G.MicroMenu or UIParent)
            b:SetScale(o.scale or 1)
            b:ClearAllPoints()
            if o.points and #o.points > 0 then for _, p in ipairs(o.points) do b:SetPoint(unpack(p)) end end
        end)
    end
    self._microEmbedded = false
    wipe(self.microSaved); if self.microButtons then wipe(self.microButtons) end
    if _G.UpdateMicroButtons then pcall(_G.UpdateMicroButtons) end
end

-- ------------------------------------------------------------
-- Onglets
-- ------------------------------------------------------------
function M:SetTab(tab)
    local cfg = SP:GetModuleConfig(self.name)
    cfg.activeTab = tab
    self.menusPage:SetShown(tab == "menus")
    self.addonsPage:SetShown(tab == "addons")
    self.modulesPage:SetShown(tab == "modules")
    for t, b in pairs(self.tabBtns) do b.sel:SetShown(t == tab) end
    if tab == "modules" then self:RefreshModulesTab() end
    self:Layout()
end

-- Onglet "Modules" : boutons côte à côte (flow) qui s'illuminent quand le module est actif.
local MOD_GREEN, MOD_RED = { 0.20, 0.80, 0.30 }, { 0.55, 0.20, 0.20 }
local MBTN_H, MBTN_PAD, MBTN_GAP = 20, 10, 4
function M:RefreshModulesTab()
    local list = {}
    for _, m in ipairs(SP:GetOrderedModules()) do
        if m.name ~= "GameMenu" then list[#list + 1] = m end
    end
    local w = self.modulesPage:GetWidth()
    if not w or w < 1 then w = (SP.db.panel.width or 280) - 8 end

    local x, y, rowMax = 0, 4, 0
    for i, m in ipairs(list) do
        local b = self.modRows[i]
        if not b then
            b = CreateFrame("Button", nil, self.modulesPage)
            b:SetHeight(MBTN_H)
            b.lit = b:CreateTexture(nil, "BACKGROUND"); b.lit:SetAllPoints(b)
            b.glow = b:CreateTexture(nil, "ARTWORK"); b.glow:SetAllPoints(b)
            b.glow:SetColorTexture(1, 1, 1, 0.18); b.glow:Hide()  -- "illumination" active
            b.fs = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); b.fs:SetPoint("CENTER")
            b.hl = b:CreateTexture(nil, "HIGHLIGHT"); b.hl:SetAllPoints(b); b.hl:SetColorTexture(1, 1, 1, 0.12)
            self.modRows[i] = b
        end
        b.fs:SetText(m.label)
        local bw = (b.fs:GetStringWidth() or 40) + MBTN_PAD * 2
        if x + bw > w and x > 0 then x = 0; y = y + MBTN_H + MBTN_GAP end
        b:SetWidth(bw)
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", self.modulesPage, "TOPLEFT", x, -y)
        local cfg = SP:GetModuleConfig(m.name)
        local on = cfg and cfg.enabled
        local c = on and MOD_GREEN or MOD_RED
        b.lit:SetColorTexture(c[1], c[2], c[3], on and 0.85 or 0.5)
        b.glow:SetShown(on and true or false)   -- illuminé si actif
        b.fs:SetTextColor(1, 1, 1)
        b:SetScript("OnClick", function()
            local mc = SP:GetModuleConfig(m.name)
            if mc and mc.enabled then SP:DisableModuleUI(m) else SP:EnableModule(m.name) end
            self:RefreshModulesTab()
        end)
        b:Show()
        x = x + bw + MBTN_GAP
        if y + MBTN_H > rowMax then rowMax = y + MBTN_H end
    end
    for i = #list + 1, #self.modRows do self.modRows[i]:Hide() end
    self._modulesTabH = rowMax + 4
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
    -- fusion : l'info va dans le bandeau SpherePanel, pas dans un bandeau de module
    if SP.panel and SP.panel.titleInfo then
        SP.panel.titleInfo:SetText(table.concat(parts, "  "))
    end
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
    elseif cfg.activeTab == "modules" then
        needed = self._modulesTabH or 40
    elseif self._microEmbedded then
        needed = self:LayoutMicroMenu()
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
    for i, h in ipairs(self.order) do
        local col, rowN = (i - 1) % perRow, math.floor((i - 1) / perRow)
        h:ClearAllPoints()
        h:SetSize(ICON, ICON)
        h:SetPoint("TOPLEFT", self.addonsPage, "TOPLEFT", leftPad + col * (ICON + IGAP), -(IGAP + rowN * (ICON + IGAP)))
        h:Show()
        if h.manage then h.manage:SetShown(self._manage and h.button ~= nil) end
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

-- Trouve la texture d'icône d'un bouton minimap (LibDBIcon ou heuristique).
local function GrabIcon(button)
    local cand = button.icon or button.Icon
    if cand and cand.GetTexture then return cand end
    for _, r in ipairs({ button:GetRegions() }) do
        if r.GetObjectType and r:GetObjectType() == "Texture" then
            local tx = r:GetTexture()
            local at = r.GetAtlas and r:GetAtlas()
            local s = tostring(tx or at or ""):lower()
            if (tx or at) and not (s:find("border") or s:find("background")
                or s:find("tracking") or s:find("ring") or s:find("highlight")) then
                return r
            end
        end
    end
end

-- Case carrée uniforme (contour clair + fond sombre + icône + highlight).
function M:AcquireHolder(i)
    local h = self.holders[i]
    if not h then
        if InCombatLockdown() then return nil end
        h = CreateFrame("Frame", nil, self.addonsPage)
        h:Hide()
        h.outline = h:CreateTexture(nil, "BACKGROUND")
        h.outline:SetAllPoints(h); h.outline:SetColorTexture(0.35, 0.35, 0.42, 1)
        h.bg = h:CreateTexture(nil, "BORDER")
        h.bg:SetPoint("TOPLEFT", h, "TOPLEFT", 1, -1); h.bg:SetPoint("BOTTOMRIGHT", h, "BOTTOMRIGHT", -1, 1)
        h.bg:SetColorTexture(0.09, 0.09, 0.11, 1)
        h.icon = h:CreateTexture(nil, "ARTWORK")
        h.icon:SetPoint("TOPLEFT", h, "TOPLEFT", 2, -2); h.icon:SetPoint("BOTTOMRIGHT", h, "BOTTOMRIGHT", -2, 2)
        h.hl = h:CreateTexture(nil, "OVERLAY")
        h.hl:SetAllPoints(h); h.hl:SetColorTexture(0.30, 0.55, 0.95, 0.35); h.hl:Hide()
        -- overlay "Gérer" : strata maximale (passe au-dessus des boutons volés, même DIALOG),
        -- visible uniquement en mode gestion ; clic = exclusion définitive.
        local ov = CreateFrame("Button", nil, h)
        ov:SetAllPoints(h)
        ov:SetFrameStrata("FULLSCREEN_DIALOG")
        ov.bg = ov:CreateTexture(nil, "BACKGROUND"); ov.bg:SetAllPoints(ov); ov.bg:SetColorTexture(0.75, 0.15, 0.15, 0.45)
        ov.fs = ov:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge"); ov.fs:SetPoint("CENTER"); ov.fs:SetText("x")
        ov:Hide()
        ov:SetScript("OnClick", function() if h.button then M:ExcludeButton(h.button); M:SetManage(true) end end)
        ov:SetScript("OnEnter", function(s)
            GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
            GameTooltip:SetText("Exclure : " .. tostring(h.button and h.button:GetName() or "?"))
            GameTooltip:Show()
        end)
        ov:SetScript("OnLeave", function() GameTooltip:Hide() end)
        h.manage = ov
        self.holders[i] = h
    end
    return h
end

-- Mode gestion : overlays rouges cliquables sur chaque icône (exclusion en 1 clic).
function M:SetManage(on)
    self._manage = on and true or false
    for _, h in ipairs(self.holders) do
        if h.manage then h.manage:SetShown(self._manage and h:IsShown() and h.button ~= nil) end
    end
    if self.manageBtn then
        self.manageBtn.fs:SetTextColor(self._manage and 1 or 0.7, self._manage and 0.3 or 0.7, 0.3)
    end
end

-- Exclut définitivement un bouton capturé : blacklist (nom sans suffixe numérique) + restitution.
function M:ExcludeButton(button)
    local cfg = SP:GetModuleConfig(self.name)
    cfg.addonBlacklist = cfg.addonBlacklist or {}
    local n = button:GetName()
    if n and n ~= "" then
        local pat = n:gsub("%d+$", "")           -- "TodoSphere12" → "TodoSphere" (exclut toute la famille)
        table.insert(cfg.addonBlacklist, pat)
        SP:Print("Icône exclue : " .. pat .. "* (modifiable dans SPDB.modules.GameMenu.addonBlacklist)")
    end
    -- restitue ce bouton et tous ses frères blacklistés
    local toRestore = {}
    for b in pairs(self.stolen) do
        local bn = b:GetName()
        if b == button or (n and bn and bn:gsub("%d+$", "") == n:gsub("%d+$", "")) then
            toRestore[#toRestore + 1] = b
        end
    end
    for _, b in ipairs(toRestore) do self:RestoreOne(b) end
    self:Layout()
end

function M:RestoreOne(button)
    local o = self.stolen[button]
    if not o then return end
    pcall(function()
        if o.hidden then for _, r in ipairs(o.hidden) do r:Show() end end
        if o.holder then o.holder.button = nil; o.holder:Hide() end
        button._spH = nil
        button:SetParent(o.parent or Minimap)
        button:SetScale(o.scale or 1)
        button:SetMovable(o.movable and true or false)
        button:SetScript("OnUpdate", o.onUpdate)
        button:SetScript("OnDragStart", o.onDragStart)
        button:SetScript("OnDragStop", o.onDragStop)
        button:ClearAllPoints()
        if o.points and #o.points > 0 then for _, p in ipairs(o.points) do button:SetPoint(unpack(p)) end
        else button:SetPoint("CENTER", Minimap, "CENTER", 0, 0) end
        button:Hide()   -- exclu = ni dans le module, ni sur la carte
    end)
    self.stolen[button] = nil
    for i, h in ipairs(self.order) do
        if h.button == button or h.button == nil then
            if h.button == button then table.remove(self.order, i) break end
        end
    end
end

-- Capture un bouton d'addon dans une case carrée uniforme (icône copiée, textures natives masquées).
function M:StealOne(button)
    if not button or self.stolen[button] then return end
    local idx = #self.order + 1
    local h = self:AcquireHolder(idx)
    if not h then return end

    -- copie l'icône dans la case
    local src = GrabIcon(button)
    if src then
        local at = src.GetAtlas and src:GetAtlas()
        if at and at ~= "" then
            pcall(h.icon.SetAtlas, h.icon, at, false)
        else
            local tx = src:GetTexture()
            if tx then h.icon:SetTexture(tx); h.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
        end
    end

    -- sauvegarde + masque toutes les textures natives du bouton
    local pts = {}
    for i = 1, button:GetNumPoints() do pts[i] = { button:GetPoint(i) } end
    local hidden = {}
    for _, r in ipairs({ button:GetRegions() }) do
        if r.GetObjectType and r:GetObjectType() == "Texture" and r:IsShown() then
            hidden[#hidden + 1] = r; r:Hide()
        end
    end
    self.stolen[button] = {
        parent = button:GetParent(), points = pts, scale = button:GetScale(),
        onUpdate = button:GetScript("OnUpdate"),
        onDragStart = button:GetScript("OnDragStart"),
        onDragStop = button:GetScript("OnDragStop"),
        movable = button:IsMovable(), hidden = hidden, holder = h,
    }
    pcall(function() button:SetScript("OnUpdate", nil) end)
    pcall(function() button:SetScript("OnDragStart", nil) end)
    pcall(function() button:SetScript("OnDragStop", nil) end)
    pcall(function() button:SetMovable(false) end)

    -- le bouton devient une couche de clic transparente par-dessus la case
    button:SetParent(h)
    button:ClearAllPoints(); button:SetAllPoints(h)
    button:SetScale(1)
    if not button._spHooked then
        button._spHooked = true
        button:HookScript("OnEnter", function()
            if button._spH then button._spH.hl:Show(); if button._spH.ex then button._spH.ex:Show() end end
        end)
        button:HookScript("OnLeave", function()
            if button._spH then
                button._spH.hl:Hide()
                C_Timer.After(0.4, function()
                    if button._spH and button._spH.ex and not button._spH.ex:IsMouseOver() then button._spH.ex:Hide() end
                end)
            end
        end)
    end
    button._spH = h
    h.button = button
    self.order[idx] = h
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
    -- 3) boutons d'addons cliquables enfants directs de la minimap (non LibDBIcon)
    for _, c in ipairs(children) do
        local n = c:GetName()
        local w = c:GetWidth() or 0
        if not self.stolen[c] and c:GetObjectType() == "Button" and w > 8 and w < 56
            and not (n and (n:match("^Minimap") or n:match("^MiniMap") or n:match("^SpherePanel")))
            and not Blacklisted(n, bl) and HasClick(c) then
            self:StealOne(c)
        end
    end
    -- 4) boutons parentés AILLEURS (UIParent…) mais ANCRÉS sur la minimap (Narcissus, etc.)
    local function anchoredToMinimap(f)
        local okN, np = pcall(f.GetNumPoints, f)
        if not okN or not np then return false end
        for i = 1, np do
            local ok, _, rel = pcall(f.GetPoint, f, i)
            if ok and rel and (rel == Minimap or rel == _G.MinimapCluster or rel == _G.MinimapBackdrop) then
                return true
            end
        end
        return false
    end
    for _, c in ipairs({ UIParent:GetChildren() }) do
        if not self.stolen[c] and c.GetObjectType and c:GetObjectType() == "Button" then
            local w = c:GetWidth() or 0
            local n = c:GetName()
            if w > 8 and w < 56 and not Blacklisted(n, bl)
                and not (n and n:match("^SpherePanel")) and anchoredToMinimap(c) then
                self:StealOne(c)
            end
        end
    end
    table.sort(self.order, function(a, b) return (a.button:GetName() or "") < (b.button:GetName() or "") end)
end

function M:RestoreAddons()
    for button, o in pairs(self.stolen) do
        pcall(function()
            if o.hidden then for _, r in ipairs(o.hidden) do r:Show() end end
            if o.holder then o.holder.button = nil; o.holder:Hide() end
            button._spH = nil
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
