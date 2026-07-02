-- ============================================================
-- ModuleSystem.lua — Moteur de modules
--   • Registre + validation d'interface
--   • Bandeaux collapsibles (header + content)
--   • Drag-to-reorder (fantôme + RebuildLayout)
-- ============================================================
local ADDON_NAME, SP = ...

-- Textures de boutons natives (bords transparents garantis).
local TEX_PLUS   = "Interface\\Buttons\\UI-PlusButton-Up"
local TEX_MINUS  = "Interface\\Buttons\\UI-MinusButton-Up"
local TEX_LOCK   = "Interface\\Buttons\\LockButton-Locked-Up"
local TEX_UNLOCK = "Interface\\Buttons\\LockButton-Unlocked-Up"
local SNP_FONT_DIR = "Interface\\AddOns\\SphereNameplates\\media\\fonts\\"

-- Interface obligatoire que tout module DOIT exposer.
local REQUIRED    = { "name", "label" }
local REQUIRED_FN = { "Init", "Enable", "Disable", "OnResize" }

local function clamp(v, lo, hi)
    v = tonumber(v) or lo
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

local function copyColor(dst, src, fallback)
    src, fallback = src or {}, fallback or {}
    dst.r = clamp(src.r ~= nil and src.r or fallback.r or 1, 0, 1)
    dst.g = clamp(src.g ~= nil and src.g or fallback.g or 1, 0, 1)
    dst.b = clamp(src.b ~= nil and src.b or fallback.b or 1, 0, 1)
    if src.a ~= nil or fallback.a ~= nil then dst.a = clamp(src.a ~= nil and src.a or fallback.a or 1, 0, 1) end
    return dst
end

function SP:GetEffectiveModuleFont(name)
    local panel = SP.db and SP.db.panel or {}
    local cfg = SP:GetModuleConfig(name) or {}
    local face = (panel.fontGlobal and panel.fontFace) or cfg.fontFace or cfg.font or panel.fontFace
    local size = (panel.fontGlobal and panel.fontSize) or cfg.fontSize or panel.fontSize or 11
    local fontFlags = (panel.fontGlobal and panel.fontFlags) or cfg.fontFlags or panel.fontFlags or ""
    if type(face) == "string" and face ~= "" and not face:find("[/\\]") then
        face = SNP_FONT_DIR .. face
    end
    return face or STANDARD_TEXT_FONT, tonumber(size) or 11, fontFlags
end

function SP:GetEffectiveModuleSecondaryFont(name)
    local panel = SP.db and SP.db.panel or {}
    local cfg = SP:GetModuleConfig(name) or {}
    local face = (panel.fontGlobal and panel.fontSecondaryFace) or cfg.fontSecondaryFace or panel.fontSecondaryFace or cfg.fontFace or panel.fontFace
    local size = (panel.fontGlobal and panel.fontSecondarySize) or cfg.fontSecondarySize or panel.fontSecondarySize or math.max(8, (tonumber(panel.fontSize) or 11) - 1)
    local fontFlags = (panel.fontGlobal and panel.fontSecondaryFlags) or cfg.fontSecondaryFlags or panel.fontSecondaryFlags or panel.fontFlags or ""
    if type(face) == "string" and face ~= "" and not face:find("[/\\]") then
        face = SNP_FONT_DIR .. face
    end
    return face or STANDARD_TEXT_FONT, tonumber(size) or 10, fontFlags
end

function SP:ApplyFontToObject(fs, moduleName, offset, flags)
    if not fs or not fs.SetFont then return end
    local face, size, effectiveFlags = SP:GetEffectiveModuleFont(moduleName)
    if effectiveFlags == nil or effectiveFlags == "" then effectiveFlags = flags or "" end
    fs:SetFont(face, math.max(6, (tonumber(size) or 11) + (offset or 0)), effectiveFlags)
end

function SP:ApplySecondaryFontToObject(fs, moduleName, offset, flags)
    if not fs or not fs.SetFont then return end
    local face, size, effectiveFlags = SP:GetEffectiveModuleSecondaryFont(moduleName)
    if effectiveFlags == nil or effectiveFlags == "" then effectiveFlags = flags or "" end
    fs:SetFont(face, math.max(6, (tonumber(size) or 10) + (offset or 0)), effectiveFlags)
end

local function ApplyFontsRecursive(frame, moduleName, depth)
    if not frame or depth > 6 then return end
    local regions = { frame:GetRegions() }
    for _, r in ipairs(regions) do
        if r and r.GetObjectType and r:GetObjectType() == "FontString" then
            if r._spFontRole == "secondary" then
                SP:ApplySecondaryFontToObject(r, moduleName, 0)
            else
                SP:ApplyFontToObject(r, moduleName, 0)
            end
        end
    end
    local children = { frame:GetChildren() }
    for _, child in ipairs(children) do ApplyFontsRecursive(child, moduleName, depth + 1) end
end

function SP:GetModuleAppearanceConfig(name)
    local cfg = SP:GetModuleConfig(name)
    if not cfg then return nil end
    local def = SP.db and SP.db.panel and SP.db.panel.moduleAppearance or {}
    cfg.appearance = cfg.appearance or {}
    cfg.appearance.bgColor = copyColor(cfg.appearance.bgColor or {}, cfg.appearance.bgColor, def.bgColor or { r = 0.12, g = 0.15, b = 0.20, a = 0.46 })
    if cfg.appearance.bgColor.a == nil then cfg.appearance.bgColor.a = (def.bgColor and def.bgColor.a) or 0.46 end
    cfg.appearance.textColor = copyColor(cfg.appearance.textColor or {}, cfg.appearance.textColor, def.textColor or { r = 0.92, g = 0.96, b = 1 })
    return cfg.appearance
end

