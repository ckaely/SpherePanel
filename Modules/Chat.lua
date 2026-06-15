-- ============================================================
-- Module : Chat — panneaux filtrés configurables (additionnel)
-- ============================================================
-- Boutons de canaux config-driven (couleur/ordre/nom/activation, séparateurs).
--   clic DROIT = affiche le panneau ; clic GAUCHE = arme l'écriture.
-- Noms colorés par classe + cliquables (chuchotement), horodatage cliquable
-- (survol = date/heure, clic = copie du message), liens URL copiables, police configurable.
local ADDON_NAME, SP = ...

local M = {
    name          = "Chat",
    label         = "Chat",
    defaultHeight = 200,
}

local CAP = 300

local CHAT_EVENTS = {
    "CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_EMOTE",
    "CHAT_MSG_GUILD", "CHAT_MSG_OFFICER",
    "CHAT_MSG_WHISPER", "CHAT_MSG_WHISPER_INFORM", "CHAT_MSG_BN_WHISPER", "CHAT_MSG_BN_WHISPER_INFORM",
    "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER",
    "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER", "CHAT_MSG_RAID_WARNING",
    "CHAT_MSG_INSTANCE_CHAT", "CHAT_MSG_INSTANCE_CHAT_LEADER",
    "CHAT_MSG_CHANNEL",
}

local KEYDEF = {
    A = { write = "SAY",     all = true },
    S = { write = "SAY",     types = { SAY = true, YELL = true, EMOTE = true } },
    W = { write = "WHISPER", types = { WHISPER = true } },
    I = { write = "GROUP",   types = { INSTANCE_CHAT = true, PARTY = true, RAID = true, RAID_WARNING = true } },
    G = { write = "GUILD",   types = { GUILD = true, OFFICER = true } },
    M = { write = "TRADE",   isTrade = true },
}

local function NormType(suffix)
    suffix = suffix:gsub("_LEADER$", "")
    if suffix == "WHISPER_INFORM" or suffix == "BN_WHISPER" or suffix == "BN_WHISPER_INFORM" then return "WHISPER" end
    return suffix
end

local function IsTradeChannel(name)
    if type(name) ~= "string" then return false end
    local l = name:lower()
    return (l:find("commerce") or l:find("trade") or l:find("market")) and true or false
end

local function LinkifyURLs(text)
    text = text:gsub("(https?://[^%s|]+)", "|cff33ccff|Hspurl:%1|h[lien]|h|r")
    text = text:gsub("(www%.[%w%.%-/%?=&_#]+)", "|cff33ccff|Hspurl:%1|h[lien]|h|r")
    return text
end

