# Raid Team Decorator

A World of Warcraft addon that displays raid team information in chat messages and tooltips by integrating with Guild Roster Manager (GRM). Perfect for guilds that organize members into different raid teams.

## Features

- **Raid Team Display**: Shows colored raid team tags before chat messages from guild members
- **Tooltip Integration**: Displays raid team information when hovering over guild members
- **GRM Integration**: Automatically reads raid team information from GRM's custom notes
- **Alt Group Support**: Propagates raid team information across alt characters in the same group
- **Customizable Mappings**: Configure up to 10 different raid team patterns with custom colors
- **Configurable Channels**: Choose which chat channels to show raid teams in (Guild, Whisper, Raid, Party)
- **Performance Optimized**: Automatically disables tooltips in raid instances for better performance
- **Settings Panel**: Easy-to-use configuration interface with real-time updates
- **Debug Mode**: Optional debug messages for troubleshooting
- **Slash Commands**: Quick access to settings and cache refresh

## Requirements

- World of Warcraft Classic Era (Interface 11508)
- Guild Roster Manager (GRM) addon
- Ace3 libraries (included)

## Installation

1. Download the addon files
2. Extract to your `World of Warcraft\_classic_\Interface\AddOns\` directory
3. Ensure Guild Roster Manager is installed and enabled
4. Restart World of Warcraft or reload your UI (`/reload`)

## Usage

### Basic Usage

Once installed, the addon will automatically:
- Cache raid team information from GRM's custom notes on login
- Display colored raid team tags in chat messages
- Update the cache when guild roster changes

### Raid Team Format

The addon recognizes patterns in GRM custom notes (field 4). By default, it looks for:
- `st6`, `dil`, `tfs` (case insensitive, displayed as ST6, DIL, TFS)

You can customize up to 10 different raid team patterns using the settings panel. Patterns support:
- **OR Logic**: Use `|` to separate multiple patterns (e.g., `st6|team6|raid6`)
- **Case Insensitive**: All matching is case-insensitive
- **Alphanumeric Only**: Patterns can contain letters, numbers, and spaces

### Default Raid Team Colors

- **ST6**: Steel Blue
- **DIL**: Crimson  
- **TFS**: Sea Green
- **TEAM4-10**: Various colors (disabled by default)

All colors can be customized in the settings panel.

### Slash Commands

- `/rtd` or `/raidteamdecorator` - Open settings panel
- `/rtd refresh` - Manually refresh the raid team cache
- `/rtd status` - Show current addon status and cache information
- `/rtd config` or `/rtd settings` - Open settings panel
- `/rtd toggle` - Enable/disable the addon
- `/rtd debug` - Toggle debug mode

### Settings

Access settings through:
- Interface Options → AddOns → Raid Team Decorator
- Slash command `/rtd`

Available settings:
- **Enable Raid Team Decorator**: Turn the feature on/off
- **Debug Mode**: Enable debug messages for troubleshooting
- **Chat Channels**: Configure which channels show raid teams
  - Guild Chat
  - Whisper
  - Raid Chat
  - Party Chat
- **Tooltip Settings**:
  - **Enable Tooltips**: Show raid team info in tooltips
  - **Disable in Raid Zones**: Automatically disable in raid instances for performance
- **Raid Team Mappings**: Configure up to 10 custom raid team patterns
  - Enable/disable each mapping
  - Set custom tags (e.g., "ST6", "DIL")
  - Configure match patterns (e.g., "st6", "dil|team6")
  - Choose custom colors
  - Reset to defaults
- **Refresh Cache**: Manually refresh raid team data

## How It Works

1. **Data Collection**: The addon reads custom notes from GRM for all guild members
2. **Pattern Parsing**: Extracts raid team information using configurable patterns with OR logic support
3. **Alt Group Processing**: Merges raid teams across alt characters in the same GRM group
4. **Caching**: Stores raid team data for fast lookup during chat and tooltip display
5. **Chat Filtering**: Hooks into chat events to add colored raid team prefixes
6. **Tooltip Integration**: Shows raid team information when hovering over guild members
7. **Performance Optimization**: Automatically disables tooltips in raid instances

## Alt Group Support

If a player is in an alt group in GRM:
- The addon collects raid teams from all characters in the group
- Merges all unique raid teams together
- Applies the combined raid teams to all characters in the group
- This ensures consistent raid team display across all alts

## Troubleshooting

For issues or questions:
1. Enable debug mode and check for error messages
2. Use `/rtd status` to verify addon state
3. Check that GRM is working properly
4. Verify raid team format in custom notes

### No Raid Teams Showing

1. Ensure raid team information is properly formatted in GRM custom notes (st6, dil, tfs)
2. Check that the chat channel is enabled in settings
3. Verify the player is a guild member
4. Try refreshing the cache with `/rtd refresh`
5. Enable debug mode to see detailed processing information

### Custom Patterns Not Working

1. Check that the pattern uses only alphanumeric characters and spaces
2. Use `|` to separate multiple patterns (e.g., `st6|team6`)
3. Ensure the mapping is enabled in settings
4. Apply changes using the "Apply Changes" button in settings

### Performance Issues

1. Enable "Disable Tooltips in Raid Zones" for better performance in raids
2. Disable debug mode when not troubleshooting
3. Consider reducing the number of active mappings
