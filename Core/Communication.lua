local _, Spoilscribe = ...

-- Addon communication for sharing favorite dungeons with party.
local COMM_PREFIX = "Spoilscribe"
if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
    C_ChatInfo.RegisterAddonMessagePrefix(COMM_PREFIX)
end

local function IsPlayerInInstance()
    if _G.IsInInstance then
        local _, instanceType = _G.IsInInstance()
        return instanceType and instanceType ~= "none"
    end
    return false
end

function Spoilscribe:BroadcastFavorites()
    if InCombatLockdown and InCombatLockdown() then return end
    if IsPlayerInInstance() then return end
    if not IsInGroup or not IsInGroup() then return end
    if self.GetOption and not self:GetOption("groupSync") then return end

    local dungeons = self:GetFavoriteDungeonNames()
    local parts = {}
    for dn, count in pairs(dungeons) do
        parts[#parts + 1] = dn .. ":" .. tostring(count)
    end
    -- Send "FAV:DungeonName:count,DungeonName:count,..." (empty string = no favorites).
    local payload = "FAV:" .. table.concat(parts, ",")
    local channel = IsInGroup(LE_PARTY_CATEGORY_INSTANCE) and "INSTANCE_CHAT" or "PARTY"
    C_ChatInfo.SendAddonMessage(COMM_PREFIX, payload, channel)

    -- Also broadcast individual item IDs with the selected difficulty.
    SpoilscribeCharDB.favorites = SpoilscribeCharDB.favorites or {}
    local ids = {}
    for id in pairs(SpoilscribeCharDB.favorites) do
        ids[#ids + 1] = tostring(id)
    end
    local frame = self.UI and self.UI.frame
    local diffId = 23
    if frame then
        local difficulty = self.Data.Difficulties[frame.selectedDifficultyIndex or 1]
        diffId = difficulty and difficulty.id or 23
    end
    local itemPayload = "ITEMS:" .. tostring(diffId) .. ":" .. table.concat(ids, ",")
    C_ChatInfo.SendAddonMessage(COMM_PREFIX, itemPayload, channel)
end

function Spoilscribe:BroadcastKeystone()
    if InCombatLockdown and InCombatLockdown() then return end
    if IsPlayerInInstance() then return end
    if not IsInGroup or not IsInGroup() then return end
    if self.GetOption and not self:GetOption("groupSync") then return end

    local mapID = C_MythicPlus and C_MythicPlus.GetOwnedKeystoneChallengeMapID and C_MythicPlus.GetOwnedKeystoneChallengeMapID()
    local level = C_MythicPlus and C_MythicPlus.GetOwnedKeystoneLevel and C_MythicPlus.GetOwnedKeystoneLevel()

    local dungeonName = ""
    if mapID and C_ChallengeMode and C_ChallengeMode.GetMapUIInfo then
        dungeonName = C_ChallengeMode.GetMapUIInfo(mapID) or ""
    end

    local payload = "KEY:" .. dungeonName .. ":" .. tostring(level or 0)
    local channel = IsInGroup(LE_PARTY_CATEGORY_INSTANCE) and "INSTANCE_CHAT" or "PARTY"
    C_ChatInfo.SendAddonMessage(COMM_PREFIX, payload, channel)
end

function Spoilscribe:RequestPartyFavorites()
    if IsPlayerInInstance() then return end
    if not IsInGroup or not IsInGroup() then return end
    if self.GetOption and not self:GetOption("groupSync") then return end
    local channel = IsInGroup(LE_PARTY_CATEGORY_INSTANCE) and "INSTANCE_CHAT" or "PARTY"
    C_ChatInfo.SendAddonMessage(COMM_PREFIX, "REQ", channel)
end

function Spoilscribe:GetPartyFavDungeons()
    return self._partyFavDungeons
end

function Spoilscribe:HandleCommReceived(prefix, message, _, sender)
    if prefix ~= COMM_PREFIX then return end
    if self.GetOption and not self:GetOption("groupSync") then return end

    -- Ignore messages from self.
    local myName = UnitName("player")
    local myRealm = GetNormalizedRealmName and GetNormalizedRealmName() or GetRealmName():gsub("%s", "")
    local myFullName = myName .. "-" .. myRealm
    if sender == myName or sender == myFullName then return end

    -- Handle sync request: another client reloaded and wants our favorites.
    if message == "REQ" then
        self:BroadcastFavorites()
        self:BroadcastKeystone()
        return
    end

    -- Handle keystone info: KEY:dungeonName:level
    if message and message:sub(1, 4) == "KEY:" then
        local rest = message:sub(5)
        local dungeonName, levelStr = rest:match("^(.*):(%d+)$")
        local level = tonumber(levelStr)
        if dungeonName and dungeonName ~= "" and level and level > 0 then
            self._partyKeystones[sender] = { dungeonName = dungeonName, level = level }
        else
            self._partyKeystones[sender] = nil
        end
        if self.UI and self.UI.frame and self.UI.frame:IsShown() then
            self.UI:RenderPage()
        end
        return
    end

    -- Handle item ID list from party members: ITEMS:diffId:id1,id2,...
    if message and message:sub(1, 6) == "ITEMS:" then
        local rest = message:sub(7)
        local diffStr, itemBody = rest:match("^(%d+):(.*)$")
        local diffId = tonumber(diffStr)
        if not diffId then
            -- Backwards compat: no difficulty prefix.
            diffId = 23
            itemBody = rest
        end
        local items = {}
        if itemBody and itemBody ~= "" then
            for idStr in itemBody:gmatch("%d+") do
                local id = tonumber(idStr)
                if id then
                    items[id] = true
                end
            end
        end
        if next(items) then
            self._partyFavItems[sender] = { diffId = diffId, items = items }
        else
            self._partyFavItems[sender] = nil
        end
        if self.UI and self.UI.frame and self.UI.frame:IsShown() then
            if self.UI.frame._zoomedPartyFavorites then
                self.UI:ZoomPartyFavorites()
            end
        end
        return
    end

    -- Strip the "FAV:" prefix (backwards-compat: accept messages without it too).
    local body = message
    if body and body:sub(1, 4) == "FAV:" then
        body = body:sub(5)
    end

    local dungeons = {}
    if body and body ~= "" then
        for entry in body:gmatch("[^,]+") do
            local dn, countStr = entry:match("^(.+):(%d+)$")
            if dn then
                local trimmed = dn:match("^%s*(.-)%s*$")
                if trimmed and trimmed ~= "" then
                    dungeons[trimmed] = tonumber(countStr) or 1
                end
            else
                -- Backwards compat: no count means 1.
                local trimmed = entry:match("^%s*(.-)%s*$")
                if trimmed and trimmed ~= "" then
                    dungeons[trimmed] = 1
                end
            end
        end
    end
    self._partyFavDungeons[sender] = next(dungeons) and dungeons or nil

    -- Refresh the UI if open so icons update.
    if self.UI and self.UI.frame and self.UI.frame:IsShown() then
        self.UI:RenderPage()
    end
end

function Spoilscribe:GetKeystoneHolders(dungeonName)
    local holders = {}

    -- Check the player's own keystone.
    local mapID = C_MythicPlus and C_MythicPlus.GetOwnedKeystoneChallengeMapID and C_MythicPlus.GetOwnedKeystoneChallengeMapID()
    local level = C_MythicPlus and C_MythicPlus.GetOwnedKeystoneLevel and C_MythicPlus.GetOwnedKeystoneLevel()
    if mapID and level and level > 0 then
        local myKeystoneName = ""
        if C_ChallengeMode and C_ChallengeMode.GetMapUIInfo then
            myKeystoneName = C_ChallengeMode.GetMapUIInfo(mapID) or ""
        end
        if myKeystoneName ~= "" and string.lower(myKeystoneName) == string.lower(dungeonName) then
            local myName = UnitName and UnitName("player") or "You"
            holders[#holders + 1] = { name = myName, level = level }
        end
    end

    -- Check party members' keystones.
    for sender, data in pairs(self._partyKeystones) do
        if data.dungeonName and string.lower(data.dungeonName) == string.lower(dungeonName) then
            local shortName = sender:match("^([^-]+)") or sender
            holders[#holders + 1] = { name = shortName, level = data.level }
        end
    end

    return holders
end

function Spoilscribe:PrunePartyMembers()
    if IsInGroup and IsInGroup() then
        local validNames = {}
        for i = 1, GetNumGroupMembers() do
            local name = GetRaidRosterInfo(i)
            if name then validNames[name] = true end
        end
        for sender in pairs(self._partyFavDungeons) do
            -- sender may be "Name" or "Name-Realm"
            local shortName = sender:match("^([^-]+)") or sender
            if not validNames[sender] and not validNames[shortName] then
                self._partyFavDungeons[sender] = nil
                self._partyFavItems[sender] = nil
                self._partyKeystones[sender] = nil
            end
        end
    else
        wipe(self._partyFavDungeons)
        wipe(self._partyFavItems)
        wipe(self._partyKeystones)
    end
end
