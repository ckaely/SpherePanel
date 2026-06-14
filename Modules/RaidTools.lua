-- ============================================================
-- Module : RaidTools — assistant raid (marquage, balises, pull, ready check)
-- ============================================================
-- Rangée 1 : 8 marqueurs de CIBLE (clic = poser sur la cible, clic droit = retirer).
-- Rangée 2 : 8 balises MONDE (boutons sécurisés type="worldmarker", toggle) + effacer tout.
-- Rangée 3 : Pull <N>s (molette = ajuster, clic = compte à rebours, clic droit = annuler)
--            + Prêt ? (ready check) + Rôles (sondage).
-- Affiché par défaut uniquement en groupe (conditions du module).
local ADDON_NAME, SP = ...

local M = {
    name          = "RaidTools",
    label         = "Assistant Raid",
    defaultHeight = 96,
}

local BTN, GAP = 22, 3
local MARKER_TEX = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_%d"
local MARKER_NAMES = { "Étoile", "Rond", "Losange", "Triangle", "Lune", "Carré", "Croix", "Crâne" }
-- couleurs approximatives des balises monde (ordre Blizzard : 1..8)
local WORLD_COLORS = {
    { 0.2, 0.6, 1.0 }, { 0.4, 0.9, 0.4 }, { 0.7, 0.4, 0.9 }, { 0.9, 0.3, 0.3 },
    { 0.9, 0.9, 0.3 }, { 0.9, 0.6, 0.2 }, { 0.8, 0.8, 0.8 }, { 0.3, 0.9, 0.9 },
}

