do
	local tProtoPerms = {
		-- [1] = { Uncomment if you change permissions, use the guide below to decide on the value.
			-- [0] = true, [1] = true, [2] = true, [3] = true, [4] = false, [5] = false, [-1] = false;
		-- },
		-- [2] = {
			-- [0] = true, [1] = true, [2] = true, [3] = true, [4] = true, [5] = true, [-1] = true;
		-- },
		[3] = {
			[1] = true, [2] = true, [3] = true, [4] = true, [5] = true, [0] = true, [-1] = false,
		},
		-- [4] = {
			-- [1] = {
				-- [1] = false, [2] = true, [3] = true, [4] = true, [5] = true, [0] = false, [-1] = true,
			-- },
			-- [2] = {
				-- [1] = false, [2] = false, [3] = true, [4] = true, [5] = true, [0] = false, [-1] = true,
			-- },
			-- [3] = {
				-- [1] = false, [2] = false, [3] = false, [4] = true, [5] = true, [0] = false, [-1] = true,
			-- },
			-- [4] = {
				-- [1] = false, [2] = false, [3] = false, [4] = false, [5] = false, [0] = false, [-1] = true,
			-- },
			-- [0] = {
				-- [1] = false, [2] = true, [3] = true, [4] = true, [5] = true, [0] = false, [-1] = true,
			-- },
			-- [5] = {
				-- [1] = false, [2] = false, [3] = false, [4] = false, [5] = false, [0] = false, [-1] = false,
			-- },
		-- }
	}


	tCommandArrivals = {
		--[[
			Guide:
				1 == Op only command.
				2 == All
				3 == Reg-only
				4 == Generic Multi-dimension
		]]
		join = {
			Permissions = tProtoPerms[3],
			sHelp = " - Joins chatroom.\n" 			--#nomulti
		},
		part = {
			Permissions = tProtoPerms[3],
			sHelp = " - Parts chatroom.\n"
		},
		roomhelp = {
			Permissions = tProtoPerms[3],
			sHelp = " - Gives this help message.\n"
		},
	}
end

function tCommandArrivals.join:Action( tUser )		--#nomulti
	if not tRooms.tAllUsers[ tUser.sNick ] then
		table.insert( tOnlineUsers, Core.GetUser( tUser.sNick ) )
		tRooms.tAllUsers[ tUser.sNick ] = #tOnlineUsers									--See part command to understand why this is done.
		for i, v in ipairs( tOnlineUsers ) do
			Core.SendPmToUser( v, tConfig.sNick, tUser.sNick .. " has joined the room.\124" )
		end
		return true, "You've joined a room.", false, tConfig.sNick
	else
		return true, "You're already in that room.\124", false, tConfig.sNick
	end
end

function tCommandArrivals.part:Action( tUser )		--#nomulti
	if tRooms.tAllUsers[ tUser.sNick ] then
		table.remove( tOnlineUsers, tRooms.tAllUsers[ tUser.sNick ] )		--the value of tRooms.tAllUsers[ tUser.sNick ] should be the user's indice in OnlineUsers.
		tRooms.tAllUsers[ tUser.sNick ] = nil
		for i, v in ipairs( tOnlineUsers ) do
			Core.SendPmToUser( v, tConfig.sNick, tUser.sNick .. " has left the room.\124" )
		end
	else
		return true, "You're not currently in a room.\124", false, tConfig.sNick
	end
	return true, "You've left a room.", false, tConfig.sNick
end

function tCommandArrivals.roomhelp:Action( tUser )
	local sRet = "\n\n**-*-** " .. ScriptMan.GetScript().sName .."  help (use one of these prefixes: " .. SetMan.GetString( 29 ) .. "\n\n"
	for name, obj in pairs( tCommandArrivals ) do
		if obj.Permissions[ tUser.iProfile ] then
			sRet = sRet .. "\t" .. name .. "\t" .. obj.sHelp;
		end
	end
	return true, sRet .. "\n\tWorks in main only at the moment!**-*-**\n", false, tConfig.sNick
end
