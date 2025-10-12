-- RaidTeamDecorator - Displays raid team information in chat messages and tooltips
-- Integrates with Guild Roster Manager (GRM) to show raid team tags

local RaidTeamDecorator = LibStub("AceAddon-3.0"):NewAddon("RaidTeamDecorator", "AceConsole-3.0", "AceEvent-3.0")
local AceConfig = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")

-- Addon version
local VERSION = "0.5.1"

-- Raid team colors (colorblind-friendly palette)
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
    disableInRaidZones = true
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
    },
}

function RaidTeamDecorator:OnInitialize()
    -- Initialize database
    self.db = LibStub("AceDB-3.0"):New("RaidTeamDecoratorDB", {profile = defaults}, true)
    
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
    self:DebugPrint("=== OnEnable called ===")
    self:RegisterEvent("ADDON_LOADED", "OnAddonLoaded")
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnPlayerEnteringWorld")
    self:DebugPrint("Events registered: ADDON_LOADED, PLAYER_ENTERING_WORLD")
    
    -- Initialize GRM if already loaded
    if IsAddOnLoaded("Guild_Roster_Manager") then
        self:DebugPrint("GRM already loaded, initializing...")
        self:InitializeGRM()
    else
        self:DebugPrint("GRM not loaded yet")
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
    self:DebugPrint("Player entering world")
    -- Only initialize cache on first world entry, not every zone change
    if not cacheInitialized then
        self:DebugPrint("Cache not initialized yet, scheduling initial refresh")
        self:ScheduleCacheRefresh()
    else
        self:DebugPrint("Cache already initialized, skipping refresh")
    end
end

function RaidTeamDecorator:ScheduleCacheRefresh()
    -- Check if cache refresh is already in progress
    if cacheRefreshInProgress then
        self:DebugPrint("Cache refresh already in progress, skipping schedule")
        return
    end
    
    if self.db.profile.enabled then
        self:UpdateChatHooks()
        
        -- Schedule initial cache refresh after a delay using frame
        self:DebugPrint("Scheduling delayed cache refresh...")
        local frame = CreateFrame("Frame")
        frame:SetScript("OnUpdate", function(frame, elapsed)
            frame.timer = (frame.timer or 0) + elapsed
            if frame.timer >= 2 then
                frame:SetScript("OnUpdate", nil)
                RaidTeamDecorator:DelayedInitialRefresh()
                frame:Hide()
            end
        end)
        self:DebugPrint("Frame timer created successfully")
    else
        self:DebugPrint("Addon not enabled, skipping cache refresh")
    end
end

function RaidTeamDecorator:DelayedInitialRefresh()
    self:DebugPrint("Running delayed initial cache refresh")
    
    -- Check if cache refresh is already in progress
    if cacheRefreshInProgress then
        self:DebugPrint("Cache refresh already in progress, skipping duplicate")
        return
    end
    
    if not self.db.profile.enabled then
        self:DebugPrint("Addon not enabled, skipping cache refresh")
        return
    end
    
    -- Check if GRM is loaded and API is available
    if not IsAddOnLoaded("Guild_Roster_Manager") then
        self:DebugPrint("GRM not loaded, skipping cache refresh")
        return
    end
    self:DebugPrint("GRM addon is loaded, continuing...")
    
    if not GRM_API or not GRM_API.GetMember then
        self:DebugPrint("GRM API not available or functions not ready")
        return
    end
    
    -- Set flag to prevent duplicate refreshes
    cacheRefreshInProgress = true
    
    local success, err = pcall(function()
        self:RefreshRaidTeamCache(false)
    end)
    
    -- Clear flag when done
    cacheRefreshInProgress = false
    
    if not success then
        self:Print("|cffFF0000Error in RefreshRaidTeamCache:|r " .. tostring(err))
        self:DebugPrint("RefreshRaidTeamCache failed: " .. tostring(err))
    else
        self:DebugPrint("RefreshRaidTeamCache completed successfully")
    end
end

function RaidTeamDecorator:InitializeGRM()
    if not GRM_API then
        self:Print("Guild Roster Manager not found or API not available")
        return false
    end
    
    self:Print("RaidTeamDecorator: Guild Roster Manager loaded successfully")
    self:DebugPrint("GRM API initialized")
    return true
end

function RaidTeamDecorator:SlashCommand(input)
    local success, err = pcall(function()
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
        elseif command == "tooltips" then
            self.db.profile.enableTooltips = not self.db.profile.enableTooltips
            -- Show reload dialog since HookScript hooks can't be removed dynamically
            StaticPopup_Show("RAIDTEAMDECORATOR_RELOAD")
            self:Print("Tooltips " .. (self.db.profile.enableTooltips and "enabled" or "disabled") .. " - Reload UI to apply changes")
        else
            self:Print("Usage: /rtd [refresh|status|config|toggle|debug|tooltips]")
        end
    end)
    
    if not success then
        self:Print("|cffFF0000Error in slash command:|r " .. tostring(err))
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

function RaidTeamDecorator:GetColoredRaidTeam(teamString)
    if not teamString then
        return ""
    end
    
    local color = raidTeamColors[teamString] or "|cffFFFFFF"
    return color .. teamString .. "|r"
end

