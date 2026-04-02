-- ============================================================================
-- GearScoreUI - Minimap Button & Settings Panel
-- Vanilla 1.12 / Lua 5.0 compatible
-- ============================================================================

GearScoreSettings = GearScoreSettings or {}

-- ============================================================================
-- DEFAULTS
-- ============================================================================

local DEFAULTS = {
    minimapPos = 220,
    lootEnabled = true,
    talentsEnabled = true,
    debugLog = false,
}

local function ApplyDefaults()
    if GearScoreSettings.minimapPos == nil then
        GearScoreSettings.minimapPos = DEFAULTS.minimapPos
    end
    if GearScoreSettings.lootEnabled == nil then
        GearScoreSettings.lootEnabled = DEFAULTS.lootEnabled
    end
    if GearScoreSettings.debugLog == nil then
        GearScoreSettings.debugLog = DEFAULTS.debugLog
    end
    if GearScoreSettings.talentsEnabled == nil then
        GearScoreSettings.talentsEnabled = DEFAULTS.talentsEnabled
    end
end

-- ============================================================================
-- MINIMAP BUTTON
-- ============================================================================

local minimapButton = CreateFrame("Button", "GearScoreMinimapButton", Minimap)
minimapButton:SetWidth(33)
minimapButton:SetHeight(33)
minimapButton:SetFrameStrata("MEDIUM")
minimapButton:SetFrameLevel(8)
minimapButton:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

-- Icon
local icon = minimapButton:CreateTexture(nil, "BACKGROUND")
icon:SetTexture("Interface\\Icons\\INV_Misc_Gear_01")
icon:SetWidth(20)
icon:SetHeight(20)
icon:SetPoint("CENTER", 0, 0)

-- Border overlay
local border = minimapButton:CreateTexture(nil, "OVERLAY")
border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
border:SetWidth(56)
border:SetHeight(56)
border:SetPoint("TOPLEFT", 0, 0)

-- Position the button around the minimap
local function UpdateMinimapPosition()
    local angle = GearScoreSettings.minimapPos or 220
    local radius = 80
    minimapButton:ClearAllPoints()
    minimapButton:SetPoint(
        "TOPLEFT", "Minimap", "TOPLEFT",
        52 - (radius * cos(angle)),
        (radius * sin(angle)) - 52
    )
end

-- Drag handling
local isDragging = false
minimapButton:RegisterForDrag("LeftButton")
minimapButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")

minimapButton:SetScript("OnDragStart", function()
    isDragging = true
end)

minimapButton:SetScript("OnDragStop", function()
    isDragging = false
end)

minimapButton:SetScript("OnUpdate", function()
    if not isDragging then return end
    local xpos, ypos = GetCursorPosition()
    local xmin, ymin = Minimap:GetLeft(), Minimap:GetBottom()
    local scale = UIParent:GetEffectiveScale()
    xpos = xmin - xpos / scale + 70
    ypos = ypos / scale - ymin - 70
    local angle = math.deg(math.atan2(ypos, xpos))
    if angle < 0 then angle = angle + 360 end
    GearScoreSettings.minimapPos = angle
    UpdateMinimapPosition()
end)

-- Click handler
minimapButton:SetScript("OnClick", function()
    if arg1 == "LeftButton" then
        if GearScoreSettingsFrame:IsVisible() then
            GearScoreSettingsFrame:Hide()
        else
            GearScoreSettingsFrame:Show()
            GearScoreUI_UpdateStatus()
        end
    elseif arg1 == "RightButton" then
        -- Quick status
        local lootCount = GearScore_GetLootDBCount and GearScore_GetLootDBCount() or 0
        local upgradeCount = 0
        if GearScoreUpgrades then
            for _ in pairs(GearScoreUpgrades) do
                upgradeCount = upgradeCount + 1
            end
        end
        local enabled = GearScoreSettings.lootEnabled and "|cFF00FF00ON|r" or "|cFFFF0000OFF|r"
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[GearScore]|r Loot: " .. enabled .. " | Items: " .. lootCount .. " | Upgrades: " .. upgradeCount)
    end
end)

