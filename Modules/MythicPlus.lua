-- ============================================================
-- Module : MythicPlus ("Clés / Donjon") — deux visages
--   • HORS instance : ma clé, affixes de la semaine, meilleur hebdo (coffre).
--   • EN instance   : objectifs (boss + forces ennemies %), timer M+, +2/+3, morts.
-- S'ajuste automatiquement (normal / HM / M / M+). Inspiré d'AngryKeystones
-- (C_Scenario / C_ScenarioInfo / C_ChallengeMode / GetWorldElapsedTime / GetDeathCount).
-- ============================================================
local ADDON_NAME, SP = ...

local M = { name = "MythicPlus", label = "Clés", defaultHeight = 90 }

local ROW = 15
local CHECK = "|cFF40FF40|A:common-icon-checkmark:12:12:0:0|a|r"
local CROSS = "|cFF888888|A:common-icon-redx:12:12:0:0|a|r"

local function fmtTime(sec)
    sec = math.max(0, math.floor(sec or 0))
    return ("%d:%02d"):format(math.floor(sec / 60), sec % 60)
end

function M:Init(body)
    self.body = body
    self.lines = {}
    self.ev = CreateFrame("Frame")
    self.ev:SetScript("OnEvent", function() self:RequestRefresh() end)
end

function M:Enable()
    self._enabled = true
    if self._placeholder then self._placeholder:Hide() end
    for _, e in ipairs({
        "CHALLENGE_MODE_START", "CHALLENGE_MODE_COMPLETED", "CHALLENGE_MODE_RESET",
        "MYTHIC_PLUS_CURRENT_AFFIX_UPDATE", "BAG_UPDATE_DELAYED", "PLAYER_ENTERING_WORLD",
        "SCENARIO_CRITERIA_UPDATE", "SCENARIO_UPDATE", "ENCOUNTER_END", "ZONE_CHANGED_NEW_AREA",
    }) do
        pcall(self.ev.RegisterEvent, self.ev, e)
    end
    if C_MythicPlus then
        pcall(C_MythicPlus.RequestCurrentAffixes)
        pcall(C_MythicPlus.RequestMapInfo)
    end
    if not self._ticker then
        self._ticker = C_Timer.NewTicker(1, function() if self._inRun then self:Refresh() end end)
    end
    self:RequestRefresh()
end

function M:Disable()
    self._enabled = false
    if self.ev then self.ev:UnregisterAllEvents() end
    if self._ticker then self._ticker:Cancel(); self._ticker = nil end
    for _, fs in ipairs(self.lines) do fs:Hide() end
    SP:SetModuleHeaderText(self, "")
end

function M:OnResize(w, h) end

function M:RequestRefresh()
    if not self._enabled or self._pending then return end
    self._pending = true
    C_Timer.After(0.25, function() self._pending = false; self:Refresh() end)
end

function M:_Line(i)
    local fs = self.lines[i]
    if not fs then
        fs = self.body:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        fs:SetPoint("RIGHT", self.body, "RIGHT", -6, 0)
        fs:SetJustifyH("LEFT"); fs:SetWordWrap(false)
        self.lines[i] = fs
    end
    return fs
end

-- ============================================================
function M:Refresh()
    if not self._enabled or not self.body then return end
    self._n = 0
    local y = 4
    local function line(txt)
        self._n = self._n + 1
        local fs = self:_Line(self._n)
        fs:ClearAllPoints()
        fs:SetPoint("TOPLEFT", self.body, "TOPLEFT", 6, -y)
        fs:SetPoint("RIGHT", self.body, "RIGHT", -6, 0)
        fs:SetText(txt or ""); fs:Show()
        y = y + ROW
    end

    local inChallenge = C_ChallengeMode and C_ChallengeMode.GetActiveChallengeMapID and C_ChallengeMode.GetActiveChallengeMapID()
    local inInstance, instType = IsInInstance()
    self._inRun = inChallenge and true or false

    if inChallenge then
        self:RenderMythicPlus(line, inChallenge)
    elseif inInstance and instType == "party" then
        self:RenderDungeon(line)
    else
        self:RenderOverview(line)
    end

    for i = self._n + 1, #self.lines do self.lines[i]:Hide() end
    SP:SetAutoHeight(self, math.max(40, y + 2))
end