function SP:ResetModuleAppearance(name)
    local cfg = SP:GetModuleConfig(name)
    if not cfg then return end
    local def = SP.db and SP.db.panel and SP.db.panel.moduleAppearance or {}
    cfg.appearance = cfg.appearance or {}
    cfg.appearance.bgColor = copyColor(cfg.appearance.bgColor or {}, nil, def.bgColor or { r = 0.12, g = 0.15, b = 0.20, a = 0.46 })
    cfg.appearance.textColor = copyColor(cfg.appearance.textColor or {}, nil, def.textColor or { r = 0.92, g = 0.96, b = 1 })
    local m = SP.modulesByName and SP.modulesByName[name]
    if m then SP:ApplyModuleAppearance(m) end
end

function SP:ApplyModuleAppearance(m)
    if not m then return end
    local app = SP:GetModuleAppearanceConfig(m.name)
    if not app then return end
    local bg = app.bgColor or {}
    local tx = app.textColor or {}
    local a = clamp(bg.a, 0, 1)
    local hr, hg, hb = clamp(bg.r, 0, 1), clamp(bg.g, 0, 1), clamp(bg.b, 0, 1)

    if m.headerBg then m.headerBg:SetColorTexture(hr, hg, hb, math.min(0.82, a + 0.18)) end
    if m.headerGlass then m.headerGlass:SetColorTexture(1, 1, 1, math.max(0.04, a * 0.24)) end
    if m.headerLine then m.headerLine:SetColorTexture(math.min(1, hr + 0.18), math.min(1, hg + 0.18), math.min(1, hb + 0.18), math.max(0.18, a * 0.80)) end
    if m.bodyBg then m.bodyBg:SetColorTexture(hr * 0.50, hg * 0.50, hb * 0.56, math.max(0.03, a * 0.78)) end
    if m.labelFS then m.labelFS:SetTextColor(clamp(tx.r, 0, 1), clamp(tx.g, 0, 1), clamp(tx.b, 0, 1), 1) end
    if m.suffixFS then m.suffixFS:SetTextColor(clamp(tx.r, 0, 1), clamp(tx.g, 0, 1), clamp(tx.b, 0, 1), 0.82) end
    if m._placeholder then m._placeholder:SetTextColor(clamp(tx.r, 0, 1), clamp(tx.g, 0, 1), clamp(tx.b, 0, 1), 0.30) end
    if m.frame then ApplyFontsRecursive(m.frame, m.name, 0) end
    SP:ApplyFontToObject(m.labelFS, m.name, 1)
    SP:ApplySecondaryFontToObject(m.suffixFS, m.name, 0)
    SP:ApplySecondaryFontToObject(m._placeholder, m.name, 0)
    if m.ApplyFonts then pcall(m.ApplyFonts, m) end
end

function SP:ApplyAllModuleAppearance()
    for _, m in ipairs(SP.modules or {}) do SP:ApplyModuleAppearance(m) end
end

-- Révèle un module quelques secondes (notification douce) puis restaure son état.
-- Réutilise forceReveal (respecté par fade/slide) + déplie si replié, et re-replie après.
function SP:RevealModule(m, seconds)
    if not m then return end
    local cfg = SP:GetModuleConfig(m.name)
    if m._revealPrevCollapsed == nil then m._revealPrevCollapsed = (cfg and cfg.collapsed) or false end
    if cfg and cfg.collapsed then cfg.collapsed = false; SP:UpdateCollapseVisual(m) end
    m._forceReveal = true
    if SP.panel then SP.panel:Show() end
    if m.frame and UIFrameFadeIn and m._layoutTop then pcall(UIFrameFadeIn, m.frame, 0.3, m.frame:GetAlpha() or 1, 1) end
    SP:RebuildLayout()
    if m._revealTimer then m._revealTimer:Cancel() end
    m._revealTimer = C_Timer.NewTimer(seconds or 5, function()
        m._forceReveal = false
        if m._revealPrevCollapsed then
            local c = SP:GetModuleConfig(m.name)
            if c then c.collapsed = true; SP:UpdateCollapseVisual(m) end
        end
        m._revealPrevCollapsed = nil
        m._revealTimer = nil
        SP:RebuildLayout()
    end)
end

-- ============================================================
-- A) Enregistrement
-- ============================================================
function SP:RegisterModule(module)
    if type(module) ~= "table" then
        SP:Print("|cFFFF5555RegisterModule|r : argument non-table ignoré")
        return false
    end
    for _, key in ipairs(REQUIRED) do
        if type(module[key]) ~= "string" then
            SP:Print(("|cFFFF5555RegisterModule|r : champ '%s' manquant"):format(key))
            return false
        end
    end
    for _, fn in ipairs(REQUIRED_FN) do
        if type(module[fn]) ~= "function" then
            SP:Print(("|cFFFF5555RegisterModule|r [%s] : méthode '%s' manquante")
                :format(module.name, fn))
            return false
        end
    end
    if SP.modulesByName[module.name] then
        SP:Print(("|cFFFF5555RegisterModule|r : doublon '%s' ignoré"):format(module.name))
        return false
    end

    SP.modulesByName[module.name] = module
    table.insert(SP.modules, module)
    return true
end

