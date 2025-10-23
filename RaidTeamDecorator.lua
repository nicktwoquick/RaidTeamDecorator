-- RaidTeamDecorator - Displays raid team information in chat messages and tooltips
-- Integrates with Guild Roster Manager (GRM) to show raid team tags

local RaidTeamDecorator = LibStub("AceAddon-3.0"):NewAddon("RaidTeamDecorator", "AceConsole-3.0", "AceEvent-3.0")
local AceConfig = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")


-- Default raid team mappings (10 total)
local defaultMappings = {
    {tag = "ST6", pattern = "st6", color = "|cff4682B4", enabled = true},
    {tag = "DIL", pattern = "dil", color = "|cffDC143C", enabled = true},
    {tag = "TFS", pattern = "tfs", color = "|cff2E8B57", enabled = true},
    {tag = "TEAM4", pattern = "team4", color = "|cffFF8C00", enabled = false},
    {tag = "TEAM5", pattern = "team5", color = "|cff9370DB", enabled = false},
    {tag = "TEAM6", pattern = "team6", color = "|cff20B2AA", enabled = false},
    {tag = "TEAM7", pattern = "team7", color = "|cffFF6347", enabled = false},
    {tag = "TEAM8", pattern = "team8", color = "|cff32CD32", enabled = false},
    {tag = "TEAM9", pattern = "team9", color = "|cffFFD700", enabled = false},
    {tag = "TEAM10", pattern = "team10", color = "|cffFF69B4", enabled = false}
}


-- Default settings
local defaults = {
    enabled = true,
    showInGuild = true,
    showInWhisper = true,
    showInRaid = true,
    showInParty = true,
    debugMode = false,
    -- Tooltip settings
    enableTooltips = true,
    -- Performance settings
    disableInRaidZones = true,
    -- Mapping overrides (user customizations)
    mappingOverrides = {}
}

-- Global cache for raid team data
RaidTeamCache = {}

-- Flag to prevent multiple simultaneous UpdateChatHooks calls
local updatingChatHooks = false

-- Flag to prevent multiple cache refreshes
local cacheRefreshInProgress = false

-- Flag to track if cache has been initialized
local cacheInitialized = false

-- Store filter function references for proper cleanup
local chatFilterFunctions = {}

-- Store tooltip hook references for proper cleanup
local tooltipHooks = {}

