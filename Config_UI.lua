-- ============================================================
-- Config_UI.lua — Panneau d'options global (réorganisé, design-system)
-- ============================================================
-- Nav : Général · Modules · Apparence · Comportement · (une section par module)
-- Tokens de couleur cohérents, états actif(vert)/inactif(rouge), une page par module
-- (Activé + conditions d'affichage + options spécifiques).
local ADDON_NAME, SP = ...

-- Tokens
local COL = {
    accent   = { 0.29, 0.64, 1.0 },
    active   = { 0.20, 0.80, 0.30 },
    inactive = { 0.85, 0.25, 0.25 },
    dim      = { 0.70, 0.70, 0.70 },
}

local CONDITIONS = {
    { "capital", "Capitale" }, { "dungeon", "Donjon" }, { "raid", "Raid" },
    { "group", "En groupe" }, { "combat", "En combat" }, { "nocombat", "Hors combat" },
}

-- ===== Helpers de contrôles =================================================
local function MakeCheck(parent, label, x, y, getf, setf)
    local c = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    c:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    c.text = c:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    c.text:SetPoint("LEFT", c, "RIGHT", 2, 0); c.text:SetText(label)
    c:SetChecked(getf() and true or false)
    c:SetScript("OnClick", function(s) setf(s:GetChecked() and true or false) end)
    return c
end

local sliderCount = 0
local function MakeSlider(parent, label, x, y, minV, maxV, step, getf, setf, fmt)
    sliderCount = sliderCount + 1
    local s = CreateFrame("Slider", "SpherePanelCfgSlider" .. sliderCount, parent, "OptionsSliderTemplate")
    s:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y); s:SetWidth(220)
    s:SetMinMaxValues(minV, maxV); s:SetValueStep(step)
    if s.SetObeyStepOnDrag then s:SetObeyStepOnDrag(true) end
    local nm = s:GetName()
    if _G[nm .. "Low"] then _G[nm .. "Low"]:SetText(tostring(minV)) end
    if _G[nm .. "High"] then _G[nm .. "High"]:SetText(tostring(maxV)) end
    local txt = _G[nm .. "Text"]
    local function refresh(v) if txt then txt:SetText(label .. " : " .. (fmt and fmt(v) or v)) end end
    s:SetValue(getf()); refresh(getf())
    s:SetScript("OnValueChanged", function(_, v)
        if step >= 1 then v = math.floor(v + 0.5) end
        setf(v); refresh(v)
    end)
    return s
end

-- swatch couleur (avec alpha optionnel)
local function MakeColorSwatch(parent, x, y, color, hasAlpha, onChange)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(18, 18); b:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    b.tex = b:CreateTexture(nil, "ARTWORK"); b.tex:SetAllPoints(b)
    local function paint() b.tex:SetColorTexture(color.r, color.g, color.b, 1) end
    paint()
    b:SetScript("OnClick", function()
        if not (ColorPickerFrame and ColorPickerFrame.SetupColorPickerAndShow) then return end
        ColorPickerFrame:SetupColorPickerAndShow({
            r = color.r, g = color.g, b = color.b, opacity = color.a, hasOpacity = hasAlpha and true or false,
            swatchFunc = function()
                color.r, color.g, color.b = ColorPickerFrame:GetColorRGB()
                if hasAlpha then color.a = ColorPickerFrame.GetColorAlpha and ColorPickerFrame:GetColorAlpha() or (OpacitySliderFrame and OpacitySliderFrame:GetValue()) or color.a end
                paint(); if onChange then onChange() end
            end,
            opacityFunc = function()
                if ColorPickerFrame.GetColorAlpha then color.a = ColorPickerFrame:GetColorAlpha() end
                if onChange then onChange() end
            end,
            cancelFunc = function() end,
        })
    end)
    return b
end

