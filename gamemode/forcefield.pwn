#include <a_samp>

#include <fader>
#include <streamer>
#include <YSI\y_iterate>

#define FADE_FROM_COLOR \
	((0xA30000FF & ~0xFF) | 25)
	
#define FADE_TO_COLOR \
	((0xA30000FF & ~0xFF) | 150)

new const reductionTimerCountdown[] =
{
	((3 *60*1000) + (15 *1000)),
	((2 *60*1000) + (45 *1000)),
	((2 *60*1000) + (25 *1000)),
	((1 *60*1000) + (35 *1000)),
	((1 *60*1000) + (15 *1000)),
	((0 *60*1000) + (45 *1000)),
};

new const Float:reductionNumbers[sizeof reductionTimerCountdown][3] =
{
 	{15.0, 14.0, 13.0},
	{10.0, 9.5, 9.0},
	{9.0, 8.8, 8.5},
	{8.0, 7.5, 7.0},
	{5.5, 5.0, 4.5},
	{3.5, 3.0, 2.5}
};

new reductionTimer = -1;
new reductionIndex;
new secondsPast;

new Float:redField[4];
new redForcefield[4] = {-1, -1, -1, -1};
new redAreaid = INVALID_STREAMER_ID;

new Float:whiteField[4];
new whiteForcefield[4] = {-1, -1, -1, -1};
new whiteAreaid = INVALID_STREAMER_ID;

new Text:bloodFaderTextDraw = Text:INVALID_TEXT_DRAW;
new bool:leftRedArea[MAX_PLAYERS];

new Text:announcementTextDraw;
new Text:countDownTextDraw;

CreateForceField(gangzone[4], &area, color, Float:size, Float:minx, Float:miny, Float:maxx, Float:maxy)
{
	new Float:tmp;
	if (maxx < minx)
	{
	    tmp = maxx;
	    maxx = minx;
	    minx = tmp;
	}
	if (maxy < miny)
	{
	    tmp = maxy;
	    maxy = miny;
	    miny = tmp;
	}

    GangZoneDestroy(gangzone[0]);
	GangZoneDestroy(gangzone[1]);
	GangZoneDestroy(gangzone[2]);
	GangZoneDestroy(gangzone[3]);
	
    size *= 3;
    gangzone[0] = GangZoneCreate((minx - size), miny, (minx + size), maxy);
	gangzone[1] = GangZoneCreate((minx - size), (maxy - size), maxx, (maxy + size));
	gangzone[2] = GangZoneCreate((maxx - size), miny, (maxx + size), maxy);
	gangzone[3] = GangZoneCreate((minx - size), (miny - size), maxx, (miny + size));

	GangZoneShowForAll(gangzone[0], color);
	GangZoneShowForAll(gangzone[1], color);
	GangZoneShowForAll(gangzone[2], color);
	GangZoneShowForAll(gangzone[3], color);

	Streamer_SetFloatData(STREAMER_TYPE_AREA, area, E_STREAMER_MIN_X, minx);
	Streamer_SetFloatData(STREAMER_TYPE_AREA, area, E_STREAMER_MIN_Y, miny);
	Streamer_SetFloatData(STREAMER_TYPE_AREA, area, E_STREAMER_MAX_X, maxx);
	Streamer_SetFloatData(STREAMER_TYPE_AREA, area, E_STREAMER_MAX_Y, maxy);
	foreach (new i : Player)
	{
	    Streamer_Update(i, STREAMER_TYPE_AREA);
	}
	return 1;
}

