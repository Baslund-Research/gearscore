-- ============================================================================
-- LootCollector - Captures items from all in-game sources for GearSync
-- Stores item data account-wide for TurtleLootLine sync
-- ============================================================================

-- Account-wide SavedVariable
GearSyncLootDB = GearSyncLootDB or {}

-- ============================================================================
-- CONSTANTS
-- ============================================================================

local RETRY_INTERVAL = 2.0   -- Seconds between retry passes
local MAX_RETRIES = 5         -- Give up after this many attempts
local MAX_SOURCES = 20        -- Max source entries per item
local SOURCE_DEDUP_TIME = 300 -- Skip duplicate source within 5 minutes
local MIN_QUALITY = 2         -- Minimum item quality (2 = Uncommon/Green)

-- ============================================================================
-- STATE
-- ============================================================================

local pendingItems = {}  -- { [itemId] = { link=, sources={}, retries=0 } }
local retryTimer = 0
local lootCollectionEnabled = true

function GearSync_SetLootEnabled(enabled)
    lootCollectionEnabled = enabled
end

function GearSync_GetLootEnabled()
    return lootCollectionEnabled
end

-- ============================================================================
-- EVENT FRAME
-- ============================================================================

local lootFrame = CreateFrame("Frame")

-- ============================================================================
-- UTILITY
-- ============================================================================

local function Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[GearSync Loot]|r " .. msg)
end

-- Extract item ID from an item link
local function ExtractItemId(itemLink)
    if not itemLink then return nil end
    local _, _, idStr = string.find(itemLink, "item:(%d+)")
    if idStr then
        return tonumber(idStr)
    end
    return nil
end

-- Extract item link from a chat message
local function ExtractItemLink(msg)
    if not msg then return nil end
    local _, _, link = string.find(msg, "(|c%x+|Hitem:%d+:%d+:%d+:%d+|h%[.-%]|h|r)")
    return link
end

-- Extract item name from a link
local function ExtractItemName(itemLink)
    if not itemLink then return nil end
    local _, _, name = string.find(itemLink, "%[(.+)%]")
    return name
end

-- ============================================================================
-- DB INITIALIZATION
-- ============================================================================

local function InitDB()
    if not GearSyncLootDB.version then
        GearSyncLootDB = {
            version = 1,
            lastUpdated = 0,
            items = {},
        }
    end
    if not GearSyncLootDB.items then
        GearSyncLootDB.items = {}
    end
end

-- ============================================================================
-- CORE ITEM PROCESSING
-- ============================================================================

-- Check if a source is a duplicate of a recent entry for this item
local function IsSourceDuplicate(existingItem, source)
    if not existingItem or not existingItem.sources then return false end

    local now = time()
    -- Check last 5 sources for dedup
    local count = table.getn(existingItem.sources)
    local startIdx = count - 4
    if startIdx < 1 then startIdx = 1 end

    for i = startIdx, count do
        local s = existingItem.sources[i]
        if s and s.mob == source.mob and s.zone == source.zone then
            if (now - (s.time or 0)) < SOURCE_DEDUP_TIME then
                return true
            end
        end
    end

    return false
end

