-- ============================================================
-- Module : Raid - cadres de groupe/raid cliquables
-- ============================================================
local ADDON_NAME, SP = ...

local M = {
    name = "Raid",
    label = "Groupe",
    defaultHeight = 180,
    secureChildren = true,
}

local MEDIA = "Interface\\AddOns\\SphereNameplates\\media\\"
local BAR_DIR = MEDIA .. "bar_raid\\"
local FLAG_DIR = MEDIA .. "Flag\\"
local BAR_H, GAP = 20, 2

local ROLE_ORDER = { TANK = 1, HEALER = 2, DAMAGER = 3, NONE = 4 }
local ROLE_ICON = {
    TANK = "|A:roleicon-tiny-tank:12:12|a ",
    HEALER = "|A:roleicon-tiny-healer:12:12|a ",
    DAMAGER = "|A:roleicon-tiny-dps:12:12|a ",
    NONE = "",
}
local ROLE_LABEL = { TANK = "Tank", HEALER = "Soigneurs", DAMAGER = "DPS", NONE = "Sans role" }

local REGION_FALLBACK = {
    [1] = "american.tga", [2] = "american.tga", [3] = "british.tga", [4] = "oceanic.tga", [5] = "american.tga",
}

local REALM_FLAGS = {
    -- FR
    ["archimonde"] = "french.tga", ["hyjal"] = "french.tga", ["dalaran"] = "french.tga", ["elune"] = "french.tga",
    ["eitrigg"] = "french.tga", ["ysondre"] = "french.tga", ["illidan"] = "french.tga", ["chogall"] = "french.tga",
    ["cho'gall"] = "french.tga", ["voljin"] = "french.tga", ["vol'jin"] = "french.tga", ["kaelthas"] = "french.tga",
    ["kael'thas"] = "french.tga", ["kirintor"] = "french.tga", ["kirin tor"] = "french.tga", ["medivh"] = "french.tga",
    ["nerzhul"] = "french.tga", ["ner'zhul"] = "french.tga", ["suramar"] = "french.tga", ["khazmodan"] = "french.tga",
    ["khaz modan"] = "french.tga",
    -- DE
    ["antonidas"] = "german.tga", ["blackhand"] = "german.tga", ["eredar"] = "german.tga", ["frostwolf"] = "german.tga",
    ["blackmoore"] = "german.tga", ["aegwynn"] = "german.tga", ["arthas"] = "german.tga", ["azshara"] = "german.tga",
    ["destromath"] = "german.tga", ["malganis"] = "german.tga", ["mal'ganis"] = "german.tga", ["mannoroth"] = "german.tga",
    ["nozdormu"] = "german.tga", ["proudmoore"] = "german.tga",
    -- ES/IT/RU
    ["dunmodr"] = "spanish.tga", ["dun modr"] = "spanish.tga", ["cthun"] = "spanish.tga", ["c'thun"] = "spanish.tga",
    ["sanguino"] = "spanish.tga", ["uldum"] = "spanish.tga", ["zuljin"] = "spanish.tga", ["zul'jin"] = "spanish.tga",
    ["exodar"] = "spanish.tga", ["tyrande"] = "spanish.tga", ["minahonda"] = "spanish.tga", ["loserrantes"] = "spanish.tga",
    ["los errantes"] = "spanish.tga", ["pozzo delleternita"] = "italian.tga", ["pozzo dell'eternita"] = "italian.tga",
    ["gordunni"] = "russian.tga", ["howlingfjord"] = "russian.tga", ["howling fjord"] = "russian.tga",
    ["soulflayer"] = "russian.tga", ["soul flayer"] = "russian.tga", ["deepholm"] = "russian.tga",
    -- US/Oceanic/LatAm/BR
    ["frostmourne"] = "oceanic.tga", ["barthilas"] = "oceanic.tga", ["jubeithos"] = "oceanic.tga", ["jubei'thos"] = "oceanic.tga",
    ["ragnaros"] = "mexican.tga", ["quelthalas"] = "mexican.tga", ["quel'thalas"] = "mexican.tga", ["drakkari"] = "mexican.tga",
    ["azralon"] = "brazilian.tga", ["goldrinn"] = "brazilian.tga", ["gallywix"] = "brazilian.tga", ["tolbarad"] = "brazilian.tga",
    ["tol barad"] = "brazilian.tga", ["nemesis"] = "brazilian.tga",
}

