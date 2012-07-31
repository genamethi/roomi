--[[
	What and Who: Roomi by amenay
	More What: Private chatroom script (with crosshub support)
	Why: Trying not to think about this.
	How: Read comments to come.
	v0.0.2
	
	Notes: 	
	
		A lot of early code (commented or not) may seem unnecessary for something so small, it is designed this way in order to frame multi-room support.
		
		You will automatically rejoin a room upon connecting. (and it will be announced by default)
		
		Adding yourself to tOnlineUsers through SIM will result in bugs. (I suggest adding through command when possible. Otherwise, run this in one line:
		table.insert( tOnlineUsers, ( ... ) ) tRooms.tAllUsers[ ( ... ).sNick ]
		This will add you silently, hence it should be less annoying for users when testing something repeatedly in an active environment.
		
		Support for xhub bots hasn't been added yet. (There is a table wasting memory for it, though!*)
		
		This script goes off the assumption of data integrity skipping checks in some places. If you'd like a more strict approach, I will release it in a separate branch.
		
		*Feature
		
		Todo: 
		
			Multi-room support. !mkroom "RoomName"
			Relay support.		!addrelay "RoomName" Sent from relay (Registers relay)
			Configure script.
]]

require "sim"

dofile( Core.GetPtokaXPath( ) .. "scripts/data/chill.table.lua" )		 	--Gives us table.load, table.save.
dofile( Core.GetPtokaXPath( ) .. "cfg/roomi.cfg" )						--Basic Confiugration.
dofile( Core.GetPtokaXPath( ) .. "scripts/data/roomi/tCommands.lua" )	--Commands and Permissions.

--[[ sPre creates a formatted pattern readable by string.match in order to detect when PtokaX set prefixes are used. ]]
sPre = "^[" .. ( SetMan.GetString( 29 ):gsub( ( "%p" ), function ( p ) return "%" .. p end ) ) .. "]"
tOnlineUsers = {}	--This may or may not support multi-room, depends on design of Users object within each room table.

do
	tRooms = table.load( tConfig.sPath .. tConfig.sFile )	--Load pre-existent rooms
	if not tRooms then										--Nothing to load.
		tRooms = { }							--Create object to hold rooms.
		--Note: Eventual object will initial blank, will be an array of tables describing each room. Rooms and users will be persistent between script restarts (and user reconnects?)
	end
end

--[[ Register rooms and interactive Lua mode.]]
	
function OnStartup( )
	Core.RegBot( tConfig.sNick, tConfig.sDescription, "", false )		--Recreating rooms.
	--[[ Todo: Add multiple room support.
	for i = 1, #tRooms do
		Core.RegBot( tRooms[i].sNick, tRooms[i].sDescription, "", false )		--Recreating rooms.
	end]]
	for i, v in ipairs( tRooms ) do
		for sNick in pairs( v.tAllUsers ) do
			table.insert( tOnlineUsers, Core.GetUser( sNick ) )
		end
	end
	sim.hook_OnStartup( { "#SIM", "PtokaX Lua interface via ToArrival", "", true }, tConfig.tAdmins )
end

function OnExit( )
	table.save( tRooms, tConfig.sPath .. tConfig.sFile )
	sim.hook_OnExit()
end

OnError = sim.hook_OnError

function UserConnected( tUser )
	if tConfig.bAutoRejoin then
		for _, oRoom in ipairs( tRooms ) do
			if oRoom.tAllUsers[ tUser.sNick ] then
				table.insert( tOnlineUsers, Core.GetUser( tUser.sNick ) )
				oRoom.tAllUsers[ tUser.sNick ] = #tOnlineUsers									--See UserDisconnected to understand why this is done.
				for i, v in ipairs( tOnlineUsers ) do
					Core.SendPmToUser( v, oRoom.sNick, tUser.sNick .. " has re-joined the room.\124" )
				end
			end
		end
	end
end

OpConnected, RegConnected = UserConnected, UserConnected

function UserDisconnected( tUser )
	for _, oRoom in ipairs( tRooms ) do
		if oRoom.tAllUsers[ tUser.sNick ] then
			table.remove( tOnlineUsers, oRoom.tAllUsers[ tUser.sNick ] )		--the value of tAllUsers[ tUser.sNick ] should be the user's indice in OnlineUsers.
			if not tConfig.bAutoRejoin then
				oRoom.tAllUsers[ tUser.sNick ] = nil
				for i,v in pairs( oRoom.tAllUsers ) do
					v = v - 1;
				end
			end
			for i, v in ipairs( tOnlineUsers ) do										--don't know how I feel about this, could get spammy
				Core.SendPmToUser( v, oRoom.sNick, tUser.sNick .. " has left the hub.\124" )
			end
		end
	end
end

OpDisconnected, RegDisconnected = UserDisconnected, UserDisconnected

function ChatArrival( tUser, sData )
	local nInitIndex = #tUser.sNick + 4
	if sData:match( sPre, nInitIndex ) then
		local sCmd = sData:match( "^(%w+)", nInitIndex + 1 )
		if sCmd then
			sCmd = sCmd:lower( )
			if tCommandArrivals[ sCmd ] then
				local sMsg
				if nInitIndex + #sCmd <= #sData + 1 then sMsg = sData:sub( nInitIndex + #sCmd + 2 ) end
				return ExecuteCommand( tUser, sMsg, sCmd )
			else
				return false
			end
		end
	end
end		

function ToArrival( tUser, sData )				--#nomulti
	local sToUser = sData:match( "^(%S+)", 6 )										--Capture begins at the 6th char, ends at the first space after the 1st non-space character. Receiving user, per nmdc prot.
	local nInitIndex = #sToUser + 18 + #tUser.sNick * 2								--A bit of math to mark the first character of the actual message sent
	sim.hook_ToArrival( tUser, sData, sToUser, nInitIndex )							--sim will listen for messages sent to Botname registered to it on startup. see sim.hook_ToArrival
	if sData:match( sPre, nInitIndex ) then						 					--Uses our premade pattern match to see if the first char of the message is a prefix.
		local sCmd = sData:match( "^(%w+)", nInitIndex + 1 ) 	 					--It is, so, we capture alphanumeric matches immediately following said prefix.
		if sCmd then 																--was someone just shouting expletives?
			sCmd = sCmd:lower( ) 													--again users shouldnt have to worry about case.
			if tCommandArrivals[ sCmd ] then 										--checks all available commands
				if tCommandArrivals[ sCmd ].Permissions[ tUser.iProfile ] then 
					local sMsg = "";
					if ( nInitIndex + #sCmd + 2 ) < #sData then 
						sMsg = sData:sub( nInitIndex + #sCmd + 2 );
					end
					return ExecuteCommand( tUser, sMsg, sCmd, true ); 				--per usual we let ExectueCommand do the job of passing the command its arguments and passing back its returns.
				else
					return Core.SendPmToUser( tUser, tMail[1],  "*** Permission denied.\124" ), true;
				end
			end
		end
	end
	for _, oRoom in ipairs( tRooms ) do
		if sToUser == oRoom.sBotNick and oRoom.tAllUsers[ tUser.sNick ] then
			local sMessage = " From: " .. oRoom.sNick .. sData:sub( nInitIndex - #tUser.sNick - 5 )
			for i, v in ipairs( tOnlineUsers ) do
				if v.sNick ~= tUser.sNick then
					Core.SendToUser( v, "$To: " .. v.sNick .. sMessage )
				end
			end
		end
end

----------------------------------------------------------------------------
----------------------------------------------------------------------------
function ExecuteCommand( tUser, sMsg, sCmd, bInPM )
	local bRet, sRetMsg, bInPM, sFrom = tCommandArrivals[ sCmd ]:Action( tUser, sMsg );
	if sRetMsg then
		if bInPM then
			if sFrom then
				return Core.SendPmToUser( tUser, sFrom, sRetMsg ), true;
			else
				return Core.SendPmToUser( tUser, tConfig.sNick, sRetMsg ), true;
			end
		else
			if sFrom then
				return Core.SendToUser( tUser, "<" .. sFrom .. "> " .. sRetMsg ), true;
			else
				return Core.SendToUser( tUser, "<" .. tConfig.sNick "> "  .. sRetMsg ), true;
			end
		end
	else
		return bRet;
	end
end
----------------------------------------------------------------------------
----------------------------------------------------------------------------

