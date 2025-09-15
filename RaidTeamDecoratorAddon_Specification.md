# Raid Team Decorator Addon Specification

## Overview
This document provides comprehensive specifications for creating a standalone World of Warcraft addon that displays raid team information in chat messages. The addon will integrate with the Guild Roster Manager (GRM) addon's public API to extract raid team data and display it in colored format after each chat message.

## Core Functionality
The addon will:
1. Extract raid team information from GRM's custom notes system
2. Cache raid team data for efficient lookup
3. Hook into chat message events to modify message display
4. Display colored raid team tags before chat messages
5. Support alt group propagation of raid team information

## Technical Architecture

### 1. Data Source Integration
The addon will use GRM's public API to access guild member data:

**Primary API Functions:**
- `GRM_API.GetMember(name, guild)` - Returns complete member data including custom notes
- `GRM_API.IsGuildMember(name, guild)` - Validates guild membership
- `GRM_API.GetMemberAlts(name, guild)` - Gets alt information for alt group propagation

**Data Structure:**
```lua
-- GRM member data structure (relevant fields)
member = {
    customNote = {
        [1] = syncEnabled,      -- boolean
        [2] = timestamp,        -- number (epoch)
        [3] = editedBy,         -- string (player name)
        [4] = noteText          -- string (contains raid team info)
    },
    altGroup = "groupName",     -- string (for alt group propagation)
    name = "PlayerName",        -- string
    -- ... other fields
}
```

### 2. Raid Team Parsing Logic

**Pattern Recognition:**
The addon must parse raid team information from the custom note text using these patterns:
- `RT1`, `RT2`, `RT3`, etc. (case insensitive)
- `raid team 1`, `raid team 2`, `raid team 3`, etc. (case insensitive)

**Parsing Function:**
```lua
function ParseRaidTeamsFromNote(note)
    if not note or note == "" then
        return {}
    end
    
    local raidTeams = {}
    local lowerNote = string.lower(note)
    
    -- Pattern to match RT1, RT2, etc.
    local rtPattern = "rt(%d+)"
    local raidTeamPattern = "raid%s+team%s+(%d+)"
    
    -- Find RT1, RT2, etc. patterns
    for rt in string.gmatch(lowerNote, rtPattern) do
        local rtNum = tonumber(rt)
        if rtNum and rtNum > 0 then
            table.insert(raidTeams, "RT" .. rtNum)
        end
    end
    
    -- Find "raid team 1", "raid team 2", etc. patterns
    for teamNum in string.gmatch(lowerNote, raidTeamPattern) do
        local teamNumber = tonumber(teamNum)
        if teamNumber and teamNumber > 0 then
            local rtString = "RT" .. teamNumber
            -- Avoid duplicates
            local found = false
            for _, existing in ipairs(raidTeams) do
                if existing == rtString then
                    found = true
                    break
                end
            end
            if not found then
                table.insert(raidTeams, rtString)
            end
        end
    end
    
    return raidTeams
end
```

### 3. Color System

**Raid Team Colors (Colorblind-Friendly):**
```lua
local raidTeamColors = {
    ["RT1"] = "|cffFF8C00",  -- Dark Orange (high contrast, distinguishable from red/green)
    ["RT2"] = "|cff4169E1",  -- Royal Blue (distinct from other blues)
    ["RT3"] = "|cff8A2BE2",  -- Blue Violet (purple-blue, high contrast)
    ["RT4"] = "|cffFFD700",  -- Gold (bright yellow, distinguishable)
    ["RT5"] = "|cff00CED1",  -- Dark Turquoise (teal, distinct from green)
    ["RT6"] = "|cffFF1493",  -- Deep Pink (magenta, distinct from red)
    ["RT7"] = "|cff32CD32",  -- Lime Green (bright green, distinguishable)
    ["RT8"] = "|cffFF4500",  -- Orange Red (orange-red, distinct from pure red)
    ["RT9"] = "|cff9370DB",  -- Medium Purple (purple, distinct from blue)
    ["RT10"] = "|cff20B2AA", -- Light Sea Green (teal-green, distinct from other greens)
}
```

