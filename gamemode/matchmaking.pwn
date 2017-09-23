#include <a_samp>

#include "../include/foreach.inc"

#include "forcefield.pwn"
#include "inventory.pwn"
#include "spectate.pwn"

#define MAP_TEXT_DRAW_STRING \
	"MAP: Original Battlegrounds"

#define MIN_PLAYERS \
	7
	
#define COUNT_DOWN \
	30
	
#define COLOR_YELLOW \
	0xFFDD00FF
#define COL_YELLOW \
	"{FFDD00}"
	
new Iterator:PLAYERS<MAX_PLAYERS>;

enum
{
	GAME_STATE_WAITING,
	GAME_STATE_STARTED_COUNTDOWN,
	GAME_STATE_IN_PROGRESS,
	GAME_STATE_FINISHED
};
new gameState;
new gameTimer;
new gameCountDown;

new Text:gameProgressTextDraw[6];
new Text:gameAnnouncementTextDraw;

new playerSpectatingID[MAX_PLAYERS];

new airplaneObjects[8];
new airplanePickups[6];
new airplaneCheckpoints[2];
new airplaneEjectionTimer;
new const Float:AIRPLANE_SPAWNS[][4] =
{
	{-448.0642, -2506.2397, 499.7656, 180.5720},
	{-440.7981, -2505.9656, 499.7702, 188.4915},
	{-448.3781, -2522.6348, 499.7708, 177.3993},
	{-440.9725, -2519.1389, 499.7656, 161.6072},
	{-444.2775, -2512.9321, 499.7693, 181.5354}
};
new bool:playerEjected[MAX_PLAYERS];

#if defined OnGameStart
	forward OnGameStart();
#endif

#if defined OnGameFinish
	forward OnGameFinish();
#endif

IsGameFinished()
{
    return (gameState == GAME_STATE_FINISHED);
}

Float:floatrandom(Float:max)
{
	return floatmul(floatdiv(float(random(cellmax)), float(cellmax - 1)), max);
}

GetRandomSpawn(Float:minx, Float:miny, Float:maxx, Float:maxy, &Float:x, &Float:y)
{
	x = floatrandom(floatsqroot(floatpower((minx - maxx), 2))) + minx;
	y = floatrandom(floatsqroot(floatpower((miny - maxy), 2))) + miny;
}

ShowPlayerTextDraws(playerid)
{
    switch (gameState)
	{
		case GAME_STATE_WAITING, GAME_STATE_STARTED_COUNTDOWN:
	    {
	        for (new i; i < sizeof gameProgressTextDraw; i++)
	        {
	        	TextDrawHideForPlayer(playerid, gameProgressTextDraw[i]);
			}
  			TextDrawShowForPlayer(playerid, gameAnnouncementTextDraw);
	    }
	    
		case GAME_STATE_IN_PROGRESS:
	    {
	        for (new i; i < sizeof gameProgressTextDraw; i++)
	        {
	        	TextDrawShowForPlayer(playerid, gameProgressTextDraw[i]);
			}
  			TextDrawHideForPlayer(playerid, gameAnnouncementTextDraw);
	    }
	    
		case GAME_STATE_FINISHED:
	    {
	        for (new i; i < sizeof gameProgressTextDraw; i++)
	        {
	        	TextDrawHideForPlayer(playerid, gameProgressTextDraw[i]);
			}
  			TextDrawShowForPlayer(playerid, gameAnnouncementTextDraw);
	    }
	}
}

