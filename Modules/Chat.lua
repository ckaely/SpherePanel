-- ============================================================
-- Module : Chat — panneaux filtrés configurables (additionnel)
-- ============================================================
-- Boutons de canaux pilotés par la config (couleur/ordre/activation).
--   clic DROIT = affiche le panneau filtré ; clic GAUCHE = arme l'écriture.
-- Noms colorés par classe, liens cliquables (copie), police/taille configurables.
local ADDON_NAME, SP = ...

local M = {
    name          = "Chat",
    label         = "Chat",
    defaultHeight = 200,
}

local CAP = 200

local CHAT_EVENTS = {
    "CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_EMOTE",
    "CHAT_MSG_GUILD", "CHAT_MSG_OFFICER",
    "CHAT_MSG_WHISPER", "CHAT_MSG_WHISPER_INFORM", "CHAT_MSG_BN_WHISPER", "CHAT_MSG_BN_WHISPER_INFORM",
    "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER",
    "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER", "CHAT_MSG_RAID_WARNING",
    "CHAT_MSG_INSTANCE_CHAT", "CHAT_MSG_INSTANCE_CHAT_LEADER",
    "CHAT_MSG_CHANNEL",
}

-- Définition statique des clés de canal : write = canal d'envoi ; types = events captés ; isTrade.
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
    if suffix == "INSTANCE_CHAT" then return "INSTANCE_CHAT" end
    return suffix
end

local function IsTradeChannel(channelName)
    if type(channelName) ~= "string" then return false end
    local l = channelName:lower()
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
    self.buf = { A = {}, S = {}, W = {}, I = {}, G = {}, M = {} }
    self.btns = {}

    self.bar = CreateFrame("Frame", nil, body)
    self.bar:SetPoint("TOPLEFT", body, "TOPLEFT", 4, -2)
    self.bar:SetPoint("TOPRIGHT", body, "TOPRIGHT", -4, -2)
    self.bar:SetHeight(16)
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
        if url then self:CopyLink(url) else SetItemRef(link, text, button) end
    end)

    self.eb = CreateFrame("EditBox", nil, body)
    self.eb:SetPoint("BOTTOMLEFT", body, "BOTTOMLEFT", 4, 2)
    self.eb:SetPoint("BOTTOMRIGHT", body, "BOTTOMRIGHT", -4, 2)
    self.eb:SetHeight(18)
    self.eb:SetAutoFocus(false)
    self.eb:SetFontObject(ChatFontNormal or GameFontHighlightSmall)
    self.eb:SetScript("OnEnterPressed", function(s) self:Send(s:GetText()); s:SetText(""); s:ClearFocus() end)
    self.eb:SetScript("OnEscapePressed", function(s) s:SetText(""); s:ClearFocus() end)

    -- Éditbox de copie de lien (sélectionnée pour Ctrl+C)
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
        self:AddMessage(typeKey, msg, author, channelName, guid)
    end)

    self:ApplyConfig()
end

function M:Enable()
    self._enabled = true
    if self._placeholder then self._placeholder:Hide() end
    self:ApplyConfig()
    for _, e in ipairs(CHAT_EVENTS) do pcall(self.ev.RegisterEvent, self.ev, e) end
end

function M:Disable()
    self._enabled = false
    if self.ev then self.ev:UnregisterAllEvents() end
end

function M:OnResize(w, h) end

