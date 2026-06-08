-- ============================================================
-- ModuleSystem.lua — Moteur de modules
--   • Registre + validation d'interface
--   • Bandeaux collapsibles (header + content)
--   • Drag-to-reorder (fantôme + RebuildLayout)
-- ============================================================
local ADDON_NAME, SP = ...

-- Textures de boutons natives (bords transparents garantis).
local TEX_PLUS  = "Interface\\Buttons\\UI-PlusButton-Up"
local TEX_MINUS = "Interface\\Buttons\\UI-MinusButton-Up"
local TEX_GEAR  = "Interface\\Buttons\\UI-OptionsButton"

-- Interface obligatoire que tout module DOIT exposer.
local REQUIRED    = { "name", "label" }
local REQUIRED_FN = { "Init", "Enable", "Disable", "OnResize" }

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
        if m then
            result[#result + 1] = m
            seen[name] = true
        end
    end
    for _, m in ipairs(SP.modules) do
        if not seen[m.name] then result[#result + 1] = m end
    end
    return result
end

-- Sous-ensemble activé (visible) dans l'ordre courant.
function SP:GetVisibleOrderedModules()
    local t = {}
    for _, m in ipairs(SP:GetOrderedModules()) do
        local cfg = SP:GetModuleConfig(m.name)
        if cfg and cfg.enabled and m.frame then t[#t + 1] = m end
    end
    return t
end

-- ============================================================
-- B) Construction visuelle
-- ============================================================
function SP:BuildModules()
    if not SP.panel then return end
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

function SP:CreateModuleFrame(m)
    local UIc     = SP.UI
    local content = SP.panel.content

    local frame = CreateFrame("Frame", "SpherePanelModule_" .. m.name, content)
    frame:SetPoint("TOPLEFT",  content, "TOPLEFT",  0, 0)   -- repositionné par RebuildLayout
    frame:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, 0)
    frame:SetHeight(UIc.HEADER_H)

    -- --- Header (Button : clic = collapse, drag = reorder) ---
    local header = CreateFrame("Button", nil, frame)
    header:SetPoint("TOPLEFT",  frame, "TOPLEFT",  0, 0)
    header:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    header:SetHeight(UIc.HEADER_H)
    header:RegisterForClicks("LeftButtonUp")
    header:RegisterForDrag("LeftButton")
    local hbg = header:CreateTexture(nil, "BACKGROUND")
    hbg:SetAllPoints(header)
    hbg:SetColorTexture(0.14, 0.14, 0.18, 0.95)
    local hl = header:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints(header)
    hl:SetColorTexture(1, 1, 1, 0.06)

    local baseLvl = header:GetFrameLevel()

    -- Flèche collapse/expand
    local arrow = CreateFrame("Button", nil, header)
    arrow:SetSize(UIc.HEADER_H - 4, UIc.HEADER_H - 4)
    arrow:SetPoint("LEFT", header, "LEFT", 3, 0)
    arrow:SetFrameLevel(baseLvl + 2)
    arrow:SetScript("OnClick", function() SP:ToggleCollapse(m) end)
    m.arrow = arrow

    -- Label
    local label = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("LEFT", arrow, "RIGHT", 4, 0)
    label:SetText(m.label)

    -- Bouton fermer (désactive le module)
    local close = CreateFrame("Button", nil, header, "UIPanelCloseButton")
    close:SetSize(UIc.HEADER_H, UIc.HEADER_H)
    close:SetPoint("RIGHT", header, "RIGHT", 2, 0)
    close:SetFrameLevel(baseLvl + 2)
    close:SetScript("OnClick", function() SP:DisableModuleUI(m) end)

    -- Bouton options (inline) — stub étape 2
    local opt = CreateFrame("Button", nil, header)
    opt:SetSize(UIc.HEADER_H - 4, UIc.HEADER_H - 4)
    opt:SetPoint("RIGHT", close, "LEFT", -2, 0)
    opt:SetFrameLevel(baseLvl + 2)
    opt:SetNormalTexture(TEX_GEAR)
    opt:SetScript("OnClick", function() SP:ToggleOptions(m) end)

    header:SetScript("OnClick",     function() SP:ToggleCollapse(m) end)
    header:SetScript("OnDragStart", function() SP:BeginReorder(m) end)
    header:SetScript("OnDragStop",  function() SP:EndReorder(m) end)
    m.header = header

    -- --- Body (contenu du module) ---
    local body = CreateFrame("Frame", nil, frame)
    body:SetPoint("TOPLEFT",  header, "BOTTOMLEFT",  0, 0)
    body:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT", 0, 0)
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
    m._placeholder = ph

    m.frame = frame
    m.body  = body
    SP:UpdateCollapseVisual(m)
end

-- ============================================================
-- Collapse / Options / Disable
-- ============================================================
function SP:UpdateCollapseVisual(m)
    local cfg = SP:GetModuleConfig(m.name)
    if not cfg then return end
    if m.arrow then m.arrow:SetNormalTexture(cfg.collapsed and TEX_PLUS or TEX_MINUS) end
    if m.body then
        if cfg.collapsed then m.body:Hide() else m.body:Show() end
    end
end

function SP:ToggleCollapse(m)
    local cfg = SP:GetModuleConfig(m.name)
    if not cfg then return end
    cfg.collapsed = not cfg.collapsed
    SP:UpdateCollapseVisual(m)
    SP:RebuildLayout()
end

function SP:ToggleOptions(m)
    -- TODO(dev) : panneau d'options inline par module.
    SP:Print(("Options de |cFFFFFFFF%s|r : à venir."):format(m.label))
end

-- ✕ : désactive le module (Disable + masque). Réactivable via /sp enable <Nom>.
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
function SP:RebuildLayout()
    local panel = SP.panel
    if not panel then return end
    local content = panel.content
    local UIc = SP.UI
    local y = 0

    for _, m in ipairs(SP:GetOrderedModules()) do
        local cfg = SP:GetModuleConfig(m.name)
        if cfg and cfg.enabled and m.frame then
            local h = UIc.HEADER_H
            if not cfg.collapsed then
                local bodyH = cfg.height or m.defaultHeight or 100
                if m.body then m.body:SetHeight(bodyH) end
                h = h + bodyH
            end
            m.frame:ClearAllPoints()
            m.frame:SetPoint("TOPLEFT",  content, "TOPLEFT",  0, -y)
            m.frame:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, -y)
            m.frame:SetHeight(h)
            m.frame:Show()
            m._layoutTop, m._layoutHeight = y, h
            y = y + h + UIc.GAP
        elseif m.frame then
            m.frame:Hide()
            m._layoutTop, m._layoutHeight = nil, nil
        end
    end

    if y < 1 then y = 1 end
    content:SetHeight(y)
    panel:SetHeight(y + UIc.TITLE_H)
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
    if not SP._dropLine and SP.panel then
        local ln = SP.panel.content:CreateTexture(nil, "OVERLAY")
        ln:SetColorTexture(0.30, 0.70, 1.0, 0.95)
        ln:SetHeight(2)
        ln:Hide()
        SP._dropLine = ln
    end