-- Configuration options
local options = {
    name = "Raid Team Decorator",
    handler = RaidTeamDecorator,
    type = "group",
    args = {
        enabled = {
            type = "toggle",
            name = "Enable Raid Team Decorator",
            desc = "Turn raid team chat decoration on or off",
            get = function() return RaidTeamDecorator.db.profile.enabled end,
            set = function(info, value)
                RaidTeamDecorator.db.profile.enabled = value
                RaidTeamDecorator:UpdateChatHooks()
            end,
            order = 1,
        },
        debugMode = {
            type = "toggle",
            name = "Debug Mode",
            desc = "Enable debug messages",
            get = function() return RaidTeamDecorator.db.profile.debugMode end,
            set = function(info, value)
                RaidTeamDecorator.db.profile.debugMode = value
            end,
            order = 2,
        },
        channels = {
            type = "group",
            name = "Chat Channels",
            desc = "Configure which chat channels to show raid teams in",
            order = 3,
            args = {
                showInGuild = {
                    type = "toggle",
                    name = "Guild Chat",
                    desc = "Show raid teams in guild chat",
                    get = function() return RaidTeamDecorator.db.profile.showInGuild end,
                    set = function(info, value)
                        RaidTeamDecorator.db.profile.showInGuild = value
                    end,
                    order = 1,
                },
                showInWhisper = {
                    type = "toggle",
                    name = "Whisper",
                    desc = "Show raid teams in whisper messages",
                    get = function() return RaidTeamDecorator.db.profile.showInWhisper end,
                    set = function(info, value)
                        RaidTeamDecorator.db.profile.showInWhisper = value
                    end,
                    order = 2,
                },
                showInRaid = {
                    type = "toggle",
                    name = "Raid Chat",
                    desc = "Show raid teams in raid chat",
                    get = function() return RaidTeamDecorator.db.profile.showInRaid end,
                    set = function(info, value)
                        RaidTeamDecorator.db.profile.showInRaid = value
                    end,
                    order = 3,
                },
                showInParty = {
                    type = "toggle",
                    name = "Party Chat",
                    desc = "Show raid teams in party chat",
                    get = function() return RaidTeamDecorator.db.profile.showInParty end,
                    set = function(info, value)
                        RaidTeamDecorator.db.profile.showInParty = value
                    end,
                    order = 4,
                },
            },
        },
        tooltips = {
            type = "group",
            name = "Tooltip Settings",
            desc = "Configure tooltip display options",
            order = 4,
            args = {
                enableTooltips = {
                    type = "toggle",
                    name = "Enable Tooltips",
                    desc = "Show raid team information in tooltips when hovering over guild members",
                    get = function() return RaidTeamDecorator.db.profile.enableTooltips end,
                    set = function(info, value)
                        RaidTeamDecorator.db.profile.enableTooltips = value
                        -- Show reload dialog since HookScript hooks can't be removed dynamically
                        StaticPopup_Show("RAIDTEAMDECORATOR_RELOAD")
                    end,
                    order = 1,
                },
                disableInRaidZones = {
                    type = "toggle",
                    name = "Disable Tooltips in Raid Zones",
                    desc = "Automatically disable tooltips when in raid instances to improve performance",
                    get = function() return RaidTeamDecorator.db.profile.disableInRaidZones end,
                    set = function(info, value)
                        RaidTeamDecorator.db.profile.disableInRaidZones = value
                    end,
                    order = 2,
                },
            },
        },
        refresh = {
            type = "execute",
            name = "Refresh Cache",
            desc = "Manually refresh the raid team cache",
            func = function()
                RaidTeamDecorator:RefreshRaidTeamCache(true)
                RaidTeamDecorator:Print("Raid team cache refreshed!")
            end,
            order = 5,
        },
        mappings = {
            type = "group",
            name = "Raid Team Mappings",
            desc = "Configure custom raid team mappings",
            order = 6,
            args = {
                applyChanges = {
                    type = "execute",
                    name = "Apply Changes",
                    desc = "Save all mapping changes and refresh cache",
                    func = function()
                        RaidTeamDecorator:ApplyMappingChanges()
                    end,
                    order = 1,
                },
            },
        },
    },
}

function RaidTeamDecorator:BuildMappingOptions()
    -- Dynamically build mapping configuration options for all 10 mappings
    local mappingArgs = options.args.mappings.args
    
    for i = 1, 10 do
        local mapping = self:GetMappingConfig(i)
        if mapping then
            -- Create a group for each mapping
            mappingArgs["mapping" .. i] = {
                type = "group",
                name = "Mapping " .. i .. ": " .. mapping.tag,
                order = i + 1,
                inline = true,
                args = {
                    enabled = {
                        type = "toggle",
                        name = "Enabled",
                        desc = "Enable or disable this mapping",
                        get = function() 
                            local cfg = RaidTeamDecorator:GetMappingConfig(i)
                            return cfg and cfg.enabled or false
                        end,
                        set = function(info, value)
                            RaidTeamDecorator:SaveMappingOverride(i, "enabled", value)
                        end,
                        order = 1,
                    },
                    tag = {
                        type = "input",
                        name = "Tag",
                        desc = "The tag to display in chat (e.g., ST6, DIL)",
                        get = function()
                            local cfg = RaidTeamDecorator:GetMappingConfig(i)
                            return cfg and cfg.tag or ""
                        end,
                        set = function(info, value)
                            RaidTeamDecorator:SaveMappingOverride(i, "tag", value)
                        end,
                        order = 2,
                    },
                    pattern = {
                        type = "input",
                        name = "Pattern",
                        desc = "Match pattern (alphanumeric and spaces only, use | to separate multiple patterns)",
                        get = function()
                            local cfg = RaidTeamDecorator:GetMappingConfig(i)
                            return cfg and cfg.pattern or ""
                        end,
                        set = function(info, value)
                            local isValid, errorMsg = RaidTeamDecorator:ValidatePattern(value)
                            if not isValid then
                                RaidTeamDecorator:Print("|cffFF0000Error:|r " .. errorMsg)
                                return
                            end
                            RaidTeamDecorator:SaveMappingOverride(i, "pattern", value)
                        end,
                        order = 3,
                    },
                    color = {
                        type = "color",
                        name = "Color",
                        desc = "Choose the color for this raid team tag",
                        hasAlpha = false,
                        get = function()
                            local cfg = RaidTeamDecorator:GetMappingConfig(i)
                            if cfg and cfg.color then
                                -- Convert hex color to RGB (0-1 range)
                                local hex = cfg.color:match("|cff(%x%x%x%x%x%x)")
                                if hex then
                                    local r = tonumber(hex:sub(1,2), 16) / 255
                                    local g = tonumber(hex:sub(3,4), 16) / 255
                                    local b = tonumber(hex:sub(5,6), 16) / 255
                                    return r, g, b
                                end
                            end
                            return 1, 1, 1 -- Default white
                        end,
                        set = function(info, r, g, b)
                            -- Convert RGB (0-1 range) to hex color
                            local hex = string.format("|cff%02x%02x%02x", r*255, g*255, b*255)
                            RaidTeamDecorator:SaveMappingOverride(i, "color", hex)
                        end,
                        order = 4,
                    },
                    reset = {
                        type = "execute",
                        name = "Reset to Default",
                        desc = "Reset this mapping to default values",
                        func = function()
                            RaidTeamDecorator:ResetMapping(i)
                            RaidTeamDecorator:Print("Mapping " .. i .. " reset to default")
                        end,
                        order = 5,
                    },
                },
            }
        end
    end