-- ===== Conditions d'affichage (commun à chaque page module) =================
local function BuildConditions(page, m, y0)
    local cfg = SP:GetModuleConfig(m.name)
    cfg.conditions = cfg.conditions or { enabled = false }
    local c = cfg.conditions
    local hdr = page:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    hdr:SetPoint("TOPLEFT", page, "TOPLEFT", 8, y0); hdr:SetText("Conditions d'affichage")
    MakeCheck(page, "N'afficher que si l'une des conditions est remplie", 16, y0 - 22,
        function() return c.enabled end,
        function(v) c.enabled = v; SP:RebuildLayout() end)
    for i, d in ipairs(CONDITIONS) do
        local col, rowN = (i - 1) % 2, math.floor((i - 1) / 2)
        local cb = CreateFrame("CheckButton", nil, page, "UICheckButtonTemplate")
        cb:SetSize(20, 20)
        cb:SetPoint("TOPLEFT", page, "TOPLEFT", 24 + col * 180, y0 - 48 - rowN * 22)
        cb.text = cb:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        cb.text:SetPoint("LEFT", cb, "RIGHT", 2, 0); cb.text:SetText(d[2])
        cb:SetChecked(c[d[1]] and true or false)
        cb:SetScript("OnClick", function(s) c[d[1]] = s:GetChecked() and true or false; SP:RebuildLayout() end)
    end
    return y0 - 48 - 3 * 22 - 8   -- y après le bloc conditions
end

-- ===== Options spécifiques par module =======================================
local function MenusOptions(page, y)
    local cfg = SP:GetModuleConfig("GameMenu")
    MakeCheck(page, "Afficher l'horloge", 16, y, function() return cfg.showClock end, function(v) cfg.showClock = v end)
    MakeCheck(page, "Format 24h (sinon 12h AM/PM)", 32, y - 24, function() return cfg.clock24h end, function(v) cfg.clock24h = v end)
    MakeCheck(page, "Afficher les FPS", 16, y - 48, function() return cfg.showFPS end, function(v) cfg.showFPS = v end)
end

local function QuestOptions(page, y)
    local cfg = SP:GetModuleConfig("QuestTracker")
    MakeSlider(page, "Hauteur du module", 16, y - 4, 100, 600, 10,
        function() return cfg.height or 300 end,
        function(v) cfg.height = v; SP:RebuildLayout() end, function(v) return v .. " px" end)
end

local function SquareMapOptions(page, y)
    local cfg = SP:GetModuleConfig("SquareMap")
    MakeCheck(page, "Garder la minimap masquée quand le module est désactivé", 16, y,
        function() return cfg.hideWhenDisabled end, function(v) cfg.hideWhenDisabled = v end)
end

