local SP = _G.SpherePanel
if not SP then return end

local M = {}
SP.ChatFollow = M

local DEFAULT_CHANNELS = {
    WHISPER = true,
    BN_WHISPER = true,
    PARTY = true,
    RAID = true,
    INSTANCE_CHAT = true,
    GUILD = true,
    OFFICER = true,
    CHANNEL = false,
    SAY = false,
    YELL = false,
    EMOTE = false,
}

local TYPE_LABELS = {
    WHISPER = "Chuchotement",
    BN_WHISPER = "Battle.net",
    PARTY = "Groupe",
    RAID = "Raid",
    INSTANCE_CHAT = "Instance",
    GUILD = "Guilde",
    OFFICER = "Officier",
    CHANNEL = "Canal",
    SAY = "Dire",
    YELL = "Crier",
    EMOTE = "Emote",
}

local REPLY_WRITE_TYPE = {
    WHISPER = "WHISPER",
    BN_WHISPER = "WHISPER",
    PARTY = "GROUP",
    RAID = "RAID",
    INSTANCE_CHAT = "INSTANCE_CHAT",
    GUILD = "GUILD",
    OFFICER = "OFFICER",
    CHANNEL = "CUSTOM",
}

local function Clamp(v, minV, maxV)
    v = tonumber(v) or minV
    if v < minV then return minV end
    if v > maxV then return maxV end
    return v
end

local PILL_MASK = "Interface\\AddOns\\SpherePanel\\Media\\pill_mask"        -- pilule pleine
local RING_MASK = "Interface\\AddOns\\SpherePanel\\Media\\pill_ring_mask"   -- anneau (liseré seul)

