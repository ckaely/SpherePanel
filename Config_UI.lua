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

local function ClampValue(v, minV, maxV)
    v = tonumber(v) or minV
    if v < minV then return minV end
    if v > maxV then return maxV end
    return v
end

-- helpers partagés (définis plus bas, forward-declarés pour être utilisables partout)
local MakeScrollPage, MakeRadioRow, SectionHeader, MakeTabbedPage
local FONT_CHOICES = {
    { "Inter-Regular.ttf", "Inter Regular" },
    { "ExpresswayRegular.ttf", "Expressway Regular" },
    { "Roboto-Regular.ttf", "Roboto Regular" },
    { "NotoSans-Regular.ttf", "NotoSans Regular" },
    { "BarlowCondensed-Regular.ttf", "BarlowCondensed Regular" },
    { "frizqt__.ttf", "FrizQT" },
    { "Accidental Presidency.ttf", "Accidental Presidency" },
    { "Adventure.ttf", "Adventure" },
    { "AFPEPSI_.TTF", "AF Pepsi" },
    { "alphapixels.ttf", "Alpha Pixels" },
    { "Alte.ttf", "Alte" },
    { "AlteHaasGroteskBold.ttf", "Alte Haas Grotesk Bold" },
    { "ARIALN.ttf", "Arial Narrow" },
    { "ariblk.ttf", "Arial Black" },
    { "Arimo.ttf", "Arimo" },
    { "Audiowide-Regular.ttf", "Audiowide Regular" },
    { "Augustus Beveled.ttf", "Augustus Beveled" },
    { "AUGUSTUS.TTF", "Augustus" },
    { "BarlowCondensed-Bold.ttf", "BarlowCondensed Bold" },
    { "BarlowCondensed-Medium.ttf", "BarlowCondensed Medium" },
    { "BarlowCondensed-SemiBold.ttf", "BarlowCondensed SemiBold" },
    { "Bazooka.ttf", "Bazooka" },
    { "BebasNeue-Regular.ttf", "BebasNeue Regular" },
    { "BlackChancery.ttf", "Black Chancery" },
    { "Bungee.ttf", "Bungee" },
    { "CAESAR.TTF", "Caesar" },
    { "CapitalisTypOasis.ttf", "Capitalis TypOasis" },
    { "CasualMemoriesBold.ttf", "Casual Memories Bold" },
    { "CelestiaMediumRedux1.55.ttf", "Celestia Medium Redux" },
    { "Cleopatra.ttf", "Cleopatra" },
    { "Comfortaa-Bold.ttf", "Comfortaa Bold" },
    { "Comfortaa-Light.ttf", "Comfortaa Light" },
    { "Comfortaa-Regular.ttf", "Comfortaa Regular" },
    { "Dajova.ttf", "Dajova" },
    { "DejaVuLGCSans.ttf", "DejaVu LGC Sans" },
    { "DejaVuLGCSerif.ttf", "DejaVu LGC Serif" },
    { "Designosaur-Italic.ttf", "Designosaur Italic" },
    { "Designosaur-Regular.ttf", "Designosaur Regular" },
    { "DIOGENES.ttf", "Diogenes" },
    { "DorisPP.ttf", "Doris PP" },
    { "Embossed Germanica.ttf", "Embossed Germanica" },
    { "EnigmaU_2.TTF", "Enigma U2" },
    { "Exo2-BlackItalic.ttf", "Exo2 Black Italic" },
    { "Exo2-Regular.ttf", "Exo2 Regular" },
    { "ExocetBlizzardLight.ttf", "Exocet Blizzard Light" },
    { "ExocetBlizzardMedium.ttf", "Exocet Blizzard Medium" },
    { "Expressway.TTF", "Expressway" },
    { "ExpresswayMonoNum.ttf", "Expressway Mono Num" },
    { "FiraSansMedium.ttf", "Fira Sans Medium" },
    { "Fitzgerald.ttf", "Fitzgerald" },
    { "Fluted Germanica.ttf", "Fluted Germanica" },
    { "FORCED SQUARE.ttf", "Forced Square" },
    { "Fremont-Regular.ttf", "Fremont Regular" },
    { "frizqt___cyr.ttf", "FrizQT Cyrillic" },
    { "geek.ttf", "Geek" },
    { "GentiumPlus-Regular.ttf", "Gentium Plus Regular" },
    { "Hack-Regular.ttf", "Hack Regular" },
    { "HARRYP__.TTF", "Harry P" },
    { "headlines.ttf", "Headlines" },
    { "headlines_old.ttf", "Headlines Old" },
    { "HookedUp.ttf", "Hooked Up" },
    { "IBMPlexSans_Condensed-Bold.ttf", "IBM Plex Sans Condensed Bold" },
    { "IBMPlexSans-Regular.ttf", "IBM Plex Sans Regular" },
    { "IBMPlexSans-VariableFont_wdth,wght.ttf", "IBM Plex Sans Variable" },
    { "Impact Label Reversed.ttf", "Impact Label Reversed" },
    { "Impact Label.ttf", "Impact Label" },
    { "Inter_28pt-Regular.ttf", "Inter 28pt Regular" },
    { "Inter_28pt-SemiBold.ttf", "Inter 28pt SemiBold" },
    { "Inter-Bold.ttf", "Inter Bold" },
    { "Inter-SemiBold.ttf", "Inter SemiBold" },
    { "Inter-UI-Black.ttf", "Inter UI Black" },
    { "Inter-UI-Bold.ttf", "Inter UI Bold" },
    { "Inter-UI-Medium.ttf", "Inter UI Medium" },
    { "Inter-UI-Regular.ttf", "Inter UI Regular" },
    { "Junicode.ttf", "Junicode" },
    { "King Arthur Legend.ttf", "King Arthur Legend" },
    { "Lato-Bold.ttf", "Lato Bold" },
    { "Lato-Regular.ttf", "Lato Regular" },
    { "Lemon-Regular.ttf", "Lemon Regular" },
    { "LiberationMono-Regular.ttf", "Liberation Mono Regular" },
    { "LiberationSans-Regular.ttf", "Liberation Sans Regular" },
    { "LiberationSerif-Regular.ttf", "Liberation Serif Regular" },
    { "mara2v2.ttf", "Mara 2v2" },
    { "menomonia.ttf", "Menomonia" },
    { "menomonia_old.ttf", "Menomonia Old" },
    { "menomonia-italic.ttf", "Menomonia Italic" },
    { "Montserrat-Bold.ttf", "Montserrat Bold" },
    { "Montserrat-Italic.ttf", "Montserrat Italic" },
    { "Montserrat-Medium.ttf", "Montserrat Medium" },
    { "Montserrat-Regular.ttf", "Montserrat Regular" },
    { "Montserrat-SemiBold.ttf", "Montserrat SemiBold" },
    { "Nexa-Heavy.ttf", "Nexa Heavy" },
    { "NotoSans-Bold.ttf", "NotoSans Bold" },
    { "NotoSans-Medium.ttf", "NotoSans Medium" },
    { "NotoSans-SemiBold.ttf", "NotoSans SemiBold" },
    { "Nueva Std Cond.ttf", "Nueva Std Cond" },
    { "OldeEnglish.ttf", "Olde English" },
    { "OpenSans-Bold.ttf", "OpenSans Bold" },
    { "OpenSans-BoldItalic.ttf", "OpenSans Bold Italic" },
    { "OpenSans-SemiBold.ttf", "OpenSans SemiBold" },
    { "OpenSans-SemiBoldItalic.ttf", "OpenSans SemiBold Italic" },
    { "Orbitron-Regular.ttf", "Orbitron Regular" },
    { "Orbitron-VariableFont_wght.ttf", "Orbitron Variable" },
    { "Oswald-Bold.ttf", "Oswald Bold" },
    { "Oswald-Light.ttf", "Oswald Light" },
    { "Oswald-Regular.ttf", "Oswald Regular" },
    { "Plain Germanica.ttf", "Plain Germanica" },
    { "PTSansNarrow-Bold.ttf", "PT Sans Narrow Bold" },
    { "PTSansNarrow-Regular.ttf", "PT Sans Narrow Regular" },
    { "RobotoCondensed-Regular.ttf", "Roboto Condensed Regular" },
    { "Roboto-Medium.ttf", "Roboto Medium" },
    { "Roman SD.ttf", "Roman SD" },
    { "Romanum Est.ttf", "Romanum Est" },
    { "rotund.ttf", "Rotund" },
    { "rotundo.ttf", "Rotundo" },
    { "SFAtarianSystem.ttf", "SF Atarian System" },
    { "SFCovington.ttf", "SF Covington" },
    { "SFMoviePoster-Bold.ttf", "SF Movie Poster Bold" },
    { "SFWonderComic.ttf", "SF Wonder Comic" },
    { "Shadowed Germanica.ttf", "Shadowed Germanica" },
    { "Share.ttf", "Share" },
    { "Share-Bold.ttf", "Share Bold" },
    { "Share-Italic.ttf", "Share Italic" },
    { "ShareTech.ttf", "Share Tech" },
    { "SimplySans-Bold.ttf", "Simply Sans Bold" },
    { "SimplySans-Book.ttf", "Simply Sans Book" },
    { "skurri.ttf", "Skurri" },
    { "SourceSans3-Medium.ttf", "Source Sans 3 Medium" },
    { "SourceSans3-Regular.ttf", "Source Sans 3 Regular" },
    { "SourceSansPro-Bold.ttf", "Source Sans Pro Bold" },
    { "SourceSansPro-Regular.ttf", "Source Sans Pro Regular" },
    { "SourceSansPro-Semibold.ttf", "Source Sans Pro Semibold" },
    { "SWF!T___.TTF", "Swift" },
    { "TaurusNormal.ttf", "Taurus Normal" },
    { "Teko.ttf", "Teko" },
    { "Teko-Bold.ttf", "Teko Bold" },
    { "TelluralAlt.ttf", "Tellural Alt" },
    { "TitanOne-Regular.ttf", "Titan One Regular" },
    { "TrajanPro3SemiBold.ttf", "Trajan Pro SemiBold" },
    { "TrashHand.TTF", "Trash Hand" },
    { "trebuchet_ms.ttf", "Trebuchet MS" },
    { "Triatlhon In.ttf", "Triatlhon In" },
    { "Ubuntu-Bold.ttf", "Ubuntu Bold" },
    { "UbuntuMedium.ttf", "Ubuntu Medium" },
    { "Ubuntu-Medium.ttf", "Ubuntu Medium Alt" },
    { "YanoneKaffeesatz-Bold.ttf", "Yanone Kaffeesatz Bold" },
    { "yellow.ttf", "Yellow" },
}
local FONT_FLAG_CHOICES = {
    { "", "Normal" },
    { "OUTLINE", "Outline" },
    { "THICKOUTLINE", "Thick outline" },
    { "MONOCHROME", "Monochrome" },
    { "MONOCHROME,OUTLINE", "Monochrome + outline" },
    { "MONOCHROME,THICKOUTLINE", "Monochrome + thick" },
}
local RAID_BAR_CHOICES = {
    { "bar_serenity.tga", "Serenity" }, { "r10.tga", "R10" }, { "r11.tga", "R11" },
    { "r12.tga", "R12" }, { "k30.tga", "K30" }, { "np_castBar.tga", "CastBar" },
}
local SNP_MEDIA = "Interface\\AddOns\\SphereNameplates\\media\\"
local SNP_FONT_DIR = SNP_MEDIA .. "fonts\\"
local SNP_RAID_BAR_DIR = SNP_MEDIA .. "bar_raid\\"

local function FontPath(face)
    face = face or "Inter-Regular.ttf"
    if face:find("[/\\]") then return face end
    return SNP_FONT_DIR .. face
end

local function RaidBarPath(tex)
    tex = tex or "bar_serenity.tga"
    if tex:find("[/\\]") then return tex end
    return SNP_RAID_BAR_DIR .. tex
end

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
local function MakeSlider(parent, label, x, y, minV, maxV, step, getf, setf, fmt, width)
    sliderCount = sliderCount + 1
    local s = CreateFrame("Slider", "SpherePanelCfgSlider" .. sliderCount, parent)
    s:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    s:SetSize(width or 220, 26)
    if s.SetOrientation then s:SetOrientation("HORIZONTAL") end
    s:SetMinMaxValues(minV, maxV); s:SetValueStep(step)
    if s.SetObeyStepOnDrag then s:SetObeyStepOnDrag(true) end
    s.label = s:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    s.label:SetPoint("BOTTOMLEFT", s, "TOPLEFT", 0, -2)
    s.label:SetPoint("BOTTOMRIGHT", s, "TOPRIGHT", 0, -2)
    s.label:SetJustifyH("CENTER")
    s.track = s:CreateTexture(nil, "BACKGROUND")
    s.track:SetPoint("LEFT", s, "LEFT", 0, -2)
    s.track:SetPoint("RIGHT", s, "RIGHT", 0, -2)
    s.track:SetHeight(7)
    s.track:SetColorTexture(0.05, 0.06, 0.09, 0.95)
    s.fill = s:CreateTexture(nil, "ARTWORK")
    s.fill:SetPoint("LEFT", s.track, "LEFT", 0, 0)
    s.fill:SetHeight(5)
    s.fill:SetColorTexture(0.29, 0.64, 1.0, 0.75)
    local thumb = s:CreateTexture(nil, "OVERLAY")
    thumb:SetSize(6, 14)
    thumb:SetColorTexture(0.86, 0.90, 1.0, 0.95)
    s:SetThumbTexture(thumb)
    local function refresh(v)
        if s.label then s.label:SetText(label .. " : " .. (fmt and fmt(v) or v)) end
        local lo, hi = s:GetMinMaxValues()
        local frac = (hi > lo) and ((tonumber(v) or lo) - lo) / (hi - lo) or 0
        s.fill:SetWidth(math.max(1, (s:GetWidth() or (width or 220)) * math.max(0, math.min(1, frac))))
    end
    local initial = tonumber(getf()) or minV
    s:SetValue(initial); refresh(initial)
    s:SetScript("OnValueChanged", function(_, v)
        if step >= 1 then v = math.floor(v + 0.5) end
        setf(v); refresh(v)
    end)
    return s
