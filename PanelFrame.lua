-- ============================================================
-- PanelFrame.lua — Frame principal (déplaçable, resize en largeur)
-- ============================================================
local ADDON_NAME, SP = ...

-- ------------------------------------------------------------
-- Crée le conteneur principal du panneau. Idempotent.
-- ------------------------------------------------------------
function SP:CreatePanel()
    if SP.panel then return SP.panel end
    local UIc = SP.UI
    local db  = SP.db.panel

    local p = CreateFrame("Frame", "SpherePanelMain", UIParent)
    p:SetSize(db.width or 280, 200)
    p:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", db.x or -20, db.y or -200)
    p:SetClampedToScreen(true)
    p:SetMovable(true)
    p:SetFrameStrata("MEDIUM")

    -- Fond du panneau
    local bg = p:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(p)
    local c = SP.db.panel.bgColor or { r = 0.05, g = 0.05, b = 0.07, a = 0.85 }
    bg:SetColorTexture(c.r, c.g, c.b, c.a)
    p.bg = bg

    -- --- Barre de titre (poignée de déplacement) ---
    local title = CreateFrame("Frame", nil, p)
    title:SetPoint("TOPLEFT", p, "TOPLEFT", 0, 0)
    title:SetPoint("TOPRIGHT", p, "TOPRIGHT", 0, 0)
    title:SetHeight(UIc.TITLE_H)
    title:EnableMouse(true)
    title:RegisterForDrag("LeftButton")
    local tbg = title:CreateTexture(nil, "ARTWORK")
    tbg:SetAllPoints(title)
    tbg:SetColorTexture(0.10, 0.10, 0.15, 0.95)
    -- Orbe lumineux (signature SpherePanel)
    local orb = title:CreateTexture(nil, "OVERLAY")
    orb:SetTexture("Interface\\Cooldown\\ping4")
    orb:SetBlendMode("ADD"); orb:SetVertexColor(0.29, 0.64, 1)
    orb:SetSize(16, 16); orb:SetPoint("LEFT", title, "LEFT", 6, 0)
    p.titleOrb = orb

    local tlabel = title:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    tlabel:SetPoint("LEFT", orb, "RIGHT", 4, 0)
    tlabel:SetText("|cFF4AA3FFSphere|rPanel")

    -- zone d'info à droite du bandeau (horloge / FPS, alimentée par le module Menus)
    local tinfo = title:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    tinfo:SetPoint("RIGHT", title, "RIGHT", -8, 0)
    p.titleInfo = tinfo

    -- icône courrier non lu (visible seulement si du courrier attend)
    local mail = title:CreateTexture(nil, "OVERLAY")
    mail:SetSize(14, 14)
    mail:SetPoint("RIGHT", tinfo, "LEFT", -6, 0)
    if not (pcall(mail.SetAtlas, mail, "auctionhouse-icon-mail", true) and mail:GetAtlas()) then
        mail:SetTexture("Interface\\Icons\\INV_Letter_15")
        mail:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    end
    mail:Hide()
    p.mailIcon = mail
    local mev = CreateFrame("Frame")
    mev:RegisterEvent("UPDATE_PENDING_MAIL")
    mev:RegisterEvent("MAIL_INBOX_UPDATE")
    mev:RegisterEvent("PLAYER_ENTERING_WORLD")
    mev:SetScript("OnEvent", function()
        mail:SetShown(HasNewMail and HasNewMail() or false)
    end)

    -- Ligne d'accent + shimmer animé qui balaie
    local accent = title:CreateTexture(nil, "ARTWORK")
    accent:SetPoint("BOTTOMLEFT", title, "BOTTOMLEFT", 0, 0)
    accent:SetPoint("BOTTOMRIGHT", title, "BOTTOMRIGHT", 0, 0)
    accent:SetHeight(2); accent:SetColorTexture(0.29, 0.64, 1, 0.35)
    local shimmer = title:CreateTexture(nil, "OVERLAY")
    shimmer:SetBlendMode("ADD"); shimmer:SetColorTexture(1, 1, 1, 0.5); shimmer:SetSize(44, 2)
    shimmer:SetPoint("BOTTOMLEFT", title, "BOTTOMLEFT", 0, 0)
    p.titleShimmer = shimmer
    p.title = title

    title:SetScript("OnDragStart", function()
        if SP.db.panel.locked or InCombatLockdown() then return end
        -- en mode magnétisé (1/2), le panneau reste du côté défini : pas de déplacement manuel
        if (SP.db.panel.behavior or 3) ~= 3 then return end
        p._dragging = true
        p:StartMoving()
    end)
    title:SetScript("OnDragStop", function()
        p:StopMovingOrSizing()
        SP:SavePanelPosition()
        C_Timer.After(0.05, function() p._dragging = false end)
    end)
    -- clic gauche = afficher/masquer le module Menus (fusionné) ; clic droit = menu contextuel
    title:SetScript("OnMouseUp", function(_, button)
        if p._dragging then return end
        local m = SP.modulesByName and SP.modulesByName["GameMenu"]
        if not m then return end
        if button == "RightButton" then
            SP:ShowModuleMenu(m)
        elseif button == "LeftButton" then
            local cfg = SP:GetModuleConfig("GameMenu")
            if cfg and cfg.enabled then SP:DisableModuleUI(m) else SP:EnableModule("GameMenu") end
        end
    end)

    -- --- Région de contenu (les modules s'y ancrent, sous le titre) ---
    local content = CreateFrame("Frame", nil, p)
    content:SetPoint("TOPLEFT", p, "TOPLEFT", 0, -UIc.TITLE_H)
    content:SetPoint("TOPRIGHT", p, "TOPRIGHT", 0, -UIc.TITLE_H)
    content:SetHeight(1)
    p.content = content

    -- --- Poignée de redimensionnement (largeur) en bas à gauche ---
    -- Ancrée à gauche : le panneau est ancré TOPRIGHT, on étend donc vers la gauche.
    local sizer = CreateFrame("Button", nil, p)
    sizer:SetSize(16, 16)
    sizer:SetPoint("BOTTOMLEFT", p, "BOTTOMLEFT", 0, 0)
    sizer:EnableMouse(true)
    local stex = sizer:CreateTexture(nil, "OVERLAY")
    stex:SetAllPoints(sizer)
    stex:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    stex:SetTexCoord(1, 0, 0, 1)  -- miroir horizontal (grabber pointant à gauche)
    sizer:SetScript("OnMouseDown", function(self)
        if SP.db.panel.locked or InCombatLockdown() then return end
        local scale = p:GetEffectiveScale()
        self.startCX = (GetCursorPosition()) / scale
        self.startW  = p:GetWidth()
        self:SetScript("OnUpdate", function(s)
            local sc = p:GetEffectiveScale()
            local x  = (GetCursorPosition()) / sc
            local dw = s.startCX - x           -- curseur vers la gauche = largeur ↑
            local w  = math.max(SP.UI.MIN_W, math.min(SP.UI.MAX_W, s.startW + dw))
            p:SetWidth(w)
        end)
    end)
    sizer:SetScript("OnMouseUp", function(self)
        self:SetScript("OnUpdate", nil)
        SP.db.panel.width = math.floor(p:GetWidth() + 0.5)
        SP:OnPanelResized()
    end)
    p.sizer = sizer

    SP:_InitPanelController(p)
    SP.panel = p
    return p
end

-- ------------------------------------------------------------
-- Auto-fade PAR MODULE : chaque module s'estompe individuellement après inactivité.
-- Survol d'un module → seul celui-ci réapparaît. Modules épinglés/exclus restent opaques.
-- Transition fluide (lerp chaque frame). alpha 0 = transparence totale (toujours cliquable).
-- ------------------------------------------------------------
local function lerp(cur, goal, elapsed, dur)
    local step = elapsed / math.max(0.05, dur or 0.35)
    local a = cur + (goal - cur) * math.min(1, step)
    if math.abs(a - goal) < 0.005 then a = goal end
    return a
end

-- Couleurs de glow par module (comportement 2).
local GLOW_COLORS = {
    { 0.95, 0.3, 0.3 }, { 0.3, 0.7, 0.95 }, { 0.4, 0.9, 0.4 }, { 0.95, 0.8, 0.3 },
    { 0.8, 0.4, 0.95 }, { 0.3, 0.9, 0.85 }, { 0.95, 0.55, 0.25 }, { 0.6, 0.6, 0.95 }, { 0.9, 0.5, 0.7 },
}

-- ===== Comportement 3 : libre + auto-fade alpha par module (option) =====
function SP:_TickFree(p, elapsed)
    local af = SP.db and SP.db.panel and SP.db.panel.autofade
    local now = GetTime()
    if not af or not af.enabled then
        if p.bg:GetAlpha() ~= 1 then p.bg:SetAlpha(1) end
        p.title:SetAlpha(1)
        for _, m in ipairs(SP.modules) do if m.frame and m.frame:GetAlpha() ~= 1 then m.frame:SetAlpha(1) end end
        return
    end
    local target, delay, dur, apply = af.alpha or 0.25, af.delay or 5, af.fadeDuration or 0.35, af.apply
    if p:IsMouseOver() then p._panelActive = now end
    local pg = ((now - (p._panelActive or 0)) > delay) and target or 1
    p.title:SetAlpha(lerp(p.title:GetAlpha(), pg, elapsed, dur))
    p.bg:SetAlpha(lerp(p.bg:GetAlpha(), pg, elapsed, dur))
    for _, m in ipairs(SP.modules) do
        local f = m.frame
        if f and f:IsShown() and not m._onPanel2 then
            local cfg = SP:GetModuleConfig(m.name)
            local goal
            if m._forceReveal or (cfg and cfg.pinned) or (apply and apply[m.name] == false) then goal = 1
            else
                if f:IsMouseOver() then p._mActive[m.name] = now end
                goal = ((now - (p._mActive[m.name] or 0)) > delay) and target or 1
            end
            local cur = f:GetAlpha()
            if cur ~= goal then f:SetAlpha(lerp(cur, goal, elapsed, dur)) end
        end
    end
end

-- ===== Comportements 1/2 : glissement sur le côté (générique, panneau ① ou ②) =====
function SP:_TickSlide(p, elapsed, b, side, isP2)
    b = b or SP.db.panel.behavior
    side = side or SP.db.panel.side or "right"
    local dir = (side == "left") and -1 or 1
    local hidden = ((p:GetWidth() or 280) + 40) * dir
    local af = SP.db.panel.autofade or {}
    local delay, dur = af.delay or 5, af.fadeDuration or 0.35
    local now = GetTime()

    local revealAll
    if b == 1 then
        if p:IsMouseOver() or (p.edge and p.edge:IsMouseOver()) then p._panelActive = now end
        revealAll = (now - (p._panelActive or 0)) <= delay
    end

    local anyRevealed = false
    p._mActive = p._mActive or {}
    local wantP2 = isP2 and true or false
    for _, m in ipairs(SP.modules) do
        local f = m.frame
        if f and f:IsShown() and m._layoutTop and ((m._onPanel2 and true or false) == wantP2) then
            local cfg = SP:GetModuleConfig(m.name)
            local reveal
            if m._forceReveal or (cfg and cfg.pinned) then reveal = true
            elseif b == 1 then reveal = revealAll
            else
                if f:IsMouseOver() or m._glowHover then p._mActive[m.name] = now end
                reveal = (now - (p._mActive[m.name] or 0)) <= delay
            end
            if reveal then anyRevealed = true end
            local goal = reveal and 0 or hidden
            local cur = lerp(m._curSlide or 0, goal, elapsed, dur)
            if math.abs(cur - goal) < 0.5 then cur = goal end
            m._curSlide = cur
            if not (InCombatLockdown() and m.secureChildren) then
                f:ClearAllPoints()
                f:SetPoint("TOPLEFT", p.content, "TOPLEFT", cur, -m._layoutTop)
                f:SetPoint("TOPRIGHT", p.content, "TOPRIGHT", cur, -m._layoutTop)
            end
        end
    end

    local bgGoal = anyRevealed and 1 or 0
    local tGoal  = anyRevealed and 1 or 0
    p.bg:SetAlpha(lerp(p.bg:GetAlpha(), bgGoal, elapsed, dur))
    p.title:SetAlpha(lerp(p.title:GetAlpha(), tGoal, elapsed, dur))

    if b == 2 then SP:_UpdateEdgeGlows(p, side, isP2) else SP:_HideEdgeGlows(p) end
end

function SP:_HideEdgeGlows(p)
    if p.edge and p.edge.glows then for _, g in ipairs(p.edge.glows) do g:Hide() end end
end

function SP:_UpdateEdgeGlows(p, side, isP2)
    local edge = p.edge
    if not edge then return end
    local uh = UIParent:GetTop()
    local leftSide = (side or SP.db.panel.side or "right") == "left"
    local wantP2 = isP2 and true or false
    local i = 0
    for _, m in ipairs(SP.modules) do
        local f = m.frame
        if f and f:IsShown() and m._layoutTop and ((m._onPanel2 and true or false) == wantP2) then
            local cfg = SP:GetModuleConfig(m.name)
            local slidOff = (math.abs(m._curSlide or 0) > 4) and not (cfg and cfg.pinned)
            i = i + 1
            local g = edge.glows[i]
            if not g then
                g = CreateFrame("Frame", nil, edge)
                g:EnableMouse(true)
                g.tex = g:CreateTexture(nil, "OVERLAY"); g.tex:SetAllPoints(g)
                g:SetScript("OnEnter", function(s) if s._m then s._m._glowHover = true end end)
                g:SetScript("OnLeave", function(s) if s._m then s._m._glowHover = false end end)
                edge.glows[i] = g
            end
            g._m = m
            -- bordure = couleur PERSONNALISÉE du module si définie, sinon palette générique
            local c = GLOW_COLORS[((i - 1) % #GLOW_COLORS) + 1]
            local app = SP.GetModuleAppearanceConfig and SP:GetModuleAppearanceConfig(m.name)
            local bc = app and app.bgColor
            local def = (SP.db.panel.moduleAppearance and SP.db.panel.moduleAppearance.bgColor) or { r = 0.12, g = 0.15, b = 0.20 }
            if bc and (math.abs((bc.r or 0) - def.r) > 0.02 or math.abs((bc.g or 0) - def.g) > 0.02 or math.abs((bc.b or 0) - def.b) > 0.02) then
                c = { bc.r, bc.g, bc.b }
            end
            g.tex:SetColorTexture(c[1], c[2], c[3], 0.9)
            local top = f:GetTop()
            if top and uh and slidOff then
                g:ClearAllPoints()
                g:SetWidth(6); g:SetHeight(f:GetHeight() or 20)
                g:SetPoint(leftSide and "LEFT" or "RIGHT", edge, leftSide and "LEFT" or "RIGHT", 0, 0)
                g:SetPoint("TOP", edge, "TOP", 0, -(uh - top))
                g:Show()
            else
                g:Hide()
            end
        end
    end
    for j = i + 1, #edge.glows do edge.glows[j]:Hide() end
end

function SP:_ResetSlides(p, isP2)
    local wantP2 = isP2 and true or false
    for _, m in ipairs(SP.modules) do
        if m.frame and m._layoutTop and ((m._onPanel2 and true or false) == wantP2) then
            m._curSlide = 0
            if not (InCombatLockdown() and m.secureChildren) then
                m.frame:ClearAllPoints()
                m.frame:SetPoint("TOPLEFT", p.content, "TOPLEFT", 0, -m._layoutTop)
                m.frame:SetPoint("TOPRIGHT", p.content, "TOPRIGHT", 0, -m._layoutTop)
            end
        end
    end
    p.bg:SetAlpha(1); p.title:SetAlpha(1)
    SP:_HideEdgeGlows(p)
end

-- Effets visuels de la barre de titre (orbe pulsant + shimmer balayant).
function SP:_TickCosmetics(p, elapsed)
    local fx = SP.db and SP.db.panel and SP.db.panel.fx
    if not fx then
        if p.titleOrb then p.titleOrb:SetAlpha(0) end
        if p.titleShimmer then p.titleShimmer:Hide() end
        return
    end
    local now = GetTime()
    if p.titleOrb then p.titleOrb:SetAlpha(0.45 + 0.40 * (math.sin(now * 2.2) * 0.5 + 0.5)) end
    if p.titleShimmer and p.title then
        p.titleShimmer:Show()
        local w = (p.title:GetWidth() or 200) - 44
        local t = (now * 0.30) % 1
        p.titleShimmer:ClearAllPoints()
        p.titleShimmer:SetPoint("BOTTOMLEFT", p.title, "BOTTOMLEFT", t * w, 0)
        p.titleShimmer:SetAlpha(0.30 + 0.35 * (math.sin(now * 4) * 0.5 + 0.5))
    end
end

function SP:_PanelTick(p, elapsed)
    SP:_TickCosmetics(p, elapsed)
    local b = (SP.db and SP.db.panel and SP.db.panel.behavior) or 3
    if b == 1 or b == 2 then SP:_TickSlide(p, elapsed, b, SP.db.panel.side, false)
    else SP:_TickFree(p, elapsed) end

    -- panneau ② : son propre mode (libre / glissant / individuel)
    local p2 = SP.panel2
    local p2cfg = SP.db.panel.panel2
    if p2 and p2:IsShown() and p2cfg and p2cfg.enabled then
        local b2 = p2cfg.behavior or 3
        if b2 == 1 or b2 == 2 then
            p2._resetDone = false
            SP:_TickSlide(p2, elapsed, b2, SP._p2side or "left", true)
        elseif not p2._resetDone then
            SP:_ResetSlides(p2, true)
            p2._resetDone = true
        end
    end
end

function SP:_InitPanelController(p)
    p._mActive = {}
    p._panelActive = GetTime()
    local edge = CreateFrame("Frame", "SpherePanelEdge", UIParent)
    edge:SetWidth(10); edge:EnableMouse(true); edge:SetFrameStrata("HIGH"); edge:Hide()
    edge.glows = {}
    p.edge = edge
    p:SetScript("OnUpdate", function(self, e) SP:_PanelTick(self, e) end)
end

-- Applique le comportement choisi (ancrage côté, bord déclencheur). Appelé au login + à chaque changement.
function SP:ApplyPanelBehavior()
    local p = SP.panel
    if not p then return end
    local b = SP.db.panel.behavior or 3
    local side = SP.db.panel.side or "right"
    if b == 1 or b == 2 then
        -- aimante le panneau au bord choisi, ancré en haut ou en bas (vpos)
        local x = math.abs(SP.db.panel.x or 20)
        local vpos = SP.db.panel.vpos or "top"
        p:ClearAllPoints()
        if vpos == "bottom" then
            if side == "left" then p:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x, 4)
            else p:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -x, 4) end
        else
            if side == "left" then p:SetPoint("TOPLEFT", UIParent, "TOPLEFT", x, -4)
            else p:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -x, -4) end
        end
    end
    if p.edge then
        p.edge:ClearAllPoints()
        if side == "left" then
            p.edge:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 0); p.edge:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 0, 0)
        else
            p.edge:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", 0, 0); p.edge:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", 0, 0)
        end
        p.edge:SetShown(b == 1 or b == 2)
    end
    if b == 3 then SP:_ResetSlides(p) else p._panelActive = 0 end  -- 1/2 : démarre réduit
    -- le panneau ② suit : toujours du côté opposé au principal
    if SP.db.panel.panel2 and SP.db.panel.panel2.enabled then SP:ApplyPanel2() end
