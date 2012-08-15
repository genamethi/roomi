do
	local tProtoPerms = {
		[1] = {
			[0] = true, [1] = true, [2] = true, [3] = true, [4] = false, [5] = false, [-1] = false;
		},
		[2] = {
			[0] = true, [1] = true, [2] = true, [3] = true, [4] = true, [5] = true, [-1] = true;
		},
		[3] = {
			[1] = true, [2] = true, [3] = true, [4] = true, [5] = true, [0] = true, [-1] = false,
		},
		[4] = {
			[1] = {
				[1] = false, [2] = true, [3] = true, [4] = true, [5] = true, [0] = false, [-1] = true,
			},
			[2] = {
				[1] = false, [2] = false, [3] = true, [4] = true, [5] = true, [0] = false, [-1] = true,
			},
			[3] = {
				[1] = false, [2] = false, [3] = false, [4] = true, [5] = true, [0] = false, [-1] = true,
			},
			[4] = {
				[1] = false, [2] = false, [3] = false, [4] = false, [5] = false, [0] = false, [-1] = true,
			},
			[0] = {
				[1] = false, [2] = true, [3] = true, [4] = true, [5] = true, [0] = false, [-1] = true,
			},
			[5] = {
				[1] = false, [2] = false, [3] = false, [4] = false, [5] = false, [0] = false, [-1] = false,
			},
		}
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
			sHelp = " [Room] - Joins chatroom.\n"
		},
		part = {
			Permissions = tProtoPerms[3],
			sHelp = " - Parts chatroom.\n"
		},
		roomhelp = {
			Permissions = tProtoPerms[3],
			sHelp = " - Gives this help message.\n"
		},
		lsusers = {
			Permissions = tProtoPerms[3],
			sHelp = " - Lists all chatters in room.\n"
		},
		mkroom = {
			Permissions = tProtoPerms[3],
			sHelp = "<Room Name> - Creates a new room.\n"
		},
		delroom = {
			Permissions = tProtoPerms[1],
			sHelp = "<Room> - Removes room.\n"
		},
		rmhistory = {
			Permissions = tProtoPerms[3],
			sHelp = "<Start> <End> - Give command first and last desired line number of viewable history.\n"
		},
	}
end

function tCommandArrivals.join:Action( tUser, sMsg, sToUser )
	local sRoomName, oRoom = sMsg:match( "^(%S+)|$" )
	if not sToUser and not sRoomName then
		return true, "Please specify a name when attempting to join a room\124", true, tConfig.sNick
	else
		sRoomName = sRoomName or sToUser
		for i = 1, #tRooms do
			if tRooms[i].sNick:lower() == sRoomName:lower() then
				oRoom = tRooms[i]
				break
			end
		end
		if oRoom then
			if not oRoom.tAllUsers[ tUser.sNick ] then
				table.insert( oRoom.tOnlineUsers, tUser )
				oRoom.tAllUsers[ tUser.sNick ] = #oRoom.tOnlineUsers									--See part command to understand why this is done.
				for i, v in ipairs( oRoom.tOnlineUsers ) do
					Core.SendPmToUser( v, oRoom.sNick, tUser.sNick .. " has joined the room.\124" )
				end
				return true, "You've joined a room.", false, oRoom.sNick
			else
				return true, "You're already in that room.\124", true, oRoom.sNick
			end
		else
			return tCommandArrivals.mkroom:Action( tUser, sMsg )
		end
	end
end

function tCommandArrivals.part:Action( tUser, sMsg, sToUser )
	local oRoom;
	for i = 1, #tRooms do
		sRoom = sMsg:match( "^(%S+)|$" ):lower() or sToUser:lower()
		if tRooms[i].sNick:lower() == sRoom then
			oRoom = tRooms[i]
			break;
		end
	end
	if oRoom then
		if oRoom.tAllUsers[ tUser.sNick ] then
			table.remove( oRoom.tOnlineUsers, oRoom.tAllUsers[ tUser.sNick ] )		--the value of tRooms.tAllUsers[ tUser.sNick ] should be the user's indice in OnlineUsers.
			oRoom.tAllUsers[ tUser.sNick ] = nil
			for sNick, nIndice in pairs( oRoom.tAllUsers ) do
				nIndice = nIndice - 1;
			end
			for i, v in ipairs( oRoom.tOnlineUsers ) do
				Core.SendPmToUser( v, oRoom.sNick, tUser.sNick .. " has left the room.\124" )
			end
		else
			return true, "You're not currently in a room.\124", true, oRoom.sNick
		end
		return true, "You've left a room.", true, oRoom.sNick
	else
		return true, "Error, no room specified, or sent to incorrect nick.\124", true, tConfig.sNick
	end