-- ============================================================
function M:Init(body)
    self.body = body
    self.viewFilter = "A"
    self.writeType  = "SAY"
    self.buf = {}
    self.btns = {}
    self.seps = {}
    self.msgInfo = {}
    self._idc = 0
    self.tab = "chat"
    self.socialRows = {}

    -- onglets [Chat | Social] sur le bandeau (molette = switch)
    if self.header then
        if self.suffixFS then self.suffixFS:Hide() end
        self.tabBtns = {}
        local anchor, prev = self.lock or self.header, nil
        for _, d in ipairs({ { "social", "Social" }, { "chat", "Chat" } }) do
            local b = CreateFrame("Button", nil, self.header); b:SetSize(42, 16)
            if prev then b:SetPoint("RIGHT", prev, "LEFT", -3, 0) else b:SetPoint("RIGHT", anchor, "LEFT", -6, 0) end
            b.fs = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); b.fs:SetAllPoints(b); b.fs:SetText(d[2])
            b.hl = b:CreateTexture(nil, "BACKGROUND"); b.hl:SetAllPoints(b); b.hl:SetColorTexture(0.30, 0.55, 0.95, 0.30); b.hl:Hide()
            b.tab = d[1]; b:SetScript("OnClick", function(s) self:SetTab(s.tab) end)
            self.tabBtns[d[1]] = b; prev = b
        end
        self.header:EnableMouseWheel(true)
        self.header:SetScript("OnMouseWheel", function() self:SetTab(self.tab == "social" and "chat" or "social") end)
    end

    self.bar = CreateFrame("Frame", nil, body)
    self.bar:SetPoint("TOPLEFT", body, "TOPLEFT", 4, -2)
    self.bar:SetPoint("TOPRIGHT", body, "TOPRIGHT", -4, -2)
    self.bar:SetHeight(16)
    self.bar:EnableMouseWheel(true)
    self.bar:SetScript("OnMouseWheel", function(_, d) self:CycleChannel(d) end)  -- molette = canal suivant/précédent
    self.viewLabel = self.bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    self.viewLabel:SetPoint("RIGHT", self.bar, "RIGHT", 0, 0)

    self.smf = CreateFrame("ScrollingMessageFrame", nil, body)
    self.smf:SetPoint("TOPLEFT", self.bar, "BOTTOMLEFT", 0, -2)
    self.smf:SetPoint("BOTTOMRIGHT", body, "BOTTOMRIGHT", -4, 22)
    self.smf:SetJustifyH("LEFT")
    self.smf:SetFading(false)
    self.smf:SetMaxLines(CAP)
    self.smf:SetHyperlinksEnabled(true)
    self.smf:EnableMouseWheel(true)
    self.smf:SetScript("OnMouseWheel", function(s, d) if d > 0 then s:ScrollUp() else s:ScrollDown() end end)
    self.smf:SetScript("OnHyperlinkClick", function(_, link, text, button)
        local url = link:match("^spurl:(.+)$")
        if url then self:CopyText(url); return end
        local mid = link:match("^spMsg:(%d+)$")
        if mid then local info = self.msgInfo[tonumber(mid)]; if info then self:CopyText(info.raw) end; return end
        local who = link:match("^spWhisper:(.-);;%d+$")
        if who then self:StartWhisper(who); return end
        SetItemRef(link, text, button)
    end)
    self.smf:SetScript("OnHyperlinkEnter", function(s, link)
        local mid = link:match("^spMsg:(%d+)$")
        local _, wid = nil, nil
        if not mid then _, wid = link:match("^spWhisper:(.-);;(%d+)$") end
        local id = mid or wid
        if id then
            local info = self.msgInfo[tonumber(id)]
            if info then
                -- popup à gauche du panneau : date + heure du message
                GameTooltip:SetOwner(s, "ANCHOR_NONE")
                GameTooltip:ClearAllPoints()
                GameTooltip:SetPoint("TOPRIGHT", self.body, "TOPLEFT", -4, 0)
                GameTooltip:SetText(date("%A %d/%m/%Y", info.t), 1, 1, 1)
                GameTooltip:AddLine(date("%H:%M:%S", info.t), 0.8, 0.8, 0.8)
                GameTooltip:Show()
            end
        end
    end)
    self.smf:SetScript("OnHyperlinkLeave", function() GameTooltip:Hide() end)

    self.eb = CreateFrame("EditBox", nil, body)
    self.eb:SetPoint("BOTTOMLEFT", body, "BOTTOMLEFT", 4, 2)
    self.eb:SetPoint("BOTTOMRIGHT", body, "BOTTOMRIGHT", -4, 2)
    self.eb:SetHeight(18)
    self.eb:SetAutoFocus(false)
    self.eb:SetFontObject(ChatFontNormal or GameFontHighlightSmall)
    self.eb:SetScript("OnEnterPressed", function(s) self:Send(s:GetText()); s:SetText(""); s:ClearFocus() end)
    self.eb:SetScript("OnEscapePressed", function(s) s:SetText(""); s:ClearFocus() end)

    self.copyBox = CreateFrame("EditBox", nil, body)
    self.copyBox:SetPoint("TOPLEFT", self.smf, "TOPLEFT", 0, 0)
    self.copyBox:SetPoint("TOPRIGHT", self.smf, "TOPRIGHT", 0, 0)
    self.copyBox:SetHeight(18)
    self.copyBox:SetAutoFocus(true)
    self.copyBox:SetFontObject(ChatFontNormal or GameFontHighlightSmall)
    local cbg = self.copyBox:CreateTexture(nil, "BACKGROUND"); cbg:SetAllPoints(self.copyBox); cbg:SetColorTexture(0, 0, 0, 0.9)
    self.copyBox:Hide()
    self.copyBox:SetScript("OnEscapePressed", function(s) s:Hide() end)
    self.copyBox:SetScript("OnEnterPressed", function(s) s:Hide() end)

    self.ev = CreateFrame("Frame")
    self.ev:SetScript("OnEvent", function(_, event, ...)
        local msg, author = ...
        local channelName = select(4, ...)
        local guid = select(12, ...)
        local typeKey = NormType(event:gsub("^CHAT_MSG_", ""))
        if event == "CHAT_MSG_WHISPER" and author and author ~= "" then self._lastWhisper = author end
        -- whisper reçu → révèle le module quelques secondes (notification douce)
        if (event == "CHAT_MSG_WHISPER" or event == "CHAT_MSG_BN_WHISPER") and self._enabled then
            SP:RevealModule(self, 6)
        end
        self:AddMessage(typeKey, msg, author, channelName, guid)
    end)

    -- conteneur SOCIAL (ex-module Social) : liste amis / BNet / guilde
    self.social = CreateFrame("Frame", nil, body)
    self.social:SetPoint("TOPLEFT", body, "TOPLEFT", 2, -2)
    self.social:SetPoint("BOTTOMRIGHT", body, "BOTTOMRIGHT", -2, 2)
    self.social:SetClipsChildren(true); self.social:Hide()
    self.socialScroll = 0
    self.social:EnableMouseWheel(true)
    self.social:SetScript("OnMouseWheel", function(_, d)
        local vis = self.social:GetHeight() or 1
        local maxS = math.max(0, (self._socialH or 0) - vis)
        self.socialScroll = math.min(maxS, math.max(0, self.socialScroll - d * 30))
        self:RefreshSocial()
    end)
    self.sev = CreateFrame("Frame")
    self.sev:SetScript("OnEvent", function() if self.tab == "social" then self:RefreshSocial() end end)

    self:ApplyConfig()
    self:SetTab(self.tab or "chat")
