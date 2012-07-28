--[[
	Simple Interactive Mod[ul]e made by amenay for PtokaX.
	Version: 2.1.0
--]]
assert( Core, "A minimum version of 0.4.0.0 is required to run this module." );
module( ..., package.seeall );

buggyTo = true; --For clients that drop incoming messages without <user> before message.
err2out = true; --Redirects stderr to stdout for cmdmode

local _PROMPT;
local _CMDPROMPT
local OS;

local tSettings = { {} };
local tUsers = {
	tInteractive = { };
	tCMD = { };
	tMerged = { };
}

setmetatable( tUsers.tMerged, { --This is to cleanup some code, but it ends up making print more expensive, another solution is in order.
	__index = function( t, k )
		return tUsers.tInteractive[ k ] or tUsers.tCMD[ k ];
	end 
} )
	
if os.getenv( "PATH" ):sub( 1, 1 ) == "/" then
	OS = "Unix/Unix-Like"
else
	OS = "Windows"
end	

--General use functions.
print =
	buggyTo and function( ... )  
		local tBuff = { };
		local tostring = tostring;
		for _, v in ipairs { ... }  do
			tBuff[ #tBuff + 1 ] = tostring( v );
		end
		local SendMethod = SendMethod or function( sData )
			if tActualUser then
				Core.SendToUser( tActualUser, "$To: " .. tActualUser.sNick .. " From: " .. tSettings[2] .. " $<" .. tSettings[2] .. "> " .. sData );
			end
		end
		SendMethod( table.concat( tBuff, "\t\t" ) );
	end
	
	or
	
	function( ... )  
		local tBuff = { };
		local tostring = tostring;
		for _, v in ipairs { ... }  do
			tBuff[ #tBuff + 1 ] = tostring( v );
		end
		local SendMethod = SendMethod or function( sData )
			if tActualUser then
				Core.SendToUser( tActualUser, "$To: " .. tActualUser.sNick .. " From: " .. tSettings[2] .. " $" .. sData );
			end
		end
		SendMethod( table.concat( tBuff, "\t\t" ) );
	end


function macro( alias, default_cmd )
	local sPath = not alias and Core.GetPtokaXPath();
	local default_cmd = default_cmd or "cat ";
	local alias = alias or {
			scriptlog = "'" .. sPath .. "logs/script.log'" ;
			scriptdoc = "'" .. sPath .. "scripting.docs/scripting-interface.txt'";
			myself = "'" .. sPath .. "scripts/" .. ScriptMan.GetScript().sName .. "'";
	};
	return function( sMacro, cmd, ... )
		sMacro = alias[ sMacro ] or ( sMacro or "/dev/null" );
		if type( cmd ) == "function" or not cmd and type( default_cmd ) == "function" then
			print( cmd( sMacro, ... ):gsub( "\124", "&#124" ) );
		else -- Todo: clean up checks on types of default_cmd and cmd
			cmd = ( type( cmd ) == "string" and cmd ) or ( type( default_cmd ) == "string" and default_cmd );
			local fData, sError = io.popen( cmd .. sMacro .. table.concat( { ... }, " " ) );
			if fData then -- Todo: Allow specification of method and mode of popen
				local sContents = "\n" .. fData:read( "*a" ):gsub( "\124", "&#124" );
				print( sContents );
				fData:close();
			else
				error( sError );
			end
		end
	end
end

function getlines( fn, i, j )--tail-like function which accepts ranges
	local buff = {};
	local f = assert( io.open( fn, "r" ), "Error: " .. fn .. " does not exist." );
	for line in f:lines() do buff[ #buff + 1 ] = line end;
	f:close();
	local bufflen = #buff;
	if j then
		i, j = i or 1, ( -bufflen <= j and j < 0 ) and bufflen + j + 1 or j;
	else
		i, j = i or ( bufflen > 10 and bufflen - 9 ) or 1, bufflen;
	end
	assert( not( i < -bufflen or j < -bufflen ), "index out of range. Line count: " .. bufflen );
	return table.concat( buff, "\n", i > 0 and i or bufflen + i + 1 , j );
end
---
function printfunc( name )
	local frec = debug.getinfo( name, "S" );
	if frec.short_src:sub( 1, 7 ) == "[string" then
		print( frec.short_src:sub( 10, -3 ) );
		return;
	end
	print( "\n" .. getlines( frec.short_src, frec.linedefined, frec.lastlinedefined ):gsub( "\124", "&#124;" ) );
end
-- Interpretation mode control
function imode( tUser )
	if tUsers.tInteractive[ tUser.uptr ] then
		tUsers.tInteractive[ tUser.uptr ] = nil;
		return Core.SendPmToUser( tUser, tSettings[2], "*** Leaving interactive mode.\124" );
	else
		tUsers.tInteractive[ tUser.uptr ] = tUser;
		return Core.SendPmToUser( tUser, tSettings[2], "*** Entering interactive mode. Type imode( ... ) to end.\124$To: " .. tUser.sNick ..
			" From: " .. tSettings[2] .. " $" .. _PROMPT );
	end
end

function cmdmode( tUser )
	if tUsers.tCMD[ tUser.uptr ] then
		tUsers.tCMD[ tUser.uptr ] = nil;
		return Core.SendPmToUser( tUser, tSettings[2], tUsers.tInteractive[ tUser.uptr ] and "*** Exiting cmdmode re-entering imode, type imode( ... ) to end.\124"
			.. _PROMPT or ( buggyTo and "<" .. tSettings[2] .. "> *** Exiting cmdmode.\124" or "*** Exiting cmdmode.\124" ) );
	else
		tUsers.tCMD[ tUser.uptr ] = tUser;
		return Core.SendPmToUser( tUser, tSettings[2], "*** Entering command mode. Type cmdmode to exit.\124$To: " .. tUser.sNick ..
			" From: " .. tSettings[2] .. " $" .. _CMDPROMPT );
	end
end
-- Event hooks
hook_OnError = print;

function hook_OnExit()
	print "Interactive or command mode interrupted by script exit.\124";
end

function hook_OnStartup( tBot, tAdmins ) --Doesn't run any checks on its arguments.
	for i, v in ipairs( tAdmins ) do
		tSettings[1][v] = ( RegMan.GetReg( v ) or {} ).sPassword;
	end
	tActualUser = Core.GetUser( tAdmins[1] );
	tSettings[2] = tBot[1];
	_PROMPT = buggyTo and "<" .. tSettings[2] .. "> Interactive mode >\124" or "Interactive mode >\124";
	_CMDPROMPT = buggyTo and "<" .. tSettings[2] .. "> cmd >\124" or "cmd >\124";
	return Core.RegBot( unpack( tBot ) );
end


function hook_UserDisconnected( tUser )
	if tUsers.tInteractive[ tUser.uptr ] or tUsers.tCMD[ tUser.uptr ] then
		tUsers.tInteractive[ tUser.uptr ] = nil;
		tUsers.tCMD[ tUser.uptr ] = nil;
	end
end

function hook_ToArrival( tUser, sData, sToUser, nInitIndex  )
	local sToUser = sToUser or sData:match( "^(%S+)", 6 );
	if sToUser == tSettings[2] and tSettings[1][ tUser.sNick ] then
		local nInitIndex = nInitIndex or #sToUser + 18 + #tUser.sNick * 2;
		local sBody = sData:sub( nInitIndex, -2 );
		local tUsers, Core = tUsers, Core;
		if sBody == "cmdmode" then return cmdmode( tUser ) end;
		tActualUser = tUser;
		if tUsers.tCMD[ tUser.uptr ] then
			local sEcho = buggyTo and "$To: " .. tUser.sNick .. " From: " .. tSettings[2] .." \36<" .. tSettings[2] .. "> " .. sBody
				or "$To: " .. tUser.sNick .. " From: " .. tSettings[2] .." \36" .. sBody
			Core.SendToUser( tUser, sEcho );
			local fData, sError = err2out and io.popen( sBody .. " 2>&1" ) or io.popen( sBody ); --This is for PtokaX versions which support popen... There is an easy way that's more portable to implement with  os.execute using output redirection  (but that suffers from the overhead of writing to disk on top of running another program)
			if fData then
				print( "\n" .. fData:read "*a" );
				fData:close();
			else
				error( sError );
			end
			return Core.SendToUser( tUser, "\36To: " .. tUser.sNick .. " From: " .. tSettings[2] .." $" .. _CMDPROMPT );
		end

		if not tUsers.tInteractive[ tUser.uptr ] then
			if sBody == "imode" then
				return imode( tUser );
			end
		else
			local sEcho = buggyTo and "\36To: " .. tUser.sNick .. " From: " .. tSettings[2] .. " \36<" .. tSettings[2] .. ">\n" .. sBody
				or "\36To: " .. tUser.sNick .. " From: " .. tSettings[2] .. " \36\n" .. sBody;
			Core.SendToUser( tUser, sEcho );
			local foo = assert( loadstring( sBody ) );
			setfenv( foo, _M ); -- Todo: Either create a custom environment to privatize some of these functions, or create (a) function(s) to provide a global interface with them.
			local bStatus, ret = pcall( foo, tUser, sData );
			if tUsers.tInteractive[ tUser.uptr ] and not tUsers.tCMD[ tUser.uptr ] then
				Core.SendToUser( tUser, "\36To: " .. tUser.sNick .. " From: " .. tSettings[2] .. " \36" .. _PROMPT );
			end
			if bStatus then 
				return ret or bStatus;
			else
				return error( ret ), bStatus;
			end
		end
	end
end