-- RaidTeamChat - Displays raid team information in chat messages
-- Integrates with Guild Roster Manager (GRM) to show raid team tags

local RaidTeamChat = LibStub("AceAddon-3.0"):NewAddon("RaidTeamChat", "AceConsole-3.0", "AceEvent-3.0")
local AceConfig = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")

-- Addon version
local VERSION = "1.0.0"

-- Raid team colors
local raidTeamColors = {
    ["RT1"] = "|cffFF6B6B",  -- Red
    ["RT2"] = "|cff4ECDC4",  -- Teal
    ["RT3"] = "|cff45B7D1",  -- Blue
    ["RT4"] = "|cff96CEB4",  -- Green
    ["RT5"] = "|cffFFEAA7",  -- Yellow
    ["RT6"] = "|cffDDA0DD",  -- Plum
    ["RT7"] = "|cff98D8C8",  -- Mint
    ["RT8"] = "|cffF7DC6F",  -- Gold
    ["RT9"] = "|cffBB8FCE",  -- Lavender
    ["RT10"] = "|cff85C1E9", -- Light Blue
}

-- Default settings
local defaults = {
    enabled = true,
    showInGuild = true,
    showInOfficer = true,
    showInParty = true,
    showInRaid = true,
    showInWhisper = false,
    showInInstance = true,
    debugMode = false
}

-- Global cache for raid team data
RaidTeamCache = {}

-- Configuration options
local options = {
    name = "Raid Team Chat",
    handler = RaidTeamChat,
    type = "group",
    args = {
        enabled = {
            type = "toggle",
            name = "Enable Raid Team Chat",
            desc = "Turn raid team chat decoration on or off",
            get = function() return RaidTeamChat.db.profile.enabled end,
            set = function(info, value)
                RaidTeamChat.db.profile.enabled = value
                RaidTeamChat:UpdateChatHooks()
            end,
            order = 1,
        },
        debugMode = {
            type = "toggle",
            name = "Debug Mode",
            desc = "Enable debug messages",
            get = function() return RaidTeamChat.db.profile.debugMode end,
            set = function(info, value)
                RaidTeamChat.db.profile.debugMode = value
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
                    get = function() return RaidTeamChat.db.profile.showInGuild end,
                    set = function(info, value)
                        RaidTeamChat.db.profile.showInGuild = value
                    end,
                    order = 1,
                },
                showInOfficer = {
                    type = "toggle",
                    name = "Officer Chat",
                    desc = "Show raid teams in officer chat",
                    get = function() return RaidTeamChat.db.profile.showInOfficer end,
                    set = function(info, value)
                        RaidTeamChat.db.profile.showInOfficer = value
                    end,
                    order = 2,
                },
                showInParty = {
                    type = "toggle",
                    name = "Party Chat",
                    desc = "Show raid teams in party chat",
                    get = function() return RaidTeamChat.db.profile.showInParty end,
                    set = function(info, value)
                        RaidTeamChat.db.profile.showInParty = value
                    end,
                    order = 3,
                },
                showInRaid = {
                    type = "toggle",
                    name = "Raid Chat",
                    desc = "Show raid teams in raid chat",
                    get = function() return RaidTeamChat.db.profile.showInRaid end,
                    set = function(info, value)
                        RaidTeamChat.db.profile.showInRaid = value
                    end,
                    order = 4,
                },
                showInWhisper = {
                    type = "toggle",
                    name = "Whisper",
                    desc = "Show raid teams in whisper messages",
                    get = function() return RaidTeamChat.db.profile.showInWhisper end,
                    set = function(info, value)
                        RaidTeamChat.db.profile.showInWhisper = value
                    end,
                    order = 5,
                },
                showInInstance = {
                    type = "toggle",
                    name = "Instance Chat",
                    desc = "Show raid teams in instance chat",
                    get = function() return RaidTeamChat.db.profile.showInInstance end,
                    set = function(info, value)
                        RaidTeamChat.db.profile.showInInstance = value
                    end,
                    order = 6,
                },
            },
        },
        refresh = {
            type = "execute",
            name = "Refresh Cache",
            desc = "Manually refresh the raid team cache",
            func = function()
                RaidTeamChat:RefreshRaidTeamCache()
                RaidTeamChat:Print("Raid team cache refreshed!")
            end,
            order = 4,
        },
    },
}

