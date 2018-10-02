#include <a_samp>

#include <streamer>
#include <colandreas>
#include <sscanf2>
#include <zcmd>
#include <pawno/include/PreviewModelDialog.inc> // TODO: Fix import path
#include <easydialog>

// Settings
enum
{
	BACKGROUND = 1263615688,
	LEFT_BACKGROUND = 1853316296,
	RIGHT_BACKGROUND = 1853316296,
	SELECTED = 0xd63417BB,
	FONT = 1,
	MAX_PLAYER_ITEMS = 10 // maximum = 15
};
//

#define COLOR_TOMATO \
	0xFF6347FF
#define COL_TOMATO \
	"{FF6347}"

#define COLOR_GREEN \
	0x00FF00FF
#define COL_GREEN \
	"{00FF00}"

#define COLOR_DEFAULT \
	0xA9C4E4FF
#define COL_DEFAULT \
	"{A9C4E4}"

#define PAGES(%0,%1) \
	(((%0) - 1) / (%1) + 1)

#define MAX_MENU_TEXTDRAWS \
	100
#define MAX_MENU_PLAYER_TEXTDRAWS \
	50

#define MAX_RIGHT_MENU_COLUMNS \
	5
#define MAX_RIGHT_MENU_ROWS \
	3

#define MAX_LEFT_MENU_ROWS \
	7

#define MAX_ITEMS \
	1000

#define MAX_ITEM_NAME \
	64

enum E_MENU_TEXTDRAW
{
    E_MENU_TEXTDRAW_SCROLL_UP,
    E_MENU_TEXTDRAW_SCROLL_DOWN,
    E_MENU_TEXTDRAW_SCROLL,
    E_MENU_TEXTDRAW_LEFT_BOX[MAX_RIGHT_MENU_COLUMNS * MAX_RIGHT_MENU_ROWS],
    E_MENU_TEXTDRAW_LEFT_MODEL[MAX_RIGHT_MENU_COLUMNS * MAX_RIGHT_MENU_ROWS],
    E_MENU_TEXTDRAW_LEFT_TEXT[MAX_RIGHT_MENU_COLUMNS * MAX_RIGHT_MENU_ROWS],
    E_MENU_TEXTDRAW_RIGHT_MODEL[MAX_RIGHT_MENU_COLUMNS * MAX_RIGHT_MENU_ROWS],
    E_MENU_TEXTDRAW_RIGHT_NUMBER[MAX_RIGHT_MENU_COLUMNS * MAX_RIGHT_MENU_ROWS],
    E_MENU_TEXTDRAW_RIGHT_TEXT[MAX_RIGHT_MENU_COLUMNS * MAX_RIGHT_MENU_ROWS],
    E_MENU_TEXTDRAW_LEFT_COUNT,
    E_MENU_TEXTDRAW_RIGHT_COUNT,
    E_MENU_TEXTDRAW_LEFTBTN,
    E_MENU_TEXTDRAW_RIGHTBTN,
    E_MENU_TEXTDRAW_MIDDLEBTN,
    E_MENU_TEXTDRAW_CLOSE,
    E_MENU_TEXTDRAW_EMPTY_LEFT[2],
	E_MENU_TEXTDRAW_EMPTY_RIGHT[2]
};
new Text:menuTextDraw[MAX_MENU_TEXTDRAWS];
new menuTextDrawID[E_MENU_TEXTDRAW];
new menuTextDrawCount;

new PlayerText:menuPlayerTextDraw[MAX_PLAYERS][MAX_MENU_PLAYER_TEXTDRAWS];
new menuPlayerTextDrawID[MAX_PLAYERS][E_MENU_TEXTDRAW];
new menuPlayerTextDrawCount[MAX_PLAYERS];

new bool:playerUsingMenu[MAX_PLAYERS];

new playerLeftMenuClickTickCount[MAX_PLAYERS][MAX_LEFT_MENU_ROWS];
new playerRightMenuClickTickCount[MAX_PLAYERS][MAX_PLAYER_ITEMS];

enum E_ITEM
{
	bool:E_ITEM_VALID,
	E_ITEM_NAME[MAX_ITEM_NAME],
	E_ITEM_OBJECTID,
	Float:E_ITEM_ROTX,
	Float:E_ITEM_ROTY,
	Float:E_ITEM_ROTZ,
	Float:E_ITEM_ZPUSH,
	E_ITEM_PLAYERID,
	E_ITEM_AREAID,
	E_ITEM_MODELID
};
new item[MAX_ITEMS][E_ITEM];
new itemPoolSize = -1;

new nearbyItems[MAX_PLAYERS][MAX_PLAYER_ITEMS * 3];
new nearbyItemsCount[MAX_PLAYERS];

new playerInventoryItems[MAX_PLAYERS][MAX_PLAYER_ITEMS];
new playerInventoryItemsCount[MAX_PLAYERS];

new playerLeftMenuPage[MAX_PLAYERS];
new playerLeftMenuListitem[MAX_PLAYERS];
new playerRightMenuListitem[MAX_PLAYERS];

new PlayerText:playerItemPickupTextDraw[MAX_PLAYERS];

ScrollBar(page, totalPages, &Float:y, Float:maxHeight, &Float:height)
{
	height = maxHeight / totalPages;
	y += (height * 9) * page;
}

Inv_AddItem(modelid, const name[], Float:x, Float:y, Float:z, Float:rx = 0.0, Float:ry = 0.0, Float:rz = 0.0, Float:zpush = 0.0)
{
	new index = -1;
	for (new i; i < MAX_ITEMS; i++)
	{
	    if (!item[i][E_ITEM_VALID])
	    {
	        index = i;
	        break;
	    }
	}

	if (index == -1)
	{
	    return -1;
	}

	if (index > itemPoolSize)
	{
	    itemPoolSize = index;
	}

 	item[index][E_ITEM_VALID] = true;

	format(item[index][E_ITEM_NAME], MAX_ITEM_NAME, name);

	CA_FindZ_For2DCoord(x, y, z);
 	item[index][E_ITEM_OBJECTID] = CreateDynamicObject(modelid, x, y, z, rx, ry, rz);

 	new Float:unused, Float:radius;
 	CA_GetModelBoundingSphere(modelid, unused, unused, unused, radius);
  	item[index][E_ITEM_AREAID] = CreateDynamicCircle(x, y, radius + 2.0);

	item[index][E_ITEM_ROTX] = rx;
	item[index][E_ITEM_ROTY] = ry;
	item[index][E_ITEM_ROTZ] = rz;

	item[index][E_ITEM_ZPUSH] = zpush;

 	item[index][E_ITEM_PLAYERID] = INVALID_PLAYER_ID;

   	item[index][E_ITEM_MODELID] = modelid;
	return index;
}

Inv_RemoveItem(itemid)
{
	if (item[itemid][E_ITEM_PLAYERID] == INVALID_PLAYER_ID)
	{
	    DestroyDynamicObject(item[itemid][E_ITEM_OBJECTID]);
		item[itemid][E_ITEM_OBJECTID] = INVALID_STREAMER_ID;
 		DestroyDynamicArea(item[itemid][E_ITEM_AREAID]);
		item[itemid][E_ITEM_AREAID] = INVALID_STREAMER_ID;

	    for (new i, j = GetPlayerPoolSize(); i <= j; i++)
	    {
	        if (IsPlayerConnected(i) && playerUsingMenu[i])
	        {
		    	Inv_UpdateLeftMenu(i);
				Inv_UpdatePlaiyerPickupTextDraw(i);
			}
    	}
	}
	else
	{
	    new playerid = item[itemid][E_ITEM_PLAYERID];
	    for (new i; i < playerInventoryItemsCount[playerid]; i++)
		{
		    if (playerInventoryItems[playerid][i] == itemid)
		    {
		       	for (; i < (playerInventoryItemsCount[playerid] - 1); i++)
		        {
		        	playerInventoryItems[playerid][i] = playerInventoryItems[playerid][i + 1];
		        }
		        playerInventoryItemsCount[playerid]--;
		        break;
		    }
		}

		Inv_UpdateRightMenu(playerid);
	}

	item[itemid][E_ITEM_VALID] = false;

	if (itemid == itemPoolSize)
	{
		for (new i = itemPoolSize; i != -1; i--)
		{
            if (!item[i][E_ITEM_VALID])
            {
                continue;
            }

            itemPoolSize = i;
            break;
		}
	}
	return 1;
}

Inv_EditItem(playerid, itemid)
{
	if (itemid < 0 || itemid > itemPoolSize)
	{
		return 0;
	}

	if (item[itemid][E_ITEM_PLAYERID] != INVALID_PLAYER_ID)
	{
		return 0;
	}

	GetDynamicObjectPos(item[itemid][E_ITEM_OBJECTID], item[itemid][E_ITEM_ZPUSH], item[itemid][E_ITEM_ZPUSH], item[itemid][E_ITEM_ZPUSH]);
	return EditDynamicObject(playerid, item[itemid][E_ITEM_OBJECTID]);
}

Inv_Show(playerid)
{
    playerLeftMenuPage[playerid] = 0;
    playerLeftMenuListitem[playerid] = 0;
    playerRightMenuListitem[playerid] = 0;


    new bool:skip;
 	for (new i; i < menuTextDrawCount; i++)
    {
        if (menuTextDrawID[E_MENU_TEXTDRAW_EMPTY_LEFT][0] == i || menuTextDrawID[E_MENU_TEXTDRAW_EMPTY_LEFT][1] == i)
	    {
	      	continue;
		}

        if (menuTextDrawID[E_MENU_TEXTDRAW_EMPTY_RIGHT][0] == i || menuTextDrawID[E_MENU_TEXTDRAW_EMPTY_RIGHT][1] == i)
	    {
	      	continue;
		}

	    for (new x; x < MAX_LEFT_MENU_ROWS; x++)
	    {
	        if (menuTextDrawID[E_MENU_TEXTDRAW_LEFT_BOX][x] == i || menuTextDrawID[E_MENU_TEXTDRAW_LEFT_MODEL][x] == i)
	        {
	            skip = true;
       			break;
			}
		}

        for (new x; x < (MAX_RIGHT_MENU_ROWS * MAX_RIGHT_MENU_COLUMNS); x++)
	    {
	        if (menuTextDrawID[E_MENU_TEXTDRAW_RIGHT_MODEL][x] == i || menuTextDrawID[E_MENU_TEXTDRAW_RIGHT_NUMBER][x] == i)
	        {
	            skip = true;
	            break;
			}
		}

		if (skip)
		{
		    skip = false;
		    continue;
		}
        TextDrawShowForPlayer(playerid, menuTextDraw[i]);
    }

    for (new i; i < menuPlayerTextDrawCount[playerid]; i++)
    {
        for (new x; x < MAX_LEFT_MENU_ROWS; x++)
	    {
	        if (menuPlayerTextDrawID[playerid][E_MENU_TEXTDRAW_LEFT_TEXT][x] == i)
	        {
	            skip = true;
	            break;
			}
		}

        for (new x; x < (MAX_RIGHT_MENU_ROWS * MAX_RIGHT_MENU_COLUMNS); x++)
	    {
	        if (menuPlayerTextDrawID[playerid][E_MENU_TEXTDRAW_RIGHT_TEXT][x] == i)
	        {
	            skip = true;
	            break;
			}
		}

		if (skip)
		{
		    skip = false;
		    continue;
		}
        PlayerTextDrawShow(playerid, menuPlayerTextDraw[playerid][i]);
    }

    Inv_UpdateLeftMenu(playerid);
    Inv_UpdateRightMenu(playerid);

    playerUsingMenu[playerid] = true;
    return SelectTextDraw(playerid, 0xBB);
}