end

function tCommandArrivals.lsusers:Action( tUser, sMsg, sToUser )
	local sRet = "\n\n**-*-** Current Members **-*-**\n\n"
	local oRoom;
	for i = 1, #tRooms do
		sToUser = sMsg:match( "^(%S+)|$" ):lower() or sToUser
		if tRooms[i].sNick == sToUser then
			oRoom = tRooms[i]
			break;
		end
	end
	if oRoom then
		for i, v in ipairs( oRoom.tOnlineUsers ) do
			sRet = sRet .. "\t\t* " .. v.sNick .. "\n\n"
		end
		return true, sRet, true, oRoom.sNick
	else
		return true, "Error, no room specified, or sent to invalid user or bot.\124", true, tConfig.sNick
	end
end

function tCommandArrivals.mkroom:Action( tUser, sMsg ) --Need to add check for forbidden characters.
	local sRoom = sMsg:match( "^(%S+)|$" )
	if sRoom then
		local tReserved = Core.GetBots( )
		table.insert( tReserved, sHBName )
		table.insert( tReserved, sOCName )
		for i = 1, #tReserved - 2 do
			tReserved[ tReserved[ i ].sNick:lower() ], tReserved[ i ] = true, nil;
		end
		if tReserved[ sRoom:lower() ] or RegMan.GetReg( sRoom ) then
			return true, "This nick is reserved by a bot or another user, please use something else.\124", true, tConfig.sNick
		else
			Core.RegBot( sRoom, "Roomi chatroom!", "", false )
			table.insert( tRooms, { sNick = sRoom, tAllUsers = { }, tOnlineUsers = { }, ChatHistory = NewHistory() } )
			table.insert( tRooms[ #tRooms ].tOnlineUsers, tUser )
			tRooms[ #tRooms ].tAllUsers[ tUser.sNick ] = #tRooms[ #tRooms ].tOnlineUsers
			return true, "New room created!", true, tConfig.sNick
		end
	else
		return true, "Please specify a name when attempting to make a new room\124", true, tConfig.sNick
	end
end

function tCommandArrivals.delroom:Action( tUser, sMsg )
	local sRoom = sMsg:match( "^(%S+)|$" ):lower()
	if sRoom then
		for i = 1, #tRooms do
			if tRooms[i].sNick:lower() == sRoom then
				table.remove( tRooms, i )
				Core.UnregBot( sRoom )
				break;
			end
		end
		return true, "Room has been deleted!", true, tConfig.sNick
	else
		return true, "Specified room does not exist.", true, tConfig.sNick
	end
end
		

function tCommandArrivals.roomhelp:Action( tUser )
	local sRet = "\n\n**-*-** " .. ScriptMan.GetScript().sName .."  help (use one of these prefixes: " .. SetMan.GetString( 29 ) .. "\n\n"
	for name, obj in pairs( tCommandArrivals ) do
		if obj.Permissions[ tUser.iProfile ] then
			sRet = sRet .. "\t" .. name .. "\t" .. obj.sHelp
		end
	end
	return true, sRet .. "\n\tWorks in main only at the moment!**-*-**\n", true, tConfig.sNick
end

function tCommandArrivals.rmhistory:Action( tUser, sMsg, sToUser )
	local opt, i, j = sMsg:match "^%s*(%a-)%s*(%-?%d*)%s*(%--%d-)%s*|$"
	if sMsg:match( "%S+%s*|$" ) and not opt and not i and not j then
		return true, self.sHelp
	else
		local oRoom
		for i = 1, #tRooms do
			sToUser = sMsg:match( "^(%S+)|$" ):lower() or sToUser
			if tRooms[i].sNick == sToUser then
				oRoom = tRooms[i]
				break
			end
		end
		if oRoom then
			i, j = tonumber( i ), tonumber( j );
			return true, doHistory( oRoom.ChatHistory, i, j )
		else
			return true, "Error, no room specified, or sent to invalid user or bot.\124", true, tConfig.sNick
		end
	end
end
