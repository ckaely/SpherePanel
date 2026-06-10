-- ============================================================
-- Module : MythicPlus ("Clés") — clé, affixes, meilleur hebdo, run en cours
-- ============================================================
local ADDON_NAME, SP = ...

local M = { name = "MythicPlus", label = "Clés", defaultHeight = 90 }

local ROW = 16

function M:Init(body)
    self.body = body
    self.lines = {}
    for i = 1, 5 do
        local fs = body:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        fs:SetPoint("TOPLEFT", body, "TOPLEFT", 6, -4 - (i - 1) * ROW)
        fs:SetPoint("RIGHT", body, "RIGHT", -6, 0)
        fs:SetJustifyH("LEFT")
        self.lines[i] = fs
    end
    self.ev = CreateFrame("Frame")
    self.ev:SetScript("OnEvent", function() self:RequestRefresh() end)
end

function M:Enable()
    self._enabled = true
    if self._placeholder then self._placeholder:Hide() end
    for _, e in ipairs({ "CHALLENGE_MODE_START", "CHALLENGE_MODE_COMPLETED", "CHALLENGE_MODE_RESET",
                         "MYTHIC_PLUS_CURRENT_AFFIX_UPDATE", "BAG_UPDATE_DELAYED", "PLAYER_ENTERING_WORLD" }) do
        pcall(self.ev.RegisterEvent, self.ev, e)
    end
    if C_MythicPlus then
        pcall(C_MythicPlus.RequestCurrentAffixes)
        pcall(C_MythicPlus.RequestMapInfo)
    end
    -- timer du run en cours
    if not self._ticker then
        self._ticker = C_Timer.NewTicker(1, function()
            if self._inRun then self:Refresh() end
        end)
    end
    self:RequestRefresh()
end

function M:Disable()
    self._enabled = false
    if self.ev then self.ev:UnregisterAllEvents() end
    if self._ticker then self._ticker:Cancel(); self._ticker = nil end
    SP:SetModuleHeaderText(self, "")
end

function M:OnResize(w, h) end

function M:RequestRefresh()
    if not self._enabled or self._pending then return end
    self._pending = true
    C_Timer.After(0.3, function() self._pending = false; self:Refresh() end)
end

local function fmtTime(sec)
    sec = math.max(0, math.floor(sec or 0))
    return ("%d:%02d"):format(math.floor(sec / 60), sec % 60)
end

function M:Refresh()
    if not self._enabled then return end
    local L = self.lines
    for _, fs in ipairs(L) do fs:SetText("") end
    if not C_MythicPlus then L[1]:SetText("|cFF888888API M+ indisponible.|r"); return end

    -- ma clé
    local mapID = C_MythicPlus.GetOwnedKeystoneChallengeMapID and C_MythicPlus.GetOwnedKeystoneChallengeMapID()
    local lvl = C_MythicPlus.GetOwnedKeystoneLevel and C_MythicPlus.GetOwnedKeystoneLevel()
    if mapID and lvl then
        local name = C_ChallengeMode and C_ChallengeMode.GetMapUIInfo and C_ChallengeMode.GetMapUIInfo(mapID)
        L[1]:SetText(("|cFFFFD200Ma clé :|r |cFFA335EE%s +%d|r"):format(name or "?", lvl))
        SP:SetModuleHeaderText(self, ("+%d"):format(lvl))
    else
        L[1]:SetText("|cFFFFD200Ma clé :|r |cFF888888aucune|r")
        SP:SetModuleHeaderText(self, "")
    end

    -- affixes de la semaine
    local affs = C_MythicPlus.GetCurrentAffixes and C_MythicPlus.GetCurrentAffixes()
    if affs and #affs > 0 then
        local parts = {}
        for _, a in ipairs(affs) do
            local an = C_ChallengeMode.GetAffixInfo and C_ChallengeMode.GetAffixInfo(a.id)
            if an then parts[#parts + 1] = an end
        end
        L[2]:SetText("|cFFFFD200Affixes :|r " .. table.concat(parts, ", "))
    end

    -- meilleur hebdo (récompense coffre)
    local weekly = C_MythicPlus.GetWeeklyChestRewardLevel and C_MythicPlus.GetWeeklyChestRewardLevel()
    if weekly and weekly > 0 then
        L[3]:SetText(("|cFFFFD200Hebdo :|r meilleur +%d"):format(weekly))
    end

    -- run en cours
    self._inRun = false
    if C_ChallengeMode and C_ChallengeMode.GetActiveChallengeMapID and C_ChallengeMode.GetActiveChallengeMapID() then
        self._inRun = true
        local amap = C_ChallengeMode.GetActiveChallengeMapID()
        local aname = C_ChallengeMode.GetMapUIInfo and C_ChallengeMode.GetMapUIInfo(amap)
        local _, elapsed = GetWorldElapsedTime(1)
        local _, _, timeLimit = C_ChallengeMode.GetMapUIInfo(amap)
        local txt = ("|cFF40FF40Run :|r %s  %s"):format(aname or "?", fmtTime(elapsed))
        if timeLimit and timeLimit > 0 then txt = txt .. " / " .. fmtTime(timeLimit) end
        L[4]:SetText(txt)
    end
end

SP:RegisterModule(M)
