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
        p:StartMoving()
    end)
    title:SetScript("OnDragStop", function()
        p:StopMovingOrSizing()
        SP:SavePanelPosition()
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
        if f and f:IsShown() then
            local cfg = SP:GetModuleConfig(m.name)
            local goal
            if (cfg and cfg.pinned) or (apply and apply[m.name] == false) then goal = 1
            else
                if f:IsMouseOver() then p._mActive[m.name] = now end
                goal = ((now - (p._mActive[m.name] or 0)) > delay) and target or 1
            end
            local cur = f:GetAlpha()
            if cur ~= goal then f:SetAlpha(lerp(cur, goal, elapsed, dur)) end
        end
    end
end

-- ===== Comportements 1/2 : glissement sur le côté =====
function SP:_TickSlide(p, elapsed)
    local b = SP.db.panel.behavior
    local side = SP.db.panel.side or "right"
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
    for _, m in ipairs(SP.modules) do
        local f = m.frame
        if f and f:IsShown() and m._layoutTop then
            local cfg = SP:GetModuleConfig(m.name)
            local reveal
            if cfg and cfg.pinned then reveal = true
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
            f:ClearAllPoints()
            f:SetPoint("TOPLEFT", p.content, "TOPLEFT", cur, -m._layoutTop)
            f:SetPoint("TOPRIGHT", p.content, "TOPRIGHT", cur, -m._layoutTop)
        end
    end

    local bgGoal = anyRevealed and 1 or 0
    local tGoal  = anyRevealed and 1 or 0
    p.bg:SetAlpha(lerp(p.bg:GetAlpha(), bgGoal, elapsed, dur))
    p.title:SetAlpha(lerp(p.title:GetAlpha(), tGoal, elapsed, dur))

    if b == 2 then SP:_UpdateEdgeGlows(p) else SP:_HideEdgeGlows(p) end
end

function SP:_HideEdgeGlows(p)
    if p.edge and p.edge.glows then for _, g in ipairs(p.edge.glows) do g:Hide() end end
end

function SP:_UpdateEdgeGlows(p)
    local edge = p.edge
    local uh = UIParent:GetTop()
    local leftSide = (SP.db.panel.side or "right") == "left"
    local i = 0
    for _, m in ipairs(SP.modules) do
        local f = m.frame
        if f and f:IsShown() and m._layoutTop then
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
            local c = GLOW_COLORS[((i - 1) % #GLOW_COLORS) + 1]
            g.tex:SetColorTexture(c[1], c[2], c[3], 0.85)
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

function SP:_ResetSlides(p)
    for _, m in ipairs(SP.modules) do
        if m.frame and m._layoutTop then
            m._curSlide = 0
            m.frame:ClearAllPoints()
            m.frame:SetPoint("TOPLEFT", p.content, "TOPLEFT", 0, -m._layoutTop)
            m.frame:SetPoint("TOPRIGHT", p.content, "TOPRIGHT", 0, -m._layoutTop)
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
    if b == 1 or b == 2 then SP:_TickSlide(p, elapsed) else SP:_TickFree(p, elapsed) end
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
        -- aimante le panneau au bord choisi
        local y = SP.db.panel.y or -200
        p:ClearAllPoints()
        if side == "left" then
            p:SetPoint("TOPLEFT", UIParent, "TOPLEFT", math.abs(SP.db.panel.x or 20), y)
        else
            p:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -math.abs(SP.db.panel.x or 20), y)
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
    if not SP.panel then return end
    local c = SP.db.panel.bgColor or { r = 0.05, g = 0.05, b = 0.07, a = 0.85 }
    SP.panel.bg:SetColorTexture(c.r, c.g, c.b, c.a)
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
