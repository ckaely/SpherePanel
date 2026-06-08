-- ============================================================
-- Module : Chat — panneaux de conversation filtrés (additionnel, ne remplace pas l'existant)
-- ============================================================
-- Phase 4. Boutons A / W / I / M :
--   • clic DROIT  = affiche le panneau filtré de ce canal
--   • clic GAUCHE = arme l'écriture dans le canal correspondant
-- Buffers locaux par catégorie. Aucun historique antérieur au chargement (limite API).
local ADDON_NAME, SP = ...

local M = {
    name          = "Chat",
    label         = "Chat",
    defaultHeight = 200,
}

local CAP = 200  -- lignes mémorisées par buffer

local CHAT_EVENTS = {
    "CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_EMOTE",
    "CHAT_MSG_GUILD", "CHAT_MSG_OFFICER",
    "CHAT_MSG_WHISPER", "CHAT_MSG_WHISPER_INFORM", "CHAT_MSG_BN_WHISPER", "CHAT_MSG_BN_WHISPER_INFORM",
    "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER",
    "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER", "CHAT_MSG_RAID_WARNING",
    "CHAT_MSG_INSTANCE_CHAT", "CHAT_MSG_INSTANCE_CHAT_LEADER",
    "CHAT_MSG_CHANNEL",
}

-- Boutons : view = buffer affiché ; write = canal d'écriture ; info = clé ChatTypeInfo (couleur).
local BUTTONS = {
    { label = "A", view = "A", write = "SAY",     info = "SAY",           tip = "Tout (clic D)" },
    { label = "W", view = "W", write = "WHISPER", info = "WHISPER",       tip = "Chuchotements" },
    { label = "I", view = "I", write = "GROUP",   info = "INSTANCE_CHAT", tip = "Instance / groupe" },
    { label = "M", view = "M", write = "TRADE",   info = "CHANNEL",       tip = "Commerce (Market)" },
}

local function NormType(suffix)
    suffix = suffix:gsub("_LEADER$", "")
    if suffix == "WHISPER_INFORM" or suffix == "BN_WHISPER" or suffix == "BN_WHISPER_INFORM" then
        return "WHISPER"
    end
    return suffix
end

-- Catégorie de buffer dédiée (hors "A" qui reçoit tout). nil = uniquement dans A.
local function CategoryOf(typeKey, channelName)
    if typeKey == "WHISPER" then return "W" end
    if typeKey == "INSTANCE_CHAT" or typeKey == "PARTY" or typeKey == "RAID" or typeKey == "RAID_WARNING" then
        return "I"
    end
    if typeKey == "CHANNEL" and type(channelName) == "string" then
        local l = channelName:lower()
        if l:find("commerce") or l:find("trade") or l:find("market") then return "M" end
    end
    return nil
end

local function ChanColor(infoKey)
    local ci = ChatTypeInfo and ChatTypeInfo[infoKey]
    if ci then return ci.r, ci.g, ci.b end
    return 1, 1, 1
end

function M:Init(body)
    self.body = body
    self.viewFilter = "A"
    self.writeType  = "SAY"
    self.buf = { A = {}, W = {}, I = {}, M = {} }

    -- Barre de boutons (canaux)
    self.bar = CreateFrame("Frame", nil, body)
    self.bar:SetPoint("TOPLEFT", body, "TOPLEFT", 4, -2)
    self.bar:SetPoint("TOPRIGHT", body, "TOPRIGHT", -4, -2)
    self.bar:SetHeight(16)
    self.viewBtns = {}
    local x = 0
    for _, c in ipairs(BUTTONS) do
        local b = CreateFrame("Button", nil, self.bar)
        b:SetSize(20, 16)
        b:SetPoint("LEFT", self.bar, "LEFT", x, 0)
        local hl = b:CreateTexture(nil, "BACKGROUND")
        hl:SetAllPoints(b); hl:SetColorTexture(1, 1, 1, 0.18); hl:Hide()
        b.sel = hl
        b.fs = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        b.fs:SetAllPoints(b)
        b.fs:SetText(c.label)
        b.fs:SetTextColor(ChanColor(c.info))
        b.view, b.write, b.info, b.tip = c.view, c.write, c.info, c.tip
        b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        b:SetScript("OnClick", function(s, mouse)
            if mouse == "RightButton" then self:SetView(s.view) else self:SetWrite(s.write, s.info) end
        end)
        b:SetScript("OnEnter", function(s)
            GameTooltip:SetOwner(s, "ANCHOR_BOTTOM")
            GameTooltip:SetText(s.tip)
            GameTooltip:AddLine("Clic droit : afficher | Clic gauche : écrire", 0.7, 0.7, 0.7)
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        self.viewBtns[c.view] = b
        x = x + 22
    end
    self.viewLabel = self.bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    self.viewLabel:SetPoint("RIGHT", self.bar, "RIGHT", 0, 0)

    -- Zone de messages
    self.smf = CreateFrame("ScrollingMessageFrame", nil, body)
    self.smf:SetPoint("TOPLEFT", self.bar, "BOTTOMLEFT", 0, -2)
    self.smf:SetPoint("BOTTOMRIGHT", body, "BOTTOMRIGHT", -4, 22)
    self.smf:SetFontObject(ChatFontNormal or GameFontHighlightSmall)
    self.smf:SetJustifyH("LEFT")
    self.smf:SetFading(false)
    self.smf:SetMaxLines(CAP)
    self.smf:SetHyperlinksEnabled(true)
    self.smf:EnableMouseWheel(true)
    self.smf:SetScript("OnMouseWheel", function(s, d) if d > 0 then s:ScrollUp() else s:ScrollDown() end end)
    self.smf:SetScript("OnHyperlinkClick", function(_, link, text, btn) SetItemRef(link, text, btn) end)

    -- Éditbox
    self.eb = CreateFrame("EditBox", nil, body)
    self.eb:SetPoint("BOTTOMLEFT", body, "BOTTOMLEFT", 4, 2)
    self.eb:SetPoint("BOTTOMRIGHT", body, "BOTTOMRIGHT", -4, 2)
    self.eb:SetHeight(18)
    self.eb:SetAutoFocus(false)
    self.eb:SetFontObject(ChatFontNormal or GameFontHighlightSmall)
    self.eb:SetScript("OnEnterPressed", function(s) self:Send(s:GetText()); s:SetText(""); s:ClearFocus() end)
    self.eb:SetScript("OnEscapePressed", function(s) s:SetText(""); s:ClearFocus() end)

    self.ev = CreateFrame("Frame")
    self.ev:SetScript("OnEvent", function(_, event, msg, author, _lang, channelName)
        local suffix = event:gsub("^CHAT_MSG_", "")
        local typeKey = NormType(suffix)
        if suffix == "WHISPER" and author and author ~= "" then self._lastWhisper = author end
        self:AddMessage(typeKey, msg, author, channelName)
    end)

    self:SetView("A")
    self:SetWrite("SAY", "SAY")
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

function M:OnResize(w, h) end

-- ------------------------------------------------------------
-- Messages
-- ------------------------------------------------------------
function M:Push(cat, entry)
    local b = self.buf[cat]
    if not b then return end
    b[#b + 1] = entry
    if #b > CAP then table.remove(b, 1) end
end

function M:AddMessage(typeKey, msg, author, channelName)
    if type(msg) ~= "string" then return end
    local r, g, b = ChanColor(typeKey)
    local prefix = ""
    if author and author ~= "" then
        local short = Ambiguate and Ambiguate(author, "none") or author
        prefix = "|cffffffff" .. short .. "|r: "
    end
    local entry = { prefix .. msg, r, g, b }
    self:Push("A", entry)
    local cat = CategoryOf(typeKey, channelName)
    if cat then self:Push(cat, entry) end
    if self.viewFilter == "A" or self.viewFilter == cat then
        self.smf:AddMessage(entry[1], r, g, b)
    end
end

function M:SetView(key)
    self.viewFilter = key
    self.smf:Clear()
    for _, e in ipairs(self.buf[key] or {}) do self.smf:AddMessage(e[1], e[2], e[3], e[4]) end
    for v, btn in pairs(self.viewBtns) do btn.sel:SetShown(v == key) end
    if self.viewLabel then self.viewLabel:SetText("|cFFAAAAAAvue:|r " .. key) end
end

function M:SetWrite(write, infoKey)
    self.writeType = write
    if self.eb then
        self.eb:SetTextColor(ChanColor(infoKey))
        self.eb:SetFocus()
    end
end

-- ------------------------------------------------------------
-- Envoi
-- ------------------------------------------------------------
function M:FindTradeChannel()
    local list = { GetChannelList() }
    for i = 1, #list, 3 do
        local id, name = list[i], list[i + 1]
        if type(name) == "string" then
            local l = name:lower()
            if l:find("commerce") or l:find("trade") then return id end
        end
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
    elseif w == "TRADE" then
        local idx = self:FindTradeChannel()
        if idx then pcall(SendChatMessage, text, "CHANNEL", nil, idx)
        else SP:Print("Chat : canal Commerce introuvable (rejoins-le d'abord).") end
    else
        pcall(SendChatMessage, text, "SAY")
    end
end

SP:RegisterModule(M)