end

local function MakeModernButton(parent, text, w, h)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(w or 120, h or 22)
    b.bg = b:CreateTexture(nil, "BACKGROUND")
    b.bg:SetAllPoints(b)
    b.bg:SetColorTexture(0.07, 0.08, 0.12, 0.92)
    b.glass = b:CreateTexture(nil, "ARTWORK")
    b.glass:SetPoint("TOPLEFT", b, "TOPLEFT", 1, -1)
    b.glass:SetPoint("TOPRIGHT", b, "TOPRIGHT", -1, -1)
    b.glass:SetHeight(9)
    b.glass:SetColorTexture(1, 1, 1, 0.08)
    b.line = b:CreateTexture(nil, "OVERLAY")
    b.line:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 1, 0)
    b.line:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -1, 0)
    b.line:SetHeight(1)
    b.line:SetColorTexture(0.29, 0.64, 1, 0.65)
    b.fs = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    b.fs:SetPoint("LEFT", b, "LEFT", 8, 0)
    b.fs:SetPoint("RIGHT", b, "RIGHT", -8, 0)
    b.fs:SetJustifyH("CENTER")
    b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    b.SetText = function(self, v) self.fs:SetText(v or "") end
    b.GetText = function(self) return self.fs:GetText() end
    if text then b:SetText(text) end
    return b
end

-- ===== Moteur de dropdown partagé (anti-clip + exclusion mutuelle + clic extérieur) =====
-- Tous les menus de MakeCycle vivent au-dessus du scrollframe (strata TOOLTIP, parent
-- UIParent) : ils ne sont plus rognés par SetClipsChildren et un seul est ouvert à la fois.
local openCycleMenu, cycleCloser
local function GetCycleCloser()
    if not cycleCloser then
        cycleCloser = CreateFrame("Button", nil, UIParent)
        cycleCloser:SetAllPoints(UIParent)
        cycleCloser:SetFrameStrata("FULLSCREEN_DIALOG")
        cycleCloser:EnableMouse(true)
        cycleCloser:Hide()
        cycleCloser:SetScript("OnClick", function()
            if openCycleMenu then openCycleMenu:Hide() end
        end)
    end
    return cycleCloser
end