function M:Init(body)
    self.body = body
    local cfg = SP:GetModuleConfig(self.name)
    cfg.pullSec = cfg.pullSec or 10

    -- ===== rangée 1 : marqueurs de cible =====
    local l1 = body:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    l1:SetPoint("TOPLEFT", body, "TOPLEFT", 4, -4); l1:SetText("|cFFAAAAAACible|r")
    for i = 1, 8 do
        local b = CreateFrame("Button", nil, body)
        b:SetSize(BTN, BTN)
        b:SetPoint("TOPLEFT", body, "TOPLEFT", 44 + (i - 1) * (BTN + GAP), -2)
        b.icon = b:CreateTexture(nil, "ARTWORK"); b.icon:SetAllPoints(b)
        b.icon:SetTexture(MARKER_TEX:format(i))
        b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
        b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        b:SetScript("OnClick", function(_, btn)
            if btn == "RightButton" then pcall(SetRaidTarget, "target", 0)
            else pcall(SetRaidTarget, "target", i) end
        end)
        b:SetScript("OnEnter", function(s)
            GameTooltip:SetOwner(s, "ANCHOR_TOP")
            GameTooltip:SetText(MARKER_NAMES[i])
            GameTooltip:AddLine("Clic : marquer la cible | Clic droit : retirer", 0.7, 0.7, 0.7)
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end

    -- ===== rangée 2 : balises monde (sécurisé) =====
    local l2 = body:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    l2:SetPoint("TOPLEFT", body, "TOPLEFT", 4, -32); l2:SetText("|cFFAAAAAAMonde|r")
    for i = 1, 8 do
        local b = CreateFrame("Button", "SpherePanelWorldMarker" .. i, body, "SecureActionButtonTemplate")
        b:SetSize(BTN, BTN)
        b:SetPoint("TOPLEFT", body, "TOPLEFT", 44 + (i - 1) * (BTN + GAP), -30)
        b:RegisterForClicks("AnyUp")
        b:SetAttribute("type", "worldmarker")
        b:SetAttribute("marker", i)
        b:SetAttribute("action", "toggle")
        local c = WORLD_COLORS[i]
        b.bg = b:CreateTexture(nil, "BACKGROUND")
        b.bg:SetPoint("TOPLEFT", 2, -2); b.bg:SetPoint("BOTTOMRIGHT", -2, 2)
        b.bg:SetColorTexture(c[1], c[2], c[3], 0.9)
        local bd = b:CreateTexture(nil, "BORDER"); bd:SetAllPoints(b); bd:SetColorTexture(0.1, 0.1, 0.12, 1)
        b.bg:SetDrawLayer("ARTWORK")
        b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
        b:SetScript("OnEnter", function(s)
            GameTooltip:SetOwner(s, "ANCHOR_TOP")
            GameTooltip:SetText("Balise monde " .. i)
            GameTooltip:AddLine("Clic : poser/retirer au sol (curseur)", 0.7, 0.7, 0.7)
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end
    -- effacer toutes les balises (sécurisé via macro)
    local clr = CreateFrame("Button", "SpherePanelWorldMarkerClear", body, "SecureActionButtonTemplate")
    clr:SetSize(BTN, BTN)
    clr:SetPoint("TOPLEFT", body, "TOPLEFT", 44 + 8 * (BTN + GAP), -30)
    clr:RegisterForClicks("AnyUp")
    clr:SetAttribute("type", "macro")
    clr:SetAttribute("macrotext", "/clearworldmarker all")
    clr.fs = clr:CreateFontString(nil, "OVERLAY", "GameFontNormal"); clr.fs:SetPoint("CENTER"); clr.fs:SetText("|cFFFF6666X|r")
    clr:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    clr:SetScript("OnEnter", function(s)
        GameTooltip:SetOwner(s, "ANCHOR_TOP"); GameTooltip:SetText("Effacer toutes les balises"); GameTooltip:Show()
    end)
    clr:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- ===== rangée 3 : pull / prêt / rôles =====
    local pull = CreateFrame("Button", nil, body, "UIPanelButtonTemplate")
    pull:SetSize(86, 20)
    pull:SetPoint("TOPLEFT", body, "TOPLEFT", 4, -60)
    pull:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    pull:EnableMouseWheel(true)
    self.pull, self.pullCfg = pull, cfg
    self:UpdatePullLabel()
    pull:SetScript("OnMouseWheel", function(_, delta)
        if self._pullEnd then return end   -- pas d'ajustement pendant le décompte
        cfg.pullSec = math.max(3, math.min(60, (cfg.pullSec or 10) + delta))
        self:UpdatePullLabel()
    end)
    pull:SetScript("OnClick", function(_, btn)
        if not (C_PartyInfo and C_PartyInfo.DoCountdown) then return end
        if btn == "RightButton" then pcall(C_PartyInfo.DoCountdown, 0)   -- annule
        else pcall(C_PartyInfo.DoCountdown, cfg.pullSec or 10) end
    end)
    pull:SetScript("OnEnter", function(s)
        GameTooltip:SetOwner(s, "ANCHOR_TOP")
        GameTooltip:SetText("Compte à rebours de pull")
        GameTooltip:AddLine("Molette : ajuster | Clic : lancer | Clic droit : annuler", 0.7, 0.7, 0.7)
        local relay = (C_AddOns.IsAddOnLoaded("BigWigs") and "BigWigs")
            or (C_AddOns.IsAddOnLoaded("DBM-Core") and "DBM") or nil
        if relay then GameTooltip:AddLine("Relayé par " .. relay, 0.4, 0.8, 1) end
        GameTooltip:Show()
    end)
    pull:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local ready = CreateFrame("Button", nil, body, "UIPanelButtonTemplate")
    ready:SetSize(70, 20)
    ready:SetPoint("LEFT", pull, "RIGHT", 6, 0)
    ready:SetText("Prêt ?")
    ready:SetScript("OnClick", function() if DoReadyCheck then pcall(DoReadyCheck) end end)
    ready:SetScript("OnEnter", function(s)
        GameTooltip:SetOwner(s, "ANCHOR_TOP"); GameTooltip:SetText("Appel : tout le monde est prêt ?"); GameTooltip:Show()
    end)
    ready:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local roles = CreateFrame("Button", nil, body, "UIPanelButtonTemplate")
    roles:SetSize(70, 20)
    roles:SetPoint("LEFT", ready, "RIGHT", 6, 0)
    roles:SetText("Rôles")
    roles:SetScript("OnClick", function() if InitiateRolePoll then pcall(InitiateRolePoll) end end)
    roles:SetScript("OnEnter", function(s)
        GameTooltip:SetOwner(s, "ANCHOR_TOP"); GameTooltip:SetText("Sondage de rôles (tank/heal/dps)"); GameTooltip:Show()
    end)
    roles:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

-- ===== compte à rebours de pull (live, relayé par Blizzard/DBM/BigWigs via START_TIMER) =====
function M:UpdatePullLabel()
    if not self.pull then return end
    if self._pullEnd then
        local rem = math.max(0, self._pullEnd - GetTime())
        self.pull:SetText(("|cFFFF4040%d|r"):format(math.ceil(rem)))
        SP:SetModuleHeaderText(self, ("|cFFFF8800Pull %d|r"):format(math.ceil(rem)))
    else
        self.pull:SetText(("Pull %ds"):format((self.pullCfg and self.pullCfg.pullSec) or 10))
        SP:SetModuleHeaderText(self, "")
    end
end

function M:StartPull(remaining)
    if not remaining or remaining <= 0 then self:ClearPull(); return end
    self._pullEnd = GetTime() + remaining
    if not self._pullTicker then
        self._pullTicker = C_Timer.NewTicker(0.2, function()
            if not self._pullEnd or GetTime() >= self._pullEnd then self:ClearPull()
            else self:UpdatePullLabel() end
        end)
    end
    self:UpdatePullLabel()
end

function M:ClearPull()
    self._pullEnd = nil
    if self._pullTicker then self._pullTicker:Cancel(); self._pullTicker = nil end
    self:UpdatePullLabel()
end

function M:Enable()
    if self._placeholder then self._placeholder:Hide() end
    if not self.ev then
        self.ev = CreateFrame("Frame")
        self.ev:SetScript("OnEvent", function(_, e, a, b)
            if e == "START_TIMER" then
                if b and b > 0 then self:StartPull(b) end       -- a=type, b=secondes restantes
            elseif e == "PLAYER_REGEN_DISABLED" then
                self:ClearPull()                                -- combat engagé → fin du décompte
            end
        end)
    end
    pcall(self.ev.RegisterEvent, self.ev, "START_TIMER")
    pcall(self.ev.RegisterEvent, self.ev, "PLAYER_REGEN_DISABLED")
    self:UpdatePullLabel()
end

function M:Disable()
    if self.ev then self.ev:UnregisterAllEvents() end
    self:ClearPull()
end

function M:OnResize(w, h) end

SP:RegisterModule(M)