-- Tooltip
minimapButton:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_LEFT")
    GameTooltip:AddLine("|cFF00FF00GearScore|r")
    GameTooltip:AddLine("Left-click: Open settings", 1, 1, 1)
    GameTooltip:AddLine("Right-click: Quick status", 1, 1, 1)
    GameTooltip:AddLine("Drag: Move button", 0.7, 0.7, 0.7)
    GameTooltip:Show()
end)

minimapButton:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)

-- ============================================================================
-- SETTINGS PANEL
-- ============================================================================

local settingsFrame = CreateFrame("Frame", "GearScoreSettingsFrame", UIParent)
settingsFrame:SetWidth(280)
settingsFrame:SetHeight(396)
settingsFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
settingsFrame:SetFrameStrata("DIALOG")
settingsFrame:SetMovable(true)
settingsFrame:EnableMouse(true)
settingsFrame:RegisterForDrag("LeftButton")
settingsFrame:SetScript("OnDragStart", function() this:StartMoving() end)
settingsFrame:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
settingsFrame:Hide()

-- Backdrop
settingsFrame:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
})
settingsFrame:SetBackdropColor(0, 0, 0, 0.9)

-- Make closable with Escape
if UISpecialFrames then
    table.insert(UISpecialFrames, "GearScoreSettingsFrame")
end

-- Title
local title = settingsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
title:SetPoint("TOP", settingsFrame, "TOP", 0, -12)
title:SetText("|cFF00FF00GearScore Settings|r")

-- Close button
local closeBtn = CreateFrame("Button", nil, settingsFrame, "UIPanelCloseButton")
closeBtn:SetPoint("TOPRIGHT", settingsFrame, "TOPRIGHT", -2, -2)

-- ============================================================================
-- LOOT TOGGLE
-- ============================================================================

local lootToggle = CreateFrame("CheckButton", "GearScoreLootToggle", settingsFrame, "OptionsCheckButtonTemplate")
lootToggle:SetPoint("TOPLEFT", settingsFrame, "TOPLEFT", 16, -42)

local lootToggleText = getglobal("GearScoreLootToggleText")
if lootToggleText then
    lootToggleText:SetText("Enable loot collection")
end

lootToggle:SetScript("OnClick", function()
    local checked = (this:GetChecked() == 1)
    GearScoreSettings.lootEnabled = checked
    if GearScore_SetLootEnabled then
        GearScore_SetLootEnabled(checked)
    end
    if checked then
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[GearScore]|r Loot collection |cFF00FF00enabled|r")
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[GearScore]|r Loot collection |cFFFF0000disabled|r")
    end
end)

-- ============================================================================
-- TALENT SYNC TOGGLE
-- ============================================================================

local talentToggle = CreateFrame("CheckButton", "GearScoreTalentToggle", settingsFrame, "OptionsCheckButtonTemplate")
talentToggle:SetPoint("TOPLEFT", settingsFrame, "TOPLEFT", 16, -66)

local talentToggleText = getglobal("GearScoreTalentToggleText")
if talentToggleText then
    talentToggleText:SetText("Enable talent sync")
end

talentToggle:SetScript("OnClick", function()
    local checked = (this:GetChecked() == 1)
    GearScoreSettings.talentsEnabled = checked
    if checked then
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[GearScore]|r Talent sync |cFF00FF00enabled|r")
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[GearScore]|r Talent sync |cFFFF0000disabled|r")
    end
end)

-- ============================================================================
-- DEBUG LOG TOGGLE
-- ============================================================================

local debugToggle = CreateFrame("CheckButton", "GearScoreDebugToggle", settingsFrame, "OptionsCheckButtonTemplate")
debugToggle:SetPoint("TOPLEFT", settingsFrame, "TOPLEFT", 16, -90)