end

function M:Enable()
    self._enabled = true
    if self._placeholder then self._placeholder:Hide() end
    self:ApplyConfig()
    for _, e in ipairs(CHAT_EVENTS) do pcall(self.ev.RegisterEvent, self.ev, e) end
    -- onglet Social : events + rafraîchissement périodique
    if self.sev then
        for _, e in ipairs({ "FRIENDLIST_UPDATE", "BN_FRIEND_INFO_CHANGED", "GUILD_ROSTER_UPDATE", "PLAYER_ENTERING_WORLD" }) do
            pcall(self.sev.RegisterEvent, self.sev, e)
        end
    end
    if not self._socialTicker then
        self._socialTicker = C_Timer.NewTicker(30, function()
            if C_FriendList and C_FriendList.ShowFriends then pcall(C_FriendList.ShowFriends) end
            if C_GuildInfo and C_GuildInfo.GuildRoster then pcall(C_GuildInfo.GuildRoster) end
            if self.tab == "social" then self:RefreshSocial() end
        end)
    end
end

function M:Disable()
    self._enabled = false
    if self.ev then self.ev:UnregisterAllEvents() end
    if self.sev then self.sev:UnregisterAllEvents() end
    if self._socialTicker then self._socialTicker:Cancel(); self._socialTicker = nil end
end

function M:OnResize(w, h) end

function M:ChannelByKey(key)
    for _, ch in ipairs(SP:GetModuleConfig(self.name).channels or {}) do
        if ch.key == key then return ch end
    end
end