-- ----- Mythique+ (run en cours) -----
function M:RenderMythicPlus(line, mapID)
    local name, _, timeLimit = C_ChallengeMode.GetMapUIInfo(mapID)
    local level = C_ChallengeMode.GetActiveKeystoneInfo and C_ChallengeMode.GetActiveKeystoneInfo() or 0
    line(("|cFFA335EE%s +%d|r"):format(name or "Donjon", level or 0))
    SP:SetModuleHeaderText(self, ("+%d"):format(level or 0))

    -- timer + jalons +2/+3
    local elapsed = 0
    local ok, _, e = pcall(GetWorldElapsedTime, 1); if ok and e then elapsed = e end
    if timeLimit and timeLimit > 0 then
        local remain = timeLimit - elapsed
        local col = remain > 0 and "FF40FF40" or "FFFF4040"
        line(("|cFFFFD200Temps :|r |c%s%s|r / %s"):format(col, fmtTime(elapsed), fmtTime(timeLimit)))
        local t3, t2 = timeLimit * 0.6 - elapsed, timeLimit * 0.8 - elapsed
        line(("|cFFFFD200+3|r %s   |cFFFFD200+2|r %s")
            :format(t3 > 0 and fmtTime(t3) or "|cFFFF4040raté|r", t2 > 0 and fmtTime(t2) or "|cFFFF4040raté|r"))
    else
        line(("|cFFFFD200Temps :|r %s"):format(fmtTime(elapsed)))
    end

    self:RenderCriteria(line)

    local deaths, timeLost = 0, 0
    if C_ChallengeMode.GetDeathCount then local d, t = C_ChallengeMode.GetDeathCount(); deaths, timeLost = d or 0, t or 0 end
    line(("|cFFFFD200Morts :|r %d%s"):format(deaths, (timeLost and timeLost > 0) and (" |cFFFF4040(+" .. fmtTime(timeLost) .. ")|r") or ""))
end

-- ----- Donjon normal / HM / M0 -----
function M:RenderDungeon(line)
    local name, _, diff = GetInstanceInfo()
    line(("|cFFFF8000%s|r |cFF888888%s|r"):format(name or "Donjon", diff or ""))
    SP:SetModuleHeaderText(self, "")
    self:RenderCriteria(line)
end

-- objectifs du scénario (boss + forces ennemies) — communs M+/donjon scénarisé
function M:RenderCriteria(line)
    if not (C_Scenario and C_Scenario.GetStepInfo) then return end
    local _, _, numCriteria = C_Scenario.GetStepInfo()
    if not numCriteria or numCriteria == 0 then return end
    local getC = C_ScenarioInfo and C_ScenarioInfo.GetCriteriaInfo or C_Scenario.GetCriteriaInfo
    for i = 1, numCriteria do
        local ok, c = pcall(getC, i)
        if ok and c then
            if c.isWeightedProgress then
                line(("|cFFFFD200Forces :|r %s"):format(c.quantityString or "0%"))
            else
                line((c.completed and CHECK or CROSS) .. " " .. (c.description or "?"))
            end
        end
    end
end

-- ----- Vue d'ensemble (hors instance) -----
function M:RenderOverview(line)
    if not C_MythicPlus then line("|cFF888888API M+ indisponible.|r"); return end
    local mapID = C_MythicPlus.GetOwnedKeystoneChallengeMapID and C_MythicPlus.GetOwnedKeystoneChallengeMapID()
    local lvl = C_MythicPlus.GetOwnedKeystoneLevel and C_MythicPlus.GetOwnedKeystoneLevel()
    if mapID and lvl and lvl > 0 then
        local name = C_ChallengeMode and C_ChallengeMode.GetMapUIInfo and C_ChallengeMode.GetMapUIInfo(mapID)
        line(("|cFFFFD200Ma clé :|r |cFFA335EE%s +%d|r"):format(name or "?", lvl))
        SP:SetModuleHeaderText(self, ("+%d"):format(lvl))
    else
        line("|cFFFFD200Ma clé :|r |cFF888888aucune|r")
        SP:SetModuleHeaderText(self, "")
    end
    local affs = C_MythicPlus.GetCurrentAffixes and C_MythicPlus.GetCurrentAffixes()
    if affs and #affs > 0 then
        local parts = {}
        for _, a in ipairs(affs) do
            local an = C_ChallengeMode.GetAffixInfo and C_ChallengeMode.GetAffixInfo(a.id)
            if an then parts[#parts + 1] = an end
        end
        if #parts > 0 then line("|cFFFFD200Affixes :|r " .. table.concat(parts, ", ")) end
    end
    local weekly = C_MythicPlus.GetWeeklyChestRewardLevel and C_MythicPlus.GetWeeklyChestRewardLevel()
    if weekly and weekly > 0 then line(("|cFFFFD200Hebdo :|r meilleur +%d"):format(weekly)) end
end

SP:RegisterModule(M)