-- ============================================================
-- Ordres
-- ============================================================
-- Tous les modules enregistrés, dans l'ordre SPDB (ignore les noms inconnus,
-- ajoute en fin les modules absents de `order`).
function SP:GetOrderedModules()
    local result, seen = {}, {}
    local order = (SP.db and SP.db.modules and SP.db.modules.order) or {}
    for _, name in ipairs(order) do
        local m = SP.modulesByName[name]
        if m and not seen[name] then   -- déduplique (un ordre SPDB legacy peut contenir des doublons)
            result[#result + 1] = m
            seen[name] = true
        end
    end
    for _, m in ipairs(SP.modules) do
        if not seen[m.name] then result[#result + 1] = m end
    end
    return result
end

-- ============================================================
-- B) Construction visuelle
-- ============================================================
-- Nettoie SPDB.modules.order : retire doublons + noms non enregistrés, ajoute les modules manquants.
function SP:SanitizeOrder()
    if not (SP.db and SP.db.modules) then return end
    local new, seen = {}, {}
    for _, name in ipairs(SP.db.modules.order or {}) do
        if SP.modulesByName[name] and not seen[name] then new[#new + 1] = name; seen[name] = true end
    end
    for _, m in ipairs(SP.modules) do
        if not seen[m.name] then new[#new + 1] = m.name; seen[m.name] = true end
    end
    SP.db.modules.order = new
end

-- Conditions d'affichage : un module ne s'affiche que si ses conditions sont remplies.
function SP:ModuleConditionsMet(m)
    local cfg = SP:GetModuleConfig(m.name)
    local c = cfg and cfg.conditions
    if not c or not c.enabled then return true end
    local _, instType = IsInInstance()
    local inCombat = InCombatLockdown() or (UnitAffectingCombat and UnitAffectingCombat("player"))
    if c.capital and instType == "none" and IsResting and IsResting() then return true end
    if c.dungeon and instType == "party" then return true end
    if c.raid and instType == "raid" then return true end
    if c.group and IsInGroup and IsInGroup() then return true end
    if c.combat and inCombat then return true end
    if c.nocombat and not inCombat then return true end
    return false
end

function SP:BuildModules()
    if not SP.panel then return end
    SP:SanitizeOrder()
    SP:MigrateLegacyDocks()   -- cfg.dock (itération abandonnée) → cfg.corner + cfg.panel
    SP:_EnsureDragWidgets()
    for _, m in ipairs(SP.modules) do
        if not m.frame then
            SP:CreateModuleFrame(m)
            local ok, err = pcall(m.Init, m, m.body)
            if not ok then SP:Print(("Init %s : %s"):format(m.name, tostring(err))) end
            local cfg = SP:GetModuleConfig(m.name)
            if cfg and cfg.enabled then pcall(m.Enable, m) end
        end
    end
    SP:RebuildLayout()
end

-- Place le bandeau (header) en HAUT (défaut) ou en BAS de la frame du module.
-- cfg.headerBottom = true → bandeau en bas, le corps se déplie vers le HAUT.
function SP:ApplyHeaderLayout(m)
    if not (m and m.frame and m.header and m.body) then return end
    local cfg = SP:GetModuleConfig(m.name)
    m.header:ClearAllPoints()
    m.body:ClearAllPoints()
    if m.headerless then
        m.header:Hide()
        m.body:SetPoint("TOPLEFT",  m.frame, "TOPLEFT",  0, 0)
        m.body:SetPoint("TOPRIGHT", m.frame, "TOPRIGHT", 0, 0)
        return
    end
    m.header:Show()
    if cfg and cfg.headerBottom then
        m.header:SetPoint("BOTTOMLEFT",  m.frame, "BOTTOMLEFT",  0, 0)
        m.header:SetPoint("BOTTOMRIGHT", m.frame, "BOTTOMRIGHT", 0, 0)
        m.body:SetPoint("TOPLEFT",  m.frame, "TOPLEFT",  0, 0)
        m.body:SetPoint("TOPRIGHT", m.frame, "TOPRIGHT", 0, 0)
        if m.headerLine then
            m.headerLine:ClearAllPoints()
            m.headerLine:SetPoint("TOPLEFT",  m.header, "TOPLEFT",  1, 0)
            m.headerLine:SetPoint("TOPRIGHT", m.header, "TOPRIGHT", -1, 0)
        end
    else
        m.header:SetPoint("TOPLEFT",  m.frame, "TOPLEFT",  0, 0)
        m.header:SetPoint("TOPRIGHT", m.frame, "TOPRIGHT", 0, 0)
        m.body:SetPoint("TOPLEFT",  m.header, "BOTTOMLEFT",  0, 0)
        m.body:SetPoint("TOPRIGHT", m.header, "BOTTOMRIGHT", 0, 0)
        if m.headerLine then
            m.headerLine:ClearAllPoints()
            m.headerLine:SetPoint("BOTTOMLEFT",  m.header, "BOTTOMLEFT",  1, 0)
            m.headerLine:SetPoint("BOTTOMRIGHT", m.header, "BOTTOMRIGHT", -1, 0)
        end
    end
end

function SP:CreateModuleFrame(m)
    local UIc     = SP.UI
    local content = SP.panel.content
    local headerH = m.headerHeight or UIc.HEADER_H

    local frame = CreateFrame("Frame", "SpherePanelModule_" .. m.name, content)
    frame:SetPoint("TOPLEFT",  content, "TOPLEFT",  0, 0)   -- repositionné par RebuildLayout
    frame:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, 0)
    frame:SetHeight(headerH)

    -- --- Header (Button : clic = collapse, drag = reorder) ---
    local header = CreateFrame("Button", nil, frame)
    header:SetPoint("TOPLEFT",  frame, "TOPLEFT",  0, 0)
    header:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    header:SetHeight(headerH)
    header:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    header:RegisterForDrag("LeftButton")
    local hbg = header:CreateTexture(nil, "BACKGROUND")
    hbg:SetAllPoints(header)
    hbg:SetColorTexture(0.14, 0.14, 0.18, 0.95)
    local hglass = header:CreateTexture(nil, "ARTWORK")
    hglass:SetPoint("TOPLEFT", header, "TOPLEFT", 1, -1)
    hglass:SetPoint("TOPRIGHT", header, "TOPRIGHT", -1, -1)
    hglass:SetHeight(math.max(6, headerH * 0.45))
    hglass:SetColorTexture(1, 1, 1, 0.10)
    local hline = header:CreateTexture(nil, "OVERLAY")
    hline:SetPoint("BOTTOMLEFT", header, "BOTTOMLEFT", 1, 0)
    hline:SetPoint("BOTTOMRIGHT", header, "BOTTOMRIGHT", -1, 0)
    hline:SetHeight(1)
    hline:SetColorTexture(0.35, 0.62, 1, 0.35)
    local hl = header:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints(header)
    hl:SetColorTexture(1, 1, 1, 0.10)

    local baseLvl = header:GetFrameLevel()

    -- Bouton de réduction RETIRÉ (DEC-026) : plus de flèche ▶/▼ ni de clic-collapse.
    -- L'état `collapsed` subsiste UNIQUEMENT pour le pilotage programmatique (Bags via B,
    -- SilverDragon sur alerte, touche C du module Personnage).

    -- Label
    local label = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("LEFT", header, "LEFT", 8, 0)
    label:SetText(m.label)
    m.labelFS = label

    -- Cadenas : épingle l'affichage (exclu du futur auto-fade)
    local lock = CreateFrame("Button", nil, header)
    lock:SetSize(math.min(UIc.HEADER_H, headerH) - 4, math.min(UIc.HEADER_H, headerH) - 4)
    lock:SetPoint("RIGHT", header, "RIGHT", -3, 0)
    lock:SetFrameLevel(baseLvl + 2)
    lock:SetScript("OnClick", function() SP:TogglePin(m) end)
    lock:SetScript("OnEnter", function(s)
        GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
        local cfg = SP:GetModuleConfig(m.name)
        GameTooltip:SetText((cfg and cfg.pinned) and "Épinglé — clic pour libérer" or "Épingler ce module")
        GameTooltip:Show()
    end)
    lock:SetScript("OnLeave", function() GameTooltip:Hide() end)
    m.lock = lock

    -- Suffixe dynamique du bandeau (ex : compteur de quêtes "18 / 35")
    local suffix = header:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    suffix:SetPoint("RIGHT", lock, "LEFT", -6, 0)
    suffix._spFontRole = "secondary"
    m.suffixFS = suffix

    -- Clic gauche = réduire/ouvrir (sans flèche) ; clic droit = menu ; drag = reorder.
    header:SetScript("OnClick", function(_, button)
        if button == "RightButton" then SP:ShowModuleMenu(m)
        elseif not m.headerless then SP:ToggleCollapse(m) end
    end)
    header:SetScript("OnDragStart", function() SP:BeginReorder(m) end)
    header:SetScript("OnDragStop",  function() SP:EndReorder(m) end)
    m.header = header

    -- --- Body (contenu du module) --- (ancrage haut/bas posé par ApplyHeaderLayout)
    local body = CreateFrame("Frame", nil, frame)
    local cfg = SP:GetModuleConfig(m.name)
    body:SetHeight((cfg and cfg.height) or m.defaultHeight or 100)
    local bbg = body:CreateTexture(nil, "BACKGROUND")
    bbg:SetAllPoints(body)
    bbg:SetColorTexture(0.08, 0.08, 0.10, 0.85)
    -- Placeholder visuel tant que le module ne dessine pas (sera masqué quand Init dessinera).
    local ph = body:CreateFontString(nil, "OVERLAY", "GameFontDisableLarge")
    ph:SetPoint("CENTER")
    ph:SetText(m.label)
    ph:SetAlpha(0.30)
    ph._spFontRole = "secondary"
    m._placeholder = ph

    m.frame = frame
    m.body  = body
    m.headerBg = hbg
    m.headerGlass = hglass
    m.headerLine = hline
    m.bodyBg = bbg

    -- Ancrage bandeau/corps (haut par défaut, bas si cfg.headerBottom ; gère aussi headerless)
    SP:ApplyHeaderLayout(m)

    SP:ApplyModuleAppearance(m)
    SP:UpdateCollapseVisual(m)
    SP:UpdatePinVisual(m)
end

-- ============================================================
-- Collapse / Options / Disable
-- ============================================================
function SP:UpdateCollapseVisual(m)
    local cfg = SP:GetModuleConfig(m.name)
    if not cfg then return end
    if m.headerless then if m.body then m.body:Show() end return end
    if m.arrow then m.arrow:SetNormalTexture(cfg.collapsed and TEX_PLUS or TEX_MINUS) end
    if m.body then
        if cfg.collapsed then m.body:Hide() else m.body:Show() end
    end
    if m.OnCollapseChanged then pcall(m.OnCollapseChanged, m, cfg.collapsed and true or false) end
end

function SP:ToggleCollapse(m)
    local cfg = SP:GetModuleConfig(m.name)
    if not cfg then return end
    cfg.collapsed = not cfg.collapsed
    SP:UpdateCollapseVisual(m)
    SP:RebuildLayout()
end

-- ------------------------------------------------------------
-- Cadenas / épingle (pin)
-- ------------------------------------------------------------
function SP:UpdatePinVisual(m)
    if not m.lock or not m.frame then return end
    local cfg = SP:GetModuleConfig(m.name)
    local pinned = cfg and cfg.pinned
    m.lock:SetNormalTexture(pinned and TEX_LOCK or TEX_UNLOCK)
    m.lock:SetAlpha(pinned and 1 or 0.45)
    -- un module épinglé ignore l'alpha du panneau → reste opaque sous l'auto-fade (phase 2)
    m.frame:SetIgnoreParentAlpha(pinned and true or false)
end

function SP:TogglePin(m)
    local cfg = SP:GetModuleConfig(m.name)
    if not cfg then return end
    cfg.pinned = not cfg.pinned
    SP:UpdatePinVisual(m)
end

-- Texte secondaire du bandeau (suffixe). Utilisé par QuestTracker (compteur), etc.
function SP:SetModuleHeaderText(m, text)
    if m and m.suffixFS then m.suffixFS:SetText(text or "") end
end

-- Hauteur auto d'un module : respecte une hauteur fixée manuellement (cfg.fixedHeight).
function SP:SetAutoHeight(m, needed)
    local cfg = SP:GetModuleConfig(m.name)
    if not cfg or cfg.fixedHeight then return end
    if cfg.height ~= needed then
        cfg.height = needed
        SP:RebuildLayout()
    end
end

-- ------------------------------------------------------------
-- Menu contextuel (clic droit sur le bandeau)
-- ------------------------------------------------------------
function SP:ShowModuleMenu(m)
    local cfg = SP:GetModuleConfig(m.name)
    local function build(_, root)
        root:CreateTitle(m.label)
        root:CreateButton("Paramètres", function()
            if SP.OpenConfig then SP:OpenConfig(m.name) end
        end)
        root:CreateButton((cfg and cfg.pinned) and "Déverrouiller" or "Verrouiller", function()
            SP:TogglePin(m)
        end)
        -- Réserver un coin d'écran de la colonne du panneau (haut/bas ; le côté suit le panneau).
        -- Aussi accessible en glissant le bandeau vers une zone de coin.
        local sub = root:CreateButton("Réserver le coin d'écran")
        local function setCorner(v) if cfg then cfg.corner = v; SP:RebuildLayout() end end
        sub:CreateButton(((cfg and cfg.corner == "top") and "* " or "") .. "Coin haut", function() setCorner("top") end)
        sub:CreateButton(((cfg and cfg.corner == "bottom") and "* " or "") .. "Coin bas", function() setCorner("bottom") end)
        sub:CreateButton(((cfg and not cfg.corner) and "* " or "") .. "Aucun (dans le flux)", function() setCorner(nil) end)
        -- Bandeau en bas : le corps se déplie vers le haut (utile pour le chat)
        root:CreateButton(((cfg and cfg.headerBottom) and "* " or "") .. "Bandeau en bas (déplier vers le haut)", function()
            if cfg then
                cfg.headerBottom = (not cfg.headerBottom) and true or nil
                SP:ApplyHeaderLayout(m)
                SP:RebuildLayout()
            end
        end)
        root:CreateButton("Masquer", function() SP:DisableModuleUI(m) end)
    end
    if MenuUtil and MenuUtil.CreateContextMenu then
        MenuUtil.CreateContextMenu(m.header, build)
    else
        SP:_ShowFallbackMenu(m)
    end
end

-- Menu de secours minimal si MenuUtil indisponible (build ancienne / future).
function SP:_ShowFallbackMenu(m)
    local cfg = SP:GetModuleConfig(m.name)
    local entries = {
        { "Paramètres", function() if SP.OpenConfig then SP:OpenConfig(m.name) end end },
        { (cfg and cfg.pinned) and "Déverrouiller" or "Verrouiller", function() SP:TogglePin(m) end },
        { "Masquer", function() SP:DisableModuleUI(m) end },
    }
    local menu = SP._fbMenu
    if not menu then
        menu = CreateFrame("Frame", "SpherePanelCtxMenu", UIParent)
        menu:SetFrameStrata("DIALOG")
        menu:EnableMouse(true)
        local bg = menu:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(menu); bg:SetColorTexture(0.05, 0.05, 0.07, 0.96)
        menu.buttons = {}
        menu:SetScript("OnLeave", function(s) if not s:IsMouseOver() then s:Hide() end end)
        SP._fbMenu = menu
    end
    local W, ROW = 150, 18
    for i, e in ipairs(entries) do
        local b = menu.buttons[i]
        if not b then
            b = CreateFrame("Button", nil, menu)
            b:SetSize(W - 4, ROW)
            b:SetPoint("TOPLEFT", menu, "TOPLEFT", 2, -2 - (i - 1) * ROW)
            b.fs = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            b.fs:SetPoint("LEFT", b, "LEFT", 4, 0)
            local hl = b:CreateTexture(nil, "HIGHLIGHT"); hl:SetAllPoints(b); hl:SetColorTexture(1, 1, 1, 0.10)
            menu.buttons[i] = b
        end
        b.fs:SetText(e[1])
        b:SetScript("OnClick", function() menu:Hide(); e[2]() end)
        b:Show()
    end
    for i = #entries + 1, #menu.buttons do menu.buttons[i]:Hide() end
    menu:SetSize(W, 4 + #entries * ROW)
    menu:ClearAllPoints()
    local scale = UIParent:GetEffectiveScale()
    local x, y = GetCursorPosition()
    menu:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x / scale, y / scale)
    menu:Show()
end

-- Désactive le module (Disable + masque). Réactivable via menu, /sp enable <Nom> ou options.
function SP:DisableModuleUI(m)
    local cfg = SP:GetModuleConfig(m.name)
    if not cfg then return end
    cfg.enabled = false
    pcall(m.Disable, m)
    if m.frame then m.frame:Hide() end
    SP:RebuildLayout()
end

function SP:EnableModule(name)
    local m = SP.modulesByName[name]
    if not m then SP:Print("Module inconnu : " .. tostring(name)); return end
    local cfg = SP:GetModuleConfig(name)
    if not cfg then return end
    cfg.enabled = true
    if m.frame then m.frame:Show() end
    pcall(m.Enable, m)
    SP:RebuildLayout()
end

-- ============================================================
-- Layout : ancre les modules activés TOP→BOTTOM dans content.
-- Stocke _layoutTop / _layoutHeight (coordonnées de layout, lues par le drag).
-- ============================================================
function SP:AnchorModuleFrame(m, content, x, y)
    if not (m and m.frame and content) then return end
    local cfg = SP:GetModuleConfig(m.name)
    x, y = x or 0, y or 0
    m.frame:ClearAllPoints()
    m.frame:SetPoint("TOPLEFT", content, "TOPLEFT", x, -y)
    if cfg and cfg.width and cfg.width > 0 then
        m.frame:SetWidth(cfg.width)
    else
        m.frame:SetPoint("TOPRIGHT", content, "TOPRIGHT", x, -y)
    end
end

-- ============================================================
-- Réservations de coin (système unifié) : chaque panneau actif possède deux
-- emplacements réservés aux extrémités de SA colonne d'écran — coin HAUT et
-- coin BAS de son côté. Un module `cfg.corner = "top"|"bottom"` y est empilé,
-- collé au coin, même largeur que le panneau, et le flux central s'écarte
-- (ApplyCornerReservations) → aucun chevauchement. Les modules de coin restent
-- dans le système de tick (fade/slide) comme les autres.
-- (Remplace l'itération précédente de docks flottants TL/TR/BL/BR.)
-- ============================================================

-- Côté d'écran d'une colonne : ① = db.panel.side ; ② = side résolu (auto = opposé).
function SP:_ColumnSide(idx)
    local side1 = (SP.db.panel and SP.db.panel.side) or "right"
    if idx == 2 then
        return SP._p2side or ((side1 == "right") and "left" or "right")
    end
    return side1
end

-- Largeur d'une colonne (valeur SPDB, jamais de mesure runtime — AP-06).
function SP:_ColumnWidth(idx)
    if idx == 2 then
        return (SP.db.panel.panel2 and SP.db.panel.panel2.width) or 280
    end
    return SP.db.panel.width or 280
end

-- Host d'un coin de colonne (créé à la demande). key = "<idx><which>" (ex "1top").
function SP:EnsureCornerHost(idx, which)
    SP.cornerHosts = SP.cornerHosts or {}
    local key = idx .. which
    local d = SP.cornerHosts[key]
    if not d then
        d = CreateFrame("Frame", "SpherePanelCorner" .. key, UIParent)
        d:SetFrameStrata("HIGH")   -- au-dessus des barres d'action/sacs par défaut (sinon occulté)
        d:SetClampedToScreen(true)
        d._idx, d._which = idx, which
        d:Hide()
        SP.cornerHosts[key] = d
    end
    -- (Ré)ancrage : collé au coin d'écran du côté de la colonne, même largeur qu'elle.
    local side = SP:_ColumnSide(idx)
    local pt = ((which == "top") and "TOP" or "BOTTOM") .. ((side == "left") and "LEFT" or "RIGHT")
    d:ClearAllPoints()
    d:SetPoint(pt, UIParent, pt, 0, 0)
    d:SetWidth(SP:_ColumnWidth(idx))
    return d
end

-- Décale le flux central pour laisser la place aux coins réservés (modes aimantés 1/2
-- uniquement — en mode libre la position appartient à l'utilisateur).
function SP:ApplyCornerReservations()
    local GAP = (SP.UI and SP.UI.GAP) or 4
    local ch = SP._cornerH or {}
    local p, b = SP.panel, SP.db.panel.behavior or 3
    if p and (b == 1 or b == 2) then
        local side = SP.db.panel.side or "right"
        local vpos = SP.db.panel.vpos or "top"
        local x = math.abs(SP.db.panel.x or 20)
        local h = ch["1" .. ((vpos == "bottom") and "bottom" or "top")] or 0
        local y = (h > 0) and (h + GAP) or 0
        p:ClearAllPoints()
        if vpos == "bottom" then
            if side == "left" then p:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x, y)
            else p:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -x, y) end
        else
            if side == "left" then p:SetPoint("TOPLEFT", UIParent, "TOPLEFT", x, -y)
            else p:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -x, -y) end
        end
    end
    local p2, p2cfg = SP.panel2, SP.db.panel.panel2
    if p2 and p2:IsShown() and p2cfg and p2cfg.enabled then
        local b2 = p2cfg.behavior or 3
        if b2 == 1 or b2 == 2 then
            local side2 = SP:_ColumnSide(2)
            local vpos2 = p2cfg.vpos or "top"
            local h2 = ch["2" .. ((vpos2 == "bottom") and "bottom" or "top")] or 0
            local y2 = 4 + ((h2 > 0) and (h2 + GAP) or 0)
            p2:ClearAllPoints()
            if vpos2 == "bottom" then
                if side2 == "left" then p2:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 4, y2)
                else p2:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -4, y2) end
            else
                if side2 == "left" then p2:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 4, -y2)
                else p2:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -4, -y2) end
            end
        end
    end