local EVENTS = {
    "GROUP_ROSTER_UPDATE", "PLAYER_ENTERING_WORLD", "PLAYER_ROLES_ASSIGNED",
    "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_CONNECTION", "UNIT_NAME_UPDATE",
    "UNIT_FLAGS", "PLAYER_REGEN_ENABLED",
}

local function CleanRealm(s)
    s = (s or ""):lower():gsub("%s+", " "):gsub("[%-']", "")
    return s
end

local function UnitRealm(unit)
    local name, realm = UnitFullName(unit)
    if not realm or realm == "" then realm = GetRealmName and GetRealmName() end
    return realm or "", name or UnitName(unit) or unit
end

local function FlagForUnit(unit)
    local realm = UnitRealm(unit)
    local key = CleanRealm(realm)
    local direct = REALM_FLAGS[key]
    if direct then return FLAG_DIR .. direct end
    local locale = GetLocale and GetLocale()
    if locale == "frFR" then return FLAG_DIR .. "french.tga" end
    if locale == "deDE" then return FLAG_DIR .. "german.tga" end
    if locale == "esES" or locale == "esMX" then return FLAG_DIR .. "spanish.tga" end
    if locale == "itIT" then return FLAG_DIR .. "italian.tga" end
    if locale == "ruRU" then return FLAG_DIR .. "russian.tga" end
    local region = GetCurrentRegion and GetCurrentRegion()
    return FLAG_DIR .. (REGION_FALLBACK[region] or "british.tga")
end

local function GroupIndex(unit)
    if UnitInRaid and UnitInRaid(unit) then
        local _, _, subgroup = GetRaidRosterInfo(UnitInRaid(unit))
        return subgroup or 1
    end
    return 1
end

local function UnitRole(unit)
    local role = UnitGroupRolesAssigned and UnitGroupRolesAssigned(unit) or "NONE"
    if role == "HEALER" or role == "TANK" or role == "DAMAGER" then return role end
    return "NONE"
end

local function SeparateBy(cfg)
    return (cfg and cfg.separateBy == "role") and "role" or "group"
end