*Note: This color palette has been specifically designed to be accessible for users with common forms of color blindness (deuteranopia, protanopia, and tritanopia). The colors avoid red-green combinations and use high-contrast alternatives that remain distinguishable across different types of color vision.*

**Color Application Function:**
```lua
function GetColoredRaidTeam(teamString)
    if not teamString then
        return ""
    end
    
    local color = raidTeamColors[teamString] or "|cffFFFFFF"
    return color .. teamString .. "|r"
end
```

### 4. Caching System

**Cache Structure:**
```lua
-- Global cache for raid team data
RaidTeamCache = {
    ["PlayerName-Server"] = {"RT1", "RT3"},  -- Array of raid teams
    -- ... more players
}
```

**Cache Building Logic:**
1. Clear existing cache
2. Iterate through all guild members using GRM API
3. Parse custom notes for raid team information
4. Handle alt group propagation (if player is in alt group, inherit raid teams from all alts)
5. Store in cache for fast lookup

**Alt Group Propagation:**
- If a player is in an alt group, collect raid teams from all members of that group
- Merge raid teams from all alts, avoiding duplicates
- Apply merged raid teams to all members of the alt group

### 5. Chat Message Integration

**Event Hooking:**
The addon must hook into these chat events:
- `CHAT_MSG_GUILD`
- `CHAT_MSG_OFFICER`
- `CHAT_MSG_PARTY`
- `CHAT_MSG_PARTY_LEADER`
- `CHAT_MSG_RAID`
- `CHAT_MSG_RAID_LEADER`
- `CHAT_MSG_INSTANCE_CHAT`
- `CHAT_MSG_INSTANCE_CHAT_LEADER`
- `CHAT_MSG_WHISPER`

**Message Filter Function:**
```lua
function ChatMessageFilter(self, event, msg, sender, ...)
    if not IsInGuild() or not GRM_API then
        return false, msg, sender, ...
    end
    
    -- Don't modify own messages
    if sender == UnitName("player") then
        return false, msg, sender, ...
    end
    
    -- Get raid teams for sender
    local raidTeams = GetPlayerRaidTeams(sender)
    
    if #raidTeams > 0 then
        -- Create colored raid team prefix
        local coloredTeams = {}
        for _, team in ipairs(raidTeams) do
            table.insert(coloredTeams, GetColoredRaidTeam(team))
        end
        local raidTeamPrefix = "[" .. table.concat(coloredTeams, ",") .. "]: "
        
        -- Prepend to message
        msg = raidTeamPrefix .. msg
    end
    
    return false, msg, sender, ...
end
```

### 6. Cache Management

**Cache Refresh Triggers:**
- Guild roster updates
- Player login/logout events
- Custom note changes (if detectable)
- Manual refresh command

**Cache Refresh Function:**
```lua
function RefreshRaidTeamCache()
    if not IsInGuild() then
        return
    end
    
    -- Clear existing cache
    for k in pairs(RaidTeamCache) do
        RaidTeamCache[k] = nil
    end
    
    -- Get guild data from GRM
    local guildData = GRM_API.GetGuild() -- This may need to be implemented differently
    if not guildData then
        return
    end
    
    -- Process each player
    for playerName, player in pairs(guildData) do
        if type(player) == "table" and player.customNote and player.customNote[4] then
            local raidTeams = ParseRaidTeamsFromNote(player.customNote[4])
            
            if #raidTeams > 0 then
                RaidTeamCache[playerName] = raidTeams
            end
            
            -- Handle alt group propagation
            if player.altGroup and player.altGroup ~= "" then
                -- Implementation for alt group handling
                -- (This requires access to GRM's alt group system)
            end
        end
    end
end
```

## Addon Structure

