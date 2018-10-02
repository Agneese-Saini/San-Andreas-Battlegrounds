#include <a_samp>

#include <YSI\y_iterate>

new Text:spectateTextDraw[5];
new PlayerText:spectatePlayerTextDraw[MAX_PLAYERS];

new playerTargetID[MAX_PLAYERS];
new playerWorldID[MAX_PLAYERS];

public OnGameModeInit()
{
    spectateTextDraw[0] = TextDrawCreate(0.000000, 331.000000, "box");
	TextDrawBackgroundColor(spectateTextDraw[0], 255);
	TextDrawFont(spectateTextDraw[0], 2);
	TextDrawLetterSize(spectateTextDraw[0], 0.000000, 12.800003);
	TextDrawColor(spectateTextDraw[0], 297271295);
	TextDrawSetOutline(spectateTextDraw[0], 1);
	TextDrawSetProportional(spectateTextDraw[0], 1);
	TextDrawUseBox(spectateTextDraw[0], 1);
	TextDrawBoxColor(spectateTextDraw[0], 175);
	TextDrawTextSize(spectateTextDraw[0], 640.000000, 0.000000);
	TextDrawSetSelectable(spectateTextDraw[0], 0);

	spectateTextDraw[1] = TextDrawCreate(319.000000, 359.000000, "NOW SPECTATING:");
	TextDrawAlignment(spectateTextDraw[1], 2);
	TextDrawBackgroundColor(spectateTextDraw[1], 255);
	TextDrawFont(spectateTextDraw[1], 2);
	TextDrawLetterSize(spectateTextDraw[1], 0.300000, 1.899999);
	TextDrawColor(spectateTextDraw[1], 297271295);
	TextDrawSetOutline(spectateTextDraw[1], 1);
	TextDrawSetProportional(spectateTextDraw[1], 1);
	TextDrawSetSelectable(spectateTextDraw[1], 0);

	spectateTextDraw[2] = TextDrawCreate(199.000000, 359.000000, "<");
	TextDrawAlignment(spectateTextDraw[2], 2);
	TextDrawBackgroundColor(spectateTextDraw[2], 255);
	TextDrawFont(spectateTextDraw[2], 2);
	TextDrawLetterSize(spectateTextDraw[2], 0.300000, 1.899999);
	TextDrawColor(spectateTextDraw[2], 297271295);
	TextDrawSetOutline(spectateTextDraw[2], 1);
	TextDrawSetProportional(spectateTextDraw[2], 1);
	TextDrawSetSelectable(spectateTextDraw[2], 0);

	spectateTextDraw[3] = TextDrawCreate(429.000000, 359.000000, ">");
	TextDrawAlignment(spectateTextDraw[3], 2);
	TextDrawBackgroundColor(spectateTextDraw[3], 255);
	TextDrawFont(spectateTextDraw[3], 2);
	TextDrawLetterSize(spectateTextDraw[3], 0.300000, 1.899999);
	TextDrawColor(spectateTextDraw[3], 297271295);
	TextDrawSetOutline(spectateTextDraw[3], 1);
	TextDrawSetProportional(spectateTextDraw[3], 1);
	TextDrawSetSelectable(spectateTextDraw[3], 0);

	spectateTextDraw[4] = TextDrawCreate(319.000000, 402.000000, "Press ~k~~PED_FIREWEAPON~ or ~k~~PED_LOCK_TARGET~ to switch players to spectate.~n~Type /deathmatch to join deathmatch mode in the mean time game ends (12 players in dm)");
	TextDrawAlignment(spectateTextDraw[4], 2);
	TextDrawBackgroundColor(spectateTextDraw[4], 255);
	TextDrawFont(spectateTextDraw[4], 2);
	TextDrawLetterSize(spectateTextDraw[4], 0.180000, 1.199998);
	TextDrawColor(spectateTextDraw[4], -1);
	TextDrawSetOutline(spectateTextDraw[4], 1);
	TextDrawSetProportional(spectateTextDraw[4], 1);
	TextDrawSetSelectable(spectateTextDraw[4], 0);
	
	#if defined Spec_OnGameModeInit
		return Spec_OnGameModeInit();
	#else
		return 1;
	#endif
}
#if defined _ALS_OnGameModeInit
	#undef OnGameModeInit
#else
	#define _ALS_OnGameModeInit
#endif
#define OnGameModeInit Spec_OnGameModeInit
#if defined Spec_OnGameModeInit
	forward Spec_OnGameModeInit();
