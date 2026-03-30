-- ============================================================================
-- TooltipParser - Hidden tooltip stat extraction for GearSync
-- Parses item stats from a hidden tooltip frame (Vanilla 1.12 / Lua 5.0)
-- ============================================================================

-- Hidden tooltip created on first use (UIParent may not exist at load time)
local scanTooltip = nil

local function GetScanTooltip()
    if not scanTooltip then
        scanTooltip = CreateFrame("GameTooltip", "GearSyncScanTooltip", UIParent, "GameTooltipTemplate")
        scanTooltip:SetOwner(UIParent, "ANCHOR_NONE")
    end
    return scanTooltip
end

-- ============================================================================
-- STAT MAPPING
-- ============================================================================

-- Maps tooltip stat text to canonical keys
local STAT_MAP = {
    ["Stamina"] = "stamina",
    ["Strength"] = "strength",
    ["Agility"] = "agility",
    ["Intellect"] = "intellect",
    ["Spirit"] = "spirit",
    ["Attack Power"] = "attackPower",
    ["Defense"] = "defense",
    ["Fire Resistance"] = "fireResistance",
    ["Nature Resistance"] = "natureResistance",
    ["Frost Resistance"] = "frostResistance",
    ["Shadow Resistance"] = "shadowResistance",
    ["Arcane Resistance"] = "arcaneResistance",
    ["Armor"] = "armor",
}

-- Equipment slot strings found in tooltips
local EQUIP_SLOTS = {
    ["Head"] = "Head",
    ["Neck"] = "Neck",
    ["Shoulder"] = "Shoulder",
    ["Back"] = "Back",
    ["Chest"] = "Chest",
    ["Wrist"] = "Wrist",
    ["Hands"] = "Hands",
    ["Waist"] = "Waist",
    ["Legs"] = "Legs",
    ["Feet"] = "Feet",
    ["Finger"] = "Finger",
    ["Trinket"] = "Trinket",
    ["Main Hand"] = "MainHand",
    ["Off Hand"] = "OffHand",
    ["One-Hand"] = "OneHand",
    ["Two-Hand"] = "TwoHand",
    ["Ranged"] = "Ranged",
    ["Relic"] = "Relic",
    ["Held In Off-hand"] = "HeldInOffhand",
    ["Shirt"] = "Shirt",
    ["Tabard"] = "Tabard",
}

-- Armor type strings
local ARMOR_TYPES = {
    ["Plate"] = true,
    ["Mail"] = true,
    ["Leather"] = true,
    ["Cloth"] = true,
    ["Shield"] = true,
}

-- Weapon subtype strings
local WEAPON_TYPES = {
    ["Sword"] = true,
    ["Mace"] = true,
    ["Axe"] = true,
    ["Dagger"] = true,
    ["Staff"] = true,
    ["Polearm"] = true,
    ["Fist Weapon"] = true,
    ["Gun"] = true,
    ["Bow"] = true,
    ["Crossbow"] = true,
    ["Wand"] = true,
    ["Thrown"] = true,
}

-- ============================================================================
-- EQUIP EFFECT PARSERS
-- ============================================================================

-- Each entry: { pattern, stat_key }
-- Applied to text after "Equip: " prefix
local EQUIP_PATTERNS = {
    { "damage and healing done by magical spells and effects by up to (%d+)", "spellPower" },
    { "healing done by spells and effects by up to (%d+)", "healingPower" },
    { "chance to hit by (%d+)%%", "hitChance" },
    { "chance to get a critical strike by (%d+)%%", "critChance" },
    { "Restores (%d+) mana per 5 sec", "mp5" },
    { "Restores (%d+) health per 5 sec", "hp5" },
    { "Increases defense by (%d+)", "defenseBonus" },
    { "chance to dodge an attack by (%d+)%%", "dodgeChance" },
    { "chance to parry an attack by (%d+)%%", "parryChance" },
    { "chance to block attacks with a shield by (%d+)%%", "blockChance" },
    { "Increases your attack power by (%d+)", "attackPower" },
    { "%+(%d+) Attack Power", "attackPower" },
    { "ranged attack power by (%d+)", "rangedAttackPower" },
    { "%+(%d+) Ranged Attack Power", "rangedAttackPower" },
}

-- ============================================================================
-- TOOLTIP PARSER
-- ============================================================================

-- Get text from a tooltip line
local function GetTooltipLine(lineNum)
    local fontString = getglobal("GearSyncScanTooltipTextLeft" .. lineNum)
    if fontString then
        return fontString:GetText()
    end
    return nil
end

-- Get text from the right side of a tooltip line
local function GetTooltipLineRight(lineNum)
    local fontString = getglobal("GearSyncScanTooltipTextRight" .. lineNum)
    if fontString then
        return fontString:GetText()
    end
    return nil
end