end

function RaidTeamDecorator:OnInitialize()
    -- Initialize database
    self.db = LibStub("AceDB-3.0"):New("RaidTeamDecoratorDB", {profile = defaults}, true)
    
    -- Build mapping options dynamically
    self:BuildMappingOptions()
    
    -- Register configuration
    AceConfig:RegisterOptionsTable("RaidTeamDecorator", options)
    AceConfigDialog:AddToBlizOptions("RaidTeamDecorator", "Raid Team Decorator")
    
    -- Register slash commands
    self:RegisterChatCommand("rtd", "SlashCommand")
    self:RegisterChatCommand("raidteamdecorator", "SlashCommand")
    
    -- Define custom reload dialog
    StaticPopupDialogs["RAIDTEAMDECORATOR_RELOAD"] = {
        text = "Changing the tooltip setting requires a UI reload. Do you want to reload now?",
        button1 = "Yes",
        button2 = "No",
        OnAccept = function()
            ReloadUI()
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }
end

function RaidTeamDecorator:OnEnable()
    self:RegisterEvent("ADDON_LOADED", "OnAddonLoaded")
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnPlayerEnteringWorld")
    
    -- Initialize GRM if already loaded
    if IsAddOnLoaded("Guild_Roster_Manager") then
        self:InitializeGRM()
    end
    
    -- Set up chat hooks if enabled
    if self.db.profile.enabled then
        self:UpdateChatHooks()
    end
    
    -- Set up tooltip hooks if enabled
    if self.db.profile.enableTooltips then
        self:UpdateTooltipHooks()
    end
end

function RaidTeamDecorator:OnDisable()
    self:UnregisterAllEvents()
    self:UnhookAll()
end

function RaidTeamDecorator:UnhookAll()
    -- Remove all chat filters using stored function references
    for filter, filterFunc in pairs(chatFilterFunctions) do
        ChatFrame_RemoveMessageEventFilter(filter, filterFunc)
    end
    
    -- Clear the stored functions
    chatFilterFunctions = {}
end

function RaidTeamDecorator:OnAddonLoaded(event, addonName)
    if addonName == "Guild_Roster_Manager" then
        self:InitializeGRM()
    end
end

function RaidTeamDecorator:OnPlayerEnteringWorld()
    -- Only initialize cache on first world entry, not every zone change
    if not cacheInitialized then
        self:ScheduleCacheRefresh()
    end
end

function RaidTeamDecorator:ScheduleCacheRefresh()
    -- Check if cache refresh is already in progress
    if cacheRefreshInProgress then
        return
    end
    
    if self.db.profile.enabled then
        self:UpdateChatHooks()
        
        -- Schedule initial cache refresh after a delay using frame
        local frame = CreateFrame("Frame")
        frame:SetScript("OnUpdate", function(frame, elapsed)
            frame.timer = (frame.timer or 0) + elapsed
            if frame.timer >= 2 then
                frame:SetScript("OnUpdate", nil)
                RaidTeamDecorator:DelayedInitialRefresh()
                frame:Hide()
            end
        end)
    end
end