local function MakeCycle(parent, label, x, y, choices, getf, setf, applyf, previewf)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fs:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    fs:SetText(label)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(150, 20)
    b:SetPoint("TOPLEFT", parent, "TOPLEFT", x + 120, y + 4)
    b.bg = b:CreateTexture(nil, "BACKGROUND")
    b.bg:SetAllPoints(b)
    b.bg:SetColorTexture(0.07, 0.08, 0.12, 0.92)
    b.glass = b:CreateTexture(nil, "ARTWORK")
    b.glass:SetPoint("TOPLEFT", b, "TOPLEFT", 1, -1)
    b.glass:SetPoint("TOPRIGHT", b, "TOPRIGHT", -1, -1)
    b.glass:SetHeight(8)
    b.glass:SetColorTexture(1, 1, 1, 0.08)
    b.line = b:CreateTexture(nil, "OVERLAY")
    b.line:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 1, 0)
    b.line:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -1, 0)
    b.line:SetHeight(1)
    b.line:SetColorTexture(0.29, 0.64, 1, 0.65)
    b.fs = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    b.fs:SetPoint("LEFT", b, "LEFT", 8, 0)
    b.fs:SetPoint("RIGHT", b, "RIGHT", -18, 0)
    b.fs:SetJustifyH("LEFT")
    b.arrow = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    b.arrow:SetPoint("RIGHT", b, "RIGHT", -6, 0)
    b.arrow:SetText("v")
    b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    local function labelFor(v)
        for _, c in ipairs(choices) do if c[1] == v then return c[2] end end
        return tostring(v or choices[1][1])
    end
    local function refresh() b.fs:SetText(labelFor(getf())) end
    local function choose(v)
        setf(v)
        refresh()
        if applyf then applyf() end
    end
    local menu
    local refreshPreviewMenu
    local function ensurePreviewMenu()
        if menu then return menu end
        -- parent UIParent (pas la page scrollable) + strata TOOLTIP : échappe au clip
        menu = CreateFrame("Frame", nil, UIParent)
        menu:SetFrameStrata("TOOLTIP")
        menu:SetScript("OnHide", function()
            if openCycleMenu == menu then openCycleMenu = nil end
            if cycleCloser then cycleCloser:Hide() end
        end)
        menu.visibleRows = math.min(#choices, 12)
        menu.scroll = 0
        menu:SetSize(250, menu.visibleRows * 24 + 6)
        menu:SetPoint("TOPLEFT", b, "BOTTOMLEFT", 0, -2)
        menu:EnableMouseWheel(true)
        menu:SetScript("OnMouseWheel", function(_, delta)
            menu.scroll = math.max(0, math.min(math.max(0, #choices - menu.visibleRows), (menu.scroll or 0) - delta))
            refreshPreviewMenu()
        end)
        menu.bg = menu:CreateTexture(nil, "BACKGROUND")
        menu.bg:SetAllPoints(menu)
        menu.bg:SetColorTexture(0.02, 0.02, 0.03, 0.98)
        menu.rows = {}
        for i = 1, menu.visibleRows do
            local row = CreateFrame("Button", nil, menu)
            row:SetSize(246, 22)
            row:SetPoint("TOPLEFT", menu, "TOPLEFT", 2, -3 - (i - 1) * 24)
            row.bg = row:CreateTexture(nil, "BACKGROUND")
            row.bg:SetAllPoints(row)
            row.label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            row.label:SetPoint("LEFT", row, "LEFT", 8, 0)
            row.label:SetJustifyH("LEFT")
            row:SetScript("OnClick", function()
                if row.choice then
                    choose(row.choice[1])
                    menu:Hide()
                end
            end)
            menu.rows[i] = row
        end
        menu:Hide()
        return menu
    end
    refreshPreviewMenu = function()
        if not menu then return end
        local cur = getf()
        local start = (menu.scroll or 0) + 1
        for i = 1, menu.visibleRows do
            local c = choices[start + i - 1]
            local row = menu.rows[i]
            if c then
                row:Show()
                row.choice = c
                local selected = c[1] == cur
                row.bg:SetColorTexture(selected and 0.18 or 1, selected and 0.34 or 1, selected and 0.62 or 1, selected and 0.85 or ((i % 2 == 0) and 0.05 or 0.02))
                row.label:SetText(c[2])
                row.label:SetFontObject(GameFontHighlightSmall)
                if previewf then previewf(row, c[1], c[2], selected) end
            else
                row:Hide()
                row.choice = nil
            end
        end
    end
    b:SetScript("OnClick", function()
        ensurePreviewMenu()
        if openCycleMenu and openCycleMenu ~= menu then openCycleMenu:Hide() end   -- ferme l'autre
        if menu:IsShown() then
            menu:Hide()
        else
            refreshPreviewMenu()
            GetCycleCloser():Show()
            menu:Show()
            menu:Raise()
            openCycleMenu = menu
        end
    end)
    refresh()
    return b, refresh
end

local function MakeFontPreview(parent, x, y, getFace, getSize, getFlags, text)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    fs:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    fs:SetText(text or "Apercu : SpherePanel Groupe")
    local function refresh()
        local size = getSize and getSize() or 12
        local ok = fs:SetFont(FontPath(getFace and getFace() or nil), size, getFlags and getFlags() or "")
        if not ok then fs:SetFontObject(GameFontHighlight) end
        fs:SetText(text or "Apercu : SpherePanel Groupe")
    end
    fs.Refresh = refresh
    refresh()
    return fs
end

local function MakeRaidBarPreview(parent, x, y, getTex)
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetSize(220, 22)
    holder:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    holder.bg = holder:CreateTexture(nil, "BACKGROUND")
    holder.bg:SetAllPoints(holder)
    holder.bg:SetColorTexture(0, 0, 0, 0.55)
    holder.bar = CreateFrame("StatusBar", nil, holder)
    holder.bar:SetPoint("TOPLEFT", holder, "TOPLEFT", 2, -3)
    holder.bar:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", -2, 3)
    holder.bar:SetMinMaxValues(0, 1)
    holder.bar:SetValue(1)
    holder.bar:SetStatusBarColor(0.29, 0.64, 1.0, 0.95)
    holder.txt = holder:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    holder.txt:SetPoint("CENTER", holder, "CENTER", 0, 0)
    holder.txt:SetText("Apercu de la barre")
    local function refresh()
        holder.bar:SetStatusBarTexture(RaidBarPath(getTex and getTex() or nil))
    end
    holder.Refresh = refresh
    refresh()
    return holder
end

local function FontChoicePreview(row, face, label, selected)
    row.label:ClearAllPoints()
    row.label:SetPoint("LEFT", row, "LEFT", 8, 0)
    row.label:SetPoint("RIGHT", row, "RIGHT", -8, 0)
    local ok = row.label:SetFont(FontPath(face), selected and 13 or 12, selected and "OUTLINE" or "")
    if not ok then row.label:SetFontObject(GameFontHighlightSmall) end
    row.label:SetText(label)
end

local function RaidBarChoicePreview(row, tex, label, selected)
    if not row.bar then
        row.bar = CreateFrame("StatusBar", nil, row)
        row.bar:SetPoint("LEFT", row, "LEFT", 8, 0)
        row.bar:SetSize(92, 13)
        row.bar:SetMinMaxValues(0, 1)
        row.bar:SetValue(1)
        row.bar:SetStatusBarColor(0.29, 0.64, 1.0, selected and 1 or 0.86)
        row.label:ClearAllPoints()
        row.label:SetPoint("LEFT", row.bar, "RIGHT", 10, 0)
        row.label:SetPoint("RIGHT", row, "RIGHT", -8, 0)
    end
    row.bar:SetStatusBarTexture(RaidBarPath(tex))
    row.bar:SetStatusBarColor(0.29, 0.64, 1.0, selected and 1 or 0.86)
    row.label:SetText(label)
end

local miniSliderCount = 0
local function MakeMiniSlider(parent, x, y, width, getf, setf, fmt)
    miniSliderCount = miniSliderCount + 1
    local s = CreateFrame("Slider", "SpherePanelCfgMiniSlider" .. miniSliderCount, parent)
    s:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    s:SetSize(width or 120, 18)
    if s.SetOrientation then s:SetOrientation("HORIZONTAL") end
    s:SetMinMaxValues(0, 1)
    s:SetValueStep(0.05)
    if s.SetObeyStepOnDrag then s:SetObeyStepOnDrag(true) end
    s.track = s:CreateTexture(nil, "BACKGROUND")
    s.track:SetPoint("LEFT", s, "LEFT", 0, -1)
    s.track:SetPoint("RIGHT", s, "RIGHT", 0, -1)
    s.track:SetHeight(6)
    s.track:SetColorTexture(0.05, 0.06, 0.09, 0.95)
    s.fill = s:CreateTexture(nil, "ARTWORK")
    s.fill:SetPoint("LEFT", s.track, "LEFT", 0, 0)
    s.fill:SetHeight(4)
    s.fill:SetColorTexture(0.29, 0.64, 1.0, 0.72)
    local thumb = s:CreateTexture(nil, "OVERLAY")
    thumb:SetSize(5, 12)
    thumb:SetColorTexture(0.86, 0.90, 1.0, 0.95)
    s:SetThumbTexture(thumb)
    s.value = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    s.value:SetPoint("LEFT", s, "RIGHT", 8, 1)
    local function refresh(v)
        if s.value then s.value:SetText(fmt and fmt(v) or tostring(v)) end
        if s.fill then s.fill:SetWidth(math.max(1, (s:GetWidth() or (width or 120)) * math.max(0, math.min(1, tonumber(v) or 0)))) end
    end
    local v = tonumber(getf()) or 0
    s:SetValue(v)
    refresh(v)
    s:SetScript("OnValueChanged", function(_, value)
        value = math.floor((value or 0) * 20 + 0.5) / 20
        setf(value)
        refresh(value)
    end)
    return s
end

-- swatch couleur (avec alpha optionnel)
local function MakeColorSwatch(parent, x, y, color, hasAlpha, onChange)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(18, 18); b:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    b.tex = b:CreateTexture(nil, "ARTWORK"); b.tex:SetAllPoints(b)
    local function paint() b.tex:SetColorTexture(color.r, color.g, color.b, 1) end
    b.Paint = paint
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

local function AurasOptions(page, y)
    local cfg = SP:GetModuleConfig("Auras")
    MakeCheck(page, "Masquer les auras Blizzard même si le module est désactivé", 16, y,
        function() return cfg.hideBlizzardAlways end,
        function(v)
            cfg.hideBlizzardAlways = v
            local m = SP.modulesByName and SP.modulesByName["Auras"]
            if m and m.ApplyBlizzardVisibility then m:ApplyBlizzardVisibility() end
        end)
end

local function SquareMapOptions(page, y)
    local cfg = SP:GetModuleConfig("SquareMap")
    MakeCheck(page, "Garder la minimap masquée quand le module est désactivé", 16, y,
        function() return cfg.hideWhenDisabled end, function(v) cfg.hideWhenDisabled = v end)
end

local function ChatOptions(root, y, opage)
    local cfg = SP:GetModuleConfig("Chat")
    local function applyChat()
        local mm = SP.modulesByName and SP.modulesByName["Chat"]
        if mm and mm.ApplyConfig then mm:ApplyConfig() end
        if SP.ChatFollow and SP.ChatFollow.ApplyConfig then SP.ChatFollow:ApplyConfig() end
    end
    local function ensureTabs()
        cfg.chatTabs = cfg.chatTabs or {}
        if #cfg.chatTabs == 0 then cfg.chatTabs[1] = { id = "main", label = "Tout", channels = { "A" }, showUnread = true } end
        for i, tab in ipairs(cfg.chatTabs) do
            tab.id = tab.id or ("tab" .. i)
            tab.label = tab.label or ("Chat " .. i)
            tab.channels = tab.channels or { "A" }
            if tab.showUnread == nil then tab.showUnread = true end
        end
        root._selectedChatTabId = root._selectedChatTabId or cfg.activeChatTab or cfg.chatTabs[1].id
        return cfg.chatTabs
    end
    local function selectedTab()
        ensureTabs()
        for _, tab in ipairs(cfg.chatTabs) do if tab.id == root._selectedChatTabId then return tab end end
        root._selectedChatTabId = cfg.chatTabs[1] and cfg.chatTabs[1].id
        return cfg.chatTabs[1]
    end
    local function followCfg()
        cfg.follow = cfg.follow or {}
        local f = cfg.follow
        if f.enabled == nil then f.enabled = cfg.instantPopups ~= false end
        f.style = f.style or ((cfg.popupTheme == "shadow") and "dark" or "white")
        f.width = f.width or 360
        f.height = f.height or 58
        f.x = f.x or 0
        f.y = f.y or 150
        f.grow = f.grow or "up"
        f.gap = f.gap or 8
        f.maxVisible = f.maxVisible or 4
        f.duration = ClampValue(f.duration or cfg.popupDuration or 7, 3, 120)
        f.whisperDuration = math.max(ClampValue(f.whisperDuration or math.max(10, f.duration), 3, 120), f.duration)
        f.fadeIn = f.fadeIn or 0.16
        f.fadeOut = f.fadeOut or 0.30
        f.combatMode = f.combatMode or "all"
        if f.hideIfChatVisible == nil then f.hideIfChatVisible = true end
        if f.clickReply == nil then f.clickReply = true end
        if f.hoverDismiss == nil then f.hoverDismiss = true end
        if f.locked == nil then f.locked = true end
        f.channels = f.channels or {}
        f.sounds = f.sounds or {}
        local defaults = { WHISPER = true, BN_WHISPER = true, PARTY = true, RAID = true, INSTANCE_CHAT = true, GUILD = true, OFFICER = true, CHANNEL = false, SAY = false, YELL = false, EMOTE = false }
        for k, v in pairs(defaults) do if f.channels[k] == nil then f.channels[k] = v end end
        return f
    end
    local function tabHas(tab, key)
        for _, k in ipairs((tab and tab.channels) or {}) do if k == key then return true end end
        return false
    end
    local function setTabChannel(tab, key, enabled)
        if not tab or not key then return end
        tab.channels = tab.channels or {}
        if key == "A" and enabled then tab.channels = { "A" }; return end
        for i = #tab.channels, 1, -1 do
            if tab.channels[i] == "A" or tab.channels[i] == key then table.remove(tab.channels, i) end
        end
        if enabled then tab.channels[#tab.channels + 1] = key end
        if #tab.channels == 0 then tab.channels[1] = "A" end
    end
    local function channelNotifyKeys(ch)
        if not ch then return {} end
        if ch.key == "W" then return { "WHISPER", "BN_WHISPER" } end
        if ch.key == "I" then return { "PARTY", "RAID", "INSTANCE_CHAT" } end
        if ch.key == "G" then return { "GUILD", "OFFICER" } end
        if ch.key == "S" then return { "SAY", "YELL", "EMOTE" } end
        if ch.key == "M" or ch.channelName or (type(ch.key) == "string" and ch.key:match("^C:")) then return { ch.key } end
        return { ch.key }
    end
    local function getFollowChannel(ch)
        local f = followCfg()
        for _, key in ipairs(channelNotifyKeys(ch)) do
            if f.channels[key] == true then return true end
        end
        return false
    end
    local function setFollowChannel(ch, enabled)
        local f = followCfg()
        for _, key in ipairs(channelNotifyKeys(ch)) do f.channels[key] = enabled and true or false end
    end
    local function getSoundChannel(ch)
        local f = followCfg()
        for _, key in ipairs(channelNotifyKeys(ch)) do
            if f.sounds[key] == true then return true end
        end
        return false
    end
    local function setSoundChannel(ch, enabled)
        local f = followCfg()
        for _, key in ipairs(channelNotifyKeys(ch)) do f.sounds[key] = enabled and true or nil end
    end

    y = SectionHeader(root, y, "Affichage")
    MakeCheck(root, "Colorer les noms par classe", 16, y,
        function() return cfg.classColorNames end, function(v) cfg.classColorNames = v; applyChat() end)
    y = y - 30
    MakeCheck(root, "Masquer le chat Blizzard", 16, y,
        function() return cfg.hideBlizzardChat ~= false end, function(v) cfg.hideBlizzardChat = v; applyChat() end)
    MakeCheck(root, "Remplacer la saisie Entree", 210, y,
        function() return cfg.replaceBlizzardInput ~= false end, function(v) cfg.replaceBlizzardInput = v; applyChat() end)
    y = y - 30
    MakeSlider(root, "Taille de police", 16, y, 8, 24, 1,
        function() return cfg.fontSize or 12 end, function(v) cfg.fontSize = v; applyChat() end, function(v) return tostring(v) end)
    y = y - 50
    MakeRadioRow(root, 16, y, { { "bottom", "Bandeau bas" }, { "top", "Bandeau haut" } },
        function() return cfg.inputDock or "bottom" end, function(v) cfg.inputDock = v; applyChat() end)
    MakeCheck(root, "Saisie temporaire", 270, y,
        function() return cfg.inputAutoHide ~= false end, function(v) cfg.inputAutoHide = v and true or false; applyChat() end)
    y = y - 32
    MakeSlider(root, "Hauteur bandeau", 16, y, 18, 42, 1,
        function() return cfg.inputBandHeight or 22 end, function(v) cfg.inputBandHeight = v; applyChat() end, function(v) return v .. " px" end)
    MakeSlider(root, "Alpha bandeau", 270, y, 0.05, 0.8, 0.05,
        function() return cfg.inputBandAlpha or 0.18 end, function(v) cfg.inputBandAlpha = v; applyChat() end, function(v) return ("%d%%"):format(math.floor(v * 100)) end, 170)
    y = y - 52
    -- (la largeur du module Chat se règle via « Largeur du module » en haut de page — individuelle)

    -- Les réglages du SUIVI CHAT (capsules) ont leur PROPRE page dédiée « Suivi chat »
    -- (nav de gauche). On garde ici juste un renvoi pour la clarté / éviter la duplication.
    y = SectionHeader(root, y, "Suivi chat (capsules)")
    local fnote = root:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    fnote:SetPoint("TOPLEFT", root, "TOPLEFT", 16, y); fnote:SetPoint("RIGHT", root, "RIGHT", -10, 0); fnote:SetJustifyH("LEFT"); fnote:SetWordWrap(true)
    fnote:SetText("|cFF888888Tous les réglages des capsules de suivi (style, position, canaux suivis, test) sont sur la page « Suivi chat » dans le menu de gauche.|r")
    y = y - 34

    y = SectionHeader(root, y, "Fenetres de chat")
    root.chatWinRows = root.chatWinRows or {}
    root.chatChanChecks = root.chatChanChecks or {}
    local tabsTop, chanTop = y, y - 58
    root._refreshWindows = function()
        local tabs = ensureTabs()
        local xx = 12
        for i, tab in ipairs(tabs) do
            local row = root.chatWinRows[i]
            if not row then
                row = CreateFrame("Frame", nil, root); row:SetSize(134, 24)
                row.bg = row:CreateTexture(nil, "BACKGROUND"); row.bg:SetAllPoints(row)
                row.swatch = CreateFrame("Button", nil, row); row.swatch:SetSize(14, 14); row.swatch:SetPoint("LEFT", row, "LEFT", 5, 0)
                row.swatch.tex = row.swatch:CreateTexture(nil, "ARTWORK"); row.swatch.tex:SetAllPoints(row.swatch)
                row.swatch.bd = row.swatch:CreateTexture(nil, "BACKGROUND"); row.swatch.bd:SetPoint("TOPLEFT", -1, 1); row.swatch.bd:SetPoint("BOTTOMRIGHT", 1, -1); row.swatch.bd:SetColorTexture(0, 0, 0, 0.8)
                row.name = CreateFrame("EditBox", nil, row, "InputBoxTemplate"); row.name:SetSize(58, 18); row.name:SetAutoFocus(false); row.name:SetPoint("LEFT", row.swatch, "RIGHT", 8, 0)
                row.unread = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate"); row.unread:SetSize(18, 18); row.unread:SetPoint("LEFT", row.name, "RIGHT", 4, 0)
                row.del = CreateFrame("Button", nil, row); row.del:SetSize(16, 16); row.del:SetPoint("LEFT", row.unread, "RIGHT", 2, 0)
                row.del.fs = row.del:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); row.del.fs:SetAllPoints(row.del); row.del.fs:SetText("|cFFFF6666x|r")
                row:EnableMouse(true)
                root.chatWinRows[i] = row
            end
            row:ClearAllPoints(); row:SetPoint("TOPLEFT", root, "TOPLEFT", xx, tabsTop)
            row.bg:SetColorTexture(0.30, 0.55, 0.95, (tab.id == root._selectedChatTabId) and 0.28 or 0.08)
            local tcol = tab.color or { 0.85, 0.9, 1 }
            row.swatch.tex:SetColorTexture(tcol[1], tcol[2], tcol[3])
            row.swatch:SetScript("OnClick", function()
                local c = tab.color or { 0.85, 0.9, 1 }
                if ColorPickerFrame and ColorPickerFrame.SetupColorPickerAndShow then
                    ColorPickerFrame:SetupColorPickerAndShow({ r = c[1], g = c[2], b = c[3], hasOpacity = false,
                        swatchFunc = function() local r, g, b = ColorPickerFrame:GetColorRGB(); tab.color = { r, g, b }; row.swatch.tex:SetColorTexture(r, g, b); applyChat(); root._refreshWindows() end,
                        cancelFunc = function() end })
                end
            end)
            if not (row.name.HasFocus and row.name:HasFocus()) then row.name:SetText(tab.label or tab.id) end
            row.name:SetScript("OnEditFocusLost", function(s) tab.label = s:GetText(); applyChat(); root._refreshWindows() end)
            row.name:SetScript("OnEnterPressed", function(s) s:ClearFocus() end)
            row.unread:SetChecked(tab.showUnread ~= false)
            row.unread:SetScript("OnClick", function(s) tab.showUnread = s:GetChecked() and true or false; applyChat() end)
            row.del:SetShown(#tabs > 1)
            row.del:SetScript("OnClick", function()
                for idx, t in ipairs(cfg.chatTabs) do if t == tab then table.remove(cfg.chatTabs, idx); break end end
                root._selectedChatTabId = cfg.chatTabs[1] and cfg.chatTabs[1].id
                cfg.activeChatTab = root._selectedChatTabId
                applyChat(); root._refreshWindows()
            end)
            row:SetScript("OnMouseDown", function()
                root._selectedChatTabId = tab.id
                cfg.activeChatTab = tab.id
                applyChat(); root._refreshWindows()
            end)
            row:Show()
            xx = xx + 140
        end
        for i = #tabs + 1, #root.chatWinRows do root.chatWinRows[i]:Hide() end
        if not root.chatWinAdd then
            root.chatWinAdd = MakeModernButton(root, "+", 24, 22)
            root.chatWinAdd:SetScript("OnClick", function()
                local n = #(cfg.chatTabs or {}) + 1
                local id = "tab" .. tostring(time()) .. tostring(n)
                cfg.chatTabs[#cfg.chatTabs + 1] = { id = id, label = "Chat " .. n, channels = { "A" }, showUnread = true }
                root._selectedChatTabId = id
                cfg.activeChatTab = id
                applyChat(); root._refreshWindows()
            end)
        end
        root.chatWinAdd:ClearAllPoints(); root.chatWinAdd:SetPoint("TOPLEFT", root, "TOPLEFT", xx, tabsTop - 1); root.chatWinAdd:Show()

        local tab = selectedTab()
        if not root.chatChanLabel then root.chatChanLabel = root:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall") end
        root.chatChanLabel:ClearAllPoints(); root.chatChanLabel:SetPoint("TOPLEFT", root, "TOPLEFT", 16, chanTop)
        root.chatChanLabel:SetText("|cFFAAAAAAFenetre selectionnee :|r |cFFFFFFFF" .. ((tab and tab.label) or "?") .. "|r |cFF777777(colonne Fen. dans le tableau)|r")
        for i = 1, #root.chatChanChecks do root.chatChanChecks[i]:Hide() end
    end
    root._refreshWindows()
    y = y - 86

    y = SectionHeader(root, y, "Canaux - registre global")
    local th = root:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    th:SetPoint("TOPLEFT", root, "TOPLEFT", 12, y); th:SetText("|cFF888888drag  Actif  Fen.  Couleur  Alias  Canal|r")
    y = y - 16
    local listTop = y

    root.chRows = root.chRows or {}
    root._refresh = function()
        if root._refreshWindows then root._refreshWindows() end
        local yy = listTop
        for i, ch in ipairs(cfg.channels) do
            local row = root.chRows[i]
            if not row then
                row = CreateFrame("Frame", nil, root); row:SetHeight(24)
                row.stripe = row:CreateTexture(nil, "BACKGROUND"); row.stripe:SetAllPoints(row)
                row.grip = CreateFrame("Button", nil, row); row.grip:SetSize(16, 20); row.grip:SetPoint("LEFT", row, "LEFT", 4, 0)
                row.grip:RegisterForDrag("LeftButton")
                for _k = 1, 3 do local bar = row.grip:CreateTexture(nil, "ARTWORK"); bar:SetSize(10, 2); bar:SetPoint("CENTER", row.grip, "CENTER", 0, (_k - 2) * 4); bar:SetColorTexture(0.72, 0.72, 0.78, 0.9) end
                row.grip:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
                row.check = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate"); row.check:SetSize(20, 20); row.check:SetPoint("LEFT", row.grip, "RIGHT", 2, 0)
                row.win = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate"); row.win:SetSize(20, 20); row.win:SetPoint("LEFT", row.check, "RIGHT", 18, 0)
                row.swatch = CreateFrame("Button", nil, row); row.swatch:SetSize(16, 16); row.swatch:SetPoint("LEFT", row.win, "RIGHT", 18, 0)
                row.swatch.tex = row.swatch:CreateTexture(nil, "ARTWORK"); row.swatch.tex:SetAllPoints(row.swatch)
                row.swatch.bd = row.swatch:CreateTexture(nil, "BACKGROUND"); row.swatch.bd:SetPoint("TOPLEFT", -1, 1); row.swatch.bd:SetPoint("BOTTOMRIGHT", 1, -1); row.swatch.bd:SetColorTexture(0, 0, 0, 0.8)
                row.nameBox = CreateFrame("EditBox", nil, row, "InputBoxTemplate"); row.nameBox:SetSize(110, 18); row.nameBox:SetAutoFocus(false); row.nameBox:SetPoint("LEFT", row.swatch, "RIGHT", 10, 0)
                row.key = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall"); row.key:SetPoint("LEFT", row.nameBox, "RIGHT", 8, 0)
                root.chRows[i] = row
            end
            row.chRef = ch
            local tab = selectedTab()
            row.stripe:SetColorTexture(1, 1, 1, (i % 2 == 0) and 0.05 or 0)
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", root, "TOPLEFT", 8, yy)
            row:SetPoint("TOPRIGHT", root, "TOPRIGHT", -8, yy)
            row.key:SetText("|cFF666666(" .. ch.key .. ")|r")
            row.nameBox:SetText(ch.label or ch.key)
            row.nameBox:SetScript("OnTextChanged", function(s, u) if u then ch.label = s:GetText(); applyChat() end end)
            row.check:SetChecked(ch.enabled and true or false)
            row.check:SetScript("OnClick", function(s) ch.enabled = s:GetChecked() and true or false; applyChat() end)
            row.win:SetChecked(tabHas(tab, ch.key))
            row.win:SetScript("OnClick", function(s) setTabChannel(selectedTab(), ch.key, s:GetChecked()); applyChat(); root._refresh() end)
            row.swatch.tex:SetColorTexture(ch.r, ch.g, ch.b)
            row.swatch:SetScript("OnClick", function()
                if ColorPickerFrame and ColorPickerFrame.SetupColorPickerAndShow then
                    ColorPickerFrame:SetupColorPickerAndShow({ r = ch.r, g = ch.g, b = ch.b, hasOpacity = false,
                        swatchFunc = function() local r, g, b = ColorPickerFrame:GetColorRGB(); ch.r, ch.g, ch.b = r, g, b; row.swatch.tex:SetColorTexture(r, g, b); applyChat() end,
                        cancelFunc = function() end })
                end
            end)
            row.grip:SetScript("OnDragStart", function() root._dragCh = ch end)
            row.grip:SetScript("OnDragStop", function()
                local src = root._dragCh; root._dragCh = nil
                if not src then return end
                local target
                for _, r in ipairs(root.chRows) do
                    if r:IsShown() and r:IsMouseOver() and r.chRef then target = r.chRef; break end
                end
                if target and target ~= src then
                    local chs, si, ti = cfg.channels
                    for idx, cc in ipairs(chs) do if cc == src then si = idx end; if cc == target then ti = idx end end
                    if si and ti then
                        table.remove(chs, si)
                        table.insert(chs, (si < ti) and (ti - 1) or ti, src)
                        root._refresh(); applyChat()
                    end
                end
            end)
            row:Show()
            yy = yy - 26
        end
        for j = #cfg.channels + 1, #root.chRows do root.chRows[j]:Hide() end
        root._impBtn:ClearAllPoints(); root._impBtn:SetPoint("TOPLEFT", root, "TOPLEFT", 12, yy - 4)
        root:SetHeight(math.max(560, -(yy) + 60))
    end

    local imp = MakeModernButton(root)
    imp:SetSize(210, 22); imp:SetText("+ Importer les canaux rejoints")
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
        root._refresh(); applyChat()
    end)
    root._impBtn = imp
    root._refresh()
    return listTop - (#cfg.channels + 2) * 26
end

local function BagsOptions(root, y, opage)
    local cfg = SP:GetModuleConfig("Bags")
    local function apply() local m = SP.modulesByName and SP.modulesByName["Bags"]; if m and m.RequestRefresh then m:RequestRefresh() end end
    cfg.displayMode = cfg.displayMode or "categorized"

    y = SectionHeader(root, y, "Affichage")
    MakeRadioRow(root, 16, y, { { "categorized", "Catégories" }, { "onebag", "Un sac" }, { "split", "Par sac" } },
        function() return cfg.displayMode end, function(v) cfg.displayMode = v; apply() end)
    y = y - 28
    MakeSlider(root, "Taille des icônes", 16, y, 20, 48, 1,
        function() return _G.BAGANATOR_CONFIG and _G.BAGANATOR_CONFIG.bag_icon_size or 30 end,
        function(v) _G.BAGANATOR_CONFIG = _G.BAGANATOR_CONFIG or {}; _G.BAGANATOR_CONFIG.bag_icon_size = v; apply() end,
        function(v) return v .. " px" end)
    y = y - 48
    MakeCheck(root, "Afficher l'iLvl", 16, y, function() return cfg.showIlvl end, function(v) cfg.showIlvl = v; apply() end)
    MakeCheck(root, "Flèche d'upgrade (Pawn)", 180, y, function() return cfg.showUpgrade end, function(v) cfg.showUpgrade = v; apply() end)
    y = y - 26
    MakeCheck(root, "Afficher les monnaies", 16, y, function() return cfg.showCurrencies ~= false end, function(v) cfg.showCurrencies = v; apply() end)
    y = y - 26
    MakeCheck(root, "Remplacer les sacs Blizzard", 16, y,
        function() return cfg.replaceBlizzardBags ~= false end, function(v) cfg.replaceBlizzardBags = v; apply() end)
    MakeCheck(root, "Ouvrir chez les PNJ", 220, y,
        function() return cfg.autoOpenAtNpc ~= false end, function(v) cfg.autoOpenAtNpc = v; apply() end)
    y = y - 26
    MakeCheck(root, "Vendre la camelote", 16, y,
        function() return cfg.autoSellJunk ~= false end, function(v) cfg.autoSellJunk = v end)
    y = y - 30

    y = SectionHeader(root, y, "Apparence des icônes")
    MakeSlider(root, "Épaisseur de bordure", 16, y, 0, 6, 1,
        function() return cfg.iconBorderThickness or 2 end,
        function(v) cfg.iconBorderThickness = v; apply() end, function(v) return v .. " px" end)
    y = y - 48
    MakeCheck(root, "Estomper les icônes hors survol", 16, y,
        function() return cfg.hoverDim == true end, function(v) cfg.hoverDim = v and true or false; apply() end)
    y = y - 28
    MakeSlider(root, "Saturation hors survol", 16, y, 0.05, 1, 0.05,
        function() return cfg.hoverSaturation or 0.35 end,
        function(v) cfg.hoverSaturation = v end, function(v) return ("%d%%"):format(math.floor(v * 100)) end)
    y = y - 50

    y = SectionHeader(root, y, "Catégories — glisser pour réordonner")
    -- aide mots-clés (filtre = tokens ET, repris de Baganator/Syndicator)
    local kw = root:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    kw:SetPoint("TOPLEFT", root, "TOPLEFT", 12, y); kw:SetPoint("RIGHT", root, "RIGHT", -10, 0); kw:SetJustifyH("LEFT"); kw:SetWordWrap(true)
    kw:SetText("|cFF6E8FB8Filtre = mots-clés (ET) : arme armure equipement consommable potion artisanat quete gemme · tete epaules torse jambes pieds mains anneau bijou cape · rare epique legendaire camelote · boe bop. Sinon = fragment de nom.|r")
    y = y - 40
    -- en-tête de table
    local th = root:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    th:SetPoint("TOPLEFT", root, "TOPLEFT", 12, y); th:SetText("|cFF888888glisser  ·  actif  ·  couleur  ·  nom  ·  filtre  ·  suppr|r")
    y = y - 16
    local listTop = y

    root.bagRows = root.bagRows or {}
    root._refresh = function()
        local yy = listTop
        for i, c in ipairs(cfg.categories) do
            local row = root.bagRows[i]
            if not row then
                row = CreateFrame("Frame", nil, root); row:SetHeight(24)
                row.stripe = row:CreateTexture(nil, "BACKGROUND"); row.stripe:SetAllPoints(row)
                row.grip = CreateFrame("Button", nil, row); row.grip:SetSize(16, 20); row.grip:SetPoint("LEFT", row, "LEFT", 4, 0)
                row.grip:RegisterForDrag("LeftButton")
                for _k = 1, 3 do local bar = row.grip:CreateTexture(nil, "ARTWORK"); bar:SetSize(10, 2); bar:SetPoint("CENTER", row.grip, "CENTER", 0, (_k - 2) * 4); bar:SetColorTexture(0.72, 0.72, 0.78, 0.9) end
                row.grip:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
                row.check = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate"); row.check:SetSize(20, 20); row.check:SetPoint("LEFT", row.grip, "RIGHT", 2, 0)
                row.color = CreateFrame("Button", nil, row); row.color:SetSize(16, 16); row.color:SetPoint("LEFT", row.check, "RIGHT", 4, 0)
                row.color.tex = row.color:CreateTexture(nil, "ARTWORK"); row.color.tex:SetAllPoints(row.color)
                row.color.bd = row.color:CreateTexture(nil, "BACKGROUND"); row.color.bd:SetPoint("TOPLEFT", -1, 1); row.color.bd:SetPoint("BOTTOMRIGHT", 1, -1); row.color.bd:SetColorTexture(0, 0, 0, 0.8)
                row.name = CreateFrame("EditBox", nil, row, "InputBoxTemplate"); row.name:SetSize(90, 18); row.name:SetAutoFocus(false); row.name:SetPoint("LEFT", row.color, "RIGHT", 10, 0)
                row.search = CreateFrame("EditBox", nil, row, "InputBoxTemplate"); row.search:SetSize(120, 18); row.search:SetAutoFocus(false); row.search:SetPoint("LEFT", row.name, "RIGHT", 12, 0)
                row.del = CreateFrame("Button", nil, row); row.del:SetSize(16, 16); row.del:SetPoint("LEFT", row.search, "RIGHT", 8, 0)
                row.del.fs = row.del:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); row.del.fs:SetAllPoints(row.del); row.del.fs:SetText("|cFFFF6666x|r")
                root.bagRows[i] = row
            end
            row.catRef = c
            row.stripe:SetColorTexture(1, 1, 1, (i % 2 == 0) and 0.05 or 0)
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", root, "TOPLEFT", 8, yy)
            row:SetPoint("TOPRIGHT", root, "TOPRIGHT", -8, yy)
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
            -- suppression (uniquement les filtres custom Cxx)
            local isCustom = type(c.key) == "string" and c.key:match("^C%d+$")
            row.del:SetShown(isCustom and true or false)
            row.del:SetScript("OnClick", function()
                for idx, cc in ipairs(cfg.categories) do if cc == c then table.remove(cfg.categories, idx); break end end
                root._refresh(); apply()
            end)
            row.grip:SetScript("OnDragStart", function() root._dragCat = c end)
            row.grip:SetScript("OnDragStop", function()
                local src = root._dragCat; root._dragCat = nil
                if not src then return end
                local target
                for _, r in ipairs(root.bagRows) do
                    if r:IsShown() and r:IsMouseOver() and r.catRef then target = r.catRef; break end
                end
                if target and target ~= src then
                    local cats, si, ti = cfg.categories
                    for idx, cc in ipairs(cats) do if cc == src then si = idx end; if cc == target then ti = idx end end
                    if si and ti then
                        table.remove(cats, si)
                        table.insert(cats, (si < ti) and (ti - 1) or ti, src)
                        root._refresh(); apply()
                    end
                end
            end)
            row:Show()
            yy = yy - 26
        end
        for j = #cfg.categories + 1, #root.bagRows do root.bagRows[j]:Hide() end
        -- bouton ajouter, après les lignes (scrolle avec)
        root._addBtn:ClearAllPoints(); root._addBtn:SetPoint("TOPLEFT", root, "TOPLEFT", 12, yy - 4)
        root:SetHeight(math.max(560, -(yy) + 60))
    end

    local add = MakeModernButton(root)
    add:SetSize(180, 22); add:SetText("+ Ajouter un filtre (par nom)")
    add:SetScript("OnClick", function()
        local n = 0; for _, c in ipairs(cfg.categories) do if type(c.key) == "string" and c.key:match("^C%d+$") then n = n + 1 end end
        table.insert(cfg.categories, 1, { key = "C" .. (n + 1), label = "Filtre " .. (n + 1), enabled = true, collapsed = false, search = "", color = { 0.5, 0.85, 1 } })
        root._refresh(); apply()
    end)
    root._addBtn = add
    root._refresh()
    return listTop - (#cfg.categories + 2) * 26
end

local function CharacterOptions(page, y)
    local cfg = SP:GetModuleConfig("Character")
    MakeCheck(page, "Remplacer la feuille de personnage (touche C)", 16, y,
        function() return cfg.replaceCharSheet end,
        function(v)
            cfg.replaceCharSheet = v
            local m = SP.modulesByName and SP.modulesByName["Character"]
            if m and m.ApplyKeyOverride then m:ApplyKeyOverride() end
        end)
    local note = page:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    note:SetPoint("TOPLEFT", page, "TOPLEFT", 16, y - 26)
    note:SetText("|cFF888888Feuille Blizzard accessible via le bouton du module (transmo, titres).\nMolette sur le bandeau = Équipement / Stats.|r")
end

local function RaidOptions(page, y)
    local cfg = SP:GetModuleConfig("Raid")
    local function apply()
        local m = SP.modulesByName and SP.modulesByName.Raid
        if m and m.Rebuild then m:Rebuild() end
    end
    y = SectionHeader(page, y, "Cadres de groupe / raid")
    MakeCheck(page, "Masquer les cadres Blizzard", 16, y,
        function() return cfg.hideBlizzard ~= false end,
        function(v) cfg.hideBlizzard = v and true or false; apply() end)
    MakeCheck(page, "Afficher les flags region", 230, y,
        function() return cfg.showFlags ~= false end,
        function(v) cfg.showFlags = v and true or false; apply() end)
    y = y - 28
    MakeCycle(page, "Separer par", 16, y, { { "group", "Groupe" }, { "role", "Role" } },
        function() return cfg.separateBy or "group" end,
        function(v) cfg.separateBy = v end,
        apply)
    y = y - 36
    local barPreview = MakeRaidBarPreview(page, 290, y + 6, function() return cfg.barTexture or "bar_serenity.tga" end)
    MakeCycle(page, "Texture barre", 16, y, RAID_BAR_CHOICES,
        function() return cfg.barTexture or "bar_serenity.tga" end,
        function(v) cfg.barTexture = v end,
        function()
            if barPreview and barPreview.Refresh then barPreview:Refresh() end
            apply()
        end,
        RaidBarChoicePreview)
    y = y - 40
    y = SectionHeader(page, y, "Barres de vie")
    MakeCheck(page, "Afficher le % de vie", 16, y,
        function() return cfg.showHP ~= false end,
        function(v) cfg.showHP = v and true or false; apply() end)
    y = y - 30
    local cl = page:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    cl:SetPoint("TOPLEFT", page, "TOPLEFT", 16, y - 6); cl:SetText("|cFFAAAAAAForme :|r")
    MakeRadioRow(page, 80, y, { { "square", "Carré" }, { "rounded", "Arrondi" }, { "capsule", "Capsule" } },
        function() return cfg.barStyle or "square" end,
        function(v) cfg.barStyle = v; apply() end)
    y = y - 30
    MakeCheck(page, "Bordure", 16, y,
        function() return cfg.showBorder == true end,
        function(v) cfg.showBorder = v and true or false; apply() end)
    y = y - 30
    MakeSlider(page, "Épaisseur bordure", 16, y, 1, 4, 1,
        function() return cfg.borderThickness or 1 end,
        function(v) cfg.borderThickness = v; apply() end, function(v) return v .. " px" end)
    y = y - 48
    MakeSlider(page, "Transparence du fond", 16, y, 0, 1, 0.05,
        function() return cfg.bgAlpha or 0.58 end,
        function(v) cfg.bgAlpha = v; apply() end, function(v) return ("%d%%"):format(math.floor(v * 100)) end)
    y = y - 50
    local note = page:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    note:SetPoint("TOPLEFT", page, "TOPLEFT", 16, y)
    note:SetText("|cFF888888Mort = tete de mort, hors ligne = prise debranchee. Clic gauche = cibler, clic droit = menu.|r")
    return y - 34
end

local SPECIFIC = {
    GameMenu = MenusOptions, SquareMap = SquareMapOptions, Chat = ChatOptions, Bags = BagsOptions,
    Auras = AurasOptions, Character = CharacterOptions, Raid = RaidOptions,
}

-- Dépendances tierces par module (affichées dans la page du module + statut chargé/absent).
local REQUIRES = {
    Knowledge    = { "MyusKnowledgePointsTracker" },
    SilverDragon = { "SilverDragon" },
    DamageMeter  = { "Details (optionnel, sinon moteur interne)" },
    Bags         = { "Pawn (optionnel, flèche upgrade)" },
    AlterEgo     = { "AlterEgo" },
    PerfMonitor  = { "AddonScope" },
}

-- ===== Page d'un module (sous-onglets : Général / Apparence / Options) ======
-- Onglet « Général » : activation, dimensions/position, conditions.
local function BuildModuleGeneralTab(root, m, cfg)
    local y = -6
    MakeCheck(root, "Activé", 8, y,
        function() return cfg and cfg.enabled end,
        function(v) if v then SP:EnableModule(m.name) else SP:DisableModuleUI(m) end end)
    if REQUIRES[m.name] then
        local req = root:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        req:SetPoint("TOPLEFT", root, "TOPLEFT", 210, y - 4)
        local parts = {}
        for _, dep in ipairs(REQUIRES[m.name]) do
            local an = dep:match("^(%S+)")
            local loaded = C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded(an)
            parts[#parts + 1] = (loaded and "|cFF40FF40" or "|cFFFF7777") .. dep .. "|r"
        end
        req:SetText("Requiert : " .. table.concat(parts, ", "))
    end
    y = y - 32

    if m.name ~= "GameMenu" then
        y = SectionHeader(root, y, "Dimensions et position")
        MakeSlider(root, "Hauteur", 16, y, 40, 600, 5,
            function() return (cfg and cfg.height) or m.defaultHeight or 150 end,
            function(v) if cfg then cfg.height = v; cfg.fixedHeight = true; SP:RebuildLayout() end end,
            function(v) return v .. " px" end)
        local auto = MakeModernButton(root)
        auto:SetSize(50, 20); auto:SetPoint("TOPLEFT", root, "TOPLEFT", 250, y - 6); auto:SetText("Auto")
        auto:SetScript("OnClick", function()
            if cfg then cfg.fixedHeight = false end
            local mod = SP.modulesByName[m.name]
            if mod then pcall(mod.OnResize, mod, 0, 0); if mod.RequestRefresh then mod:RequestRefresh() end end
            SP:RebuildLayout()
        end)
        y = y - 50
        MakeSlider(root, "Largeur du module", 16, y, 180, 800, 5,
            function() return (cfg and cfg.width and cfg.width > 0) and cfg.width or (SP.db.panel.width or 280) end,
            function(v) if cfg then cfg.width = v; SP:RebuildLayout() end end,
            function(v) return v .. " px" end)
        local wauto = MakeModernButton(root)
        wauto:SetSize(50, 20); wauto:SetPoint("TOPLEFT", root, "TOPLEFT", 250, y - 6); wauto:SetText("Pleine")
        wauto:SetScript("OnClick", function() if cfg then cfg.width = nil; SP:RebuildLayout() end end)
        y = y - 50
        local cl = root:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        cl:SetPoint("TOPLEFT", root, "TOPLEFT", 16, y - 6); cl:SetText("|cFFAAAAAAFixer dans l'angle du panneau :|r")
        MakeRadioRow(root, 130, y, { { "none", "Aucun" }, { "top", "Haut" }, { "bottom", "Bas" } },
            function() return cfg.corner or "none" end,
            function(v) cfg.corner = (v ~= "none") and v or nil; SP:RebuildLayout() end)
        y = y - 32
    end
    local afterCond = BuildConditions(root, m, y)
    root:SetHeight(math.max(420, -afterCond + 40))
end

-- Onglet « Apparence » : police du module + bordure (mode individuel).
local function BuildModuleAppearanceTab(root, m, cfg, app)
    local y = -6
    if m.name ~= "GameMenu" then
        y = SectionHeader(root, y, "Police du module")
        local fontPreview = MakeFontPreview(root, 290, y + 4,
            function() return cfg.fontFace or "Inter-Regular.ttf" end,
            function() return cfg.fontSize or SP.db.panel.fontSize or 11 end,
            function() return cfg.fontFlags or SP.db.panel.fontFlags or "" end,
            "Apercu police module")
        MakeCycle(root, "Police", 16, y, FONT_CHOICES,
            function() return cfg.fontFace or "Inter-Regular.ttf" end,
            function(v) cfg.fontFace = v end,
            function()
                if fontPreview and fontPreview.Refresh then fontPreview:Refresh() end
                if SP.ApplyModuleAppearance then SP:ApplyModuleAppearance(m) end
            end,
            FontChoicePreview)
        y = y - 34
        MakeSlider(root, "Taille police", 16, y, 8, 22, 1,
            function() return cfg.fontSize or SP.db.panel.fontSize or 11 end,
            function(v)
                cfg.fontSize = v
                if fontPreview and fontPreview.Refresh then fontPreview:Refresh() end
                if SP.ApplyModuleAppearance then SP:ApplyModuleAppearance(m) end
            end,
            function(v) return tostring(v) end)
        y = y - 48
        MakeCycle(root, "Style police", 16, y, FONT_FLAG_CHOICES,
            function() return cfg.fontFlags or SP.db.panel.fontFlags or "" end,
            function(v) cfg.fontFlags = v end,
            function()
                if fontPreview and fontPreview.Refresh then fontPreview:Refresh() end
                if SP.ApplyModuleAppearance then SP:ApplyModuleAppearance(m) end
            end)
        y = y - 38
    end
    if app then
        app.glowMode = app.glowMode or "auto"
        app.glowColor = app.glowColor or { r = 0.29, g = 0.64, b = 1 }
        y = SectionHeader(root, y, "Bordure quand réduit (mode individuel)")
        MakeRadioRow(root, 16, y, { { "auto", "Auto" }, { "text", "= Texte" }, { "bg", "= Fond" }, { "custom", "Perso" } },
            function() return app.glowMode end,
            function(v) app.glowMode = v end)
        y = y - 26
        local sw = root:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        sw:SetPoint("TOPLEFT", root, "TOPLEFT", 16, y - 2); sw:SetText("|cFFAAAAAACouleur perso :|r")
        MakeColorSwatch(root, 120, y - 4, app.glowColor, false, function() app.glowMode = "custom" end)
        y = y - 30
        MakeCheck(root, "Surcharger epaisseur/transparence", 16, y - 4,
            function() return app.glowLocal == true end,
            function(v) app.glowLocal = v and true or nil end)
        y = y - 30
        MakeSlider(root, "Epaisseur de bordure", 16, y, 2, 16, 1,
            function() return (app.glowLocal and app.glowThickness) or SP.db.panel.glowThickness or 6 end,
            function(v) app.glowLocal = true; app.glowThickness = v end, function(v) return v .. " px" end)
        y = y - 48
        MakeSlider(root, "Transparence de bordure", 16, y, 0.1, 1, 0.05,
            function() return (app.glowLocal and app.glowAlpha) or SP.db.panel.glowAlpha or 0.9 end,
            function(v) app.glowLocal = true; app.glowAlpha = v end, function(v) return ("%d%%"):format(math.floor(v * 100)) end)
        y = y - 48
    end
    root:SetHeight(math.max(360, -y + 40))
end

local function BuildModulePage(page, m)
    local cfg = SP:GetModuleConfig(m.name)
    local app = SP.GetModuleAppearanceConfig and SP:GetModuleAppearanceConfig(m.name)
    local defs = {
        { label = "Général",   build = function(root) BuildModuleGeneralTab(root, m, cfg) end },
        { label = "Apparence", build = function(root) BuildModuleAppearanceTab(root, m, cfg, app) end },
    }
    if SPECIFIC[m.name] then
        defs[#defs + 1] = { label = "Options", build = function(root)
            local bottom = SPECIFIC[m.name](root, -8, page) or -400
            root:SetHeight(math.max(520, -bottom + 40))
        end }
    end
    MakeTabbedPage(page, defs)
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
    MakeTabbedPage(page, {
        { label = "Panneau", build = function(root)
            local bgc = SP.db.panel.bgColor
            local lbl = root:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            lbl:SetPoint("TOPLEFT", root, "TOPLEFT", 8, -12); lbl:SetText("Couleur du fond :")
            MakeColorSwatch(root, 130, -10, bgc, true, function() if SP.ApplyAppearance then SP:ApplyAppearance() end end)
            MakeSlider(root, "Transparence du fond", 16, -48, 0, 1, 0.05,
                function() return bgc.a end,
                function(v) bgc.a = v; if SP.ApplyAppearance then SP:ApplyAppearance() end end,
                function(v) return string.format("%d%%", math.floor(v * 100)) end)
            MakeCheck(root, "Effets visuels (orbe pulsant + shimmer + intro)", 16, -92,
                function() return SP.db.panel.fx end, function(v) SP.db.panel.fx = v end)
            local note = root:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
            note:SetPoint("TOPLEFT", root, "TOPLEFT", 8, -124)
            note:SetText("|cFF777777La couleur et la transparence s'appliquent immediatement.|r")
            root:SetHeight(170)
        end },
        { label = "Modules", build = function(root)
            local y = -8
            local headers = { { "Module", 8 }, { "Transparence", 138 }, { "Fond", 314 }, { "Texte", 360 } }
            for _, h in ipairs(headers) do
                local fs = root:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
                fs:SetPoint("TOPLEFT", root, "TOPLEFT", h[2], y); fs:SetText(h[1])
            end
            y = y - 20
            for _, m in ipairs(SP:GetOrderedModules()) do
                local app = SP.GetModuleAppearanceConfig and SP:GetModuleAppearanceConfig(m.name)
                if app then
                    local row = CreateFrame("Frame", nil, root)
                    row:SetPoint("TOPLEFT", root, "TOPLEFT", 4, y)
                    row:SetSize(430, 28)
                    row.bg = row:CreateTexture(nil, "BACKGROUND"); row.bg:SetAllPoints(row); row.bg:SetColorTexture(1, 1, 1, 0.035)
                    local name = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                    name:SetPoint("LEFT", row, "LEFT", 4, 0); name:SetWidth(118); name:SetJustifyH("LEFT"); name:SetText(m.label)
                    local alphaSlider = MakeMiniSlider(row, 134, -5, 116,
                        function() return app.bgColor.a or 0.46 end,
                        function(v) app.bgColor.a = v; if SP.ApplyModuleAppearance then SP:ApplyModuleAppearance(m) end end,
                        function(v) return string.format("%d%%", math.floor((v or 0) * 100 + 0.5)) end)
                    local bgSwatch = MakeColorSwatch(row, 310, -5, app.bgColor, true, function()
                        if alphaSlider then alphaSlider:SetValue(app.bgColor.a or 0.46) end
                        if SP.ApplyModuleAppearance then SP:ApplyModuleAppearance(m) end
                    end)
                    local textSwatch = MakeColorSwatch(row, 358, -5, app.textColor, false, function()
                        if SP.ApplyModuleAppearance then SP:ApplyModuleAppearance(m) end
                    end)
                    local reset = MakeModernButton(row)
                    reset:SetSize(46, 18); reset:SetPoint("LEFT", row, "LEFT", 382, 0); reset:SetText("Reset")
                    reset:SetScript("OnClick", function()
                        if SP.ResetModuleAppearance then SP:ResetModuleAppearance(m.name) end
                        if alphaSlider then alphaSlider:SetValue(app.bgColor.a or 0.46) end
                        if bgSwatch and bgSwatch.Paint then bgSwatch:Paint() end
                        if textSwatch and textSwatch.Paint then textSwatch:Paint() end
                    end)
                    y = y - 30
                end
            end
            root:SetHeight(math.max(400, -y + 24))
        end },
    })
end

-- Page scrollable : retourne un conteneur interne déplacé à la molette.
MakeScrollPage = function(page, innerH)
    page:SetClipsChildren(true)
    local inner = CreateFrame("Frame", nil, page)
    inner:SetPoint("TOPLEFT", page, "TOPLEFT", 0, 0)
    inner:SetPoint("TOPRIGHT", page, "TOPRIGHT", 0, 0)
    inner:SetHeight(innerH or 700)
    page._scroll = 0
    page:EnableMouseWheel(true)
    page:SetScript("OnMouseWheel", function(_, delta)
        local maxS = math.max(0, inner:GetHeight() - (page:GetHeight() or 1))
        page._scroll = math.min(maxS, math.max(0, page._scroll - delta * 40))
        inner:ClearAllPoints()
        inner:SetPoint("TOPLEFT", page, "TOPLEFT", 0, page._scroll)
        inner:SetPoint("TOPRIGHT", page, "TOPRIGHT", 0, page._scroll)
    end)
    return inner
end

-- Barre de sous-onglets en haut de `page` + un MakeScrollPage clippé par onglet.
-- defs = { { label=..., build=function(inner) ... end, height=? }, ... }
-- Chaque onglet scrolle indépendamment ; le 1er est actif. Si un build pose `inner._refresh`,
-- il est rappelé à l'activation de l'onglet (listes dynamiques).
MakeTabbedPage = function(page, defs)
    local bar = CreateFrame("Frame", nil, page)
    bar:SetPoint("TOPLEFT", page, "TOPLEFT", 4, -4)
    bar:SetPoint("TOPRIGHT", page, "TOPRIGHT", -4, -4)
    bar:SetHeight(22)
    local line = bar:CreateTexture(nil, "ARTWORK")
    line:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", -4, 0); line:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 4, 0)
    line:SetHeight(1); line:SetColorTexture(0.29, 0.64, 1, 0.25)
    local hosts, btns = {}, {}
    local function show(idx)
        for i, h in ipairs(hosts) do h:SetShown(i == idx) end
        for i, b in ipairs(btns) do
            b.bg:SetShown(i == idx)
            b.fs:SetTextColor(i == idx and 0.29 or 0.72, i == idx and 0.64 or 0.72, i == idx and 1 or 0.72)
        end
        page._activeSub = idx
        local d = defs[idx]
        if d and d.inner then
            d.host._scroll = 0
            d.inner:ClearAllPoints()
            d.inner:SetPoint("TOPLEFT", d.host, "TOPLEFT", 0, 0)
            d.inner:SetPoint("TOPRIGHT", d.host, "TOPRIGHT", 0, 0)
            if d.inner._refresh then d.inner._refresh() end
        end
    end
    local x = 2
    for i, d in ipairs(defs) do
        local b = CreateFrame("Button", nil, bar)
        b.fs = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); b.fs:SetText(d.label); b.fs:SetPoint("CENTER")
        local w = math.max(46, (b.fs:GetStringWidth() or 40) + 18)
        b:SetSize(w, 20); b:SetPoint("LEFT", bar, "LEFT", x, 0)
        b.bg = b:CreateTexture(nil, "BACKGROUND"); b.bg:SetAllPoints(b); b.bg:SetColorTexture(0.29, 0.64, 1, 0.28)
        b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
        x = x + w + 4
        local host = CreateFrame("Frame", nil, page)
        host:SetPoint("TOPLEFT", bar, "BOTTOMLEFT", -4, -3)
        host:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", 0, 0)
        local inner = MakeScrollPage(host, d.height or 700)
        d.inner, d.host = inner, host
        hosts[i], btns[i] = host, b
        b:SetScript("OnClick", function() show(i) end)
        d.build(inner)
    end
    page._showSub = function() show(page._activeSub or 1) end
    page:SetScript("OnShow", function() show(page._activeSub or 1) end)
    show(1)
    return defs
end

-- ===== Comportement (scrollable, sections nettes) ===========================
MakeRadioRow = function(parent, x, y, defs, getf, setf)
    -- defs = { {val,label,disabled?}, ... } ; une seule coche active ; molette non requise
    local btns = {}
    local cx = x
    for _, d in ipairs(defs) do
        local c = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
        c:SetSize(22, 22)
        c:SetPoint("TOPLEFT", parent, "TOPLEFT", cx, y)
        c.text = c:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        c.text:SetPoint("LEFT", c, "RIGHT", 2, 0); c.text:SetText(d[2])
        c.val = d[1]
        if d[3] then
            c:Disable()
            c.text:SetTextColor(0.45, 0.45, 0.45)
        else
            c:SetScript("OnClick", function(s)
                setf(s.val)
                for _, o in ipairs(btns) do o:SetChecked(o.val == getf()) end
            end)
        end
        btns[#btns + 1] = c
        cx = cx + 24 + (c.text:GetStringWidth() or 40) + 14
    end
    local function refresh() for _, o in ipairs(btns) do o:SetChecked(o.val == getf()) end end
    refresh()
    return btns, refresh
end

SectionHeader = function(parent, y, text)
    local h = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    h:SetPoint("TOPLEFT", parent, "TOPLEFT", 6, y)
    h:SetText("|cFF4AA3FF" .. text .. "|r")
    local line = parent:CreateTexture(nil, "ARTWORK")
    line:SetHeight(1)
    line:SetPoint("TOPLEFT", parent, "TOPLEFT", 6, y - 16)
    line:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -10, y - 16)
    line:SetColorTexture(0.29, 0.64, 1, 0.20)
    return y - 26
end

local function BuildComportement(page)
    local pcfg = SP.db.panel
    local af = pcfg.autofade
    local function applyBeh() if SP.ApplyPanelBehavior then SP:ApplyPanelBehavior() end end
    MakeTabbedPage(page, {
        { label = "Panneau ①", build = function(pg)
            local y = SectionHeader(pg, -8, "Panneau principal ①")
            local BEH = {
                { 1, "1 — Glissant magnétisé (revient au bord)" },
                { 2, "2 — Modules individuels + glow au bord" },
                { 3, "3 — Libre, toujours visible" },
            }
            local behBtns = {}
            for i, d in ipairs(BEH) do
                local c = CreateFrame("CheckButton", nil, pg, "UICheckButtonTemplate")
                c:SetPoint("TOPLEFT", pg, "TOPLEFT", 14, y - (i - 1) * 22)
                c.text = c:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                c.text:SetPoint("LEFT", c, "RIGHT", 2, 0); c.text:SetText(d[2])
                c.val = d[1]; c:SetChecked(pcfg.behavior == d[1])
                c:SetScript("OnClick", function(s)
                    pcfg.behavior = s.val
                    for _, o in ipairs(behBtns) do o:SetChecked(o.val == s.val) end
                    applyBeh()
                end)
                behBtns[i] = c
            end
            y = y - 3 * 22 - 6
            local sideL = pg:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            sideL:SetPoint("TOPLEFT", pg, "TOPLEFT", 14, y - 6); sideL:SetText("|cFFAAAAAACôté :|r")
            MakeRadioRow(pg, 60, y, { { "right", "Droite" }, { "left", "Gauche" } },
                function() return pcfg.side or "right" end, function(v) pcfg.side = v; applyBeh() end)
            local vposL = pg:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            vposL:SetPoint("TOPLEFT", pg, "TOPLEFT", 250, y - 6); vposL:SetText("|cFFAAAAAAAncrage :|r")
            MakeRadioRow(pg, 310, y, { { "top", "Haut" }, { "bottom", "Bas" } },
                function() return pcfg.vpos or "top" end, function(v) pcfg.vpos = v; applyBeh() end)
            y = y - 30
            pg:SetHeight(-y + 30)
        end },
        { label = "Panneau ②", build = function(pg)
            local y = SectionHeader(pg, -8, "Second panneau ②")
            MakeCheck(pg, "Activer", 14, y,
                function() return pcfg.panel2 and pcfg.panel2.enabled end,
                function(v)
                    pcfg.panel2 = pcfg.panel2 or { x = 20, y = -200, width = 280, side = "auto", vpos = "top" }
                    pcfg.panel2.enabled = v
                    if SP.ApplyPanel2 then SP:ApplyPanel2() end
                end)
            y = y - 26
            local p2 = pcfg.panel2
            local s2L = pg:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            s2L:SetPoint("TOPLEFT", pg, "TOPLEFT", 14, y - 6); s2L:SetText("|cFFAAAAAACôté :|r")
            MakeRadioRow(pg, 60, y, { { "auto", "Auto (opposé)" }, { "right", "Droite" }, { "left", "Gauche" } },
                function() return (p2 and p2.side) or "auto" end,
                function(v) p2.side = v; if SP.ApplyPanel2 then SP:ApplyPanel2() end end)
            y = y - 26
            local v2L = pg:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            v2L:SetPoint("TOPLEFT", pg, "TOPLEFT", 14, y - 6); v2L:SetText("|cFFAAAAAAAncrage :|r")
            MakeRadioRow(pg, 75, y, { { "top", "Haut" }, { "bottom", "Bas" } },
                function() return (p2 and p2.vpos) or "top" end,
                function(v) p2.vpos = v; if SP.ApplyPanel2 then SP:ApplyPanel2() end end)
            y = y - 26
            local m2L = pg:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            m2L:SetPoint("TOPLEFT", pg, "TOPLEFT", 14, y - 6); m2L:SetText("|cFFAAAAAAMode :|r")
            MakeRadioRow(pg, 60, y, { { 3, "Libre" }, { 1, "Glissant" }, { 2, "Individuel" } },
                function() return (p2 and p2.behavior) or 3 end,
                function(v) p2.behavior = v; if SP.ApplyPanel2 then SP:ApplyPanel2() end end)
            y = y - 26
            local p2n = pg:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
            p2n:SetPoint("TOPLEFT", pg, "TOPLEFT", 14, y - 2); p2n:SetJustifyH("LEFT")
            p2n:SetText("|cFF888888Glissez le bandeau d'un module et déposez-le sur le ② pour l'y déplacer.|r")
            y = y - 24
            pg:SetHeight(-y + 30)
        end },
        { label = "Estompage", build = function(pg)
            local y = SectionHeader(pg, -8, "Estompage (mode libre)")
            MakeCheck(pg, "Estomper après inactivité", 14, y,
                function() return af.enabled end, function(v) af.enabled = v end)
            y = y - 38
            MakeSlider(pg, "Délai", 24, y, 1, 30, 1,
                function() return af.delay end, function(v) af.delay = v end, function(v) return v .. " s" end)
            y = y - 48
            MakeSlider(pg, "Opacité (0% = transparent)", 24, y, 0, 1, 0.05,
                function() return af.alpha end, function(v) af.alpha = v end,
                function(v) return string.format("%d%%", math.floor(v * 100)) end)
            y = y - 48
            MakeSlider(pg, "Transition", 24, y, 0.1, 1, 0.05,
                function() return af.fadeDuration end, function(v) af.fadeDuration = v end,
                function(v) return string.format("%.2f s", v) end)
            y = y - 44
            y = SectionHeader(pg, y - 6, "Appliquer estompage/réduction à")
            local listTop = y
            pg.fadeRows = {}
            pg._refresh = function()
                af.apply = af.apply or {}
                for i, m in ipairs(SP:GetOrderedModules()) do
                    local c = pg.fadeRows[i]
                    if not c then
                        c = CreateFrame("CheckButton", nil, pg, "UICheckButtonTemplate"); c:SetSize(20, 20)
                        c.text = c:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); c.text:SetPoint("LEFT", c, "RIGHT", 2, 0)
                        pg.fadeRows[i] = c
                    end
                    local col, rowN = (i - 1) % 2, math.floor((i - 1) / 2)
                    c:ClearAllPoints(); c:SetPoint("TOPLEFT", pg, "TOPLEFT", 14 + col * 190, listTop - rowN * 22)
                    c.text:SetText(m.label)
                    local mcfg = SP:GetModuleConfig(m.name); local en = mcfg and mcfg.enabled
                    c:SetEnabled(en and true or false)
                    c.text:SetTextColor(en and 1 or 0.5, en and 1 or 0.5, en and 1 or 0.5)
                    c:SetChecked(af.apply[m.name] ~= false)
                    c:SetScript("OnClick", function(s) af.apply[m.name] = s:GetChecked() and true or false end)
                    c:Show()
                end
                for i = #SP:GetOrderedModules() + 1, #pg.fadeRows do pg.fadeRows[i]:Hide() end
            end
            pg._refresh()
            pg:SetHeight(-listTop + math.ceil(#SP:GetOrderedModules() / 2) * 22 + 50)
        end },
    })
end

local function BuildGeneral(realPage)
    -- Général en sous-onglets : Panneau / Bordures / Polices
    MakeTabbedPage(realPage, {
        { label = "Panneau", build = function(page)
            local y = SectionHeader(page, -8, "Panneau")
            MakeSlider(page, "Largeur du panneau", 16, y, 180, 600, 5,
                function() return SP.db.panel.width or 280 end,
                function(v) SP.db.panel.width = v; if SP.panel then SP.panel:SetWidth(v); SP:OnPanelResized() end end,
                function(v) return v .. " px" end)
            y = y - 54
            local note = page:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
            note:SetPoint("TOPLEFT", page, "TOPLEFT", 8, y)
            note:SetText("|cFF777777Astuce : clic droit sur un bandeau = menu (Paramètres / Verrouiller / Masquer).|r")
            page:SetHeight(180)
        end },
        { label = "Bordures", build = function(page)
            local y = SectionHeader(page, -8, "Bordures globales (surchargeable par module)")
            MakeSlider(page, "Épaisseur des bordures (global)", 16, y, 2, 16, 1,
                function() return SP.db.panel.glowThickness or 6 end,
                function(v) SP.db.panel.glowThickness = v end, function(v) return v .. " px" end)
            y = y - 48
            MakeSlider(page, "Transparence des bordures (global)", 16, y, 0.1, 1, 0.05,
                function() return SP.db.panel.glowAlpha or 0.9 end,
                function(v) SP.db.panel.glowAlpha = v end, function(v) return ("%d%%"):format(math.floor(v * 100)) end)
            page:SetHeight(180)
        end },
        { label = "Polices", build = function(page)
            local y = SectionHeader(page, -8, "Polices")
            MakeCheck(page, "Police globale prioritaire", 16, y,
                function() return SP.db.panel.fontGlobal == true end,
                function(v) SP.db.panel.fontGlobal = v and true or false; if SP.ApplyAllModuleAppearance then SP:ApplyAllModuleAppearance() end end)
            y = y - 32
            local fontPreview = MakeFontPreview(page, 300, y + 4,
                function() return SP.db.panel.fontFace or "Inter-Regular.ttf" end,
                function() return SP.db.panel.fontSize or 11 end,
                function() return SP.db.panel.fontFlags or "" end,
                "Apercu police globale")
            MakeCycle(page, "Police globale", 16, y, FONT_CHOICES,
                function() return SP.db.panel.fontFace or "Inter-Regular.ttf" end,
                function(v) SP.db.panel.fontFace = v end,
                function()
                    if fontPreview and fontPreview.Refresh then fontPreview:Refresh() end
                    if SP.ApplyAllModuleAppearance then SP:ApplyAllModuleAppearance() end
                end,
                FontChoicePreview)
            y = y - 42
            MakeSlider(page, "Taille police globale", 16, y, 8, 22, 1,
                function() return SP.db.panel.fontSize or 11 end,
                function(v)
                    SP.db.panel.fontSize = v
                    if fontPreview and fontPreview.Refresh then fontPreview:Refresh() end
                    if SP.ApplyAllModuleAppearance then SP:ApplyAllModuleAppearance() end
                end,
                function(v) return tostring(v) end)
            y = y - 48
            MakeCycle(page, "Style police globale", 16, y, FONT_FLAG_CHOICES,
                function() return SP.db.panel.fontFlags or "" end,
                function(v) SP.db.panel.fontFlags = v end,
                function()
                    if fontPreview and fontPreview.Refresh then fontPreview:Refresh() end
                    if SP.ApplyAllModuleAppearance then SP:ApplyAllModuleAppearance() end
                end)
            y = y - 40
            local secondaryPreview = MakeFontPreview(page, 300, y + 4,
                function() return SP.db.panel.fontSecondaryFace or SP.db.panel.fontFace or "Inter-Regular.ttf" end,
                function() return SP.db.panel.fontSecondarySize or math.max(8, (SP.db.panel.fontSize or 11) - 1) end,
                function() return SP.db.panel.fontSecondaryFlags or "" end,
                "Apercu texte secondaire")
            MakeCycle(page, "Police secondaire", 16, y, FONT_CHOICES,
                function() return SP.db.panel.fontSecondaryFace or SP.db.panel.fontFace or "Inter-Regular.ttf" end,
                function(v) SP.db.panel.fontSecondaryFace = v end,
                function()
                    if secondaryPreview and secondaryPreview.Refresh then secondaryPreview:Refresh() end
                    if SP.ApplyAllModuleAppearance then SP:ApplyAllModuleAppearance() end
                end,
                FontChoicePreview)
            y = y - 42
            MakeSlider(page, "Taille police secondaire", 16, y, 8, 20, 1,
                function() return SP.db.panel.fontSecondarySize or 10 end,
                function(v)
                    SP.db.panel.fontSecondarySize = v
                    if secondaryPreview and secondaryPreview.Refresh then secondaryPreview:Refresh() end
                    if SP.ApplyAllModuleAppearance then SP:ApplyAllModuleAppearance() end
                end,
                function(v) return tostring(v) end)
            y = y - 48
            MakeCycle(page, "Style police secondaire", 16, y, FONT_FLAG_CHOICES,
                function() return SP.db.panel.fontSecondaryFlags or "" end,
                function(v) SP.db.panel.fontSecondaryFlags = v end,
                function()
                    if secondaryPreview and secondaryPreview.Refresh then secondaryPreview:Refresh() end
                    if SP.ApplyAllModuleAppearance then SP:ApplyAllModuleAppearance() end
                end)
            y = y - 42
            page:SetHeight(-y + 40)
        end },
    })
end

-- ===== Fenêtre ==============================================================
-- ===== Page « Suivi chat » (capsules flottantes) — DISTINCTE du module Chat =====
local FOLLOW_TYPES = {
    { "WHISPER", "Chuchotements" }, { "BN_WHISPER", "Battle.net" },
    { "PARTY", "Groupe" }, { "RAID", "Raid" }, { "INSTANCE_CHAT", "Instance" },
    { "GUILD", "Guilde" }, { "OFFICER", "Officier" },
    { "CHANNEL", "Canaux perso" }, { "SAY", "Dire" }, { "YELL", "Crier" }, { "EMOTE", "Émote" },
}
local function FollowTypeColor(tk)
    local c = ChatTypeInfo and ChatTypeInfo[tk]
    if c then return c.r or 0.7, c.g or 0.7, c.b or 0.7 end
    return 0.7, 0.7, 0.7
end

local function BuildSuiviChat(page)
    local function fc() return SP.ChatFollow and SP.ChatFollow:GetConfig() end
    local function apply()
        if SP.ChatFollow then
            if SP.ChatFollow.ApplyConfig then SP.ChatFollow:ApplyConfig() end
            if SP.ChatFollow.RefreshConfigPreview then SP.ChatFollow:RefreshConfigPreview() end
        end
    end
    if not fc() then
        local note = page:CreateFontString(nil, "OVERLAY", "GameFontDisable")
        note:SetPoint("TOPLEFT", page, "TOPLEFT", 12, -12); note:SetText("Module Suivi chat indisponible.")
        return
    end
    -- Aperçu LIVE persistant en haut, au-dessus des sous-onglets (mis à jour à chaque réglage).
    local preview = CreateFrame("Frame", nil, page)
    preview:SetPoint("TOPLEFT", page, "TOPLEFT", 4, -4); preview:SetPoint("TOPRIGHT", page, "TOPRIGHT", -4, -4); preview:SetHeight(66)
    preview.bg = preview:CreateTexture(nil, "BACKGROUND"); preview.bg:SetAllPoints(preview); preview.bg:SetColorTexture(1, 1, 1, 0.03)
    preview.lbl = preview:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall"); preview.lbl:SetPoint("TOPLEFT", preview, "TOPLEFT", 6, -3); preview.lbl:SetText("|cFF888888Aperçu live|r")
    local function ensurePreview() if SP.ChatFollow and SP.ChatFollow.GetConfigPreview then SP.ChatFollow:GetConfigPreview(preview) end end
    page:SetScript("OnShow", ensurePreview)
    ensurePreview()
    -- Les sous-onglets occupent l'espace SOUS l'aperçu.
    local tabArea = CreateFrame("Frame", nil, page)
    tabArea:SetPoint("TOPLEFT", preview, "BOTTOMLEFT", -4, -4); tabArea:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", 0, 0)
    MakeTabbedPage(tabArea, {
        { label = "Apparence", build = function(root)
            local y = -6
            MakeCheck(root, "Activer le suivi chat (capsules flottantes)", 8, y,
                function() return fc().enabled ~= false end, function(v) fc().enabled = v and true or false; apply() end)
            y = y - 30
            local sl = root:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            sl:SetPoint("TOPLEFT", root, "TOPLEFT", 16, y - 6); sl:SetText("|cFFAAAAAAStyle :|r")
            MakeRadioRow(root, 70, y, { { "pill", "Pilule (noir transparent)" }, { "white", "Clair" } },
                function() return fc().style or "pill" end, function(v) fc().style = v; apply() end)
            y = y - 30
            MakeSlider(root, "Transparence du fond (0% = transparent)", 16, y, 0, 1, 0.05,
                function() return fc().bgAlpha or 0.35 end, function(v) fc().bgAlpha = v; apply() end, function(v) return ("%d%%"):format(math.floor(v * 100)) end)
            y = y - 48
            MakeCheck(root, "Ombre intérieure (effet creusé)", 16, y,
                function() return fc().innerShadow ~= false end, function(v) fc().innerShadow = v and true or false; apply() end)
            y = y - 30
            MakeSlider(root, "Intensité du liseré (anneau)", 16, y, 0.2, 1, 0.05,
                function() return fc().borderAlpha or 0.95 end, function(v) fc().borderAlpha = v; apply() end, function(v) return ("%d%%"):format(math.floor(v * 100)) end)
            y = y - 50
            MakeCheck(root, "Halo coloré", 16, y, function() return fc().glow == true end, function(v) fc().glow = v and true or false; apply() end)
            MakeCheck(root, "Halo pulsant", 200, y, function() return fc().pulse == true end, function(v) fc().pulse = v and true or false; apply() end)
            y = y - 28
            MakeSlider(root, "Intensité du halo", 16, y, 0.05, 0.6, 0.05,
                function() return fc().glowAlpha or 0.22 end, function(v) fc().glowAlpha = v; apply() end, function(v) return ("%d%%"):format(math.floor(v * 100)) end)
            y = y - 48
            MakeCheck(root, "Afficher l'heure", 16, y, function() return fc().showTime == true end, function(v) fc().showTime = v and true or false; apply() end)
            y = y - 30
            MakeSlider(root, "Épaisseur de la bordure", 16, y, 1, 5, 1,
                function() return fc().borderThickness or 2 end, function(v) fc().borderThickness = v; apply() end, function(v) return v .. " px" end)
            y = y - 48
            MakeSlider(root, "Largeur des capsules", 16, y, 220, 600, 5,
                function() return fc().width or 360 end, function(v) fc().width = v; apply() end, function(v) return v .. " px" end)
            y = y - 48
            local hn = root:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
            hn:SetPoint("TOPLEFT", root, "TOPLEFT", 16, y); hn:SetText("La hauteur des capsules s'ajuste automatiquement au contenu.")
            y = y - 28
            root:SetHeight(-y + 30)
        end },
        { label = "Comportement", build = function(root)
            local y = -6
            local gl = root:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            gl:SetPoint("TOPLEFT", root, "TOPLEFT", 16, y - 6); gl:SetText("|cFFAAAAAAEmpilage :|r")
            MakeRadioRow(root, 90, y, { { "up", "Vers le haut" }, { "down", "Vers le bas" } },
                function() return fc().grow or "up" end, function(v) fc().grow = v; apply() end)
            y = y - 30
            MakeSlider(root, "Nombre max de capsules", 16, y, 1, 8, 1,
                function() return fc().maxVisible or 4 end, function(v) fc().maxVisible = v; apply() end, function(v) return tostring(v) end)
            y = y - 48
            MakeSlider(root, "Espacement", 16, y, 0, 20, 1,
                function() return fc().gap or 8 end, function(v) fc().gap = v; apply() end, function(v) return v .. " px" end)
            y = y - 48
            MakeSlider(root, "Durée normale", 16, y, 3, 60, 1,
                function() return fc().duration or 7 end, function(v) local f = fc(); f.duration = v; f.whisperDuration = math.max(f.whisperDuration or v, v); apply() end, function(v) return v .. " s" end)
            y = y - 48
            MakeSlider(root, "Durée chuchotement", 16, y, 3, 120, 1,
                function() return fc().whisperDuration or 12 end, function(v) fc().whisperDuration = v; apply() end, function(v) return v .. " s" end)
            y = y - 48
            MakeSlider(root, "Fondu entrée", 16, y, 0, 1, 0.02,
                function() return fc().fadeIn or 0.16 end, function(v) fc().fadeIn = v; apply() end, function(v) return ("%.2f s"):format(v) end)
            y = y - 48
            MakeSlider(root, "Fondu sortie", 16, y, 0, 1, 0.02,
                function() return fc().fadeOut or 0.30 end, function(v) fc().fadeOut = v; apply() end, function(v) return ("%.2f s"):format(v) end)
            y = y - 50
            MakeCheck(root, "Fermer au survol", 16, y, function() return fc().hoverDismiss ~= false end, function(v) fc().hoverDismiss = v and true or false; apply() end)
            MakeCheck(root, "Clic = répondre", 230, y, function() return fc().clickReply ~= false end, function(v) fc().clickReply = v and true or false; apply() end)
            y = y - 30
            MakeCheck(root, "Masquer si le chat affiche déjà le message", 16, y, function() return fc().hideIfChatVisible ~= false end, function(v) fc().hideIfChatVisible = v and true or false; apply() end)
            y = y - 30
            local cl = root:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            cl:SetPoint("TOPLEFT", root, "TOPLEFT", 16, y - 6); cl:SetText("|cFFAAAAAAEn combat :|r")
            MakeRadioRow(root, 80, y, { { "all", "Toujours" }, { "hide", "Masquer" }, { "only", "Seulement" } },
                function() return fc().combatMode or "all" end, function(v) fc().combatMode = v; apply() end)
            y = y - 36
            local pmove = MakeModernButton(root); pmove:SetSize(130, 22); pmove:SetPoint("TOPLEFT", root, "TOPLEFT", 16, y); pmove:SetText("Déplacer la zone")
            pmove:SetScript("OnClick", function() if SP.ChatFollow and SP.ChatFollow.SetEditMode then SP.ChatFollow:SetEditMode(fc().locked ~= false) end end)
            local preset = MakeModernButton(root); preset:SetSize(130, 22); preset:SetPoint("LEFT", pmove, "RIGHT", 8, 0); preset:SetText("Réinitialiser position")
            preset:SetScript("OnClick", function() if SP.ChatFollow and SP.ChatFollow.ResetPosition then SP.ChatFollow:ResetPosition() end end)
            y = y - 40
            root:SetHeight(-y + 30)
        end },
        { label = "Canaux", build = function(root)
            local y = SectionHeader(root, -6, "Canaux suivis — capsule affichée si activé")
            for _, t in ipairs(FOLLOW_TYPES) do
                local key, lbl = t[1], t[2]
                local cb = MakeCheck(root, "", 16, y, function() return fc().channels[key] == true end, function(v) fc().channels[key] = v and true or false; apply() end)
                local dot = root:CreateTexture(nil, "ARTWORK"); dot:SetSize(11, 11); dot:SetPoint("LEFT", cb, "RIGHT", 4, 0)
                local dr, dg, db = FollowTypeColor(key); dot:SetColorTexture(dr, dg, db)
                local name = root:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); name:SetPoint("LEFT", dot, "RIGHT", 6, 0); name:SetText(lbl)
                y = y - 26
            end
            y = y - 6
            local note = root:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
            note:SetPoint("TOPLEFT", root, "TOPLEFT", 12, y); note:SetPoint("RIGHT", root, "RIGHT", -10, 0); note:SetJustifyH("LEFT"); note:SetWordWrap(true)
            note:SetText("|cFF777777La pastille = couleur du liseré de la capsule (reprise des couleurs de canaux du module Chat).|r")
            y = y - 32
            root:SetHeight(-y + 30)
        end },
        { label = "Test", build = function(root)
            local y = SectionHeader(root, -6, "Tester le rendu")
            local b1 = MakeModernButton(root); b1:SetSize(160, 24); b1:SetPoint("TOPLEFT", root, "TOPLEFT", 16, y); b1:SetText("Tester (1 capsule)")
            b1:SetScript("OnClick", function() if SP.ChatFollow and SP.ChatFollow.Test then SP.ChatFollow:Test() end end)
            local b2 = MakeModernButton(root); b2:SetSize(160, 24); b2:SetPoint("LEFT", b1, "RIGHT", 8, 0); b2:SetText("Remplir (4 capsules)")
            b2:SetScript("OnClick", function() if SP.ChatFollow and SP.ChatFollow.Test then for _ = 1, 4 do SP.ChatFollow:Test() end end end)
            y = y - 34
            local b3 = MakeModernButton(root); b3:SetSize(160, 24); b3:SetPoint("TOPLEFT", root, "TOPLEFT", 16, y); b3:SetText("Mode édition (déplacer)")
            b3:SetScript("OnClick", function() if SP.ChatFollow and SP.ChatFollow.SetEditMode then SP.ChatFollow:SetEditMode(fc().locked ~= false) end end)
            local b4 = MakeModernButton(root); b4:SetSize(160, 24); b4:SetPoint("LEFT", b3, "RIGHT", 8, 0); b4:SetText("Réinitialiser position")
            b4:SetScript("OnClick", function() if SP.ChatFollow and SP.ChatFollow.ResetPosition then SP.ChatFollow:ResetPosition() end end)
            y = y - 42
            local note = root:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
            note:SetPoint("TOPLEFT", root, "TOPLEFT", 12, y); note:SetPoint("RIGHT", root, "RIGHT", -10, 0); note:SetJustifyH("LEFT"); note:SetWordWrap(true)
            note:SetText("|cFF777777« Tester » affiche une capsule d'exemple avec le style actuel. « Mode édition » montre la zone et permet de la glisser pour la positionner.|r")
            y = y - 44
            root:SetHeight(-y + 30)
        end },
    })
end

local function CreateOptions()
    if SP.optionsFrame then return SP.optionsFrame end

    local f = CreateFrame("Frame", "SpherePanelOptions", UIParent)
    f:SetSize(620, 560)
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
    nav:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -34); nav:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 8, 8); nav:SetWidth(150)
    local navbg = nav:CreateTexture(nil, "BACKGROUND"); navbg:SetAllPoints(nav); navbg:SetColorTexture(0, 0, 0, 0.3)
    -- nav scrollable (conteneur clippé + chariot)
    nav:SetClipsChildren(true)
    local navInner = CreateFrame("Frame", nil, nav)
    navInner:SetPoint("TOPLEFT", nav, "TOPLEFT", 0, 0); navInner:SetPoint("TOPRIGHT", nav, "TOPRIGHT", 0, 0)
    navInner:SetHeight(10)
    -- séparateur sous la barre de titre (respiration)
    local sep = f:CreateTexture(nil, "ARTWORK"); sep:SetHeight(1)
    sep:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -27); sep:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, -27)
    sep:SetColorTexture(0.29, 0.64, 1, 0.25)

    local content = CreateFrame("Frame", nil, f)
    content:SetPoint("TOPLEFT", nav, "TOPRIGHT", 12, -4); content:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -12, 10)

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
    local entries = { { "Général", "Général" }, { "Modules", "Modules" }, { "Apparence", "Apparence" }, { "Comportement", "Comportement" }, { "SuiviChat", "Suivi chat" } }
    for _, m in ipairs(SP:GetOrderedModules()) do entries[#entries + 1] = { m.name, m.label, m } end

    local y = -4
    for _, e in ipairs(entries) do
        local key, label = e[1], e[2]
        local b = CreateFrame("Button", nil, navInner); b:SetSize(136, 22); b:SetPoint("TOPLEFT", navInner, "TOPLEFT", 3, y)
        b.fs = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); b.fs:SetPoint("LEFT", b, "LEFT", 8, 0); b.fs:SetText(label)
        local hl = b:CreateTexture(nil, "HIGHLIGHT"); hl:SetAllPoints(b); hl:SetColorTexture(1, 1, 1, 0.08)
        b:SetScript("OnClick", function() f:ShowSection(key) end)
        f.navButtons[key] = b
        local page = CreateFrame("Frame", nil, content); page:SetAllPoints(content); page:Hide()
        f.pages[key] = page
        if e[3] then BuildModulePage(page, e[3]) end
        y = y - 25
    end
    navInner:SetHeight(-y + 6)

    -- ===== chariot de défilement de la nav =====
    local track = CreateFrame("Frame", nil, nav); track:SetWidth(5)
    track:SetPoint("TOPRIGHT", nav, "TOPRIGHT", -1, -3); track:SetPoint("BOTTOMRIGHT", nav, "BOTTOMRIGHT", -1, 3)
    local tbg = track:CreateTexture(nil, "BACKGROUND"); tbg:SetAllPoints(track); tbg:SetColorTexture(1, 1, 1, 0.06)
    local thumb = CreateFrame("Button", nil, track); thumb:SetWidth(5); thumb:SetPoint("TOP", track, "TOP", 0, 0)
    local thtex = thumb:CreateTexture(nil, "ARTWORK"); thtex:SetAllPoints(thumb); thtex:SetColorTexture(0.29, 0.64, 1, 0.7)
    nav._scroll = 0
    local function applyScroll(s)
        local vis = nav:GetHeight() or 1
        local content = navInner:GetHeight()
        local maxS = math.max(0, content - vis)
        nav._scroll = math.min(maxS, math.max(0, s or 0))
        navInner:ClearAllPoints()
        navInner:SetPoint("TOPLEFT", nav, "TOPLEFT", 0, nav._scroll)
        navInner:SetPoint("TOPRIGHT", nav, "TOPRIGHT", 0, nav._scroll)
        -- chariot
        if content <= vis + 1 then track:Hide(); return end
        track:Show()
        local trackH = track:GetHeight() or 1
        local th = math.max(24, trackH * vis / content)
        thumb:SetHeight(th)
        local frac = (maxS > 0) and (nav._scroll / maxS) or 0
        thumb:ClearAllPoints(); thumb:SetPoint("TOP", track, "TOP", 0, -frac * (trackH - th))
    end
    nav:EnableMouseWheel(true)
    nav:SetScript("OnMouseWheel", function(_, d) applyScroll((nav._scroll or 0) - d * 40) end)
    thumb:RegisterForDrag("LeftButton")
    thumb:SetScript("OnMouseDown", function(s)
        local sc = nav:GetEffectiveScale(); local _, cy = GetCursorPosition()
        s._grabOff = (s:GetTop() or 0) - cy / sc; s._drag = true
    end)
    thumb:SetScript("OnMouseUp", function(s) s._drag = false end)
    thumb:SetScript("OnUpdate", function(s)
        if not s._drag then return end
        local sc = nav:GetEffectiveScale(); local _, cy = GetCursorPosition(); cy = cy / sc
        local trackTop, trackH, th = track:GetTop() or 0, track:GetHeight() or 1, s:GetHeight() or 1
        local off = math.max(0, math.min(trackH - th, trackTop - (cy + s._grabOff)))
        local frac = off / math.max(1, trackH - th)
        applyScroll(frac * math.max(0, navInner:GetHeight() - (nav:GetHeight() or 1)))
    end)
    f._navApplyScroll = applyScroll
    C_Timer.After(0, function() applyScroll(0) end)

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
    BuildSuiviChat(f.pages["SuiviChat"])

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