end

-- Zones de dépôt (contour bleu + libellé) pendant un drag de bandeau : une zone
-- par coin de chaque colonne ACTIVE (2 zones, ou 4 si le panneau ② est affiché).
function SP:_ShowCornerZones(show)
    SP._cornerZones = SP._cornerZones or {}
    if not show then
        for _, z in pairs(SP._cornerZones) do z:Hide() end
        return
    end
    local panels = { 1 }
    if SP.panel2 and SP.panel2:IsShown() then panels[#panels + 1] = 2 end
    for _, idx in ipairs(panels) do
        for _, which in ipairs({ "top", "bottom" }) do
            local key = idx .. which
            local z = SP._cornerZones[key]
            if not z then
                z = CreateFrame("Frame", nil, UIParent)
                z:SetFrameStrata("FULLSCREEN_DIALOG")
                z.bg = z:CreateTexture(nil, "BACKGROUND"); z.bg:SetAllPoints(z)
                z.borders = {}
                for _, e in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
                    local t = z:CreateTexture(nil, "OVERLAY"); t:SetColorTexture(0.35, 0.75, 1.0, 0.9)
                    z.borders[e] = t
                end
                z.borders.TOP:SetPoint("TOPLEFT"); z.borders.TOP:SetPoint("TOPRIGHT"); z.borders.TOP:SetHeight(2)
                z.borders.BOTTOM:SetPoint("BOTTOMLEFT"); z.borders.BOTTOM:SetPoint("BOTTOMRIGHT"); z.borders.BOTTOM:SetHeight(2)
                z.borders.LEFT:SetPoint("TOPLEFT"); z.borders.LEFT:SetPoint("BOTTOMLEFT"); z.borders.LEFT:SetWidth(2)
                z.borders.RIGHT:SetPoint("TOPRIGHT"); z.borders.RIGHT:SetPoint("BOTTOMRIGHT"); z.borders.RIGHT:SetWidth(2)
                z.label = z:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                z.label:SetPoint("CENTER")
                z._idx, z._which = idx, which
                SP._cornerZones[key] = z
            end
            local side = SP:_ColumnSide(idx)
            local pt = ((which == "top") and "TOP" or "BOTTOM") .. ((side == "left") and "LEFT" or "RIGHT")
            z:ClearAllPoints()
            z:SetPoint(pt, UIParent, pt, 0, 0)
            z:SetSize(SP:_ColumnWidth(idx), 60)
            z.bg:SetColorTexture(0.30, 0.70, 1.0, 0.12)
            z.label:SetText(((which == "top") and "Coin haut" or "Coin bas")
                .. ((idx == 2) and " (panneau 2)" or ""))
            z:Show()
        end
    end
end

-- Zone de coin sous le curseur (ou nil) → idx, which.
function SP:_CornerZoneAtCursor()
    if not SP._cornerZones then return nil end
    for _, z in pairs(SP._cornerZones) do
        if z:IsShown() and z:IsMouseOver() then return z._idx, z._which end
    end
    return nil
end

-- Migration : ancien système de docks flottants (cfg.dock = TL/TR/BL/BR) →
-- réservation de coin de colonne (cfg.corner + cfg.panel). Appelé par BuildModules.
function SP:MigrateLegacyDocks()
    local mods = SP.db and SP.db.modules
    if not mods then return end
    local side1 = (SP.db.panel and SP.db.panel.side) or "right"
    local p2en = SP.db.panel and SP.db.panel.panel2 and SP.db.panel.panel2.enabled
    for _, cfg in pairs(mods) do
        if type(cfg) == "table" and cfg.dock then
            local d = cfg.dock
            cfg.corner = (d == "TL" or d == "TR") and "top" or "bottom"
            local dockSide = (d == "TL" or d == "BL") and "left" or "right"
            cfg.panel = (dockSide == side1) and 1 or (p2en and 2 or 1)
            cfg.dock = nil
        end
    end
end

function SP:RebuildLayout()
    local panel = SP.panel
    if not panel then return end
    local UIc = SP.UI
    local p2 = SP.panel2 and SP.panel2:IsShown() and SP.panel2 or nil
    local y1, y2 = 0, 0
    local top1, flow1, bottom1 = {}, {}, {}
    local top2, flow2, bottom2 = {}, {}, {}

    local function GetModuleHeight(m, cfg)
        local h
        if m.headerless then
            h = cfg.height or m.defaultHeight or 100
            if m.body then m.body:SetHeight(h) end
        else
            h = m.headerHeight or UIc.HEADER_H
            if not cfg.collapsed then
                local bodyH = cfg.height or m.defaultHeight or 100
                if m.body then m.body:SetHeight(bodyH) end
                h = h + bodyH
            end
        end
        return h
    end

    local function Queue(list, m, cfg, onP2)
        list[#list + 1] = { module = m, cfg = cfg, onP2 = onP2 }
    end

    local function Place(entry, content, y)
        local m, cfg = entry.module, entry.cfg
        if m.frame:GetParent() ~= content then m.frame:SetParent(content) end
        local h = GetModuleHeight(m, cfg)
        SP:AnchorModuleFrame(m, content, m._curSlide or 0, y)   -- respecte le glissement courant
        m.frame:SetHeight(h)
        -- Anti-scintillement (AP-32) : ne PLUS forcer alpha=1 en masse (sinon flash global au
        -- relayout, puis re-estompage par _PanelTick). Seul un module explicitement révélé
        -- passe à 1 ; les autres gardent leur alpha animé courant.
        if m._forceReveal then m.frame:SetAlpha(1) end
        m.frame:Show()
        m._layoutTop, m._layoutHeight = y, h
        m._layoutHost = content   -- host d'ancrage (content de panneau OU host de coin) — lu par les ticks
        m._onPanel2 = entry.onP2
        return y + h + UIc.GAP
    end

    local function Layout(list, content, y)
        for _, entry in ipairs(list) do
            y = Place(entry, content, y)
        end
        return y
    end

    for _, m in ipairs(SP:GetOrderedModules()) do
        local cfg = SP:GetModuleConfig(m.name)
        if cfg and cfg.enabled and m.frame and SP:ModuleConditionsMet(m) then
            -- panneau cible (2 si demandé ET second panneau actif, sinon 1)
            local onP2 = (cfg.panel == 2) and p2 ~= nil
            if cfg.corner == "top" then
                Queue(onP2 and top2 or top1, m, cfg, onP2)
            elseif cfg.corner == "bottom" then
                Queue(onP2 and bottom2 or bottom1, m, cfg, onP2)
            else
                Queue(onP2 and flow2 or flow1, m, cfg, onP2)
            end
        elseif m.frame then
            m.frame:Hide()
            m._layoutTop, m._layoutHeight, m._layoutHost = nil, nil, nil
        end
    end

    -- Flux central de chaque colonne.
    y1 = Layout(flow1, panel.content, y1)
    if p2 then y2 = Layout(flow2, p2.content, y2) end

    -- Coins réservés : mini-pile par extrémité de colonne, collée au coin d'écran.
    -- Host pré-dimensionné AVANT placement (géométrie finale dès l'ancrage), hauteurs
    -- mémorisées pour que le flux s'écarte (ApplyCornerReservations).
    SP._cornerH = {}
    local cornerLists = { ["1top"] = top1, ["1bottom"] = bottom1, ["2top"] = top2, ["2bottom"] = bottom2 }
    for key, list in pairs(cornerLists) do
        local idx, which = tonumber(key:sub(1, 1)), key:sub(2)
        if #list == 0 then
            if SP.cornerHosts and SP.cornerHosts[key] then SP.cornerHosts[key]:Hide() end
        else
            local d = SP:EnsureCornerHost(idx, which)
            local total = 0
            for _, entry in ipairs(list) do
                total = total + GetModuleHeight(entry.module, entry.cfg) + UIc.GAP
            end
            if total < 1 then total = 1 end
            d:SetHeight(total)
            d:Show()
            local yd = 0
            for _, entry in ipairs(list) do
                yd = Place(entry, d, yd)
            end
            SP._cornerH[key] = total
        end
    end

    if y1 < 1 then y1 = 1 end
    panel.content:SetHeight(y1)
    panel:SetHeight(y1 + UIc.TITLE_H)
    if p2 then
        local empty = y2 < 1
        if p2.emptyHint then p2.emptyHint:SetShown(empty) end
        if empty then y2 = 80 end   -- zone de dépôt visible quand vide
        p2.content:SetHeight(y2)
        p2:SetHeight(y2 + UIc.TITLE_H)
    end

    -- Le flux s'écarte des coins réservés (aucun chevauchement en modes aimantés).
    SP:ApplyCornerReservations()
end

-- ============================================================
-- C) Drag-to-reorder
-- ============================================================
function SP:_EnsureDragWidgets()
    if not SP._ghost then
        local g = CreateFrame("Frame", "SpherePanelGhost", UIParent)
        g:SetFrameStrata("TOOLTIP")
        g:SetSize(200, SP.UI.HEADER_H)
        g:SetAlpha(0.85)
        g:Hide()
        local bg = g:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(g)
        bg:SetColorTexture(0.20, 0.45, 0.85, 0.65)
        g.label = g:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        g.label:SetPoint("LEFT", g, "LEFT", 6, 0)
        SP._ghost = g
    end
    if not SP._dropLine then
        -- ligne portée par une frame TOOLTIP → peut s'afficher au-dessus du panneau ① OU ②
        local f = CreateFrame("Frame", nil, UIParent); f:SetFrameStrata("TOOLTIP")
        local ln = f:CreateTexture(nil, "OVERLAY")
        ln:SetColorTexture(0.30, 0.70, 1.0, 0.95)
        ln:SetHeight(2)
        ln:Hide()
        SP._dropFrame, SP._dropLine = f, ln
    end
end

-- Modules visibles d'UN panneau (① ou ②), dans l'ordre, avec position de layout.
function SP:GetPanelModules(isP2)
    isP2 = isP2 and true or false
    local t = {}
    for _, m in ipairs(SP:GetOrderedModules()) do
        local cfg = SP:GetModuleConfig(m.name)
        if cfg and cfg.enabled and m.frame and m._layoutTop and not cfg.corner and ((m._onPanel2 and true or false) == isP2) then
            t[#t + 1] = m
        end
    end
    return t
end

function SP:BeginReorder(m)
    if SP.db.panel.locked or InCombatLockdown() then return end
    SP:_EnsureDragWidgets()
    SP._dragModule = m
    local g = SP._ghost
    g.label:SetText(m.label)
    g:SetWidth(SP.panel:GetWidth())
    g:Show()
    SP:_ShowCornerZones(true)   -- montre les coins réservés des colonnes actives
    g:SetScript("OnUpdate", function() SP:UpdateReorder() end)
end

-- Panneau actuellement survolé par le curseur (pour le drag) → content + isP2.
function SP:_DragTarget()
    if SP.panel2 and SP.panel2:IsShown() and SP.panel2:IsMouseOver() then
        return SP.panel2.content, true
    end
    return SP.panel.content, false
end

-- Index d'insertion parmi `mods` (modules d'un panneau) selon la position Y du curseur.
function SP:ComputeDropIndex(content, mods)
    local top = content and content:GetTop()
    if not top then return nil end
    local scale = content:GetEffectiveScale()
    local _, cy = GetCursorPosition()
    cy = cy / scale
    local off = top - cy
    for i, m in ipairs(mods) do
        local mt, mh = m._layoutTop, m._layoutHeight or 0
        if mt and off < (mt + mh / 2) then return i end
    end
    return #mods + 1
end

function SP:ShowDropIndicator(content, mods, idx)
    local ln = SP._dropLine
    if not ln or not content then return end
    local yTop
    if idx and mods[idx] and mods[idx]._layoutTop then
        yTop = mods[idx]._layoutTop
    else
        local last = mods[#mods]
        yTop = last and ((last._layoutTop or 0) + (last._layoutHeight or 0)) or 0
    end
    ln:ClearAllPoints()
    ln:SetPoint("TOPLEFT",  content, "TOPLEFT",  0, -yTop + 1)
    ln:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, -yTop + 1)
    ln:Show()
end

function SP:UpdateReorder()
    local g = SP._ghost
    if not g then return end
    local scale = UIParent:GetEffectiveScale()
    local x, y = GetCursorPosition()
    x, y = x / scale, y / scale
    g:ClearAllPoints()
    g:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x + 8, y + 8)
    -- survol d'un coin réservé ? → surligne la zone, cache la ligne d'insertion panneau
    local zIdx, zWhich = SP:_CornerZoneAtCursor()
    if SP._cornerZones then
        for _, z in pairs(SP._cornerZones) do
            local hot = (z._idx == zIdx and z._which == zWhich)
            z.bg:SetColorTexture(0.30, 0.70, 1.0, hot and 0.30 or 0.12)
        end
    end
    if zIdx then
        if SP._dropLine then SP._dropLine:Hide() end
        return
    end
    -- sinon : ligne d'insertion sur le panneau survolé (① ou ②)
    local content, isP2 = SP:_DragTarget()
    local mods = SP:GetPanelModules(isP2)
    SP:ShowDropIndicator(content, mods, SP:ComputeDropIndex(content, mods))
end

function SP:EndReorder(m)
    local g = SP._ghost
    if g then g:SetScript("OnUpdate", nil); g:Hide() end
    if SP._dropLine then SP._dropLine:Hide() end

    -- Lâché sur un coin réservé ? → le module occupe ce coin de colonne.
    local zIdx, zWhich = SP:_CornerZoneAtCursor()
    SP:_ShowCornerZones(false)
    local cfg = SP:GetModuleConfig(m.name)
    if zIdx then
        if cfg then cfg.panel = zIdx; cfg.corner = zWhich end
        SP._dragModule = nil
        SP:RebuildLayout()
        return
    end

    -- panneau cible = celui survolé ; on calcule l'index AVANT de déplacer le module
    local content, isP2 = SP:_DragTarget()
    local mods = SP:GetPanelModules(isP2)
    local dropIdx = SP:ComputeDropIndex(content, mods)
    local beforeName = (dropIdx and mods[dropIdx]) and mods[dropIdx].name or nil

    -- assignation du panneau (① ou ②) selon le survol ; un drop dans le flux sort du coin
    if cfg then cfg.panel = isP2 and 2 or 1; cfg.corner = nil end
    SP._dragModule = nil

    -- Liste complète des noms ordonnés, dragged retiré, réinséré avant beforeName.
    local full = {}
    for _, mm in ipairs(SP:GetOrderedModules()) do full[#full + 1] = mm.name end
    for i = #full, 1, -1 do if full[i] == m.name then table.remove(full, i) end end

    local pos = #full + 1
    if beforeName and beforeName ~= m.name then
        for i, n in ipairs(full) do if n == beforeName then pos = i; break end end
    end
    table.insert(full, pos, m.name)

    SP.db.modules.order = full
    SP:RebuildLayout()
end