local function ChatOptions(page, y)
    local cfg = SP:GetModuleConfig("Chat")
    local function applyChat() local mm = SP.modulesByName and SP.modulesByName["Chat"]; if mm and mm.ApplyConfig then mm:ApplyConfig() end end
    MakeCheck(page, "Colorer les noms par classe", 16, y,
        function() return cfg.classColorNames end, function(v) cfg.classColorNames = v; applyChat() end)
    MakeSlider(page, "Taille de police", 24, y - 30, 8, 24, 1,
        function() return cfg.fontSize or 12 end, function(v) cfg.fontSize = v; applyChat() end, function(v) return tostring(v) end)
    local lh = page:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    lh:SetPoint("TOPLEFT", page, "TOPLEFT", 8, y - 72); lh:SetText("Canaux — activer / couleur / nom / ordre")
    page.chRows = {}
    page.RefreshChannels = function()
        local yy = y - 92
        for i, ch in ipairs(cfg.channels) do
            local row = page.chRows[i]
            if not row then
                row = CreateFrame("Frame", nil, page); row:SetSize(380, 22)
                row.check = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
                row.check:SetSize(20, 20); row.check:SetPoint("LEFT", row, "LEFT", 0, 0)
                row.swatch = CreateFrame("Button", nil, row); row.swatch:SetSize(16, 16); row.swatch:SetPoint("LEFT", row.check, "RIGHT", 4, 0)
                row.swatch.tex = row.swatch:CreateTexture(nil, "ARTWORK"); row.swatch.tex:SetAllPoints(row.swatch)
                row.nameBox = CreateFrame("EditBox", nil, row, "InputBoxTemplate")
                row.nameBox:SetSize(90, 18); row.nameBox:SetAutoFocus(false); row.nameBox:SetPoint("LEFT", row.swatch, "RIGHT", 10, 0)
                row.key = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall"); row.key:SetPoint("LEFT", row.nameBox, "RIGHT", 6, 0)
                row.up = CreateFrame("Button", nil, row); row.up:SetSize(18, 18); row.up:SetPoint("LEFT", row, "LEFT", 200, 0); row.up:SetNormalTexture("Interface\\Buttons\\UI-ScrollBar-ScrollUpButton-Up")
                row.down = CreateFrame("Button", nil, row); row.down:SetSize(18, 18); row.down:SetPoint("LEFT", row.up, "RIGHT", 2, 0); row.down:SetNormalTexture("Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-Up")
                page.chRows[i] = row
            end
            row:ClearAllPoints(); row:SetPoint("TOPLEFT", page, "TOPLEFT", 8, yy)
            row.key:SetText("(" .. ch.key .. ")")
            row.nameBox:SetText(ch.label or ch.key)
            row.nameBox:SetScript("OnEnterPressed", function(s) ch.label = s:GetText(); s:ClearFocus(); applyChat() end)
            row.nameBox:SetScript("OnTextChanged", function(s, u) if u then ch.label = s:GetText(); applyChat() end end)
            row.check:SetChecked(ch.enabled and true or false)
            row.check:SetScript("OnClick", function(s) ch.enabled = s:GetChecked() and true or false; applyChat() end)
            row.swatch.tex:SetColorTexture(ch.r, ch.g, ch.b)
            row.swatch:SetScript("OnClick", function()
                if ColorPickerFrame and ColorPickerFrame.SetupColorPickerAndShow then
                    ColorPickerFrame:SetupColorPickerAndShow({ r = ch.r, g = ch.g, b = ch.b, hasOpacity = false,
                        swatchFunc = function() local r, g, b = ColorPickerFrame:GetColorRGB(); ch.r, ch.g, ch.b = r, g, b; row.swatch.tex:SetColorTexture(r, g, b); applyChat() end,
                        cancelFunc = function() end })
                end
            end)
            row.up:SetScript("OnClick", function() if i > 1 then cfg.channels[i], cfg.channels[i - 1] = cfg.channels[i - 1], cfg.channels[i]; page.RefreshChannels(); applyChat() end end)
            row.down:SetScript("OnClick", function() if i < #cfg.channels then cfg.channels[i], cfg.channels[i + 1] = cfg.channels[i + 1], cfg.channels[i]; page.RefreshChannels(); applyChat() end end)
            row:Show()
            yy = yy - 24
        end
        for j = #cfg.channels + 1, #page.chRows do page.chRows[j]:Hide() end
    end
    local imp = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
    imp:SetSize(200, 22); imp:SetPoint("BOTTOMLEFT", page, "BOTTOMLEFT", 8, 8); imp:SetText("Importer les canaux rejoints")
    imp:SetScript("OnClick", function()
        local list = { GetChannelList() }
        for i = 1, #list, 3 do
            local nm = list[i + 1]
            if type(nm) == "string" and nm ~= "" then
                local key = "C:" .. nm; local exists = false
                for _, ch in ipairs(cfg.channels) do if ch.key == key then exists = true; break end end
                if not exists then cfg.channels[#cfg.channels + 1] = { key = key, label = nm, channelName = nm, enabled = true, r = 0.9, g = 0.8, b = 0.5 } end
            end
        end
        page.RefreshChannels(); applyChat()
    end)
    page:SetScript("OnShow", function() page.RefreshChannels() end)
    page.RefreshChannels()
end

local function BagsOptions(page, y)
    local cfg = SP:GetModuleConfig("Bags")
    local function apply() local m = SP.modulesByName and SP.modulesByName["Bags"]; if m and m.RequestRefresh then m:RequestRefresh() end end
    MakeSlider(page, "Taille des icônes", 16, y - 4, 20, 48, 1,
        function() return _G.BAGANATOR_CONFIG and _G.BAGANATOR_CONFIG.bag_icon_size or 30 end,
        function(v) _G.BAGANATOR_CONFIG = _G.BAGANATOR_CONFIG or {}; _G.BAGANATOR_CONFIG.bag_icon_size = v; apply() end,
        function(v) return v .. " px" end)
    MakeCheck(page, "Afficher l'iLvl", 16, y - 34,
        function() return cfg.showIlvl end, function(v) cfg.showIlvl = v; apply() end)
    MakeCheck(page, "Flèche d'upgrade (Pawn)", 160, y - 34,
        function() return cfg.showUpgrade end, function(v) cfg.showUpgrade = v; apply() end)
    local lh = page:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    lh:SetPoint("TOPLEFT", page, "TOPLEFT", 8, y - 62); lh:SetText("Catégories — glisser ≡ pour l'ordre · couleur · nom · filtre")
    page.bagRows = {}
    page.RefreshBags = function()
        local yy = y - 84
        for i, c in ipairs(cfg.categories) do
            local row = page.bagRows[i]
            if not row then
                row = CreateFrame("Frame", nil, page); row:SetSize(450, 22)
                row.grip = CreateFrame("Button", nil, row); row.grip:SetSize(16, 18); row.grip:SetPoint("LEFT", row, "LEFT", 0, 0)
                row.grip:RegisterForDrag("LeftButton")
                row.grip.fs = row.grip:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge"); row.grip.fs:SetAllPoints(row.grip); row.grip.fs:SetText("|cFF888888≡|r")
                row.check = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate"); row.check:SetSize(20, 20); row.check:SetPoint("LEFT", row.grip, "RIGHT", 2, 0)
                row.color = CreateFrame("Button", nil, row); row.color:SetSize(16, 16); row.color:SetPoint("LEFT", row.check, "RIGHT", 2, 0)
                row.color.tex = row.color:CreateTexture(nil, "ARTWORK"); row.color.tex:SetAllPoints(row.color)
                row.name = CreateFrame("EditBox", nil, row, "InputBoxTemplate"); row.name:SetSize(80, 18); row.name:SetAutoFocus(false); row.name:SetPoint("LEFT", row.color, "RIGHT", 8, 0)
                row.search = CreateFrame("EditBox", nil, row, "InputBoxTemplate"); row.search:SetSize(100, 18); row.search:SetAutoFocus(false); row.search:SetPoint("LEFT", row.name, "RIGHT", 10, 0)
                page.bagRows[i] = row
            end
            row.catRef = c
            row:ClearAllPoints(); row:SetPoint("TOPLEFT", page, "TOPLEFT", 8, yy)
            row.check:SetChecked(c.enabled and true or false)
            row.check:SetScript("OnClick", function(s) c.enabled = s:GetChecked() and true or false; apply() end)
            c.color = c.color or { 1, 0.82, 0 }
            row.color.tex:SetColorTexture(c.color[1], c.color[2], c.color[3])
            row.color:SetScript("OnClick", function()
                if ColorPickerFrame and ColorPickerFrame.SetupColorPickerAndShow then
                    ColorPickerFrame:SetupColorPickerAndShow({ r = c.color[1], g = c.color[2], b = c.color[3], hasOpacity = false,
                        swatchFunc = function() local r, g, b = ColorPickerFrame:GetColorRGB(); c.color = { r, g, b }; row.color.tex:SetColorTexture(r, g, b); apply() end,
                        cancelFunc = function() end })
                end
            end)
            row.name:SetText(c.label or c.key)
            row.name:SetScript("OnTextChanged", function(s, u) if u then c.label = s:GetText(); apply() end end)
            row.search:SetText(c.search or "")
            row.search:SetScript("OnTextChanged", function(s, u) if u then c.search = s:GetText(); apply() end end)
            row.grip:SetScript("OnDragStart", function() page._dragCat = c end)
            row.grip:SetScript("OnDragStop", function()
                local src = page._dragCat; page._dragCat = nil
                if not src then return end
                local target
                for _, r in ipairs(page.bagRows) do
                    if r:IsShown() and r:IsMouseOver() and r.catRef then target = r.catRef; break end
                end
                if target and target ~= src then
                    local cats, si, ti = cfg.categories
                    for idx, cc in ipairs(cats) do if cc == src then si = idx end; if cc == target then ti = idx end end
                    if si and ti then
                        table.remove(cats, si)
                        table.insert(cats, (si < ti) and (ti - 1) or ti, src)
                        page.RefreshBags(); apply()
                    end
                end
            end)
            row:Show(); yy = yy - 24
        end
        for j = #cfg.categories + 1, #page.bagRows do page.bagRows[j]:Hide() end
    end
    local add = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
    add:SetSize(170, 22); add:SetPoint("BOTTOMLEFT", page, "BOTTOMLEFT", 8, 8); add:SetText("Ajouter un filtre (par nom)")
    add:SetScript("OnClick", function()
        local n = 0; for _, c in ipairs(cfg.categories) do if type(c.key) == "string" and c.key:match("^C%d+$") then n = n + 1 end end
        table.insert(cfg.categories, 1, { key = "C" .. (n + 1), label = "Filtre " .. (n + 1), enabled = true, collapsed = false, search = "", color = { 0.5, 0.85, 1 } })
        page.RefreshBags(); apply()
    end)
    page:SetScript("OnShow", function() page.RefreshBags() end)
    page.RefreshBags()
end

local SPECIFIC = {
    GameMenu = MenusOptions, QuestTracker = QuestOptions, SquareMap = SquareMapOptions, Chat = ChatOptions, Bags = BagsOptions,
}

-- ===== Page d'un module =====================================================
local function BuildModulePage(page, m)
    local cfg = SP:GetModuleConfig(m.name)
    local hdr = page:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    hdr:SetPoint("TOPLEFT", page, "TOPLEFT", 4, -4); hdr:SetText(m.label .. "  |cFF888888(" .. m.name .. ")|r")
    MakeCheck(page, "Activé", 8, -32,
        function() return cfg and cfg.enabled end,
        function(v) if v then SP:EnableModule(m.name) else SP:DisableModuleUI(m) end end)
    local afterCond = BuildConditions(page, m, -64)
    if SPECIFIC[m.name] then SPECIFIC[m.name](page, afterCond) end
end

-- ===== Modules (vue d'ensemble, boîtes vert/rouge) ==========================
function SP:_RefreshModulesPage(page)
    local mods = SP:GetOrderedModules()
    local y = -36
    for i, m in ipairs(mods) do
        local row = page.rows[i]
        if not row then
            row = CreateFrame("Frame", nil, page); row:SetSize(380, 24)
            row.box = row:CreateTexture(nil, "ARTWORK"); row.box:SetSize(14, 14); row.box:SetPoint("LEFT", row, "LEFT", 0, 0)
            row.check = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
            row.check:SetSize(22, 22); row.check:SetPoint("LEFT", row.box, "RIGHT", 6, 0)
            row.label = row:CreateFontString(nil, "OVERLAY", "GameFontNormal"); row.label:SetPoint("LEFT", row.check, "RIGHT", 4, 0)
            page.rows[i] = row
        end
        row:ClearAllPoints(); row:SetPoint("TOPLEFT", page, "TOPLEFT", 8, y)
        row.label:SetText(("%s  |cFF888888(%s)|r"):format(m.label, m.name))
        local cfg = SP:GetModuleConfig(m.name)
        local on = cfg and cfg.enabled
        local bc = on and COL.active or COL.inactive
        row.box:SetColorTexture(bc[1], bc[2], bc[3], 1)
        row.check:SetChecked(on)
        row.check:SetScript("OnClick", function(c)
            if c:GetChecked() then SP:EnableModule(m.name) else SP:DisableModuleUI(m) end
            local nb = c:GetChecked() and COL.active or COL.inactive
            row.box:SetColorTexture(nb[1], nb[2], nb[3], 1)
        end)
        row:Show()
        y = y - 26
    end
    for i = #mods + 1, #page.rows do page.rows[i]:Hide() end
end

-- ===== Apparence ============================================================
local function BuildApparence(page)
    local hdr = page:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    hdr:SetPoint("TOPLEFT", page, "TOPLEFT", 4, -4); hdr:SetText("Apparence")
    local bgc = SP.db.panel.bgColor
    local lbl = page:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    lbl:SetPoint("TOPLEFT", page, "TOPLEFT", 8, -40); lbl:SetText("Couleur du fond :")
    MakeColorSwatch(page, 130, -38, bgc, true, function() if SP.ApplyAppearance then SP:ApplyAppearance() end end)
    MakeSlider(page, "Transparence du fond", 16, -76, 0, 1, 0.05,
        function() return bgc.a end,
        function(v) bgc.a = v; if SP.ApplyAppearance then SP:ApplyAppearance() end end,
        function(v) return string.format("%d%%", math.floor(v * 100)) end)
    local note = page:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    note:SetPoint("TOPLEFT", page, "TOPLEFT", 8, -130)
    note:SetText("|cFF777777La couleur et la transparence s'appliquent immédiatement.|r")
end

-- ===== Comportement =========================================================
local function BuildComportement(page)
    local pcfg = SP.db.panel
    local af = pcfg.autofade
    local function applyBeh() if SP.ApplyPanelBehavior then SP:ApplyPanelBehavior() end end

    local hdr = page:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    hdr:SetPoint("TOPLEFT", page, "TOPLEFT", 4, -4); hdr:SetText("Comportement du panneau")

    local modeL = page:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    modeL:SetPoint("TOPLEFT", page, "TOPLEFT", 8, -32); modeL:SetText("Mode :")
    local BEH = {
        { 1, "1 — Panneau glissant magnétisé (revient au bord)" },
        { 2, "2 — Modules individuels + glow coloré au bord" },
        { 3, "3 — Libre, toujours visible" },
    }
    page.behChecks = {}
    for i, d in ipairs(BEH) do
        local c = CreateFrame("CheckButton", nil, page, "UICheckButtonTemplate")
        c:SetPoint("TOPLEFT", page, "TOPLEFT", 16, -50 - (i - 1) * 22)
        c.text = c:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); c.text:SetPoint("LEFT", c, "RIGHT", 2, 0); c.text:SetText(d[2])
        c.val = d[1]; c:SetChecked(pcfg.behavior == d[1])
        c:SetScript("OnClick", function(s)
            pcfg.behavior = s.val
            for _, o in ipairs(page.behChecks) do o:SetChecked(o.val == s.val) end
            applyBeh()
        end)
        page.behChecks[i] = c
    end

    local sideL = page:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    sideL:SetPoint("TOPLEFT", page, "TOPLEFT", 8, -124); sideL:SetText("Côté d'aimantation :")
    local cR = CreateFrame("CheckButton", nil, page, "UICheckButtonTemplate"); cR:SetPoint("TOPLEFT", page, "TOPLEFT", 16, -144)
    cR.text = cR:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); cR.text:SetPoint("LEFT", cR, "RIGHT", 2, 0); cR.text:SetText("Droite")
    local cL = CreateFrame("CheckButton", nil, page, "UICheckButtonTemplate"); cL:SetPoint("TOPLEFT", page, "TOPLEFT", 130, -144)
    cL.text = cL:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); cL.text:SetPoint("LEFT", cL, "RIGHT", 2, 0); cL.text:SetText("Gauche")
    cR:SetChecked(pcfg.side ~= "left"); cL:SetChecked(pcfg.side == "left")
    cR:SetScript("OnClick", function() pcfg.side = "right"; cL:SetChecked(false); cR:SetChecked(true); applyBeh() end)
    cL:SetScript("OnClick", function() pcfg.side = "left"; cR:SetChecked(false); cL:SetChecked(true); applyBeh() end)

    local fh = page:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fh:SetPoint("TOPLEFT", page, "TOPLEFT", 8, -176); fh:SetText("Estompage (mode libre)")
    MakeCheck(page, "Estomper après inactivité", 16, -196, function() return af.enabled end, function(v) af.enabled = v end)
    MakeSlider(page, "Délai", 24, -226, 1, 30, 1, function() return af.delay end, function(v) af.delay = v end, function(v) return v .. " s" end)
    MakeSlider(page, "Opacité (0% = transparent)", 24, -270, 0, 1, 0.05,
        function() return af.alpha end, function(v) af.alpha = v end, function(v) return string.format("%d%%", math.floor(v * 100)) end)
    MakeSlider(page, "Transition", 24, -314, 0.1, 1, 0.05,
        function() return af.fadeDuration end, function(v) af.fadeDuration = v end, function(v) return string.format("%.2f s", v) end)

    local clHdr = page:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    clHdr:SetPoint("TOPLEFT", page, "TOPLEFT", 8, -352); clHdr:SetText("Appliquer estompage/réduction à :")
    page.fadeRows = {}
    page.RefreshFade = function()
        af.apply = af.apply or {}
        for i, m in ipairs(SP:GetOrderedModules()) do
            local c = page.fadeRows[i]
            if not c then
                c = CreateFrame("CheckButton", nil, page, "UICheckButtonTemplate"); c:SetSize(20, 20)
                c.text = c:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); c.text:SetPoint("LEFT", c, "RIGHT", 2, 0)
                page.fadeRows[i] = c
            end
            local col, rowN = (i - 1) % 2, math.floor((i - 1) / 2)
            c:ClearAllPoints(); c:SetPoint("TOPLEFT", page, "TOPLEFT", 16 + col * 180, -374 - rowN * 22)
            c.text:SetText(m.label)
            local mcfg = SP:GetModuleConfig(m.name); local en = mcfg and mcfg.enabled
            c:SetEnabled(en and true or false)
            c.text:SetTextColor(en and 1 or 0.5, en and 1 or 0.5, en and 1 or 0.5)
            c:SetChecked(af.apply[m.name] ~= false)
            c:SetScript("OnClick", function(s) af.apply[m.name] = s:GetChecked() and true or false end)
            c:Show()
        end
        for i = #SP:GetOrderedModules() + 1, #page.fadeRows do page.fadeRows[i]:Hide() end
    end
    page:SetScript("OnShow", function() page.RefreshFade() end)
