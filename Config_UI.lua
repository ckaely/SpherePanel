-- ============================================================
-- Config_UI.lua — Panneau d'options global (base, phase 1)
-- ============================================================
-- Frame maison : nav gauche + pages. Section "Modules" fonctionnelle (enable/disable),
-- autres sections = conteneurs prêts pour les passes suivantes.
local ADDON_NAME, SP = ...

local SECTIONS = { "Général", "Modules", "Chat", "Addons", "Quêtes", "Apparence", "Comportement" }

-- Mappe un module vers sa section d'options (pour le menu contextuel "Paramètres").
local MODULE_SECTION = {
    Chat           = "Chat",
    MinimapButtons = "Addons",
    QuestTracker   = "Quêtes",
}

-- Rafraîchit la liste des modules (section "Modules").
function SP:_RefreshModulesPage(page)
    local mods = SP:GetOrderedModules()
    local y = -36
    for i, m in ipairs(mods) do
        local row = page.rows[i]
        if not row then
            row = CreateFrame("Frame", nil, page)
            row:SetSize(360, 24)
            row.check = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
            row.check:SetSize(22, 22)
            row.check:SetPoint("LEFT", row, "LEFT", 0, 0)
            row.label = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            row.label:SetPoint("LEFT", row.check, "RIGHT", 4, 0)
            page.rows[i] = row
        end
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", page, "TOPLEFT", 8, y)
        row.label:SetText(("%s  |cFF888888(%s)|r"):format(m.label, m.name))
        local cfg = SP:GetModuleConfig(m.name)
        row.check:SetChecked(cfg and cfg.enabled)
        row.check:SetScript("OnClick", function(c)
            if c:GetChecked() then SP:EnableModule(m.name) else SP:DisableModuleUI(m) end
        end)
        row:Show()
        y = y - 26
    end
    for i = #mods + 1, #page.rows do page.rows[i]:Hide() end
end

local function CreateOptions()
    if SP.optionsFrame then return SP.optionsFrame end

    local f = CreateFrame("Frame", "SpherePanelOptions", UIParent)
    f:SetSize(560, 420)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:EnableMouse(true)
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    f:Hide()
    tinsert(UISpecialFrames, "SpherePanelOptions")  -- fermeture avec Échap

    local bg = f:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(f); bg:SetColorTexture(0.06, 0.06, 0.08, 0.97)

    -- Barre de titre (déplaçable)
    local tb = CreateFrame("Frame", nil, f)
    tb:SetPoint("TOPLEFT"); tb:SetPoint("TOPRIGHT"); tb:SetHeight(26)
    tb:EnableMouse(true); tb:RegisterForDrag("LeftButton")
    tb:SetScript("OnDragStart", function() f:StartMoving() end)
    tb:SetScript("OnDragStop", function() f:StopMovingOrSizing() end)
    local tbbg = tb:CreateTexture(nil, "ARTWORK")
    tbbg:SetAllPoints(tb); tbbg:SetColorTexture(0.10, 0.10, 0.15, 1)
    local title = tb:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("LEFT", tb, "LEFT", 10, 0)
    title:SetText("|cFF4AA3FFSphere|rPanel — Options")
    local close = CreateFrame("Button", nil, tb, "UIPanelCloseButton")
    close:SetPoint("RIGHT", tb, "RIGHT", 2, 0)
    close:SetScript("OnClick", function() f:Hide() end)

    -- Navigation gauche
    local nav = CreateFrame("Frame", nil, f)
    nav:SetPoint("TOPLEFT", f, "TOPLEFT", 6, -32)
    nav:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 6, 6)
    nav:SetWidth(130)
    local navbg = nav:CreateTexture(nil, "BACKGROUND")
    navbg:SetAllPoints(nav); navbg:SetColorTexture(0, 0, 0, 0.3)

    -- Zone de contenu
    local content = CreateFrame("Frame", nil, f)
    content:SetPoint("TOPLEFT", nav, "TOPRIGHT", 8, 0)
    content:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -8, 8)

    f.pages = {}
    f.navButtons = {}

    function f:ShowSection(name)
        if not self.pages[name] then name = "Modules" end
        for sec, page in pairs(self.pages) do page:SetShown(sec == name) end
        for sec, b in pairs(self.navButtons) do
            if sec == name then b.fs:SetTextColor(1, 0.82, 0.30) else b.fs:SetTextColor(0.7, 0.7, 0.7) end
        end
        self.current = name
    end

    -- Boutons de nav + pages
    local y = -4
    for _, sec in ipairs(SECTIONS) do
        local b = CreateFrame("Button", nil, nav)
        b:SetSize(124, 22)
        b:SetPoint("TOPLEFT", nav, "TOPLEFT", 3, y)
        b.fs = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        b.fs:SetPoint("LEFT", b, "LEFT", 6, 0)
        b.fs:SetText(sec)
        local hl = b:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints(b); hl:SetColorTexture(1, 1, 1, 0.08)
        b:SetScript("OnClick", function() f:ShowSection(sec) end)
        f.navButtons[sec] = b

        local page = CreateFrame("Frame", nil, content)
        page:SetAllPoints(content)
        page:Hide()
        f.pages[sec] = page
        y = y - 24
    end

    -- Page "Modules" (fonctionnelle)
    do
        local page = f.pages["Modules"]
        local hdr = page:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        hdr:SetPoint("TOPLEFT", page, "TOPLEFT", 4, -4)
        hdr:SetText("Modules — activer / désactiver")
        page.rows = {}
        page:SetScript("OnShow", function() SP:_RefreshModulesPage(page) end)
    end

    -- Pages stub (options à venir dans les passes suivantes)
    for _, sec in ipairs({ "Général", "Chat", "Addons", "Quêtes", "Apparence", "Comportement" }) do
        local page = f.pages[sec]
        local fs = page:CreateFontString(nil, "OVERLAY", "GameFontDisable")
        fs:SetPoint("CENTER")
        fs:SetJustifyH("CENTER")
        fs:SetText(sec .. "\n\n|cFF777777Options à venir.|r")
    end

    SP.optionsFrame = f
    f:ShowSection("Modules")
    return f
end

-- Ouvre le panneau ; `moduleOrSection` = nom de module (→ sa section) ou nom de section.
function SP:OpenConfig(moduleOrSection)
    local f = CreateOptions()
    f:Show()
    local section = "Modules"
    if moduleOrSection then
        section = MODULE_SECTION[moduleOrSection]
            or (f.pages[moduleOrSection] and moduleOrSection)
            or "Modules"
    end
    f:ShowSection(section)
end
