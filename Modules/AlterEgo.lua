-- ============================================================
-- Module : AlterEgo ("Personnages") — montage AlterEgo adapté au panneau
-- ============================================================
-- Un personnage à la fois (MOLETTE sur le bandeau = suivant/précédent).
-- Mise en page reprise d'AlterEgo : lignes alternées, iLvl/cote colorés par rareté,
-- Grand Coffre (Raids/Donjons/Monde × 3 cases), table des donjons M+ :
-- niveau + chevrons de tier (|A:Professions-ChatIcon-Quality-TierN|a) + score coloré.
-- Requiert : AlterEgo (lecture de AlterEgoDB).
local ADDON_NAME, SP = ...

local M = { name = "AlterEgo", label = "Personnages", defaultHeight = 260 }

local ROW = 17

-- Enum.WeeklyRewardChestThresholdType : 1 = Activités (M+), 3 = Raid, 6 = Monde
local VAULT_TYPES = { { 3, "Raids" }, { 1, "Donjons" }, { 6, "Monde" } }

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

local function ratingHex(rating)
    local col = C_ChallengeMode and C_ChallengeMode.GetDungeonScoreRarityColor
        and C_ChallengeMode.GetDungeonScoreRarityColor(rating or 0)
    if col then return ("|cff%02x%02x%02x"):format(col.r * 255, col.g * 255, col.b * 255) end
    return "|cffffffff"
end

local function scoreHex(score)
    local col = C_ChallengeMode and C_ChallengeMode.GetSpecificDungeonOverallScoreRarityColor
        and C_ChallengeMode.GetSpecificDungeonOverallScoreRarityColor(score or 0)
    if col then return ("|cff%02x%02x%02x"):format(col.r * 255, col.g * 255, col.b * 255) end
    return ratingHex(score)
end