#endif

public OnGameModeExit()
{
    for (new i; i < sizeof spectateTextDraw; i++)
	{
	    TextDrawDestroy(spectateTextDraw[i]);
	}
	
	#if defined Spec_OnGameModeExit
		return Spec_OnGameModeExit();
	#else
		return 1;
	#endif
}
#if defined _ALS_OnGameModeExit
	#undef OnGameModeExit
#else
	#define _ALS_OnGameModeExit
#endif
#define OnGameModeExit Spec_OnGameModeExit
#if defined Spec_OnGameModeExit
	forward Spec_OnGameModeExit();
#endif

public OnPlayerConnect(playerid)
{
	playerTargetID[playerid] = INVALID_PLAYER_ID;
	
	spectatePlayerTextDraw[playerid] = CreatePlayerTextDraw(playerid,319.000000, 376.000000, "Gammix (0)");
	PlayerTextDrawAlignment(playerid,spectatePlayerTextDraw[playerid], 2);
	PlayerTextDrawBackgroundColor(playerid,spectatePlayerTextDraw[playerid], 255);
	PlayerTextDrawFont(playerid,spectatePlayerTextDraw[playerid], 2);
	PlayerTextDrawLetterSize(playerid,spectatePlayerTextDraw[playerid], 0.389999, 2.199997);
	PlayerTextDrawColor(playerid,spectatePlayerTextDraw[playerid], 297271295);
	PlayerTextDrawSetOutline(playerid,spectatePlayerTextDraw[playerid], 1);
	PlayerTextDrawSetProportional(playerid,spectatePlayerTextDraw[playerid], 1);
	PlayerTextDrawSetSelectable(playerid,spectatePlayerTextDraw[playerid], 0);
	
	#if defined Spec_OnPlayerConnect
	  	return Spec_OnPlayerConnect(playerid);
	#else
	   	return 1;
	#endif
}
#if defined _ALS_OnPlayerConnect
    #undef OnPlayerConnect
#else
    #define _ALS_OnPlayerConnect
#endif
#define OnPlayerConnect Spec_OnPlayerConnect
#if defined Spec_OnPlayerConnect
    forward Spec_OnPlayerConnect(playerid);
#endif

public OnPlayerUpdate(playerid)
{
	if (GetPlayerVirtualWorld(playerid) != playerWorldID[playerid])
	{
	    playerWorldID[playerid] = GetPlayerVirtualWorld(playerid);
	    
	    foreach (new i : Player)
	    {
	        if (i != playerid && GetPlayerState(i) == PLAYER_STATE_SPECTATING)
	        {
	            if (playerTargetID[i] == playerid)
	            {
	                SetPlayerVirtualWorld(i, playerWorldID[playerid]);
	            }
	        }
	    }
	}
	
	#if defined Spec_OnPlayerUpdate
 		return Spec_OnPlayerUpdate(playerid);
	#else
		return 1;
	#endif
}
#if defined _ALS_OnPlayerUpdate
	#undef OnPlayerUpdate
#else
    #define _ALS_OnPlayerUpdate
#endif
#define OnPlayerUpdate Spec_OnPlayerUpdate
#if defined Spec_OnPlayerUpdate
    forward Spec_OnPlayerUpdate(playerid);
#endif

public OnPlayerInteriorChange(playerid, newinteriorid, oldinteriorid)
{
    foreach (new i : Player)
    {
    	if (i != playerid && GetPlayerState(i) == PLAYER_STATE_SPECTATING)
	    {
	    	if (playerTargetID[i] == playerid)
      		{
                SetPlayerInterior(i, newinteriorid);
            }
        }
    }
	
	#if defined Spec_OnPlayerInteriorChange
	  	return Spec_OnPlayerInteriorChange(playerid, newinteriorid, oldinteriorid);
	#else
	   	return 1;
	#endif
}
#if defined _ALS_OnPlayerInteriorChange
    #undef OnPlayerInteriorChange
#else
    #define _ALS_OnPlayerInteriorChange
#endif
#define OnPlayerInteriorChange Spec_OnPlayerInteriorChange
#if defined Spec_OnPlayerInteriorChange
    forward Spec_OnPlayerInteriorChange(playerid, newinteriorid, oldinteriorid);
#endif