Inv_Hide(playerid)
{
    for (new i; i < menuTextDrawCount; i++)
 	{
  		TextDrawHideForPlayer(playerid, menuTextDraw[i]);
    }

	for (new i; i < menuPlayerTextDrawCount[playerid]; i++)
 	{
  		PlayerTextDrawHide(playerid, menuPlayerTextDraw[playerid][i]);
    }

    playerUsingMenu[playerid] = false;
    return CancelSelectTextDraw(playerid);
}

Inv_UpdateLeftMenu(playerid)
{
    nearbyItemsCount[playerid] = 0;
	for (new i; i <= itemPoolSize; i++)
	{
	    if (!item[i][E_ITEM_VALID])
	    {
	        continue;
	    }

	    if (IsPlayerInDynamicArea(playerid, item[i][E_ITEM_AREAID]))
	    {
	        nearbyItems[playerid][nearbyItemsCount[playerid]++] = i;
	        if (nearbyItemsCount[playerid] == sizeof nearbyItems[])
	        {
	            break;
	        }
	    }
	}

    if (nearbyItemsCount[playerid] == 0)
    {
		for (new i; i < MAX_LEFT_MENU_ROWS; i++)
		{
		    TextDrawHideForPlayer(playerid, menuTextDraw[menuTextDrawID[E_MENU_TEXTDRAW_LEFT_BOX][i]]);
			TextDrawHideForPlayer(playerid, menuTextDraw[menuTextDrawID[E_MENU_TEXTDRAW_LEFT_MODEL][i]]);
			PlayerTextDrawHide(playerid, menuPlayerTextDraw[playerid][menuPlayerTextDrawID[playerid][E_MENU_TEXTDRAW_LEFT_TEXT][i]]);
		}
    }
    else
    {
        new pages = PAGES(nearbyItemsCount[playerid], MAX_LEFT_MENU_ROWS);
        if (playerLeftMenuPage[playerid] >= pages)
        {
            playerLeftMenuPage[playerid] = pages - 1;
           	playerLeftMenuListitem[playerid] = MAX_LEFT_MENU_ROWS - 1;
        }
        else
        {
			if ((playerLeftMenuListitem[playerid] + (playerLeftMenuPage[playerid] * MAX_LEFT_MENU_ROWS)) >= nearbyItemsCount[playerid])
			{
			    playerLeftMenuListitem[playerid] = ((nearbyItemsCount[playerid] - 1) - (playerLeftMenuPage[playerid] * MAX_LEFT_MENU_ROWS));
	        }
        }

	    new index;
		for (new i; i < MAX_LEFT_MENU_ROWS; i++)
		{
		    index = (i + (playerLeftMenuPage[playerid] * MAX_LEFT_MENU_ROWS));
			if (index >= nearbyItemsCount[playerid])
			{
			    TextDrawHideForPlayer(playerid, menuTextDraw[menuTextDrawID[E_MENU_TEXTDRAW_LEFT_BOX][i]]);
				TextDrawHideForPlayer(playerid, menuTextDraw[menuTextDrawID[E_MENU_TEXTDRAW_LEFT_MODEL][i]]);
				PlayerTextDrawHide(playerid, menuPlayerTextDraw[playerid][menuPlayerTextDrawID[playerid][E_MENU_TEXTDRAW_LEFT_TEXT][i]]);
			}
			else
			{
				if (playerLeftMenuListitem[playerid] == i)
				{
				    TextDrawBoxColor(menuTextDraw[menuTextDrawID[E_MENU_TEXTDRAW_LEFT_BOX][i]], SELECTED);

                    new itemName[10 + 3];
					for (new x; x < (sizeof itemName - 3); x++)
					{
						itemName[x] = item[nearbyItems[playerid][index]][E_ITEM_NAME][x];
					}
					if (strlen(item[nearbyItems[playerid][index]][E_ITEM_NAME]) > (sizeof itemName - 3))
					{
					    strcat(itemName, "...");
					}
				}
				else
				{
				    TextDrawBoxColor(menuTextDraw[menuTextDrawID[E_MENU_TEXTDRAW_LEFT_BOX][i]], 50);
				}

				TextDrawShowForPlayer(playerid, menuTextDraw[menuTextDrawID[E_MENU_TEXTDRAW_LEFT_BOX][i]]);

				TextDrawSetPreviewModel(menuTextDraw[menuTextDrawID[E_MENU_TEXTDRAW_LEFT_MODEL][i]], item[nearbyItems[playerid][index]][E_ITEM_MODELID]);
				TextDrawShowForPlayer(playerid, menuTextDraw[menuTextDrawID[E_MENU_TEXTDRAW_LEFT_MODEL][i]]);

				PlayerTextDrawSetString(playerid, menuPlayerTextDraw[playerid][menuPlayerTextDrawID[playerid][E_MENU_TEXTDRAW_LEFT_TEXT][i]], item[nearbyItems[playerid][index]][E_ITEM_NAME]);
			 	PlayerTextDrawShow(playerid, menuPlayerTextDraw[playerid][menuPlayerTextDrawID[playerid][E_MENU_TEXTDRAW_LEFT_TEXT][i]]);
			}
		}
    }

    new pages = PAGES(nearbyItemsCount[playerid], MAX_LEFT_MENU_ROWS);
 	if (pages > 1)
	{
	    if (playerLeftMenuPage[playerid] < 0)
	    {
	        playerLeftMenuPage[playerid] = 0;
	    }
	    else if (playerLeftMenuPage[playerid] >= pages)
	    {
	        playerLeftMenuPage[playerid] = pages - 1;
	    }

		new Float:y = 172.000000;
		new Float:height;
		ScrollBar(playerLeftMenuPage[playerid], pages, y, 14.6, height);

		PlayerTextDrawDestroy(playerid, menuPlayerTextDraw[playerid][menuPlayerTextDrawID[playerid][E_MENU_TEXTDRAW_SCROLL]]);

		menuPlayerTextDraw[playerid][menuPlayerTextDrawID[playerid][E_MENU_TEXTDRAW_SCROLL]] = CreatePlayerTextDraw(playerid, 246.000000, y, "_");
		PlayerTextDrawBackgroundColor(playerid, menuPlayerTextDraw[playerid][menuPlayerTextDrawID[playerid][E_MENU_TEXTDRAW_SCROLL]], 255);
		PlayerTextDrawFont(playerid, menuPlayerTextDraw[playerid][menuPlayerTextDrawID[playerid][E_MENU_TEXTDRAW_SCROLL]], 1);
		PlayerTextDrawLetterSize(playerid, menuPlayerTextDraw[playerid][menuPlayerTextDrawID[playerid][E_MENU_TEXTDRAW_SCROLL]], 0.000000, height);
		PlayerTextDrawColor(playerid, menuPlayerTextDraw[playerid][menuPlayerTextDrawID[playerid][E_MENU_TEXTDRAW_SCROLL]], -1);
		PlayerTextDrawSetOutline(playerid, menuPlayerTextDraw[playerid][menuPlayerTextDrawID[playerid][E_MENU_TEXTDRAW_SCROLL]], 0);
		PlayerTextDrawSetProportional(playerid, menuPlayerTextDraw[playerid][menuPlayerTextDrawID[playerid][E_MENU_TEXTDRAW_SCROLL]], 1);
		PlayerTextDrawSetShadow(playerid, menuPlayerTextDraw[playerid][menuPlayerTextDrawID[playerid][E_MENU_TEXTDRAW_SCROLL]], 1);
		PlayerTextDrawUseBox(playerid, menuPlayerTextDraw[playerid][menuPlayerTextDrawID[playerid][E_MENU_TEXTDRAW_SCROLL]], 1);
		PlayerTextDrawBoxColor(playerid, menuPlayerTextDraw[playerid][menuPlayerTextDrawID[playerid][E_MENU_TEXTDRAW_SCROLL]], -1768515896);
		PlayerTextDrawTextSize(playerid, menuPlayerTextDraw[playerid][menuPlayerTextDrawID[playerid][E_MENU_TEXTDRAW_SCROLL]], 247.000000, 0.000000);
		PlayerTextDrawSetSelectable(playerid, menuPlayerTextDraw[playerid][menuPlayerTextDrawID[playerid][E_MENU_TEXTDRAW_SCROLL]], 0);

	 	PlayerTextDrawShow(playerid, menuPlayerTextDraw[playerid][menuPlayerTextDrawID[playerid][E_MENU_TEXTDRAW_SCROLL]]);
	}
	else
	{
	 	PlayerTextDrawHide(playerid, menuPlayerTextDraw[playerid][menuPlayerTextDrawID[playerid][E_MENU_TEXTDRAW_SCROLL]]);
	}

	new string[128];
	format(string, sizeof string, "Items close to you: ~y~%i", nearbyItemsCount[playerid]);
	PlayerTextDrawSetString(playerid, menuPlayerTextDraw[playerid][menuPlayerTextDrawID[playerid][E_MENU_TEXTDRAW_LEFT_COUNT]], string);

	if (nearbyItemsCount[playerid] == 0)
	{
	    TextDrawShowForPlayer(playerid, menuTextDraw[menuTextDrawID[E_MENU_TEXTDRAW_EMPTY_LEFT][0]]);
	    TextDrawShowForPlayer(playerid, menuTextDraw[menuTextDrawID[E_MENU_TEXTDRAW_EMPTY_LEFT][1]]);
	}
	else
	{
	    TextDrawHideForPlayer(playerid, menuTextDraw[menuTextDrawID[E_MENU_TEXTDRAW_EMPTY_LEFT][0]]);
	    TextDrawHideForPlayer(playerid, menuTextDraw[menuTextDrawID[E_MENU_TEXTDRAW_EMPTY_LEFT][1]]);
	}
	return 1;
}