end

-- ------------------------------------------------------------
-- Sauvegarde la position (offsets relatifs à UIParent TOPRIGHT).
-- GetRight/GetTop sont OK ici (frame non liée à une nameplate → pas de restriction).
-- ------------------------------------------------------------
function SP:SavePanelPosition()
    local p = SP.panel
    if not p then return end
    local right, top = p:GetRight(), p:GetTop()
    local uw, uh = UIParent:GetRight(), UIParent:GetTop()
    if not (right and top and uw and uh) then return end
    SP.db.panel.x = right - uw   -- négatif
    SP.db.panel.y = top - uh     -- négatif
    p:ClearAllPoints()
    p:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", SP.db.panel.x, SP.db.panel.y)
end

-- Réinitialise position + largeur aux valeurs par défaut.
function SP:ResetPanel()
    local d = SP.defaults.panel
    SP.db.panel.x, SP.db.panel.y, SP.db.panel.width = d.x, d.y, d.width
    local p = SP.panel
    if not p then return end
    p:ClearAllPoints()
    p:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", d.x, d.y)
    p:SetWidth(d.width)
    SP:OnPanelResized()
end

-- Verrouille / déverrouille le déplacement et le resize.
function SP:SetPanelLocked(locked)
    SP.db.panel.locked = locked and true or false
