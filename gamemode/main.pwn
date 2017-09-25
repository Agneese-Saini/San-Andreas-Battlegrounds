//a_samp

#include <a_samp>

// a_samp settings

#undef MAX_PLAYERS
#define MAX_PLAYERS \
	100
	
#undef MAX_VEHICLES
#define MAX_VEHICLES \
	100

// rcon settings

main()
{
	SetGameModeText("Deathmach - v1.0");
	SendRconCommand("maxplayers "#MAX_PLAYERS"");
}

// priority libraries

//#include "../include/lagcomp.inc"

#define ZMSG_HYPHEN_START \
	""
#define ZMSG_HYPHEN_END \
	"-"
#include "../include/zmessage.inc"

// gamemode dependencies

#include "matchmaking.pwn"

// other libraries (no placement priorities)

#include "../include/sscanf2.inc"
#include "../include/streamer.inc"

#include "../include/zcmd.inc"
#include "../include/easydialog.inc"
#include "../include/kickbanfix.inc"

// login/register settings

#define MAX_LOGIN_ATTEMPTS \
	3
#define MAX_ACCOUNT_LOCKTIME \
	2 // minutes

#define MIN_PASSWORD_LENGTH \
	4
#define MAX_PASSWORD_LENGTH \
	45

#define MAX_SECURITY_QUESTION_SIZE \
	128

// colors

#define COLOR_WHITE \
	0xFFFFFFFF
#define COL_WHITE \
	"{FFFFFF}"

#define COLOR_TOMATO \
	0xFF6347FF
#define COL_TOMATO \
	"{FF6347}"

#define COLOR_YELLOW \
	0xFFDD00FF
#define COL_YELLOW \
	"{FFDD00}"

#define COLOR_GREEN \
	0x00FF00FF
#define COL_GREEN \
	"{00FF00}"

#define COLOR_DEFAULT \
	0xA9C4E4FF
#define COL_DEFAULT \
	"{A9C4E4}"

// variables

new DB:db;

new Text:joinScreenTextDraw[11];
new PlayerText:joinScreenPlayerTextDraw[MAX_PLAYERS];

new const SECURITY_QUESTIONS[][MAX_SECURITY_QUESTION_SIZE] =
{
	"What was your childhood nickname?",
	"What is the name of your favorite childhood friend?",
	"In what city or town did your mother and father meet?",
	"What is the middle name of your oldest child?",
	"What is your favorite team?",
	"What is your favorite movie?",
	"What is the first name of the boy or girl that you first kissed?",
	"What was the make and model of your first car?",
	"What was the name of the hospital where you were born?",
	"Who is your childhood sports hero?",
	"In what town was your first job?",
	"What was the name of the company where you had your first job?",
	"What school did you attend for sixth grade?",
	"What was the last name of your third grade teacher?"
};

enum E_PLAYER_DATA
{
	E_PLAYER_DATA_SQLID,
	E_PLAYER_DATA_PASSWORD[64 + 1],
	E_PLAYER_DATA_SALT[64 + 1],
	E_PLAYER_DATA_KILLS,
	E_PLAYER_DATA_DEATHS,
	E_PLAYER_DATA_SCORE,
	E_PLAYER_DATA_MONEY,
	E_PLAYER_DATA_REG_TIMESTAMP,
	E_PLAYER_DATA_LASTLOG_TIMESTAMP,
	E_PLAYER_DATA_SEC_QUESTION[MAX_SECURITY_QUESTION_SIZE],
	E_PLAYER_DATA_SEC_ANSWER[64 + 1]
};
new playerData[MAX_PLAYERS][E_PLAYER_DATA];

new playerLoginAttempts[MAX_PLAYERS];
new playerAnswerAttempts[MAX_PLAYERS];

new playerInJoinScreen[MAX_PLAYERS];

new PlayerText:killPlayerTextDraw[MAX_PLAYERS];
new killPlayerTimer[MAX_PLAYERS];
new playerKills[MAX_PLAYERS];

// function declarations

#if defined OnPlayerLogin
	forward OnPlayerLogin(playerid);
#endif

// functions

IpToLong(const address[])
{
	new parts[4];
	sscanf(address, "p<.>a<i>[4]", parts);
	return ((parts[0] << 24) | (parts[1] << 16) | (parts[2] << 8) | parts[3]);
}

ReturnTimelapse(start, till)
{
    new ret[32];
	new seconds = till - start;

	const
		MINUTE = 60,
		HOUR = 60 * MINUTE,
		DAY = 24 * HOUR,
		MONTH = 30 * DAY;

	if (seconds == 1)
	{
		format(ret, sizeof(ret), "a second");
	}
	if (seconds < (1 * MINUTE))
	{
		format(ret, sizeof(ret), "%i seconds", seconds);
	}
	else if (seconds < (2 * MINUTE))
	{
		format(ret, sizeof(ret), "a minute");
	}
	else if (seconds < (45 * MINUTE))
	{
		format(ret, sizeof(ret), "%i minutes", (seconds / MINUTE));
	}
	else if (seconds < (90 * MINUTE))
	{
		format(ret, sizeof(ret), "an hour");
	}
	else if (seconds < (24 * HOUR))
	{
		format(ret, sizeof(ret), "%i hours", (seconds / HOUR));
	}
	else if (seconds < (48 * HOUR))
	{
		format(ret, sizeof(ret), "a day");
	}
	else if (seconds < (30 * DAY))
	{
		format(ret, sizeof(ret), "%i days", (seconds / DAY));
	}
	else if (seconds < (12 * MONTH))
    {
		new months = floatround(seconds / DAY / 30);
      	if (months <= 1)
    	{
			format(ret, sizeof(ret), "a month");
		}
      	else
    	{
			format(ret, sizeof(ret), "%i months", months);
		}
	}
    else
    {
      	new years = floatround(seconds / DAY / 365);
      	if (years <= 1)
    	{
			format(ret, sizeof(ret), "a year");
		}
      	else
    	{
			format(ret, sizeof(ret), "%i years", years);
		}
	}
	return ret;
}

// callbacks

public OnGameModeInit()
{
	db_debug_openresults();
    db = db_open("database.db");
	db_query(db, "PRAGMA synchronous = NORMAL");
 	db_query(db, "PRAGMA journal_mode = WAL");

	new string[1024] = "CREATE TABLE IF NOT EXISTS `users`(\
		`id` INTEGER PRIMARY KEY, \
		`name` VARCHAR(24) NOT NULL DEFAULT '', \
		`ip` VARCHAR(18) NOT NULL DEFAULT '', \
		`longip` INT NOT NULL DEFAULT '0', \
		`password` VARCHAR(64) NOT NULL DEFAULT '', \
		`salt` VARCHAR(64) NOT NULL DEFAULT '', \
		`sec_question` VARCHAR("#MAX_SECURITY_QUESTION_SIZE") NOT NULL DEFAULT '', \
		`sec_answer` VARCHAR(64) NOT NULL DEFAULT '', ";
	strcat(string, "`register_timestamp` INT NOT NULL DEFAULT '0', \
		`lastlogin_timestamp` INT NOT NULL DEFAULT '0', \
		`kills` INT NOT NULL DEFAULT '0', \
		`deaths` INT NOT NULL DEFAULT '0', \
		`score` INT NOT NULL DEFAULT '0', \
		`money` INT NOT NULL DEFAULT '0', \
		`adminlevel` INT NOT NULL DEFAULT '0', \
		`viplevel` INT NOT NULL DEFAULT '0')");
	db_query(db, string);

	db_query(db, "CREATE TABLE IF NOT EXISTS `temp_blocked_users` (\
		`ip` VARCHAR(18) NOT NULL DEFAULT '', \
		`lock_timestamp` INT NOT NULL DEFAULT '0', \
		`user_id` INT NOT NULL DEFAULT '-1')");




    joinScreenTextDraw[0] = TextDrawCreate(0.000000, 0.000000, "box");
	TextDrawBackgroundColor(joinScreenTextDraw[0], 255);
	TextDrawFont(joinScreenTextDraw[0], 1);
	TextDrawLetterSize(joinScreenTextDraw[0], 0.000000, 12.000000);
	TextDrawColor(joinScreenTextDraw[0], -1);
	TextDrawSetOutline(joinScreenTextDraw[0], 0);
	TextDrawSetProportional(joinScreenTextDraw[0], 1);
	TextDrawSetShadow(joinScreenTextDraw[0], 1);
	TextDrawUseBox(joinScreenTextDraw[0], 1);
	TextDrawBoxColor(joinScreenTextDraw[0], 255);
	TextDrawTextSize(joinScreenTextDraw[0], 640.000000, 0.000000);
	TextDrawSetSelectable(joinScreenTextDraw[0], 0);

	joinScreenTextDraw[1] = TextDrawCreate(0.000000, 339.000000, "box");
	TextDrawBackgroundColor(joinScreenTextDraw[1], 255);
	TextDrawFont(joinScreenTextDraw[1], 1);
	TextDrawLetterSize(joinScreenTextDraw[1], 0.000000, 12.000000);
	TextDrawColor(joinScreenTextDraw[1], -1);
	TextDrawSetOutline(joinScreenTextDraw[1], 0);
	TextDrawSetProportional(joinScreenTextDraw[1], 1);
	TextDrawSetShadow(joinScreenTextDraw[1], 1);
	TextDrawUseBox(joinScreenTextDraw[1], 1);
	TextDrawBoxColor(joinScreenTextDraw[1], 255);
	TextDrawTextSize(joinScreenTextDraw[1], 640.000000, 0.000000);
	TextDrawSetSelectable(joinScreenTextDraw[1], 0);

	joinScreenTextDraw[2] = TextDrawCreate(319.000000, 189.000000, "San Andreas");
	TextDrawAlignment(joinScreenTextDraw[2], 2);
	TextDrawBackgroundColor(joinScreenTextDraw[2], 255);
	TextDrawFont(joinScreenTextDraw[2], 0);
	TextDrawLetterSize(joinScreenTextDraw[2], 0.500000, 2.199999);
	TextDrawColor(joinScreenTextDraw[2], -1);
	TextDrawSetOutline(joinScreenTextDraw[2], 1);
	TextDrawSetProportional(joinScreenTextDraw[2], 1);
	TextDrawSetSelectable(joinScreenTextDraw[2], 0);

	joinScreenTextDraw[3] = TextDrawCreate(278.000000, 211.000000, "LD_POOL:BALL");
	TextDrawAlignment(joinScreenTextDraw[3], 2);
	TextDrawBackgroundColor(joinScreenTextDraw[3], 255);
	TextDrawFont(joinScreenTextDraw[3], 4);
	TextDrawLetterSize(joinScreenTextDraw[3], 0.500000, 2.000000);
	TextDrawColor(joinScreenTextDraw[3], 255);
	TextDrawSetOutline(joinScreenTextDraw[3], 1);
	TextDrawSetProportional(joinScreenTextDraw[3], 1);
	TextDrawUseBox(joinScreenTextDraw[3], 1);
	TextDrawBoxColor(joinScreenTextDraw[3], 255);
	TextDrawTextSize(joinScreenTextDraw[3], 13.000000, 22.000000);
	TextDrawSetSelectable(joinScreenTextDraw[3], 0);

	joinScreenTextDraw[4] = TextDrawCreate(349.000000, 211.000000, "LD_POOL:BALL");
	TextDrawAlignment(joinScreenTextDraw[4], 2);
	TextDrawBackgroundColor(joinScreenTextDraw[4], 255);
	TextDrawFont(joinScreenTextDraw[4], 4);
	TextDrawLetterSize(joinScreenTextDraw[4], 0.500000, 2.000000);
	TextDrawColor(joinScreenTextDraw[4], 255);
	TextDrawSetOutline(joinScreenTextDraw[4], 1);
	TextDrawSetProportional(joinScreenTextDraw[4], 1);
	TextDrawUseBox(joinScreenTextDraw[4], 1);
	TextDrawBoxColor(joinScreenTextDraw[4], 255);
	TextDrawTextSize(joinScreenTextDraw[4], 13.000000, 22.000000);
	TextDrawSetSelectable(joinScreenTextDraw[4], 0);

	joinScreenTextDraw[5] = TextDrawCreate(285.000000, 211.000000, "LD_SPAC:BLACK");
	TextDrawAlignment(joinScreenTextDraw[5], 2);
	TextDrawBackgroundColor(joinScreenTextDraw[5], 255);
	TextDrawFont(joinScreenTextDraw[5], 4);
	TextDrawLetterSize(joinScreenTextDraw[5], 0.500000, 2.000000);
	TextDrawColor(joinScreenTextDraw[5], 255);
	TextDrawSetOutline(joinScreenTextDraw[5], 1);
	TextDrawSetProportional(joinScreenTextDraw[5], 1);
	TextDrawUseBox(joinScreenTextDraw[5], 1);
	TextDrawBoxColor(joinScreenTextDraw[5], 255);
	TextDrawTextSize(joinScreenTextDraw[5], 71.000000, 22.000000);
	TextDrawSetSelectable(joinScreenTextDraw[5], 0);

	joinScreenTextDraw[6] = TextDrawCreate(279.000000, 212.000000, "LD_POOL:BALL");
	TextDrawAlignment(joinScreenTextDraw[6], 2);
	TextDrawBackgroundColor(joinScreenTextDraw[6], 255);
	TextDrawFont(joinScreenTextDraw[6], 4);
	TextDrawLetterSize(joinScreenTextDraw[6], 0.500000, 2.000000);
	TextDrawColor(joinScreenTextDraw[6], -65281);
	TextDrawSetOutline(joinScreenTextDraw[6], 1);
	TextDrawSetProportional(joinScreenTextDraw[6], 1);
	TextDrawUseBox(joinScreenTextDraw[6], 1);
	TextDrawBoxColor(joinScreenTextDraw[6], 255);
	TextDrawTextSize(joinScreenTextDraw[6], 13.000000, 20.000000);
	TextDrawSetSelectable(joinScreenTextDraw[6], 0);

	joinScreenTextDraw[7] = TextDrawCreate(348.000000, 212.000000, "LD_POOL:BALL");
	TextDrawAlignment(joinScreenTextDraw[7], 2);
	TextDrawBackgroundColor(joinScreenTextDraw[7], 255);
	TextDrawFont(joinScreenTextDraw[7], 4);
	TextDrawLetterSize(joinScreenTextDraw[7], 0.500000, 2.000000);
	TextDrawColor(joinScreenTextDraw[7], -65281);
	TextDrawSetOutline(joinScreenTextDraw[7], 1);
	TextDrawSetProportional(joinScreenTextDraw[7], 1);
	TextDrawUseBox(joinScreenTextDraw[7], 1);
	TextDrawBoxColor(joinScreenTextDraw[7], 255);
	TextDrawTextSize(joinScreenTextDraw[7], 13.000000, 20.000000);
	TextDrawSetSelectable(joinScreenTextDraw[7], 0);

	joinScreenTextDraw[8] = TextDrawCreate(285.000000, 212.000000, "LD_SPAC:WHITE");
	TextDrawAlignment(joinScreenTextDraw[8], 2);
	TextDrawBackgroundColor(joinScreenTextDraw[8], 255);
	TextDrawFont(joinScreenTextDraw[8], 4);
	TextDrawLetterSize(joinScreenTextDraw[8], 0.500000, 2.000000);
	TextDrawColor(joinScreenTextDraw[8], -65281);
	TextDrawSetOutline(joinScreenTextDraw[8], 1);
	TextDrawSetProportional(joinScreenTextDraw[8], 1);
	TextDrawUseBox(joinScreenTextDraw[8], 1);
	TextDrawBoxColor(joinScreenTextDraw[8], 255);
	TextDrawTextSize(joinScreenTextDraw[8], 71.000000, 19.000000);
	TextDrawSetSelectable(joinScreenTextDraw[8], 0);

	joinScreenTextDraw[9] = TextDrawCreate(320.000000, 214.000000, "BATTLEGROUNDS");
	TextDrawAlignment(joinScreenTextDraw[9], 2);
	TextDrawBackgroundColor(joinScreenTextDraw[9], 0);
	TextDrawFont(joinScreenTextDraw[9], 1);
	TextDrawLetterSize(joinScreenTextDraw[9], 0.270000, 1.499999);
	TextDrawColor(joinScreenTextDraw[9], 255);
	TextDrawSetOutline(joinScreenTextDraw[9], 0);
	TextDrawSetProportional(joinScreenTextDraw[9], 1);
	TextDrawSetShadow(joinScreenTextDraw[9], 1);
	TextDrawSetSelectable(joinScreenTextDraw[9], 0);

	joinScreenTextDraw[10] = TextDrawCreate(319.000000, 237.000000, "v1.0 - OPEN BETA - Last update: 14 Sept, 2017");
	TextDrawAlignment(joinScreenTextDraw[10], 2);
	TextDrawBackgroundColor(joinScreenTextDraw[10], 255);
	TextDrawFont(joinScreenTextDraw[10], 1);
	TextDrawLetterSize(joinScreenTextDraw[10], 0.210000, 1.099999);
	TextDrawColor(joinScreenTextDraw[10], -1);
	TextDrawSetOutline(joinScreenTextDraw[10], 1);
	TextDrawSetProportional(joinScreenTextDraw[10], 1);
	TextDrawSetSelectable(joinScreenTextDraw[10], 0);
	

		
		
    EnableVehicleFriendlyFire();
    DisableInteriorEnterExits();
	UsePlayerPedAnims();
	ShowPlayerMarkers(PLAYER_MARKERS_MODE_OFF);
	return 1;
}

public OnGameModeExit()
{
	db_close(db);
	
	for (new i; i < sizeof joinScreenTextDraw; i++)
	{
	    TextDrawDestroy(joinScreenTextDraw[i]);
	}
	return 1;
}

public OnGameStart()
{
	foreach (new i : Player)
	{
	    if (GetPVarInt(i, "LoggedIn") == 1)
	    {
			TextDrawHideForPlayer(i, joinScreenTextDraw[0]);
			TextDrawHideForPlayer(i, joinScreenTextDraw[1]);
		}
	}
	return 1;
}

public OnGameFinish()
{
	foreach (new i : Player)
	{
	    if (GetPVarInt(i, "LoggedIn") == 1)
	    {
			TextDrawShowForPlayer(i, joinScreenTextDraw[0]);
			TextDrawShowForPlayer(i, joinScreenTextDraw[1]);
		}
	}
	return 1;
}

public OnPlayerConnect(playerid)
{
    joinScreenPlayerTextDraw[playerid] = CreatePlayerTextDraw(playerid, 319.000000, 248.000000, "Press ~k~~VEHICLE_ENTER_EXIT~ to continue.");
	PlayerTextDrawAlignment(playerid, joinScreenPlayerTextDraw[playerid], 2);
	PlayerTextDrawBackgroundColor(playerid, joinScreenPlayerTextDraw[playerid], 255);
	PlayerTextDrawFont(playerid, joinScreenPlayerTextDraw[playerid], 1);
	PlayerTextDrawLetterSize(playerid, joinScreenPlayerTextDraw[playerid], 0.210000, 1.099999);
	PlayerTextDrawColor(playerid, joinScreenPlayerTextDraw[playerid], -1);
	PlayerTextDrawSetOutline(playerid, joinScreenPlayerTextDraw[playerid], 1);
	PlayerTextDrawSetProportional(playerid, joinScreenPlayerTextDraw[playerid], 1);
	PlayerTextDrawSetSelectable(playerid, joinScreenPlayerTextDraw[playerid], 0);

    killPlayerTextDraw[playerid] = CreatePlayerTextDraw(playerid,319.000000, 343.000000, "You killed ~y~~h~Gammix(0) ~w~~h~with MP5 at head~n~~r~3 Kills");
	PlayerTextDrawAlignment(playerid,killPlayerTextDraw[playerid], 2);
	PlayerTextDrawBackgroundColor(playerid,killPlayerTextDraw[playerid], 255);
	PlayerTextDrawFont(playerid,killPlayerTextDraw[playerid], 2);
	PlayerTextDrawLetterSize(playerid,killPlayerTextDraw[playerid], 0.220000, 1.399998);
	PlayerTextDrawColor(playerid,killPlayerTextDraw[playerid], -1);
	PlayerTextDrawSetOutline(playerid,killPlayerTextDraw[playerid], 1);
	PlayerTextDrawSetProportional(playerid,killPlayerTextDraw[playerid], 1);
	PlayerTextDrawSetSelectable(playerid,killPlayerTextDraw[playerid], 0);

	TogglePlayerSpectating(playerid, true);
	return SetTimerEx("OnPlayerJoin", 100, false, "i", playerid);
}

forward OnPlayerJoin(playerid);
public OnPlayerJoin(playerid)
{
	for (new i; i < 100; i++)
	{
	    SendClientMessage(playerid, COLOR_WHITE, "");
	}

	SetPlayerCameraPos(playerid, -144.2838, 1244.2357, 35.6595);
	SetPlayerCameraLookAt(playerid, -144.2255, 1243.2335, 35.3393);
	
	playerInJoinScreen[playerid] = true;
	for (new i; i < sizeof joinScreenTextDraw; i++)
	{
		TextDrawShowForPlayer(playerid, joinScreenTextDraw[i]);
	}
	PlayerTextDrawShow(playerid, joinScreenPlayerTextDraw[playerid]);
}

public OnPlayerDisconnect(playerid, reason)
{
	if (GetPVarInt(playerid, "LoggedIn"))
	{
		new name[MAX_PLAYER_NAME];
		GetPlayerName(playerid, name, MAX_PLAYER_NAME);
		
		new string[1024];
		format(string, sizeof(string),
			"UPDATE `users` SET `name` = '%s', \
			`password` = '%q', \
			`salt` = '%q', \
			`sec_question` = '%q', \
			`sec_answer` = '%q', \
			`kills` = %i, \
			`deaths` = %i, \
			`score` = %i, \
			`money` = %i, \
			`adminlevel` = %i, \
			`viplevel` = %i, \
			WHERE `id` = %i",
			name,
			playerData[playerid][E_PLAYER_DATA_PASSWORD],
			playerData[playerid][E_PLAYER_DATA_SALT],
			playerData[playerid][E_PLAYER_DATA_SEC_QUESTION],
			playerData[playerid][E_PLAYER_DATA_SEC_ANSWER],
			playerData[playerid][E_PLAYER_DATA_KILLS],
			playerData[playerid][E_PLAYER_DATA_DEATHS],
			GetPlayerScore(playerid),
			GetPlayerMoney(playerid),
			GetPVarInt(playerid, "AdminLevel"),
			GetPVarInt(playerid, "VipLevel"),
			playerData[playerid][E_PLAYER_DATA_SQLID]);
		db_query(db, string);
	}
	return 1;
}

public OnPlayerRequestClass(playerid, classid)
{
	if (!GetPVarInt(playerid, "LoggedIn"))
	{
		return 0;
	}
	
	return SetTimerEx("OnPlayerEnterClassSelection", 50, false, "i", playerid);
}

forward OnPlayerEnterClassSelection(playerid);
public OnPlayerEnterClassSelection(playerid)
{
	return SpawnPlayer(playerid);
}

public OnPlayerRequestSpawn(playerid)
{
	return GameTextForPlayer(playerid, "~r~Processing game menu...", 5000, 3);
}

public OnPlayerSpawn(playerid)
{
    playerKills[playerid] = 0;
    
	for (new i; i < sizeof joinScreenTextDraw; i++)
	{
		TextDrawHideForPlayer(playerid, joinScreenTextDraw[i]);
	}
	PlayerTextDrawHide(playerid, joinScreenPlayerTextDraw[playerid]);
	
	if (IsGameFinished())
	{
	    TextDrawShowForPlayer(playerid, joinScreenTextDraw[0]);
		TextDrawShowForPlayer(playerid, joinScreenTextDraw[1]);
	}
	return 1;
}

public OnPlayerDeath(playerid, killerid, reason)
{
	playerData[playerid][E_PLAYER_DATA_DEATHS]++;
	if (killerid != INVALID_PLAYER_ID)
	{
		playerData[killerid][E_PLAYER_DATA_KILLS]++;
		playerKills[killerid]++;
		
		new name[MAX_PLAYER_NAME];
		GetPlayerName(playerid, name, sizeof name);
		
		new weaponname[35];
		GetWeaponName(reason, weaponname, sizeof weaponname);
		
		new string[128];
		format(string, sizeof string, "You killed ~y~~h~%s ~w~~h~with a %s~n~~r~+%i Kills", name, weaponname, playerKills[killerid]);
		PlayerTextDrawSetString(killerid, killPlayerTextDraw[killerid], string);
		PlayerTextDrawShow(killerid, killPlayerTextDraw[killerid]);

		KillTimer(killPlayerTimer[killerid]);
		killPlayerTimer[killerid] = SetTimerEx("OnPlayerKillFeedExpire", 5000, false, "i", killerid);
	}
	return 1;
}

forward OnPlayerKillFeedExpire(playerid);
public OnPlayerKillFeedExpire(playerid)
{
    PlayerTextDrawHide(playerid, killPlayerTextDraw[playerid]);
}

public OnPlayerUpdate(playerid)
{
	return 1;
}

public OnPlayerLogin(playerid)
{
	PlayerTextDrawSetString(playerid, joinScreenPlayerTextDraw[playerid], "Spawning...");
	SetTimerEx("OnPlayerLoggedIn", 2500, false, "i", playerid);
	return 1;
}

forward OnPlayerLoggedIn(playerid);
public OnPlayerLoggedIn(playerid)
{
	TogglePlayerSpectating(playerid, false);
	return SpawnPlayer(playerid);
}

public OnPlayerKeyStateChange(playerid, newkeys, oldkeys)
{
	if (playerInJoinScreen[playerid])
	{
		if (newkeys == KEY_SECONDARY_ATTACK)
		{
	    	playerInJoinScreen[playerid] = false;

			PlayerTextDrawSetString(playerid, joinScreenPlayerTextDraw[playerid], "Checking for auto-login...");

            PlayerPlaySound(playerid, 1054, 0.0, 0.0, 0.0);
			SetTimerEx("OnPlayerPressedEnter", 2500, false, "i", playerid);
	    }
	}

	if (gameState == GAME_STATE_IN_PROGRESS || gameState == GAME_STATE_WAITING)
	{
		if (newkeys & KEY_YES)
		{
		    if (Iter_Contains(PLAYERS, playerid))
		    {
		        PlayerPlaySound(playerid, 1054, 0.0, 0.0, 0.0);
				return Inv_Show(playerid);
			}
		}
	}
	return 1;
}

forward OnPlayerPressedEnter(playerid);
public OnPlayerPressedEnter(playerid)
{
    new name[MAX_PLAYER_NAME];
	GetPlayerName(playerid, name, MAX_PLAYER_NAME);

	new string[150];
	format(string, sizeof(string), "SELECT * FROM `users` WHERE `name` = '%q' LIMIT 1", name);

	new DBResult:result = db_query(db, string);
	if (db_num_rows(result) == 0)
	{
		PlayerTextDrawSetString(playerid, joinScreenPlayerTextDraw[playerid], "Registration required!");
			
	    playerData[playerid][E_PLAYER_DATA_SQLID] = -1;
	    playerData[playerid][E_PLAYER_DATA_PASSWORD][0] = EOS;
	    playerData[playerid][E_PLAYER_DATA_SALT][0] = EOS;
		playerData[playerid][E_PLAYER_DATA_KILLS] = 0;
		playerData[playerid][E_PLAYER_DATA_DEATHS] = 0;
		playerData[playerid][E_PLAYER_DATA_SCORE] = 0;
		playerData[playerid][E_PLAYER_DATA_MONEY] = 0;
		playerData[playerid][E_PLAYER_DATA_REG_TIMESTAMP] = 0;
		playerData[playerid][E_PLAYER_DATA_LASTLOG_TIMESTAMP] = 0;
		playerData[playerid][E_PLAYER_DATA_SEC_QUESTION][0] = EOS;
		playerData[playerid][E_PLAYER_DATA_SEC_ANSWER][0] = EOS;
		
		SetPVarInt(playerid, "AdminLevel", 0);
		SetPVarInt(playerid, "VipLevel", 0);
	
		Dialog_Show(playerid, REGISTER, DIALOG_STYLE_PASSWORD, "Account Registeration... [Step: 1/3]", COL_WHITE "We will take you through "COL_GREEN"3 simple steps "COL_WHITE"to register your account with a backup option in case you forgot your password!\nInsert your password below (Passwords are "COL_TOMATO"Case Sensitive"COL_WHITE")", "Continue", "Options");
		SendClientMessage(playerid, COLOR_WHITE, "[Step: 1/3] Enter your new account's password.");
	}
	else
	{
		PlayerTextDrawSetString(playerid, joinScreenPlayerTextDraw[playerid], "Login required!");

		playerLoginAttempts[playerid] = 0;
		playerAnswerAttempts[playerid] = 0;

		playerData[playerid][E_PLAYER_DATA_SQLID] = db_get_field_assoc_int(result, "id");
		
		format(string, sizeof(string), "SELECT `lock_timestamp` FROM `temp_blocked_users` WHERE `user_id` = %i LIMIT 1", playerData[playerid][E_PLAYER_DATA_SQLID]);

		new DBResult:lock_result = db_query(db, string);
		if (db_num_rows(lock_result) == 1)
		{
			new lock_timestamp = db_get_field_int(lock_result, 0);
			if ((gettime() - lock_timestamp) < 0)
		    {
		        SendClientMessage(playerid, COLOR_TOMATO, "Sorry! The account is temporarily locked on your IP. due to "#MAX_LOGIN_ATTEMPTS"/"#MAX_LOGIN_ATTEMPTS" failed login attempts.");

				format(string, sizeof(string), "You'll be able to try again in %s.", ReturnTimelapse(gettime(), lock_timestamp));
				SendClientMessage(playerid, COLOR_TOMATO, string);

				db_free_result(result);
				db_free_result(lock_result);

				return Kick(playerid);
		    }
		    else
		    {
		        new ip[18];
				GetPlayerIp(playerid, ip, 18);
				
		        format(string, sizeof(string), "DELETE FROM `temp_blocked_users` WHERE `user_id` = %i AND `ip` = '%s'", playerData[playerid][E_PLAYER_DATA_SQLID], ip);
		        db_query(db, string);
		    }
		}
		db_free_result(lock_result);

		db_get_field_assoc(result, "password", playerData[playerid][E_PLAYER_DATA_PASSWORD], 64);
		db_get_field_assoc(result, "salt", playerData[playerid][E_PLAYER_DATA_SALT], 64);
		playerData[playerid][E_PLAYER_DATA_SALT][64] = EOS;
		playerData[playerid][E_PLAYER_DATA_KILLS] = db_get_field_assoc_int(result, "kills");
		playerData[playerid][E_PLAYER_DATA_DEATHS] = db_get_field_assoc_int(result, "deaths");
		playerData[playerid][E_PLAYER_DATA_SCORE] = db_get_field_assoc_int(result, "score");
		playerData[playerid][E_PLAYER_DATA_MONEY] = db_get_field_assoc_int(result, "money");
		playerData[playerid][E_PLAYER_DATA_REG_TIMESTAMP] = db_get_field_assoc_int(result, "register_timestamp");
		playerData[playerid][E_PLAYER_DATA_LASTLOG_TIMESTAMP] = db_get_field_assoc_int(result, "lastlogin_timestamp");
		db_get_field_assoc(result, "sec_question", playerData[playerid][E_PLAYER_DATA_SEC_QUESTION], MAX_SECURITY_QUESTION_SIZE);
		db_get_field_assoc(result, "sec_answer", playerData[playerid][E_PLAYER_DATA_SEC_ANSWER], MAX_PASSWORD_LENGTH * 2);
		
		SetPVarInt(playerid, "AdminLevel", db_get_field_assoc_int(result, "adminlevel"));
		SetPVarInt(playerid, "VipLevel", db_get_field_assoc_int(result, "viplevel"));

		if ((gettime() - playerData[playerid][E_PLAYER_DATA_LASTLOG_TIMESTAMP]) < (6 * 60 * 60))
		{
			new ip[18];
			GetPlayerIp(playerid, ip, sizeof ip);
			
			db_get_field_assoc(result, "ip", string, 18);
			if (!strcmp(string, ip))
			{
				format(string, sizeof(string), "UPDATE `users` SET `lastlogin_timestamp` = %i, `ip` = '%s', `longip` = %i WHERE `id` = %i", gettime(), ip, IpToLong(ip), playerData[playerid][E_PLAYER_DATA_SQLID]);
				db_query(db, string);

				format(string, sizeof(string), "Auto-logged in! Welcome back to our server %s, we hope you enjoy your stay. [Last login: %s ago]", name, ReturnTimelapse(playerData[playerid][E_PLAYER_DATA_LASTLOG_TIMESTAMP], gettime()));
				SendClientMessage(playerid, COLOR_GREEN, string);

				PlayerPlaySound(playerid, 1057, 0.0, 0.0, 0.0);
				
				SetPVarInt(playerid, "LoggedIn", 1);
				CallRemoteFunction("OnPlayerLogin", "i", playerid);
				return 1;
			}
		}
		
		Dialog_Show(playerid, LOGIN, DIALOG_STYLE_PASSWORD, "Account Login...", COL_WHITE "Insert your password below (Click \""COL_TOMATO"Options"COL_WHITE"\" if you forgot username or password or want to leave)", "Continue", "Options");
	}

	db_free_result(result);
	return 1;
}

// dialogs

Dialog:LOGIN(playerid, response, listitem, inputtext[])
{
	if (!response)
	{
	    PlayerPlaySound(playerid, 1054, 0.0, 0.0, 0.0);
	    Dialog_Show(playerid, LOGIN_OPTIONS, DIALOG_STYLE_LIST, "Account Options...", "Forgot password\nForgot username\nExit to desktop", "Select", "Back");
	    return 1;
	}

	new string[256];

	new hash[64];
	SHA256_PassHash(inputtext, playerData[playerid][E_PLAYER_DATA_SALT], hash, sizeof(hash));
	if (strcmp(hash, playerData[playerid][E_PLAYER_DATA_PASSWORD]))
	{
		if (++playerLoginAttempts[playerid] == MAX_LOGIN_ATTEMPTS)
		{
		    new lock_timestamp = gettime() + (MAX_ACCOUNT_LOCKTIME * 60);

			new ip[18];
		    GetPlayerIp(playerid, ip, 18);

			format(string, sizeof(string), "INSERT INTO `temp_blocked_users` VALUES('%s', %i, %i)", ip, lock_timestamp, playerData[playerid][E_PLAYER_DATA_SQLID]);
			db_query(db, string);

		    SendClientMessage(playerid, COLOR_TOMATO, "Sorry! The account has been temporarily locked on your IP. due to "#MAX_LOGIN_ATTEMPTS"/"#MAX_LOGIN_ATTEMPTS" failed login attempts.");

			format(string, sizeof(string), "If you forgot your password/username, click on 'Options' in login window next time (you may retry in %s).", ReturnTimelapse(gettime(), lock_timestamp));
			SendClientMessage(playerid, COLOR_TOMATO, string);
		    return Kick(playerid);
		}

	    Dialog_Show(playerid, LOGIN, DIALOG_STYLE_INPUT, "Account Login...", COL_WHITE "Insert your password below (Click \""COL_TOMATO"Options"COL_WHITE"\" if you forgot username or password or want to leave)", "Continue", "Options");

		format(string, sizeof(string), "Incorrect password! Your login tries left: %i/"#MAX_LOGIN_ATTEMPTS" attempts.", playerLoginAttempts[playerid]);
		SendClientMessage(playerid, COLOR_TOMATO, string);
	    return 1;
	}

	new name[MAX_PLAYER_NAME];
	GetPlayerName(playerid, name, MAX_PLAYER_NAME);

	new ip[18];
	GetPlayerIp(playerid, ip, 18);

	format(string, sizeof(string), "UPDATE `users` SET `lastlogin_timestamp` = %i, `ip` = '%s', `longip` = %i WHERE `id` = %i", gettime(), ip, IpToLong(ip), playerData[playerid][E_PLAYER_DATA_SQLID]);
	db_query(db, string);

	format(string, sizeof(string), "Successfully logged in! Welcome back to our server %s, we hope you enjoy your stay. [Last login: %s ago]", name, ReturnTimelapse(playerData[playerid][E_PLAYER_DATA_LASTLOG_TIMESTAMP], gettime()));
	SendClientMessage(playerid, COLOR_GREEN, string);
	
	ResetPlayerMoney(playerid);
	GivePlayerMoney(playerid, playerData[playerid][E_PLAYER_DATA_MONEY]);
	SetPlayerScore(playerid, playerData[playerid][E_PLAYER_DATA_SCORE]);
	
	PlayerPlaySound(playerid, 1057, 0.0, 0.0, 0.0);
	
	SetPVarInt(playerid, "LoggedIn", 1);
	CallRemoteFunction("OnPlayerLogin", "i", playerid);
	return 1;
}

Dialog:REGISTER(playerid, response, listitem, inputtext[])
{
	if (!response)
	{
	    PlayerPlaySound(playerid, 1054, 0.0, 0.0, 0.0);
	    Dialog_Show(playerid, REGISTER_OPTIONS, DIALOG_STYLE_LIST, "Account Options...", "Forgot username\nExit to desktop", "Select", "Back");
	    return 1;
	}

	if (!(MIN_PASSWORD_LENGTH <= strlen(inputtext) <= MAX_PASSWORD_LENGTH))
	{
	    Dialog_Show(playerid, REGISTER, DIALOG_STYLE_PASSWORD, "Account Registeration... [Step: 1/3]", COL_WHITE "We will take you through "COL_GREEN"3 simple steps "COL_WHITE"to register your account with a backup option in case you forgot your password!\nInsert your password below (Passwords are "COL_TOMATO"Case Sensitive"COL_WHITE")", "Continue", "Options");
		SendClientMessage(playerid, COLOR_TOMATO, "Invalid password length, must be between "#MIN_PASSWORD_LENGTH" - "#MAX_PASSWORD_LENGTH" characters.");
	    return 1;
	}

	for (new i; i < 64; i++)
	{
		playerData[playerid][E_PLAYER_DATA_SALT][i] = (random('z' - 'A') + 'A');
	}
	playerData[playerid][E_PLAYER_DATA_SALT][64] = EOS;
	SHA256_PassHash(inputtext, playerData[playerid][E_PLAYER_DATA_SALT], playerData[playerid][E_PLAYER_DATA_PASSWORD], 64);

	new list[2 + (sizeof(SECURITY_QUESTIONS) * MAX_SECURITY_QUESTION_SIZE)];
	for (new i; i < sizeof(SECURITY_QUESTIONS); i++)
	{
	    strcat(list, SECURITY_QUESTIONS[i]);
	    strcat(list, "\n");
	}
	Dialog_Show(playerid, SEC_QUESTION, DIALOG_STYLE_LIST, "Account Registeration... [Step: 2/3]", list, "Continue", "Back");

	SendClientMessage(playerid, COLOR_WHITE, "[Step: 2/3] Select a security question. This will help you retrieve your password in case you forget it any time soon!");
	PlayerPlaySound(playerid, 1054, 0.0, 0.0, 0.0);
	return 1;
}

Dialog:SEC_QUESTION(playerid, response, listitem, inputtext[])
{
	if (!response)
	{
	    Dialog_Show(playerid, REGISTER, DIALOG_STYLE_PASSWORD, "Account Registeration... [Step: 1/3]", COL_WHITE "We will take you through "COL_GREEN"3 simple steps "COL_WHITE"to register your account with a backup option in case you forgot your password!\nInsert your password below (Passwords are "COL_TOMATO"Case Sensitive"COL_WHITE")", "Continue", "Options");
		SendClientMessage(playerid, COLOR_WHITE, "[Step: 1/3] Enter your new account's password.");
		return 1;
	}

	format(playerData[playerid][E_PLAYER_DATA_SEC_QUESTION], MAX_SECURITY_QUESTION_SIZE, SECURITY_QUESTIONS[listitem]);

	new string[256];
	format(string, sizeof(string), COL_TOMATO "%s\n"COL_WHITE"Insert your answer below in the box. (don't worry about CAPS, answers are NOT case sensitive).", SECURITY_QUESTIONS[listitem]);
	Dialog_Show(playerid, SEC_ANSWER, DIALOG_STYLE_INPUT, "Account Registeration... [Step: 3/3]", string, "Confirm", "Back");

	SendClientMessage(playerid, COLOR_WHITE, "[Step: 3/3] Write the answer to your secuirty question and you'll be done :)");
	PlayerPlaySound(playerid, 1054, 0.0, 0.0, 0.0);
	return 1;
}

Dialog:SEC_ANSWER(playerid, response, listitem, inputtext[])
{
	if (!response)
	{
	    new list[2 + (sizeof(SECURITY_QUESTIONS) * MAX_SECURITY_QUESTION_SIZE)];
		for (new i; i < sizeof(SECURITY_QUESTIONS); i++)
		{
		    strcat(list, SECURITY_QUESTIONS[i]);
		    strcat(list, "\n");
		}
		Dialog_Show(playerid, SEC_QUESTION, DIALOG_STYLE_LIST, "Account Registeration... [Step: 2/3]", list, "Continue", "Back");
		SendClientMessage(playerid, COLOR_WHITE, "[Step: 2/3] Select a security question. This will help you retrieve your password in case you forget it any time soon!");
		return 1;
	}

	new string[512];

	if (strlen(inputtext) < MIN_PASSWORD_LENGTH || inputtext[0] == ' ')
	{
	    format(string, sizeof(string), COL_TOMATO "%s\n"COL_WHITE"Insert your answer below in the box. (don't worry about CAPS, answers are NOT case sensitive).", SECURITY_QUESTIONS[listitem]);
		Dialog_Show(playerid, SEC_ANSWER, DIALOG_STYLE_INPUT, "Account Registeration... [Step: 3/3]", string, "Confirm", "Back");

		SendClientMessage(playerid, COLOR_TOMATO, "Security answer cannot be an less than "#MIN_PASSWORD_LENGTH" characters.");
		return 1;
	}

	for (new i, j = strlen(inputtext); i < j; i++)
	{
        inputtext[i] = tolower(inputtext[i]);
	}
	SHA256_PassHash(inputtext, playerData[playerid][E_PLAYER_DATA_SALT], playerData[playerid][E_PLAYER_DATA_SEC_ANSWER], 64);

	new name[MAX_PLAYER_NAME];
	GetPlayerName(playerid, name, MAX_PLAYER_NAME);

	new ip[18];
	GetPlayerIp(playerid, ip, 18);

	format(string, sizeof(string), "INSERT INTO `users`(`name`, `ip`, `longip`, `password`, `salt`, `sec_question`, `sec_answer`, `register_timestamp`, `lastlogin_timestamp`) VALUES('%s', '%s', %i, '%q', '%q', '%q', '%q', %i, %i)", name, ip, IpToLong(ip), playerData[playerid][E_PLAYER_DATA_PASSWORD], playerData[playerid][E_PLAYER_DATA_SALT], playerData[playerid][E_PLAYER_DATA_SEC_QUESTION], playerData[playerid][E_PLAYER_DATA_SEC_ANSWER], gettime(), gettime());
	db_query(db, string);

	format(string, sizeof(string), "SELECT `id` FROM `users` WHERE `name` = '%q' LIMIT 1", name);
	new DBResult:result = db_query(db, string);
    playerData[playerid][E_PLAYER_DATA_SQLID] = db_get_field_int(result, 0);
	db_free_result(result);

	format(string, sizeof(string), "Successfully registered! Welcome to our server %s, we hope you enjoy your stay. [IP: %s]", name, ip);
	SendClientMessage(playerid, COLOR_GREEN, string);
	
	PlayerPlaySound(playerid, 1057, 0.0, 0.0, 0.0);
	
	SetPVarInt(playerid, "LoggedIn", 1);
	CallRemoteFunction("OnPlayerRegister", "i", playerid);
	CallRemoteFunction("OnPlayerLogin", "i", playerid);
	return 1;
}

Dialog:LOGIN_OPTIONS(playerid, response, listitem, inputtext[])
{
	if (!response)
	{
		return Dialog_Show(playerid, LOGIN, DIALOG_STYLE_PASSWORD, "Account Login...", COL_WHITE "Insert your password below (Click \""COL_TOMATO"Options"COL_WHITE"\" if you forgot username or password or want to leave)", "Continue", "Options");
	}

	switch (listitem)
	{
	    case 0:
	    {
			new string[64 + MAX_SECURITY_QUESTION_SIZE];
			format(string, sizeof(string), COL_WHITE "Answer your security question to reset password.\n\n"COL_TOMATO"%s", playerData[playerid][E_PLAYER_DATA_SEC_QUESTION]);
			Dialog_Show(playerid, FORGOT_PASSWORD, DIALOG_STYLE_INPUT, "Forgot Password:", string, "Confirm", "");
	    }
	    case 1:
	    {
	        const MASK = (-1 << (32 - 36));
	        
			new ip[18];
			GetPlayerIp(playerid, ip, 18);
			
			new string[256];
			format(string, sizeof(string), "SELECT `name`, `lastlogin_timestamp` FROM `users` WHERE ((`longip` & %i) = %i) LIMIT 1", MASK, (IpToLong(ip) & MASK));

			new DBResult:result = db_query(db, string);
			if (db_num_rows(result) == 0)
			{
			    SendClientMessage(playerid, COLOR_TOMATO, "There are no accounts realted to this ip, this seems to be your first join!");
		     	Dialog_Show(playerid, LOGIN_OPTIONS, DIALOG_STYLE_LIST, "Account Options...", "Forgot password\nForgot username\nExit to desktop", "Select", "Back");
			    return 1;
			}

			new list[25 * (MAX_PLAYER_NAME + 32)],
				name[MAX_PLAYER_NAME],
				lastlogin_timestamp,
				i,
				j = ((db_num_rows(result) > 10) ? (10) : (db_num_rows(result)));
				
			do
			{
			    db_get_field_assoc(result, "name", name, MAX_PLAYER_NAME);
				lastlogin_timestamp = db_get_field_assoc_int(result, "lastlogin_timestamp");
			    format(list, sizeof(list), "%s"COL_TOMATO"%s "COL_WHITE"|| Last login: %s ago\n", list, name, ReturnTimelapse(lastlogin_timestamp, gettime()));
			}
			while (db_next_row(result) && i > j);
			db_free_result(result);

			Dialog_Show(playerid, FORGOT_USERNAME, DIALOG_STYLE_LIST, "Your username history...", list, "Close", "");
			PlayerPlaySound(playerid, 1054, 0.0, 0.0, 0.0);
	    }
	    case 2:
	    {
	        return Kick(playerid);
	    }
	}
	return 1;
}

Dialog:REGISTER_OPTIONS(playerid, response, listitem, inputtext[])
{
	if (!response)
	{
		return Dialog_Show(playerid, REGISTER, DIALOG_STYLE_PASSWORD, "Account Registeration... [Step: 1/3]", COL_WHITE "We will take you through "COL_GREEN"3 simple steps "COL_WHITE"to register your account with a backup option in case you forgot your password!\nInsert your password below (Passwords are "COL_TOMATO"Case Sensitive"COL_WHITE")", "Continue", "Options");
	}

	switch (listitem)
	{
	    case 0:
	    {
	        dialog_LOGIN_OPTIONS(playerid, 1, 1, "\1");
	        
	        const MASK = (-1 << (32 - 36));
	        
			new ip[18];
			GetPlayerIp(playerid, ip, 18);
			
			new string[256];
			format(string, sizeof(string), "SELECT `name`, `lastlogin_timestamp` FROM `users` WHERE ((`longip` & %i) = %i) LIMIT 1", MASK, (IpToLong(ip) & MASK));

			new DBResult:result = db_query(db, string);
			if (db_num_rows(result) == 0)
			{
			    SendClientMessage(playerid, COLOR_TOMATO, "There are no accounts realted to this ip, this seems to be your first join!");
		     	Dialog_Show(playerid, REGISTER_OPTIONS, DIALOG_STYLE_LIST, "Account Options...", "Forgot username\nExit to desktop", "Select", "Back");
			    return 1;
			}

			new list[25 * (MAX_PLAYER_NAME + 32)],
				name[MAX_PLAYER_NAME],
				lastlogin_timestamp,
				i,
				j = ((db_num_rows(result) > 10) ? (10) : (db_num_rows(result)));

			do
			{
			    db_get_field_assoc(result, "name", name, MAX_PLAYER_NAME);
				lastlogin_timestamp = db_get_field_assoc_int(result, "lastlogin_timestamp");
			    format(list, sizeof(list), "%s"COL_TOMATO"%s "COL_WHITE"|| Last login: %s ago\n", list, name, ReturnTimelapse(lastlogin_timestamp, gettime()));
			}
			while (db_next_row(result) && i > j);
			db_free_result(result);

			Dialog_Show(playerid, FORGOT_USERNAME, DIALOG_STYLE_LIST, "Your username history...", list, "Close", "");
	    }
	    case 1:
	    {
	        return Kick(playerid);
	    }
	}
	return 1;
}

Dialog:FORGOT_PASSWORD(playerid, response, listitem, inputtext[])
{
	if (!response)
	{
	    Kick(playerid);
	    return 1;
	}

	new string[256];
	
	new hash[64];
	SHA256_PassHash(inputtext, playerData[playerid][E_PLAYER_DATA_SALT], hash, sizeof(hash));
	if (strcmp(hash, playerData[playerid][E_PLAYER_DATA_SEC_ANSWER]))
	{
		if (++playerAnswerAttempts[playerid] == MAX_LOGIN_ATTEMPTS)
		{
		    new lock_timestamp = gettime() + (MAX_ACCOUNT_LOCKTIME * 60);
		    
		    new ip[18];
		    GetPlayerIp(playerid, ip, 18);
		    
            format(string, sizeof(string), "INSERT INTO `temp_blocked_users` VALUES('%s', %i, %i)", ip, lock_timestamp, playerData[playerid][E_PLAYER_DATA_SQLID]);
			db_query(db, string);

		    SendClientMessage(playerid, COLOR_TOMATO, "Sorry! The account has been temporarily locked on your IP. due to "#MAX_LOGIN_ATTEMPTS"/"#MAX_LOGIN_ATTEMPTS" failed login attempts.");

			format(string, sizeof(string), "If you forgot your password/username, click on 'Options' in login window next time (you may retry in %s).", ReturnTimelapse(gettime(), lock_timestamp));
			SendClientMessage(playerid, COLOR_TOMATO, string);
		    return Kick(playerid);
		}

	    format(string, sizeof(string), COL_WHITE "Answer your security question to reset password.\n\n"COL_TOMATO"%s", playerData[playerid][E_PLAYER_DATA_SEC_QUESTION]);
		Dialog_Show(playerid, FORGOT_PASSWORD, DIALOG_STYLE_INPUT, "Forgot Password:", string, "Next", "Cancel");

		format(string, sizeof(string), "Incorrect answer! Your tries left: %i/"#MAX_LOGIN_ATTEMPTS" attempts.", playerAnswerAttempts[playerid]);
		SendClientMessage(playerid, COLOR_TOMATO, string);
	    return 1;
	}

	Dialog_Show(playerid, RESET_PASSWORD, DIALOG_STYLE_PASSWORD, "Reset Password:", COL_WHITE "Insert a new password for your account. Also in case you want to change security question for later, use /changeques.", "Confirm", "");

	SendClientMessage(playerid, COLOR_GREEN, "Successfully answered your security question! You shall now reset your password.");

	PlayerPlaySound(playerid, 1057, 0.0, 0.0, 0.0);
	return 1;
}

Dialog:RESET_PASSWORD(playerid, response, listitem, inputtext[])
{
	if (!response)
	{
		Dialog_Show(playerid, RESET_PASSWORD, DIALOG_STYLE_PASSWORD, "Reset Password:", COL_WHITE "Insert a new password for your account. Also in case you want to change security question for later, use /changeques.", "Confirm", "");
		return 1;
	}

	new string[256];

	if (!(MIN_PASSWORD_LENGTH <= strlen(inputtext) <= MAX_PASSWORD_LENGTH))
	{
	    Dialog_Show(playerid, RESET_PASSWORD, DIALOG_STYLE_PASSWORD, "Reset Password:", COL_WHITE "Insert a new password for your account. Also in case you want to change security question for later, use /changeques.", "Confirm", "");
		SendClientMessage(playerid, COLOR_TOMATO, "Invalid password length, must be between "#MIN_PASSWORD_LENGTH" - "#MAX_PASSWORD_LENGTH" characters.");
	    return 1;
	}

	SHA256_PassHash(inputtext, playerData[playerid][E_PLAYER_DATA_SALT], playerData[playerid][E_PLAYER_DATA_PASSWORD], 64);

	new name[MAX_PLAYER_NAME];
	GetPlayerName(playerid, name, MAX_PLAYER_NAME);
	
	new ip[18];
	GetPlayerIp(playerid, ip, 18);

	format(string, sizeof(string), "UPDATE `users` SET `password` = '%q', `ip` = '%s', `longip` = %i, `lastlogin_timestamp` = %i WHERE `id` = %i", playerData[playerid][E_PLAYER_DATA_PASSWORD], ip, IpToLong(ip), gettime(), playerData[playerid][E_PLAYER_DATA_SQLID]);
	db_query(db, string);

	format(string, sizeof(string), "Successfully logged in with new password! Welcome back to our server %s, we hope you enjoy your stay. [Last login: %s ago]", name, ReturnTimelapse(playerData[playerid][E_PLAYER_DATA_LASTLOG_TIMESTAMP], gettime()));
	SendClientMessage(playerid, COLOR_GREEN, string);
	
	PlayerPlaySound(playerid, 1057, 0.0, 0.0, 0.0);
	
	SetPVarInt(playerid, "LoggedIn", 1);
	CallRemoteFunction("OnPlayerLogin", "i", playerid);
	return 1;
}

Dialog:FORGOT_USERNAME(playerid, response, listitem, inputtext[])
{
	Kick(playerid);
	return 1;
}

// commands

CMD:kick(playerid, params[])
{
	if (GetPVarInt(playerid, "AdminLevel") < 1)
	{
		SendClientMessage(playerid, COLOR_TOMATO, "You are not allowed to use this command.");
		return 1;
	}

	new targetid;

	if(sscanf(params, "u", targetid))
	{ 
		SendClientMessage(playerid, COLOR_WHITE, "USAGE: {FFFFFF}/kick [id]");
		return 1;
	}

	if(!IsPlayerConnected(targetid) || targetid == INVALID_PLAYER_ID) 
	{
		SendClientMessage(playerid, COLOR_TOMATO, "The player is no more connected.");
		return 1;
	}

	if(GetPVarInt(targetid, "AdminLevel") > GetPVarInt(playerid, "AdminLevel"))
	{
		SendClientMessage(playerid, COLOR_TOMATO, "You are not allowed to use this command.");
		return 1;
	}

	Kick(targetid);

	return 1;
}

CMD:freeze(playerid, params[])
{
	if (GetPVarInt(playerid, "AdminLevel") < 1)
	{
		SendClientMessage(playerid, COLOR_TOMATO, "You are not allowed to use this command.");
		return 1;
	}

	new targetid;

	if(sscanf(params, "u", targetid))
	{ 
		SendClientMessage(playerid, COLOR_WHITE, "USAGE: {FFFFFF}/freeze [id]");
		return 1;
	}

	if(!IsPlayerConnected(targetid) || targetid == INVALID_PLAYER_ID) 
	{
		SendClientMessage(playerid, COLOR_TOMATO, "The player is no more connected.");
		return 1;
	}

	if(GetPVarInt(targetid, "AdminLevel") > GetPVarInt(playerid, "AdminLevel"))
	{
		SendClientMessage(playerid, COLOR_TOMATO, "You are not allowed to use this command.");
		return 1;
	}

	TogglePlayerControllable(targetid, false);

	return 1;

}

CMD:unfreeze(playerid, params[])
{
	if (GetPVarInt(playerid, "AdminLevel") < 1)
	{
		SendClientMessage(playerid, COLOR_TOMATO, "You are not allowed to use this command.");
		return 1;
	}

	new targetid;

	if(sscanf(params, "u", targetid))
	{ 
		SendClientMessage(playerid, COLOR_WHITE, "USAGE: {FFFFFF}/unfreeze [id]");
		return 1;
	}

	if(!IsPlayerConnected(targetid) || targetid == INVALID_PLAYER_ID) 
	{
		SendClientMessage(playerid, COLOR_WHITE, "The player is no more connected.");
		return 1;
	}

	if(GetPVarInt(targetid, "AdminLevel") > GetPVarInt(playerid, "AdminLevel"))
	{
		SendClientMessage(playerid, COLOR_TOMATO, "You are not allowed to use this command.");
		return 1;
	}

	TogglePlayerControllable(targetid, true);

	return 1;

}

CMD:changepass(playerid, params[])
{
	if (playerData[playerid][E_PLAYER_DATA_SQLID] != 1)
	{
		SendClientMessage(playerid, COLOR_TOMATO, "Only registered users can use this command.");
		return 1;
	}

    Dialog_Show(playerid, CHANGE_PASSWORD, DIALOG_STYLE_PASSWORD, "Change account password...", COL_WHITE "Insert a new password for your account, Passwords are "COL_YELLOW"case sensitive"COL_WHITE".", "Confirm", "Cancel");

	SendClientMessage(playerid, COLOR_WHITE, "Enter your new password.");

	PlayerPlaySound(playerid, 1054, 0.0, 0.0, 0.0);
	return 1;
}

Dialog:CHANGE_PASSWORD(playerid, response, listitem, inputtext[])
{
	if (!response)
		return 1;

	if (!(MIN_PASSWORD_LENGTH <= strlen(inputtext) <= MAX_PASSWORD_LENGTH))
	{
	    Dialog_Show(playerid, CHANGE_PASSWORD, DIALOG_STYLE_PASSWORD, "Change account password...", COL_WHITE "Insert a new password for your account, Passwords are "COL_YELLOW"case sensitive"COL_WHITE".", "Confirm", "Cancel");
		SendClientMessage(playerid, COLOR_TOMATO, "Invalid password length, must be between "#MIN_PASSWORD_LENGTH" - "#MAX_PASSWORD_LENGTH" characters.");
	    return 1;
	}

	SHA256_PassHash(inputtext, playerData[playerid][E_PLAYER_DATA_SALT], playerData[playerid][E_PLAYER_DATA_PASSWORD], 64);

	new string[256];
	for (new i, j = strlen(inputtext); i < j; i++)
	{
	    inputtext[i] = '*';
	}
	format(string, sizeof(string), "Successfully changed your password. [P: %s]", inputtext);

	SendClientMessage(playerid, COLOR_GREEN, string);

	PlayerPlaySound(playerid, 1057, 0.0, 0.0, 0.0);
	return 1;
}

CMD:changeques(playerid, params[])
{
	if (playerData[playerid][E_PLAYER_DATA_SQLID] != 1)
	{
		SendClientMessage(playerid, COLOR_TOMATO, "Only registered users can use this command.");
		return 1;
	}

    new list[2 + (sizeof(SECURITY_QUESTIONS) * MAX_SECURITY_QUESTION_SIZE)];
	for (new i; i < sizeof(SECURITY_QUESTIONS); i++)
	{
	    strcat(list, SECURITY_QUESTIONS[i]);
	    strcat(list, "\n");
	}
	Dialog_Show(playerid, CHANGE_SEC_QUESTION, DIALOG_STYLE_LIST, "Change account security question... [Step: 1/2]", list, "Continue", "Cancel");

	SendClientMessage(playerid, COLOR_WHITE, "[Step: 1/2] Select a security question. This will help you retrieve your password in case you forget it any time soon!");

	PlayerPlaySound(playerid, 1054, 0.0, 0.0, 0.0);
	return 1;
}

Dialog:CHANGE_SEC_QUESTION(playerid, response, listitem, inputext[])
{
	if (!response)
		return 1;

	SetPVarInt(playerid, "Question", listitem);

	new string[256];
	format(string, sizeof(string), COL_YELLOW "%s\n"COL_WHITE"Insert your answer below in the box. (don't worry about CAPS, answers are NOT case sensitive).", SECURITY_QUESTIONS[listitem]);
	Dialog_Show(playerid, CHANGE_SEC_ANSWER, DIALOG_STYLE_INPUT, "Change account security question... [Step: 2/2]", string, "Confirm", "Back");

	SendClientMessage(playerid, COLOR_WHITE, "[Step: 2/2] Write the answer to your secuirty question.");

	PlayerPlaySound(playerid, 1054, 0.0, 0.0, 0.0);
	return 1;
}

Dialog:CHANGE_SEC_ANSWER(playerid, response, listitem, inputtext[])
{
	if (!response)
	{
		new list[2 + (sizeof(SECURITY_QUESTIONS) * MAX_SECURITY_QUESTION_SIZE)];
		for (new i; i < sizeof(SECURITY_QUESTIONS); i++)
		{
		    strcat(list, SECURITY_QUESTIONS[i]);
		    strcat(list, "\n");
		}
		Dialog_Show(playerid, CHANGE_SEC_QUESTION, DIALOG_STYLE_LIST, "Change account security question... [Step: 1/2]", list, "Continue", "Cancel");

		SendClientMessage(playerid, COLOR_WHITE, "[Step: 1/2] Select a security question. This will help you retrieve your password in case you forget it any time soon!");
		return 1;
	}

	new string[512];

	if (strlen(inputtext) < MIN_PASSWORD_LENGTH || inputtext[0] == ' ')
	{
	    format(string, sizeof(string), COL_YELLOW "%s\n"COL_WHITE"Insert your answer below in the box. (don't worry about CAPS, answers are NOT case sensitive).", SECURITY_QUESTIONS[listitem]);
		Dialog_Show(playerid, CHANGE_SEC_ANSWER, DIALOG_STYLE_INPUT, "Change account security question... [Step: 2/2]", string, "Confirm", "Back");

		SendClientMessage(playerid, COLOR_TOMATO, "Security answer cannot be an less than "#MIN_PASSWORD_LENGTH" characters.");
		return 1;
	}

	format(playerData[playerid][E_PLAYER_DATA_SEC_QUESTION], MAX_SECURITY_QUESTION_SIZE, SECURITY_QUESTIONS[GetPVarInt(playerid, "Question")]);
	DeletePVar(playerid, "Question");

	for (new i, j = strlen(inputtext); i < j; i++)
	{
        inputtext[i] = tolower(inputtext[i]);
	}
	SHA256_PassHash(inputtext, playerData[playerid][E_PLAYER_DATA_SALT], playerData[playerid][E_PLAYER_DATA_SEC_ANSWER], 64);

	format(string, sizeof(string), "Successfully changed your security answer and question [Q: %s].", playerData[playerid][E_PLAYER_DATA_SEC_QUESTION]);
	SendClientMessage(playerid, COLOR_GREEN, string);

	PlayerPlaySound(playerid, 1057, 0.0, 0.0, 0.0);
	return 1;
}

CMD:stats(playerid, params[])
{
	new targetid;
	if (sscanf(params, "u", targetid))
	{
  		targetid = playerid;
		SendClientMessage(playerid, COLOR_DEFAULT, "Tip: You can also view other players stats by /stats [player]");
	}

	if (!IsPlayerConnected(targetid))
	{
		return SendClientMessage(playerid, COLOR_TOMATO, "The player is no more connected.");
	}
	
	new name[MAX_PLAYER_NAME];
	GetPlayerName(targetid, name, MAX_PLAYER_NAME);

	new string[150];
	SendClientMessage(playerid, COLOR_GREEN, "_______________________________________________");
	SendClientMessage(playerid, COLOR_GREEN, "");
	format(string, sizeof(string), "%s[%i]'s stats: (AccountId: %i)", name, targetid, playerData[targetid][E_PLAYER_DATA_SQLID]);
	SendClientMessage(playerid, COLOR_GREEN, string);

	new Float:ratio = ((playerData[targetid][E_PLAYER_DATA_DEATHS] < 0) ? (0.0) : (floatdiv(playerData[targetid][E_PLAYER_DATA_KILLS], playerData[targetid][E_PLAYER_DATA_DEATHS])));

	static levelname[6][25];
	if (!levelname[0][0])
	{
		levelname[0] = "Player";
		levelname[1] = "Operator";
		levelname[2] = "Moderator";
		levelname[3] = "Administrator";
		levelname[4] = "Manager";
		levelname[5] = "Owner/RCON";
	}

	format(string, sizeof (string),
		"Level: %i || \
		Money: $%i || \
		Kills: %i || \
		Deaths: %i || \
		Ratio: %0.2f || \
		Admin Level: %i - %s || \
		Vip Level: %i",
		GetPlayerScore(targetid),
		GetPlayerMoney(targetid),
		playerData[targetid][E_PLAYER_DATA_KILLS],
		playerData[targetid][E_PLAYER_DATA_DEATHS],
		ratio, GetPVarInt(playerid, "AdminLevel"),
		levelname[((GetPVarInt(playerid, "AdminLevel") > 5) ? (5) : (GetPVarInt(playerid, "AdminLevel")))],
		GetPVarInt(playerid, "VipLevel"));
	SendClientMessage(playerid, COLOR_GREEN, string);

	format(string, sizeof (string),
		"Registeration On: %s || \
		Last Seen: %s",
	 	ReturnTimelapse(playerData[playerid][E_PLAYER_DATA_REG_TIMESTAMP],
		 gettime()),
		 ReturnTimelapse(playerData[playerid][E_PLAYER_DATA_LASTLOG_TIMESTAMP], gettime()));
	SendClientMessage(playerid, COLOR_GREEN, string);

	SendClientMessage(playerid, COLOR_GREEN, "");
	SendClientMessage(playerid, COLOR_GREEN, "_______________________________________________");
	return 1;
}