ForceField_Init(Float:red_minx, Float:red_miny, Float:red_maxx, Float:red_maxy, Float:white_minx, Float:white_miny, Float:white_maxx, Float:white_maxy)
{
    announcementTextDraw = TextDrawCreate(319.000000, 230.000000, "-");
	TextDrawAlignment(announcementTextDraw, 2);
	TextDrawBackgroundColor(announcementTextDraw, 255);
	TextDrawFont(announcementTextDraw, 2);
	TextDrawLetterSize(announcementTextDraw, 0.389999, 2.199997);
	TextDrawColor(announcementTextDraw, 297271295);
	TextDrawSetOutline(announcementTextDraw, 1);
	TextDrawSetProportional(announcementTextDraw, 1);
	TextDrawSetSelectable(announcementTextDraw, 0);
	
	countDownTextDraw = TextDrawCreate(42.000000, 300.000000, "Next Zone Reduction: -:-");
	TextDrawBackgroundColor(countDownTextDraw, 255);
	TextDrawFont(countDownTextDraw, 1);
	TextDrawLetterSize(countDownTextDraw, 0.280000, 1.599997);
	TextDrawColor(countDownTextDraw, -1);
	TextDrawSetOutline(countDownTextDraw, 1);
	TextDrawSetProportional(countDownTextDraw, 1);
	TextDrawSetSelectable(countDownTextDraw, 0);

    redField[0] = red_minx;
    redField[1] = red_miny;
    redField[2] = red_maxx;
    redField[3] = red_maxy;
    
    whiteField[0] = white_minx;
    whiteField[1] = white_miny;
    whiteField[2] = white_maxx;
    whiteField[3] = white_maxy;
    
    bloodFaderTextDraw = TextDrawCreate(0.0, 0.0, "~r~");
	TextDrawTextSize(bloodFaderTextDraw, 640.0, 480.0);
	TextDrawLetterSize(bloodFaderTextDraw, 0.0, 50.0);
	TextDrawUseBox(bloodFaderTextDraw, 1);

    redAreaid = CreateDynamicRectangle(redField[0], redField[1], redField[2], redField[3]);
    CreateForceField(redForcefield, redAreaid, 0xFF0000FF, 1, redField[0], redField[1], redField[2], redField[3]);

    whiteAreaid = CreateDynamicRectangle(whiteField[0], whiteField[1], whiteField[2], whiteField[3]);
    CreateForceField(whiteForcefield, whiteAreaid, 0xFFFFFFFF, 1, whiteField[0], whiteField[1], whiteField[2], whiteField[3]);

    reductionTimer = SetTimer("OnForceFieldReduce", 100, true);
    secondsPast = 0;
    
    new seconds = reductionTimerCountdown[reductionIndex] / 1000;
	new minutes = seconds / 60;
	seconds = seconds % 60;

	new string[128];
	if (minutes != 0)
	{
		format(string, sizeof string, "~y~Reducing player area in %i min %i secs", minutes, seconds);
		TextDrawSetString(announcementTextDraw, string);
		foreach (new i : Player)
		{
		    if (GetPVarInt(i, "LoggedIn") == 1)
		    {
		        TextDrawShowForPlayer(i, announcementTextDraw);
		        SetTimerEx("OnAnnouncementExpire", 5000, false, "i", i);
		    }
		}
	}
	else
	{
		format(string, sizeof string, "~y~Reducing player area in %i secs", seconds);
		TextDrawSetString(announcementTextDraw, string);
		foreach (new i : Player)
		{
		    if (GetPVarInt(i, "LoggedIn") == 1)
		    {
		        TextDrawShowForPlayer(i, announcementTextDraw);
		        SetTimerEx("OnAnnouncementExpire", 5000, false, "i", i);
		    }
		}
	}
	
	foreach (new i : Player)
	{
	    if (GetPVarInt(i, "LoggedIn") == 1)
	    {
	        TextDrawShowForPlayer(i, countDownTextDraw);
	    }
	}
	return 1;
}

forward OnAnnouncementExpire(playerid);
public OnAnnouncementExpire(playerid)
{
    return TextDrawHideForPlayer(playerid, announcementTextDraw);
}

ForceField_Exit()
{
	TextDrawDestroy(announcementTextDraw);
	TextDrawDestroy(countDownTextDraw);

	KillTimer(reductionTimer);
	reductionTimer = - 1;

	foreach (new i : Player)
	{
	    TextDrawStopBoxFadeForPlayer(i, bloodFaderTextDraw);
	}
	TextDrawDestroy(bloodFaderTextDraw);
	bloodFaderTextDraw = Text:INVALID_TEXT_DRAW;

    GangZoneDestroy(redForcefield[0]);
	GangZoneDestroy(redForcefield[1]);
	GangZoneDestroy(redForcefield[2]);
	GangZoneDestroy(redForcefield[3]);
	DestroyDynamicArea(redAreaid);

    GangZoneDestroy(whiteForcefield[0]);
	GangZoneDestroy(whiteForcefield[1]);
	GangZoneDestroy(whiteForcefield[2]);
	GangZoneDestroy(whiteForcefield[3]);
	DestroyDynamicArea(whiteAreaid);
	return 1;
}