end

-- Applique l'apparence (couleur + transparence du fond). Appelé au login + à chaque changement.
function SP:ApplyAppearance()
    local c = SP.db.panel.bgColor or { r = 0.05, g = 0.05, b = 0.07, a = 0.85 }
    if SP.panel then SP.panel.bg:SetColorTexture(c.r, c.g, c.b, c.a) end
    if SP.panel2 then SP.panel2.bg:SetColorTexture(c.r, c.g, c.b, c.a) end
    if SP.ApplyAllModuleAppearance then SP:ApplyAllModuleAppearance() end
end

-- ------------------------------------------------------------
-- Second panneau (option) : libre, déplaçable, reçoit les modules par drag-and-drop.
-- ------------------------------------------------------------
function SP:CreatePanel2()
    if SP.panel2 then return SP.panel2 end
    local db = SP.db.panel.panel2
    local p = CreateFrame("Frame", "SpherePanelSecond", UIParent)
    p:SetSize(db.width or 280, 200)
    p:SetPoint("TOPLEFT", UIParent, "TOPLEFT", db.x or 20, db.y or -200)
    p:SetClampedToScreen(true)
    p:SetMovable(true)
    p:SetFrameStrata("MEDIUM")

    local bg = p:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(p)
    local c = SP.db.panel.bgColor or { r = 0.05, g = 0.05, b = 0.07, a = 0.85 }
    bg:SetColorTexture(c.r, c.g, c.b, c.a)
    p.bg = bg

    local title = CreateFrame("Frame", nil, p)
    title:SetPoint("TOPLEFT"); title:SetPoint("TOPRIGHT"); title:SetHeight(SP.UI.TITLE_H)
    title:EnableMouse(true); title:RegisterForDrag("LeftButton")
    local tbg = title:CreateTexture(nil, "ARTWORK"); tbg:SetAllPoints(title); tbg:SetColorTexture(0.10, 0.10, 0.15, 0.95)
    local tl = title:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    tl:SetPoint("LEFT", title, "LEFT", 8, 0); tl:SetText("|cFF4AA3FFSphere|rPanel |cFF888888②|r")
    title:SetScript("OnDragStart", function() if not InCombatLockdown() then p:StartMoving() end end)
    title:SetScript("OnDragStop", function()
        p:StopMovingOrSizing()
        local l, t = p:GetLeft(), p:GetTop()
        local ut = UIParent:GetTop()
        if l and t and ut then db.x, db.y = l, t - ut end
        p:ClearAllPoints()
        p:SetPoint("TOPLEFT", UIParent, "TOPLEFT", db.x, db.y)
    end)
    p.title = title

    local content = CreateFrame("Frame", nil, p)
    content:SetPoint("TOPLEFT", p, "TOPLEFT", 0, -SP.UI.TITLE_H)
    content:SetPoint("TOPRIGHT", p, "TOPRIGHT", 0, -SP.UI.TITLE_H)
    content:SetHeight(1)
    p.content = content

    -- zone de dépôt visible quand le panneau est vide
    local hint = content:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    hint:SetPoint("TOP", content, "TOP", 0, -28)
    hint:SetText("|cFF777777Déposez des modules ici\n(glissez leur bandeau)|r")
    p.emptyHint = hint

    -- bord déclencheur (modes 1/2 du panneau ②)
    local edge = CreateFrame("Frame", "SpherePanelEdge2", UIParent)
    edge:SetWidth(10); edge:EnableMouse(true); edge:SetFrameStrata("HIGH"); edge:Hide()
    edge.glows = {}
    p.edge = edge
    p._mActive = {}

    SP.panel2 = p
    return p