Inv_UpdateRightMenu(playerid)
{
    if (playerInventoryItemsCount[playerid] == 0)
    {
		for (new i; i < MAX_PLAYER_ITEMS; i++)
		{
		    TextDrawHideForPlayer(playerid, menuTextDraw[menuTextDrawID[E_MENU_TEXTDRAW_RIGHT_MODEL][i]]);
			TextDrawHideForPlayer(playerid, menuTextDraw[menuTextDrawID[E_MENU_TEXTDRAW_RIGHT_NUMBER][i]]);
			PlayerTextDrawHide(playerid, menuPlayerTextDraw[playerid][menuPlayerTextDrawID[playerid][E_MENU_TEXTDRAW_RIGHT_TEXT][i]]);
		}

    	new string[128];
		format(string, sizeof string, "Items in your inventory: ~y~0/%i", MAX_PLAYER_ITEMS);
		PlayerTextDrawSetString(playerid, menuPlayerTextDraw[playerid][menuPlayerTextDrawID[playerid][E_MENU_TEXTDRAW_RIGHT_COUNT]], string);

		TextDrawShowForPlayer(playerid, menuTextDraw[menuTextDrawID[E_MENU_TEXTDRAW_EMPTY_RIGHT][0]]);
		TextDrawShowForPlayer(playerid, menuTextDraw[menuTextDrawID[E_MENU_TEXTDRAW_EMPTY_RIGHT][1]]);
    }
    else
    {
        if (playerRightMenuListitem[playerid] >= playerInventoryItemsCount[playerid])
        {
            playerRightMenuListitem[playerid] = (playerInventoryItemsCount[playerid] - 1);
        }

		for (new i; i < playerInventoryItemsCount[playerid]; i++)
		{
			if (playerRightMenuListitem[playerid] == i)
			{
   				TextDrawBackgroundColor(menuTextDraw[menuTextDrawID[E_MENU_TEXTDRAW_RIGHT_MODEL][i]], SELECTED);

				new itemName[10 + 3];
				for (new x; x < (sizeof itemName - 3); x++)
				{
					itemName[x] = item[playerInventoryItems[playerid][i]][E_ITEM_NAME][x];
				}
				if (strlen(item[playerInventoryItems[playerid][i]][E_ITEM_NAME]) > (sizeof itemName - 3))
				{
				    strcat(itemName, "...");
				}
			}
			else
			{
			    TextDrawBackgroundColor(menuTextDraw[menuTextDrawID[E_MENU_TEXTDRAW_RIGHT_MODEL][i]], 100);
			}

			TextDrawSetPreviewModel(menuTextDraw[menuTextDrawID[E_MENU_TEXTDRAW_RIGHT_MODEL][i]], item[playerInventoryItems[playerid][i]][E_ITEM_MODELID]);
   			TextDrawShowForPlayer(playerid, menuTextDraw[menuTextDrawID[E_MENU_TEXTDRAW_RIGHT_MODEL][i]]);

			TextDrawShowForPlayer(playerid, menuTextDraw[menuTextDrawID[E_MENU_TEXTDRAW_RIGHT_NUMBER][i]]);

			PlayerTextDrawSetString(playerid, menuPlayerTextDraw[playerid][menuPlayerTextDrawID[playerid][E_MENU_TEXTDRAW_RIGHT_TEXT][i]], item[playerInventoryItems[playerid][i]][E_ITEM_NAME]);
		 	PlayerTextDrawShow(playerid, menuPlayerTextDraw[playerid][menuPlayerTextDrawID[playerid][E_MENU_TEXTDRAW_RIGHT_TEXT][i]]);
		}

		for (new i = playerInventoryItemsCount[playerid]; i < MAX_PLAYER_ITEMS; i++)
		{
			TextDrawHideForPlayer(playerid, menuTextDraw[menuTextDrawID[E_MENU_TEXTDRAW_RIGHT_MODEL][i]]);
			TextDrawHideForPlayer(playerid, menuTextDraw[menuTextDrawID[E_MENU_TEXTDRAW_RIGHT_NUMBER][i]]);
			PlayerTextDrawHide(playerid, menuPlayerTextDraw[playerid][menuPlayerTextDrawID[playerid][E_MENU_TEXTDRAW_RIGHT_TEXT][i]]);
		}

    	new string[128];
    	format(string, sizeof string, "Items in your inventory: ~y~%i/%i", playerInventoryItemsCount[playerid], MAX_PLAYER_ITEMS);
		PlayerTextDrawSetString(playerid, menuPlayerTextDraw[playerid][menuPlayerTextDrawID[playerid][E_MENU_TEXTDRAW_RIGHT_COUNT]], string);

		TextDrawHideForPlayer(playerid, menuTextDraw[menuTextDrawID[E_MENU_TEXTDRAW_EMPTY_RIGHT][0]]);
	    TextDrawHideForPlayer(playerid, menuTextDraw[menuTextDrawID[E_MENU_TEXTDRAW_EMPTY_RIGHT][1]]);
    }
	return 1;
}

Inv_GivePlayerItem(playerid, itemid)
{
	if (playerInventoryItemsCount[playerid] == MAX_PLAYER_ITEMS)
	{
	    return 0;
	}

	new index = playerInventoryItemsCount[playerid]++;
	playerInventoryItems[playerid][index] = itemid;

	item[itemid][E_ITEM_PLAYERID] = playerid;

	DestroyDynamicObject(item[itemid][E_ITEM_OBJECTID]);
	item[itemid][E_ITEM_OBJECTID] = INVALID_STREAMER_ID;
 	DestroyDynamicArea(item[itemid][E_ITEM_AREAID]);
 	item[itemid][E_ITEM_AREAID] = INVALID_STREAMER_ID;

 	for (new i, j = GetPlayerPoolSize(); i <= j; i++)
    {
        if (IsPlayerConnected(i) && playerUsingMenu[playerid])
        {
	    	Inv_UpdateLeftMenu(i);
	    	Inv_UpdatePlaiyerPickupTextDraw(i);
		}
    }

	Inv_UpdateRightMenu(playerid);
	return 1;
}

Inv_DropPlayerItem(playerid, playerSlot)
{
	new itemid = playerInventoryItems[playerid][playerSlot];

	item[itemid][E_ITEM_PLAYERID] = INVALID_PLAYER_ID;

	new Float:x, Float:y, Float:z;
	GetPlayerPos(playerid, x, y, z);
	new Float:ang;
	GetPlayerFacingAngle(playerid, ang);
	x += (1.5 * floatsin(-ang, degrees));
	y += (1.5 * floatcos(-ang, degrees));
	CA_FindZ_For2DCoord(x, y, z);
 	item[itemid][E_ITEM_OBJECTID] = CreateDynamicObject(item[itemid][E_ITEM_MODELID], x, y, z + item[itemid][E_ITEM_ZPUSH], item[itemid][E_ITEM_ROTX], item[itemid][E_ITEM_ROTY], item[itemid][E_ITEM_ROTZ]);

 	item[itemid][E_ITEM_PLAYERID] = INVALID_PLAYER_ID;

 	new Float:unused, Float:radius;
 	CA_GetModelBoundingSphere(item[itemid][E_ITEM_MODELID], unused, unused, unused, radius);
  	item[itemid][E_ITEM_AREAID] = CreateDynamicCircle(x, y, radius + 2.0);

	for (new i = playerSlot; i < (playerInventoryItemsCount[playerid] - 1); i++)
	{
	    playerInventoryItems[playerid][i] = playerInventoryItems[playerid][i + 1];
 	}
 	playerInventoryItemsCount[playerid]--;

    for (new i, j = GetPlayerPoolSize(); i <= j; i++)
    {
        if (IsPlayerConnected(i) && playerUsingMenu[i])
        {
	 		Streamer_Update(i);
	    	Inv_UpdateLeftMenu(i);
		}
    }

	Inv_UpdateRightMenu(playerid);
	return itemid;
}

Inv_LoadItemsFromDatabase(database[])
{
    new DB:inventoryDB = db_open(database);
	if (!inventoryDB)
	{
	    return 0;
	}

    db_query(inventoryDB, "CREATE TABLE IF NOT EXISTS `items` \
		(`modelid` INTEGER, \
		`name` VARCHAR("#MAX_ITEM_NAME"), \
		`x` FLOAT, \
		`y` FLOAT, \
		`z` FLOAT, \
		`rx` FLOAT, \
		`ry` FLOAT, \
		`rz` FLOAT, \
		`zpush` FLOAT)");

	new DBResult:result = db_query(inventoryDB, "SELECT * FROM `items`");
	if (!result)
	{
	    db_close(inventoryDB);
	    return 0;
	}

	new count;
	if (db_num_rows(result) > 0)
	{
		new name[MAX_ITEM_NAME];
		do
		{
		    db_get_field(result, 1, name, sizeof name);
			if (Inv_AddItem(db_get_field_int(result, 0), name, db_get_field_float(result, 2), db_get_field_float(result, 3), db_get_field_float(result, 4), db_get_field_float(result, 5), db_get_field_float(result, 6), db_get_field_float(result, 7), db_get_field_float(result, 8)) != -1)
			{
			    count++;
			}
		}
		while (db_next_row(result));
	}
	
	db_free_result(result);
	db_close(inventoryDB);
	return count;
}

Inv_RemoveAllItems()
{
	for (new i; i < itemPoolSize; i++)
	{
	    if (item[i][E_ITEM_VALID])
	    {
		    if (item[i][E_ITEM_PLAYERID] == INVALID_PLAYER_ID)
			{
			    DestroyDynamicObject(item[i][E_ITEM_OBJECTID]);
				item[i][E_ITEM_OBJECTID] = INVALID_STREAMER_ID;
				
		 		DestroyDynamicArea(item[i][E_ITEM_AREAID]);
				item[i][E_ITEM_AREAID] = INVALID_STREAMER_ID;
			}
		}
		
		item[i][E_ITEM_VALID] = false;
	}
	
	itemPoolSize = -1;

	for (new i, j = GetPlayerPoolSize(); i <= j; i++)
 	{
		if (IsPlayerConnected(i) && playerUsingMenu[i])
		{
		    playerInventoryItemsCount[i] = 0;
 	
			Inv_UpdateLeftMenu(i);
			Inv_UpdateRightMenu(i);
			Inv_UpdatePlaiyerPickupTextDraw(i);
		}
	}
	return 1;
}

