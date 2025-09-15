# Raid Team Decorator

A World of Warcraft addon that displays raid team information in chat messages by integrating with Guild Roster Manager (GRM).

## Features

- **Raid Team Display**: Shows colored raid team tags before chat messages from guild members
- **GRM Integration**: Automatically reads raid team information from GRM's custom notes
- **Alt Group Support**: Propagates raid team information across alt characters
- **Configurable Channels**: Choose which chat channels to show raid teams in
- **Settings Panel**: Easy-to-use configuration interface
- **Debug Mode**: Optional debug messages for troubleshooting
- **Slash Commands**: Quick access to settings and cache refresh

## Requirements

- World of Warcraft Classic Era (Interface 11403)
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

The addon recognizes these patterns in GRM custom notes:
- `RT1`, `RT2`, `RT3`, etc. (case insensitive)
- `raid team 1`, `raid team 2`, `raid team 3`, etc. (case insensitive)

### Raid Team Colors

- **RT1**: Dark Orange
- **RT2**: Royal Blue
- **RT3**: Blue Violet
- **RT4**: Gold
- **RT5**: Dark Turquoise
- **RT6**: Deep Pink
- **RT7**: Lime Green
- **RT8**: Orange Red
- **RT9**: Medium Purple
- **RT10**: Light Sea Green

### Slash Commands

- `/rtd` or `/raidteamdecorator` - Open settings panel
- `/rtd refresh` - Manually refresh the raid team cache
- `/rtd status` - Show current addon status
- `/rtd config` - Open settings panel

### Settings

Access settings through:
- Interface Options → AddOns → Raid Team Decorator
- Slash command `/rtd`

Available settings:
- **Enable Raid Team Chat**: Turn the feature on/off
- **Debug Mode**: Enable debug messages
- **Chat Channels**: Configure which channels show raid teams
  - Guild Chat
  - Officer Chat
  - Party Chat
  - Raid Chat
  - Whisper
  - Instance Chat
- **Refresh Cache**: Manually refresh raid team data

## How It Works

1. **Data Collection**: The addon reads custom notes from GRM for all guild members
2. **Pattern Parsing**: Extracts raid team information using regex patterns
3. **Alt Group Processing**: Merges raid teams across alt characters in the same group
4. **Caching**: Stores raid team data for fast lookup during chat
5. **Chat Filtering**: Hooks into chat events to add raid team prefixes

## Alt Group Support

If a player is in an alt group in GRM:
- The addon collects raid teams from all characters in the group
- Merges all unique raid teams together
- Applies the combined raid teams to all characters in the group

## Troubleshooting

### Addon Not Working

1. Check that Guild Roster Manager is installed and enabled
2. Verify you're in a guild
3. Enable debug mode to see diagnostic messages
4. Try manually refreshing the cache with `/rtd refresh`

### No Raid Teams Showing

1. Ensure raid team information is properly formatted in GRM custom notes
2. Check that the chat channel is enabled in settings
3. Verify the player is a guild member
4. Try refreshing the cache

### Debug Mode

Enable debug mode in settings to see:
- Cache refresh progress
- Raid team parsing results
- Alt group processing
- General addon status messages

## Configuration

The addon uses Ace3's configuration system and stores settings in the `RaidTeamDecoratorDB` saved variable.

### Default Settings

```lua
{
    enabled = true,
    showInGuild = true,
    showInOfficer = true,
    showInParty = true,
    showInRaid = true,
    showInWhisper = false,
    showInInstance = true,
    debugMode = false
}
```

## Performance

- **Caching**: Raid team data is cached in memory for fast lookup
- **Selective Updates**: Cache only refreshes when necessary (guild roster changes, login)
- **Efficient Parsing**: Uses optimized string matching patterns
- **Memory Management**: Cache is cleared when leaving guild

## Compatibility

- **WoW Version**: Classic Era (Interface 11403)
- **GRM Version**: Any version with public API support
- **Other Addons**: Should be compatible with most other addons

## Support

For issues or questions:
1. Enable debug mode and check for error messages
2. Use `/rtd status` to verify addon state
3. Check that GRM is working properly
4. Verify raid team format in custom notes

## Changelog

### Version 1.0.0
- Initial release
- Basic raid team parsing and display
- GRM integration
- Alt group support
- Settings panel
- Slash commands
- Debug mode

## License

This addon is provided as-is for educational and personal use.
