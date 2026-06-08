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
    bg:SetColorTexture(0.05, 0.05, 0.07, 0.85)
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
    local tlabel = title:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    tlabel:SetPoint("LEFT", title, "LEFT", 8, 0)
    tlabel:SetText("|cFF4AA3FFSphere|rPanel")
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

    SP.panel = p
    return p
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