function RaidTeamDecorator:DelayedInitialRefresh()
    -- Check if cache refresh is already in progress
    if cacheRefreshInProgress then
        return
    end
    
    if not self.db.profile.enabled then
        return
    end
    
    -- Check if GRM is loaded and API is available
    if not IsAddOnLoaded("Guild_Roster_Manager") then
        return
    end
    
    if not GRM_API or not GRM_API.GetMember then
        return
    end
    
    -- Set flag to prevent duplicate refreshes
    cacheRefreshInProgress = true
    
    self:RefreshRaidTeamCache(false)
    
    -- Clear flag when done
    cacheRefreshInProgress = false
end

function RaidTeamDecorator:InitializeGRM()
    if not GRM_API then
        self:Print("Guild Roster Manager not found or API not available")
        return false
    end
    
    self:Print("RaidTeamDecorator: Guild Roster Manager loaded successfully")
    return true
end

function RaidTeamDecorator:SlashCommand(input)
    if not input or input == "" then
        self:ShowSettings()
        return
    end
    
    local command = string.lower(input)
    
    if command == "refresh" then
        self:RefreshRaidTeamCache(true)
        self:Print("Raid team cache refreshed!")
    elseif command == "status" then
        self:PrintStatus()
    elseif command == "config" or command == "settings" then
        self:ShowSettings()
    elseif command == "toggle" then
        self.db.profile.enabled = not self.db.profile.enabled
        self:UpdateChatHooks()
        self:Print("Raid Team Decorator " .. (self.db.profile.enabled and "enabled" or "disabled"))
    elseif command == "debug" then
        self.db.profile.debugMode = not self.db.profile.debugMode
        self:Print("Debug mode " .. (self.db.profile.debugMode and "enabled" or "disabled"))
    else
        self:Print("Usage: /rtd [refresh|status|config|toggle|debug]")
    end
end

function RaidTeamDecorator:ShowSettings()
    if Settings and Settings.OpenToCategory then
        Settings.OpenToCategory("Raid Team Decorator")
    else
        -- Fallback for older versions
        InterfaceOptionsFrame_OpenToCategory("Raid Team Decorator")
    end
end

function RaidTeamDecorator:PrintStatus()
    local status = self.db.profile.enabled and "Enabled" or "Disabled"
    self:Print("Raid Team Decorator: " .. status)
    self:Print("Debug Mode: " .. (self.db.profile.debugMode and "On" or "Off"))
    self:Print("Tooltips: " .. (self.db.profile.enableTooltips and "Enabled" or "Disabled"))
    self:Print("Cached Players: " .. self:GetCacheSize())
    self:Print("GRM Available: " .. (GRM_API and "Yes" or "No"))
    self:Print("In Guild: " .. (IsInGuild() and "Yes" or "No"))
    
    if GRM_API then
        self:Print("GRM Functions:")
        self:Print("  GetMember: " .. (GRM_API.GetMember and "Yes" or "No"))
        self:Print("  IsGuildMember: " .. (GRM_API.IsGuildMember and "Yes" or "No"))
        self:Print("  GetMemberAlts: " .. (GRM_API.GetMemberAlts and "Yes" or "No"))
    end
    
    if IsInGuild() then
        local guildName = GetGuildInfo("player")
        local numMembers = GetNumGuildMembers()
        self:Print("Guild: " .. (guildName or "Unknown"))
        self:Print("Members: " .. numMembers)
    end
    
    -- Show cache contents
    self:Print("Cache Contents:")
    local count = 0
    for name, teams in pairs(RaidTeamCache) do
        count = count + 1
        if count <= 10 then  -- Limit to first 10 entries
            self:Print("  '" .. name .. "': " .. table.concat(teams, ", "))
        end
    end
    if count > 10 then
        self:Print("  ... and " .. (count - 10) .. " more entries")
    end
end


function RaidTeamDecorator:GetCacheSize()
    local count = 0
    for _ in pairs(RaidTeamCache) do
        count = count + 1
    end
    return count
end

function RaidTeamDecorator:DebugPrint(message)
    if self.db.profile.debugMode then
        self:Print("|cff00FF00[DEBUG]|r " .. message)
    end
end