-- abréviation d'un nom de donjon : initiales des mots significatifs ("Fosse de Saron" → "FdS")
local function Abbr(name)
    if not name then return "?" end
    local out = {}
    for w in name:gmatch("[%wÀ-ÿ']+") do
        local first = w:sub(1, 1)
        out[#out + 1] = (w:len() > 2) and first:upper() or first:lower()
    end
    return table.concat(out):sub(1, 5)
end

-- chevrons de tier AlterEgo : durée du meilleur run vs timer du donjon (x1 / x0.8 / x0.6)
local function TierMarkup(durationSec, timeLimit)
    if not (durationSec and timeLimit and timeLimit > 0) then return "" end
    if durationSec <= timeLimit * 0.6 then return " |A:Professions-ChatIcon-Quality-Tier3:12:12|a"
    elseif durationSec <= timeLimit * 0.8 then return " |A:Professions-ChatIcon-Quality-Tier2:12:12|a"
    elseif durationSec <= timeLimit then return " |A:Professions-ChatIcon-Quality-Tier1:12:12|a" end
    return ""
end

-- ============================================================
function M:Init(body)
    self.body = body
    self.idx = 1
    self.rows = {}       -- pool de lignes { stripe, left, right }
    self.list = CreateFrame("Frame", nil, body)
    self.list:SetPoint("TOPLEFT", body, "TOPLEFT", 2, -2)
    self.list:SetPoint("BOTTOMRIGHT", body, "BOTTOMRIGHT", -2, 2)
    self.list:SetClipsChildren(true)

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

function M:_Row(i)
    local r = self.rows[i]
    if not r then
        r = CreateFrame("Frame", nil, self.list)
        r:SetHeight(ROW)
        r.stripe = r:CreateTexture(nil, "BACKGROUND")
        r.stripe:SetAllPoints(r)
        r.left = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        r.left:SetPoint("LEFT", r, "LEFT", 4, 0); r.left:SetJustifyH("LEFT")
        r.right = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        r.right:SetPoint("RIGHT", r, "RIGHT", -4, 0); r.right:SetJustifyH("RIGHT")
        self.rows[i] = r
    end
    return r
end

function M:Enable()
    self._enabled = true
    if self._placeholder then self._placeholder:Hide() end
    pcall(self.ev.RegisterEvent, self.ev, "PLAYER_ENTERING_WORLD")
    pcall(self.ev.RegisterEvent, self.ev, "CHALLENGE_MODE_COMPLETED")
    pcall(self.ev.RegisterEvent, self.ev, "WEEKLY_REWARDS_UPDATE")
    self:RequestRefresh()
end

function M:Disable()
    self._enabled = false
    if self.ev then self.ev:UnregisterAllEvents() end
    for _, r in ipairs(self.rows) do r:Hide() end
    SP:SetModuleHeaderText(self, "")
end

function M:OnResize(w, h) self:RequestRefresh() end

function M:RequestRefresh()
    if not self._enabled or self._pending then return end
    self._pending = true
    C_Timer.After(0.3, function() self._pending = false; self:Refresh() end)
end

function M:Refresh()
    if not self._enabled then return end
    local chars = GetChars()
    local i, y = 0, 0

    local function row(left, right, header)
        i = i + 1
        local r = self:_Row(i)
        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", self.list, "TOPLEFT", 0, -y)
        r:SetPoint("TOPRIGHT", self.list, "TOPRIGHT", 0, -y)
        if header then
            r.stripe:SetColorTexture(0.29, 0.64, 1, 0.12)
        elseif i % 2 == 0 then
            r.stripe:SetColorTexture(1, 1, 1, 0.035)   -- alternance AlterEgo
        else
            r.stripe:SetColorTexture(0, 0, 0, 0)
        end
        r.left:SetText(left or "")
        r.right:SetText(right or "")
        r:Show()
        y = y + ROW
    end

    if #chars == 0 then
        row("|cFFFF7777Requiert : AlterEgo|r", "")
        for j = i + 1, #self.rows do self.rows[j]:Hide() end
        SP:SetModuleHeaderText(self, "")
        SP:SetAutoHeight(self, y + 6)
        return
    end
    if self.idx > #chars then self.idx = 1 end
    local c = chars[self.idx]
    local hex = classHex(c)
    local mp = c.mythicplus or {}

    SP:SetModuleHeaderText(self, ("%s%s|r |cFF888888%d/%d|r"):format(hex, c.info.name, self.idx, #chars))

    -- ===== identité =====
    local ilvl = c.info.ilvl and (c.info.ilvl.equipped or c.info.ilvl.level) or 0
    local ilvlHex = c.info.ilvl and c.info.ilvl.color and ("|c" .. c.info.ilvl.color) or "|cffffffff"
    row(("%s%s|r-%s  |cFFAAAAAA%d|r"):format(hex, c.info.name, c.info.realm or "?", c.info.level or 0),
        ("%s%.0f|r  %s%d|r"):format(ilvlHex, ilvl, ratingHex(mp.rating), mp.rating or 0), true)

    local ks = mp.keystone
    if ks and (ks.level or 0) > 0 then
        local kn = C_ChallengeMode and C_ChallengeMode.GetMapUIInfo and C_ChallengeMode.GetMapUIInfo(ks.challengeModeID or 0)
        row("|cFFFFD200Clé|r", ("|cFFA335EE%s +%d|r"):format(Abbr(kn), ks.level))
    else
        row("|cFFFFD200Clé|r", "|cFF666666—|r")
    end
    if c.money and c.money > 0 then
        row("|cFFFFD200Or|r", GetMoneyString and GetMoneyString(c.money, true) or tostring(math.floor(c.money / 10000)))
    end

    -- ===== Grand Coffre (montage AlterEgo : 3 lignes × 3 cases) =====
    row("|cFF4AA3FFGrand Coffre|r", "", true)
    local slots = c.vault and c.vault.slots or {}
    for _, vt in ipairs(VAULT_TYPES) do
        local cells = {}
        for idx = 1, 3 do
            local slot
            for _, s in ipairs(slots) do
                if s.type == vt[1] and s.index == idx then slot = s; break end
            end
            if slot and (slot.progress or 0) >= (slot.threshold or 1) then
                cells[#cells + 1] = (vt[1] == 1 and slot.level and slot.level > 0)
                    and ("|cFF40FF40+%d|r"):format(slot.level) or "|cFF40FF40✓|r"
            elseif slot then
                cells[#cells + 1] = ("|cFF888888%d/%d|r"):format(slot.progress or 0, slot.threshold or 1)
            else
                cells[#cells + 1] = "|cFF555555—|r"
            end
        end
        row("  " .. vt[2], table.concat(cells, "  "))
    end

    -- ===== Donjons M+ (table AlterEgo : abbr · niveau+tier · score) =====
    local dungeons = mp.dungeons or {}
    if #dungeons > 0 then
        row("|cFF4AA3FFDonjons|r", "|cFF888888meilleur · score|r", true)
        local sorted = {}
        for _, d in ipairs(dungeons) do sorted[#sorted + 1] = d end
        table.sort(sorted, function(a, b)
            local na = C_ChallengeMode.GetMapUIInfo(a.challengeModeID or 0) or ""
            local nb = C_ChallengeMode.GetMapUIInfo(b.challengeModeID or 0) or ""
            return na < nb
        end)
        for _, d in ipairs(sorted) do
            local name, _, timeLimit = C_ChallengeMode.GetMapUIInfo(d.challengeModeID or 0)
            -- meilleur affixScore (niveau le plus haut)
            local best
            for _, asc in ipairs(d.affixScores or {}) do
                if not best or (asc.level or 0) > (best.level or 0) then best = asc end
            end
            local lvl = (best and best.level) or d.level or 0
            local score = (d.bestOverAllScore and d.bestOverAllScore.score)
                or (best and best.score) or 0
            local levelTxt
            if lvl > 0 then
                levelTxt = ("|cFFFFFFFF%d|r%s"):format(lvl, TierMarkup(best and best.durationSec, timeLimit))
            else
                levelTxt = "|cFF555555—|r"
            end
            row("  " .. Abbr(name), score > 0
                and ("%s · %s%d|r"):format(levelTxt, scoreHex(score), score)
                or levelTxt)
        end
    end

    -- ===== runs de la semaine =====
    local runs = mp.numCompletedDungeonRuns
    if runs then
        row("|cFFFFD200Runs semaine|r", ("M+ %d  |cFF888888M0 %d · HM %d|r")
            :format(runs.mythicPlus or 0, runs.mythic or 0, runs.heroic or 0))
    end

    for j = i + 1, #self.rows do self.rows[j]:Hide() end
    SP:SetAutoHeight(self, y + 6)
end

SP:RegisterModule(M)