forward OnForceFieldReduce();
public OnForceFieldReduce()
{
	secondsPast += 100;
    if (secondsPast < reductionTimerCountdown[reductionIndex])
    {
	    new seconds = ((reductionTimerCountdown[reductionIndex] / 1000) - (secondsPast / 1000));
		new minutes = seconds / 60;
		seconds = seconds % 60;

		new string[128];
		format(string, sizeof string, "Next Zone Reduction: %02i:%02i", minutes, seconds);
		TextDrawSetString(countDownTextDraw, string);
        return;
    }

    TextDrawSetString(countDownTextDraw, "Next Zone Reduction: -:-");

    const updaterate = 20;

	new closed;
	new Float:diff;
	for (new i; i < 4; i++)
	{
	    if (redField[i] > whiteField[i])
	    {
	        diff = floatabs(redField[i] - whiteField[i]);
	        if (diff < 5.0)
	        {
	            redField[i] = whiteField[i];
	        }
	        else
	        {
	        	redField[i] -= diff / updaterate;
			}

	        if (redField[i] <= whiteField[i])
	        {
	            closed++;
	        }
	    }
	    else if (redField[i] < whiteField[i])
	    {
	        diff = floatabs(whiteField[i] - redField[i]);
			if (diff < 5.0)
	        {
	            redField[i] = whiteField[i];
	        }
	        else
	        {
	        	redField[i] += diff / updaterate;
			}

	        if (redField[i] >= whiteField[i])
	        {
	            closed++;
	        }
	    }
	    else
	    {
	        closed++;
	        continue;
	    }

	    CreateForceField(redForcefield, redAreaid, 0xFF0000FF, 1, redField[0], redField[1], redField[2], redField[3]);
	}

	if (closed == 4)
	{
	    diff = floatabs(whiteField[2] - whiteField[0]);
	    whiteField[0] += diff / reductionNumbers[reductionIndex][random(sizeof reductionNumbers[])];
	    whiteField[2] -= diff / reductionNumbers[reductionIndex][random(sizeof reductionNumbers[])];

		diff = floatabs(whiteField[3] - whiteField[1]);
	    whiteField[1] += diff / reductionNumbers[reductionIndex][random(sizeof reductionNumbers[])];
	    whiteField[3] -= diff / reductionNumbers[reductionIndex][random(sizeof reductionNumbers[])];

	    CreateForceField(whiteForcefield, whiteAreaid, 0xFFFFFFFF, 1, whiteField[0], whiteField[1], whiteField[2], whiteField[3]);

		KillTimer(reductionTimer);
	    if (reductionIndex == sizeof reductionTimerCountdown)
		{
		    return;
		}

        reductionIndex++;
		reductionTimer = SetTimerEx("OnForceFieldReduce", 100, true, "ii", reductionTimerCountdown[reductionIndex], reductionIndex);
		secondsPast = 0;

		new seconds = reductionTimerCountdown[reductionIndex] / 1000;
		new minutes = seconds / 60;
		seconds = seconds % 60;

		new string[150];
		if (minutes != 0)
		{
			format(string, sizeof string, "~y~Reducing player area in %i min %i secs", minutes, seconds);
			TextDrawSetString(announcementTextDraw, string);
			foreach (new i : Player)
			{
			    if (GetPVarInt(i, "LoggedIn") == 1)
			    {
			        TextDrawShowForPlayer(i, announcementTextDraw);
			        SetTimerEx("OnAnnouncementExpire", 5000, false, "i", i);
			    }
			}

			format(string, sizeof string, "The player area has been reduced. Next reduction will be in \"%i min %i secs\".", minutes, seconds);
			SendClientMessageToAll(-1, string);
		}
		else
		{
			format(string, sizeof string, "~y~Reducing player area in %i secs", seconds);
			TextDrawSetString(announcementTextDraw, string);
			foreach (new i : Player)
			{
			    if (GetPVarInt(i, "LoggedIn") == 1)
			    {
			        TextDrawShowForPlayer(i, announcementTextDraw);
			        SetTimerEx("OnAnnouncementExpire", 5000, false, "i", i);
			    }
			}

			format(string, sizeof string, "The player area has been reduced. Next reduction will be in \"%i secs\".", seconds);
			SendClientMessageToAll(-1, string);
		}
	}
}