function RaidTeamChat:OnInitialize()
    -- Initialize database
    self.db = LibStub("AceDB-3.0"):New("RaidTeamChatDB", {profile = defaults}, true)
    
    -- Register configuration
    AceConfig:RegisterOptionsTable("RaidTeamChat", options)
    AceConfigDialog:AddToBlizOptions("RaidTeamChat", "Raid Team Chat")
    
    -- Register slash commands
    self:RegisterChatCommand("rtc", "SlashCommand")
    self:RegisterChatCommand("raidteamchat", "SlashCommand")
    
    self:DebugPrint("RaidTeamChat initialized")
end

function RaidTeamChat:OnEnable()
    self:RegisterEvent("ADDON_LOADED", "OnAddonLoaded")
    self:RegisterEvent("PLAYER_LOGIN", "OnPlayerLogin")
    self:RegisterEvent("GUILD_ROSTER_UPDATE", "OnGuildRosterUpdate")
    
    -- Wait for GRM to load
    if IsAddOnLoaded("Guild_Roster_Manager") then
        self:InitializeGRM()
    end
end

function RaidTeamChat:OnDisable()
    self:UnregisterAllEvents()
    self:UnhookAll()
end

function RaidTeamChat:OnAddonLoaded(event, addonName)
    if addonName == "Guild_Roster_Manager" then
        self:InitializeGRM()
    end
end

function RaidTeamChat:OnPlayerLogin()
    self:DebugPrint("Player logged in")
    if self.db.profile.enabled then
        self:RefreshRaidTeamCache()
        self:UpdateChatHooks()
    end
end

function RaidTeamChat:OnGuildRosterUpdate()
    self:DebugPrint("Guild roster updated")
    if self.db.profile.enabled then
        self:RefreshRaidTeamCache()
    end
end

function RaidTeamChat:InitializeGRM()
    if not GRM_API then
        self:Print("Guild Roster Manager not found or API not available")
        return false
    end
    
    self:DebugPrint("GRM API initialized")
    return true
end

function RaidTeamChat:SlashCommand(input)
    if not input or input == "" then
        InterfaceOptionsFrame_OpenToCategory("Raid Team Chat")
        return
    end
    
    local command = string.lower(input)
    
    if command == "refresh" then
        self:RefreshRaidTeamCache()
        self:Print("Raid team cache refreshed!")
    elseif command == "status" then
        self:PrintStatus()
    elseif command == "config" or command == "settings" then
        InterfaceOptionsFrame_OpenToCategory("Raid Team Chat")
    else
        self:Print("Usage: /rtc [refresh|status|config]")
    end
end

function RaidTeamChat:PrintStatus()
    local status = self.db.profile.enabled and "Enabled" or "Disabled"
    self:Print("Raid Team Chat: " .. status)
    self:Print("Debug Mode: " .. (self.db.profile.debugMode and "On" or "Off"))
    self:Print("Cached Players: " .. self:GetCacheSize())
    self:Print("GRM Available: " .. (GRM_API and "Yes" or "No"))
end

function RaidTeamChat:GetCacheSize()
    local count = 0
    for _ in pairs(RaidTeamCache) do
        count = count + 1
    end
    return count
end

function RaidTeamChat:DebugPrint(message)
    if self.db.profile.debugMode then
        self:Print("|cff00FF00[DEBUG]|r " .. message)
    end
end

function RaidTeamChat:ParseRaidTeamsFromNote(note)
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

function RaidTeamChat:GetColoredRaidTeam(teamString)
    if not teamString then
        return ""
    end
    
    local color = raidTeamColors[teamString] or "|cffFFFFFF"
    return color .. teamString .. "|r"
end

function RaidTeamChat:RefreshRaidTeamCache()
    if not IsInGuild() then
        self:DebugPrint("Not in a guild, skipping cache refresh")
        return
    end
    
    if not GRM_API then
        self:DebugPrint("GRM API not available, skipping cache refresh")
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
        return
    end
    
    -- Process guild members
    local memberCount = 0
    local raidTeamCount = 0
    
    -- Get all guild members
    local numMembers = GetNumGuildMembers()
    for i = 1, numMembers do
        local name, rank, rankIndex, level, class, zone, note, officernote, online, status, classFileName, achievementPoints, achievementRank, isMobile, canSoR, repStanding = GetGuildRosterInfo(i)
        
        if name then
            memberCount = memberCount + 1
            
            -- Get member data from GRM
            local memberData = GRM_API.GetMember(name, guildName)
            if memberData and memberData.customNote and memberData.customNote[4] then
                local raidTeams = self:ParseRaidTeamsFromNote(memberData.customNote[4])
                
                if #raidTeams > 0 then
                    RaidTeamCache[name] = raidTeams
                    raidTeamCount = raidTeamCount + 1
                    self:DebugPrint("Cached " .. name .. ": " .. table.concat(raidTeams, ", "))
                end
                
                -- Handle alt group propagation
                if memberData.altGroup and memberData.altGroup ~= "" then
                    self:ProcessAltGroup(name, memberData.altGroup, guildName)
                end
            end
        end
    end
    
    self:DebugPrint(string.format("Cache refresh complete: %d members processed, %d with raid teams", memberCount, raidTeamCount))
