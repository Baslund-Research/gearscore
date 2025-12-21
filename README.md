# GearSync - TurtleLootLine WoW Addon

A Turtle WoW addon that syncs character gear data and displays upgrade recommendations from TurtleLootLine.

## Features

- ⚡ **Automatic Gear Scanning**: Scans equipped items on login and gear changes
- 💾 **SavedVariables Sync**: Saves gear data for desktop companion to sync
- 📊 **Tooltip Integration**: Shows upgrade stats directly in item tooltips
- 🎨 **Color-coded Stats**: Green for upgrades, red for downgrades
- ⌨️ **Slash Commands**: Easy manual control via /gs commands

## Installation

1. Copy the `gearscore` folder to your WoW AddOns directory:
   - Windows: `C:\Games\Turtle WoW\Interface\AddOns\`
   - macOS: `~/Applications/Turtle WoW/Interface/AddOns/`

2. Rename the folder to `GearSync` (or keep as `gearscore`)

3. Install the TurtleLootLine Desktop Companion app

4. Launch WoW and enable the addon

## Usage

### Automatic Scanning

The addon automatically scans your equipment:
- When you log in
- When you equip/unequip items
- When your inventory changes

Data is saved to `SavedVariables/GearSync.lua` which the companion app reads.

### Slash Commands

- `/gs` or `/gearsync` - Base command
- `/gs scan` - Manually scan and save gear
- `/gs stats` - Show addon statistics
- `/gs upgrades` - List items with upgrade data
- `/gs clear` - Clear saved data
- `/gs help` - Show command help

### Tooltip Display

Hover over any item to see upgrade recommendations:

```
┌────────────────────────────────────┐
│ Lionheart Helm                     │
│ ...                                │
│                                    │
│ ⚔ TurtleLootLine:                  │
│   Stamina: +15                     │
│   Armor: +120                      │
│   Defense: -2                      │
│   Overall: +8.5%                   │
│   BIS for Phase 2                  │
└────────────────────────────────────┘
```

## How It Works

1. **Addon scans gear** → Saves to `GearSync.lua` in SavedVariables
2. **Desktop companion detects change** → Parses the file
3. **Companion syncs to API** → Sends character data
4. **API returns upgrade data** → Companion receives recommendations
5. **Companion generates `UpgradeData.lua`** → Writes to addon folder
6. **Next reload/login** → Addon loads upgrade data and shows in tooltips

## File Structure

```
GearSync/
├── GearSync.toc        # Addon manifest
├── GearSync.lua        # Main addon code
├── UpgradeData.lua     # Auto-generated upgrade data
└── README.md           # This file
```

## SavedVariables Format

The addon saves data in this format:

```lua
GearSyncData = {
    lastUpdated = 1703001234,
    character = "Paleedk",
    realm = "Turtle WoW",
    class = "Paladin",
    equipment = {
        [1] = {
            slot = "Head",
            itemId = 12640,
            itemName = "Lionheart Helm",
            itemLink = "|cff1eff00|Hitem:12640:0:0:0|h[Lionheart Helm]|h|r",
        },
        -- ... more slots
    },
}
```

## Upgrade Data Format

The companion app generates `UpgradeData.lua`:

```lua
GearSyncUpgrades = {
    [12640] = {
        stamina = "+15",
        armor = "+120",
        defense = "-2",
        overall = "+8.5%",
        note = "BIS for Phase 2",
    },
    -- ... more items
}
```

## Troubleshooting

### No upgrade data showing in tooltips

1. Check that desktop companion is running
2. Check that companion has synced (green status in tray)
3. Do a `/reload` in WoW to load latest `UpgradeData.lua`
4. Type `/gs upgrades` to see if data is loaded

### Gear not syncing

1. Type `/gs scan` to manually trigger a scan
2. Check companion app is watching the correct WoW folder
3. Logout/reload to ensure SavedVariables are written

### Addon not loading

1. Check folder name is correct (should be in `Interface/AddOns/GearSync/`)
2. Check `.toc` file exists and is named `GearSync.toc`
3. Enable addon in character selection screen

## Requirements

- Turtle WoW (1.12 client)
- TurtleLootLine Desktop Companion app
- TurtleLootLine account with sync token

## Version

- Current version: 1.0.0
- Compatible with Interface: 11200 (WoW 1.12)

## Author

Ronni

## License

MIT