end

local function BuildGeneral(page)
    local hdr = page:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    hdr:SetPoint("TOPLEFT", page, "TOPLEFT", 4, -4); hdr:SetText("Général")
    MakeSlider(page, "Largeur du panneau", 16, -44, 180, 600, 5,
        function() return SP.db.panel.width or 280 end,
        function(v) SP.db.panel.width = v; if SP.panel then SP.panel:SetWidth(v); SP:OnPanelResized() end end,
        function(v) return v .. " px" end)
    local note = page:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    note:SetPoint("TOPLEFT", page, "TOPLEFT", 8, -96)
    note:SetText("|cFF777777Astuce : clic droit sur un bandeau = menu (Paramètres / Verrouiller / Masquer).|r")
end

-- ===== Fenêtre ==============================================================
local function CreateOptions()
    if SP.optionsFrame then return SP.optionsFrame end

    local f = CreateFrame("Frame", "SpherePanelOptions", UIParent)
    f:SetSize(560, 520)
    f:SetPoint("CENTER"); f:SetFrameStrata("DIALOG"); f:EnableMouse(true); f:SetMovable(true); f:SetClampedToScreen(true); f:Hide()
    tinsert(UISpecialFrames, "SpherePanelOptions")
    local bg = f:CreateTexture(nil, "BACKGROUND"); bg:SetAllPoints(f); bg:SetColorTexture(0.06, 0.06, 0.08, 0.97)

    local tb = CreateFrame("Frame", nil, f); tb:SetPoint("TOPLEFT"); tb:SetPoint("TOPRIGHT"); tb:SetHeight(26)
    tb:EnableMouse(true); tb:RegisterForDrag("LeftButton")
    tb:SetScript("OnDragStart", function() f:StartMoving() end); tb:SetScript("OnDragStop", function() f:StopMovingOrSizing() end)
    local tbbg = tb:CreateTexture(nil, "ARTWORK"); tbbg:SetAllPoints(tb); tbbg:SetColorTexture(0.10, 0.10, 0.15, 1)
    local title = tb:CreateFontString(nil, "OVERLAY", "GameFontNormal"); title:SetPoint("LEFT", tb, "LEFT", 10, 0)
    title:SetText("|cFF4AA3FFSphere|rPanel — Options")
    local close = CreateFrame("Button", nil, tb, "UIPanelCloseButton"); close:SetPoint("RIGHT", tb, "RIGHT", 2, 0)
    close:SetScript("OnClick", function() f:Hide() end)

    local nav = CreateFrame("Frame", nil, f)
    nav:SetPoint("TOPLEFT", f, "TOPLEFT", 6, -32); nav:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 6, 6); nav:SetWidth(140)
    local navbg = nav:CreateTexture(nil, "BACKGROUND"); navbg:SetAllPoints(nav); navbg:SetColorTexture(0, 0, 0, 0.3)

    local content = CreateFrame("Frame", nil, f)
    content:SetPoint("TOPLEFT", nav, "TOPRIGHT", 8, 0); content:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -8, 8)

    f.pages = {}; f.navButtons = {}
    function f:ShowSection(name)
        if not self.pages[name] then return end
        for sec, page in pairs(self.pages) do page:SetShown(sec == name) end
        for sec, btn in pairs(self.navButtons) do
            if sec == name then btn.fs:SetTextColor(COL.accent[1], COL.accent[2], COL.accent[3]) else btn.fs:SetTextColor(COL.dim[1], COL.dim[2], COL.dim[3]) end
        end
        self.current = name
    end

    -- liste des entrées de nav : sections fixes + une par module
    local entries = { { "Général", "Général" }, { "Modules", "Modules" }, { "Apparence", "Apparence" }, { "Comportement", "Comportement" } }
    for _, m in ipairs(SP:GetOrderedModules()) do entries[#entries + 1] = { m.name, m.label, m } end

    local y = -4
    for _, e in ipairs(entries) do
        local key, label = e[1], e[2]
        local b = CreateFrame("Button", nil, nav); b:SetSize(134, 20); b:SetPoint("TOPLEFT", nav, "TOPLEFT", 3, y)
        b.fs = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); b.fs:SetPoint("LEFT", b, "LEFT", 6, 0); b.fs:SetText(label)
        local hl = b:CreateTexture(nil, "HIGHLIGHT"); hl:SetAllPoints(b); hl:SetColorTexture(1, 1, 1, 0.08)
        b:SetScript("OnClick", function() f:ShowSection(key) end)
        f.navButtons[key] = b
        local page = CreateFrame("Frame", nil, content); page:SetAllPoints(content); page:Hide()
        f.pages[key] = page
        if e[3] then BuildModulePage(page, e[3]) end
        y = y - 21
    end

    -- pages fixes
    do
        local mp = f.pages["Modules"]
        local h = mp:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge"); h:SetPoint("TOPLEFT", mp, "TOPLEFT", 4, -4); h:SetText("Modules — actif (vert) / inactif (rouge)")
        mp.rows = {}
        mp:SetScript("OnShow", function() SP:_RefreshModulesPage(mp) end)
    end
    BuildGeneral(f.pages["Général"])
    BuildApparence(f.pages["Apparence"])
    BuildComportement(f.pages["Comportement"])

    SP.optionsFrame = f
    f:ShowSection("Modules")
    return f
end

function SP:OpenConfig(moduleOrSection)
    local f = CreateOptions()
    f:Show()
    local section = "Modules"
    if moduleOrSection and f.pages[moduleOrSection] then section = moduleOrSection end
    f:ShowSection(section)
end