local debugToggleText = getglobal("GearScoreDebugToggleText")
if debugToggleText then
    debugToggleText:SetText("Show chat log messages")
end

debugToggle:SetScript("OnClick", function()
    local checked = (this:GetChecked() == 1)
    GearScoreSettings.debugLog = checked
    if checked then
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[GearScore]|r Chat log |cFF00FF00enabled|r")
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[GearScore]|r Chat log |cFFFF0000disabled|r")
    end
end)

-- ============================================================================
-- SECTION: ACTIONS
-- ============================================================================

local actionsLabel = settingsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
actionsLabel:SetPoint("TOPLEFT", settingsFrame, "TOPLEFT", 16, -120)
actionsLabel:SetText("Actions")

-- Scan Gear button
local scanBtn = CreateFrame("Button", nil, settingsFrame, "UIPanelButtonTemplate")
scanBtn:SetWidth(240)
scanBtn:SetHeight(22)
scanBtn:SetPoint("TOPLEFT", settingsFrame, "TOPLEFT", 20, -140)
scanBtn:SetText("Scan Gear")
scanBtn:SetScript("OnClick", function()
    if GearScore_ManualScan then
        GearScore_ManualScan()
    end
    GearScoreUI_UpdateStatus()
end)

-- Show Loot List button
local lootListBtn = CreateFrame("Button", nil, settingsFrame, "UIPanelButtonTemplate")
lootListBtn:SetWidth(240)
lootListBtn:SetHeight(22)
lootListBtn:SetPoint("TOPLEFT", settingsFrame, "TOPLEFT", 20, -168)
lootListBtn:SetText("Show Loot List")
lootListBtn:SetScript("OnClick", function()
    if GearScoreLootListFrame:IsVisible() then
        GearScoreLootListFrame:Hide()
    else
        GearScoreUI_ShowLootList()
    end
end)

-- Show Upgrades button
local upgradeListBtn = CreateFrame("Button", nil, settingsFrame, "UIPanelButtonTemplate")
upgradeListBtn:SetWidth(240)
upgradeListBtn:SetHeight(22)
upgradeListBtn:SetPoint("TOPLEFT", settingsFrame, "TOPLEFT", 20, -196)
upgradeListBtn:SetText("Show Upgrades")
upgradeListBtn:SetScript("OnClick", function()
    if GearScoreUpgradeListFrame:IsVisible() then
        GearScoreUpgradeListFrame:Hide()
    else
        GearScoreUI_ShowUpgradeList()
    end
end)

-- Loot DB Stats button
local lootStatsBtn = CreateFrame("Button", nil, settingsFrame, "UIPanelButtonTemplate")
lootStatsBtn:SetWidth(240)
lootStatsBtn:SetHeight(22)
lootStatsBtn:SetPoint("TOPLEFT", settingsFrame, "TOPLEFT", 20, -224)
lootStatsBtn:SetText("Loot DB Stats")
lootStatsBtn:SetScript("OnClick", function()
    if GearScore_ShowLootDBStats then
        GearScore_ShowLootDBStats()
    end
end)

-- Clear Loot DB button (shift+click safety)
local clearBtn = CreateFrame("Button", nil, settingsFrame, "UIPanelButtonTemplate")
clearBtn:SetWidth(240)
clearBtn:SetHeight(22)
clearBtn:SetPoint("TOPLEFT", settingsFrame, "TOPLEFT", 20, -252)
clearBtn:SetText("Clear Loot DB (Shift+Click)")
clearBtn:SetScript("OnClick", function()
    if IsShiftKeyDown() then
        GearScoreLootDB = { version = 1, lastUpdated = 0, items = {} }
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[GearScore]|r Loot database cleared")
        GearScoreUI_UpdateStatus()
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000[GearScore]|r Hold Shift and click to clear the loot database")
    end
end)

-- ============================================================================
-- UPGRADE LIST WINDOW
-- ============================================================================

local UPGRADE_ROW_HEIGHT = 16
local UPGRADE_VISIBLE_ROWS = 20
local upgradeListOffset = 0
local upgradeListItems = {}