### File Organization
```
RaidTeamDecorator/
├── RaidTeamDecorator.toc          -- Addon metadata
├── RaidTeamDecorator.lua          -- Main addon logic
├── RaidTeamDecorator_Config.lua   -- Configuration options
└── README.md                 -- User documentation
```

### TOC File Content
```lua
## Interface: 11403
## Title: Raid Team Decorator
## Notes: Displays raid team information in chat messages
## Author: YourName
## Version: 1.0.0
## Dependencies: Guild_Roster_Manager
## OptionalDeps: Guild_Roster_Manager

RaidTeamDecorator.lua
RaidTeamDecorator_Config.lua
```

### Configuration Options
```lua
-- Default settings
local defaults = {
    enabled = true,
    showInGuild = true,
    showInOfficer = true,
    showInParty = true,
    showInRaid = true,
    showInWhisper = false,
    showInInstance = true,
    refreshInterval = 30,  -- seconds
    debugMode = false
}
```

## Integration Points

### GRM API Dependencies
The addon relies on these GRM functions:
- `GRM_API.GetMember(name, guild)` - Primary data source
- `GRM_API.IsGuildMember(name, guild)` - Validation
- `GRM_API.GetMemberAlts(name, guild)` - Alt group support

### Event Dependencies
- `GUILD_ROSTER_UPDATE` - Trigger cache refresh
- `PLAYER_LOGIN` - Initialize addon
- `ADDON_LOADED` - Check for GRM availability

### Error Handling
- Graceful degradation if GRM is not available
- Validation of API responses
- Fallback behavior for missing data

## Performance Considerations

### Optimization Strategies
1. **Caching**: Store raid team data in memory to avoid repeated API calls
2. **Throttling**: Limit cache refresh frequency
3. **Selective Updates**: Only refresh cache when necessary
4. **Efficient Parsing**: Use optimized string matching patterns

### Memory Management
- Clear cache on guild changes
- Limit cache size for large guilds
- Garbage collection optimization

## User Interface

### Settings Panel
- Enable/disable per chat channel
- Refresh interval configuration
- Debug mode toggle
- Manual cache refresh button

### Commands
- `/rtd refresh` - Manual cache refresh
- `/rtd status` - Show current status
- `/rtd config` - Open settings panel

## Testing Requirements

### Test Scenarios
1. **Basic Functionality**
   - Raid team parsing from various note formats
   - Color application
   - Chat message modification

2. **Edge Cases**
   - Players with no raid teams
   - Invalid raid team numbers
   - Very long custom notes
   - Special characters in notes

3. **Integration Testing**
   - GRM API availability
   - Chat event handling
   - Cache refresh timing

4. **Performance Testing**
   - Large guild rosters
   - Frequent roster updates
   - Memory usage monitoring

## Deployment Considerations

### Version Compatibility
- Target WoW Classic Era (Interface 11403)
- Compatible with GRM versions that include the public API
- Backward compatibility considerations

### Distribution
- Standalone addon package
- Clear documentation of GRM dependency
- Installation instructions

## Future Enhancements

### Potential Features
1. **Custom Colors**: User-defined raid team colors
2. **Additional Patterns**: Support for more raid team notation formats
3. **Raid Team Management**: UI for managing raid team assignments
4. **Statistics**: Raid team participation tracking
5. **Export/Import**: Backup and restore raid team configurations

### API Extensions
- Request additional GRM API functions if needed
- Integration with other guild management addons
- Cross-addon communication protocols

## Implementation Notes

### Development Phases
1. **Phase 1**: Basic parsing and caching
2. **Phase 2**: Chat message integration
3. **Phase 3**: Alt group support
4. **Phase 4**: Configuration UI
5. **Phase 5**: Testing and optimization

### Code Quality
- Follow WoW addon development best practices
- Comprehensive error handling
- Performance optimization
- Clean, documented code

### Documentation
- Inline code comments
- User manual
- Developer documentation
- API reference

This specification provides a complete roadmap for recreating the raid team chat feature as a standalone addon that integrates with GRM's public API while maintaining the same functionality and user experience.
