-- ============================================================
-- Module : Social — amis / BNet / guilde en ligne
-- ============================================================
-- Clic = chuchoter ; clic droit = inviter. Scroll molette.
local ADDON_NAME, SP = ...

local M = { name = "Social", label = "Social", defaultHeight = 140 }

local ROW = 15

local function CreateRow(self, i)
    local r = CreateFrame("Button", nil, self.list)
    r:SetHeight(ROW)
    r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    r.fs = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    r.fs:SetPoint("LEFT", r, "LEFT", 2, 0); r.fs:SetPoint("RIGHT", r, "RIGHT", -2, 0)
    r.fs:SetJustifyH("LEFT"); r.fs:SetWordWrap(false)
    local hl = r:CreateTexture(nil, "HIGHLIGHT"); hl:SetAllPoints(r); hl:SetColorTexture(1, 1, 1, 0.08)
    r:SetScript("OnClick", function(s, btn)
        if not s.who then return end
        if btn == "RightButton" then
            if C_PartyInfo and C_PartyInfo.InviteUnit then pcall(C_PartyInfo.InviteUnit, s.who) end
        else
            if ChatFrame_OpenChat then pcall(ChatFrame_OpenChat, "/w " .. s.who .. " ") end
        end
    end)
    self.rows[i] = r
    return r
end

function M:Init(body)
    self.body = body
    self.rows = {}
    self.list = CreateFrame("Frame", nil, body)
    self.list:SetPoint("TOPLEFT", body, "TOPLEFT", 2, -2)
    self.list:SetPoint("BOTTOMRIGHT", body, "BOTTOMRIGHT", -2, 2)
    self.list:SetClipsChildren(true)
    self.scroll = 0
    self.list:EnableMouseWheel(true)
    self.list:SetScript("OnMouseWheel", function(_, d)
        local vis = self.list:GetHeight() or 1
        local maxS = math.max(0, (self._contentH or 0) - vis)
        self.scroll = math.min(maxS, math.max(0, self.scroll - d * ROW * 2))
        self:Refresh()
    end)
    self.ev = CreateFrame("Frame")
    self.ev:SetScript("OnEvent", function() self:RequestRefresh() end)
end

function M:Enable()
    self._enabled = true
    if self._placeholder then self._placeholder:Hide() end
    for _, e in ipairs({ "FRIENDLIST_UPDATE", "BN_FRIEND_INFO_CHANGED", "GUILD_ROSTER_UPDATE", "PLAYER_ENTERING_WORLD" }) do
        pcall(self.ev.RegisterEvent, self.ev, e)
    end
    if not self._ticker then
        self._ticker = C_Timer.NewTicker(30, function()
            if C_FriendList and C_FriendList.ShowFriends then pcall(C_FriendList.ShowFriends) end
            if C_GuildInfo and C_GuildInfo.GuildRoster then pcall(C_GuildInfo.GuildRoster) end
        end)
    end
    if C_FriendList and C_FriendList.ShowFriends then pcall(C_FriendList.ShowFriends) end
    self:RequestRefresh()
end

function M:Disable()
    self._enabled = false
    if self.ev then self.ev:UnregisterAllEvents() end
    if self._ticker then self._ticker:Cancel(); self._ticker = nil end
    for _, r in ipairs(self.rows) do r:Hide() end
    SP:SetModuleHeaderText(self, "")
end

function M:OnResize(w, h) self:RequestRefresh() end

function M:RequestRefresh()
    if not self._enabled or self._pending then return end
    self._pending = true
    C_Timer.After(0.3, function() self._pending = false; self:Refresh() end)
end

local function classColor(class)
    local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    if c then return ("|cff%02x%02x%02x"):format(c.r * 255, c.g * 255, c.b * 255) end
    return "|cffffffff"
end

function M:Refresh()
    if not self._enabled then return end
    local entries = {}

    -- BNet (amis en ligne jouant à WoW)
    local nBN = BNGetNumFriends and BNGetNumFriends() or 0
    for i = 1, nBN do
        local ok, acc = pcall(C_BattleNet.GetFriendAccountInfo, i)
        if ok and acc and acc.gameAccountInfo and acc.gameAccountInfo.isOnline then
            local g = acc.gameAccountInfo
            if g.clientProgram == "WoW" and g.characterName then
                entries[#entries + 1] = {
                    who = g.characterName .. (g.realmName and ("-" .. g.realmName) or ""),
                    txt = ("|cFF82C5FF[BN]|r %s%s|r |cFF888888%s|r"):format(
                        classColor(g.className and g.className:upper():gsub(" ", "")), g.characterName, acc.accountName or ""),
                }
            end
        end
    end
    -- amis classiques
    local nF = (C_FriendList and C_FriendList.GetNumFriends and C_FriendList.GetNumFriends()) or 0
    for i = 1, nF do
        local ok, info = pcall(C_FriendList.GetFriendInfoByIndex, i)
        if ok and info and info.connected then
            entries[#entries + 1] = { who = info.name,
                txt = ("|cFF40FF40[Ami]|r %s |cFF888888%d %s|r"):format(info.name, info.level or 0, info.className or "") }
        end
    end
    -- guilde (en ligne)
    if IsInGuild and IsInGuild() then
        local total = GetNumGuildMembers() or 0
        for i = 1, total do
            local name, _, _, level, _, _, _, _, online, _, classFile = GetGuildRosterInfo(i)
            if online and name then
                entries[#entries + 1] = { who = name,
                    txt = ("|cFF40FF90[G]|r %s%s|r |cFF888888%d|r"):format(classColor(classFile), Ambiguate(name, "guild"), level or 0) }
                if #entries > 80 then break end
            end
        end
    end

    local y = 0
    for i, e in ipairs(entries) do
        local r = self.rows[i] or CreateRow(self, i)
        r.who = e.who
        r.fs:SetText(e.txt)
        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", self.list, "TOPLEFT", 0, -(y - self.scroll))
        r:SetPoint("TOPRIGHT", self.list, "TOPRIGHT", 0, -(y - self.scroll))
        r:Show()
        y = y + ROW
    end
    for i = #entries + 1, #self.rows do self.rows[i]:Hide() end
    self._contentH = y
    SP:SetModuleHeaderText(self, ("%d en ligne"):format(#entries))
end

SP:RegisterModule(M)