public OnGameModeInit()
{
    gameState = GAME_STATE_WAITING;
    gameTimer = SetTimer("OnGameModeUpdate", 1000, true);
    gameCountDown = 0;
    
    #if defined OnGameStart
        OnGameStart();
	#endif



    gameProgressTextDraw[0] = TextDrawCreate(280.000000, 2.000000, "LD_GRAV:TIMER");
	TextDrawBackgroundColor(gameProgressTextDraw[0], 255);
	TextDrawFont(gameProgressTextDraw[0], 4);
	TextDrawLetterSize(gameProgressTextDraw[0], 0.500000, 1.000000);
	TextDrawColor(gameProgressTextDraw[0], -1);
	TextDrawSetOutline(gameProgressTextDraw[0], 0);
	TextDrawSetProportional(gameProgressTextDraw[0], 1);
	TextDrawSetShadow(gameProgressTextDraw[0], 1);
	TextDrawUseBox(gameProgressTextDraw[0], 1);
	TextDrawBoxColor(gameProgressTextDraw[0], 255);
	TextDrawTextSize(gameProgressTextDraw[0], 24.000000, 24.000000);
	TextDrawSetSelectable(gameProgressTextDraw[0], 0);

	gameProgressTextDraw[1] = TextDrawCreate(303.000000, 3.000000, "TIME ELAPSED:");
	TextDrawBackgroundColor(gameProgressTextDraw[1], 255);
	TextDrawFont(gameProgressTextDraw[1], 1);
	TextDrawLetterSize(gameProgressTextDraw[1], 0.170000, 0.799997);
	TextDrawColor(gameProgressTextDraw[1], -1);
	TextDrawSetOutline(gameProgressTextDraw[1], 1);
	TextDrawSetProportional(gameProgressTextDraw[1], 1);
	TextDrawSetSelectable(gameProgressTextDraw[1], 0);

	gameProgressTextDraw[2] = TextDrawCreate(303.000000, 10.000000, "0:31");
	TextDrawBackgroundColor(gameProgressTextDraw[2], 255);
	TextDrawFont(gameProgressTextDraw[2], 1);
	TextDrawLetterSize(gameProgressTextDraw[2], 0.280000, 1.499997);
	TextDrawColor(gameProgressTextDraw[2], -1);
	TextDrawSetOutline(gameProgressTextDraw[2], 1);
	TextDrawSetProportional(gameProgressTextDraw[2], 1);
	TextDrawSetSelectable(gameProgressTextDraw[2], 0);

    gameProgressTextDraw[3] = TextDrawCreate(5.000000, 429.000000, MAP_TEXT_DRAW_STRING);
	TextDrawBackgroundColor(gameProgressTextDraw[3], 255);
	TextDrawFont(gameProgressTextDraw[3], 1);
	TextDrawLetterSize(gameProgressTextDraw[3], 0.280000, 1.599997);
	TextDrawColor(gameProgressTextDraw[3], -1);
	TextDrawSetOutline(gameProgressTextDraw[3], 1);
	TextDrawSetProportional(gameProgressTextDraw[3], 1);
	TextDrawSetSelectable(gameProgressTextDraw[3], 0);

	gameProgressTextDraw[4] = TextDrawCreate(42.000000, 272.000000, "Alive: -");
	TextDrawBackgroundColor(gameProgressTextDraw[4], 255);
	TextDrawFont(gameProgressTextDraw[4], 1);
	TextDrawLetterSize(gameProgressTextDraw[4], 0.280000, 1.599997);
	TextDrawColor(gameProgressTextDraw[4], -1);
	TextDrawSetOutline(gameProgressTextDraw[4], 1);
	TextDrawSetProportional(gameProgressTextDraw[4], 1);
	TextDrawSetSelectable(gameProgressTextDraw[4], 0);

	gameProgressTextDraw[5] = TextDrawCreate(42.000000, 286.000000, "In Que: -");
	TextDrawBackgroundColor(gameProgressTextDraw[5], 255);
	TextDrawFont(gameProgressTextDraw[5], 1);
	TextDrawLetterSize(gameProgressTextDraw[5], 0.280000, 1.599997);
	TextDrawColor(gameProgressTextDraw[5], -1);
	TextDrawSetOutline(gameProgressTextDraw[5], 1);
	TextDrawSetProportional(gameProgressTextDraw[5], 1);
	TextDrawSetSelectable(gameProgressTextDraw[5], 0);





    gameAnnouncementTextDraw = TextDrawCreate(319.000000, 287.000000, "-");
	TextDrawAlignment(gameAnnouncementTextDraw, 2);
	TextDrawBackgroundColor(gameAnnouncementTextDraw, 255);
	TextDrawFont(gameAnnouncementTextDraw, 2);
	TextDrawLetterSize(gameAnnouncementTextDraw, 0.300000, 1.899999);
	TextDrawColor(gameAnnouncementTextDraw, 297271295);
	TextDrawSetOutline(gameAnnouncementTextDraw, 1);
	TextDrawSetProportional(gameAnnouncementTextDraw, 1);
	TextDrawSetSelectable(gameAnnouncementTextDraw, 0);
	
	
	
	
	airplaneObjects[0] = CreateObject(3068, -444.23911, -2496.41650, 500.00000,   0.00000, 0.00000, 0.00000);
	airplaneObjects[1] = CreateObject(3068, -444.23911, -2532.41650, 500.00000,   0.00000, 0.00000, 180.00000);
	airplaneObjects[2] = CreateObject(19463, -439.09921, -2514.55029, 500.34119,   0.00000, 0.00000, 0.00000);
	airplaneObjects[3] = CreateObject(19463, -446.13873, -2514.43921, 498.66919,   0.00000, 90.00000, 0.00000);
	airplaneObjects[4] = CreateObject(19463, -442.59280, -2514.40161, 498.66919,   0.00000, 90.00000, 0.00000);
	airplaneObjects[5] = CreateObject(19463, -447.78690, -2514.42896, 498.66919,   0.00000, 90.00000, 0.00000);
	airplaneObjects[6] = CreateObject(19463, -440.74567, -2514.54150, 498.66919,   0.00000, 90.00000, 0.00000);
	airplaneObjects[7] = CreateObject(19463, -449.34787, -2514.53149, 500.34119,   0.00000, 0.00000, 0.00000);

	airplanePickups[0] = CreatePickup(371, 1, -447.7282, -2514.3511, 499.7551);
	airplanePickups[1] = CreatePickup(371, 1, -447.6532, -2526.2283, 499.7693);
	airplanePickups[2] = CreatePickup(371, 1, -440.4853, -2514.3149, 499.7551);
	airplanePickups[3] = CreatePickup(371, 1, -441.0576, -2526.4932, 499.7656);
	airplanePickups[4] = CreatePickup(371, 1, -447.5696, -2502.9143, 499.7656);
	airplanePickups[5] = CreatePickup(371, 1, -440.7872, -2502.0117, 499.7692);

    airplaneCheckpoints[0] = CreateDynamicRaceCP(1, -444.3222, -2528.9590, 499.7656, 0.0, 0.0, 0.0, 2.0);
    airplaneCheckpoints[1] = CreateDynamicRaceCP(1, -444.1135, -2499.5623, 499.7656, 0.0, 0.0, 0.0, 2.0);
	
	#if defined MM_OnGameModeInit
		return MM_OnGameModeInit();
	#else
		return 1;
	#endif
}
#if defined _ALS_OnGameModeInit
	#undef OnGameModeInit
