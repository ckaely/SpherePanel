-- ============================================================
-- Module : RecentLoot ("Butin") — derniers objets lootés (toi + groupe)
-- ============================================================
-- Survol = tooltip de l'objet ; clic = lien dans le champ de chat.
local ADDON_NAME, SP = ...

local M = { name = "RecentLoot", label = "Butin", defaultHeight = 120 }

local ROW, CAP = 17, 15

local function CreateRow(self, i)
    local r = CreateFrame("Button", nil, self.list)
    r:SetHeight(ROW)
    r.icon = r:CreateTexture(nil, "ARTWORK"); r.icon:SetSize(14, 14); r.icon:SetPoint("LEFT", r, "LEFT", 2, 0)
    r.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    r.fs = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    r.fs:SetPoint("LEFT", r.icon, "RIGHT", 4, 0); r.fs:SetPoint("RIGHT", r, "RIGHT", -2, 0)
    r.fs:SetJustifyH("LEFT"); r.fs:SetWordWrap(false)
    local hl = r:CreateTexture(nil, "HIGHLIGHT"); hl:SetAllPoints(r); hl:SetColorTexture(1, 1, 1, 0.08)
    r:SetScript("OnEnter", function(s)
        if s.link then SP:AnchorTooltipOutsidePanel(GameTooltip, s); pcall(GameTooltip.SetHyperlink, GameTooltip, s.link); GameTooltip:Show() end
    end)
    r:SetScript("OnLeave", function() GameTooltip:Hide() end)
    r:SetScript("OnClick", function(s)
        if s.link and ChatEdit_InsertLink then pcall(ChatEdit_InsertLink, s.link) end
    end)
    self.rows[i] = r
    return r
end

function M:Init(body)
    self.body = body
    self.rows = {}
    self.items = {}   -- { link, who, t }
    self.list = CreateFrame("Frame", nil, body)
    self.list:SetPoint("TOPLEFT", body, "TOPLEFT", 2, -2)
    self.list:SetPoint("BOTTOMRIGHT", body, "BOTTOMRIGHT", -2, 2)
    self.list:SetClipsChildren(true)

    self.empty = self.list:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    self.empty:SetPoint("TOP", self.list, "TOP", 0, -6)
    self.empty:SetText("Aucun butin récent")

    self.ev = CreateFrame("Frame")
    self.ev:SetScript("OnEvent", function(_, _, msg, author)
        self:OnLoot(msg, author)
    end)
end

function M:Enable()
    self._enabled = true
    if self._placeholder then self._placeholder:Hide() end
    pcall(self.ev.RegisterEvent, self.ev, "CHAT_MSG_LOOT")
    self:Refresh()
end

function M:Disable()
    self._enabled = false
    if self.ev then self.ev:UnregisterAllEvents() end
    for _, r in ipairs(self.rows) do r:Hide() end
end

function M:OnResize(w, h) self:Refresh() end

function M:OnLoot(msg, author)
    if type(msg) ~= "string" then return end
    local link = msg:match("(|c%x+|Hitem:.-|h%[.-%]|h|r)")
    if not link then return end
    local who = (author and author ~= "" and Ambiguate(author, "none")) or UnitName("player")
    table.insert(self.items, 1, { link = link, who = who, t = date("%H:%M") })
    while #self.items > CAP do table.remove(self.items) end
    self:Refresh()
end

function M:Refresh()
    if not self._enabled then return end
    local y = 0
    for i, it in ipairs(self.items) do
        local r = self.rows[i] or CreateRow(self, i)
        r.link = it.link
        local iid = it.link:match("Hitem:(%d+)")
        local tex = iid and (select(10, GetItemInfo(tonumber(iid))) or GetItemIcon and GetItemIcon(tonumber(iid)))
        r.icon:SetTexture(tex or "Interface\\Icons\\INV_Misc_QuestionMark")
        r.fs:SetText(("|cFF888888%s|r %s |cFF888888— %s|r"):format(it.t, it.link, it.who))
        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", self.list, "TOPLEFT", 0, -y)
        r:SetPoint("TOPRIGHT", self.list, "TOPRIGHT", 0, -y)
        r:Show()
        y = y + ROW
    end
    for i = #self.items + 1, #self.rows do self.rows[i]:Hide() end
    self.empty:SetShown(#self.items == 0)
    SP:SetAutoHeight(self, math.max(40, y + 4))
end

SP:RegisterModule(M)