-- ------------------------------------------------------------
-- Application config : police, couleurs, boutons + séparateurs, buffers
-- ------------------------------------------------------------
function M:ApplyConfig()
    local cfg = SP:GetModuleConfig(self.name)
    pcall(function() self.smf:SetFont(cfg.font or STANDARD_TEXT_FONT, cfg.fontSize or 12, "") end)

    self.colorOf = {}
    for _, ch in ipairs(cfg.channels or {}) do
        self.colorOf[ch.key] = { ch.r or 1, ch.g or 1, ch.b or 1 }
        self.buf[ch.key] = self.buf[ch.key] or {}
    end
    self.buf.A = self.buf.A or {}

    for _, b in ipairs(self.btns) do b:Hide() end
    for _, s in ipairs(self.seps) do s:Hide() end

    local x, i = 0, 0
    for _, ch in ipairs(cfg.channels or {}) do
        if ch.enabled then
            i = i + 1
            if i > 1 then
                local sep = self.seps[i - 1]
                if not sep then
                    sep = self.bar:CreateTexture(nil, "ARTWORK"); sep:SetSize(1, 12); self.seps[i - 1] = sep
                end
                sep:SetColorTexture(1, 1, 1, 0.25)
                sep:ClearAllPoints(); sep:SetPoint("LEFT", self.bar, "LEFT", x - 3, 0); sep:Show()
            end
            local b = self.btns[i]
            if not b then
                b = CreateFrame("Button", nil, self.bar)
                b:SetSize(20, 16)
                local hl = b:CreateTexture(nil, "BACKGROUND"); hl:SetAllPoints(b); hl:SetColorTexture(1, 1, 1, 0.18); hl:Hide()
                b.sel = hl
                b.fs = b:CreateFontString(nil, "OVERLAY", "GameFontNormal"); b.fs:SetAllPoints(b)
                b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
                self.btns[i] = b
            end
            b:ClearAllPoints(); b:SetPoint("LEFT", self.bar, "LEFT", x, 0)
            b.fs:SetText(ch.label or ch.key)
            b.fs:SetTextColor(ch.r or 1, ch.g or 1, ch.b or 1)
            b.key = ch.key
            b:SetScript("OnClick", function(s, mouse)
                if mouse == "RightButton" then self:SetView(s.key) else self:SetWrite(s.key) end
            end)
            b:SetScript("OnEnter", function(s)
                GameTooltip:SetOwner(s, "ANCHOR_BOTTOM")
                GameTooltip:SetText(ch.label or ch.key); GameTooltip:AddLine("Clic D : afficher | Clic G : écrire", 0.7, 0.7, 0.7); GameTooltip:Show()
            end)
            b:SetScript("OnLeave", function() GameTooltip:Hide() end)
            b:Show()
            x = x + (#(ch.label or ch.key) > 1 and 30 or 24)
        end
    end
    self._btnUsed = i
    if not self.colorOf[self.viewFilter] then self.viewFilter = "A" end
    self:SetView(self.viewFilter)
end

-- ------------------------------------------------------------
-- Messages
-- ------------------------------------------------------------
function M:PrimaryKey(typeKey, channelName)
    for _, ch in ipairs(SP:GetModuleConfig(self.name).channels or {}) do
        if ch.enabled and ch.key ~= "A" then
            local def = KEYDEF[ch.key]
            if def then
                if def.types and def.types[typeKey] then return ch.key end
                if def.isTrade and typeKey == "CHANNEL" and IsTradeChannel(channelName) then return ch.key end
            elseif ch.channelName and typeKey == "CHANNEL" and type(channelName) == "string"
                and channelName:lower():find(ch.channelName:lower(), 1, true) then
                return ch.key
            end
        end
    end
    return "A"
end

function M:BuildName(author, guid, id)
    if not author or author == "" then return nil end
    local short = Ambiguate and Ambiguate(author, "none") or author
    local cfg = SP:GetModuleConfig(self.name)
    local colored
    if cfg.classColorNames and guid then
        local ok, _, eng = pcall(GetPlayerInfoByGUID, guid)
        local c = ok and eng and RAID_CLASS_COLORS and RAID_CLASS_COLORS[eng]
        if c then colored = ("|cff%02x%02x%02x%s|r"):format(c.r * 255, c.g * 255, c.b * 255, short) end
    end
    colored = colored or ("|cffffffff" .. short .. "|r")
    -- lien : survol = date/heure (popup gauche), clic = chuchotement
    return ("|HspWhisper:%s;;%d|h%s|h"):format(author, id or 0, colored)
end

function M:Push(key, entry)
    local b = self.buf[key]
    if not b then return end
    b[#b + 1] = entry
    if #b > CAP then table.remove(b, 1) end
end

function M:AddMessage(typeKey, msg, author, channelName, guid)
    if type(msg) ~= "string" then return end
    self._idc = self._idc + 1
    local id = self._idc
    self.msgInfo[id] = { t = time(), raw = (author and author ~= "" and (author .. ": ") or "") .. msg }
    self.msgInfo[id - 2000] = nil

    local pk = self:PrimaryKey(typeKey, channelName)
    local col = self.colorOf[pk] or self.colorOf.A or { 1, 1, 1 }
    local ts = ("|cff808080|HspMsg:%d|h[%s]|h|r "):format(id, date("%H:%M"))
    local name = self:BuildName(author, guid, id)
    local line = ts .. (name and (name .. ": ") or "") .. LinkifyURLs(msg)
    local entry = { line, col[1], col[2], col[3] }

    self:Push("A", entry)
    if pk ~= "A" then self:Push(pk, entry) end
    if self.viewFilter == "A" or self.viewFilter == pk then
        self.smf:AddMessage(entry[1], col[1], col[2], col[3])
    end
end

function M:SetView(key)
    self.viewFilter = key
    self.smf:Clear()
    for _, e in ipairs(self.buf[key] or {}) do self.smf:AddMessage(e[1], e[2], e[3], e[4]) end
    for i = 1, (self._btnUsed or 0) do
        local b = self.btns[i]
        if b then b.sel:SetShown(b.key == key) end
    end
    if self.viewLabel then self.viewLabel:SetText("|cFFAAAAAAvue:|r " .. key) end
end

function M:SetWrite(key)
    local def = KEYDEF[key]
    local ch = self:ChannelByKey(key)
    if def then self.writeType, self.writeChannel = def.write, nil
    elseif ch and ch.channelName then self.writeType, self.writeChannel = "CUSTOM", ch.channelName
    else self.writeType, self.writeChannel = "SAY", nil end
    local col = self.colorOf[key] or { 1, 1, 1 }
    if self.eb then self.eb:SetTextColor(col[1], col[2], col[3]); self.eb:SetFocus() end
end

function M:StartWhisper(name)
    self.writeType, self.writeChannel = "WHISPER", nil
    self._lastWhisper = name
    if self.eb then self.eb:SetFocus() end
    if self.viewLabel then
        self.viewLabel:SetText("|cFF40FF40→ " .. (Ambiguate and Ambiguate(name, "none") or name) .. "|r")
        C_Timer.After(4, function() if self.viewLabel then self:SetView(self.viewFilter) end end)
    end
end

function M:CopyText(text)
    if self.copyBox then
        self.copyBox:SetText(text); self.copyBox:Show(); self.copyBox:HighlightText(); self.copyBox:SetFocus()
    end
    if self.viewLabel then
        self.viewLabel:SetText("|cFF40FF40Ctrl+C pour copier|r")
        C_Timer.After(4, function() if self.viewLabel then self:SetView(self.viewFilter) end end)
    end
end

-- ------------------------------------------------------------
-- Envoi
-- ------------------------------------------------------------
function M:FindChannelByName(name)
    if not name then return end
    local list = { GetChannelList() }
    for i = 1, #list, 3 do
        local id, nm = list[i], list[i + 1]
        if type(nm) == "string" and nm:lower():find(name:lower(), 1, true) then return id end
    end
end

function M:Send(text)
    if not text or text == "" then return end
    local w = self.writeType or "SAY"
    if w == "WHISPER" then
        local target = self._lastWhisper or (ChatEdit_GetLastTellTarget and ChatEdit_GetLastTellTarget())
        if target and target ~= "" then pcall(SendChatMessage, text, "WHISPER", nil, target)
        else SP:Print("Chat : aucune cible de chuchotement récente.") end
    elseif w == "GROUP" then
        local ch = "SAY"
        if LE_PARTY_CATEGORY_INSTANCE and IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then ch = "INSTANCE_CHAT"
        elseif IsInRaid() then ch = "RAID"
        elseif IsInGroup() then ch = "PARTY" end
        pcall(SendChatMessage, text, ch)
    elseif w == "GUILD" then
        pcall(SendChatMessage, text, "GUILD")
    elseif w == "TRADE" then
        local idx = self:FindChannelByName("commerce") or self:FindChannelByName("trade")
        if idx then pcall(SendChatMessage, text, "CHANNEL", nil, idx)
        else SP:Print("Chat : canal Commerce introuvable (rejoins-le d'abord).") end
    elseif w == "CUSTOM" and self.writeChannel then
        local idx = self:FindChannelByName(self.writeChannel)
        if idx then pcall(SendChatMessage, text, "CHANNEL", nil, idx)
        else SP:Print("Chat : canal '" .. self.writeChannel .. "' introuvable.") end
    else
        pcall(SendChatMessage, text, "SAY")
    end
end

-- ============================================================
-- Onglets Chat / Social + cycle de canaux
-- ============================================================
function M:SetTab(tab)
    self.tab = tab
    local chatOn = (tab ~= "social")
    if self.bar then self.bar:SetShown(chatOn) end
    if self.smf then self.smf:SetShown(chatOn) end
    if self.eb then self.eb:SetShown(chatOn) end
    if self.social then self.social:SetShown(not chatOn) end
    if self.tabBtns then for k, b in pairs(self.tabBtns) do b.hl:SetShown(k == tab) end end
    if not chatOn then self:RefreshSocial() end
end

function M:CycleChannel(delta)
    local keys = { "A" }
    for _, ch in ipairs(SP:GetModuleConfig(self.name).channels or {}) do
        if ch.enabled and ch.key ~= "A" then keys[#keys + 1] = ch.key end
    end
    local idx = 1
    for i, k in ipairs(keys) do if k == self.viewFilter then idx = i; break end end
    idx = ((idx - 1 - delta) % #keys) + 1
    self:SetView(keys[idx])
end

local function socialClassColor(class)
    local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    if c then return ("|cff%02x%02x%02x"):format(c.r * 255, c.g * 255, c.b * 255) end
    return "|cffffffff"
end

function M:_SocialRow(i)
    local r = self.socialRows[i]
    if not r then
        r = CreateFrame("Button", nil, self.social); r:SetHeight(15)
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
                self:StartWhisper(s.who)
            end
        end)
        self.socialRows[i] = r
    end
    return r
end

function M:RefreshSocial()
    if not self.social then return end
    local entries = {}
    local nBN = BNGetNumFriends and BNGetNumFriends() or 0
    for i = 1, nBN do
        local ok, acc = pcall(C_BattleNet.GetFriendAccountInfo, i)
        local g = ok and acc and acc.gameAccountInfo
        if g and g.isOnline and g.clientProgram == "WoW" and g.characterName then
            entries[#entries + 1] = { who = g.characterName .. (g.realmName and ("-" .. g.realmName) or ""),
                txt = ("|cFF82C5FF[BN]|r %s |cFF888888%s|r"):format(g.characterName, acc.accountName or "") }
        end
    end
    local nF = (C_FriendList and C_FriendList.GetNumFriends and C_FriendList.GetNumFriends()) or 0
    for i = 1, nF do
        local ok, info = pcall(C_FriendList.GetFriendInfoByIndex, i)
        if ok and info and info.connected then
            entries[#entries + 1] = { who = info.name,
                txt = ("|cFF40FF40[Ami]|r %s |cFF888888%d %s|r"):format(info.name, info.level or 0, info.className or "") }
        end
    end
    if IsInGuild and IsInGuild() then
        local total = GetNumGuildMembers() or 0
        for i = 1, total do
            local name, _, _, level, _, _, _, _, online, _, classFile = GetGuildRosterInfo(i)
            if online and name then
                entries[#entries + 1] = { who = name,
                    txt = ("|cFF40FF90[G]|r %s%s|r |cFF888888%d|r"):format(socialClassColor(classFile), Ambiguate(name, "guild"), level or 0) }
                if #entries > 120 then break end
            end
        end
    end
    local y = 0
    for i, e in ipairs(entries) do
        local r = self:_SocialRow(i)
        r.who = e.who; r.fs:SetText(e.txt)
        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", self.social, "TOPLEFT", 0, -(y - (self.socialScroll or 0)))
        r:SetPoint("TOPRIGHT", self.social, "TOPRIGHT", 0, -(y - (self.socialScroll or 0)))
        r:Show()
        y = y + 15
    end
    for i = #entries + 1, #self.socialRows do self.socialRows[i]:Hide() end
    self._socialH = y
end

SP:RegisterModule(M)
