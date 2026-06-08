-- ============================================================
-- Module : SilverDragon — intégration alertes de rares (dépendance optionnelle)
-- ============================================================
-- Étape 11. Détecte SilverDragon ; si présent, écoute ses détections ; sinon, message.
local ADDON_NAME, SP = ...

local M = {
    name          = "SilverDragon",
    label         = "Rares",
    defaultHeight = 80,
}

function M:Init(body)
    self.body = body
    self.info = body:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    self.info:SetPoint("TOPLEFT", body, "TOPLEFT", 6, -6)
    self.info:SetPoint("TOPRIGHT", body, "TOPRIGHT", -6, -6)
    self.info:SetJustifyH("LEFT")
    self.info:SetWordWrap(true)

    self.pingBtn = CreateFrame("Button", nil, body, "UIPanelButtonTemplate")
    self.pingBtn:SetSize(110, 20)
    self.pingBtn:SetPoint("BOTTOMLEFT", body, "BOTTOMLEFT", 6, 6)
    self.pingBtn:SetText("Ping carte")
    self.pingBtn:Hide()
    self.pingBtn:SetScript("OnClick", function() self:PingLast() end)
end

local function HasSilverDragon()
    return C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("SilverDragon")
end

function M:Enable()
    self._enabled = true
    if self._placeholder then self._placeholder:Hide() end

    if not HasSilverDragon() then
        self.info:SetText("|cFF888888SilverDragon non installé — module en veille.|r")
        self.pingBtn:Hide()
        return
    end

    self.info:SetText("SilverDragon détecté. En attente d'un rare…")
    -- SilverDragon est Ace3 : on tente de s'abonner à son callback "Seen".
    local sd = _G.SilverDragon
    if sd and sd.RegisterCallback and not self._hooked then
        local ok = pcall(function()
            sd.RegisterCallback(self, "Seen", function(_, _, id, zone, x, y, dead, source, unit)
                self:OnSeen(id, zone, x, y, dead)
            end)
        end)
        self._hooked = ok
    end
end

function M:Disable()
    self._enabled = false
    local sd = _G.SilverDragon
    if sd and sd.UnregisterCallback and self._hooked then
        pcall(function() sd.UnregisterCallback(self, "Seen") end)
        self._hooked = false
    end
end

function M:OnSeen(id, zone, x, y, dead)
    if not self._enabled then return end
    local name = id
    if type(id) == "number" and C_NPCInfo == nil then
        -- SilverDragon fournit souvent un nom via son API mob ; fallback sur l'id
        name = ("PNJ %d"):format(id)
    end
    self.last = { id = id, zone = zone, x = x, y = y }
    local status = dead and "|cFFFF5555(mort)|r" or "|cFF55FF55(vivant)|r"
    self.info:SetText(("|cFFFFD200%s|r %s\n%s"):format(tostring(name), status, tostring(zone or "")))
    self.pingBtn:Show()
    PlaySound and PlaySound(SOUNDKIT and SOUNDKIT.RAID_WARNING or 8959)
end

function M:PingLast()
    local l = self.last
    if not l or not l.x or not l.y then return end
    if C_Map and C_Map.GetBestMapForUnit and C_Map.SetUserWaypoint then
        local mapID = C_Map.GetBestMapForUnit("player")
        if mapID then
            pcall(function()
                local p = UiMapPoint and UiMapPoint.CreateFromCoordinates(mapID, l.x, l.y)
                if p then C_Map.SetUserWaypoint(p) end
            end)
        end
    end
end

function M:OnResize(w, h) end

SP:RegisterModule(M)