end

-- Active/désactive le second panneau (option Comportement).
-- Position automatique : TOUJOURS du côté opposé au panneau principal
-- (principal à droite → ② à gauche, et inversement), même ancrage haut/bas.
function SP:ApplyPanel2()
    local en = SP.db.panel.panel2 and SP.db.panel.panel2.enabled
    if en then
        local p2 = SP:CreatePanel2()
        local p2cfg = SP.db.panel.panel2
        local mainSide = SP.db.panel.side or "right"
        -- côté du ② : "auto" = opposé au principal, sinon choix explicite
        local side2 = p2cfg.side or "auto"
        if side2 == "auto" then side2 = (mainSide == "right") and "left" or "right" end
        local vpos = p2cfg.vpos or "top"
        local x = 4
        SP._p2side = side2
        p2:ClearAllPoints()
        if side2 == "left" then
            if vpos == "bottom" then p2:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x, 4)
            else p2:SetPoint("TOPLEFT", UIParent, "TOPLEFT", x, -4) end
        else
            if vpos == "bottom" then p2:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -x, 4)
            else p2:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -x, -4) end
        end
        -- bord déclencheur du ② : positionné sur SON côté, actif en modes 1/2
        local b2 = p2cfg.behavior or 3
        if p2.edge then
            p2.edge:ClearAllPoints()
            if side2 == "left" then
                p2.edge:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 0)
                p2.edge:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 0, 0)
            else
                p2.edge:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", 0, 0)
                p2.edge:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", 0, 0)
            end
            p2.edge:SetShown(b2 == 1 or b2 == 2)
        end
        p2._panelActive = 0
        p2._resetDone = false
        p2:Show()
    elseif SP.panel2 then
        -- rapatrie les modules du panneau 2 vers le 1
        for _, m in ipairs(SP.modules) do
            local cfg = SP:GetModuleConfig(m.name)
            if cfg and cfg.panel == 2 then cfg.panel = 1 end
        end
        SP.panel2:Hide()
    end
    SP:RebuildLayout()
end

-- Largeur changée : propager aux modules (les ancres LEFT/RIGHT gèrent déjà la largeur,
-- OnResize permet aux modules de recalculer leur layout interne).
function SP:OnPanelResized()
    local w = SP.panel and SP.panel:GetWidth() or (SP.db.panel.width or 280)
    for _, m in ipairs(SP.modules) do
        if m.frame and m.OnResize then
            pcall(m.OnResize, m, w, m._layoutHeight or 0)
        end
    end
    SP:RebuildLayout()
end