-- Mapping helper functions
function RaidTeamDecorator:GetMappingConfig(index)
    if not index or index < 1 or index > 10 then
        return nil
    end
    
    local default = defaultMappings[index]
    if not default then
        return nil
    end
    
    -- Start with default values
    local config = {
        tag = default.tag,
        pattern = default.pattern,
        color = default.color,
        enabled = default.enabled
    }
    
    -- Apply user overrides if they exist
    local overrides = self.db.profile.mappingOverrides[index]
    if overrides then
        for field, value in pairs(overrides) do
            config[field] = value
        end
    end
    
    return config
end

function RaidTeamDecorator:GetAllMappings()
    local mappings = {}
    for i = 1, 10 do
        mappings[i] = self:GetMappingConfig(i)
    end
    return mappings
end

function RaidTeamDecorator:SaveMappingOverride(index, field, value)
    if not index or index < 1 or index > 10 then
        return false
    end
    
    if not self.db.profile.mappingOverrides[index] then
        self.db.profile.mappingOverrides[index] = {}
    end
    
    self.db.profile.mappingOverrides[index][field] = value
    return true
end

function RaidTeamDecorator:ResetMapping(index)
    if not index or index < 1 or index > 10 then
        return false
    end
    
    self.db.profile.mappingOverrides[index] = nil
    return true
end