function RaidTeamDecorator:RefreshRaidTeamCache(forceRefresh)
    local isManualRefresh = forceRefresh or false
    self:DebugPrint("Starting cache refresh..." .. (isManualRefresh and " (manual refresh)" or " (automatic initialization)"))
    
    if not IsInGuild() then
        self:DebugPrint("Not in a guild, skipping cache refresh")
        self:Print("|cffFF0000Error:|r You must be in a guild to use RaidTeamDecorator")
        return
    end
    
    if not GRM_API or not GRM_API.GetMember then
        self:DebugPrint("GRM API not available or missing GetMember function")
        self:Print("|cffFF0000Error:|r Guild Roster Manager (GRM) not found or API not available")
        return
    end
    
    -- Clear existing cache
    for k in pairs(RaidTeamCache) do
        RaidTeamCache[k] = nil
    end
    
    self:DebugPrint("Refreshing raid team cache...")
    
    -- Get guild name
    local guildName = GetGuildInfo("player")
    if not guildName then
        self:DebugPrint("Could not get guild name")
        self:Print("|cffFF0000Error:|r Could not get guild name")
        return
    end
    
    self:DebugPrint("Guild name: " .. guildName)
    
    -- Process guild members
    local memberCount = 0
    local raidTeamCount = 0
    local grmMemberCount = 0
    
    -- Get all guild members
    local numMembers = GetNumGuildMembers()
    self:DebugPrint("Total guild members: " .. numMembers)
    
    for i = 1, numMembers do
        local name, rank, rankIndex, level, class, zone, note, officernote, online, status, classFileName, achievementPoints, achievementRank, isMobile, canSoR, repStanding = GetGuildRosterInfo(i)
        
        if name then
            memberCount = memberCount + 1
            
            -- Get member data from GRM (no guild name needed for public API)
            local success, memberData = pcall(GRM_API.GetMember, name)
            if success and memberData then
                grmMemberCount = grmMemberCount + 1
                self:DebugPrint("GRM data for " .. name .. ": " .. (memberData and "found" or "nil"))
                
                if memberData.customNote and memberData.customNote[4] then
                    local customNote = memberData.customNote[4]
                    self:DebugPrint("Custom note for " .. name .. ": " .. customNote)
                    
                    local raidTeams = self:ParseRaidTeamsFromNote(customNote)
                    
                    if #raidTeams > 0 then
                        -- Strip server name from the player name for consistent storage
                        local playerNameOnly = string.match(name, "^([^-]+)")
                        RaidTeamCache[playerNameOnly] = raidTeams
                        raidTeamCount = raidTeamCount + 1
                        self:DebugPrint("Cached '" .. playerNameOnly .. "' (from '" .. name .. "'): " .. table.concat(raidTeams, ", "))
                    else
                        self:DebugPrint("No raid teams found in note for " .. name)
                    end
                else
                    self:DebugPrint("No custom note for " .. name)
                end
                
                -- Handle alt group propagation
                if memberData.altGroup and memberData.altGroup ~= "" then
                    local success, err = pcall(function()
                        self:ProcessAltGroup(name, memberData.altGroup)
                    end)
                    if not success then
                        self:DebugPrint("Error in ProcessAltGroup for " .. name .. ": " .. tostring(err))
                    end
                end
            else
                self:DebugPrint("Failed to get GRM data for " .. name)
            end
        end
    end
    
    self:DebugPrint(string.format("Cache refresh complete: %d members processed, %d GRM members found, %d with raid teams", memberCount, grmMemberCount, raidTeamCount))
    
    -- Mark cache as initialized after successful refresh
    cacheInitialized = true
    self:DebugPrint("Cache initialization flag set to true")
    
    if raidTeamCount == 0 then
        self:Print("|cffFFFF00Warning:|r No raid teams found. Check that:")
        self:Print("1. GRM custom notes contain raid team info (RT1, RT2, etc.)")
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
        self:DebugPrint("GRM_API.GetMemberAlts not available, skipping alt group processing")
        return
    end
    
    -- Get all alts in the group
    local success, alts = pcall(GRM_API.GetMemberAlts, playerName)
    if not success then
        self:DebugPrint("Error calling GRM_API.GetMemberAlts for " .. playerName .. ": " .. tostring(alts))
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
        elseif not success then
            self:DebugPrint("Error getting GRM data for alt " .. altName .. ": " .. tostring(altData))
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
        self:DebugPrint(string.format("Alt group %s: %d raid teams applied to %d characters", altGroup, #allRaidTeams, #alts + 1))
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

-- Removed HookGameTooltip() and HookTooltip() functions as they are no longer needed
-- We only use the OnTooltipSetUnit event which is handled directly in UpdateTooltipHooks()

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
        self:DebugPrint("In raid zone, skipping tooltip processing for performance")
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
        -- Debug: Only show debug message when player actually has raid teams
        self:DebugPrint("Raid teams found for " .. name .. ": " .. table.concat(raidTeams, ", "))
        
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
    
    -- Debug: Log the sender name
    self:DebugPrint("Processing chat message - Event: " .. event .. ", Sender: '" .. sender .. "'")
    
    -- Get raid teams for the sender (handles realm name stripping internally)
    local success, raidTeams = pcall(function() return self:GetPlayerRaidTeams(sender) end)
    if not success then
        self:Print("|cffFF0000[ERROR]|r GetPlayerRaidTeams failed: " .. tostring(raidTeams))
        return false, msg, sender, ...
    end
    
    self:DebugPrint("Raid teams found for '" .. sender .. "': " .. (#raidTeams > 0 and table.concat(raidTeams, ", ") or "none"))
    
    if #raidTeams > 0 then
        local success3, err3 = pcall(function()
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
                self:DebugPrint("Applied raid team prefix: " .. raidTeamPrefix)
            else
                self:DebugPrint("Message already has raid team prefix, skipping")
            end
        end)
        if not success3 then
            self:Print("|cffFF0000[ERROR]|r Message processing failed: " .. tostring(err3))
            return false, msg, sender, ...
        end
    else
        self:DebugPrint("No raid teams found for sender: " .. sender)
    end
    
    return false, msg, sender, ...
end