local upgradeListFrame = CreateFrame("Frame", "GearScoreUpgradeListFrame", UIParent)
upgradeListFrame:SetWidth(460)
upgradeListFrame:SetHeight(400)
upgradeListFrame:SetPoint("CENTER", UIParent, "CENTER", -200, 0)
upgradeListFrame:SetFrameStrata("DIALOG")
upgradeListFrame:SetMovable(true)
upgradeListFrame:EnableMouse(true)
upgradeListFrame:RegisterForDrag("LeftButton")
upgradeListFrame:SetScript("OnDragStart", function() this:StartMoving() end)
upgradeListFrame:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
upgradeListFrame:Hide()

upgradeListFrame:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
})
upgradeListFrame:SetBackdropColor(0, 0, 0, 0.95)

if UISpecialFrames then
    table.insert(UISpecialFrames, "GearScoreUpgradeListFrame")
end

local ulTitle = upgradeListFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
ulTitle:SetPoint("TOP", upgradeListFrame, "TOP", 0, -10)
ulTitle:SetText("|cFF00BFFF⚔ TurtleLootLine - Upgrade Recommendations|r")

local ulCloseBtn = CreateFrame("Button", nil, upgradeListFrame, "UIPanelCloseButton")
ulCloseBtn:SetPoint("TOPRIGHT", upgradeListFrame, "TOPRIGHT", -2, -2)

local ulCountText = upgradeListFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
ulCountText:SetPoint("TOPLEFT", upgradeListFrame, "TOPLEFT", 12, -28)

-- Column headers
local ulHeaderSlot = upgradeListFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
ulHeaderSlot:SetPoint("TOPLEFT", upgradeListFrame, "TOPLEFT", 12, -44)
ulHeaderSlot:SetText("|cFFFFD700Slot|r")

local ulHeaderName = upgradeListFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
ulHeaderName:SetPoint("TOPLEFT", upgradeListFrame, "TOPLEFT", 80, -44)
ulHeaderName:SetText("|cFFFFD700Item Name|r")

local ulHeaderUpgrade = upgradeListFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
ulHeaderUpgrade:SetPoint("TOPRIGHT", upgradeListFrame, "TOPRIGHT", -28, -44)
ulHeaderUpgrade:SetText("|cFFFFD700Upgrade|r")

local ulSeparator = upgradeListFrame:CreateTexture(nil, "ARTWORK")
ulSeparator:SetTexture(1, 1, 1, 0.3)
ulSeparator:SetHeight(1)
ulSeparator:SetPoint("TOPLEFT", upgradeListFrame, "TOPLEFT", 8, -55)
ulSeparator:SetPoint("TOPRIGHT", upgradeListFrame, "TOPRIGHT", -24, -55)

-- Create row frames
local upgradeListRows = {}
for i = 1, UPGRADE_VISIBLE_ROWS do
    local row = CreateFrame("Button", nil, upgradeListFrame)
    row:SetWidth(416)
    row:SetHeight(UPGRADE_ROW_HEIGHT)
    row:SetPoint("TOPLEFT", upgradeListFrame, "TOPLEFT", 10, -56 - ((i - 1) * UPGRADE_ROW_HEIGHT))

    local highlight = row:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetTexture(1, 1, 1, 0.1)
    highlight:SetAllPoints(row)

    local slotText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    slotText:SetPoint("LEFT", row, "LEFT", 2, 0)
    slotText:SetWidth(65)
    slotText:SetJustifyH("LEFT")

    local nameText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    nameText:SetPoint("LEFT", row, "LEFT", 70, 0)
    nameText:SetWidth(280)
    nameText:SetJustifyH("LEFT")

    local upgradeText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    upgradeText:SetPoint("RIGHT", row, "RIGHT", -2, 0)
    upgradeText:SetWidth(70)
    upgradeText:SetJustifyH("RIGHT")

    row.slotText = slotText
    row.nameText = nameText
    row.upgradeText = upgradeText

    -- Tooltip on hover: show item name from GetItemInfo if possible
    row:SetScript("OnEnter", function()
        if this.itemId then
            GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
            local itemName = GetItemInfo(this.itemId)
            if itemName then
                -- SetHyperlink with just the item ID
                GameTooltip:SetHyperlink("item:" .. this.itemId .. ":0:0:0")
            else
                GameTooltip:AddLine("Item #" .. this.itemId)
                GameTooltip:AddLine(this.noteTxt or "", 1, 1, 1)
            end
            GameTooltip:Show()
        end
    end)

    row:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    upgradeListRows[i] = row