function RaidTeamDecorator:ConvertPatternToRegex(pattern)
    if not pattern or pattern == "" then
        return {}
    end
    
    -- Split by | to handle OR logic properly
    local parts = {}
    for part in string.gmatch(pattern, "([^|]+)") do
        -- Trim whitespace from each part
        part = string.gsub(part, "^%s*(.-)%s*$", "%1")
        if part ~= "" then
            -- Escape special Lua pattern characters for each part
            local escaped = string.gsub(part, "([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
            table.insert(parts, escaped)
        end
    end
    
    -- Return the parts array - we'll test each part individually
    return parts
end

function RaidTeamDecorator:ValidatePattern(pattern)
    if not pattern or pattern == "" then
        return true, ""
    end
    
    -- Only allow alphanumeric characters, spaces, and | delimiter
    local invalidChars = string.match(pattern, "[^%w%s|]")
    if invalidChars then
        return false, "Pattern contains invalid character: " .. invalidChars
    end
    
    return true, ""
end

function RaidTeamDecorator:ApplyMappingChanges()
    -- Validate all patterns before applying
    for i = 1, 10 do
        local mapping = self:GetMappingConfig(i)
        if mapping and mapping.pattern then
            local isValid, errorMsg = self:ValidatePattern(mapping.pattern)
            if not isValid then
                self:Print("|cffFF0000Error in Mapping " .. i .. ":|r " .. errorMsg)
                return
            end
        end
    end
    
    -- All validations passed, refresh the cache
    self:RefreshRaidTeamCache(true)
    self:Print("|cff00FF00Success:|r Mapping changes applied and cache refreshed!")
end

function RaidTeamDecorator:IsInRaidZone()
    local inInstance, instanceType = IsInInstance()
    return inInstance and instanceType == "raid"
end

function RaidTeamDecorator:ParseRaidTeamsFromNote(note)
    if not note or note == "" then
        return {}
    end
    
    local raidTeams = {}
    local lowerNote = string.lower(note)
    
    -- Get all active mappings
    local mappings = self:GetAllMappings()
    
    for _, mapping in ipairs(mappings) do
        if mapping and mapping.enabled and mapping.pattern and mapping.pattern ~= "" then
            -- Convert pattern to parts (for OR logic)
            local patternParts = self:ConvertPatternToRegex(mapping.pattern)
            
            
            -- Test each part against note (OR logic)
            local found = false
            for _, pattern in ipairs(patternParts) do
                if string.find(lowerNote, pattern) then
                    found = true
                    break
                end
            end
            
            if found then
                -- Check if this team is already added
                local alreadyAdded = false
                for _, existing in ipairs(raidTeams) do
                    if existing == mapping.tag then
                        alreadyAdded = true
                        break
                    end
                end
                
                if not alreadyAdded then
                    table.insert(raidTeams, mapping.tag)
                end
            end
        end
    end
    
    return raidTeams
end

function RaidTeamDecorator:GetColoredRaidTeam(teamString)
    if not teamString then
        return ""
    end
    
    -- Look up color from mapping config
    local mappings = self:GetAllMappings()
    local color = "|cffFFFFFF" -- Default to white
    
    for _, mapping in ipairs(mappings) do
        if mapping and mapping.tag == teamString then
            color = mapping.color or "|cffFFFFFF"
            break
        end
    end
    
    
    return color .. teamString .. "|r"
end

function RaidTeamDecorator:RefreshRaidTeamCache(forceRefresh)
    if not IsInGuild() then
        self:Print("|cffFF0000Error:|r You must be in a guild to use RaidTeamDecorator")
        return
    end
    
    if not GRM_API or not GRM_API.GetMember then
        self:Print("|cffFF0000Error:|r Guild Roster Manager (GRM) not found or API not available")
        return
    end
    
    -- Clear existing cache
    for k in pairs(RaidTeamCache) do
        RaidTeamCache[k] = nil
    end
    
    -- Get guild name
    local guildName = GetGuildInfo("player")
    if not guildName then
        self:Print("|cffFF0000Error:|r Could not get guild name")
        return
    end
    
    -- Process guild members
    local memberCount = 0
    local raidTeamCount = 0
    local grmMemberCount = 0
    
    -- Get all guild members
    local numMembers = GetNumGuildMembers()
    
    for i = 1, numMembers do
        local name, rank, rankIndex, level, class, zone, note, officernote, online, status, classFileName, achievementPoints, achievementRank, isMobile, canSoR, repStanding = GetGuildRosterInfo(i)
        
        if name then
            memberCount = memberCount + 1
            
            -- Get member data from GRM (no guild name needed for public API)
            local success, memberData = pcall(GRM_API.GetMember, name)
            if success and memberData then
                grmMemberCount = grmMemberCount + 1
                
                if memberData.customNote and memberData.customNote[4] then
                    local customNote = memberData.customNote[4]
                    local raidTeams = self:ParseRaidTeamsFromNote(customNote)
                    
                    if #raidTeams > 0 then
                        -- Strip server name from the player name for consistent storage
                        local playerNameOnly = string.match(name, "^([^-]+)")
                        RaidTeamCache[playerNameOnly] = raidTeams
                        raidTeamCount = raidTeamCount + 1
                    end
                end
                
                -- Handle alt group propagation
                if memberData.altGroup and memberData.altGroup ~= "" then
                    self:ProcessAltGroup(name, memberData.altGroup)
                end
            end
        end
    end
    
    -- Mark cache as initialized after successful refresh
    cacheInitialized = true
    
    if raidTeamCount == 0 then
        self:Print("|cffFFFF00Warning:|r No raid teams found. Check that:")
        self:Print("1. GRM custom notes contain raid team info (st6, dil, tfs, etc.)")
        self:Print("2. You have permission to read custom notes")
        self:Print("3. GRM is properly configured")
    else
        self:Print("RaidTeamDecorator: Cache populated with " .. raidTeamCount .. " players with raid teams")
    end
end

function RaidTeamDecorator:ProcessAltGroup(playerName, altGroup)
    if not altGroup or altGroup == "" then
        return
    end
    
    -- Check if GetMemberAlts function exists
    if not GRM_API.GetMemberAlts then
        return
    end
    
    -- Get all alts in the group
    local success, alts = pcall(GRM_API.GetMemberAlts, playerName)
    if not success then
        return
    end
    
    if not alts or #alts == 0 then
        return
    end
    
    -- Collect raid teams from all alts
    local allRaidTeams = {}
    local raidTeamSet = {}
    
    -- Add current player's raid teams
    local playerNameOnly = string.match(playerName, "^([^-]+)")
    if RaidTeamCache[playerNameOnly] then
        for _, team in ipairs(RaidTeamCache[playerNameOnly]) do
            if not raidTeamSet[team] then
                table.insert(allRaidTeams, team)
                raidTeamSet[team] = true
            end
        end
    end
    
    -- Add alt raid teams
    for _, altName in ipairs(alts) do
        local success, altData = pcall(GRM_API.GetMember, altName)
        if success and altData and altData.customNote and altData.customNote[4] then
            local altRaidTeams = self:ParseRaidTeamsFromNote(altData.customNote[4])
            for _, team in ipairs(altRaidTeams) do
                if not raidTeamSet[team] then
                    table.insert(allRaidTeams, team)
                    raidTeamSet[team] = true
                end
            end
        end
    end
    
    -- Apply merged raid teams to all alts
    if #allRaidTeams > 0 then
        -- Strip server names for consistent storage
        local playerNameOnly = string.match(playerName, "^([^-]+)")
        RaidTeamCache[playerNameOnly] = allRaidTeams
        for _, altName in ipairs(alts) do
            local altNameOnly = string.match(altName, "^([^-]+)")
            RaidTeamCache[altNameOnly] = allRaidTeams
        end
    end
end

function RaidTeamDecorator:GetPlayerRaidTeams(playerName)
    if not playerName then
        return {}
    end
    
    -- First try exact match (for names without realm)
    if RaidTeamCache[playerName] then
        return RaidTeamCache[playerName]
    end
    
    -- If not found, try stripping realm name (for names like "PlayerName-Realm")
    local playerNameOnly = string.match(playerName, "^([^-]+)")
    if playerNameOnly and playerNameOnly ~= playerName and RaidTeamCache[playerNameOnly] then
        return RaidTeamCache[playerNameOnly]
    end
    
    return {}
end

function RaidTeamDecorator:UpdateChatHooks()
    -- Prevent multiple simultaneous calls
    if updatingChatHooks then
        return
    end
    updatingChatHooks = true
    
    -- Unhook all existing hooks
    self:UnhookAll()
    
    if not self.db.profile.enabled then
        updatingChatHooks = false
        return
    end
    
    -- Hook chat filters instead of events
    local chatFilters = {
        "CHAT_MSG_GUILD",
        "CHAT_MSG_WHISPER",
        "CHAT_MSG_RAID",
        "CHAT_MSG_RAID_LEADER",
        "CHAT_MSG_PARTY",
        "CHAT_MSG_PARTY_LEADER"
    }
    
    for _, filter in ipairs(chatFilters) do
        -- Create and store the filter function
        local filterFunc = function(self, event, msg, sender, ...)
            return RaidTeamDecorator:ChatMessageFilter(event, msg, sender, ...)
        end
        
        -- Store the function reference for proper cleanup
        chatFilterFunctions[filter] = filterFunc
        
        -- Add the filter
        ChatFrame_AddMessageEventFilter(filter, filterFunc)
    end
    updatingChatHooks = false
end

function RaidTeamDecorator:UpdateTooltipHooks()
    if not self.db.profile.enableTooltips then
        return
    end
    
    -- Only hook GameTooltip using the OnTooltipSetUnit event (the only method that works)
    if GameTooltip then
        GameTooltip:HookScript("OnTooltipSetUnit", function(self, unit)
            RaidTeamDecorator:AddRaidTeamToTooltip(self, unit)
        end)
    end
end


function RaidTeamDecorator:AddRaidTeamToTooltip(tooltip, unit)
    -- If unit is nil, try to get it from the tooltip
    if not unit and tooltip and tooltip.GetUnit then
        unit = tooltip:GetUnit()
    end
    
    -- Early exit conditions
    if not IsInGuild() or not GRM_API then
        return
    end
    
    -- Check if we should disable in raid zones
    if self.db.profile.disableInRaidZones and self:IsInRaidZone() then
        return
    end
    
    if not unit then
        return
    end
    
    -- Check if this is a player using mouseover GUID (since the unit parameter is just the name)
    local mouseoverGUID = UnitGUID("mouseover")
    if mouseoverGUID then
        local unitType = strsplit("-", mouseoverGUID)
        if unitType ~= "Player" then
            -- Skip processing for NPCs
            return
        end
    else
        return
    end
    
    -- Don't show for own unit
    if UnitIsUnit(unit, "player") then
        return
    end
    
    -- Get the unit's name - try different methods
    local name = nil
    
    -- First, try standard unit tokens
    if unit == "player" then
        name = UnitName("player")
    elseif unit == "target" then
        name = UnitName("target")
    elseif unit == "mouseover" then
        name = UnitName("mouseover")
    else
        -- For other cases, try UnitName first
        name = UnitName(unit)
        
        -- If UnitName failed, the unit string might be the name directly
        if not name then
            name = unit
        end
    end
    
    if not name then
        return
    end
    
    -- Get raid teams for this player
    local raidTeams = self:GetPlayerRaidTeams(name)
    
    if #raidTeams > 0 then
        -- Add a blank line for spacing
        tooltip:AddLine(" ")
        
        -- Add raid team information with colors
        local teamText = "Raid Team: "
        for i, team in ipairs(raidTeams) do
            if i > 1 then
                teamText = teamText .. ", "
            end
            teamText = teamText .. self:GetColoredRaidTeam(team)
        end
        
        tooltip:AddLine(teamText)
    end
end

function RaidTeamDecorator:ShouldShowTooltipForUnit(unit)
    -- Check if unit is in guild
    if not UnitIsInMyGuild(unit) then
        return false
    end
    
    -- Show for guild members if tooltips are enabled
    return self.db.profile.enableTooltips
end

function RaidTeamDecorator:ChatMessageFilter(event, msg, sender, ...)
    -- Early exit conditions
    if not IsInGuild() or not GRM_API then
        return false, msg, sender, ...
    end
    
    -- Don't modify own messages
    if sender == UnitName("player") then
        return false, msg, sender, ...
    end
    
    -- Explicitly exclude public channels that should never be processed
    local excludedEvents = {
        "CHAT_MSG_CHANNEL",      -- General channels (including trade)
        "CHAT_MSG_SAY",          -- Say
        "CHAT_MSG_YELL",         -- Yell
        "CHAT_MSG_EMOTE",        -- Emote
        "CHAT_MSG_TEXT_EMOTE",   -- Text emote
        "CHAT_MSG_SYSTEM",       -- System messages
        "CHAT_MSG_LOOT",         -- Loot messages
        "CHAT_MSG_MONEY",        -- Money messages
        "CHAT_MSG_ACHIEVEMENT",  -- Achievement messages
        "CHAT_MSG_COMBAT_XP_GAIN", -- XP gain messages
        "CHAT_MSG_SKILL",        -- Skill messages
        "CHAT_MSG_OPENING",      -- Opening messages
        "CHAT_MSG_TRADESKILLS",  -- Tradeskill messages
        "CHAT_MSG_PET_INFO",     -- Pet info messages
        "CHAT_MSG_COMBAT_MISC_INFO", -- Combat misc messages
        "CHAT_MSG_COMBAT_FACTION_CHANGE", -- Faction change messages
        "CHAT_MSG_BG_SYSTEM_NEUTRAL", -- BG system messages
        "CHAT_MSG_BG_SYSTEM_ALLIANCE", -- BG system messages
        "CHAT_MSG_BG_SYSTEM_HORDE", -- BG system messages
    }
    
    for _, excludedEvent in ipairs(excludedEvents) do
        if event == excludedEvent then
            return false, msg, sender, ...
        end
    end
    
    -- Check if this channel is enabled
    local channelEnabled = false
    if event == "CHAT_MSG_GUILD" and self.db.profile.showInGuild then
        channelEnabled = true
    elseif event == "CHAT_MSG_WHISPER" and self.db.profile.showInWhisper then
        channelEnabled = true
    elseif (event == "CHAT_MSG_RAID" or event == "CHAT_MSG_RAID_LEADER") and self.db.profile.showInRaid then
        channelEnabled = true
    elseif (event == "CHAT_MSG_PARTY" or event == "CHAT_MSG_PARTY_LEADER") and self.db.profile.showInParty then
        channelEnabled = true
    end
    
    if not channelEnabled then
        return false, msg, sender, ...
    end
    
    -- Get raid teams for the sender (handles realm name stripping internally)
    local raidTeams = self:GetPlayerRaidTeams(sender)
    
    if #raidTeams > 0 then
        -- Check if message already has a raid team prefix to prevent duplicates
        local hasExistingPrefix = false
        
        -- First check for any existing RT pattern in the message
        if string.find(msg, "%[RT%d+%]:") then
            hasExistingPrefix = true
        else
            -- Also check for colored versions of the current player's teams
            for _, team in ipairs(raidTeams) do
                local coloredTeam = self:GetColoredRaidTeam(team)
                if string.find(msg, "[" .. coloredTeam .. "]:", 1, true) then
                    hasExistingPrefix = true
                    break
                end
            end
        end
        
        -- Only add prefix if it doesn't already exist
        if not hasExistingPrefix then
            -- Create colored raid team prefix
            local coloredTeams = {}
            for _, team in ipairs(raidTeams) do
                table.insert(coloredTeams, self:GetColoredRaidTeam(team))
            end
            local raidTeamPrefix = "[" .. table.concat(coloredTeams, ",") .. "]: "
            
            -- Prepend to message
            msg = raidTeamPrefix .. msg
        end
    end
    
    return false, msg, sender, ...
end