public OnPlayerConnect(playerid)
{
	leftRedArea[playerid] = false;

	#if defined FF_OnPlayerConnect
		return FF_OnPlayerConnect(playerid);
	#else
		return 1;
	#endif
}
#if defined _ALS_OnPlayerConnect
	#undef OnPlayerConnect
#else
	#define _ALS_OnPlayerConnect
#endif
#define OnPlayerConnect FF_OnPlayerConnect
#if defined FF_OnPlayerConnect
	forward FF_OnPlayerConnect(playerid);
#endif

public OnPlayerEnterDynamicArea(playerid, areaid)
{
	if (areaid == redAreaid)
	{
	    if (leftRedArea[playerid])
	    {
		    if (GetPlayerState(playerid) != PLAYER_STATE_WASTED)
		    {
		    	GameTextForPlayer(playerid, "~w~You are in safe zone!", 3000, 3);

		        TextDrawColor(bloodFaderTextDraw, 0);
		        TextDrawHideForPlayer(playerid, bloodFaderTextDraw);
		        TextDrawStopBoxFadeForPlayer(playerid, bloodFaderTextDraw);
		        leftRedArea[playerid] = false;
			}
	    }
	}

   	#if defined FF_OnPlayerEnterDynamicArea
		return FF_OnPlayerEnterDynamicArea(playerid, areaid);
	#else
		return 1;
	#endif
}
#if defined _ALS_OnPlayerEnterDynamicArea
	#undef OnPlayerEnterDynamicArea
#else
	#define _ALS_OnPlayerEnterDynamicArea
#endif
#define OnPlayerEnterDynamicArea FF_OnPlayerEnterDynamicArea
#if defined FF_OnPlayerEnterDynamicArea
	forward FF_OnPlayerEnterDynamicArea(playerid, areaid);
#endif

public OnPlayerLeaveDynamicArea(playerid, areaid)
{
	if (areaid == redAreaid)
	{
	    if (GetPlayerState(playerid) != PLAYER_STATE_WASTED)
	    {
		    GameTextForPlayer(playerid, "~r~You will lose health out off red zone!", 3000, 3);

		    TextDrawFadeBoxForPlayer(playerid, bloodFaderTextDraw, FADE_FROM_COLOR, FADE_TO_COLOR);
		    leftRedArea[playerid] = true;
		}
	}
	
    #if defined FF_OnPlayerLeaveDynamicArea
		return FF_OnPlayerLeaveDynamicArea(playerid, areaid);
	#else
		return 1;
	#endif
}
#if defined _ALS_OnPlayerLeaveDynamicArea
	#undef OnPlayerLeaveDynamicArea
#else
	#define _ALS_OnPlayerLeaveDynamicArea
#endif
#define OnPlayerLeaveDynamicArea FF_OnPlayerLeaveDynamicArea
#if defined FF_OnPlayerLeaveDynamicArea
	forward FF_OnPlayerLeaveDynamicArea(playerid, areaid);
#endif

public OnPlayerDeath(playerid, killerid, reason)
{
	TextDrawStopBoxFadeForPlayer(playerid, bloodFaderTextDraw);

	#if defined FF_OnPlayerDeath
		return FF_OnPlayerDeath(playerid, killerid, reason);
	#else
		return 1;
	#endif
}
#if defined _ALS_OnPlayerDeath
	#undef OnPlayerDeath
