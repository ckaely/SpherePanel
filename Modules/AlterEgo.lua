-- ============================================================
-- Module : AlterEgo ("Personnages") — infos multi-persos depuis AlterEgoDB
-- ============================================================
-- Un personnage affiché à la fois ; MOLETTE sur le bandeau du module = personnage
-- suivant/précédent (le nom coloré classe s'affiche dans le bandeau).
-- Lignes : iLvl, cote M+, clé, or, Grand Coffre, runs de la semaine.
-- Requiert : AlterEgo (lecture de sa base SavedVariables).
local ADDON_NAME, SP = ...

local M = { name = "AlterEgo", label = "Personnages", defaultHeight = 120 }

local ROW = 16

local function GetChars()
    local db = _G.AlterEgoDB
    local chars = db and db.global and db.global.characters
    if not chars then return {} end
    local list = {}
    for _, c in pairs(chars) do
        if c.info and c.info.name and c.info.name ~= "" then list[#list + 1] = c end
    end
    table.sort(list, function(a, b)
        if (a.order or 0) ~= (b.order or 0) then return (a.order or 0) < (b.order or 0) end
        return (a.lastUpdate or 0) > (b.lastUpdate or 0)
    end)
    return list
end

local function classHex(c)
    local file = c.info and c.info.class and c.info.class.file
    local col = file and RAID_CLASS_COLORS and RAID_CLASS_COLORS[file]
    if col then return ("|cff%02x%02x%02x"):format(col.r * 255, col.g * 255, col.b * 255) end
    return "|cffffffff"
end

function M:Init(body)
    self.body = body
    self.idx = 1
    self.lines = {}
    for i = 1, 7 do
        local fs = body:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        fs:SetPoint("TOPLEFT", body, "TOPLEFT", 6, -4 - (i - 1) * ROW)
        fs:SetPoint("RIGHT", body, "RIGHT", -6, 0)
        fs:SetJustifyH("LEFT")
        self.lines[i] = fs
    end
    -- molette sur le bandeau = changer de personnage
    if self.header then
        self.header:EnableMouseWheel(true)
        self.header:SetScript("OnMouseWheel", function(_, delta)
            local n = #GetChars()
            if n == 0 then return end
            self.idx = ((self.idx - 1 - delta) % n) + 1
            self:Refresh()
        end)
    end
    self.ev = CreateFrame("Frame")
    self.ev:SetScript("OnEvent", function() self:RequestRefresh() end)
end

function M:Enable()
    self._enabled = true
    if self._placeholder then self._placeholder:Hide() end
    pcall(self.ev.RegisterEvent, self.ev, "PLAYER_ENTERING_WORLD")
    self:RequestRefresh()
end

function M:Disable()
    self._enabled = false
    if self.ev then self.ev:UnregisterAllEvents() end
    SP:SetModuleHeaderText(self, "")
end

function M:OnResize(w, h) end

function M:RequestRefresh()
    if not self._enabled or self._pending then return end
    self._pending = true
    C_Timer.After(0.3, function() self._pending = false; self:Refresh() end)
end

function M:Refresh()
    if not self._enabled then return end
    local L = self.lines
    for _, fs in ipairs(L) do fs:SetText("") end

    local chars = GetChars()
    if #chars == 0 then
        L[1]:SetText("|cFFFF7777Requiert : AlterEgo|r |cFF888888(aucune donnée)|r")
        SP:SetModuleHeaderText(self, "")
        return
    end
    if self.idx > #chars then self.idx = 1 end
    local c = chars[self.idx]
    local hex = classHex(c)

    -- bandeau : nom coloré + position dans la liste (molette pour changer)
    SP:SetModuleHeaderText(self, ("%s%s|r |cFF888888%d/%d|r"):format(hex, c.info.name, self.idx, #chars))

    local i = 0
    local function line(txt) i = i + 1; if L[i] then L[i]:SetText(txt) end end

    line(("%s%s|r-|cFFAAAAAA%s|r  niv. %d"):format(hex, c.info.name, c.info.realm or "?", c.info.level or 0))

    local ilvl = c.info.ilvl and (c.info.ilvl.equipped or c.info.ilvl.level)
    local mp = c.mythicplus or {}
    line(("|cFFFFD200iLvl :|r %s   |cFFFFD200Cote M+ :|r %s")
        :format(ilvl and ("%.0f"):format(ilvl) or "?", tostring(mp.rating or 0)))

    local ks = mp.keystone
    if ks and (ks.level or 0) > 0 then
        local mapName = ks.mapId and C_ChallengeMode and C_ChallengeMode.GetMapUIInfo
            and C_ChallengeMode.GetMapUIInfo(ks.challengeModeID or 0)
        line(("|cFFFFD200Clé :|r |cFFA335EE%s +%d|r"):format(mapName or "?", ks.level))
    else
        line("|cFFFFD200Clé :|r |cFF888888aucune|r")
    end

    if c.money and c.money > 0 then
        line(("|cFFFFD200Or :|r %s"):format(GetMoneyString and GetMoneyString(c.money, true) or tostring(math.floor(c.money / 10000))))
    end

    -- Grand Coffre (si AlterEgo a stocké les activités)
    local v = c.vault and (c.vault.slots or c.vault.activities)
    if type(v) == "table" and #v > 0 then
        local done = 0
        for _, slot in ipairs(v) do
            if (slot.progress or 0) >= (slot.threshold or 1) then done = done + 1 end
        end
        line(("|cFFFFD200Grand Coffre :|r %d/%d emplacements"):format(done, #v))
    end

    local runs = mp.numCompletedDungeonRuns
    if runs then
        line(("|cFFFFD200Runs semaine :|r M+ %d  |cFF888888(M0 %d, HM %d)|r")
            :format(runs.mythicPlus or 0, runs.mythic or 0, runs.heroic or 0))
    end

    line("|cFF666666Molette sur le bandeau = personnage suivant|r")
end

SP:RegisterModule(M)