-- ------------------------------------------------------------
-- Application de la config (couleurs / ordre / canaux / police)
-- ------------------------------------------------------------
function M:ApplyConfig()
    local cfg = SP:GetModuleConfig(self.name)
    -- police
    pcall(function() self.smf:SetFont(cfg.font or STANDARD_TEXT_FONT, cfg.fontSize or 12, "") end)
    -- couleurs par clé
    self.colorOf = {}
    for _, ch in ipairs(cfg.channels or {}) do
        self.colorOf[ch.key] = { ch.r or 1, ch.g or 1, ch.b or 1 }
    end
    -- (re)construction des boutons à partir des canaux activés
    for _, b in ipairs(self.btns) do b:Hide() end
    local x, i = 0, 0
    for _, ch in ipairs(cfg.channels or {}) do
        if ch.enabled and KEYDEF[ch.key] then
            i = i + 1
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
                if mouse == "RightButton" then self:SetView(s.key)
                else self:SetWrite(KEYDEF[s.key].write, s.key) end
            end)
            b:SetScript("OnEnter", function(s)
                GameTooltip:SetOwner(s, "ANCHOR_BOTTOM")
                GameTooltip:SetText(s.key); GameTooltip:AddLine("Clic D : afficher | Clic G : écrire", 0.7, 0.7, 0.7); GameTooltip:Show()
            end)
            b:SetScript("OnLeave", function() GameTooltip:Hide() end)
            b:Show()
            x = x + 22
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
    local cfg = SP:GetModuleConfig(self.name)
    for _, ch in ipairs(cfg.channels or {}) do
        if ch.enabled and ch.key ~= "A" then
            local def = KEYDEF[ch.key]
            if def then
                if def.types and def.types[typeKey] then return ch.key end
                if def.isTrade and typeKey == "CHANNEL" and IsTradeChannel(channelName) then return ch.key end
            end
        end
    end
    return "A"
end

function M:ColorName(author, guid)
    if not author or author == "" then return nil end
    local short = Ambiguate and Ambiguate(author, "none") or author
    local cfg = SP:GetModuleConfig(self.name)
    if cfg.classColorNames and guid then
        local ok, _, engClass = pcall(GetPlayerInfoByGUID, guid)
        local c = ok and engClass and RAID_CLASS_COLORS and RAID_CLASS_COLORS[engClass]
        if c then return ("|cff%02x%02x%02x%s|r"):format(c.r * 255, c.g * 255, c.b * 255, short) end
    end
    return "|cffffffff" .. short .. "|r"
end

function M:Push(key, entry)
    local b = self.buf[key]
    if not b then return end
    b[#b + 1] = entry
    if #b > CAP then table.remove(b, 1) end
end

function M:AddMessage(typeKey, msg, author, channelName, guid)
    if type(msg) ~= "string" then return end
    local pk = self:PrimaryKey(typeKey, channelName)
    local col = self.colorOf[pk] or self.colorOf.A or { 1, 1, 1 }
    local name = self:ColorName(author, guid)
    local line = (name and (name .. ": ") or "") .. LinkifyURLs(msg)
    local entry = { line, col[1], col[2], col[3] }

    self:Push("A", entry)
    if pk ~= "A" then self:Push(pk, entry) end
    if self.viewFilter == "A" or self.viewFilter == pk then
        self.smf:AddMessage(entry[1], entry[2], entry[3], entry[4])
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

function M:SetWrite(write, key)
    self.writeType = write
    local col = self.colorOf[key] or { 1, 1, 1 }
    if self.eb then self.eb:SetTextColor(col[1], col[2], col[3]); self.eb:SetFocus() end
end

-- ------------------------------------------------------------
-- Lien : copie (sélection Ctrl+C) + message dans le bandeau
-- ------------------------------------------------------------
function M:CopyLink(url)
    if self.copyBox then
        self.copyBox:SetText(url)
        self.copyBox:Show()
        self.copyBox:HighlightText()
        self.copyBox:SetFocus()
    end
    if self.viewLabel then
        self.viewLabel:SetText("|cFF40FF40Lien — Ctrl+C|r")
        C_Timer.After(4, function() if self.viewLabel then self:SetView(self.viewFilter) end end)
    end
end

-- ------------------------------------------------------------
-- Envoi
-- ------------------------------------------------------------
function M:FindTradeChannel()
    local list = { GetChannelList() }
    for i = 1, #list, 3 do
        local id, name = list[i], list[i + 1]
        if IsTradeChannel(name) then return id end
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
        local idx = self:FindTradeChannel()
        if idx then pcall(SendChatMessage, text, "CHANNEL", nil, idx)
        else SP:Print("Chat : canal Commerce introuvable (rejoins-le d'abord).") end
    else
        pcall(SendChatMessage, text, "SAY")
    end
end

SP:RegisterModule(M)