#else
	#define _ALS_OnPlayerDeath
#endif
#define OnPlayerDeath FF_OnPlayerDeath
#if defined FF_OnPlayerDeath
	forward FF_OnPlayerDeath(playerid, killerid, reason);
#endif

public OnTextDrawFade(Text:text, forplayerid, bool:isbox, newcolor, finalcolor)
{
	if (text == bloodFaderTextDraw)
	{
		if (newcolor == FADE_TO_COLOR)
		{
		    new Float:health;
		    GetPlayerHealth(forplayerid, health);
		    SetPlayerHealth(forplayerid, health - 5.0);

		    GameTextForPlayer(forplayerid, "~r~You are losing health outside red zone!", 3000, 3);
			TextDrawFadeBoxForPlayer(forplayerid, bloodFaderTextDraw, FADE_TO_COLOR, FADE_FROM_COLOR);
		}
		else if (newcolor == FADE_FROM_COLOR)
		{
		    new Float:health;
		    GetPlayerHealth(forplayerid, health);
		    SetPlayerHealth(forplayerid, health - 5.0);

		    GameTextForPlayer(forplayerid, "~r~You are losing health outside red zone!", 3000, 3);
			TextDrawFadeBoxForPlayer(forplayerid, bloodFaderTextDraw, FADE_FROM_COLOR, FADE_TO_COLOR);
		}
	}

	#if defined FF_OnTextDrawFade
		return FF_OnTextDrawFade(text, forplayerid, isbox, newcolor, finalcolor);
	#else
		return 1;
	#endif
}
#if defined _ALS_OnTextDrawFade
	#undef OnTextDrawFade
#else
	#define _ALS_OnTextDrawFade
#endif
#define OnTextDrawFade FF_OnTextDrawFade
#if defined FF_OnTextDrawFade
	forward FF_OnTextDrawFade(Text:text, forplayerid, bool:isbox, newcolor, finalcolor);
#endif

public OnPlayerSpawn(playerid)
{
	if (reductionTimer != -1)
	{
		TextDrawStopBoxFadeForPlayer(playerid, bloodFaderTextDraw);
	
	    GangZoneShowForPlayer(playerid, redForcefield[0], 0xFF0000FF);
		GangZoneShowForPlayer(playerid, redForcefield[1], 0xFF0000FF);
		GangZoneShowForPlayer(playerid, redForcefield[2], 0xFF0000FF);
		GangZoneShowForPlayer(playerid, redForcefield[3], 0xFF0000FF);

	    GangZoneShowForPlayer(playerid, whiteForcefield[0], 0xFFFFFFFF);
		GangZoneShowForPlayer(playerid, whiteForcefield[1], 0xFFFFFFFF);
		GangZoneShowForPlayer(playerid, whiteForcefield[2], 0xFFFFFFFF);
		GangZoneShowForPlayer(playerid, whiteForcefield[3], 0xFFFFFFFF);

		if (reductionIndex != sizeof reductionTimerCountdown)
		{
			new seconds = (reductionTimerCountdown[reductionIndex] - secondsPast) / 1000;
			new minutes = seconds / 60;
			seconds = seconds % 60;

			new string[128];
			if (minutes != 0)
			{
				format(string, sizeof string, "~y~Reducing player area in %i min %i secs", minutes, seconds);
			}
			else
			{
				format(string, sizeof string, "~y~Reducing player area in %i secs", seconds);
			}
			TextDrawSetString(announcementTextDraw, string);
			TextDrawShowForPlayer(playerid, announcementTextDraw);
			SetTimerEx("OnAnnouncementExpire", 5000, false, "i", playerid);
		}
	}
	
	#if defined FF_OnPlayerSpawn
		return FF_OnPlayerSpawn(playerid);
	#else
		return 1;
	#endif
}
#if defined _ALS_OnPlayerSpawn
	#undef OnPlayerSpawn
#else
	#define _ALS_OnPlayerSpawn
#endif
#define OnPlayerSpawn FF_OnPlayerSpawn
#if defined FF_OnPlayerSpawn
	forward FF_OnPlayerSpawn(playerid);
#endif