end

-- Scrollbar
local ulScrollBar = CreateFrame("Slider", "GearScoreUpgradeListScrollBar", upgradeListFrame, "UIPanelScrollBarTemplate")
upgradeListFrame.SetVerticalScroll = function() end
ulScrollBar:SetPoint("TOPRIGHT", upgradeListFrame, "TOPRIGHT", -8, -72)
ulScrollBar:SetPoint("BOTTOMRIGHT", upgradeListFrame, "BOTTOMRIGHT", -8, 16)
ulScrollBar:SetWidth(16)
ulScrollBar:SetMinMaxValues(0, 1)
ulScrollBar:SetValueStep(1)
ulScrollBar:SetValue(0)

ulScrollBar:SetScript("OnValueChanged", function()
    upgradeListOffset = math.floor(this:GetValue())
    GearScoreUI_UpdateUpgradeList()
end)

upgradeListFrame:EnableMouseWheel(true)
upgradeListFrame:SetScript("OnMouseWheel", function()
    local newOffset = upgradeListOffset - arg1 * 3
    if newOffset < 0 then newOffset = 0 end
    local maxOffset = table.getn(upgradeListItems) - UPGRADE_VISIBLE_ROWS
    if maxOffset < 0 then maxOffset = 0 end
    if newOffset > maxOffset then newOffset = maxOffset end
    upgradeListOffset = newOffset
    ulScrollBar:SetValue(newOffset)
    GearScoreUI_UpdateUpgradeList()
end)

function GearScoreUI_UpdateUpgradeList()
    for i = 1, UPGRADE_VISIBLE_ROWS do
        local row = upgradeListRows[i]
        local dataIdx = upgradeListOffset + i
        local item = upgradeListItems[dataIdx]

        if item then
            row.slotText:SetText("|cFFAAAAAA" .. (item.slot or "") .. "|r")
            row.nameText:SetText(item.displayName or ("Item #" .. item.itemId))
            row.upgradeText:SetText("|cFF00FF00" .. (item.overall or "") .. "|r")
            row.itemId = item.itemId
            row.noteTxt = item.note
            row:Show()
        else
            row.slotText:SetText("")
            row.nameText:SetText("")
            row.upgradeText:SetText("")
            row.itemId = nil
            row:Hide()
        end
    end
end

function GearScoreUI_RefreshUpgradeList()
    upgradeListItems = {}
    if not GearScoreUpgrades then return end

    for itemId, data in pairs(GearScoreUpgrades) do
        local numId = tonumber(itemId)
        if numId and data.overall and data.overall ~= "+0%" then
            local itemName = GetItemInfo(numId)
            table.insert(upgradeListItems, {
                itemId = numId,
                displayName = itemName and ("|cFF1EFF00" .. itemName .. "|r") or ("|cFFAAAAAA Item #" .. numId .. "|r"),
                overall = data.overall,
                note = data.note,
                slot = data.note and string.gsub(data.note, " upgrade.*", "") or "",
                -- For sorting: extract percentage number
                pct = tonumber(string.match(data.overall, "([%d%.]+)")) or 0,
            })
        end
    end

    -- Sort by upgrade percentage descending
    table.sort(upgradeListItems, function(a, b)
        return a.pct > b.pct
    end)

    ulCountText:SetText("Upgrades: " .. table.getn(upgradeListItems) .. " items")

    local maxOffset = table.getn(upgradeListItems) - UPGRADE_VISIBLE_ROWS
    if maxOffset < 0 then maxOffset = 0 end
    ulScrollBar:SetMinMaxValues(0, maxOffset)

    upgradeListOffset = 0
    ulScrollBar:SetValue(0)
    GearScoreUI_UpdateUpgradeList()
