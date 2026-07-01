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
    -- registre complet (façon Blizzard) : système / butin / créatures
    "CHAT_MSG_SYSTEM",
    "CHAT_MSG_LOOT", "CHAT_MSG_MONEY", "CHAT_MSG_CURRENCY",
    "CHAT_MSG_MONSTER_SAY", "CHAT_MSG_MONSTER_YELL", "CHAT_MSG_MONSTER_EMOTE",
    "CHAT_MSG_MONSTER_WHISPER", "CHAT_MSG_RAID_BOSS_EMOTE", "CHAT_MSG_RAID_BOSS_WHISPER",
}

-- catégories supplémentaires (registre complet) ajoutées si absentes (désactivées par défaut)
local EXTRA_CHANNELS = {
    { key = "SYS",  label = "Système",   r = 1.0, g = 1.0, b = 0.5,  enabled = false, types = { SYSTEM = true } },
    { key = "LOOT", label = "Butin",     r = 0.4, g = 1.0, b = 0.4,  enabled = false, types = { LOOT = true, MONEY = true, CURRENCY = true } },
    { key = "NPC",  label = "Créatures", r = 1.0, g = 0.85, b = 0.4, enabled = false,
      types = { MONSTER_SAY = true, MONSTER_YELL = true, MONSTER_EMOTE = true, MONSTER_WHISPER = true, RAID_BOSS_EMOTE = true, RAID_BOSS_WHISPER = true } },
}

local KEYDEF = {
    A = { write = "SAY",     all = true },
    S = { write = "SAY",     types = { SAY = true, YELL = true, EMOTE = true } },
    W = { write = "WHISPER", types = { WHISPER = true } },
    I = { write = "GROUP",   types = { INSTANCE_CHAT = true, PARTY = true, RAID = true, RAID_WARNING = true } },
    G = { write = "GUILD",   types = { GUILD = true, OFFICER = true } },
    M = { write = "TRADE",   isTrade = true },
}

local INSTANT_POPUP_TYPES = {
    WHISPER = true, BN_WHISPER = true,
    PARTY = true, RAID = true, INSTANCE_CHAT = true,
    GUILD = true, OFFICER = true,
}