-- Process a single item: parse stats and store in DB
-- Returns true if processed (or should stop retrying), false if needs retry
local function ProcessItem(itemId, itemLink, sources)
    -- Get basic item info from the client
    local name, _, quality, minLevel, itemType, itemSubType, stackCount, equipLoc, texture = GetItemInfo(itemId)

    if not name then
        return false  -- Not cached, retry later
    end

    -- [DEBUG] Log item type for troubleshooting (remove before release)
    Print(string.format("[DEBUG] Item: %s | type: %s | subType: %s | quality: %s", tostring(name), tostring(itemType), tostring(itemSubType), tostring(quality)))

    -- Filter: only Armor and Weapon types
    if itemType ~= "Armor" and itemType ~= "Weapon" then
        return true  -- Not equipment, stop retrying but don't store
    end

    -- Filter: minimum quality
    if quality and quality < MIN_QUALITY then
        return true  -- Too low quality, stop retrying
    end

    -- Parse tooltip for detailed stats
    local parsed = GearSync_ParseItemTooltip(itemLink)
    if not parsed then
        return false  -- Tooltip not ready, retry later
    end

    -- Build or update DB entry
    local existing = GearSyncLootDB.items[itemId]
    local now = time()

    if not existing then
        existing = {
            name = name,
            link = itemLink,
            quality = quality,
            requiredLevel = parsed.requiredLevel or minLevel,
            itemType = itemType,
            itemSubType = itemSubType,
            equipSlot = parsed.equipSlot or equipLoc,
            bindType = parsed.bindType,
            armorType = parsed.armorType,
            weaponType = parsed.weaponType,
            classes = parsed.classes,
            setName = parsed.setName,
            stats = parsed.stats or {},
            equip = parsed.equip or {},
            weaponDamageMin = parsed.weaponDamageMin,
            weaponDamageMax = parsed.weaponDamageMax,
            weaponSpeed = parsed.weaponSpeed,
            dps = parsed.dps,
            sources = {},
            firstSeen = now,
            lastSeen = now,
        }
        GearSyncLootDB.items[itemId] = existing
    else
        -- Update last seen
        existing.lastSeen = now
        -- Update link if we have a newer one
        existing.link = itemLink
    end

    -- Add sources with dedup
    for i = 1, table.getn(sources) do
        local source = sources[i]
        if not IsSourceDuplicate(existing, source) then
            table.insert(existing.sources, source)
            -- Cap sources
            while table.getn(existing.sources) > MAX_SOURCES do
                table.remove(existing.sources, 1)
            end
        end
    end

    GearSyncLootDB.lastUpdated = now
    return true
end

-- ============================================================================
-- QUEUE AND RETRY SYSTEM
-- ============================================================================

-- Queue an item for processing
local function QueueItem(itemLink, source)
    if not lootCollectionEnabled then return end
    local itemId = ExtractItemId(itemLink)
    if not itemId then return end

    -- Quick quality filter if info is available
    local _, _, quality = GetItemInfo(itemId)
    if quality and quality < MIN_QUALITY then return end

    local sources = { source }

    -- Try processing immediately
    if ProcessItem(itemId, itemLink, sources) then
        return  -- Done
    end

    -- Add to pending queue for retry
    if pendingItems[itemId] then
        -- Merge source into existing pending entry
        table.insert(pendingItems[itemId].sources, source)
    else
        pendingItems[itemId] = {
            link = itemLink,
            sources = sources,
            retries = 0,
        }
    end

    -- Enable OnUpdate for retry processing
    if not lootFrame:GetScript("OnUpdate") then
        retryTimer = 0
        lootFrame:SetScript("OnUpdate", function()
            retryTimer = retryTimer + arg1
            if retryTimer < RETRY_INTERVAL then return end
            retryTimer = 0

            local empty = true
            for id, pending in pairs(pendingItems) do
                empty = false
                pending.retries = pending.retries + 1

                if ProcessItem(id, pending.link, pending.sources) then
                    pendingItems[id] = nil
                elseif pending.retries >= MAX_RETRIES then
                    pendingItems[id] = nil
                end
            end

            -- Remove OnUpdate when queue is empty
            if empty then
                lootFrame:SetScript("OnUpdate", nil)
            end
        end)
    end
end

-- ============================================================================
-- CAPTURE CHANNEL 1: LOOT WINDOW
-- ============================================================================

local function OnLootOpened()
    local mobName = UnitName("target")
    local zone = GetRealZoneText() or GetZoneText() or "Unknown"
    local playerName = UnitName("player")

    local numItems = GetNumLootItems()
    for slot = 1, numItems do
        local itemLink = GetLootSlotLink(slot)
        if itemLink then
            QueueItem(itemLink, {
                type = "loot",
                mob = mobName,
                zone = zone,
                time = time(),
                looter = playerName,
            })
        end
    end
end

-- ============================================================================
-- CAPTURE CHANNEL 2: PARTY/RAID LOOT CHAT
-- ============================================================================

local function OnChatMsgLoot()
    local msg = arg1
    if not msg then return end

    local itemLink = ExtractItemLink(msg)
    if not itemLink then return end

    -- Determine looter
    local _, _, looterName = string.find(msg, "^(.+) receives loot")
    if not looterName then
        looterName = UnitName("player")
    end

    local zone = GetRealZoneText() or GetZoneText() or "Unknown"

    QueueItem(itemLink, {
        type = "partyloot",
        mob = nil,
        zone = zone,
        time = time(),
        looter = looterName,
    })
end

-- ============================================================================
-- CAPTURE CHANNEL 3: QUEST REWARDS (SYSTEM MESSAGES)
-- ============================================================================