public OnGameModeInit()
{
	CA_Init();

	menuTextDraw[menuTextDrawCount] = TextDrawCreate(160.000000, 149.000000, "_");
	TextDrawBackgroundColor(menuTextDraw[menuTextDrawCount], 255);
	TextDrawFont(menuTextDraw[menuTextDrawCount], 1);
	TextDrawLetterSize(menuTextDraw[menuTextDrawCount], 0.000000, 22.500001);
	TextDrawColor(menuTextDraw[menuTextDrawCount], -1);
	TextDrawSetOutline(menuTextDraw[menuTextDrawCount], 0);
	TextDrawSetProportional(menuTextDraw[menuTextDrawCount], 1);
	TextDrawSetShadow(menuTextDraw[menuTextDrawCount], 1);
	TextDrawUseBox(menuTextDraw[menuTextDrawCount], 1);
	TextDrawBoxColor(menuTextDraw[menuTextDrawCount], BACKGROUND);
	TextDrawTextSize(menuTextDraw[menuTextDrawCount], 490.000000, 0.000000);
	TextDrawSetSelectable(menuTextDraw[menuTextDrawCount++], 0);

	menuTextDraw[menuTextDrawCount] = TextDrawCreate(163.000000, 161.000000, "_");
	TextDrawBackgroundColor(menuTextDraw[menuTextDrawCount], 255);
	TextDrawFont(menuTextDraw[menuTextDrawCount], 1);
	TextDrawLetterSize(menuTextDraw[menuTextDrawCount], 0.000000, 17.000000);
	TextDrawColor(menuTextDraw[menuTextDrawCount], -1);
	TextDrawSetOutline(menuTextDraw[menuTextDrawCount], 0);
	TextDrawSetProportional(menuTextDraw[menuTextDrawCount], 1);
	TextDrawSetShadow(menuTextDraw[menuTextDrawCount], 1);
	TextDrawUseBox(menuTextDraw[menuTextDrawCount], 1);
	TextDrawBoxColor(menuTextDraw[menuTextDrawCount], LEFT_BACKGROUND);
	TextDrawTextSize(menuTextDraw[menuTextDrawCount], 249.000000, 0.000000);
	TextDrawSetSelectable(menuTextDraw[menuTextDrawCount++], 0);

	menuTextDraw[menuTextDrawCount] = TextDrawCreate(257.000000, 161.000000, "_");
	TextDrawBackgroundColor(menuTextDraw[menuTextDrawCount], 255);
	TextDrawFont(menuTextDraw[menuTextDrawCount], 1);
	TextDrawLetterSize(menuTextDraw[menuTextDrawCount], 0.000000, 17.000000);
	TextDrawColor(menuTextDraw[menuTextDrawCount], -1);
	TextDrawSetOutline(menuTextDraw[menuTextDrawCount], 0);
	TextDrawSetProportional(menuTextDraw[menuTextDrawCount], 1);
	TextDrawSetShadow(menuTextDraw[menuTextDrawCount], 1);
	TextDrawUseBox(menuTextDraw[menuTextDrawCount], 1);
	TextDrawBoxColor(menuTextDraw[menuTextDrawCount], RIGHT_BACKGROUND);
	TextDrawTextSize(menuTextDraw[menuTextDrawCount], 487.000000, 0.000000);
	TextDrawSetSelectable(menuTextDraw[menuTextDrawCount++], 0);

    menuTextDraw[menuTextDrawCount] = TextDrawCreate(245.000000, 170.000000, "_");
	TextDrawBackgroundColor(menuTextDraw[menuTextDrawCount], 255);
	TextDrawFont(menuTextDraw[menuTextDrawCount], 1);
	TextDrawLetterSize(menuTextDraw[menuTextDrawCount], 0.000000, 15.199996);
	TextDrawColor(menuTextDraw[menuTextDrawCount], -1);
	TextDrawSetOutline(menuTextDraw[menuTextDrawCount], 0);
	TextDrawSetProportional(menuTextDraw[menuTextDrawCount], 1);
	TextDrawSetShadow(menuTextDraw[menuTextDrawCount], 1);
	TextDrawUseBox(menuTextDraw[menuTextDrawCount], 1);
	TextDrawBoxColor(menuTextDraw[menuTextDrawCount], 842150600);
	TextDrawTextSize(menuTextDraw[menuTextDrawCount], 248.000000, 0.000000);
	TextDrawSetSelectable(menuTextDraw[menuTextDrawCount++], 0);

    menuTextDrawID[E_MENU_TEXTDRAW_SCROLL_UP] = menuTextDrawCount;
	menuTextDraw[menuTextDrawCount] = TextDrawCreate(243.000000, 161.000000, "LD_POOL:ball");
	TextDrawBackgroundColor(menuTextDraw[menuTextDrawCount], 0);
	TextDrawFont(menuTextDraw[menuTextDrawCount], 4);
	TextDrawLetterSize(menuTextDraw[menuTextDrawCount], 0.159999, 0.899999);
	TextDrawColor(menuTextDraw[menuTextDrawCount], 842150600);
	TextDrawSetOutline(menuTextDraw[menuTextDrawCount], 0);
	TextDrawSetProportional(menuTextDraw[menuTextDrawCount], 1);
	TextDrawSetShadow(menuTextDraw[menuTextDrawCount], 1);
	TextDrawUseBox(menuTextDraw[menuTextDrawCount], 1);
	TextDrawBoxColor(menuTextDraw[menuTextDrawCount], 255);
	TextDrawTextSize(menuTextDraw[menuTextDrawCount], 7.000000, 9.000000);
	TextDrawSetSelectable(menuTextDraw[menuTextDrawCount++], 1);

	menuTextDraw[menuTextDrawCount] = TextDrawCreate(244.000000, 162.000000, "LD_BEAT:up");
	TextDrawBackgroundColor(menuTextDraw[menuTextDrawCount], 0);
	TextDrawFont(menuTextDraw[menuTextDrawCount], 4);
	TextDrawLetterSize(menuTextDraw[menuTextDrawCount], 0.159999, 0.899999);
	TextDrawColor(menuTextDraw[menuTextDrawCount], -56);
	TextDrawSetOutline(menuTextDraw[menuTextDrawCount], 0);
	TextDrawSetProportional(menuTextDraw[menuTextDrawCount], 1);
	TextDrawSetShadow(menuTextDraw[menuTextDrawCount], 1);
	TextDrawUseBox(menuTextDraw[menuTextDrawCount], 1);
	TextDrawBoxColor(menuTextDraw[menuTextDrawCount], 255);
	TextDrawTextSize(menuTextDraw[menuTextDrawCount], 5.000000, 7.000000);
	TextDrawSetSelectable(menuTextDraw[menuTextDrawCount++], 0);

    menuTextDrawID[E_MENU_TEXTDRAW_SCROLL_DOWN] = menuTextDrawCount;
	menuTextDraw[menuTextDrawCount] = TextDrawCreate(243.000000, 306.000000, "LD_POOL:ball");
	TextDrawBackgroundColor(menuTextDraw[menuTextDrawCount], 0);
	TextDrawFont(menuTextDraw[menuTextDrawCount], 4);
	TextDrawLetterSize(menuTextDraw[menuTextDrawCount], 0.159999, 0.899999);
	TextDrawColor(menuTextDraw[menuTextDrawCount], 842150600);
	TextDrawSetOutline(menuTextDraw[menuTextDrawCount], 0);
	TextDrawSetProportional(menuTextDraw[menuTextDrawCount], 1);
	TextDrawSetShadow(menuTextDraw[menuTextDrawCount], 1);
	TextDrawUseBox(menuTextDraw[menuTextDrawCount], 1);
	TextDrawBoxColor(menuTextDraw[menuTextDrawCount], 255);
	TextDrawTextSize(menuTextDraw[menuTextDrawCount], 7.000000, 9.000000);
	TextDrawSetSelectable(menuTextDraw[menuTextDrawCount++], 1);

	menuTextDraw[menuTextDrawCount] = TextDrawCreate(244.000000, 307.000000, "LD_BEAT:down");
	TextDrawBackgroundColor(menuTextDraw[menuTextDrawCount], 0);
	TextDrawFont(menuTextDraw[menuTextDrawCount], 4);
	TextDrawLetterSize(menuTextDraw[menuTextDrawCount], 0.159999, 0.899999);
	TextDrawColor(menuTextDraw[menuTextDrawCount], -56);
	TextDrawSetOutline(menuTextDraw[menuTextDrawCount], 0);
	TextDrawSetProportional(menuTextDraw[menuTextDrawCount], 1);
	TextDrawSetShadow(menuTextDraw[menuTextDrawCount], 1);
	TextDrawUseBox(menuTextDraw[menuTextDrawCount], 1);
	TextDrawBoxColor(menuTextDraw[menuTextDrawCount], 255);
	TextDrawTextSize(menuTextDraw[menuTextDrawCount], 5.000000, 7.000000);
	TextDrawSetSelectable(menuTextDraw[menuTextDrawCount++], 0);

	for (new i; i < MAX_LEFT_MENU_ROWS; i++)
	{
    	menuTextDrawID[E_MENU_TEXTDRAW_LEFT_BOX][i] = menuTextDrawCount;
		menuTextDraw[menuTextDrawCount] = TextDrawCreate(165.000000, (163.000000 + (i * 22.000000)), "_");
		TextDrawBackgroundColor(menuTextDraw[menuTextDrawCount], 0);
		TextDrawFont(menuTextDraw[menuTextDrawCount], 2);
		TextDrawLetterSize(menuTextDraw[menuTextDrawCount], 0.389999, 1.999999);
		TextDrawColor(menuTextDraw[menuTextDrawCount], 0);
		TextDrawSetOutline(menuTextDraw[menuTextDrawCount], 0);
		TextDrawSetProportional(menuTextDraw[menuTextDrawCount], 1);
		TextDrawSetShadow(menuTextDraw[menuTextDrawCount], 1);
		TextDrawUseBox(menuTextDraw[menuTextDrawCount], 1);
		TextDrawBoxColor(menuTextDraw[menuTextDrawCount], 50);
		TextDrawTextSize(menuTextDraw[menuTextDrawCount], 238.000000, 100.000000);
		TextDrawSetSelectable(menuTextDraw[menuTextDrawCount++], 1);

    	menuTextDrawID[E_MENU_TEXTDRAW_LEFT_MODEL][i] = menuTextDrawCount;
		menuTextDraw[menuTextDrawCount] = TextDrawCreate(165.000000, (163.000000 + (i * 22.000000)), "Item_model");
		TextDrawBackgroundColor(menuTextDraw[menuTextDrawCount], 100);
		TextDrawFont(menuTextDraw[menuTextDrawCount], 5);
		TextDrawLetterSize(menuTextDraw[menuTextDrawCount], 0.000000, 2.000000);
		TextDrawColor(menuTextDraw[menuTextDrawCount], -1);
		TextDrawSetOutline(menuTextDraw[menuTextDrawCount], 0);
		TextDrawSetProportional(menuTextDraw[menuTextDrawCount], 1);
		TextDrawSetShadow(menuTextDraw[menuTextDrawCount], 1);
		TextDrawUseBox(menuTextDraw[menuTextDrawCount], 1);
		TextDrawBoxColor(menuTextDraw[menuTextDrawCount], 0);
		TextDrawTextSize(menuTextDraw[menuTextDrawCount], 19.000000, 18.000000);
		TextDrawSetPreviewModel(menuTextDraw[menuTextDrawCount], 18631);
		TextDrawSetPreviewRot(menuTextDraw[menuTextDrawCount], 0.000000, 0.000000, 0.000000, 1.000000);
		TextDrawSetSelectable(menuTextDraw[menuTextDrawCount++], 1);
	}

	new string[3];
    for (new a; a < MAX_RIGHT_MENU_ROWS; a++)
    {
        for (new b; b < MAX_RIGHT_MENU_COLUMNS; b++)
        {
    		menuTextDrawID[E_MENU_TEXTDRAW_RIGHT_MODEL][(a * MAX_RIGHT_MENU_COLUMNS) + b] = menuTextDrawCount;
			menuTextDraw[menuTextDrawCount] = TextDrawCreate((257.000000 + (b * 46.000000)), (161.000000 + (a * 51.000000)), "Item_model");
			TextDrawBackgroundColor(menuTextDraw[menuTextDrawCount], 100);
			TextDrawFont(menuTextDraw[menuTextDrawCount], 5);
			TextDrawLetterSize(menuTextDraw[menuTextDrawCount], 0.000000, 2.000000);
			TextDrawColor(menuTextDraw[menuTextDrawCount], -1);
			TextDrawSetOutline(menuTextDraw[menuTextDrawCount], 0);
			TextDrawSetProportional(menuTextDraw[menuTextDrawCount], 1);
			TextDrawSetShadow(menuTextDraw[menuTextDrawCount], 1);
			TextDrawUseBox(menuTextDraw[menuTextDrawCount], 1);
			TextDrawBoxColor(menuTextDraw[menuTextDrawCount], 0);
			TextDrawTextSize(menuTextDraw[menuTextDrawCount], 45.000000, 50.000000);
			TextDrawSetPreviewModel(menuTextDraw[menuTextDrawCount], 18631);
			TextDrawSetPreviewRot(menuTextDraw[menuTextDrawCount], 0.000000, 0.000000, 0.000000, 1.000000);
			TextDrawSetSelectable(menuTextDraw[menuTextDrawCount++], 1);

    		menuTextDrawID[E_MENU_TEXTDRAW_RIGHT_NUMBER][(a * MAX_RIGHT_MENU_COLUMNS) + b] = menuTextDrawCount;
			format(string, sizeof string, "%i.", (((a * MAX_RIGHT_MENU_COLUMNS) + b) + 1));
			menuTextDraw[menuTextDrawCount] = TextDrawCreate((260.000000 + (b * 46.000000)), (164.000000 + (a * 51.000000)), string);
			TextDrawBackgroundColor(menuTextDraw[menuTextDrawCount], 0);
			TextDrawFont(menuTextDraw[menuTextDrawCount], FONT);
			TextDrawLetterSize(menuTextDraw[menuTextDrawCount], 0.189999, 0.899999);
			TextDrawColor(menuTextDraw[menuTextDrawCount], -926365441);
			TextDrawSetOutline(menuTextDraw[menuTextDrawCount], 0);
			TextDrawSetProportional(menuTextDraw[menuTextDrawCount], 1);
			TextDrawSetShadow(menuTextDraw[menuTextDrawCount], 1);
			TextDrawSetSelectable(menuTextDraw[menuTextDrawCount++], 0);
		}
	}

   	menuTextDrawID[E_MENU_TEXTDRAW_LEFTBTN] = menuTextDrawCount;
	menuTextDraw[menuTextDrawCount] = TextDrawCreate(235.000000, 318.000000, "LD_POOL:ball");
	TextDrawBackgroundColor(menuTextDraw[menuTextDrawCount], 0);
	TextDrawFont(menuTextDraw[menuTextDrawCount], 4);
	TextDrawLetterSize(menuTextDraw[menuTextDrawCount], 0.159999, 0.899999);
	TextDrawColor(menuTextDraw[menuTextDrawCount], 842150550);
	TextDrawSetOutline(menuTextDraw[menuTextDrawCount], 0);
	TextDrawSetProportional(menuTextDraw[menuTextDrawCount], 1);
	TextDrawSetShadow(menuTextDraw[menuTextDrawCount], 1);
	TextDrawUseBox(menuTextDraw[menuTextDrawCount], 1);
	TextDrawBoxColor(menuTextDraw[menuTextDrawCount], 255);
	TextDrawTextSize(menuTextDraw[menuTextDrawCount], 13.000000, 16.000000);
	TextDrawSetSelectable(menuTextDraw[menuTextDrawCount++], 1);

	menuTextDraw[menuTextDrawCount] = TextDrawCreate(238.000000, 321.000000, "LD_BEAT:right");
	TextDrawBackgroundColor(menuTextDraw[menuTextDrawCount], 0);
	TextDrawFont(menuTextDraw[menuTextDrawCount], 4);
	TextDrawLetterSize(menuTextDraw[menuTextDrawCount], 0.159999, 0.899999);
	TextDrawColor(menuTextDraw[menuTextDrawCount], -56);
	TextDrawSetOutline(menuTextDraw[menuTextDrawCount], 0);
	TextDrawSetProportional(menuTextDraw[menuTextDrawCount], 1);
	TextDrawSetShadow(menuTextDraw[menuTextDrawCount], 1);
	TextDrawUseBox(menuTextDraw[menuTextDrawCount], 1);
	TextDrawBoxColor(menuTextDraw[menuTextDrawCount], 255);
	TextDrawTextSize(menuTextDraw[menuTextDrawCount], 8.000000, 10.000000);
	TextDrawSetSelectable(menuTextDraw[menuTextDrawCount++], 0);

	menuTextDraw[menuTextDrawCount] = TextDrawCreate(242.000000, 335.000000, "PICKUP~n~ITEM");
	TextDrawAlignment(menuTextDraw[menuTextDrawCount], 2);
	TextDrawBackgroundColor(menuTextDraw[menuTextDrawCount], 0);
	TextDrawFont(menuTextDraw[menuTextDrawCount], 1);
	TextDrawLetterSize(menuTextDraw[menuTextDrawCount], 0.119998, 0.599999);
	TextDrawColor(menuTextDraw[menuTextDrawCount], -926365441);
	TextDrawSetOutline(menuTextDraw[menuTextDrawCount], 0);
	TextDrawSetProportional(menuTextDraw[menuTextDrawCount], 1);
	TextDrawSetShadow(menuTextDraw[menuTextDrawCount], 1);
	TextDrawSetSelectable(menuTextDraw[menuTextDrawCount++], 0);

   	menuTextDrawID[E_MENU_TEXTDRAW_RIGHTBTN] = menuTextDrawCount;
	menuTextDraw[menuTextDrawCount] = TextDrawCreate(258.000000, 318.000000, "LD_POOL:ball");
	TextDrawBackgroundColor(menuTextDraw[menuTextDrawCount], 0);
	TextDrawFont(menuTextDraw[menuTextDrawCount], 4);
	TextDrawLetterSize(menuTextDraw[menuTextDrawCount], 0.159999, 0.899999);
	TextDrawColor(menuTextDraw[menuTextDrawCount], 842150550);
	TextDrawSetOutline(menuTextDraw[menuTextDrawCount], 0);
	TextDrawSetProportional(menuTextDraw[menuTextDrawCount], 1);
	TextDrawSetShadow(menuTextDraw[menuTextDrawCount], 1);
	TextDrawUseBox(menuTextDraw[menuTextDrawCount], 1);
	TextDrawBoxColor(menuTextDraw[menuTextDrawCount], 255);
	TextDrawTextSize(menuTextDraw[menuTextDrawCount], 13.000000, 16.000000);
	TextDrawSetSelectable(menuTextDraw[menuTextDrawCount++], 1);

	menuTextDraw[menuTextDrawCount] = TextDrawCreate(260.000000, 321.000000, "LD_BEAT:left");
	TextDrawBackgroundColor(menuTextDraw[menuTextDrawCount], 0);
	TextDrawFont(menuTextDraw[menuTextDrawCount], 4);
	TextDrawLetterSize(menuTextDraw[menuTextDrawCount], 0.159999, 0.899999);
	TextDrawColor(menuTextDraw[menuTextDrawCount], -56);
	TextDrawSetOutline(menuTextDraw[menuTextDrawCount], 0);
	TextDrawSetProportional(menuTextDraw[menuTextDrawCount], 1);
	TextDrawSetShadow(menuTextDraw[menuTextDrawCount], 1);
	TextDrawUseBox(menuTextDraw[menuTextDrawCount], 1);
	TextDrawBoxColor(menuTextDraw[menuTextDrawCount], 255);
	TextDrawTextSize(menuTextDraw[menuTextDrawCount], 8.000000, 10.000000);
	TextDrawSetSelectable(menuTextDraw[menuTextDrawCount++], 0);

	menuTextDraw[menuTextDrawCount] = TextDrawCreate(265.000000, 335.000000, "DROP~n~ITEM");
	TextDrawAlignment(menuTextDraw[menuTextDrawCount], 2);
	TextDrawBackgroundColor(menuTextDraw[menuTextDrawCount], 0);
	TextDrawFont(menuTextDraw[menuTextDrawCount], FONT);
	TextDrawLetterSize(menuTextDraw[menuTextDrawCount], 0.119998, 0.599999);
	TextDrawColor(menuTextDraw[menuTextDrawCount], -926365441);
	TextDrawSetOutline(menuTextDraw[menuTextDrawCount], 0);
	TextDrawSetProportional(menuTextDraw[menuTextDrawCount], 1);
	TextDrawSetShadow(menuTextDraw[menuTextDrawCount], 1);
	TextDrawSetSelectable(menuTextDraw[menuTextDrawCount++], 0);

   	menuTextDrawID[E_MENU_TEXTDRAW_MIDDLEBTN] = menuTextDrawCount;
	menuTextDraw[menuTextDrawCount] = TextDrawCreate(281.000000, 318.000000, "LD_POOL:ball");
	TextDrawBackgroundColor(menuTextDraw[menuTextDrawCount], 0);
	TextDrawFont(menuTextDraw[menuTextDrawCount], 4);
	TextDrawLetterSize(menuTextDraw[menuTextDrawCount], 0.159999, 0.899999);
	TextDrawColor(menuTextDraw[menuTextDrawCount], 842150550);
	TextDrawSetOutline(menuTextDraw[menuTextDrawCount], 0);
	TextDrawSetProportional(menuTextDraw[menuTextDrawCount], 1);
	TextDrawSetShadow(menuTextDraw[menuTextDrawCount], 1);
	TextDrawUseBox(menuTextDraw[menuTextDrawCount], 1);
	TextDrawBoxColor(menuTextDraw[menuTextDrawCount], 255);
	TextDrawTextSize(menuTextDraw[menuTextDrawCount], 13.000000, 16.000000);
	TextDrawSetSelectable(menuTextDraw[menuTextDrawCount++], 1);

	menuTextDraw[menuTextDrawCount] = TextDrawCreate(287.000000, 323.000000, "USE");
	TextDrawAlignment(menuTextDraw[menuTextDrawCount], 2);
	TextDrawBackgroundColor(menuTextDraw[menuTextDrawCount], 0);
	TextDrawFont(menuTextDraw[menuTextDrawCount], 1);
	TextDrawLetterSize(menuTextDraw[menuTextDrawCount], 0.149999, 0.699999);
	TextDrawColor(menuTextDraw[menuTextDrawCount], -1263225601);
	TextDrawSetOutline(menuTextDraw[menuTextDrawCount], 0);
	TextDrawSetProportional(menuTextDraw[menuTextDrawCount], 1);
	TextDrawSetShadow(menuTextDraw[menuTextDrawCount], 1);
	TextDrawSetSelectable(menuTextDraw[menuTextDrawCount++], 0);

	menuTextDraw[menuTextDrawCount] = TextDrawCreate(288.000000, 335.000000, "USE~n~ITEM");
	TextDrawAlignment(menuTextDraw[menuTextDrawCount], 2);
	TextDrawBackgroundColor(menuTextDraw[menuTextDrawCount], 0);
	TextDrawFont(menuTextDraw[menuTextDrawCount], FONT);
	TextDrawLetterSize(menuTextDraw[menuTextDrawCount], 0.119998, 0.599999);
	TextDrawColor(menuTextDraw[menuTextDrawCount], -926365441);
	TextDrawSetOutline(menuTextDraw[menuTextDrawCount], 0);
	TextDrawSetProportional(menuTextDraw[menuTextDrawCount], 1);
	TextDrawSetShadow(menuTextDraw[menuTextDrawCount], 1);
	TextDrawUseBox(menuTextDraw[menuTextDrawCount], 1);
	TextDrawBoxColor(menuTextDraw[menuTextDrawCount], 0);
	TextDrawTextSize(menuTextDraw[menuTextDrawCount], 238.000000, 0.000000);
	TextDrawSetSelectable(menuTextDraw[menuTextDrawCount++], 0);

   	menuTextDrawID[E_MENU_TEXTDRAW_CLOSE] = menuTextDrawCount;
	menuTextDraw[menuTextDrawCount] = TextDrawCreate(476.000000, 318.000000, "LD_POOL:ball");
	TextDrawBackgroundColor(menuTextDraw[menuTextDrawCount], 0);
	TextDrawFont(menuTextDraw[menuTextDrawCount], 4);
	TextDrawLetterSize(menuTextDraw[menuTextDrawCount], 0.159999, 0.899999);
	TextDrawColor(menuTextDraw[menuTextDrawCount], 842150550);
	TextDrawSetOutline(menuTextDraw[menuTextDrawCount], 0);
	TextDrawSetProportional(menuTextDraw[menuTextDrawCount], 1);
	TextDrawSetShadow(menuTextDraw[menuTextDrawCount], 1);
	TextDrawUseBox(menuTextDraw[menuTextDrawCount], 1);
	TextDrawBoxColor(menuTextDraw[menuTextDrawCount], 255);
	TextDrawTextSize(menuTextDraw[menuTextDrawCount], 13.000000, 16.000000);
	TextDrawSetSelectable(menuTextDraw[menuTextDrawCount++], 1);

	menuTextDraw[menuTextDrawCount] = TextDrawCreate(483.000000, 322.000000, "~r~~h~~h~X");
	TextDrawAlignment(menuTextDraw[menuTextDrawCount], 2);
	TextDrawBackgroundColor(menuTextDraw[menuTextDrawCount], 0);
	TextDrawFont(menuTextDraw[menuTextDrawCount], 1);
	TextDrawLetterSize(menuTextDraw[menuTextDrawCount], 0.220000, 0.899999);
	TextDrawColor(menuTextDraw[menuTextDrawCount], -1263225601);
	TextDrawSetOutline(menuTextDraw[menuTextDrawCount], 0);
	TextDrawSetProportional(menuTextDraw[menuTextDrawCount], 1);
	TextDrawSetShadow(menuTextDraw[menuTextDrawCount], 1);
	TextDrawSetSelectable(menuTextDraw[menuTextDrawCount++], 0);

	menuTextDraw[menuTextDrawCount] = TextDrawCreate(487.000000, 335.000000, "~r~~h~~h~CLOSE~n~~r~~h~~h~INVENTORY~n~");
	TextDrawAlignment(menuTextDraw[menuTextDrawCount], 3);
	TextDrawBackgroundColor(menuTextDraw[menuTextDrawCount], 0);
	TextDrawFont(menuTextDraw[menuTextDrawCount], FONT);
	TextDrawLetterSize(menuTextDraw[menuTextDrawCount], 0.119998, 0.599999);
	TextDrawColor(menuTextDraw[menuTextDrawCount], -926365441);
	TextDrawSetOutline(menuTextDraw[menuTextDrawCount], 0);
	TextDrawSetProportional(menuTextDraw[menuTextDrawCount], 1);
	TextDrawSetShadow(menuTextDraw[menuTextDrawCount], 1);
	TextDrawSetSelectable(menuTextDraw[menuTextDrawCount++], 0);

   	menuTextDrawID[E_MENU_TEXTDRAW_EMPTY_LEFT][0] = menuTextDrawCount;
	menuTextDraw[menuTextDrawCount] = TextDrawCreate(167.000000, 237.000000, "_");
	TextDrawBackgroundColor(menuTextDraw[menuTextDrawCount], 255);
	TextDrawFont(menuTextDraw[menuTextDrawCount], 1);
	TextDrawLetterSize(menuTextDraw[menuTextDrawCount], 0.000000, -0.200001);
	TextDrawColor(menuTextDraw[menuTextDrawCount], -1);
	TextDrawSetOutline(menuTextDraw[menuTextDrawCount], 0);
	TextDrawSetProportional(menuTextDraw[menuTextDrawCount], 1);
	TextDrawSetShadow(menuTextDraw[menuTextDrawCount], 1);
	TextDrawUseBox(menuTextDraw[menuTextDrawCount], 1);
	TextDrawBoxColor(menuTextDraw[menuTextDrawCount], 1179010710);
	TextDrawTextSize(menuTextDraw[menuTextDrawCount], 241.000000, 0.000000);
	TextDrawSetSelectable(menuTextDraw[menuTextDrawCount++], 0);

   	menuTextDrawID[E_MENU_TEXTDRAW_EMPTY_LEFT][1] = menuTextDrawCount;
	menuTextDraw[menuTextDrawCount] = TextDrawCreate(204.000000, 232.000000, "NOTHING CLOSE TO YOU");
	TextDrawAlignment(menuTextDraw[menuTextDrawCount], 2);
	TextDrawBackgroundColor(menuTextDraw[menuTextDrawCount], 0);
	TextDrawFont(menuTextDraw[menuTextDrawCount], FONT);
	TextDrawLetterSize(menuTextDraw[menuTextDrawCount], 0.149998, 0.899998);
	TextDrawColor(menuTextDraw[menuTextDrawCount], 1179010815);
	TextDrawSetOutline(menuTextDraw[menuTextDrawCount], 0);
	TextDrawSetProportional(menuTextDraw[menuTextDrawCount], 1);
	TextDrawSetShadow(menuTextDraw[menuTextDrawCount], 1);
	TextDrawSetSelectable(menuTextDraw[menuTextDrawCount++], 0);

   	menuTextDrawID[E_MENU_TEXTDRAW_EMPTY_RIGHT][0] = menuTextDrawCount;
	menuTextDraw[menuTextDrawCount] = TextDrawCreate(262.000000, 237.000000, "_");
	TextDrawBackgroundColor(menuTextDraw[menuTextDrawCount], 255);
	TextDrawFont(menuTextDraw[menuTextDrawCount], 1);
	TextDrawLetterSize(menuTextDraw[menuTextDrawCount], 0.000000, -0.200001);
	TextDrawColor(menuTextDraw[menuTextDrawCount], -1);
	TextDrawSetOutline(menuTextDraw[menuTextDrawCount], 0);
	TextDrawSetProportional(menuTextDraw[menuTextDrawCount], 1);
	TextDrawSetShadow(menuTextDraw[menuTextDrawCount], 1);
	TextDrawUseBox(menuTextDraw[menuTextDrawCount], 1);
	TextDrawBoxColor(menuTextDraw[menuTextDrawCount], 1179010710);
	TextDrawTextSize(menuTextDraw[menuTextDrawCount], 481.000000, 0.000000);
	TextDrawSetSelectable(menuTextDraw[menuTextDrawCount++], 0);

   	menuTextDrawID[E_MENU_TEXTDRAW_EMPTY_RIGHT][1] = menuTextDrawCount;
	menuTextDraw[menuTextDrawCount] = TextDrawCreate(373.000000, 232.000000, "NOTHING IN YOUR INVENTORY");
	TextDrawAlignment(menuTextDraw[menuTextDrawCount], 2);
	TextDrawBackgroundColor(menuTextDraw[menuTextDrawCount], 0);
	TextDrawFont(menuTextDraw[menuTextDrawCount], FONT);
	TextDrawLetterSize(menuTextDraw[menuTextDrawCount], 0.149998, 0.899998);
	TextDrawColor(menuTextDraw[menuTextDrawCount], 1179010815);
	TextDrawSetOutline(menuTextDraw[menuTextDrawCount], 0);
	TextDrawSetProportional(menuTextDraw[menuTextDrawCount], 1);
	TextDrawSetShadow(menuTextDraw[menuTextDrawCount], 1);
	TextDrawSetSelectable(menuTextDraw[menuTextDrawCount++], 0);

	for (new i, j = GetPlayerPoolSize(); i <= j; i++)
 	{
		if (IsPlayerConnected(i))
	    {
		 	OnPlayerConnect(i);
		}
	}

	#if defined INV_OnGameModeInit
		return INV_OnGameModeInit();
	#else
		return 1;
	#endif
}
#if defined _ALS_OnGameModeInit
	#undef OnGameModeInit