local REPLY_WRITE_TYPE = {
    WHISPER = "WHISPER", BN_WHISPER = "WHISPER",
    PARTY = "PARTY", RAID = "RAID", INSTANCE_CHAT = "INSTANCE_CHAT",
    GUILD = "GUILD", OFFICER = "OFFICER",
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

local function CleanName(author)
    if not author or author == "" then return "" end
    return (Ambiguate and Ambiguate(author, "none")) or author
end

-- palette par défaut pour la couleur de chaque onglet de chat
local TAB_PALETTE = {
    { 0.85, 0.90, 1.00 }, { 0.60, 1.00, 0.60 }, { 1.00, 0.80, 0.50 },
    { 1.00, 0.60, 0.90 }, { 0.55, 0.90, 1.00 }, { 1.00, 1.00, 0.62 },
}

-- commandes slash → type de chat (pour basculer vers le bon onglet)
local CMD_TYPE = {
    g = "GUILD", gu = "GUILD", guild = "GUILD",
    p = "PARTY", party = "PARTY",
    r = "RAID", raid = "RAID", rl = "RAID",
    i = "INSTANCE_CHAT", inst = "INSTANCE_CHAT", instance = "INSTANCE_CHAT",
    o = "OFFICER", officer = "OFFICER",
}

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
    self.chatTabBtns = {}
    self._socialCounts = { friends = 0, guild = 0 }
    self.toasts = {}
    self.activeToasts = {}
    self.toastHost = CreateFrame("Frame", "SpherePanelChatToastHost", UIParent)
    self.toastHost:SetSize(620, 260)
    self.toastHost:SetPoint("CENTER", UIParent, "CENTER", 0, 110)
    self.toastHost:SetFrameStrata("FULLSCREEN_DIALOG")
    self.toastHost:Hide()

    -- Mode Chat + social compact dans le bandeau.
    if self.header then
        if self.suffixFS then self.suffixFS:Hide() end
        self.tabBtns = {}
        local anchor = self.lock or self.header
        self.socialBtn = CreateFrame("Button", nil, self.header)
        self.socialBtn:SetSize(54, 16)
        self.socialBtn:SetPoint("RIGHT", anchor, "LEFT", -6, 0)
        self.socialBtn.bg = self.socialBtn:CreateTexture(nil, "BACKGROUND"); self.socialBtn.bg:SetAllPoints(self.socialBtn); self.socialBtn.bg:SetColorTexture(0.30, 0.55, 0.95, 0.12)
        self.socialBtn.icon = self.socialBtn:CreateTexture(nil, "ARTWORK"); self.socialBtn.icon:SetSize(13, 13); self.socialBtn.icon:SetPoint("LEFT", self.socialBtn, "LEFT", 3, 0)
        self.socialBtn.icon:SetTexture("Interface\\FriendsFrame\\UI-Toast-FriendOnlineIcon")
        self.socialBtn.fs = self.socialBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        self.socialBtn.fs:SetPoint("LEFT", self.socialBtn.icon, "RIGHT", 2, 0)
        self.socialBtn.fs:SetPoint("RIGHT", self.socialBtn, "RIGHT", -2, 0)
        self.socialBtn:SetScript("OnClick", function() self:SetTab(self.tab == "social" and "chat" or "social") end)
        self.tabBtns.social = self.socialBtn

        self.chatModeBtn = CreateFrame("Button", nil, self.header)
        self.chatModeBtn:SetSize(42, 16)
        self.chatModeBtn:SetPoint("RIGHT", self.socialBtn, "LEFT", -3, 0)
        self.chatModeBtn.bg = self.chatModeBtn:CreateTexture(nil, "BACKGROUND"); self.chatModeBtn.bg:SetAllPoints(self.chatModeBtn); self.chatModeBtn.bg:SetColorTexture(0.30, 0.55, 0.95, 0.12)
        self.chatModeBtn.fs = self.chatModeBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); self.chatModeBtn.fs:SetAllPoints(self.chatModeBtn); self.chatModeBtn.fs:SetText("Chat")
        self.chatModeBtn:SetScript("OnClick", function() self:SetTab("chat") end)
        self.tabBtns.chat = self.chatModeBtn

        self.header:EnableMouseWheel(true)
        self.header:SetScript("OnMouseWheel", function(_, d) self:CycleChannel(d) end)
    end

    self.chatTabBar = CreateFrame("Frame", nil, self.header or body)
    if self.header and self.labelFS then
        self.chatTabBar:SetPoint("LEFT", self.labelFS, "RIGHT", 10, 0)
        self.chatTabBar:SetPoint("RIGHT", self.chatModeBtn or (self.lock or self.header), "LEFT", -8, 0)
    else
        self.chatTabBar:SetPoint("TOPLEFT", body, "TOPLEFT", 4, -2)
        self.chatTabBar:SetPoint("TOPRIGHT", body, "TOPRIGHT", -4, -2)
    end
    self.chatTabBar:SetHeight(18)
    self.chatTabBar:EnableMouseWheel(true)
    self.chatTabBar:SetScript("OnMouseWheel", function(_, d) self:CycleChannel(d) end)

    self.bar = CreateFrame("Frame", nil, body)
    self.bar:SetPoint("TOPLEFT", body, "TOPLEFT", 4, -2)
    self.bar:SetPoint("TOPRIGHT", body, "TOPRIGHT", -4, -2)
    self.bar:SetHeight(16)
    self.bar:Hide()
    self.bar:EnableMouseWheel(true)
    self.bar:SetScript("OnMouseWheel", function(_, d) self:CycleChannel(d) end)  -- molette = canal suivant/précédent
    self.viewLabel = self.bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    self.viewLabel:SetPoint("RIGHT", self.bar, "RIGHT", 0, 0)

    -- Pilule de saisie flottante centrée (UIParent) — même style que les capsules Suivi chat,
    -- click-through quand inactive. Pilule arrondie via SP:BuildPill (cf. Core.lua).
    self.inputBand = CreateFrame("Frame", nil, UIParent)
    self.inputBand:SetFrameStrata("DIALOG")
    self.inputBand:SetClampedToScreen(true)
    SP:BuildPill(self.inputBand)
    SP:StylePill(self.inputBand, 0.65, 0.8, 1, { bgAlpha = 0.5, borderAlpha = 0.92, glow = true, glowAlpha = 0.22, dot = true })
    -- Label cible chuchotement (ex: "-> Kyalin")
    self.inputBand.targetLabel = self.inputBand:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    self.inputBand.targetLabel:SetPoint("LEFT", self.inputBand, "LEFT", 16, 0)
    self.inputBand.targetLabel:SetJustifyH("LEFT")
    self.inputBand.targetLabel:Hide()
    -- Hint "Tab" (visible 3 s à l'ouverture de la saisie)
    self.inputBand.tabHint = self.inputBand:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    self.inputBand.tabHint:SetPoint("BOTTOM", self.inputBand, "BOTTOM", 0, -12)
    self.inputBand.tabHint:SetText("Tab : changer de canal")
    self.inputBand.tabHint:Hide()

    self.smf = CreateFrame("ScrollingMessageFrame", nil, body)
    self.smf:SetPoint("TOPLEFT", body, "TOPLEFT", 4, -4)
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

    self.eb = CreateFrame("EditBox", nil, self.inputBand)
    self.eb:SetPoint("LEFT",  self.inputBand, "LEFT",  16, 0)
    self.eb:SetPoint("RIGHT", self.inputBand, "RIGHT", -14, 0)
    self.eb:SetHeight(20)
    self.eb:SetAutoFocus(false)
    self.eb:SetFontObject(ChatFontNormal or GameFontHighlightSmall)
    self.eb:SetScript("OnTextChanged", function(s, userInput)
        if userInput then
            self:UpdateInputPreview(s:GetText())
            self:UpdateWhisperTarget()
        end
    end)
    self.eb:SetScript("OnEnterPressed", function(s)
        local keepOpen = self:Send(s:GetText())
        s:SetText("")
        if keepOpen then
            self._forceReveal = true
            self:UpdateInputLayout()
            s:SetFocus()
        else
            s:ClearFocus()
            self._forceReveal = false
            self:UpdateInputLayout()
        end
    end)
    self.eb:SetScript("OnEscapePressed", function(s)
        s:SetText("")
        s:ClearFocus()
        self._forceReveal = false
        self:UpdateInputLayout()
    end)
    self.eb:SetScript("OnEditFocusGained", function()
        self._forceReveal = true
        self:UpdateInputLayout()
        self:UpdateInputPreview(self.eb and self.eb:GetText() or "")
    end)
    self.eb:SetScript("OnEditFocusLost", function()
        self._forceReveal = false
        self:UpdateInputLayout()
    end)
    self.eb:SetScript("OnTabPressed", function()
        self:CycleWriteChannel()
    end)

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
        self:AddMessage(typeKey, msg, author, channelName, guid, event)
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
    self.sev:SetScript("OnEvent", function()
        self:RefreshSocialCounts()
        if self.tab == "social" then self:RefreshSocial() end
    end)

    self:ApplyConfig()
    self:SetTab(self.tab or "chat")
end

-- Ajoute les catégories du registre complet absentes de la config (migration non-destructive).
function M:EnsureChannels()
    local cfg = SP:GetModuleConfig(self.name)
    cfg.channels = cfg.channels or {}
    local have = {}
    for _, ch in ipairs(cfg.channels) do have[ch.key] = true end
    for _, e in ipairs(EXTRA_CHANNELS) do
        if not have[e.key] then
            local copy = { key = e.key, label = e.label, r = e.r, g = e.g, b = e.b, enabled = e.enabled, types = {} }
            for t in pairs(e.types) do copy.types[t] = true end
            cfg.channels[#cfg.channels + 1] = copy
        end
    end
end

function M:BlizzardChatFrames()
    local frames = {}
    local n = NUM_CHAT_WINDOWS or 10
    for i = 1, n do
        frames[#frames + 1] = _G["ChatFrame" .. i]
        frames[#frames + 1] = _G["ChatFrame" .. i .. "Tab"]
        frames[#frames + 1] = _G["ChatFrame" .. i .. "EditBox"]
    end
    frames[#frames + 1] = ChatFrameMenuButton
    frames[#frames + 1] = ChatFrameChannelButton
    frames[#frames + 1] = ChatFrameToggleVoiceDeafenButton
    frames[#frames + 1] = ChatFrameToggleVoiceMuteButton
    frames[#frames + 1] = QuickJoinToastButton
    return frames
end

function M:ShouldHideBlizzardChat()
    local cfg = SP:GetModuleConfig(self.name)
    return self._enabled and cfg and cfg.hideBlizzardChat ~= false
end

function M:SetBlizzardChatHidden(hidden)
    hidden = hidden and true or false
    self._hiddenBlizzard = self._hiddenBlizzard or {}
    for _, f in ipairs(self:BlizzardChatFrames()) do
        if f and f.Hide and f.Show then
            if hidden then
                if self._hiddenBlizzard[f] == nil then self._hiddenBlizzard[f] = f:IsShown() and true or false end
                pcall(f.Hide, f)
            elseif self._hiddenBlizzard[f] then
                pcall(f.Show, f)
            end
        end
    end
    if not hidden then self._hiddenBlizzard = {} end
end

function M:ApplyBlizzardChatVisibility()
    self:SetBlizzardChatHidden(self:ShouldHideBlizzardChat())
end

function M:ShouldReplaceBlizzardInput()
    local cfg = SP:GetModuleConfig(self.name)
    return self._enabled and cfg and cfg.replaceBlizzardInput ~= false
end

function M:IsBlizzardChatEditBox(frame)
    if not frame then return false end
    local n = NUM_CHAT_WINDOWS or 10
    for i = 1, n do
        if frame == _G["ChatFrame" .. i .. "EditBox"] then return true end
    end
    return frame == _G.ACTIVE_CHAT_EDIT_BOX
end

function M:InstallChatHooks()
    self._chatHookedFrames = self._chatHookedFrames or {}

    local function onShowOrFocus(frame)
        if self._sendingNativeSlash then return end
        if self._loginGuardUntil and (GetTime and GetTime() or 0) < self._loginGuardUntil then return end
        if self:IsBlizzardChatEditBox(frame) and self:ShouldReplaceBlizzardInput() then
            self:OpenInput(nil, frame)
        elseif self:ShouldHideBlizzardChat() and frame and frame.Hide then
            pcall(frame.Hide, frame)
        end
    end

    for _, f in ipairs(self:BlizzardChatFrames()) do
        if f and f.HookScript and not self._chatHookedFrames[f] then
            self._chatHookedFrames[f] = true
            pcall(f.HookScript, f, "OnShow", onShowOrFocus)
            if self:IsBlizzardChatEditBox(f) then
                pcall(f.HookScript, f, "OnEditFocusGained", onShowOrFocus)
            end
        end
    end

    if hooksecurefunc then
        if ChatFrame_OpenChat and not self._chatOpenHookInstalled then
            local ok = pcall(hooksecurefunc, "ChatFrame_OpenChat", function(text)
                if self:ShouldReplaceBlizzardInput() then self:OpenInput(text or "", _G.ACTIVE_CHAT_EDIT_BOX or ChatFrame1EditBox) end
            end)
            if ok then self._chatOpenHookInstalled = true end
        end
        if ChatEdit_ActivateChat and not self._chatActivateHookInstalled then
            local ok = pcall(hooksecurefunc, "ChatEdit_ActivateChat", function(editBox)
                if self._loginGuardUntil and (GetTime and GetTime() or 0) < self._loginGuardUntil then return end
                if self:ShouldReplaceBlizzardInput() then self:OpenInput(nil, editBox) end
            end)
            if ok then self._chatActivateHookInstalled = true end
        end
    end
end

function M:OpenInput(text, sourceEditBox)
    if self._openingInput then return end
    self._openingInput = true
    local cfg = SP:GetModuleConfig(self.name)
    if not cfg then self._openingInput = false; return end
    if not cfg.enabled then self._openingInput = false; return end
    local blizzEdit = sourceEditBox or _G.ACTIVE_CHAT_EDIT_BOX or ChatFrame1EditBox
    if blizzEdit and blizzEdit.GetAttribute then
        self:AdoptBlizzardChatType(blizzEdit)
        if (not text or text == "") and blizzEdit.GetText then text = blizzEdit:GetText() end
        if blizzEdit.ClearFocus then pcall(blizzEdit.ClearFocus, blizzEdit) end
        if blizzEdit.Hide then pcall(blizzEdit.Hide, blizzEdit) end
    end
    local now = GetTime and GetTime() or 0
    if SP.panel then SP.panel._panelActive = now; SP.panel:Show() end
    if cfg.panel == 2 and SP.panel2 then SP.panel2._panelActive = now; SP.panel2:Show() end
    cfg.collapsed = false
    self._forceReveal = true
    SP:UpdateCollapseVisual(self)
    SP:RebuildLayout()
    self:SetTab("chat")
    self:ApplyBlizzardChatVisibility()
    if self.eb then
        self.eb:Show()
        self.eb:SetText(text or "")
        self.eb:SetCursorPosition((text and #text) or 0)
        self:UpdateInputLayout()
        self:UpdateInputPreview(text or "")
        self.eb:SetFocus()
    end
    self._openingInput = false
end

function M:AdoptBlizzardChatType(editBox)
    if not editBox or not editBox.GetAttribute then return end
    local t = editBox:GetAttribute("chatType")
    if not t or t == "" then return end
    if t == "WHISPER" then
        self.writeType = "WHISPER"
        self._lastWhisper = editBox:GetAttribute("tellTarget") or (ChatEdit_GetLastTellTarget and ChatEdit_GetLastTellTarget())
    elseif t == "CHANNEL" then
        self.writeType = "CUSTOM"
        self.writeChannel = editBox:GetAttribute("channelTarget")
    elseif t == "PARTY" or t == "RAID" or t == "INSTANCE_CHAT" or t == "GUILD" or t == "YELL" or t == "EMOTE" or t == "SAY" then
        self.writeType = t
        self.writeChannel = nil
    end
end

function M:Enable()
    self._enabled = true
    -- fenêtre de grâce : ignore l'activation AUTOMATIQUE du chat par Blizzard au login
    -- (sinon la fenêtre de saisie s'ouvre seule à la connexion). N'affecte pas les ouvertures
    -- volontaires faites ensuite par l'utilisateur.
    self._loginGuardUntil = (GetTime and GetTime() or 0) + 3
    if self._placeholder then self._placeholder:Hide() end
    self:EnsureChannels()
    self:ApplyConfig()
    self:InstallChatHooks()
    self:ApplyBlizzardChatVisibility()
    if C_Timer and C_Timer.After then
        C_Timer.After(0.5, function()
            if self._enabled then
                self:InstallChatHooks()
                self:ApplyBlizzardChatVisibility()
            end
        end)
    end
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
            self:RefreshSocialCounts()
            if self.tab == "social" then self:RefreshSocial() end
        end)
    end
    self:RefreshSocialCounts()
end

function M:Disable()
    self._enabled = false
    if self.ev then self.ev:UnregisterAllEvents() end
    if self.sev then self.sev:UnregisterAllEvents() end
    if self._socialTicker then self._socialTicker:Cancel(); self._socialTicker = nil end
    if self.toastHost then self.toastHost:Hide() end
    for _, f in ipairs(self.toasts or {}) do f:Hide(); f._fading = false end
    if self.activeToasts then wipe(self.activeToasts) end
    if SP.ChatFollow and SP.ChatFollow.HideAll then SP.ChatFollow:HideAll() end
    if self.inputBand then self.inputBand:Hide(); self.inputBand:EnableMouse(false) end
    if self.eb and self.eb.ClearFocus then self.eb:ClearFocus() end
    self._forceReveal = false
    self:SetBlizzardChatHidden(false)
end

function M:OnResize(w, h)
    self:UpdateInputLayout()
end

function M:OnCollapseChanged(collapsed)
    if collapsed then
        if self.chatTabBar then self.chatTabBar:Hide() end
        if self.bar then self.bar:Hide() end
        if self.smf then self.smf:Hide() end
        if self.inputBand then self.inputBand:Hide() end
        if self.eb then self.eb:Hide(); self.eb:ClearFocus() end
        if self.copyBox then self.copyBox:Hide() end
        if self.social then self.social:Hide() end
    else
        self:SetTab(self.tab or "chat")
    end
end

function M:InputVisible()
    local cfg = SP:GetModuleConfig(self.name)
    if not cfg then return false end
    if cfg.inputAutoHide == false then return true end
    return self._forceReveal == true or (self.eb and self.eb.HasFocus and self.eb:HasFocus())
end

function M:UpdateInputLayout()
    if not (self.body and self.smf and self.eb and self.inputBand) then return end
    local cfg = SP:GetModuleConfig(self.name) or {}
    local chatOn = self.tab ~= "social" and not cfg.collapsed
    local showInput = chatOn and self:InputVisible()
    local h = math.max(26, math.min(42, tonumber(cfg.inputBandHeight) or 28))

    -- ScrollingMessageFrame : occupe tout le corps (pilule flottante, pas dans le panneau)
    self.smf:ClearAllPoints()
    self.smf:SetPoint("TOPLEFT",     self.body, "TOPLEFT",     4, -4)
    self.smf:SetPoint("BOTTOMRIGHT", self.body, "BOTTOMRIGHT", -4, 4)
    self.smf:SetShown(chatOn)

    -- Pilule flottante centrée sur l'écran, taille basée sur la largeur du module
    local panelW = math.max(self.body:GetWidth() or 280, 280)
    local pillW  = math.min(panelW + 60, 500)
    self.inputBand:SetSize(pillW, h)
    self.inputBand:ClearAllPoints()
    self.inputBand:SetPoint("CENTER", UIParent, "CENTER", 0, -240)
    SP:LayoutPill(self.inputBand)   -- repositionne les embouts après SetSize
    -- Click-through quand la saisie est fermée (ne bloque pas le jeu)
    self.inputBand:EnableMouse(showInput)
    self.inputBand:SetShown(showInput)

    self.eb:SetHeight(math.max(16, h - 8))
    self.eb:SetShown(showInput)

    -- Couleur du liseré selon le canal actif
    self:SetInputColorForType(
        (self.writeType == "CUSTOM") and "CHANNEL" or (self.writeType or "SAY"),
        self:PrimaryKey(self.writeType or "SAY"))
    self:UpdateWhisperTarget()
end

function M:SetInputColorForType(chatType, key)
    local info = chatType and ChatTypeInfo and ChatTypeInfo[chatType]
    local r, g, b
    if info then
        r, g, b = info.r or 1, info.g or 1, info.b or 1
    elseif key and self.colorOf and self.colorOf[key] then
        r, g, b = self.colorOf[key][1], self.colorOf[key][2], self.colorOf[key][3]
    else
        r, g, b = 1, 1, 1
    end
    if self.eb then self.eb:SetTextColor(r, g, b) end
    -- Liseré + point + glow de la pilule = couleur du canal actif
    if self.inputBand and self.inputBand.pill then
        SP:StylePill(self.inputBand, r, g, b, {
            bgAlpha = 0.5, borderAlpha = 0.92, glow = true, glowAlpha = 0.22, dot = true,
        })
    end
end

function M:UpdateInputPreview(text)
    text = text or ""
    local cmd, num = text:match("^/(%a+)"), text:match("^/(%d+)")
    if num then
        local n = tonumber(num)
        local nm = GetChannelName and select(2, GetChannelName(n))
        if nm and nm ~= "" then
            self.writeType, self.writeChannel = "CUSTOM", nm
            self:SetInputColorForType("CHANNEL")
            if self.viewLabel then self.viewLabel:SetText("|cFFAAAAAAcanal:|r " .. nm) end
            return
        end
    elseif cmd then
        local c = cmd:lower()
        if c == "w" or c == "whisper" or c == "t" or c == "tell" then
            local target = text:match("^/%a+%s+(%S+)")
            if target then self._lastWhisper = target end
            self.writeType, self.writeChannel = "WHISPER", nil
            self:SetInputColorForType("WHISPER", "W")
            if self.viewLabel then self.viewLabel:SetText("|cFFFF80FFwhisper|r" .. (target and (" -> " .. target) or "")) end
            return
        end
        local map = { g = "GUILD", gu = "GUILD", guild = "GUILD", p = "PARTY", party = "PARTY", r = "RAID", raid = "RAID", i = "INSTANCE_CHAT", inst = "INSTANCE_CHAT", instance = "INSTANCE_CHAT", o = "OFFICER", officer = "OFFICER", s = "SAY", say = "SAY", y = "YELL", yell = "YELL", e = "EMOTE", emote = "EMOTE" }
        local t = map[c]
        if t then
            self.writeType, self.writeChannel = t, nil
            self:SetInputColorForType(t, self:PrimaryKey(t))
            if self.viewLabel then self.viewLabel:SetText("|cFFAAAAAAcanal:|r " .. t) end
            return
        end
    end
    self:SetInputColorForType(self.writeType, self:PrimaryKey(self.writeType or "SAY"))
end

function M:ChannelByKey(key)
    for _, ch in ipairs(SP:GetModuleConfig(self.name).channels or {}) do
        if ch.key == key then return ch end
    end
end

function M:EnsureChatTabs()
    local cfg = SP:GetModuleConfig(self.name)
    cfg.chatTabs = cfg.chatTabs or {}
    if #cfg.chatTabs == 0 then
        cfg.chatTabs[1] = { id = "main", label = "Tout", channels = { "A" } }
    end
    for i, tab in ipairs(cfg.chatTabs) do
        tab.id = tab.id or ("tab" .. i)
        tab.label = tab.label or ("Chat " .. i)
        tab.channels = tab.channels or { "A" }
        if tab.showUnread == nil then tab.showUnread = true end
        tab.unread = tonumber(tab.unread) or 0
        if not tab.color then
            local p = TAB_PALETTE[((i - 1) % #TAB_PALETTE) + 1]
            tab.color = { p[1], p[2], p[3] }
        end
    end
    cfg.activeChatTab = cfg.activeChatTab or cfg.chatTabs[1].id
end

function M:ChatTabContainsMessage(tab, key)
    if not tab then return false end
    return self:TabHasChannel(tab, "A") or self:TabHasChannel(tab, key)
end

function M:IncrementUnreadFor(key)
    local cfg = SP:GetModuleConfig(self.name)
    self:EnsureChatTabs()
    for _, tab in ipairs(cfg.chatTabs or {}) do
        if self:ChatTabContainsMessage(tab, key) then
            if tab.id ~= cfg.activeChatTab or self.tab == "social" or cfg.collapsed then
                if tab.showUnread ~= false then tab.unread = (tonumber(tab.unread) or 0) + 1 end
            end
        end
    end
    self:RefreshChatTabButtons()
end

function M:GetActiveChatTab()
    local cfg = SP:GetModuleConfig(self.name)
    self:EnsureChatTabs()
    for _, tab in ipairs(cfg.chatTabs or {}) do
        if tab.id == cfg.activeChatTab then return tab end
    end
    cfg.activeChatTab = cfg.chatTabs[1] and cfg.chatTabs[1].id or "main"
    return cfg.chatTabs[1]
end

function M:TabHasChannel(tab, key)
    if not tab or not tab.channels then return false end
    for _, k in ipairs(tab.channels) do if k == key then return true end end
    return false
end

function M:ToggleChannelInActiveTab(key)
    if not key then return end
    local tab = self:GetActiveChatTab()
    if not tab then return end
    tab.channels = tab.channels or {}
    if key == "A" then
        tab.channels = { "A" }
    else
        for i = #tab.channels, 1, -1 do
            if tab.channels[i] == "A" then
                table.remove(tab.channels, i)
            elseif tab.channels[i] == key then
                table.remove(tab.channels, i)
                if #tab.channels == 0 then tab.channels[1] = "A" end
                self:SetView(tab.id)
                return
            end
        end
        tab.channels[#tab.channels + 1] = key
    end
    self:SetView(tab.id)
end

function M:CreateChatTab()
    local cfg = SP:GetModuleConfig(self.name)
    self:EnsureChatTabs()
    local n = #(cfg.chatTabs or {}) + 1
    local id = "tab" .. tostring(time()) .. tostring(n)
    cfg.chatTabs[#cfg.chatTabs + 1] = { id = id, label = "Chat " .. n, channels = { "A" } }
    cfg.activeChatTab = id
    self:ApplyConfig()
end

function M:DeleteChatTab(id)
    local cfg = SP:GetModuleConfig(self.name)
    self:EnsureChatTabs()
    if #cfg.chatTabs <= 1 then return end
    for i = #cfg.chatTabs, 1, -1 do
        if cfg.chatTabs[i].id == id then table.remove(cfg.chatTabs, i); break end
    end
    cfg.activeChatTab = cfg.chatTabs[1] and cfg.chatTabs[1].id or "main"
    self:ApplyConfig()
end

-- Bascule sur l'onglet ET prépare l'écriture dans SON canal (style du chat).
-- Ex. onglet raid → écrit en raid ; onglet "Tout" → SAY par défaut.
function M:WriteToTab(tabId)
    local cfg = SP:GetModuleConfig(self.name)
    self:EnsureChatTabs()
    for _, tab in ipairs(cfg.chatTabs or {}) do
        if tab.id == tabId then
            self:SetView(tabId)
            local key
            for _, k in ipairs(tab.channels or {}) do
                if k ~= "A" then key = k; break end   -- 1er canal spécifique de l'onglet
            end
            self:SetWrite(key or "A")
            return
        end
    end
end

function M:RefreshChatTabButtons()
    if not self.chatTabBar then return end
    local cfg = SP:GetModuleConfig(self.name)
    self:EnsureChatTabs()
    if cfg and cfg.collapsed then
        self.chatTabBar:Hide()
        for _, b in ipairs(self.chatTabBtns) do b:Hide() end
        if self.chatTabAdd then self.chatTabAdd:Hide() end
        return
    end
    self.chatTabBar:SetShown(self.tab ~= "social")
    for _, b in ipairs(self.chatTabBtns) do b:Hide() end
    local x, maxW = 0, self.chatTabBar:GetWidth() or 0
    for i, tab in ipairs(cfg.chatTabs or {}) do
        local b = self.chatTabBtns[i]
        if not b then
            b = CreateFrame("Button", nil, self.chatTabBar)
            b:SetHeight(16)
            b.bg = b:CreateTexture(nil, "BACKGROUND"); b.bg:SetAllPoints(b)
            b.fs = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); b.fs:SetAllPoints(b)
            b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            self.chatTabBtns[i] = b
        end
        local label = tab.label or tab.id
        local unread = tonumber(tab.unread) or 0
        local active = tab.id == cfg.activeChatTab
        local display = label
        if not active then
            display = (label:sub(1, 1) or "?")
            if unread > 0 and tab.showUnread ~= false then display = display .. " " .. tostring(unread) end
        elseif unread > 0 and tab.showUnread ~= false then
            display = label .. " " .. tostring(unread)
        end
        b.fs:SetText(display)
        local tc = tab.color or { 0.85, 0.9, 1 }
        b.fs:SetTextColor(tc[1], tc[2], tc[3], active and 1 or 0.8)
        local w = active and math.max(42, math.min(100, (b.fs:GetStringWidth() or #display * 7) + 18)) or math.max(22, math.min(42, (b.fs:GetStringWidth() or #display * 7) + 14))
        if maxW > 0 and x + w > maxW - 22 then b:Hide(); break end
        b:SetWidth(w)
        b:ClearAllPoints(); b:SetPoint("LEFT", self.chatTabBar, "LEFT", x, 0)
        -- fond teinté par la couleur de l'onglet
        b.bg:SetColorTexture(tc[1], tc[2], tc[3], active and 0.30 or ((unread > 0) and 0.20 or 0.08))
        b.tabId = tab.id
        b:SetScript("OnClick", function(s, mouse)
            if mouse == "RightButton" then self:WriteToTab(s.tabId)   -- écrit dans le canal de l'onglet (plus de suppression)
            else self:SetView(s.tabId) end
        end)
        b:SetScript("OnEnter", function()
            GameTooltip:SetOwner(b, "ANCHOR_BOTTOM")
            GameTooltip:SetText(label)
            if unread > 0 then GameTooltip:AddLine(tostring(unread) .. " message(s) non lu(s)", 1, 0.82, 0) end
            GameTooltip:AddLine("Clic gauche : afficher. Clic droit : écrire dans ce canal.", 0.7, 0.7, 0.7)
            GameTooltip:AddLine("(suppression : bouton x dans la config)", 0.5, 0.5, 0.5)
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        b:Show()
        x = x + w + 3
    end
    if not self.chatTabAdd then
        self.chatTabAdd = CreateFrame("Button", nil, self.chatTabBar)
        self.chatTabAdd:SetSize(18, 16)
        self.chatTabAdd.bg = self.chatTabAdd:CreateTexture(nil, "BACKGROUND"); self.chatTabAdd.bg:SetAllPoints(self.chatTabAdd); self.chatTabAdd.bg:SetColorTexture(1, 1, 1, 0.12)
        self.chatTabAdd.fs = self.chatTabAdd:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); self.chatTabAdd.fs:SetAllPoints(self.chatTabAdd); self.chatTabAdd.fs:SetText("+")
        self.chatTabAdd:SetScript("OnClick", function() self:CreateChatTab() end)
    end
    self.chatTabAdd:ClearAllPoints()
    self.chatTabAdd:SetPoint("LEFT", self.chatTabBar, "LEFT", x, 0)
    self.chatTabAdd:SetShown(maxW <= 0 or x + 20 <= maxW)
end

-- ------------------------------------------------------------
-- Application config : police, couleurs, boutons + séparateurs, buffers
-- ------------------------------------------------------------
function M:ApplyConfig()
    local cfg = SP:GetModuleConfig(self.name)
    self:EnsureChatTabs()
    pcall(function()
        local face, size, flags = SP:GetEffectiveModuleFont(self.name)
        self.smf:SetFont(face or cfg.font or STANDARD_TEXT_FONT, size or cfg.fontSize or 12, flags or "")
    end)
    if self.ApplyBlizzardChatVisibility then self:ApplyBlizzardChatVisibility() end
    if SP.ChatFollow and SP.ChatFollow.ApplyConfig then SP.ChatFollow:ApplyConfig() end

    self.colorOf = {}
    for _, ch in ipairs(cfg.channels or {}) do
        self.colorOf[ch.key] = { ch.r or 1, ch.g or 1, ch.b or 1 }
        self.buf[ch.key] = self.buf[ch.key] or {}
    end
    self.buf.A = self.buf.A or {}

    for _, b in ipairs(self.btns) do b:Hide() end
    for _, s in ipairs(self.seps) do s:Hide() end
    if self.bar then self.bar:Hide() end
    self:RefreshChatTabButtons()

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
                if mouse == "RightButton" then self:ToggleChannelInActiveTab(s.key) else self:SetWrite(s.key) end
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
    self:SetView(cfg.activeChatTab)
    self:UpdateInputLayout()
    self:RefreshSocialCounts()
end

-- ------------------------------------------------------------
-- Popups instantanes
-- ------------------------------------------------------------
function M:DirectColor(typeKey, channelName, pk)
    if typeKey == "WHISPER" or typeKey == "BN_WHISPER" then return { 1.0, 0.45, 1.0 } end
    if typeKey == "GUILD" or typeKey == "OFFICER" then return { 0.25, 1.0, 0.35 } end
    if typeKey == "PARTY" or typeKey == "RAID" or typeKey == "INSTANCE_CHAT" then return { 0.40, 0.70, 1.0 } end
    local cfg = SP:GetModuleConfig(self.name)
    for _, ch in ipairs((cfg and cfg.channels) or {}) do
        local def = KEYDEF[ch.key]
        if (ch.types and ch.types[typeKey])
            or (def and def.types and def.types[typeKey])
            or (def and def.isTrade and typeKey == "CHANNEL" and IsTradeChannel(channelName))
            or (ch.channelName and typeKey == "CHANNEL" and type(channelName) == "string" and channelName:lower():find(ch.channelName:lower(), 1, true)) then
            return { ch.r or 1, ch.g or 1, ch.b or 1 }
        end
    end
    return self.colorOf[pk] or self.colorOf.A or { 1, 1, 1 }
end

function M:CreateToast()
    local template = BackdropTemplateMixin and "BackdropTemplate" or nil
    local f = CreateFrame("Button", nil, self.toastHost, template)
    f:SetSize(360, 56)
    f:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    f:EnableMouse(true)
    if f.SetBackdrop then
        f:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = false, edgeSize = 14,
            insets = { left = 4, right = 4, top = 4, bottom = 4 },
        })
    end

    f.shadow = f:CreateTexture(nil, "BACKGROUND")
    f.shadow:SetPoint("TOPLEFT", f, "TOPLEFT", -18, 18)
    f.shadow:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 18, -18)
    f.shadow:SetColorTexture(0, 0, 0, 0.32)

    f.blur = f:CreateTexture(nil, "BACKGROUND", nil, 1)
    f.blur:SetPoint("TOPLEFT", f, "TOPLEFT", -9, 9)
    f.blur:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 9, -9)
    f.blur:SetBlendMode("ADD")

    f.glow = f:CreateTexture(nil, "BORDER")
    f.glow:SetPoint("TOPLEFT", f, "TOPLEFT", -4, 4)
    f.glow:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 4, -4)
    f.glow:SetBlendMode("ADD")

    f.line = f:CreateTexture(nil, "ARTWORK")
    f.line:SetPoint("LEFT", f, "LEFT", 10, 0)
    f.line:SetSize(3, 30)

    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.title:SetPoint("TOPLEFT", f, "TOPLEFT", 22, -9)
    f.title:SetJustifyH("LEFT")
    f.title:SetWordWrap(false)

    f.msg = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.msg:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 0, -1)
    f.msg:SetJustifyH("LEFT")
    f.msg:SetWordWrap(false)

    f.fadeIn = f:CreateAnimationGroup()
    local aIn = f.fadeIn:CreateAnimation("Alpha")
    aIn:SetFromAlpha(0)
    aIn:SetToAlpha(1)
    aIn:SetDuration(0.16)
    local move = f.fadeIn:CreateAnimation("Translation")
    move:SetOffset(0, -8)
    move:SetDuration(0.16)

    f.fadeOut = f:CreateAnimationGroup()
    local aOut = f.fadeOut:CreateAnimation("Alpha")
    aOut:SetFromAlpha(1)
    aOut:SetToAlpha(0)
    aOut:SetDuration(0.34)
    f.fadeOut:SetScript("OnFinished", function()
        f:Hide()
        self:RemoveToast(f)
    end)

    f:SetScript("OnEnter", function(s)
        s._toastToken = (s._toastToken or 0) + 1
    end)
    f:SetScript("OnLeave", function(s)
        local cfg = SP:GetModuleConfig(self.name)
        s._toastToken = (s._toastToken or 0) + 1
        local token = s._toastToken
        local duration = cfg and cfg.popupDuration or 7
        if C_Timer and C_Timer.After then
            C_Timer.After(duration, function()
                if s:IsShown() and s._toastToken == token and not s:IsMouseOver() then self:FadeToast(s) end
            end)
        end
    end)
    f:SetScript("OnClick", function(s)
        self:ReplyFromToast(s)
        self:FadeToast(s)
    end)
    f:Hide()
    return f
end

function M:StyleToast(f, color, theme)
    local r, g, b = color[1] or 1, color[2] or 1, color[3] or 1
    -- init verre dépoli + halo pulsant (une seule fois ; tout local à StyleToast)
    if not f._glassInit then
        f._glassInit = true
        -- reflet (sheen) translucide en haut → effet verre
        f._sheen = f:CreateTexture(nil, "ARTWORK")
        f._sheen:SetPoint("TOPLEFT", f, "TOPLEFT", 4, -4)
        f._sheen:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4)
        f._sheen:SetHeight(20)
        f._sheen:SetColorTexture(1, 1, 1, 1)
        if f._sheen.SetGradient and CreateColor then
            pcall(f._sheen.SetGradient, f._sheen, "VERTICAL", CreateColor(1, 1, 1, 0), CreateColor(1, 1, 1, 0.22))
        end
        -- halo de CONTOUR doux (texture glow native) + pulsation alpha continue
        pcall(f.glow.SetTexture, f.glow, "Interface\\Buttons\\UI-ActionButton-Border")
        f:HookScript("OnHide", function(s) s._pt = 0 end)
        f:SetScript("OnUpdate", function(s, e)
            s._pt = (s._pt or 0) + e
            s.glow:SetAlpha(0.28 + 0.34 * (0.5 + 0.5 * math.sin(s._pt * 3.1)))
        end)
        -- lisibilité du message sur fond translucide
        f.title:SetShadowColor(0, 0, 0, 0.85); f.title:SetShadowOffset(1, -1)
        f.msg:SetShadowColor(0, 0, 0, 0.85); f.msg:SetShadowOffset(1, -1)
    end

    if theme == "shadow" then
        if f.SetBackdropColor then f:SetBackdropColor(0.05, 0.07, 0.11, 0.55) end
        if f.SetBackdropBorderColor then f:SetBackdropBorderColor(r, g, b, 0.85) end
        f.shadow:SetColorTexture(0, 0, 0, 0.50)
        f.title:SetTextColor(r, g, b, 1)
        f.msg:SetTextColor(0.95, 0.97, 1, 1)
    else
        if f.SetBackdropColor then f:SetBackdropColor(0.88, 0.93, 1.0, 0.16) end   -- verre froid translucide
        if f.SetBackdropBorderColor then f:SetBackdropBorderColor(r, g, b, 0.85) end
        f.shadow:SetColorTexture(0, 0, 0, 0.28)
        f.title:SetTextColor(r, g, b, 1)
        f.msg:SetTextColor(1, 1, 1, 1)
    end
    -- givre interne : lueur blanche douce en dégradé (faux frost, pas un vrai blur)
    f.blur:SetColorTexture(1, 1, 1, 1)
    if f.blur.SetGradient and CreateColor then
        pcall(f.blur.SetGradient, f.blur, "VERTICAL", CreateColor(1, 1, 1, 0.02), CreateColor(1, 1, 1, 0.12))
    end
    f.glow:SetVertexColor(r, g, b)   -- halo teinté par le canal (alpha animé en OnUpdate)
    f.line:SetColorTexture(r, g, b, 0.95)
end

function M:AcquireToast()
    for _, f in ipairs(self.toasts) do
        if not f:IsShown() then return f end
    end
    local f = self:CreateToast()
    self.toasts[#self.toasts + 1] = f
    return f
end

function M:RemoveToast(frame)
    for i = #self.activeToasts, 1, -1 do
        if self.activeToasts[i] == frame then table.remove(self.activeToasts, i) end
    end
    self:LayoutToasts()
    if #self.activeToasts == 0 and self.toastHost then self.toastHost:Hide() end
end

function M:LayoutToasts()
    if not self.toastHost then return end
    for i, f in ipairs(self.activeToasts or {}) do
        f:ClearAllPoints()
        f:SetPoint("TOP", self.toastHost, "TOP", 0, -((i - 1) * 62))
    end
end

function M:FadeToast(frame)
    if not frame or frame._fading then return end
    frame._fading = true
    frame._toastToken = (frame._toastToken or 0) + 1
    if frame.fadeIn and frame.fadeIn:IsPlaying() then frame.fadeIn:Stop() end
    if frame.fadeOut then frame.fadeOut:Play() else frame:Hide(); self:RemoveToast(frame) end
end

function M:ReplyFromToast(frame)
    if not frame then return end
    if frame.replyType == "WHISPER" and frame.replyTo and frame.replyTo ~= "" then
        self.writeType, self.writeChannel = "WHISPER", nil
        self._lastWhisper = frame.replyTo
        self:OpenInput("", nil)
        if self.viewLabel then
            self.viewLabel:SetText("|cFF40FF40-> " .. CleanName(frame.replyTo) .. "|r")
        end
    else
        local replyType = frame.replyType or "SAY"
        self.writeType = replyType
        self.writeChannel = nil
        self:OpenInput("", nil)
        self.writeType = replyType
    end
end

function M:ShowInstantPopup(typeKey, msg, author, pk, channelName, rawEvent)
    local cfg = SP:GetModuleConfig(self.name)
    if not cfg or cfg.instantPopups == false then return end
    if rawEvent and rawEvent:find("_INFORM", 1, true) then return end
    if not INSTANT_POPUP_TYPES[typeKey] then return end
    local who = CleanName(author)
    if who == "" or who == (UnitName and UnitName("player")) then return end

    local f = self:AcquireToast()
    f._fading = false
    f._toastToken = (f._toastToken or 0) + 1
    f.replyTo = author
    f.replyType = REPLY_WRITE_TYPE[typeKey] or "SAY"
    if f.replyType == "WHISPER" then self._lastWhisper = author end

    local color = self:DirectColor(typeKey, channelName, pk)
    self:StyleToast(f, color, cfg.popupTheme or "light")
    f.title:SetText(who)
    local popupMsg = msg
    if #popupMsg > 150 then popupMsg = popupMsg:sub(1, 147) .. "..." end
    f.msg:SetText(popupMsg)

    local w = math.max(f.title:GetStringWidth() or 0, f.msg:GetStringWidth() or 0) + 46
    w = math.min(560, math.max(220, w))
    f:SetWidth(w)
    f.title:SetWidth(w - 44)
    f.msg:SetWidth(w - 44)
    f:SetHeight(56)
    if f.fadeOut and f.fadeOut:IsPlaying() then f.fadeOut:Stop() end
    f:SetAlpha(0)
    f:Show()
    self.toastHost:Show()

    for i = #self.activeToasts, 1, -1 do
        if self.activeToasts[i] == f then table.remove(self.activeToasts, i) end
    end
    table.insert(self.activeToasts, 1, f)
    while #self.activeToasts > 4 do
        local old = table.remove(self.activeToasts)
        self:FadeToast(old)
    end
    self:LayoutToasts()
    if f.fadeIn then f.fadeIn:Play() else f:SetAlpha(1) end

    local token = f._toastToken
    local duration = cfg.popupDuration or 7
    if C_Timer and C_Timer.After then
        C_Timer.After(duration, function()
            if f:IsShown() and f._toastToken == token then self:FadeToast(f) end
        end)
    end
end

-- ------------------------------------------------------------
-- Messages
-- ------------------------------------------------------------
function M:PrimaryKey(typeKey, channelName)
    for _, ch in ipairs(SP:GetModuleConfig(self.name).channels or {}) do
        if ch.enabled and ch.key ~= "A" then
            if ch.types and ch.types[typeKey] then return ch.key end   -- registre par set de types
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

function M:AddMessage(typeKey, msg, author, channelName, guid, rawEvent)
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
    local entry = { line, col[1], col[2], col[3], id }
    entry.id = id

    self:Push("A", entry)
    if pk ~= "A" then self:Push(pk, entry) end
    self:IncrementUnreadFor(pk)
    local tab = self:GetActiveChatTab()
    local cfg = SP:GetModuleConfig(self.name)
    if not (cfg and cfg.collapsed) and self.tab ~= "social" and (self:TabHasChannel(tab, "A") or self:TabHasChannel(tab, pk)) then self:SetView(tab.id) end
    if SP.ChatFollow and SP.ChatFollow.OnChatMessage then
        SP.ChatFollow:OnChatMessage(self, typeKey, msg, author, pk, channelName, rawEvent, id)
    else
        self:ShowInstantPopup(typeKey, msg, author, pk, channelName, rawEvent)
    end
end

function M:SetView(key)
    local cfg = SP:GetModuleConfig(self.name)
    self:EnsureChatTabs()
    if key then cfg.activeChatTab = key end
    local tab = self:GetActiveChatTab()
    if tab then tab.unread = 0 end
    self.viewFilter = tab and tab.id or key or "main"
    self.smf:Clear()
    local merged, seen = {}, {}
    local channels = (tab and tab.channels) or { "A" }
    if self:TabHasChannel(tab, "A") then channels = { "A" } end
    for _, chKey in ipairs(channels) do
        for _, e in ipairs(self.buf[chKey] or {}) do
            local eid = e.id or e[5] or tostring(e[1])
            if not seen[eid] then
                seen[eid] = true
                merged[#merged + 1] = e
            end
        end
    end
    table.sort(merged, function(a, b) return (a.id or a[5] or 0) < (b.id or b[5] or 0) end)
    for _, e in ipairs(merged) do self.smf:AddMessage(e[1], e[2], e[3], e[4]) end
    for i = 1, (self._btnUsed or 0) do
        local b = self.btns[i]
        if b then b.sel:SetShown(self:TabHasChannel(tab, b.key)) end
    end
    if self.viewLabel then self.viewLabel:SetText("|cFFAAAAAAvue:|r " .. ((tab and tab.label) or key)) end
    self:RefreshChatTabButtons()
end

function M:SetWrite(key)
    local def = KEYDEF[key]
    local ch = self:ChannelByKey(key)
    if def then self.writeType, self.writeChannel = def.write, nil
    elseif ch and ch.channelName then self.writeType, self.writeChannel = "CUSTOM", ch.channelName
    else self.writeType, self.writeChannel = "SAY", nil end
    local col = self.colorOf[key] or { 1, 1, 1 }
    if self.eb then
        self._forceReveal = true
        self:UpdateInputLayout()
        self:SetInputColorForType((self.writeType == "CUSTOM") and "CHANNEL" or self.writeType, key)
        self.eb:SetFocus()
    end
end

function M:StartWhisper(name)
    self.writeType, self.writeChannel = "WHISPER", nil
    self._lastWhisper = name
    if self.eb then
        self._forceReveal = true
        self:UpdateInputLayout()
        self:SetInputColorForType("WHISPER", "W")
        self:UpdateWhisperTarget()
        self.eb:SetFocus()
    end
    if self.viewLabel then
        self.viewLabel:SetText("|cFF40FF40-> " .. (Ambiguate and Ambiguate(name, "none") or name) .. "|r")
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

-- Bascule vers le premier onglet contenant la clé (sinon un onglet "Tout").
function M:SwitchToTabForKey(key)
    if not key then return end
    local cfg = SP:GetModuleConfig(self.name)
    self:EnsureChatTabs()
    for _, tab in ipairs(cfg.chatTabs or {}) do
        if self:TabHasChannel(tab, key) and not self:TabHasChannel(tab, "A") then self:SetView(tab.id); return true end
    end
    for _, tab in ipairs(cfg.chatTabs or {}) do
        if self:TabHasChannel(tab, "A") then self:SetView(tab.id); return true end
    end
end

-- Déduit la clé de canal visée par une commande slash (/g, /2, /i…) pour basculer.
function M:KeyForCommand(text)
    local cmd, num = text:match("^/(%a+)"), text:match("^/(%d+)")
    if num then
        local n = tonumber(num)
        local nm = GetChannelName and select(2, GetChannelName(n))
        if nm then return self:PrimaryKey("CHANNEL", nm) end
        return nil
    end
    if cmd then
        local tk = CMD_TYPE[cmd:lower()]
        if tk then return self:PrimaryKey(tk) end
    end
end

function M:Send(text)
    if not text or text == "" then return end
    if text:sub(1, 1) == "/" then
        local whisperTarget = text:match("^/[wWtT][hH]?[iI]?[sS]?[pP]?[eE]?[rR]?%s+(%S+)%s*$")
        if whisperTarget then
            self:StartWhisper(whisperTarget)
            return true
        end
        local channelOnly = text:match("^/(%d+)%s*$")
        if channelOnly then
            local nm = GetChannelName and select(2, GetChannelName(tonumber(channelOnly)))
            if nm and nm ~= "" then
                self.writeType, self.writeChannel = "CUSTOM", nm
                self:SetInputColorForType("CHANNEL")
                if self.viewLabel then self.viewLabel:SetText("|cFFAAAAAAcanal:|r " .. nm) end
                return true
            end
        end
        local switchKey = self:KeyForCommand(text)   -- bascule vers la bonne fenêtre
        local eb = ChatFrame1EditBox or (DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.editBox)
        if eb and (ChatEdit_SendText or ChatEdit_ParseText) then
            self._sendingNativeSlash = true
            local ok = pcall(function()
                eb:SetText(text)
                -- EXÉCUTE réellement la commande/envoi. ChatEdit_SendText(eb,1) = comme Entrée.
                -- (ChatEdit_ParseText(eb, 0) ne faisait que parser sans envoyer → bug.)
                if ChatEdit_SendText then ChatEdit_SendText(eb, 1)
                else ChatEdit_ParseText(eb, 1) end
                eb:SetText("")
                eb:ClearFocus()
                if eb.Hide then eb:Hide() end
            end)
            self._sendingNativeSlash = false
            self:ApplyBlizzardChatVisibility()
            if ok then
                if switchKey then self:SwitchToTabForKey(switchKey) end
                self:UpdateInputPreview("")
                return
            end
        end
    end
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
    elseif w == "PARTY" or w == "RAID" or w == "INSTANCE_CHAT" or w == "YELL" or w == "EMOTE" or w == "OFFICER" then
        pcall(SendChatMessage, text, w)
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

-- Affiche la cible du chuchotement dans la pilule de saisie et repositionne l'EB.
function M:UpdateWhisperTarget()
    local band = self.inputBand
    if not band then return end
    local lbl  = band.targetLabel
    local hint = band.tabHint
    if self.writeType == "WHISPER" and self._lastWhisper and self._lastWhisper ~= "" then
        local short = (Ambiguate and Ambiguate(self._lastWhisper, "none")) or self._lastWhisper
        if lbl then
            lbl:SetText("|cFFFF80FF-> " .. short .. "|r")
            lbl:Show()
            -- label ancré à LEFT+16 → l'eb démarre après lui
            local lw = math.max(16, 16 + (lbl:GetStringWidth() or 0) + 8)
            if self.eb then
                self.eb:ClearAllPoints()
                self.eb:SetPoint("LEFT",  band, "LEFT",  lw, 0)
                self.eb:SetPoint("RIGHT", band, "RIGHT", -14, 0)
            end
        end
    else
        if lbl then lbl:Hide() end
        if self.eb then
            self.eb:ClearAllPoints()
            self.eb:SetPoint("LEFT",  band, "LEFT",  16, 0)
            self.eb:SetPoint("RIGHT", band, "RIGHT", -14, 0)
        end
    end
    -- Hint Tab : visible 3 s après l'ouverture
    if hint then
        if self._forceReveal and not self._tabHintShown then
            self._tabHintShown = true
            hint:Show()
            C_Timer.After(3, function() self._tabHintShown = false; if hint then hint:Hide() end end)
        end
    end
end

-- Tab : cycle SAY → GUILD → GROUP/RAID → WHISPER récent → SAY…
function M:CycleWriteChannel()
    local sequence = {}
    sequence[#sequence + 1] = "SAY"
    if IsInGuild and IsInGuild() then
        sequence[#sequence + 1] = "GUILD"
    end
    if IsInGroup and IsInGroup() then
        if IsInRaid and IsInRaid() then
            sequence[#sequence + 1] = "RAID"
        elseif LE_PARTY_CATEGORY_INSTANCE and IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
            sequence[#sequence + 1] = "INSTANCE_CHAT"
        else
            sequence[#sequence + 1] = "GROUP"
        end
    end
    if self._lastWhisper and self._lastWhisper ~= "" then
        sequence[#sequence + 1] = "WHISPER"
    end
    if #sequence == 0 then return end
    local cur = self.writeType or "SAY"
    local idx = 1
    for i, t in ipairs(sequence) do
        if t == cur then idx = (i % #sequence) + 1; break end
    end
    self.writeType = sequence[idx]
    self.writeChannel = nil
    self:UpdateInputPreview(self.eb and self.eb:GetText() or "")
    self:UpdateWhisperTarget()
end

-- ============================================================
-- Onglets Chat / Social + cycle de canaux
-- ============================================================
function M:SetTab(tab)
    self.tab = tab
    local chatOn = (tab ~= "social")
    local cfg = SP:GetModuleConfig(self.name)
    if self.chatTabBar then self.chatTabBar:SetShown(chatOn and not (cfg and cfg.collapsed)) end
    if self.bar then self.bar:Hide() end
    if self.social then self.social:SetShown(not chatOn) end
    self:UpdateInputLayout()
    if self.chatModeBtn and self.chatModeBtn.bg then self.chatModeBtn.bg:SetColorTexture(0.30, 0.55, 0.95, chatOn and 0.32 or 0.10) end
    if self.socialBtn and self.socialBtn.bg then self.socialBtn.bg:SetColorTexture(0.30, 0.55, 0.95, (not chatOn) and 0.32 or 0.12) end
    if not chatOn then self:RefreshSocial() end
    self:RefreshChatTabButtons()
    self:RefreshSocialCounts()
end

function M:CycleChannel(delta)
    local cfg = SP:GetModuleConfig(self.name)
    self:EnsureChatTabs()
    local keys = {}
    for _, tab in ipairs(cfg.chatTabs or {}) do keys[#keys + 1] = tab.id end
    if #keys == 0 then return end
    local idx = 1
    for i, k in ipairs(keys) do if k == cfg.activeChatTab then idx = i; break end end
    idx = ((idx - 1 - delta) % #keys) + 1
    self:SetView(keys[idx])
end

function M:RefreshSocialCounts()
    local friends, guild = 0, 0
    local nBN = BNGetNumFriends and BNGetNumFriends() or 0
    for i = 1, nBN do
        local ok, acc = (C_BattleNet and C_BattleNet.GetFriendAccountInfo) and pcall(C_BattleNet.GetFriendAccountInfo, i)
        local g = ok and acc and acc.gameAccountInfo
        if g and g.isOnline and g.clientProgram == "WoW" then friends = friends + 1 end
    end
    local nF = (C_FriendList and C_FriendList.GetNumFriends and C_FriendList.GetNumFriends()) or 0
    for i = 1, nF do
        local ok, info = pcall(C_FriendList.GetFriendInfoByIndex, i)
        if ok and info and info.connected then friends = friends + 1 end
    end
    if IsInGuild and IsInGuild() then
        local total = GetNumGuildMembers and GetNumGuildMembers() or 0
        for i = 1, total do
            local _, _, _, _, _, _, _, _, online = GetGuildRosterInfo(i)
            if online then guild = guild + 1 end
        end
    end
    self._socialCounts.friends, self._socialCounts.guild = friends, guild
    if self.socialBtn and self.socialBtn.fs then
        self.socialBtn.fs:SetText(("|cFF66AAFF%d|r |cFF40FF40%d|r"):format(friends, guild))
    end
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
    self:RefreshSocialCounts()
    local entries = {}
    local nBN = BNGetNumFriends and BNGetNumFriends() or 0
    for i = 1, nBN do
        local ok, acc = (C_BattleNet and C_BattleNet.GetFriendAccountInfo) and pcall(C_BattleNet.GetFriendAccountInfo, i)
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