end

function GearScoreUI_ShowUpgradeList()
    GearScoreUI_RefreshUpgradeList()
    upgradeListFrame:Show()
end

-- ============================================================================
-- LOOT LIST WINDOW
-- ============================================================================

local LOOT_LIST_ROW_HEIGHT = 16
local LOOT_LIST_VISIBLE_ROWS = 20
local lootListOffset = 0
local lootListItems = {}  -- sorted list of { itemId, name, quality, slot }

local lootListFrame = CreateFrame("Frame", "GearScoreLootListFrame", UIParent)
lootListFrame:SetWidth(420)
lootListFrame:SetHeight(380)
lootListFrame:SetPoint("CENTER", UIParent, "CENTER", 200, 0)
lootListFrame:SetFrameStrata("DIALOG")
lootListFrame:SetMovable(true)
lootListFrame:EnableMouse(true)
lootListFrame:RegisterForDrag("LeftButton")
lootListFrame:SetScript("OnDragStart", function() this:StartMoving() end)
lootListFrame:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
lootListFrame:Hide()

lootListFrame:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
})
lootListFrame:SetBackdropColor(0, 0, 0, 0.95)

if UISpecialFrames then
    table.insert(UISpecialFrames, "GearScoreLootListFrame")
end

-- Title
local llTitle = lootListFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
llTitle:SetPoint("TOP", lootListFrame, "TOP", 0, -10)
llTitle:SetText("|cFF00FF00GearScore - Collected Items|r")

-- Close button
local llCloseBtn = CreateFrame("Button", nil, lootListFrame, "UIPanelCloseButton")
llCloseBtn:SetPoint("TOPRIGHT", lootListFrame, "TOPRIGHT", -2, -2)

-- Item count label
local llCountText = lootListFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
llCountText:SetPoint("TOPLEFT", lootListFrame, "TOPLEFT", 12, -28)
llCountText:SetText("Total: 0")

-- Column headers
local llHeaderName = lootListFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
llHeaderName:SetPoint("TOPLEFT", lootListFrame, "TOPLEFT", 12, -44)
llHeaderName:SetText("|cFFFFD700Item Name|r")

local llHeaderSlot = lootListFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
llHeaderSlot:SetPoint("TOPRIGHT", lootListFrame, "TOPRIGHT", -28, -44)
llHeaderSlot:SetText("|cFFFFD700Slot|r")

-- Separator line
local llSeparator = lootListFrame:CreateTexture(nil, "ARTWORK")
llSeparator:SetTexture(1, 1, 1, 0.3)
llSeparator:SetHeight(1)
llSeparator:SetPoint("TOPLEFT", lootListFrame, "TOPLEFT", 8, -55)
llSeparator:SetPoint("TOPRIGHT", lootListFrame, "TOPRIGHT", -24, -55)