local function AddPillMask(frame, tex, key, maskPath)
    if not (frame and tex and frame.CreateMaskTexture and tex.AddMaskTexture) then return end
    frame._pillMasks = frame._pillMasks or {}
    local mask = frame._pillMasks[key]
    if not mask then
        mask = frame:CreateMaskTexture(nil, "ARTWORK")
        mask:SetTexture(maskPath or PILL_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        frame._pillMasks[key] = mask
        tex:AddMaskTexture(mask)
    end
    mask:ClearAllPoints()
    mask:SetPoint("TOPLEFT", tex, "TOPLEFT", 0, 0)
    mask:SetPoint("BOTTOMRIGHT", tex, "BOTTOMRIGHT", 0, 0)
end

local function CleanName(name)
    if type(name) ~= "string" then return "" end
    name = name:gsub("|H.-|h%[(.-)%]|h", "%1")
    name = name:gsub("%-.+$", "")
    return name
end

local function StripColors(text)
    if type(text) ~= "string" then return "" end
    text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    text = text:gsub("|H.-|h(.-)|h", "%1")
    text = text:gsub("|T.-|t", "")
    return text
end

local function Shorten(text, maxLen)
    text = StripColors(text or "")
    maxLen = maxLen or 80
    if #text <= maxLen then return text end
    return text:sub(1, maxLen - 3) .. "..."
end

local function GetChatCfg()
    return SP.GetModuleConfig and SP:GetModuleConfig("Chat") or nil
end

function M:GetConfig()
    local cfg = GetChatCfg()
    if not cfg then return nil end
    cfg.follow = cfg.follow or {}
    local f = cfg.follow
    if f.enabled == nil then f.enabled = cfg.instantPopups ~= false end
    f.style = f.style or "pill"          -- pill (noir transparent) / white
    f.bgAlpha = f.bgAlpha or 0.35        -- transparence du fond (0 = transparent total)
    f.borderAlpha = f.borderAlpha or 0.95 -- intensité du liseré (anneau coloré)
    f.borderThickness = Clamp(f.borderThickness or 2, 1, 5)
    if f.innerShadow == nil then f.innerShadow = true end  -- ombre intérieure creusée
    if f.glow == nil then f.glow = true end
    f.glowAlpha = f.glowAlpha or 0.30
    if f.pulse == nil then f.pulse = true end   -- halo pulsant
    if f.accentBar == nil then f.accentBar = false end -- barre d'accent à gauche
    f.width = f.width or 360
    f.height = f.height or 48
    f.x = f.x or 0
    f.y = f.y or 150
    f.grow = f.grow or "up"
    f.gap = f.gap or 8
    f.maxVisible = f.maxVisible or 4
    f.duration = Clamp(f.duration or cfg.popupDuration or 7, 3, 120)
    f.whisperDuration = math.max(Clamp(f.whisperDuration or math.max(10, f.duration), 3, 120), f.duration)
    f.fadeIn = f.fadeIn or 0.16
    f.fadeOut = f.fadeOut or 0.30
    f.hoverDelay = f.hoverDelay or 0.65
    f.combatMode = f.combatMode or "all"
    if f.hideIfChatVisible == nil then f.hideIfChatVisible = true end
    if f.clickReply == nil then f.clickReply = true end
    -- Migration V1 : forcer hoverDismiss=false (ancien défaut était true → bug capsule ~1 s)
    if not f._cfgMig1 then f.hoverDismiss = false; f._cfgMig1 = true end
    -- Migration V2 : nouvelle pilule arrondie → réactiver glow/pulse/ombre sur les profils existants
    if not f._cfgMig2 then
        f.glow = true; f.pulse = true; f.innerShadow = true
        if not f.bgAlpha or f.bgAlpha < 0.05 then f.bgAlpha = 0.40 end
        f._cfgMig2 = true
    end
    if f.locked == nil then f.locked = true end
    f.channels = f.channels or {}
    f.sounds = f.sounds or {}
    for k, v in pairs(DEFAULT_CHANNELS) do
        if f.channels[k] == nil then f.channels[k] = v end
    end
    return f
end

function M:GetChannelKey(typeKey)
    if typeKey == "BN_WHISPER" then return "BN_WHISPER" end
    if typeKey == "INSTANCE_CHAT_LEADER" then return "INSTANCE_CHAT" end
    if typeKey == "PARTY_LEADER" then return "PARTY" end
    if typeKey == "RAID_LEADER" or typeKey == "RAID_WARNING" then return "RAID" end
    if typeKey == "CHANNEL_NOTICE" or typeKey == "CHANNEL_LIST" then return "CHANNEL" end
    return typeKey
end

function M:IsAllowed(typeKey, pk, channelName)
    local cfg = self:GetConfig()
    if not cfg or not cfg.enabled then return false end
    local chKey = self:GetChannelKey(typeKey)
    if pk and cfg.channels[pk] == true then return true end
    if channelName and cfg.channels[channelName] == true then return true end
    if cfg.channels[chKey] == false then return false end
    if cfg.channels[chKey] == true then return true end
    return false
end

function M:IsChatShowingMessage(chat, pk)
    local cfg = self:GetConfig()
    if not cfg or not cfg.hideIfChatVisible then return false end
    local chatCfg = GetChatCfg()
    if chatCfg and chatCfg.collapsed then return false end
    if chat and chat.tab == "social" then return false end
    if not (chat and chat.GetActiveChatTab and chat.TabHasChannel) then return false end
    local tab = chat:GetActiveChatTab()
    return chat:TabHasChannel(tab, "A") or chat:TabHasChannel(tab, pk)
end

function M:PassCombatMode()
    local cfg = self:GetConfig()
    if not cfg then return false end
    local inCombat = (UnitAffectingCombat and UnitAffectingCombat("player")) or (InCombatLockdown and InCombatLockdown())
    if cfg.combatMode == "hide" and inCombat then return false end
    if cfg.combatMode == "only" and not inCombat then return false end
    return true
end

function M:EnsureHost()
    if self.host then return self.host end
    local h = CreateFrame("Frame", "SpherePanelChatFollowHost", UIParent, "BackdropTemplate")
    h:SetFrameStrata("DIALOG")
    h:SetClampedToScreen(true)
    h:SetMovable(true)
    h:EnableMouse(false)
    h:SetScript("OnDragStart", function(frame)
        local cfg = M:GetConfig()
        if cfg and not cfg.locked then frame:StartMoving() end
    end)
    h:SetScript("OnDragStop", function(frame)
        frame:StopMovingOrSizing()
        local cfg = M:GetConfig()
        if not cfg then return end
        local cx, cy = frame:GetCenter()
        local ux, uy = UIParent:GetCenter()
        if cx and cy and ux and uy then
            cfg.x = math.floor(cx - ux + 0.5)
            cfg.y = math.floor(cy - uy + 0.5)
        end
        M:ApplyConfig()
    end)
    self.host = h
    self.pool = self.pool or {}
    self.active = self.active or {}
    self:ApplyConfig()
    return h
end

function M:ApplyConfig()
    local cfg = self:GetConfig()
    if not cfg then return end
    local h = self:EnsureHost()
    h:ClearAllPoints()
    h:SetPoint("CENTER", UIParent, "CENTER", cfg.x or 0, cfg.y or 150)
    h:SetSize(Clamp(cfg.width, 220, 700), Clamp((cfg.height + cfg.gap) * cfg.maxVisible, 60, 600))
    h:EnableMouse(not cfg.locked)
    h:RegisterForDrag("LeftButton")
    if self.editMode then h:Show() end
    self:UpdateEditFrame()
    for _, f in ipairs(self.active or {}) do self:StyleCapsule(f) end
    self:Layout()
end

function M:SetEditMode(enabled)
    local cfg = self:GetConfig()
    if not cfg then return end
    self.editMode = enabled and true or false
    cfg.locked = not self.editMode
    self:ApplyConfig()
    if self.editMode then
        self:EnsureHost():Show()
        self:UpdateEditFrame()
    else
        self.preview = nil
        self:UpdateEditFrame()
    end
end

function M:CreateEditFrame()
    if self.editFrame then return self.editFrame end
    local f = CreateFrame("Frame", nil, self:EnsureHost(), "BackdropTemplate")
    f:SetFrameLevel((self.host:GetFrameLevel() or 0) + 20)
    f.bg = f:CreateTexture(nil, "BACKGROUND")
    f.bg:SetAllPoints(f)
    f.bg:SetColorTexture(0.05, 0.09, 0.14, 0.34)
    f.top = f:CreateTexture(nil, "ARTWORK")
    f.bottom = f:CreateTexture(nil, "ARTWORK")
    f.left = f:CreateTexture(nil, "ARTWORK")
    f.right = f:CreateTexture(nil, "ARTWORK")
    f.top:SetHeight(2); f.bottom:SetHeight(2); f.left:SetWidth(2); f.right:SetWidth(2)
    f.top:SetPoint("TOPLEFT"); f.top:SetPoint("TOPRIGHT")
    f.bottom:SetPoint("BOTTOMLEFT"); f.bottom:SetPoint("BOTTOMRIGHT")
    f.left:SetPoint("TOPLEFT"); f.left:SetPoint("BOTTOMLEFT")
    f.right:SetPoint("TOPRIGHT"); f.right:SetPoint("BOTTOMRIGHT")
    f.label = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.label:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -8)
    f.hint = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    f.hint:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 10, 8)
    f.hint:SetJustifyH("LEFT")
    f:EnableMouse(false)
    self.editFrame = f
    return f