local function OnChatMsgSystem()
    local msg = arg1
    if not msg then return end

    local itemLink = ExtractItemLink(msg)
    if not itemLink then return end

    QueueItem(itemLink, {
        type = "quest",
        mob = nil,
        zone = GetRealZoneText() or GetZoneText() or "Unknown",
        time = time(),
        looter = UnitName("player"),
    })
end

-- ============================================================================
-- CAPTURE CHANNEL 4: CHAT ITEM LINK CLICKS
-- ============================================================================

-- Hook SetItemRef to capture items clicked in chat
local originalSetItemRef = SetItemRef

SetItemRef = function(link, text, button)
    -- Extract item link from the reference
    if link and string.find(link, "^item:") then
        local itemLink = ExtractItemLink(text)
        if itemLink then
            QueueItem(itemLink, {
                type = "chatlink",
                mob = nil,
                zone = nil,
                time = time(),
                looter = nil,
            })
        end
    end

    -- Call original handler
    if originalSetItemRef then
        return originalSetItemRef(link, text, button)
    end
end

-- ============================================================================
-- CAPTURE CHANNEL 5: VENDOR/MERCHANT ITEMS
-- ============================================================================

-- Hook GameTooltip.SetMerchantItem if available
if GameTooltip.SetMerchantItem then
    local originalSetMerchantItem = GameTooltip.SetMerchantItem

    GameTooltip.SetMerchantItem = function(self, index)
        -- Call original first so tooltip is populated
        if originalSetMerchantItem then
            originalSetMerchantItem(self, index)
        end

        -- Try to get merchant item link
        if GetMerchantItemLink then
            local itemLink = GetMerchantItemLink(index)
            if itemLink then
                QueueItem(itemLink, {
                    type = "vendor",
                    mob = UnitName("target"),  -- Vendor NPC name
                    zone = GetRealZoneText() or GetZoneText() or "Unknown",
                    time = time(),
                    looter = nil,
                })
            end
        end
    end
end

-- ============================================================================
-- EVENT HANDLER
-- ============================================================================

local function OnEvent()
    if event == "PLAYER_ENTERING_WORLD" then
        InitDB()

        -- Scan equipped gear into loot DB on login
        local playerName = UnitName("player")
        local zone = GetRealZoneText() or GetZoneText() or "Unknown"
        for slotId = 1, 19 do
            local itemLink = GetInventoryItemLink("player", slotId)
            if itemLink then
                QueueItem(itemLink, {
                    type = "equipped",
                    mob = nil,
                    zone = zone,
                    time = time(),
                    looter = playerName,
                })
            end
        end

        -- Also scan bags
        for bag = 0, 4 do
            local numSlots = GetContainerNumSlots(bag)
            if numSlots then
                for slot = 1, numSlots do
                    local itemLink = GetContainerItemLink(bag, slot)
                    if itemLink then
                        QueueItem(itemLink, {
                            type = "bag",
                            mob = nil,
                            zone = zone,
                            time = time(),
                            looter = playerName,
                        })
                    end
                end
            end
        end

        local count = 0
        for _ in pairs(GearSyncLootDB.items) do
            count = count + 1
        end
        Print(string.format("Loot database: %d items (scanning equipped + bags)", count))

    elseif event == "LOOT_OPENED" then
        Print("[DEBUG] LOOT_OPENED fired")
        OnLootOpened()

    elseif event == "CHAT_MSG_LOOT" then
        Print("[DEBUG] CHAT_MSG_LOOT: " .. tostring(arg1))
        OnChatMsgLoot()

    elseif event == "CHAT_MSG_SYSTEM" then
        Print("[DEBUG] CHAT_MSG_SYSTEM: " .. tostring(arg1))
        OnChatMsgSystem()
    end
end

lootFrame:SetScript("OnEvent", OnEvent)
lootFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
lootFrame:RegisterEvent("LOOT_OPENED")
lootFrame:RegisterEvent("CHAT_MSG_LOOT")
lootFrame:RegisterEvent("CHAT_MSG_SYSTEM")

-- ============================================================================
-- PUBLIC DEBUG API
-- ============================================================================

function GearSync_GetLootDBCount()
    local count = 0
    for _ in pairs(GearSyncLootDB.items) do
        count = count + 1
    end
    return count
end

function GearSync_GetPendingCount()
    local count = 0
    for _ in pairs(pendingItems) do
        count = count + 1
    end
    return count
end