-- Parse a single tooltip line for stats
local function ParseLine(line, result)
    if not line or line == "" then return end

    -- Bind type
    if line == "Binds when picked up" then
        result.bindType = "pickup"
        return
    elseif line == "Binds when equipped" then
        result.bindType = "equip"
        return
    elseif line == "Binds when used" then
        result.bindType = "use"
        return
    end

    -- Unique
    if line == "Unique" or line == "Unique-Equipped" then
        result.unique = true
        return
    end

    -- Required level
    local _, _, reqLevel = string.find(line, "^Requires Level (%d+)")
    if reqLevel then
        result.requiredLevel = tonumber(reqLevel)
        return
    end

    -- Classes restriction
    local _, _, classes = string.find(line, "^Classes: (.+)")
    if classes then
        result.classes = classes
        return
    end

    -- Set name: "SetName (X/Y)"
    local _, _, setName = string.find(line, "^(.+) %(%d+/%d+%)")
    if setName then
        result.setName = setName
        return
    end

    -- Armor value: "125 Armor"
    local _, _, armorVal = string.find(line, "^(%d+) Armor$")
    if armorVal then
        result.stats.armor = tonumber(armorVal)
        return
    end

    -- Basic stats: "+15 Stamina", "+8 Agility"
    local _, _, statVal, statName = string.find(line, "^%+(%d+) (.+)$")
    if statVal and statName then
        local key = STAT_MAP[statName]
        if key then
            result.stats[key] = tonumber(statVal)
            return
        end
    end

    -- Negative stats: "-10 Spirit" (rare but exists on some items)
    local _, _, negVal, negName = string.find(line, "^%-(%d+) (.+)$")
    if negVal and negName then
        local key = STAT_MAP[negName]
        if key then
            result.stats[key] = -tonumber(negVal)
            return
        end
    end

    -- Equip effects: "Equip: ..."
    local _, _, equipText = string.find(line, "^Equip: (.+)")
    if equipText then
        -- Store raw equip text
        table.insert(result.equip, equipText)

        -- Try to extract parsed values
        for i = 1, table.getn(EQUIP_PATTERNS) do
            local pattern = EQUIP_PATTERNS[i][1]
            local statKey = EQUIP_PATTERNS[i][2]
            local _, _, val = string.find(equipText, pattern)
            if val then
                result.stats[statKey] = tonumber(val)
            end
        end
        return
    end

    -- Weapon damage: "89 - 165 Damage"
    local _, _, dmgMin, dmgMax = string.find(line, "^(%d+) %- (%d+) Damage$")
    if dmgMin and dmgMax then
        result.weaponDamageMin = tonumber(dmgMin)
        result.weaponDamageMax = tonumber(dmgMax)
        return
    end

    -- Weapon speed: "Speed 2.70"
    local _, _, speed = string.find(line, "^Speed (.+)$")
    if speed then
        result.weaponSpeed = tonumber(speed)
        return
    end

    -- DPS: "(24.5 damage per second)"
    local _, _, dps = string.find(line, "%((.+) damage per second%)")
    if dps then
        result.dps = tonumber(dps)
        return
    end

    -- Equip slot (check left-side text)
    if EQUIP_SLOTS[line] then
        result.equipSlot = EQUIP_SLOTS[line]
        return
    end

    -- Armor type (only for actual armor slots, not weapons/accessories/relics)
    if ARMOR_TYPES[line] and not result.weaponType then
        local slot = result.equipSlot
        if slot ~= "Neck" and slot ~= "Finger" and slot ~= "Trinket" and slot ~= "Relic" and slot ~= "HeldInOffhand" then
            result.armorType = line
            return
        end
    end

    -- Weapon type (only if we haven't already found an armor type)
    if WEAPON_TYPES[line] then
        result.weaponType = line
        -- Clear armorType if it was set (weapon tooltip may have had a misleading line earlier)
        result.armorType = nil
        return
    end
end

-- ============================================================================
-- PUBLIC API
-- ============================================================================

-- Parse an item link and return full stat data
-- Returns nil if item is not cached (caller should retry)
function GearSync_ParseItemTooltip(itemLink)
    if not itemLink then return nil end

    -- Extract the "item:ID:X:X:X" portion from the full link
    -- SetHyperlink expects just the hyperlink, not the full colored string
    local _, _, hyperlink = string.find(itemLink, "|H(item:%d+:%d+:%d+:%d+)|h")
    if not hyperlink then return nil end

    -- Clear and populate the hidden tooltip
    local tooltip = GetScanTooltip()
    tooltip:ClearLines()
    tooltip:SetHyperlink(hyperlink)

    -- Check if tooltip was populated (line 1 should have item name)
    local line1 = GetTooltipLine(1)
    if not line1 or line1 == "" then
        return nil  -- Item not cached
    end

    local result = {
        name = line1,
        bindType = nil,
        unique = nil,
        equipSlot = nil,
        armorType = nil,
        weaponType = nil,
        requiredLevel = nil,
        classes = nil,
        setName = nil,
        weaponDamageMin = nil,
        weaponDamageMax = nil,
        weaponSpeed = nil,
        dps = nil,
        stats = {},
        equip = {},
    }

    -- Iterate through tooltip lines (up to 30)
    for i = 2, 30 do
        local line = GetTooltipLine(i)
        if not line then break end

        ParseLine(line, result)

        -- Also check right-side text (weapon speed is sometimes on the right)
        local rightLine = GetTooltipLineRight(i)
        if rightLine and rightLine ~= "" then
            ParseLine(rightLine, result)
        end
    end

    return result
end