end

function M:UpdateEditFrame()
    local cfg = self:GetConfig()
    if not cfg then return end
    if not self.editMode then
        if self.editFrame then self.editFrame:Hide() end
        if self.host and #(self.active or {}) == 0 then self.host:Hide() end
        return
    end
    local f = self:CreateEditFrame()
    f:ClearAllPoints()
    f:SetAllPoints(self.host)
    f.top:SetColorTexture(0.35, 0.78, 1, 0.85)
    f.bottom:SetColorTexture(0.35, 0.78, 1, 0.85)
    f.left:SetColorTexture(0.35, 0.78, 1, 0.85)
    f.right:SetColorTexture(0.35, 0.78, 1, 0.85)
    f.label:SetText("Zone suivi_chat")
    f.hint:SetText(("deplacer la zone - %s - %d capsules"):format((cfg.grow == "down") and "pile bas" or "pile haut", cfg.maxVisible or 4))
    f:Show()
end

function M:ResetPosition()
    local cfg = self:GetConfig()
    if not cfg then return end
    cfg.x, cfg.y = 0, 150
    self:ApplyConfig()
end

function M:StyleCapsule(f)
    local cfg = self:GetConfig()
    if not cfg then return end
    local w, h = Clamp(cfg.width, 220, 700), Clamp(cfg.height, 34, 120)
    f:SetSize(w, h)
    local r, g, b = f._colorR or 0.65, f._colorG or 0.8, f._colorB or 1
    local style = cfg.style or "pill"
    -- Pilule arrondie (3-slice) : fond transparent + liseré coloré + glow + ombre + point
    SP:LayoutPill(f)
    SP:StylePill(f, r, g, b, {
        bgAlpha     = tonumber(cfg.bgAlpha) or 0.4,
        borderAlpha = tonumber(cfg.borderAlpha) or 0.95,
        light       = (style == "white"),
        glow        = cfg.glow and true or false,
        glowAlpha   = tonumber(cfg.glowAlpha) or 0.30,
        innerShadow = cfg.innerShadow ~= false,
        dot         = true,
    })
    if style == "white" then
        f.title:SetTextColor(0.10, 0.12, 0.18); f.msg:SetTextColor(0.16, 0.18, 0.26)
    else
        f.title:SetTextColor(1, 1, 1); f.msg:SetTextColor(0.92, 0.94, 0.99)
    end
    -- Barre d'accent gauche (optionnelle, en plus du point)
    if f.edge then
        f.edge:SetColorTexture(r, g, b, cfg.accentBar and 0.85 or 0)
        f.edge:SetHeight(math.max(12, h - 16))
    end
    f.channel:SetTextColor(r, g, b)
    f.time:SetShown(cfg.showTime == true)
    -- Halo + point pulsants
    local p = f.pill
    if cfg.pulse and p then
        f:SetScript("OnUpdate", function(s, e)
            s._pt = (s._pt or 0) + e
            local k = 0.5 + 0.5 * math.sin(s._pt * 3)
            if (s.pill._glowBase or 0) > 0 then
                s.pill.glowL:SetAlpha(0.35 + 0.65 * k)
                s.pill.glowR:SetAlpha(0.35 + 0.65 * k)
                s.pill.glowM:SetAlpha(0.35 + 0.65 * k)
            end
            s.pill.dot:SetAlpha(0.45 + 0.55 * k)
        end)
    else
        f:SetScript("OnUpdate", nil)
        if p then
            p.glowL:SetAlpha(1); p.glowR:SetAlpha(1); p.glowM:SetAlpha(1); p.dot:SetAlpha(1)
        end
    end
