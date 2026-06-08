-- ============================================================
-- Module : Chat — chat additionnel intégré (ne remplace PAS l'existant)
-- ============================================================
-- Étape 9. Zone de messages dédiée + barre de canaux colorés (G/W/G/i).
-- Cliquer un canal = écrire dedans via l'éditbox du module. ChatFrame1 n'est jamais touché.
local ADDON_NAME, SP = ...

local M = {
    name          = "Chat",
    label         = "Chat",
    defaultHeight = 200,
}

-- Événements de chat à afficher (suffixe = clé ChatTypeInfo).
local CHAT_EVENTS = {
    "CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_EMOTE",
    "CHAT_MSG_GUILD", "CHAT_MSG_OFFICER",
    "CHAT_MSG_WHISPER", "CHAT_MSG_WHISPER_INFORM", "CHAT_MSG_BN_WHISPER", "CHAT_MSG_BN_WHISPER_INFORM",
    "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER",
    "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER", "CHAT_MSG_RAID_WARNING",
    "CHAT_MSG_INSTANCE_CHAT", "CHAT_MSG_INSTANCE_CHAT_LEADER",
    "CHAT_MSG_CHANNEL",
}

-- Normalise un suffixe d'event vers une clé ChatTypeInfo.
local function TypeKey(suffix)
    if suffix == "WHISPER_INFORM" or suffix == "BN_WHISPER" or suffix == "BN_WHISPER_INFORM" then return "WHISPER" end
    return suffix
end

-- Boutons de canal : { label, type, infoKey, tip }
local CHANNELS = {
    { label = "G", type = "SAY",           info = "SAY",           tip = "Dire / général (tout)" },
    { label = "W", type = "WHISPER",       info = "WHISPER",       tip = "Chuchotement (dernière cible)" },
    { label = "G", type = "GUILD",         info = "GUILD",         tip = "Guilde" },
    { label = "i", type = "INSTANCE_CHAT", info = "INSTANCE_CHAT", tip = "Instance" },
}

local function ChanColor(infoKey)
    local ci = ChatTypeInfo and ChatTypeInfo[infoKey]
    if ci then return ci.r, ci.g, ci.b end
    return 1, 1, 1
end

function M:Init(body)
    self.body = body
    self.activeType = "SAY"

    -- Barre de canaux (en haut du body, façon "à côté du titre")
    self.bar = CreateFrame("Frame", nil, body)
    self.bar:SetPoint("TOPLEFT", body, "TOPLEFT", 4, -2)
    self.bar:SetPoint("TOPRIGHT", body, "TOPRIGHT", -4, -2)
    self.bar:SetHeight(16)
    self.chanBtns = {}
    local x = 0
    for i, ch in ipairs(CHANNELS) do
        local b = CreateFrame("Button", nil, self.bar)
        b:SetSize(18, 16)
        b:SetPoint("LEFT", self.bar, "LEFT", x, 0)
        b.fs = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        b.fs:SetAllPoints(b)
        local r, g, bl = ChanColor(ch.info)
        b.fs:SetText(ch.label)
        b.fs:SetTextColor(r, g, bl)
        b.chType, b.tip = ch.type, ch.tip
        b:SetScript("OnClick", function(s) self:SetActive(s.chType) end)
        b:SetScript("OnEnter", function(s)
            GameTooltip:SetOwner(s, "ANCHOR_RIGHT"); GameTooltip:SetText(s.tip); GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        self.chanBtns[i] = b
        x = x + 22
    end

    -- Indicateur de canal actif (à droite de la barre)
    self.activeFS = self.bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    self.activeFS:SetPoint("RIGHT", self.bar, "RIGHT", 0, 0)

    -- Zone de messages
    self.smf = CreateFrame("ScrollingMessageFrame", nil, body)
    self.smf:SetPoint("TOPLEFT", self.bar, "BOTTOMLEFT", 0, -2)
    self.smf:SetPoint("BOTTOMRIGHT", body, "BOTTOMRIGHT", -4, 22)
    self.smf:SetFontObject(ChatFontNormal or GameFontHighlightSmall)
    self.smf:SetJustifyH("LEFT")
    self.smf:SetFading(false)
    self.smf:SetMaxLines(300)
    self.smf:SetHyperlinksEnabled(true)
    self.smf:EnableMouseWheel(true)
    self.smf:SetScript("OnMouseWheel", function(s, delta)
        if delta > 0 then s:ScrollUp() else s:ScrollDown() end
    end)
    self.smf:SetScript("OnHyperlinkClick", function(_, link, text, button)
        SetItemRef(link, text, button)
    end)

    -- Éditbox
    self.eb = CreateFrame("EditBox", nil, body)
    self.eb:SetPoint("BOTTOMLEFT", body, "BOTTOMLEFT", 4, 2)
    self.eb:SetPoint("BOTTOMRIGHT", body, "BOTTOMRIGHT", -4, 2)
    self.eb:SetHeight(18)
    self.eb:SetAutoFocus(false)
    self.eb:SetFontObject(ChatFontNormal or GameFontHighlightSmall)
    self.eb:SetScript("OnEnterPressed", function(s)
        self:Send(s:GetText()); s:SetText(""); s:ClearFocus()
    end)
    self.eb:SetScript("OnEscapePressed", function(s) s:SetText(""); s:ClearFocus() end)

    self.ev = CreateFrame("Frame")
    self.ev:SetScript("OnEvent", function(_, event, msg, author)
        local suffix = event:gsub("^CHAT_MSG_", "")
        if suffix == "WHISPER" and author and author ~= "" then
            self._lastWhisper = author   -- mémorise la dernière cible pour répondre
        end
        self:AddMessage(TypeKey(suffix), msg, author)
    end)

    self:SetActive("SAY")
end

function M:Enable()
    self._enabled = true
    if self._placeholder then self._placeholder:Hide() end
    for _, e in ipairs(CHAT_EVENTS) do pcall(self.ev.RegisterEvent, self.ev, e) end
end

function M:Disable()
    self._enabled = false
    if self.ev then self.ev:UnregisterAllEvents() end
end

function M:SetActive(chType)
    self.activeType = chType
    local key = chType
    local r, g, b = ChanColor(key)
    if self.activeFS then
        self.activeFS:SetText("→ " .. chType)
        self.activeFS:SetTextColor(r, g, b)
    end
    if self.eb then self.eb:SetTextColor(r, g, b) end
    if self.eb then self.eb:SetFocus() end
end

function M:AddMessage(typeKey, msg, author)
    if not self.smf or type(msg) ~= "string" then return end
    local ci = ChatTypeInfo and ChatTypeInfo[typeKey] or { r = 1, g = 1, b = 1 }
    local prefix = ""
    if author and author ~= "" then
        local short = Ambiguate and Ambiguate(author, "none") or author
        prefix = "|cffffffff" .. short .. "|r: "
    end
    self.smf:AddMessage(prefix .. msg, ci.r, ci.g, ci.b)
end

function M:Send(text)
    if not text or text == "" then return end
    local t = self.activeType or "SAY"
    if t == "WHISPER" then
        local target = self._lastWhisper
        if not target and ChatEdit_GetLastTellTarget then target = ChatEdit_GetLastTellTarget() end
        if target and target ~= "" then
            pcall(SendChatMessage, text, "WHISPER", nil, target)
        else
            SP:Print("Chat : aucune cible de chuchotement récente.")
        end
    else
        pcall(SendChatMessage, text, t)
    end
end

function M:OnResize(w, h) end

SP:RegisterModule(M)