local function BuildUnits(cfg)
    local units = {}
    if not IsInGroup() then return units end
    local n = GetNumGroupMembers() or 0
    if IsInRaid() then
        for i = 1, n do units[#units + 1] = "raid" .. i end
    else
        units[#units + 1] = "player"
        for i = 1, n - 1 do units[#units + 1] = "party" .. i end
    end
    table.sort(units, function(a, b)
        local ga, gb = GroupIndex(a), GroupIndex(b)
        if SeparateBy(cfg) == "role" then
            local ra, rb = ROLE_ORDER[UnitRole(a)] or 4, ROLE_ORDER[UnitRole(b)] or 4
            if ra ~= rb then return ra < rb end
            if ga ~= gb then return ga < gb end
        else
            if ga ~= gb then return ga < gb end
            local ra, rb = ROLE_ORDER[UnitRole(a)] or 4, ROLE_ORDER[UnitRole(b)] or 4
            if ra ~= rb then return ra < rb end
        end
        return (UnitName(a) or a) < (UnitName(b) or b)
    end)
    return units
end

local function SectionForUnit(unit, cfg)
    if SeparateBy(cfg) == "role" then
        local role = UnitRole(unit)
        return role, ROLE_LABEL[role] or "Sans role"
    end
    local group = GroupIndex(unit)
    return group, "Groupe " .. tostring(group)
end

local function RoleSummary(units)
    local n = { TANK = 0, HEALER = 0, DAMAGER = 0 }
    for _, unit in ipairs(units or {}) do
        local role = UnitRole(unit)
        if n[role] ~= nil then n[role] = n[role] + 1 end
    end
    return ("%d %s  %d %s  %d %s"):format(
        n.TANK, ROLE_ICON.TANK,
        n.HEALER, ROLE_ICON.HEALER,
        n.DAMAGER, ROLE_ICON.DAMAGER
    )
end

local function TexturePath(cfg)
    local t = cfg.barTexture or "bar_serenity.tga"
    if t:find("[/\\]") then return t end
    return BAR_DIR .. t
end

local function HideBlizzardRaid(self)
    local cfg = SP:GetModuleConfig(self.name)
    if not cfg.hideBlizzard then return end
    if InCombatLockdown() then self._hideBlizzPending = true; return end
    for _, f in ipairs({ CompactRaidFrameManager, CompactRaidFrameContainer, CompactPartyFrame }) do
        if f then pcall(f.Hide, f) end
    end
    if not self._hideHooked then
        self._hideHooked = true
        for _, f in ipairs({ CompactRaidFrameManager, CompactRaidFrameContainer, CompactPartyFrame }) do
            if f then
                hooksecurefunc(f, "Show", function(s)
                    local c = SP:GetModuleConfig(self.name)
                    if self._enabled and c and c.hideBlizzard and not InCombatLockdown() then pcall(s.Hide, s) end
                end)
            end
        end
    end
end

local function RestoreBlizzardRaid()
    if InCombatLockdown() then return end
    for _, f in ipairs({ CompactRaidFrameManager, CompactRaidFrameContainer, CompactPartyFrame }) do
        if f then pcall(f.RegisterEvent, f, "GROUP_ROSTER_UPDATE"); pcall(f.Show, f) end
    end
end

local function CreateBar(self, i)
    local b = CreateFrame("Button", "SpherePanelRaidUnit" .. i, self.body, "SecureUnitButtonTemplate")
    b:RegisterForClicks("AnyUp")
    b:SetAttribute("type", "target")
    b:SetAttribute("*type1", "target")
    b:SetAttribute("type1", "target")
    b:SetAttribute("type2", "togglemenu")
    b:SetHeight(BAR_H)
    b.bg = b:CreateTexture(nil, "BACKGROUND"); b.bg:SetAllPoints(b); b.bg:SetColorTexture(0, 0, 0, 0.58)
    b.status = CreateFrame("StatusBar", nil, b)
    b.status:SetPoint("TOPLEFT", b, "TOPLEFT", 0, 0)
    b.status:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 0, 0)
    b.status:SetMinMaxValues(0, 1)
    b.status:SetValue(1)
    b.status:SetFrameLevel((b:GetFrameLevel() or 0) + 1)
    b.status:EnableMouse(false)
    b.fill = b.status:GetStatusBarTexture()
    b.shine = b:CreateTexture(nil, "OVERLAY"); b.shine:SetAllPoints(b); b.shine:SetColorTexture(1, 1, 1, 0.07)
    b.textLayer = CreateFrame("Frame", nil, b)
    b.textLayer:SetAllPoints(b)
    b.textLayer:SetFrameLevel((b.status:GetFrameLevel() or 1) + 1)
    b.textLayer:EnableMouse(false)
    b.role = b.textLayer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    b.role:SetPoint("LEFT", b.textLayer, "LEFT", 4, 0)
    b.flag = b.textLayer:CreateTexture(nil, "OVERLAY")
    b.flag:SetSize(15, 10)
    b.flag:SetPoint("LEFT", b.role, "RIGHT", 2, 0)
    b.name = b.textLayer:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    b.name:SetPoint("LEFT", b.flag, "RIGHT", 4, 0)
    b.name:SetPoint("RIGHT", b.textLayer, "RIGHT", -38, 0)
    b.name:SetJustifyH("LEFT")
    b.hp = b.textLayer:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    b.hp:SetPoint("RIGHT", b.textLayer, "RIGHT", -4, 0)
    b.hp:SetJustifyH("RIGHT")
    b:SetScript("OnEnter", function(s)
        if s.unit and UnitExists(s.unit) then
            GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
            GameTooltip:SetUnit(s.unit)
            GameTooltip:Show()
        end
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return b
end

local function CreateSeparator(self, i)
    local s = CreateFrame("Frame", nil, self.body)
    s:SetHeight(16)
    s.fs = s:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    s.fs:SetPoint("LEFT", s, "LEFT", 4, 0)
    s.line = s:CreateTexture(nil, "ARTWORK")
    s.line:SetHeight(1)
    s.line:SetPoint("LEFT", s.fs, "RIGHT", 8, 0)
    s.line:SetPoint("RIGHT", s, "RIGHT", -4, 0)
    s.line:SetColorTexture(0.55, 0.36, 0.95, 0.38)
    return s
end

function M:ApplyFonts()
    for _, b in ipairs(self.bars or {}) do
        SP:ApplyFontToObject(b.name, self.name, 0, "OUTLINE")
        SP:ApplyFontToObject(b.hp, self.name, -1, "OUTLINE")
        SP:ApplyFontToObject(b.role, self.name, 0, "OUTLINE")
    end
    for _, s in ipairs(self.seps or {}) do SP:ApplyFontToObject(s.fs, self.name, 0, "OUTLINE") end
end

local function UpdateBar(self, b)
    local unit = b.unit
    if not unit or not UnitExists(unit) then b:Hide(); return end
    local cfg = SP:GetModuleConfig(self.name)
    local name, realm = UnitName(unit), select(2, UnitFullName(unit))
    local _, class = UnitClass(unit)
    local c = (class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]) or { r = 0.55, g = 0.60, b = 0.65 }
    local pctText = ""
    local okPct = pcall(function()
        local maxHp = math.max(1, UnitHealthMax(unit) or 1)
        local hp = UnitHealth(unit) or 0
        local pct = math.max(0, math.min(1, hp / maxHp))
        pctText = ("%d%%"):format(pct * 100)
    end)
    b.status:SetStatusBarTexture(TexturePath(cfg))
    b.status:SetStatusBarColor(c.r, c.g, c.b, UnitIsConnected(unit) and 0.92 or 0.38)
    local okBar = pcall(function()
        b.status:SetMinMaxValues(0, UnitHealthMax(unit) or 1)
        b.status:SetValue(UnitHealth(unit) or 0)
    end)
    if not okBar then
        b.status:SetMinMaxValues(0, 1)
        b.status:SetValue(1)
        b.status:SetStatusBarColor(c.r, c.g, c.b, UnitIsConnected(unit) and 0.55 or 0.28)
    end
    b.role:SetText(ROLE_ICON[UnitRole(unit)] or "")
    b.flag:SetShown(cfg.showFlags ~= false)
    if cfg.showFlags ~= false then b.flag:SetTexture(FlagForUnit(unit)) end
    if UnitIsDeadOrGhost(unit) then
        b.name:SetText("|cFFAAAAAA" .. (name or unit) .. " mort|r")
    elseif not UnitIsConnected(unit) then
        b.name:SetText("|cFF777777" .. (name or unit) .. " hors ligne|r")
    else
        b.name:SetText(name or unit)
    end
    b.hp:SetText(okPct and pctText or "")
    b:Show()
end

function M:Init(body)
    self.body = body
    self.bars, self.seps, self.unitToBar = {}, {}, {}
    self.emptyText = body:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    self.emptyText:SetPoint("TOP", body, "TOP", 0, -8)
    self.emptyText:SetText("Hors groupe")
    self.emptyText:Hide()
    self.ev = CreateFrame("Frame")
    self.ev:SetScript("OnEvent", function(_, event, unit)
        if event == "PLAYER_REGEN_ENABLED" and self._hideBlizzPending then
            self._hideBlizzPending = nil
            HideBlizzardRaid(self)
        end
        if unit and self.unitToBar[unit] and (event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" or event == "UNIT_CONNECTION") then
            UpdateBar(self, self.unitToBar[unit])
        else
            self:Rebuild()
        end
    end)
end

function M:Enable()
    self._enabled = true
    self:Prewarm(40)
    for _, e in ipairs(EVENTS) do pcall(self.ev.RegisterEvent, self.ev, e) end
    if self._placeholder then self._placeholder:Hide() end
    HideBlizzardRaid(self)
    self:Rebuild()
end

function M:Disable()
    self._enabled = false
    if self.ev then self.ev:UnregisterAllEvents() end
    for _, b in ipairs(self.bars) do b:Hide() end
    RestoreBlizzardRaid()
end

function M:Prewarm(n)
    if InCombatLockdown() then return end
    for i = #self.bars + 1, n do self.bars[i] = CreateBar(self, i) end
    self:ApplyFonts()
end

function M:AcquireSep()
    local idx = (self._sepUsed or 0) + 1
    self._sepUsed = idx
    if not self.seps[idx] then self.seps[idx] = CreateSeparator(self, idx); self:ApplyFonts() end
    return self.seps[idx]
end

function M:Rebuild()
    if not self._enabled or not self.body then return end
    local cfg = SP:GetModuleConfig(self.name)
    if cfg.hideBlizzard then HideBlizzardRaid(self) else RestoreBlizzardRaid() end
    if InCombatLockdown() and self._layoutDone then
        self._rebuildPending = true
        for _, b in ipairs(self.bars or {}) do if b:IsShown() then UpdateBar(self, b) end end
        return
    end
    local units = BuildUnits(cfg)
    wipe(self.unitToBar)
    if self.emptyText then self.emptyText:SetShown(#units == 0) end
    self._sepUsed = 0
    local y, used, lastSection = 2, 0, nil
    local w = self.body:GetWidth() or 260
    for _, unit in ipairs(units) do
        local sectionKey, sectionLabel = SectionForUnit(unit, cfg)
        if sectionKey ~= lastSection then
            local sep = self:AcquireSep()
            sep.fs:SetText("|cFFB389FF" .. sectionLabel .. "|r")
            sep:ClearAllPoints()
            sep:SetPoint("TOPLEFT", self.body, "TOPLEFT", 2, -y)
            sep:SetPoint("TOPRIGHT", self.body, "TOPRIGHT", -2, -y)
            sep:Show()
            y = y + 16 + ((lastSection ~= nil) and 3 or 0)
            lastSection = sectionKey
        end
        used = used + 1
        local b = self.bars[used]
        if not b then
            if InCombatLockdown() then break end
            b = CreateBar(self, used)
            self.bars[used] = b
            self:ApplyFonts()
        end
        b.unit = unit
        self.unitToBar[unit] = b
        if not InCombatLockdown() then b:SetAttribute("unit", unit) end
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", self.body, "TOPLEFT", 2, -y)
        b:SetPoint("TOPRIGHT", self.body, "TOPRIGHT", -2, -y)
        b:SetWidth(math.max(40, (self.body:GetWidth() or w) - 4))
        b:SetHeight(BAR_H)
        UpdateBar(self, b)
        y = y + BAR_H + GAP
    end
    for i = used + 1, #self.bars do self.bars[i]:Hide() end
    for i = (self._sepUsed or 0) + 1, #self.seps do self.seps[i]:Hide() end
    SP:SetModuleHeaderText(self, #units > 0 and RoleSummary(units) or "")
    SP:SetAutoHeight(self, math.max(BAR_H + 4, y + 2))
    self._layoutDone = true
    self._rebuildPending = nil
end

function M:OnResize(w, h)
    self:Rebuild()
end

SP:RegisterModule(M)
