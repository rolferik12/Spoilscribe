local addonName, Spoilscribe = ...

function Spoilscribe:Open()
    if not self.UI or not self.UI.ToggleMainFrame then
        if DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage("Spoilscribe: UI failed to initialize.")
        end
        return
    end

    self.UI:ToggleMainFrame()
end

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("CHAT_MSG_ADDON")
f:RegisterEvent("GROUP_ROSTER_UPDATE")
f:RegisterEvent("PLAYER_REGEN_ENABLED")
f:SetScript("OnEvent", function(_, event, arg1, arg2, arg3, arg4)
    if event == "CHAT_MSG_ADDON" then
        Spoilscribe:HandleCommReceived(arg1, arg2, arg3, arg4)
        return
    end

    if event == "PLAYER_REGEN_ENABLED" then
        Spoilscribe:BroadcastFavorites()
        return
    end

    if event == "GROUP_ROSTER_UPDATE" then
        Spoilscribe:PrunePartyMembers()
        Spoilscribe:BroadcastFavorites()
        if Spoilscribe.UI and Spoilscribe.UI.Favorites and Spoilscribe.UI.frame then
            Spoilscribe.UI.Favorites:UpdateAssistButton(Spoilscribe.UI.frame)
        end
        return
    end

    if event == "PLAYER_ENTERING_WORLD" then
        -- Scan all difficulty+spec combos up front so the EJ is never needed again.
        local ok, err = pcall(function() Spoilscribe:ScanAllCombinations() end)
        if not ok then
            Spoilscribe:LogToConsole("Initial loot scan failed: " .. tostring(err))
        end
        -- Broadcast favorites and request party members' favorites.
        Spoilscribe:BroadcastFavorites()
        Spoilscribe:RequestPartyFavorites()
        f:UnregisterEvent("PLAYER_ENTERING_WORLD")
        return
    end

    if event ~= "ADDON_LOADED" or arg1 ~= addonName then
        return
    end

    -- Keep UI creation lazy to avoid startup failures if Blizzard UI modules are not loaded yet.
end)