-- Create row frames
local lootListRows = {}
for i = 1, LOOT_LIST_VISIBLE_ROWS do
    local row = CreateFrame("Button", nil, lootListFrame)
    row:SetWidth(376)
    row:SetHeight(LOOT_LIST_ROW_HEIGHT)
    row:SetPoint("TOPLEFT", lootListFrame, "TOPLEFT", 10, -56 - ((i - 1) * LOOT_LIST_ROW_HEIGHT))

    -- Highlight on hover
    local highlight = row:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetTexture(1, 1, 1, 0.1)
    highlight:SetAllPoints(row)

    -- Item name text
    local nameText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    nameText:SetPoint("LEFT", row, "LEFT", 2, 0)
    nameText:SetWidth(300)
    nameText:SetJustifyH("LEFT")

    -- Slot text
    local slotText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    slotText:SetPoint("RIGHT", row, "RIGHT", -2, 0)
    slotText:SetWidth(80)
    slotText:SetJustifyH("RIGHT")

    row.nameText = nameText
    row.slotText = slotText
    row.itemId = nil

    -- Tooltip on hover
    row:SetScript("OnEnter", function()
        if this.itemLink then
            GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
            local _, _, hyperlink = string.find(this.itemLink, "|H(item:%d+:%d+:%d+:%d+)|h")
            if hyperlink then
                GameTooltip:SetHyperlink(hyperlink)
            end
            GameTooltip:Show()
        end
    end)

    row:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    -- Shift+click to insert link into chat
    row:SetScript("OnClick", function()
        if this.itemLink and IsShiftKeyDown() and ChatFrameEditBox:IsVisible() then
            ChatFrameEditBox:Insert(this.itemLink)
        end
    end)

    lootListRows[i] = row
end

-- Scrollbar
local scrollBar = CreateFrame("Slider", "GearScoreLootListScrollBar", lootListFrame, "UIPanelScrollBarTemplate")
-- UIPanelScrollBarTemplate's OnValueChanged calls parent:SetVerticalScroll() which
-- doesn't exist on a plain Frame. Provide a no-op so it doesn't error.
lootListFrame.SetVerticalScroll = function() end
scrollBar:SetPoint("TOPRIGHT", lootListFrame, "TOPRIGHT", -8, -72)
scrollBar:SetPoint("BOTTOMRIGHT", lootListFrame, "BOTTOMRIGHT", -8, 16)
scrollBar:SetWidth(16)
scrollBar:SetMinMaxValues(0, 1)
scrollBar:SetValueStep(1)
scrollBar:SetValue(0)

scrollBar:SetScript("OnValueChanged", function()
    lootListOffset = math.floor(this:GetValue())
    GearScoreUI_UpdateLootList()
end)

-- Mouse wheel scrolling
lootListFrame:EnableMouseWheel(true)
lootListFrame:SetScript("OnMouseWheel", function()
    local newOffset = lootListOffset - arg1 * 3
    if newOffset < 0 then newOffset = 0 end
    local maxOffset = table.getn(lootListItems) - LOOT_LIST_VISIBLE_ROWS
    if maxOffset < 0 then maxOffset = 0 end
    if newOffset > maxOffset then newOffset = maxOffset end
    lootListOffset = newOffset
    scrollBar:SetValue(newOffset)
    GearScoreUI_UpdateLootList()
end)

-- Quality color lookup
local QUALITY_COLORS = {
    [0] = "|cFF9D9D9D",  -- Poor
    [1] = "|cFFFFFFFF",  -- Common
    [2] = "|cFF1EFF00",  -- Uncommon
    [3] = "|cFF0070DD",  -- Rare
    [4] = "|cFFA335EE",  -- Epic
    [5] = "|cFFFF8000",  -- Legendary
}

-- Update visible rows from data
function GearScoreUI_UpdateLootList()
    for i = 1, LOOT_LIST_VISIBLE_ROWS do
        local row = lootListRows[i]
        local dataIdx = lootListOffset + i
        local item = lootListItems[dataIdx]

        if item then
            local color = QUALITY_COLORS[item.quality] or "|cFFFFFFFF"
            row.nameText:SetText(color .. (item.name or "Unknown") .. "|r")
            row.slotText:SetText(item.slot or "")
            row.itemId = item.itemId
            row.itemLink = item.link
            row:Show()
        else
            row.nameText:SetText("")
            row.slotText:SetText("")
            row.itemId = nil
            row.itemLink = nil
            row:Hide()
        end
    end
end