#else
	#define _ALS_OnGameModeInit
#endif
#define OnGameModeInit INV_OnGameModeInit
#if defined INV_OnGameModeInit
	forward INV_OnGameModeInit();
#endif

public OnGameModeExit()
{
	for (new i; i < menuTextDrawCount; i++)
 	{
  		TextDrawDestroy(menuTextDraw[i]);
    }

	for (new i, j = GetPlayerPoolSize(); i <= j; i++)
 	{
		if (IsPlayerConnected(i))
	    {
		 	OnPlayerDisconnect(i, 0);
		}
	}

	#if defined INV_OnGameModeExit
		return INV_OnGameModeExit();
	#else
		return 1;
	#endif
}
#if defined _ALS_OnGameModeExit
	#undef OnGameModeExit
#else
	#define _ALS_OnGameModeExit
#endif
#define OnGameModeExit INV_OnGameModeExit
#if defined INV_OnGameModeExit
	forward INV_OnGameModeExit();
#endif

public OnPlayerConnect(playerid)
{
	menuPlayerTextDrawID[playerid][E_MENU_TEXTDRAW_SCROLL] = menuPlayerTextDrawCount[playerid];
	menuPlayerTextDraw[playerid][menuPlayerTextDrawCount[playerid]] = CreatePlayerTextDraw(playerid, 246.000000, 172.000000, "_");
	PlayerTextDrawBackgroundColor(playerid, menuPlayerTextDraw[playerid][menuPlayerTextDrawCount[playerid]], 255);
	PlayerTextDrawFont(playerid, menuPlayerTextDraw[playerid][menuPlayerTextDrawCount[playerid]], 1);
	PlayerTextDrawLetterSize(playerid, menuPlayerTextDraw[playerid][menuPlayerTextDrawCount[playerid]], 0.000000, 14.599998);
	PlayerTextDrawColor(playerid, menuPlayerTextDraw[playerid][menuPlayerTextDrawCount[playerid]], -1);
	PlayerTextDrawSetOutline(playerid, menuPlayerTextDraw[playerid][menuPlayerTextDrawCount[playerid]], 0);
	PlayerTextDrawSetProportional(playerid, menuPlayerTextDraw[playerid][menuPlayerTextDrawCount[playerid]], 1);
	PlayerTextDrawSetShadow(playerid, menuPlayerTextDraw[playerid][menuPlayerTextDrawCount[playerid]], 1);
	PlayerTextDrawUseBox(playerid, menuPlayerTextDraw[playerid][menuPlayerTextDrawCount[playerid]], 1);
	PlayerTextDrawBoxColor(playerid, menuPlayerTextDraw[playerid][menuPlayerTextDrawCount[playerid]], -1768515896);
	PlayerTextDrawTextSize(playerid, menuPlayerTextDraw[playerid][menuPlayerTextDrawCount[playerid]], 247.000000, 0.000000);
	PlayerTextDrawSetSelectable(playerid, menuPlayerTextDraw[playerid][menuPlayerTextDrawCount[playerid]++], 0);

	menuPlayerTextDrawID[playerid][E_MENU_TEXTDRAW_LEFT_COUNT] = menuPlayerTextDrawCount[playerid];
	menuPlayerTextDraw[playerid][menuPlayerTextDrawCount[playerid]] = CreatePlayerTextDraw(playerid,162.000000, 150.000000, "Items close to you: ~y~0");
	PlayerTextDrawBackgroundColor(playerid,menuPlayerTextDraw[playerid][menuPlayerTextDrawCount[playerid]], 0);
	PlayerTextDrawFont(playerid,menuPlayerTextDraw[playerid][menuPlayerTextDrawCount[playerid]], FONT);
	PlayerTextDrawLetterSize(playerid,menuPlayerTextDraw[playerid][menuPlayerTextDrawCount[playerid]], 0.159998, 0.899999);
	PlayerTextDrawColor(playerid,menuPlayerTextDraw[playerid][menuPlayerTextDrawCount[playerid]], -1);
	PlayerTextDrawSetOutline(playerid,menuPlayerTextDraw[playerid][menuPlayerTextDrawCount[playerid]], 0);
	PlayerTextDrawSetProportional(playerid,menuPlayerTextDraw[playerid][menuPlayerTextDrawCount[playerid]], 1);
	PlayerTextDrawSetShadow(playerid,menuPlayerTextDraw[playerid][menuPlayerTextDrawCount[playerid]], 1);
	PlayerTextDrawSetSelectable(playerid,menuPlayerTextDraw[playerid][menuPlayerTextDrawCount[playerid]++], 0);

	menuPlayerTextDrawID[playerid][E_MENU_TEXTDRAW_RIGHT_COUNT] = menuPlayerTextDrawCount[playerid];
	menuPlayerTextDraw[playerid][menuPlayerTextDrawCount[playerid]] = CreatePlayerTextDraw(playerid,255.000000, 150.000000, "Items in your inventory: ~y~13/15");
	PlayerTextDrawBackgroundColor(playerid,menuPlayerTextDraw[playerid][menuPlayerTextDrawCount[playerid]], 0);
	PlayerTextDrawFont(playerid,menuPlayerTextDraw[playerid][menuPlayerTextDrawCount[playerid]], FONT);
	PlayerTextDrawLetterSize(playerid,menuPlayerTextDraw[playerid][menuPlayerTextDrawCount[playerid]], 0.159998, 0.899999);
	PlayerTextDrawColor(playerid,menuPlayerTextDraw[playerid][menuPlayerTextDrawCount[playerid]], -1);
	PlayerTextDrawSetOutline(playerid,menuPlayerTextDraw[playerid][menuPlayerTextDrawCount[playerid]], 0);
	PlayerTextDrawSetProportional(playerid,menuPlayerTextDraw[playerid][menuPlayerTextDrawCount[playerid]], 1);
	PlayerTextDrawSetShadow(playerid,menuPlayerTextDraw[playerid][menuPlayerTextDrawCount[playerid]], 1);
	PlayerTextDrawSetSelectable(playerid,menuPlayerTextDraw[playerid][menuPlayerTextDrawCount[playerid]++], 0);

	for (new i; i < MAX_LEFT_MENU_ROWS; i++)
	{
    	menuPlayerTextDrawID[playerid][E_MENU_TEXTDRAW_LEFT_TEXT][i] = menuPlayerTextDrawCount[playerid];
		menuPlayerTextDraw[playerid][menuPlayerTextDrawCount[playerid]] = CreatePlayerTextDraw(playerid, 186.000000, (164.000000 + (i * 22.000000)), "-");
		PlayerTextDrawBackgroundColor(playerid,menuPlayerTextDraw[playerid][menuPlayerTextDrawCount[playerid]], 0);
		PlayerTextDrawFont(playerid,menuPlayerTextDraw[playerid][menuPlayerTextDrawCount[playerid]], FONT);
		PlayerTextDrawLetterSize(playerid,menuPlayerTextDraw[playerid][menuPlayerTextDrawCount[playerid]], 0.119998, 0.699998);
		PlayerTextDrawColor(playerid,menuPlayerTextDraw[playerid][menuPlayerTextDrawCount[playerid]], -926365441);
		PlayerTextDrawSetOutline(playerid,menuPlayerTextDraw[playerid][menuPlayerTextDrawCount[playerid]], 0);
		PlayerTextDrawSetProportional(playerid,menuPlayerTextDraw[playerid][menuPlayerTextDrawCount[playerid]], 1);
		PlayerTextDrawSetShadow(playerid,menuPlayerTextDraw[playerid][menuPlayerTextDrawCount[playerid]], 1);
		PlayerTextDrawUseBox(playerid,menuPlayerTextDraw[playerid][menuPlayerTextDrawCount[playerid]], 1);
		PlayerTextDrawBoxColor(playerid,menuPlayerTextDraw[playerid][menuPlayerTextDrawCount[playerid]], 0);
		PlayerTextDrawTextSize(playerid,menuPlayerTextDraw[playerid][menuPlayerTextDrawCount[playerid]], 238.000000, 0.000000);
		PlayerTextDrawSetSelectable(playerid,menuPlayerTextDraw[playerid][menuPlayerTextDrawCount[playerid]++], 0);
	}

	for (new a; a < MAX_RIGHT_MENU_ROWS; a++)
    {
        for (new b; b < MAX_RIGHT_MENU_COLUMNS; b++)
        {
    		menuPlayerTextDrawID[playerid][E_MENU_TEXTDRAW_RIGHT_TEXT][(a * MAX_RIGHT_MENU_COLUMNS) + b] = menuPlayerTextDrawCount[playerid];
			menuPlayerTextDraw[playerid][menuPlayerTextDrawCount[playerid]] = CreatePlayerTextDraw(playerid, (260.000000 + (b * 46.000000)), (193.000000 + (a * 51.000000)), "-");
			PlayerTextDrawBackgroundColor(playerid,menuPlayerTextDraw[playerid][menuPlayerTextDrawCount[playerid]], 0);
			PlayerTextDrawFont(playerid,menuPlayerTextDraw[playerid][menuPlayerTextDrawCount[playerid]], FONT);
			PlayerTextDrawLetterSize(playerid,menuPlayerTextDraw[playerid][menuPlayerTextDrawCount[playerid]], 0.149999, 0.799998);
			PlayerTextDrawColor(playerid,menuPlayerTextDraw[playerid][menuPlayerTextDrawCount[playerid]], -926365441);
			PlayerTextDrawSetOutline(playerid,menuPlayerTextDraw[playerid][menuPlayerTextDrawCount[playerid]], 0);
			PlayerTextDrawSetProportional(playerid,menuPlayerTextDraw[playerid][menuPlayerTextDrawCount[playerid]], 1);
			PlayerTextDrawSetShadow(playerid,menuPlayerTextDraw[playerid][menuPlayerTextDrawCount[playerid]], 1);
			PlayerTextDrawUseBox(playerid,menuPlayerTextDraw[playerid][menuPlayerTextDrawCount[playerid]], 1);
			PlayerTextDrawBoxColor(playerid,menuPlayerTextDraw[playerid][menuPlayerTextDrawCount[playerid]], 0);
			PlayerTextDrawTextSize(playerid,menuPlayerTextDraw[playerid][menuPlayerTextDrawCount[playerid]], (300.000000 + (b * 46.000000)), (0.000000 + (a * 51.000000)));
			PlayerTextDrawSetSelectable(playerid,menuPlayerTextDraw[playerid][menuPlayerTextDrawCount[playerid]++], 0);
		}
	}



	playerItemPickupTextDraw[playerid] = CreatePlayerTextDraw(playerid,260.000000, 360.000000, "Press Y to pickup Shovel");
	PlayerTextDrawBackgroundColor(playerid,playerItemPickupTextDraw[playerid], 255);
	PlayerTextDrawFont(playerid,playerItemPickupTextDraw[playerid], 1);
	PlayerTextDrawLetterSize(playerid,playerItemPickupTextDraw[playerid], 0.560000, 2.700000);
	PlayerTextDrawColor(playerid,playerItemPickupTextDraw[playerid], -1);
	PlayerTextDrawSetOutline(playerid,playerItemPickupTextDraw[playerid], 0);
	PlayerTextDrawSetProportional(playerid,playerItemPickupTextDraw[playerid], 1);
	PlayerTextDrawSetShadow(playerid,playerItemPickupTextDraw[playerid], 1);
	PlayerTextDrawUseBox(playerid,playerItemPickupTextDraw[playerid], 1);
	PlayerTextDrawBoxColor(playerid,playerItemPickupTextDraw[playerid], 0);
	PlayerTextDrawTextSize(playerid,playerItemPickupTextDraw[playerid], 600.000000, 0.000000);
	PlayerTextDrawSetSelectable(playerid,playerItemPickupTextDraw[playerid], 0);



	playerInventoryItemsCount[playerid] = 0;

	#if defined INV_OnPlayerConnect
		return INV_OnPlayerConnect(playerid);
	#else
		return 1;
	#endif
}
#if defined _ALS_OnPlayerConnect
	#undef OnPlayerConnect