end

function SP:BeginReorder(m)
    if SP.db.panel.locked or InCombatLockdown() then return end
    SP:_EnsureDragWidgets()
    SP._dragModule = m
    local g = SP._ghost
    g.label:SetText(m.label)
    g:SetWidth(SP.panel:GetWidth())
    g:Show()
    g:SetScript("OnUpdate", function() SP:UpdateReorder() end)
end

-- Index d'insertion (parmi les modules visibles) selon la position Y du curseur.
-- Utilise content:GetTop() + _layoutTop/_layoutHeight stockés (pas de mesure de frame runtime).
function SP:ComputeDropIndex()
    local content = SP.panel.content
    local top = content:GetTop()
    if not top then return nil end
    local scale = content:GetEffectiveScale()
    local _, cy = GetCursorPosition()
    cy = cy / scale
    local off = top - cy          -- distance vers le bas depuis le haut du contenu
    local vis = SP:GetVisibleOrderedModules()
    for i, m in ipairs(vis) do
        local mt, mh = m._layoutTop, m._layoutHeight or 0
        if mt and off < (mt + mh / 2) then
            return i
        end
    end
    return #vis + 1
end

function SP:ShowDropIndicator(idx)
    local ln = SP._dropLine
    if not ln then return end
    local content = SP.panel.content
    local vis = SP:GetVisibleOrderedModules()
    local yTop
    if idx and vis[idx] and vis[idx]._layoutTop then
        yTop = vis[idx]._layoutTop
    else
        local last = vis[#vis]
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
    SP:ShowDropIndicator(SP:ComputeDropIndex())
end

function SP:EndReorder(m)
    local g = SP._ghost
    if g then g:SetScript("OnUpdate", nil); g:Hide() end
    if SP._dropLine then SP._dropLine:Hide() end

    local dropIdx = SP:ComputeDropIndex()
    SP._dragModule = nil
    if not dropIdx then SP:RebuildLayout(); return end

    local vis = SP:GetVisibleOrderedModules()
    local beforeName = vis[dropIdx] and vis[dropIdx].name or nil

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