-- Rebuild the sorted item list and refresh display
function GearScoreUI_RefreshLootList()
    lootListItems = {}
    if not GearScoreLootDB or not GearScoreLootDB.items then return end

    for itemId, item in pairs(GearScoreLootDB.items) do
        table.insert(lootListItems, {
            itemId = itemId,
            name = item.name,
            quality = item.quality or 0,
            slot = item.equipSlot or item.armorType or item.itemType or "",
            link = item.link,
        })
    end

    -- Sort by quality descending, then name
    table.sort(lootListItems, function(a, b)
        if a.quality ~= b.quality then
            return a.quality > b.quality
        end
        return (a.name or "") < (b.name or "")
    end)

    local total = table.getn(lootListItems)
    llCountText:SetText("Total: " .. total .. " items")

    -- Update scrollbar
    local maxOffset = total - LOOT_LIST_VISIBLE_ROWS
    if maxOffset < 0 then maxOffset = 0 end
    scrollBar:SetMinMaxValues(0, maxOffset)

    lootListOffset = 0
    scrollBar:SetValue(0)
    GearScoreUI_UpdateLootList()
end

-- Show the loot list window
function GearScoreUI_ShowLootList()
    GearScoreUI_RefreshLootList()
    lootListFrame:Show()
end

-- ============================================================================
-- SECTION: STATUS
-- ============================================================================

local statusLabel = settingsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
statusLabel:SetPoint("TOPLEFT", settingsFrame, "TOPLEFT", 16, -286)
statusLabel:SetText("Status")

local itemsText = settingsFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
itemsText:SetPoint("TOPLEFT", settingsFrame, "TOPLEFT", 20, -306)
itemsText:SetText("Items collected: 0")

local upgradesText = settingsFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
upgradesText:SetPoint("TOPLEFT", settingsFrame, "TOPLEFT", 20, -324)
upgradesText:SetText("Upgrades loaded: 0")

local lootStatusText = settingsFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
lootStatusText:SetPoint("TOPLEFT", settingsFrame, "TOPLEFT", 20, -342)
lootStatusText:SetText("Loot collection: ON")

local pendingText = settingsFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
pendingText:SetPoint("TOPLEFT", settingsFrame, "TOPLEFT", 20, -360)
pendingText:SetText("Pending items: 0")

-- ============================================================================
-- STATUS UPDATE
-- ============================================================================

function GearScoreUI_UpdateStatus()
    local lootCount = GearScore_GetLootDBCount and GearScore_GetLootDBCount() or 0
    itemsText:SetText("Items collected: " .. lootCount)

    local upgradeCount = 0
    if GearScoreUpgrades then
        for _ in pairs(GearScoreUpgrades) do
            upgradeCount = upgradeCount + 1
        end
    end
    upgradesText:SetText("Upgrades loaded: " .. upgradeCount)

    local enabled = GearScoreSettings.lootEnabled
    if enabled then
        lootStatusText:SetText("Loot collection: |cFF00FF00ON|r")
    else
        lootStatusText:SetText("Loot collection: |cFFFF0000OFF|r")
    end

    local pendingCount = GearScore_GetPendingCount and GearScore_GetPendingCount() or 0
    pendingText:SetText("Pending items: " .. pendingCount)
end

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
initFrame:SetScript("OnEvent", function()
    ApplyDefaults()
    UpdateMinimapPosition()

    -- Sync toggle states
    if lootToggle.SetChecked then
        if GearScoreSettings.lootEnabled then
            lootToggle:SetChecked(1)
        else
            lootToggle:SetChecked(nil)
        end
    end

    if talentToggle.SetChecked then
        if GearScoreSettings.talentsEnabled then
            talentToggle:SetChecked(1)
        else
            talentToggle:SetChecked(nil)
        end
    end

    if debugToggle.SetChecked then
        if GearScoreSettings.debugLog then
            debugToggle:SetChecked(1)
        else
            debugToggle:SetChecked(nil)
        end
    end

    if GearScore_SetLootEnabled then
        GearScore_SetLootEnabled(GearScoreSettings.lootEnabled)
    end

    GearScoreUI_UpdateStatus()
end)