#else
	#define _ALS_OnPlayerConnect
#endif
#define OnPlayerConnect INV_OnPlayerConnect
#if defined INV_OnPlayerConnect
	forward INV_OnPlayerConnect(playerid);
#endif

public OnPlayerDisconnect(playerid, reason)
{
	for (new i; i < menuPlayerTextDrawCount[playerid]; i++)
 	{
  		PlayerTextDrawDestroy(playerid, menuPlayerTextDraw[playerid][i]);
    }

    playerUsingMenu[playerid] = false;

	#if defined INV_OnPlayerDisconnect
		return INV_OnPlayerDisconnect(playerid, reason);
	#else
		return 1;
	#endif
}
#if defined _ALS_OnPlayerDisconnect
	#undef OnPlayerDisconnect
#else
	#define _ALS_OnPlayerDisconnect
#endif
#define OnPlayerDisconnect INV_OnPlayerDisconnect
#if defined INV_OnPlayerDisconnect
	forward INV_OnPlayerDisconnect(playerid, reason);
#endif

public OnPlayerClickTextDraw(playerid, Text:clickedid)
{
	if (playerUsingMenu[playerid])
	{
		if (clickedid == Text:INVALID_TEXT_DRAW)
		{
			return Inv_Hide(playerid);
		}
		else
		{
	        for (new i; i < MAX_LEFT_MENU_ROWS; i++)
		 	{
		    	if (clickedid == menuTextDraw[menuTextDrawID[E_MENU_TEXTDRAW_LEFT_BOX][i]] || clickedid == menuTextDraw[menuTextDrawID[E_MENU_TEXTDRAW_LEFT_MODEL][i]])
		    	{
			        if (playerLeftMenuListitem[playerid] == i)
			        {
			            if ((GetTickCount() - playerLeftMenuClickTickCount[playerid][i]) <= 200)
			            {
			                return OnPlayerClickTextDraw(playerid, menuTextDraw[menuTextDrawID[E_MENU_TEXTDRAW_LEFTBTN]]);
			            }
			            playerLeftMenuClickTickCount[playerid][i] = GetTickCount();
			            return 1;
			        }

				    playerLeftMenuListitem[playerid] = i;
				    Inv_UpdateLeftMenu(playerid);
					return 1;
		    	}
		 	}

	        for (new i; i < (MAX_RIGHT_MENU_COLUMNS * MAX_RIGHT_MENU_ROWS); i++)
		 	{
		    	if (clickedid == menuTextDraw[menuTextDrawID[E_MENU_TEXTDRAW_RIGHT_MODEL][i]])
				{
			        if (playerRightMenuListitem[playerid] == i)
			        {
			            if ((GetTickCount() - playerRightMenuClickTickCount[playerid][i]) <= 200)
			            {
			                return OnPlayerClickTextDraw(playerid, menuTextDraw[menuTextDrawID[E_MENU_TEXTDRAW_MIDDLEBTN]]);
			            }
			            playerRightMenuClickTickCount[playerid][i] = GetTickCount();
			            return 1;
			        }

				    playerRightMenuListitem[playerid] = i;
				    Inv_UpdateRightMenu(playerid);
					return 1;
		    	}
		 	}

		    if (clickedid == menuTextDraw[menuTextDrawID[E_MENU_TEXTDRAW_SCROLL_UP]])
		    {
		        if (playerLeftMenuPage[playerid] == 0)
		        {
		            return 0;
		        }

			    playerLeftMenuPage[playerid]--;
			    playerLeftMenuListitem[playerid] = (MAX_LEFT_MENU_ROWS - 1);
			    Inv_UpdateLeftMenu(playerid);
				return 1;
		    }

		    if (clickedid == menuTextDraw[menuTextDrawID[E_MENU_TEXTDRAW_SCROLL_DOWN]])
		    {
		        if (playerLeftMenuPage[playerid] == (PAGES(nearbyItemsCount[playerid], MAX_LEFT_MENU_ROWS) - 1))
		        {
		            return 0;
		        }

			    playerLeftMenuPage[playerid]++;
			    playerLeftMenuListitem[playerid] = 0;
			    Inv_UpdateLeftMenu(playerid);
				return 1;
		    }

		    if (clickedid == menuTextDraw[menuTextDrawID[E_MENU_TEXTDRAW_LEFTBTN]])
		    {
		        if (nearbyItemsCount[playerid] == 0)
		        {
		            return SendClientMessage(playerid, COLOR_TOMATO, "Nothing close to you to pickup!");
		        }

		        new itemid = nearbyItems[playerid][playerLeftMenuListitem[playerid] + (playerLeftMenuPage[playerid] * MAX_LEFT_MENU_ROWS)];
				if (Inv_GivePlayerItem(playerid, itemid) == 0)
		        {
		            return SendClientMessage(playerid, COLOR_TOMATO, "Your bag is full of stuff! Empty it to swap this item.");
		        }

		        new string[128] = "Item pickedup: ";
		        strcat(string, item[itemid][E_ITEM_NAME]);
		        SendClientMessage(playerid, COLOR_GREEN, string);

		        ApplyAnimation(playerid, "MISC", "PICKUP_box", 3.0, 0, 0, 0, 0, 0);
				return 1;
		    }

		    if (clickedid == menuTextDraw[menuTextDrawID[E_MENU_TEXTDRAW_RIGHTBTN]])
		    {
		        if (playerInventoryItemsCount[playerid] == 0)
		        {
		            return SendClientMessage(playerid, COLOR_TOMATO, "There's nothing in your bag to throw!");
		        }

				new itemid = Inv_DropPlayerItem(playerid, playerRightMenuListitem[playerid]);
				if (itemid == -1)
		        {
		            return SendClientMessage(playerid, COLOR_TOMATO, "Something wrong happened! This is a rare system error, please let an admin know about this and you might get your item back.");
		        }

		        new string[128] = "Item dropped: ";
		        strcat(string, item[itemid][E_ITEM_NAME]);
		        SendClientMessage(playerid, COLOR_GREEN, string);

		        ApplyAnimation(playerid, "GRENADE", "WEAPON_throwu", 3.0, 0, 0, 0, 0, 0);
				return 1;
		    }

		    if (clickedid == menuTextDraw[menuTextDrawID[E_MENU_TEXTDRAW_MIDDLEBTN]])
		    {
		        if (playerInventoryItemsCount[playerid] == 0)
		        {
		            return SendClientMessage(playerid, COLOR_TOMATO, "There's nothing in your bag to use!");
		        }

		        new itemid = playerInventoryItems[playerid][playerRightMenuListitem[playerid]];

		        CallRemoteFunction("OnPlayerUseItem", "ii", playerid, item[itemid][E_ITEM_MODELID]);

		        new string[128] = "Item used: ";
		        strcat(string, item[itemid][E_ITEM_NAME]);
		        SendClientMessage(playerid, COLOR_GREEN, string);

				Inv_RemoveItem(itemid);

				Inv_Hide(playerid);
				return 1;
		    }

		    if (clickedid == menuTextDraw[menuTextDrawID[E_MENU_TEXTDRAW_CLOSE]])
		    {
		        return Inv_Hide(playerid);
		    }
		}
	}

	#if defined INV_OnPlayerClickTextDraw
		return INV_OnPlayerClickTextDraw(playerid, Text:clickedid);
	#else
		return 1;
	#endif
}
#if defined _ALS_OnPlayerClickTextDraw
	#undef OnPlayerClickTextDraw