end

function M:CreateCapsule()
    local f = CreateFrame("Button", nil, self:EnsureHost())
    f:SetFrameStrata("DIALOG")
    f:SetAlpha(0)
    f:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    -- Pilule arrondie (embouts demi-cercle + milieu étirable), cf. SP:BuildPill
    SP:BuildPill(f)
    -- Barre d'accent gauche (optionnelle, en plus du point indicateur)
    f.edge = f:CreateTexture(nil, "ARTWORK", nil, 2)
    f.edge:SetPoint("LEFT", f, "LEFT", 10, 0)
    f.edge:SetSize(3, 30)
    -- FontStrings (décalés à droite du point indicateur)
    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.title:SetPoint("TOPLEFT", f, "TOPLEFT", 26, -8)
    f.title:SetPoint("RIGHT",   f, "RIGHT", -92, 0)
    f.title:SetJustifyH("LEFT")
    f.title:SetWordWrap(false)
    f.channel = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.channel:SetPoint("TOPRIGHT", f, "TOPRIGHT", -10, -9)
    f.channel:SetJustifyH("RIGHT")
    f.time = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    f.time:SetPoint("RIGHT", f.channel, "LEFT", -6, 0)
    f.msg = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.msg:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 0, -4)
    f.msg:SetPoint("RIGHT",   f, "RIGHT", -10, 0)
    f.msg:SetJustifyH("LEFT")
    f.msg:SetWordWrap(false)
    -- Interactions
    f:SetScript("OnEnter", function(frame)
        local cfg = M:GetConfig()
        if not cfg or not cfg.hoverDismiss then return end
        if frame._noHover then return end
        if frame._ignoreInitialHover then return end
        local now = GetTime and GetTime() or nil
        if now and frame._shownAt and (now - frame._shownAt) < math.max(1.25, (cfg.hoverDelay or 0.65) + 0.35) then return end
        frame._hoverToken = (frame._hoverToken or 0) + 1
        local token = frame._hoverToken
        C_Timer.After(cfg.hoverDelay or 0.65, function()
            if frame:IsShown() and frame:IsMouseOver() and frame._hoverToken == token then
                M:Fade(frame, cfg.fadeOut or 0.3)
            end
        end)
    end)
    f:SetScript("OnLeave", function(frame)
        frame._hoverToken = (frame._hoverToken or 0) + 1
        frame._ignoreInitialHover = false
    end)
    f:SetScript("OnClick", function(frame, button)
        if button == "RightButton" then
            M:Fade(frame, 0.14)
        elseif button == "LeftButton" then
            M:Reply(frame._info)
            M:Fade(frame, 0.18)
        end
    end)
    return f
