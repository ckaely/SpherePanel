-- ============================================================
-- Module : Currencies ("Monnaies") — or + monnaies suivies
-- ============================================================
-- Or en tête puis les monnaies marquées "suivies" dans l'onglet Monnaies de Blizzard.
local ADDON_NAME, SP = ...

local M = { name = "Currencies", label = "Monnaies", defaultHeight = 100 }

local ROW = 16

local function CreateRow(self, i)
    local r = CreateFrame("Frame", nil, self.list)
    r:SetHeight(ROW)
    r.icon = r:CreateTexture(nil, "ARTWORK"); r.icon:SetSize(13, 13); r.icon:SetPoint("LEFT", r, "LEFT", 2, 0)
    r.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    r.fs = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    r.fs:SetPoint("LEFT", r.icon, "RIGHT", 4, 0); r.fs:SetPoint("RIGHT", r, "RIGHT", -2, 0)
    r.fs:SetJustifyH("LEFT"); r.fs:SetWordWrap(false)
    r:EnableMouse(true)
    r:SetScript("OnEnter", function(s)
        if s.currencyID then
            SP:AnchorTooltipOutsidePanel(GameTooltip, s)
            pcall(GameTooltip.SetCurrencyByID, GameTooltip, s.currencyID)
            GameTooltip:Show()
        end
    end)
    r:SetScript("OnLeave", function() GameTooltip:Hide() end)
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
    self.ev = CreateFrame("Frame")
    self.ev:SetScript("OnEvent", function() self:RequestRefresh() end)
end

function M:Enable()
    self._enabled = true
    if self._placeholder then self._placeholder:Hide() end
    for _, e in ipairs({ "CURRENCY_DISPLAY_UPDATE", "PLAYER_MONEY", "PLAYER_ENTERING_WORLD" }) do
        pcall(self.ev.RegisterEvent, self.ev, e)
    end
    self:RequestRefresh()
end

function M:Disable()
    self._enabled = false
    if self.ev then self.ev:UnregisterAllEvents() end
    for _, r in ipairs(self.rows) do r:Hide() end
    SP:SetModuleHeaderText(self, "")
end

function M:OnResize(w, h) end

function M:RequestRefresh()
    if not self._enabled or self._pending then return end
    self._pending = true
    C_Timer.After(0.3, function() self._pending = false; self:Refresh() end)
end

function M:Refresh()
    if not self._enabled then return end
    local y, shown = 0, 0

    -- or
    shown = shown + 1
    local g = self.rows[shown] or CreateRow(self, shown)
    g.currencyID = nil
    g.icon:SetTexture("Interface\\MoneyFrame\\UI-GoldIcon")
    local money = GetMoney() or 0
    g.fs:SetText(GetMoneyString and GetMoneyString(money, true) or tostring(math.floor(money / 10000)) .. " po")
    g:ClearAllPoints(); g:SetPoint("TOPLEFT", self.list, "TOPLEFT", 0, -y); g:SetPoint("TOPRIGHT", self.list, "TOPRIGHT", 0, -y)
    g:Show()
    y = y + ROW

    -- monnaies suivies (cochées dans l'onglet Monnaies)
    if C_CurrencyInfo and C_CurrencyInfo.GetCurrencyListSize then
        local n = C_CurrencyInfo.GetCurrencyListSize() or 0
        for i = 1, n do
            local ok, info = pcall(C_CurrencyInfo.GetCurrencyListInfo, i)
            if ok and info and not info.isHeader and info.isShowInBackpack ~= nil then
                -- on affiche les monnaies marquées "suivre" + celles du sac à dos
                if info.isShowInBackpack or info.isWatched then
                    shown = shown + 1
                    local r = self.rows[shown] or CreateRow(self, shown)
                    local ok2, link = pcall(C_CurrencyInfo.GetCurrencyListLink, i)
                    r.currencyID = ok2 and link and tonumber(link:match("Hcurrency:(%d+)")) or nil
                    r.icon:SetTexture(info.iconFileID or "Interface\\Icons\\INV_Misc_QuestionMark")
                    local qty = info.quantity or 0
                    local maxQ = info.maxQuantity or 0
                    local txt = ("%s  |cFFFFFFFF%d|r"):format(info.name or "?", qty)
                    if maxQ > 0 then txt = txt .. ("|cFF888888 / %d|r"):format(maxQ) end
                    r.fs:SetText(txt)
                    r:ClearAllPoints()
                    r:SetPoint("TOPLEFT", self.list, "TOPLEFT", 0, -y)
                    r:SetPoint("TOPRIGHT", self.list, "TOPRIGHT", 0, -y)
                    r:Show()
                    y = y + ROW
                end
            end
        end
    end

    for i = shown + 1, #self.rows do self.rows[i]:Hide() end
    SP:SetAutoHeight(self, math.max(40, y + 4))
end

SP:RegisterModule(M)