#else
	#define _ALS_OnPlayerClickTextDraw
#endif
#define OnPlayerClickTextDraw INV_OnPlayerClickTextDraw
#if defined INV_OnPlayerClickTextDraw
	forward INV_OnPlayerClickTextDraw(playerid, Text:clickedid);
#endif

public OnPlayerDeath(playerid, killerid, reason)
{
	if (playerUsingMenu[playerid])
	{
		Inv_Hide(playerid);
	}

	#if defined INV_OnPlayerDeath
		return INV_OnPlayerDeath(playerid, killerid, reason);
	#else
		return 1;
	#endif
}
#if defined _ALS_OnPlayerDeath
	#undef OnPlayerDeath
#else
	#define _ALS_OnPlayerDeath
#endif
#define OnPlayerDeath INV_OnPlayerDeath
#if defined INV_OnPlayerDeath
	forward INV_OnPlayerDeath(playerid, killerid, reason);
#endif

Inv_UpdatePlaiyerPickupTextDraw(playerid)
{
	new count;
	new latest;
	for (new i; i <= itemPoolSize; i++)
	{
 		if (!item[i][E_ITEM_VALID])
		{
    		continue;
		}

	    if (IsPlayerInDynamicArea(playerid, item[i][E_ITEM_AREAID]))
	    {
	        count++;
	        latest = i;
	    }
	}

	new string[64];
	if (count == 1)
	{
		format(string, sizeof string, "Press ~k~~CONVERSATION_YES~ to pickup %s", item[latest][E_ITEM_NAME]);
 		PlayerTextDrawSetString(playerid, playerItemPickupTextDraw[playerid], string);
		PlayerTextDrawShow(playerid, playerItemPickupTextDraw[playerid]);
	}
	else if (count == 2)
	{
		format(string, sizeof string, "Press ~k~~CONVERSATION_YES~ to pickup %s and 1 more item", item[latest][E_ITEM_NAME]);
 		PlayerTextDrawSetString(playerid, playerItemPickupTextDraw[playerid], string);
		PlayerTextDrawShow(playerid, playerItemPickupTextDraw[playerid]);
	}
	else if (count > 2)
	{
		format(string, sizeof string, "Press ~k~~CONVERSATION_YES~ to pickup %s and %i more items", item[latest][E_ITEM_NAME], count);
 		PlayerTextDrawSetString(playerid, playerItemPickupTextDraw[playerid], string);
		PlayerTextDrawShow(playerid, playerItemPickupTextDraw[playerid]);
	}
	else
	{
	    PlayerTextDrawHide(playerid, playerItemPickupTextDraw[playerid]);
	}
}