#else
	#define _ALS_OnGameModeInit
#endif
#define OnGameModeInit MM_OnGameModeInit
#if defined MM_OnGameModeInit
	forward MM_OnGameModeInit();
#endif

public OnGameModeExit()
{
	KillTimer(gameTimer);

	TextDrawDestroy(gameAnnouncementTextDraw);
	
	ForceField_Exit();
	
	Inv_RemoveAllItems();

	for (new i; i < sizeof airplaneObjects; i++)
	{
	    DestroyObject(airplaneObjects[i]);
	}
	for (new i; i < sizeof airplanePickups; i++)
	{
	    DestroyPickup(airplanePickups[i]);
	}
	for (new i; i < sizeof airplaneCheckpoints; i++)
	{
	    DestroyDynamicCP(airplaneCheckpoints[i]);
	}
	KillTimer(airplaneEjectionTimer);

	#if defined MM_OnGameModeExit
		return MM_OnGameModeExit();
	#else
		return 1;
	#endif
}
#if defined _ALS_OnGameModeExit
	#undef OnGameModeExit
#else
	#define _ALS_OnGameModeExit
#endif
#define OnGameModeExit MM_OnGameModeExit
#if defined MM_OnGameModeExit
	forward MM_OnGameModeExit();
#endif

public OnPlayerDisconnect(playerid, reason)
{
	Iter_Remove(PLAYERS, playerid);

	#if defined MM_OnPlayerDisconnect
		return MM_OnPlayerDisconnect(playerid, reason);
	#else
		return 1;
	#endif
}
#if defined _ALS_OnPlayerDisconnect
	#undef OnPlayerDisconnect