end

function RaidTeamChat:ProcessAltGroup(playerName, altGroup, guildName)
    if not altGroup or altGroup == "" then
        return
    end
    
    -- Get all alts in the group
    local alts = GRM_API.GetMemberAlts(playerName, guildName)
    if not alts or #alts == 0 then
        return
    end
    
    -- Collect raid teams from all alts
    local allRaidTeams = {}
    local raidTeamSet = {}
    
    -- Add current player's raid teams
    if RaidTeamCache[playerName] then
        for _, team in ipairs(RaidTeamCache[playerName]) do
            if not raidTeamSet[team] then
                table.insert(allRaidTeams, team)
                raidTeamSet[team] = true
            end
        end
    end
    
    -- Add alt raid teams
    for _, altName in ipairs(alts) do
        local altData = GRM_API.GetMember(altName, guildName)
        if altData and altData.customNote and altData.customNote[4] then
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
        RaidTeamCache[playerName] = allRaidTeams
        for _, altName in ipairs(alts) do
            RaidTeamCache[altName] = allRaidTeams
        end
        self:DebugPrint(string.format("Alt group %s: %d raid teams applied to %d characters", altGroup, #allRaidTeams, #alts + 1))
    end
end

function RaidTeamChat:GetPlayerRaidTeams(playerName)
    if not playerName or not RaidTeamCache[playerName] then
        return {}
    end
    
    return RaidTeamCache[playerName]
end

function RaidTeamChat:UpdateChatHooks()
    -- Unhook all existing hooks
    self:UnhookAll()
    
    if not self.db.profile.enabled then
        return
    end
    
    -- Hook chat events
    local events = {
        "CHAT_MSG_GUILD",
        "CHAT_MSG_OFFICER", 
        "CHAT_MSG_PARTY",
        "CHAT_MSG_PARTY_LEADER",
        "CHAT_MSG_RAID",
        "CHAT_MSG_RAID_LEADER",
        "CHAT_MSG_INSTANCE_CHAT",
        "CHAT_MSG_INSTANCE_CHAT_LEADER",
        "CHAT_MSG_WHISPER"
    }
    
    for _, event in ipairs(events) do
        self:RegisterEvent(event, "ChatMessageFilter")
    end
end

function RaidTeamChat:ChatMessageFilter(event, msg, sender, ...)
    if not IsInGuild() or not GRM_API then
        return false, msg, sender, ...
    end
    
    -- Don't modify own messages
    if sender == UnitName("player") then
        return false, msg, sender, ...
    end
    
    -- Check if this channel is enabled
    local channelEnabled = false
    if event == "CHAT_MSG_GUILD" and self.db.profile.showInGuild then
        channelEnabled = true
    elseif event == "CHAT_MSG_OFFICER" and self.db.profile.showInOfficer then
        channelEnabled = true
    elseif (event == "CHAT_MSG_PARTY" or event == "CHAT_MSG_PARTY_LEADER") and self.db.profile.showInParty then
        channelEnabled = true
    elseif (event == "CHAT_MSG_RAID" or event == "CHAT_MSG_RAID_LEADER") and self.db.profile.showInRaid then
        channelEnabled = true
    elseif event == "CHAT_MSG_WHISPER" and self.db.profile.showInWhisper then
        channelEnabled = true
    elseif (event == "CHAT_MSG_INSTANCE_CHAT" or event == "CHAT_MSG_INSTANCE_CHAT_LEADER") and self.db.profile.showInInstance then
        channelEnabled = true
    end
    
    if not channelEnabled then
        return false, msg, sender, ...
    end
    
    -- Get raid teams for sender
    local raidTeams = self:GetPlayerRaidTeams(sender)
    
    if #raidTeams > 0 then
        -- Create colored raid team prefix
        local coloredTeams = {}
        for _, team in ipairs(raidTeams) do
            table.insert(coloredTeams, self:GetColoredRaidTeam(team))
        end
        local raidTeamPrefix = "[" .. table.concat(coloredTeams, ",") .. "]: "
        
        -- Prepend to message
        msg = raidTeamPrefix .. msg
    end
    
    return false, msg, sender, ...
end