end

function M:Acquire()
    local f = table.remove(self.pool or {})
    if not f then f = self:CreateCapsule() end
    f._token = (f._token or 0) + 1
    f._expireToken = (f._expireToken or 0) + 1
    f._hoverToken = (f._hoverToken or 0) + 1
    f._ignoreInitialHover = true
    f._fading = false
    local host = self:EnsureHost()
    host:Show()
    f:SetParent(host)
    f:Show()
    return f
end

function M:Release(f)
    if not f then return end
    f:Hide()
    f._info = nil
    f._fading = false
    for i = #(self.active or {}), 1, -1 do
        if self.active[i] == f then table.remove(self.active, i) end
    end
    self.pool = self.pool or {}
    self.pool[#self.pool + 1] = f
    self:Layout()
    if #(self.active or {}) == 0 and not self.editMode and self.host then self.host:Hide() end
end

function M:Layout()
    local cfg = self:GetConfig()
    if not cfg then return end
    local gap = cfg.gap or 8
    local growDown = cfg.grow == "down"
    local last
    for i, f in ipairs(self.active or {}) do
        f:ClearAllPoints()
        if not last then
            if growDown then f:SetPoint("TOP", self.host, "TOP", 0, 0)
            else f:SetPoint("BOTTOM", self.host, "BOTTOM", 0, 0) end
        elseif growDown then
            f:SetPoint("TOP", last, "BOTTOM", 0, -gap)
        else
            f:SetPoint("BOTTOM", last, "TOP", 0, gap)
        end
        last = f
    end
end

function M:Fade(f, duration)
    if not f or f._fading then return end
    f._fading = true
    -- Stopper le fondu entrant s'il est encore en cours
    if f._fadeInAG then pcall(f._fadeInAG.Stop, f._fadeInAG) end
    local token = (f._token or 0) + 1
    f._token = token
    f._expireToken = (f._expireToken or 0) + 1
    f._hoverToken = (f._hoverToken or 0) + 1
    local ag = f:CreateAnimationGroup()
    local a = ag:CreateAnimation("Alpha")
    a:SetFromAlpha(f:GetAlpha())
    a:SetToAlpha(0)
    a:SetDuration(duration or 0.25)
    a:SetSmoothing("OUT")
    ag:SetScript("OnFinished", function()
        if f._token == token then M:Release(f) end
    end)
    ag:Play()
end

function M:Show(info)
    local cfg = self:GetConfig()
    if not cfg or not cfg.enabled then return end
    local f = self:Acquire()
    f._shownAt = GetTime and GetTime() or nil
    f._info = info
    f._noHover = info.noHover and true or false
    f._colorR, f._colorG, f._colorB = info.r or 1, info.g or 1, info.b or 1
    f.title:SetText(info.author or "")
    f.channel:SetText(info.channelLabel or "")
    f.time:SetText(info.timeText or "")
    f.msg:SetText(info.message or "")
    self:StyleCapsule(f)
    table.insert(self.active, 1, f)
    while #self.active > (cfg.maxVisible or 4) do
        self:Fade(self.active[#self.active], 0.1)
        break
    end
    self:Layout()
    f._ignoreInitialHover = f:IsMouseOver()
    -- Fondu entrant : nouveau groupe à chaque Show pour éviter les conflits inter-animations
    if f._fadeInAG then pcall(f._fadeInAG.Stop, f._fadeInAG); f._fadeInAG = nil end
    f:SetAlpha(0)
    local fadeIn = tonumber(cfg.fadeIn) or 0.16
    if fadeIn > 0.01 then
        local ag = f:CreateAnimationGroup()
        if ag.SetToFinalAlpha then ag:SetToFinalAlpha(true) end
        local a = ag:CreateAnimation("Alpha")
        a:SetFromAlpha(0); a:SetToAlpha(1); a:SetDuration(fadeIn); a:SetSmoothing("OUT")
        ag:SetScript("OnFinished", function() if f:IsShown() then f:SetAlpha(1) end end)
        f._fadeInAG = ag
        ag:Play()
    else
        f:SetAlpha(1)
    end
    local sounds = cfg.sounds or {}
    if (cfg.sound or sounds[info.typeKey] or sounds[info.pk] or sounds[info.channelName]) and PlaySound and SOUNDKIT then pcall(PlaySound, SOUNDKIT.UI_BNET_TOAST) end
    local keep = info.keep or ((info.typeKey == "WHISPER" or info.typeKey == "BN_WHISPER") and (cfg.whisperDuration or 12) or (cfg.duration or 7))
    f._expireToken = (f._expireToken or 0) + 1
    local token = f._expireToken
    C_Timer.After(keep, function()
        if f._expireToken == token and f:IsShown() then M:Fade(f, cfg.fadeOut or 0.3) end
    end)
end

function M:Reply(info)
    if not info or not info.chat or not info.chat.OpenInput then return end
    local chat = info.chat
    local cfg = self:GetConfig()
    if not cfg or not cfg.clickReply then return end
    local w = REPLY_WRITE_TYPE[info.typeKey] or REPLY_WRITE_TYPE[self:GetChannelKey(info.typeKey)]
    if not w then return end
    if w == "WHISPER" then
        chat._lastWhisper = info.authorRaw or info.author
        chat.writeType = "WHISPER"
    elseif w == "CUSTOM" then
        chat.writeType = "CUSTOM"
        chat.writeChannel = info.channelName
    else
        chat.writeType = w
    end
    chat:OpenInput("")
end

function M:OnChatMessage(chat, typeKey, msg, author, pk, channelName, rawEvent, id)
    if rawEvent and rawEvent:find("_INFORM", 1, true) then return end
    local who = CleanName(author)
    if who == "" then return end
    -- on ignore SES PROPRES messages (say/yell/groupe…) SAUF les chuchotements à soi-même
    -- (utile pour tester) : un auto-chuchotement reçu doit bien popper.
    local isWhisper = (typeKey == "WHISPER" or typeKey == "BN_WHISPER")
    if not isWhisper and UnitName and who == UnitName("player") then return end
    if not self:IsAllowed(typeKey, pk, channelName) then return end
    if not self:PassCombatMode() then return end
    if self:IsChatShowingMessage(chat, pk) then return end

    local cfg = self:GetConfig()
    local antiKey = (typeKey or "") .. "\031" .. who .. "\031" .. StripColors(msg or "")
    local now = GetTime and GetTime() or time()
    self.recent = self.recent or {}
    if self.recent[antiKey] and now - self.recent[antiKey] < 1.5 then return end
    self.recent[antiKey] = now

    local r, g, b = 0.65, 0.8, 1
    if chat and chat.DirectColor then
        local col = chat:DirectColor(typeKey, channelName, pk)
        r, g, b = col[1] or r, col[2] or g, col[3] or b
    end
    local label = channelName or TYPE_LABELS[self:GetChannelKey(typeKey)] or pk or typeKey or "Chat"
    local info = {
        chat = chat,
        typeKey = self:GetChannelKey(typeKey),
        rawTypeKey = typeKey,
        pk = pk,
        channelName = channelName,
        author = Shorten(who, 26),
        authorRaw = author,
        channelLabel = Shorten(label, 18),
        message = Shorten(msg, math.floor((cfg.width or 360) / 5.8)),
        timeText = date("%H:%M"),
        id = id,
        r = r,
        g = g,
        b = b,
    }
    self:Show(info)
end

function M:Test(keep)
    local cfg = self:GetConfig()
    if not cfg then return end
    local info = {
        chat = SP.modulesByName and SP.modulesByName.Chat,
        typeKey = "TEST",
        author = "SpherePanel",
        authorRaw = "SpherePanel",
        channelLabel = "Test",
        message = "Aperçu suivi chat : capsule interactive, empilée, cliquable.",
        timeText = date("%H:%M"),
        keep = math.max(cfg.duration or 7, 8),   -- durée garantie pour le test
        noHover = true,                          -- pas de fondu au survol (sinon disparaît trop vite)
        r = 1,
        g = 0.48,
        b = 0.95,
    }
    self:Show(info)
end

-- ===== Aperçu live pour le panneau de config =====
-- Une capsule persistante, non interactive, restylée à chaque changement d'option.
function M:RefreshConfigPreview()
    local f = self.cfgPreview
    if not f then return end
    local cfg = self:GetConfig(); if not cfg then return end
    local r, g, b = 1, 0.48, 0.95
    local chat = SP.modulesByName and SP.modulesByName.Chat
    if chat and chat.DirectColor then
        local c = chat:DirectColor("WHISPER")
        if c then r, g, b = c[1] or r, c[2] or g, c[3] or b end
    end
    f._colorR, f._colorG, f._colorB = r, g, b
    f.title:SetText("Kyalin")
    f.channel:SetText("Chuchotement")
    f.time:SetText(date("%H:%M"))
    f.msg:SetText("Aperçu de la capsule de suivi.")
    self:StyleCapsule(f)
    f:SetWidth(math.min(f:GetWidth() or 360, 380))   -- borné pour tenir dans le panneau de config
    f:SetAlpha(1); f:Show()
end

function M:GetConfigPreview(parent)
    if not self.cfgPreview then self.cfgPreview = self:CreateCapsule() end
    local f = self.cfgPreview
    f:SetParent(parent)
    f:EnableMouse(false)
    f:SetScript("OnEnter", nil); f:SetScript("OnLeave", nil); f:SetScript("OnClick", nil)
    f._noHover = true
    f:ClearAllPoints()
    f:SetPoint("CENTER", parent, "CENTER", 0, 0)
    self:RefreshConfigPreview()
    return f
end

function M:HideAll()
    for i = #(self.active or {}), 1, -1 do
        self:Release(self.active[i])
    end
    if self.editFrame then self.editFrame:Hide() end
    self.editMode = false
    if self.host then self.host:Hide() end
end