#else
	#define _ALS_OnPlayerDisconnect
#endif
#define OnPlayerDisconnect MM_OnPlayerDisconnect
#if defined MM_OnPlayerDisconnect
	forward MM_OnPlayerDisconnect(playerid, reason);
#endif

forward OnGameModeUpdate();
public OnGameModeUpdate()
{
	switch (gameState)
	{
		case GAME_STATE_WAITING:
		{
			gameCountDown++;

			new string[128];
			format(string, sizeof string, "Waiting for %i more players...~n~Time elapsed - %02i:%02i", (MIN_PLAYERS - Iter_Count(PLAYERS)), (gameCountDown / 60), (gameCountDown % 60));
			TextDrawSetString(gameAnnouncementTextDraw, string);

			if (Iter_Count(PLAYERS) >= MIN_PLAYERS)
			{
				gameCountDown = COUNT_DOWN;
				gameState = GAME_STATE_STARTED_COUNTDOWN;

				foreach (new i : Player)
				{
					if (GetPVarInt(i, "LoggedIn") == 1)
					{
						for (new x; x < 100; x++)
						{
							SendClientMessage(i, -1, "");
						}
						SendClientMessage(i, COLOR_YELLOW, "___________________");
						SendClientMessage(i, COLOR_YELLOW, "");
						SendClientMessage(i, COLOR_YELLOW, "About To Start!");
						SendClientMessage(i, COLOR_YELLOW, "Your mission is to elimiate every other survivor untill you are the last man alive.");
						SendClientMessage(i, COLOR_YELLOW, "If you are in a group, make sure your group is the last alive one. For group menu, type /group (you can only create groups before game begins).");
						SendClientMessage(i, COLOR_YELLOW, "");
						SendClientMessage(i, COLOR_YELLOW, "___________________");

						ShowPlayerTextDraws(i);

						SetPlayerHealth(i, FLOAT_INFINITY);
						SetPlayerArmour(i, 0.0);
					}
				}
			}
		}

		case GAME_STATE_STARTED_COUNTDOWN:
		{
			new string[128];
			format(string, sizeof string, "A new game will start in %i...", gameCountDown);
			TextDrawSetString(gameAnnouncementTextDraw, string);

			gameCountDown--;
			if (gameCountDown <= 0)
			{
				gameCountDown = 0;
				gameState = GAME_STATE_IN_PROGRESS;

				new r;
				foreach (new i : PLAYERS)
				{
					for (new x; x < 100; x++)
					{
						SendClientMessage(i, -1, "");
					}
					SendClientMessage(i, COLOR_YELLOW, "___________________");
					SendClientMessage(i, COLOR_YELLOW, "");
					SendClientMessage(i, COLOR_YELLOW, "Game In Progress!");
					SendClientMessage(i, COLOR_YELLOW, "The match has begun, good luck. To open your inventory press \"Y\" and to pickup item, press \"N\" close to it.");
					SendClientMessage(i, COLOR_YELLOW, "");
					SendClientMessage(i, COLOR_YELLOW, "___________________");

					ShowPlayerTextDraws(i);

					SetPlayerInterior(i, 0);
					
					r = random(sizeof AIRPLANE_SPAWNS);
					SetPlayerPos(i, AIRPLANE_SPAWNS[r][0], AIRPLANE_SPAWNS[r][1], AIRPLANE_SPAWNS[r][2]);
					SetPlayerFacingAngle(i, AIRPLANE_SPAWNS[r][3]);
					playerEjected[i] = false;
					
					GameTextForPlayer(i, "~w~Be sure to grab a parachute!", 5000, 3);
				}

				ForceField_Init(355.0, -1079.0, 2860.0, 513.0, 582.0, -990.0, 2684.0, 390.0);

				Inv_LoadItemsFromDatabase("database.db");
				
				airplaneEjectionTimer = SetTimer("OnEjectionTimeExpire", 30000, false);
				return 1;
			}

			if (Iter_Count(PLAYERS) < MIN_PLAYERS)
			{
				gameCountDown = 0;
				gameState = GAME_STATE_WAITING;

				Iter_Clear(PLAYERS);
				foreach (new i : Player)
				{
					if (GetPVarInt(i, "LoggedIn") == 1)
					{
						Iter_Add(PLAYERS, i);

						for (new x; x < 100; x++)
						{
							SendClientMessage(i, -1, "");
						}
						SendClientMessage(i, COLOR_YELLOW, "___________________");
						SendClientMessage(i, COLOR_YELLOW, "");
						SendClientMessage(i, COLOR_YELLOW, "Waiting For Player!");
						SendClientMessage(i, COLOR_YELLOW, "The game will start as soon as there are enough players to start the game. Minimum players required: "#MIN_PLAYERS".");
						SendClientMessage(i, COLOR_YELLOW, "");
						SendClientMessage(i, COLOR_YELLOW, "___________________");

						ShowPlayerTextDraws(i);

						ResetPlayerWeapons(i);
						SetPlayerHealth(i, FLOAT_INFINITY);
						SetPlayerArmour(i, 0.0);
					}
				}
			}
		}

		case GAME_STATE_IN_PROGRESS:
		{
			new string[128];
			format(string, sizeof string, "%02i:%02i", (gameCountDown / 60), (gameCountDown % 60));
			TextDrawSetString(gameProgressTextDraw[2], string);

			format(string, sizeof string, "Alive: %i", Iter_Count(PLAYERS));
			TextDrawSetString(gameProgressTextDraw[4], string);

			format(string, sizeof string, "~w~Players In Que: %i", (Iter_Count(Player) - Iter_Count(PLAYERS)));
			TextDrawSetString(gameProgressTextDraw[5], string);

			gameCountDown++;

			if (Iter_Count(PLAYERS) <= 1)
			{
				gameState = GAME_STATE_FINISHED;

				if (Iter_Count(PLAYERS) == 1)
				{
					new name[MAX_PLAYER_NAME];
					GetPlayerName(Iter_First(PLAYERS), name, MAX_PLAYER_NAME);

					format(string, sizeof string, "~y~%s ~w~won the game!~n~~w~Starting new game in 10 seconds...", name);
					TextDrawSetString(gameAnnouncementTextDraw, string);

					format(string, sizeof string, "%s won the game! Starting a new game in 10 seconds!", name);
				}
				else
				{
					TextDrawSetString(gameAnnouncementTextDraw, "~r~No winner!~n~~w~Starting new game in 10 seconds...");
					format(string, sizeof string, "No winner! Starting a new game in 10 seconds!");
				}

				foreach (new i : Player)
				{
					if (GetPVarInt(i, "LoggedIn") == 1)
					{
						for (new x; x < 100; x++)
						{
							SendClientMessage(i, -1, "");
						}
						SendClientMessage(i, COLOR_YELLOW, "___________________");
						SendClientMessage(i, COLOR_YELLOW, "");
						SendClientMessage(i, COLOR_YELLOW, string);
						SendClientMessage(i, COLOR_YELLOW, "A new game will begin in few seconds, hang in there!");
						SendClientMessage(i, COLOR_YELLOW, "");
						SendClientMessage(i, COLOR_YELLOW, "___________________");

						if (GetPlayerState(i) == PLAYER_STATE_SPECTATING)
						{
							TogglePlayerSpectating(i, false);
						}

						SetPlayerCameraPos(i, -144.2838, 1244.2357, 35.6595);
						SetPlayerCameraLookAt(i, -144.2255, 1243.2335, 35.3393);

						ShowPlayerTextDraws(i);
					}
				}

				ForceField_Exit();

				Inv_RemoveAllItems();
				
				KillTimer(airplaneEjectionTimer);

				#if defined OnGameFinish
				OnGameFinish();
				#endif

				SetTimer("OnGameModeFinish", 10000, false);
				KillTimer(gameTimer);
				return 1;
			}
		}
	}
	return 1;
}

forward OnGameModeFinish();
public OnGameModeFinish()
{
	gameState = GAME_STATE_WAITING;
    gameTimer = SetTimer("OnGameModeUpdate", 1000, true);
 	gameCountDown = 0;
 	
 	#if defined OnGameStart
        OnGameStart();
	#endif

    Iter_Clear(PLAYERS);
    
    foreach (new i : Player)
	{
 		if (GetPVarInt(i, "LoggedIn") == 1)
   		{
     		SpawnPlayer(i);
		}
	}
}

public OnPlayerSpawn(playerid)
{
    playerEjected[playerid] = false;
	playerSpectatingID[playerid] = INVALID_PLAYER_ID;
	
    ShowPlayerTextDraws(playerid);

	ResetPlayerWeapons(playerid);
	SetPlayerHealth(playerid, FLOAT_INFINITY);
	SetPlayerArmour(playerid, 0.0);

    switch (random(7))
    {
    	case 0: SetPlayerPos(playerid, 2220.8215,-1149.4452,1025.7969);
     	case 1: SetPlayerPos(playerid, 2221.6023,-1139.9663,1027.7969);
      	case 2: SetPlayerPos(playerid, 2227.1799,-1141.6085,1029.7969);
   		case 3: SetPlayerPos(playerid, 2232.9680,-1150.1281,1029.7969);
     	case 4: SetPlayerPos(playerid, 2241.6462,-1192.2533,1029.7969);
   		case 5: SetPlayerPos(playerid, 2236.2317,-1188.6218,1029.8043);
   		case 6: SetPlayerPos(playerid, 2245.2378,-1186.0424,1029.8043);
	}
	SetPlayerInterior(playerid, 15);
	
	switch (gameState)
	{
	    case GAME_STATE_WAITING:
	    {
   			Iter_Add(PLAYERS, playerid);

			SendClientMessage(playerid, COLOR_YELLOW, "___________________");
			SendClientMessage(playerid, COLOR_YELLOW, "");
			SendClientMessage(playerid, COLOR_YELLOW, "Waiting For Player!");
			SendClientMessage(playerid, COLOR_YELLOW, "The game will start as soon as there are enough players to start the game. Minimum players required: "#MIN_PLAYERS".");
			SendClientMessage(playerid, COLOR_YELLOW, "");
			SendClientMessage(playerid, COLOR_YELLOW, "___________________");
	    }
	    
	    case GAME_STATE_STARTED_COUNTDOWN:
	    {
   			Iter_Add(PLAYERS, playerid);

			SendClientMessage(playerid, COLOR_YELLOW, "___________________");
			SendClientMessage(playerid, COLOR_YELLOW, "");
			SendClientMessage(playerid, COLOR_YELLOW, "About To Start!");
			SendClientMessage(playerid, COLOR_YELLOW, "Your mission is to elimiate every other survivor untill you are the last man alive.");
			SendClientMessage(playerid, COLOR_YELLOW, "If you are in a group, you can win as a group if there is no other group left alive.");
			SendClientMessage(playerid, COLOR_YELLOW, "To loot items, press \"Y\" near them. For more game info. type /help.");
			SendClientMessage(playerid, COLOR_YELLOW, "");
			SendClientMessage(playerid, COLOR_YELLOW, "___________________");
	    }

	    case GAME_STATE_IN_PROGRESS:
	    {
			SendClientMessage(playerid, COLOR_YELLOW, "___________________");
			SendClientMessage(playerid, COLOR_YELLOW, "");
			SendClientMessage(playerid, COLOR_YELLOW, "Game In Progress!");
			SendClientMessage(playerid, COLOR_YELLOW, "You are late, so you cannot join an on-going game. For the mean time you can join the deathmatch mode (/deathmatch).");
			SendClientMessage(playerid, COLOR_YELLOW, "");
			SendClientMessage(playerid, COLOR_YELLOW, "___________________");
			
			// spectate mode
			TogglePlayerSpectating(playerid, true);
			if (playerSpectatingID[playerid] == INVALID_PLAYER_ID)
			{
			    playerSpectatingID[playerid] = Iter_Random(PLAYERS);
			}
			SetPlayerSpectating(playerid, playerSpectatingID[playerid]);
			
			printf("%i", Iter_Count(PLAYERS));
	    }

	    case GAME_STATE_FINISHED:
	    {
	        TogglePlayerControllable(playerid, false);

			SetPlayerCameraPos(playerid, -144.2838, 1244.2357, 35.6595);
			SetPlayerCameraLookAt(playerid, -144.2255, 1243.2335, 35.3393);

			new name[MAX_PLAYER_NAME];
			new string[128];
     		if (Iter_Count(PLAYERS) == 1)
			{
	            GetPlayerName(Iter_First(PLAYERS), name, MAX_PLAYER_NAME);
	            format(string, sizeof string, "%s won the game!", name);
            }
            else
            {
	            format(string, sizeof string, "No winner!");
            }
     		
			SendClientMessage(playerid, COLOR_YELLOW, "___________________");
			SendClientMessage(playerid, COLOR_YELLOW, "");
			SendClientMessage(playerid, COLOR_YELLOW, string);
			SendClientMessage(playerid, COLOR_YELLOW, "A new game will begin in few seconds, hang in there!");
			SendClientMessage(playerid, COLOR_YELLOW, "");
			SendClientMessage(playerid, COLOR_YELLOW, "___________________");
	    }
	}
	
	#if defined MM_OnPlayerSpawn
		return MM_OnPlayerSpawn(playerid);
	#else
		return 1;
	#endif
}
#if defined _ALS_OnPlayerSpawn
	#undef OnPlayerSpawn
#else
	#define _ALS_OnPlayerSpawn
#endif
#define OnPlayerSpawn MM_OnPlayerSpawn
#if defined MM_OnPlayerSpawn
	forward MM_OnPlayerSpawn(playerid);
#endif

public OnPlayerDeath(playerid, killerid, reason)
{
    playerSpectatingID[playerid] = INVALID_PLAYER_ID;
    
	Iter_Remove(PLAYERS, playerid);

	#if defined MM_OnPlayerDeath
		return MM_OnPlayerDeath(playerid, killerid, reason);
	#else
		return 1;
	#endif
}
#if defined _ALS_OnPlayerDeath
	#undef OnPlayerDeath
#else
	#define _ALS_OnPlayerDeath
#endif
#define OnPlayerDeath MM_OnPlayerDeath
#if defined MM_OnPlayerDeath
	forward MM_OnPlayerDeath(playerid, killerid, reason);
#endif

public OnPlayerKeyStateChange(playerid, newkeys, oldkeys)
{
	if (gameState == GAME_STATE_IN_PROGRESS)
	{
	    if (playerSpectatingID[playerid] != INVALID_PLAYER_ID)
		{
		    if (newkeys == KEY_LEFT)
		    {
                playerSpectatingID[playerid] = Iter_Prev(PLAYERS, playerSpectatingID[playerid]);
				SetPlayerSpectating(playerid, playerSpectatingID[playerid]);
		    }
		    else if (newkeys == /*KEY_AIM*/128)
		    {
                playerSpectatingID[playerid] = Iter_Next(PLAYERS, playerSpectatingID[playerid]);
				SetPlayerSpectating(playerid, playerSpectatingID[playerid]);
		    }
		}
	}

	#if defined MM_OnPlayerKeyStateChange
		return MM_OnPlayerKeyStateChange(playerid, newkeys, oldkeys);
	#else
		return 1;
	#endif
}
#if defined _ALS_OnPlayerKeyStateChange
	#undef OnPlayerKeyStateChange
#else
	#define _ALS_OnPlayerKeyStateChange
#endif
#define OnPlayerKeyStateChange MM_OnPlayerKeyStateChange
#if defined MM_OnPlayerKeyStateChange
	forward MM_OnPlayerKeyStateChange(playerid, newkeys, oldkeys);
#endif

public OnPlayerPickUpPickup(playerid, pickupid)
{
	for (new i; i < sizeof airplanePickups; i++)
	{
	    if (pickupid == airplanePickups[i])
	    {
	        GivePlayerWeapon(playerid, 46, 1);

			GameTextForPlayer(i, "~w~Parachute", 2000, 3);
	    }
	}
	
	#if defined MM_OnPlayerPickUpPickup
		return MM_OnPlayerPickUpPickup(playerid, pickupid);
	#else
		return 1;
	#endif
}
#if defined _ALS_OnPlayerPickUpPickup
	#undef OnPlayerPickUpPickup
#else
	#define _ALS_OnPlayerPickUpPickup
#endif
#define OnPlayerPickUpPickup MM_OnPlayerPickUpPickup
#if defined MM_OnPlayerPickUpPickup
	forward MM_OnPlayerPickUpPickup(playerid, pickupid);
#endif

forward OnEjectionTimeExpire();
public OnEjectionTimeExpire()
{
	foreach (new i : PLAYERS)
	{
	    if (!playerEjected[i])
		{
			new Float:spawnX, Float:spawnY;
			GetRandomSpawn(355.0, -1079.0, 2860.0, 513.0, spawnX, spawnY);
			SetPlayerPos(i, spawnX, spawnY, 700.0);

			playerEjected[i] = true;

			SetPlayerHealth(i, 100.0);
			SetPlayerArmour(i, 0.0);
			
			GameTextForPlayer(i, "~w~You had have to eject in 30 seconds!", 5000, 3);
		}
	}
}

public OnPlayerEnterDynamicRaceCP(playerid, checkpointid)
{
	if (checkpointid == airplaneCheckpoints[0] || checkpointid == airplaneCheckpoints[1])
	{
		new Float:spawnX, Float:spawnY;
		GetRandomSpawn(355.0, -1079.0, 2860.0, 513.0, spawnX, spawnY);
		SetPlayerPos(playerid, spawnX, spawnY, 700.0);
		
		playerEjected[playerid] = true;
		
		SetPlayerHealth(playerid, 100.0);
		SetPlayerArmour(playerid, 0.0);
		
		GameTextForPlayer(playerid, "~w~Good luck!", 2000, 3);
	}
	
	#if defined MM_OnPlayerEnterDynamicRaceCP
		return MM_OnPlayerEnterDynamicRaceCP(playerid, checkpointid);
	#else
		return 1;
	#endif
}
#if defined _ALS_OnPlayerEnterDynamicRaceCP
	#undef OnPlayerEnterDynamicRaceCP
#else
	#define _ALS_OnPlayerEnterDynamicRaceCP
#endif
#define OnPlayerEnterDynamicRaceCP MM_OnPlayerEnterDynamicRaceCP
#if defined MM_OnPlayerEnterDynamicRaceCP
	forward MM_OnPlayerEnterDynamicRaceCP(playerid, checkpointid);
#endif