public OnPlayerEnterDynamicArea(playerid, areaid)
{
    Inv_UpdatePlaiyerPickupTextDraw(playerid);

	#if defined INV_OnPlayerEnterDynamicArea
		return INV_OnPlayerEnterDynamicArea(playerid, areaid);
	#else
		return 1;
	#endif
}
#if defined _ALS_OnPlayerEnterDynamicArea
	#undef OnPlayerEnterDynamicArea
#else
	#define _ALS_OnPlayerEnterDynamicArea
#endif
#define OnPlayerEnterDynamicArea INV_OnPlayerEnterDynamicArea
#if defined INV_OnPlayerEnterDynamicArea
	forward INV_OnPlayerEnterDynamicArea(playerid, areaid);
#endif

public OnPlayerLeaveDynamicArea(playerid, areaid)
{
    Inv_UpdatePlaiyerPickupTextDraw(playerid);

	#if defined INV_OnPlayerLeaveDynamicArea
		return INV_OnPlayerLeaveDynamicArea(playerid, areaid);
	#else
		return 1;
	#endif
}
#if defined _ALS_OnPlayerLeaveDynamicArea
	#undef OnPlayerLeaveDynamicArea
#else
	#define _ALS_OnPlayerLeaveDynamicArea
#endif
#define OnPlayerLeaveDynamicArea INV_OnPlayerLeaveDynamicArea
#if defined INV_OnPlayerLeaveDynamicArea
	forward INV_OnPlayerLeaveDynamicArea(playerid, areaid);
#endif

public OnPlayerEditDynamicObject(playerid, objectid, response, Float:x, Float:y, Float:z, Float:rx, Float:ry, Float:rz)
{
	for (new i; i <= itemPoolSize; i++)
	{
	    if (!item[i][E_ITEM_VALID])
	    {
	        continue;
	    }

	    if (item[i][E_ITEM_OBJECTID] == objectid)
	    {
			item[i][E_ITEM_ROTX] = rx;
			item[i][E_ITEM_ROTY] = ry;
			item[i][E_ITEM_ROTZ] = rz;

			item[i][E_ITEM_ZPUSH] = (z - item[i][E_ITEM_ZPUSH]);
			break;
	    }
	}
	
	#if defined INV_OnPlayerEditDynamicObject
		return INV_OnPlayerEditDynamicObject(playerid, objectid, response, x, y, z, rx, ry, rz);
	#else
		return 1;
	#endif
}
#if defined _ALS_OnPlayerEditDynamicObject
	#undef OnPlayerEditDynamicObject
#else
	#define _ALS_OnPlayerEditDynamicObject
#endif
#define OnPlayerEditDynamicObject INV_OnPlayerEditDynamicObject
#if defined INV_OnPlayerEditDynamicObject
	forward INV_OnPlayerEditDynamicObject(playerid, objectid, response, Float:x, Float:y, Float:z, Float:rx, Float:ry, Float:rz);
#endif

new createdItems[MAX_ITEMS];
new createdItemsCount;

CMD:additem(playerid)
{
	if (!IsPlayerAdmin(playerid))
	{
	    return SendClientMessage(playerid, COLOR_TOMATO, "You must be RCON-Admin to use this command.");
	}

	if (createdItemsCount == 0)
	{
	    return SendClientMessage(playerid, COLOR_TOMATO, "There are no items created yet! Start with /newitem.");
	}

	static string[MAX_ITEMS * 128];
	string[0] = EOS;
	for (new i; i < createdItemsCount; i++)
	{
	    format(string, sizeof string, "%s%i\t%s\n", string, item[createdItems[i]][E_ITEM_MODELID], item[createdItems[i]][E_ITEM_NAME]);
	}
	Dialog_Show(playerid, CREATED_ITEMS, DIALOG_STYLE_PREVMODEL, "Created items history", string, "Select", "Cancel");
	return 1;
}

Dialog:CREATED_ITEMS(playerid, response, listitem, inputtext[])
{
	if (response)
	{
		new Float:x, Float:y, Float:z;
		GetPlayerPos(playerid, x, y, z);
		new Float:ang;
		GetPlayerFacingAngle(playerid, ang);
		x += (1.5 * floatsin(-ang, degrees));
		y += (1.5 * floatcos(-ang, degrees));

	    new itemid = Inv_AddItem(item[createdItems[listitem]][E_ITEM_MODELID], item[createdItems[listitem]][E_ITEM_NAME], x, y, z + item[createdItems[listitem]][E_ITEM_ZPUSH], item[createdItems[listitem]][E_ITEM_ROTX], item[createdItems[listitem]][E_ITEM_ROTY], item[createdItems[listitem]][E_ITEM_ROTZ]);
	    if (itemid == -1)
	    {
	        return SendClientMessage(playerid, COLOR_TOMATO, "Cannot add anymore items, reached limit.");
	    }

	    new string[128];
	    format(string, sizeof string, "Item created: %s [itemid: %i | modelid: %i]", item[createdItems[listitem]][E_ITEM_NAME], itemid, item[createdItems[listitem]][E_ITEM_MODELID]);
	    SendClientMessage(playerid, COLOR_GREEN, string);
	}
	return 1;
}

CMD:newitem(playerid, params[])
{
	if (!IsPlayerAdmin(playerid))
	{
	    return SendClientMessage(playerid, COLOR_TOMATO, "You must be RCON-Admin to use this command.");
	}

	new itemName[MAX_ITEM_NAME], itemModelid;
	if (sscanf(params, "is[64]", itemModelid, itemName))
	{
	    return SendClientMessage(playerid, COLOR_DEFAULT, "Usage: /newitem [modelid] [name]");
	}

	new Float:x, Float:y, Float:z;
	GetPlayerPos(playerid, x, y, z);
	new Float:ang;
	GetPlayerFacingAngle(playerid, ang);
	x += (1.5 * floatsin(-ang, degrees));
	y += (1.5 * floatcos(-ang, degrees));
    new itemid = Inv_AddItem(itemModelid, itemName, x, y, z);
    if (itemid == -1)
    {
        return SendClientMessage(playerid, COLOR_TOMATO, "Cannot add anymore items, reached limit.");
    }
    
    Inv_EditItem(playerid, itemid);

    new string[128];
    format(string, sizeof string, "Item created: %s [itemid: %i | modelid: %i]", itemName, itemid, itemModelid);
    SendClientMessage(playerid, COLOR_GREEN, string);

	createdItems[createdItemsCount++] = itemid;
    SendClientMessage(playerid, COLOR_DEFAULT, "Item added to /items list, If you want to duplicate this item, type /additem.");
	return 1;
}