public OnPlayerStateChange(playerid, newstate, oldstate)
{
	if (GetPVarInt(playerid, "LoggedIn") == 1)
	{
		if (newstate == PLAYER_STATE_SPECTATING || newstate == PLAYER_STATE_WASTED)
		{
			foreach (new i : Player)
		    {
		    	if (i != playerid && GetPlayerState(i) == PLAYER_STATE_SPECTATING)
			    {
			    	if (playerTargetID[i] == playerid)
		      		{
		                TogglePlayerSpectating(i, false);
						playerTargetID[playerid] = INVALID_PLAYER_ID;
						
						for (new x; x < sizeof spectateTextDraw; x++)
						{
						    TextDrawHideForPlayer(playerid, spectateTextDraw[x]);
						}
						PlayerTextDrawHide(playerid, spectatePlayerTextDraw[playerid]);
		            }
		        }
		    }
	  	}
		else if (newstate == PLAYER_STATE_DRIVER || newstate == PLAYER_STATE_PASSENGER)
		{
			foreach (new i : Player)
		    {
		    	if (i != playerid && GetPlayerState(i) == PLAYER_STATE_SPECTATING)
			    {
			    	if (playerTargetID[i] == playerid)
		      		{
						PlayerSpectateVehicle(i, GetPlayerVehicleID(playerid), SPECTATE_MODE_NORMAL);
		            }
		        }
		    }
	  	}
		else if (newstate == PLAYER_STATE_ONFOOT)
		{
			foreach (new i : Player)
		    {
		    	if (i != playerid && GetPlayerState(i) == PLAYER_STATE_SPECTATING)
			    {
			    	if (playerTargetID[i] == playerid)
		      		{
						PlayerSpectatePlayer(i, playerid, SPECTATE_MODE_NORMAL);
		            }
		        }
		    }
		}
	}
	
	#if defined Spec_OnPlayerStateChange
       	return Spec_OnPlayerStateChange(playerid, newstate, oldstate);
	#else
	   	return 1;
	#endif
}
#if defined _ALS_OnPlayerStateChange
    #undef OnPlayerStateChange
#else
    #define _ALS_OnPlayerStateChange
#endif
#define OnPlayerStateChange Spec_OnPlayerStateChange
#if defined Spec_OnPlayerStateChange
    forward Spec_OnPlayerStateChange(playerid, newstate, oldstate);
#endif

stock Spec_TogglePlayerSpectating(playerid, bool:toggle)
{
	new bool:ret = bool:TogglePlayerSpectating(playerid, toggle);
	if (ret)
	{
	    if (playerTargetID[playerid] != INVALID_PLAYER_ID && !toggle)
	    {
	    	playerTargetID[playerid] = INVALID_PLAYER_ID;
	    	
			for (new i; i < sizeof spectateTextDraw; i++)
			{
			    TextDrawHideForPlayer(playerid, spectateTextDraw[i]);
			}
			PlayerTextDrawHide(playerid, spectatePlayerTextDraw[playerid]);
	    }
	}
	return ret;
}
#if defined _ALS_TogglePlayerSpectating
    #undef TogglePlayerSpectating
#else
    #define _ALS_TogglePlayerSpectating
#endif
#define TogglePlayerSpectating Spec_TogglePlayerSpectating

SetPlayerSpectating(playerid, targetplayerid)
{
	playerTargetID[playerid] = targetplayerid;
	
	SetPlayerInterior(playerid, GetPlayerInterior(targetplayerid));
	SetPlayerVirtualWorld(playerid, GetPlayerVirtualWorld(targetplayerid));

	if (IsPlayerInAnyVehicle(targetplayerid))
	{
		PlayerSpectateVehicle(playerid, GetPlayerVehicleID(targetplayerid), SPECTATE_MODE_NORMAL);
	}
	else
	{
	    PlayerSpectatePlayer(playerid, targetplayerid, SPECTATE_MODE_NORMAL);
	}

	new name[MAX_PLAYER_NAME + 5];
	GetPlayerName(targetplayerid, name, MAX_PLAYER_NAME);
	format(name, sizeof name, "%s(%i)", name, playerid);
	PlayerTextDrawSetString(playerid, spectatePlayerTextDraw[playerid], name);
	
	for (new i; i < sizeof spectateTextDraw; i++)
	{
	    TextDrawShowForPlayer(playerid, spectateTextDraw[i]);
	}
	PlayerTextDrawShow(playerid, spectatePlayerTextDraw[playerid]);
	return 1;
}
