/*****************************************************************************
                       Engineer VS Medics Modified
******************************************************************************/

#include <sourcemod>
#include <sdktools>
#include <tf2>
#include <tf2_stocks>
#include <clients>
#include <sdkhooks>
#include <smlib>
#include <morecolors>
#pragma tabsize 0

// ----------------------------- Convars ------------------------------------
ConVar zve_setup_time = null;
ConVar zve_round_time = null;
ConVar zve_super_zombies = null;
ConVar g_hMaxMetal;
ConVar g_hMetalRegen;
ConVar g_hMetalRegenTime;
ConVar g_hMetalRegenAmount;
ConVar zve_zombiedoublejump;
ConVar zve_zombiedoublejump_boost;

ConVar zve_timehud = null;
ConVar zve_timehud_x = null;
ConVar zve_timehud_z = null;
ConVar zve_timehud_color = null;
ConVar zve_nohud = null;

//Game related global variables
bool InfectionStarted = false;
bool SuperZombies = false;
bool isZombie[MAXPLAYERS+1];
int ZombieHealth = 1250;
int CountDownCounter = 0;
int g_iJumps[MAXPLAYERS+1];
int g_fLastButtons[MAXPLAYERS+1];
int g_fLastFlags[MAXPLAYERS+1];
float ActualRoundTime = 0.0;

bool g_bShowTimeHud = true;
float g_fTimeHudX = -1.0;
float g_fTimeHudY = 1.00;
int g_iTimeHudColor[4] = {255, 255, 255, 255};

// ----------------------------- Handlers ------------------------------------
Handle RedWonHandle = INVALID_HANDLE;
Handle SuperZombiesTimerHandle = INVALID_HANDLE;
Handle InfectionHandle = INVALID_HANDLE;
Handle CountDownHandle = INVALID_HANDLE;
Handle CountDownStartHandle = INVALID_HANDLE;
Handle TimerHandle = INVALID_HANDLE;
Handle g_hRegenTimer = INVALID_HANDLE;
bool InPreparation = true;
float RemainingTime = 0.0;

public Plugin myinfo ={
	name = "Engineer VS Medics Modified",
	author = "shewowkees/modified by DGB",
	description = "Engies VS Zombies",
	version = "1.30",
};

public void OnPluginStart (){
	PrintToServer("Successfully loaded Zombies VS Engineers.");
	HookEvent("player_spawn",Evt_PlayerSpawnChangeClass,EventHookMode_Post);
	HookEvent("player_spawn",Evt_PlayerSpawnChangeTeam,EventHookMode_Pre);
	HookEvent("player_death",Evt_PlayerDeath,EventHookMode_Post);
	HookEvent("player_disconnect",Evt_PlayerDisconnect,EventHookMode_Post);
	HookEvent("teamplay_round_start", Evt_RoundStart);
	AddCommandListener(CommandListener_Build, "build");
	AddCommandListener(CommandListener_ChangeClass, "joinclass");
	AddCommandListener(CommandListener_ChangeTeam, "jointeam");
	AddCommandListener(CommandListener_Spectate, "spectate");
	
// ----------------------------- Commands ------------------------------------

	RegServerCmd("zve_debug_checkvictory", DebugCheckVictory);
	RegAdminCmd("sm_zvecure", Command_zvecure, ADMFLAG_KICK, "Makes an admin be a red engineer");
	RegAdminCmd("sm_zveinfect", Command_zveinfect, ADMFLAG_KICK, "Makes an admin be a Super Zombie");
    RegConsoleCmd("sm_engietutorial", Command_EngieTutorial, "Enable/Disable Engineer Tutorial");
	RegConsoleCmd("sm_medictutorial", Command_ZombieTutorial, "Enable/Disable Zombie Tutorial");


// ----------------------------- Convars ------------------------------------

	zve_round_time = CreateConVar("zve_round_time", "314", "Round time, 5 minutes by default.");
	zve_setup_time = CreateConVar("zve_setup_time", "60.0", "Setup time, 60s by default.");
	zve_super_zombies = CreateConVar("zve_super_zombies", "30.0", "How much time before round end zombies gain super abilities. Set to 0 to disable it.");

	zve_timehud = CreateConVar("zve_timehud", "1", "Enables/disables the round timeout timer.", _, true, 0.0, true, 1.0);
	zve_timehud_x = CreateConVar("zve_timehud_x", "-1.0", "X position of the time HUD.");
	zve_timehud_z = CreateConVar("zve_timehud_z", "1.00", "Z (Y) position of the weather HUD.");
	zve_timehud_color = CreateConVar("zve_timehud_color", "255,255,255,255", "Timer HUD Color (R,G,B,A).");
	
	zve_nohud = CreateConVar("zve_nohud", "1", "Disables the game's HUD a bit for players.", _, true, 0.0, true, 1.0);

	CreateConVar("zve_healthboost", "60.0", "How much time after setup the first zombies have a health boost. Set to 0 to disable it.")
	
	g_hMaxMetal = CreateConVar("zve_maxmetal", "200", "Maximum metal for engineers (200-999)", FCVAR_NONE, true, 200.0, true, 999.0);
    g_hMetalRegen = CreateConVar("zve_metalregen", "1", "Enables/disables metal regeneration (0 = disabled, 1 = enabled)", FCVAR_NONE, true, 0.0, true, 1.0);
    g_hMetalRegenTime = CreateConVar("zve_metalregentime", "1.0", "Metal regeneration interval (seconds)", FCVAR_NONE, true, 0.1, true, 10.0);
    g_hMetalRegenAmount = CreateConVar("zve_metalregenamount", "10", "Amount of metal regenerated per interval", FCVAR_NONE, true, 1.0, true, 100.0);
	
	zve_zombiedoublejump = CreateConVar("zve_zombiedoublejump", "1", "Enables double jump for zombies (1 = yes, 0 = no)", _, true, 0.0, true, 1.0);
    zve_zombiedoublejump_boost = CreateConVar("zve_zombiedoublejump_boost", "250.0", "Double Jump Vertical Power for Zombies");

    HookConVarChange(g_hMetalRegenTime, OnMetalRegenTimeChanged);
	HookConVarChange(zve_timehud, OnTimeHudChanged);
	HookConVarChange(zve_timehud_x, OnTimeHudPosChanged);
	HookConVarChange(zve_timehud_z, OnTimeHudPosChanged);
	HookConVarChange(zve_timehud_color, OnTimeHudColorChanged);
	HookConVarChange(zve_nohud, OnNoHudChanged);

    StartRegenTimer();
	
	AutoExecConfig(true, "plugin_zve");

	LoadTranslations("engiesVSmedics.phrases");
	CPrintToChatAll("%t", "load_plugin");
    Stalemate()
}

public void OnTimeHudChanged(ConVar convar, const char[] oldValue, const char[] newValue) {
	g_bShowTimeHud = GetConVarBool(zve_timehud);
}

public void OnTimeHudPosChanged(ConVar convar, const char[] oldValue, const char[] newValue) {
	g_fTimeHudX = GetConVarFloat(zve_timehud_x);
	g_fTimeHudY = GetConVarFloat(zve_timehud_z);
}

public void OnTimeHudColorChanged(ConVar convar, const char[] oldValue, const char[] newValue) {
	char colorStr[32];
	GetConVarString(zve_timehud_color, colorStr, sizeof(colorStr));
	ParseColorString(colorStr, g_iTimeHudColor);
}

public void OnNoHudChanged(ConVar convar, const char[] oldValue, const char[] newValue) {
	int flags = GetConVarInt(zve_nohud) ? HIDEHUD_MISCSTATUS : 0;
	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i) && !IsFakeClient(i)) {
			Client_SetHideHud(i, flags);
		}
	}
}

void ParseColorString(const char[] colorStr, int colors[4]) {
	char parts[4][4];
	int count = ExplodeString(colorStr, ",", parts, 4, 4);
	
	for (int i = 0; i < count; i++) {
		colors[i] = StringToInt(parts[i]);
	}
	
	if (count < 4) colors[3] = 255;
}

void Stalemate()
{
    int iEnt = -1;
    iEnt = FindEntityByClassname(iEnt, "game_round_win");
    
    if (iEnt < 1)
    {
        iEnt = CreateEntityByName("game_round_win");
        DispatchSpawn(iEnt);
    }
    
    SetVariantInt(0);
    AcceptEntityInput(iEnt, "SetTeam");
    AcceptEntityInput(iEnt, "RoundWin");
}

public OnMapStart(){

	PrecacheSound("vo/medic_medic03.mp3");
	PrecacheSound("vo/medic_no01.mp3");

	HookEntityOutput("trigger_capture_area", "OnStartCap", StartCap);

	CreateTimer(3.0, OpenDoors, _, TIMER_REPEAT);
}

public void OnClientPostAdminCheck(int client){

	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);

}

public void OnClientDisconnect(int client)
{
    g_iJumps[client] = 0;
    g_fLastButtons[client] = 0;
    g_fLastFlags[client] = 0;
}
// ----------------------------- Commands ------------------------------------
public Action DebugCheckVictory(int args){

	function_CheckVictory();
	return Plugin_Handled;

}

public Action Command_zvecure(int client, int args){
	int EntProp = GetEntProp(client, Prop_Send, "m_lifeState");
	SetEntProp(client, Prop_Send, "m_lifeState", 2);
	ChangeClientTeam(client, view_as<int>(TFTeam_Red) );
	TF2_SetPlayerClass(client, TFClass_Engineer, true, true);
	SetEntProp(client, Prop_Send, "m_lifeState", EntProp);
	TF2_RegeneratePlayer(client);
	return Plugin_Handled;
}

public Action Command_zveinfect(int client, int args){
	function_makeZombie(client,true);
	return Plugin_Handled;
}
// ----------------------------- Events and Forwards ------------------------------------


public Action:TF2_OnPlayerTeleport(client, teleporter, &bool:result) {
		result = true;
		return Plugin_Changed;
}

/*
 * This code is from Tsunami's TF2 build restrictions. It prevents engineers
 * from even placing a sentry.
 *
 */
public Action CommandListener_Build(client, const String:command[], argc)
{

	//initializing the array that will contain all user collision information


	SetEntProp(client, Prop_Data, "m_CollisionGroup", 5);
	//Feeding an array because i can only give one custom variable to the timer
	CreateTimer(3.0, reCollide, client);

	// Get arguments
	decl String:sObjectType[256]
	GetCmdArg(1, sObjectType, sizeof(sObjectType));

	// Get object mode, type and client's team
	new iObjectType = StringToInt(sObjectType),
	iTeam = GetClientTeam(client);

	// If invalid object type passed, or client is not on Blu or Red
	if(iObjectType < view_as<int>(TFObject_Dispenser) || iObjectType > view_as<int>(TFObject_Sentry) || iTeam < view_as<int>(TFTeam_Red) ) {
		return Plugin_Continue;
	}

	//Blocks sentry building
	else if(iObjectType==view_as<int>(TFObject_Sentry) ) {
		CPrintToChat(client, "%t", "sentry_restric");
		return Plugin_Handled;
	}
	return Plugin_Continue;

}


public Action CommandListener_ChangeTeam(client, const String:command[],argc){

	CPrintToChat(client, "%t", "betray_team");
	return Plugin_Handled;

}

public Action CommandListener_ChangeClass(client,const String:command[], argc){
	decl String:arg1[256];
	GetCmdArg(1, arg1, sizeof(arg1));
	if(strcmp(arg1,"medic",false)==0 && TF2_GetClientTeam(client)==TFTeam_Blue ) {

		return Plugin_Continue;

	}else if( TF2_GetClientTeam(client)==TFTeam_Blue ) {

		ClientCommand(client,"joinclass medic");

	}

	if(strcmp(arg1,"engineer",false)==0 && TF2_GetClientTeam(client)==TFTeam_Red ) {

		return Plugin_Continue;

	}else if(TF2_GetClientTeam(client)==TFTeam_Red ) {

		ClientCommand(client,"joinclass engineer");

	}

	CPrintToChat(client, "%t", "change_class");
	return Plugin_Handled;

}


public Action CommandListener_Spectate(client, const String:command[], argc){
	CPrintToChat(client,"%t", "change_spectator");
	return Plugin_Handled;
}


public Action Evt_PlayerSpawnChangeTeam(Event event, const char[] name, bool dontBroadcast){
    int client = GetClientOfUserId(event.GetInt("userid"));
    
    if (IsClientReplay(client)) {
        return Plugin_Continue;
    }

    if (Client_IsValid(client) && Client_IsIngame(client)) {
        if (InfectionStarted) {
            if (TF2_GetClientTeam(client) != TFTeam_Blue) {
                function_SafeTeamChange(client, TFTeam_Blue);
                function_SafeRespawn(client);
                function_makeZombie(client, false);
            }
        } else if (TF2_GetClientTeam(client) != TFTeam_Red) {
            function_SafeTeamChange(client, TFTeam_Red);
            function_SafeRespawn(client);
        }
    }

    return Plugin_Handled;
}


public Action Evt_PlayerSpawnChangeClass(Event event, const char[] name, bool dontBroadcast){

	int client = GetClientOfUserId(event .GetInt("userid"));

	if(Client_IsValid(client) && Client_IsIngame(client)){

		CreateTimer(3.5,reCollide,client);
		if(TF2_GetClientTeam(client) == TFTeam_Red ){

			if(TF2_GetPlayerClass(client)!=TFClass_Engineer){
				TF2_SetPlayerClass(client,TFClass_Engineer);
				TF2_RespawnPlayer(client);
			}

			SetEntProp(client, Prop_Data, "m_CollisionGroup", 3);

		}
		if(TF2_GetClientTeam(client)==TFTeam_Blue){
			function_makeZombie(client, false);
			function_StripToMelee(client);
		}

		if (GetConVarBool(zve_nohud)) {
			Client_SetHideHud(client, HIDEHUD_MISCSTATUS);
		} else {
			Client_SetHideHud(client, 0);
		}

		function_CheckVictory();
	}
	
    return Plugin_Handled;

}

public Action TF2_CalcIsAttackCritical(int client, int weapon, char[] weaponname, bool &result){

	if(TF2_GetClientTeam(client)==TFTeam_Red){
		result=true;
	}
	return Plugin_Handled;

}


public Action OnTakeDamage(victim, &attacker, &inflictor, &Float:damage, &damagetype)
{
        if (SuperZombies && TF2_GetClientTeam(attacker) == TFTeam_Blue) {
            damage *= 2.0;
            return Plugin_Changed;
        }
	
		if(!Client_IsValid(victim)||!Client_IsValid(attacker)){
			return Plugin_Continue;
		}
		if(TF2_GetClientTeam(victim)==TFTeam_Red && TF2_GetClientTeam(attacker)==TFTeam_Blue){//that number is the one of the melee medic weapon
			if(damagetype==134221952){

				if(damage>Entity_GetHealth(victim)){
					SetEntProp(attacker, Prop_Data, "m_CollisionGroup",3);
					CreateTimer(3.5,reCollide,attacker);
					function_makeZombie(victim,false);
					Client_SetScore(attacker,Client_GetScore(attacker)+1);
					function_CheckVictory();
					return Plugin_Handled;
				}
				if(SuperZombies){
					damage=damage*1000.0;
					return Plugin_Continue;
				}
				return Plugin_Continue;
			}

			return Plugin_Handled;
		}


		return Plugin_Continue;
}

public Action Evt_PlayerDeath(Event event, const char[] name, bool dontBroadcast) {
    if (InfectionStarted) {
        int client = GetClientOfUserId(event.GetInt("userid"));
        TF2_ChangeClientTeam(client, TFTeam_Blue);
        TF2_SetPlayerClass(client, TFClass_Medic, true, true);
        function_CheckVictory();
    }
    return Plugin_Handled;
}

public Action Evt_PlayerDisconnect(Event event, const char[] name, bool dontBroadcast) {
    function_CheckVictory();
    return Plugin_Handled;
}


public StartCap(const String:output[], caller, activator, Float:delay)
{
	AcceptEntityInput(caller, "Disable");

}


public Action Evt_RoundStart(Event event, const char[] name, bool dontBroadcast){
	function_AllEngineers();
	SuperZombies = false;
	InfectionStarted = false;
	ServerCommand("sm_gravity @all 1");
	ServerCommand("sm_cvar tf_boost_drain_time 0");
	
	for (int i = 1; i <= MaxClients; i++) isZombie[i] = false;

    float setupTime = GetConVarFloat(zve_setup_time);
	
    for (int i = 1; i <= MaxClients; i++)
    {
        g_iJumps[i] = 0;
        g_fLastButtons[i] = 0;
        g_fLastFlags[i] = 0;
    }
	
	if(RedWonHandle!=INVALID_HANDLE) {
		CloseHandle(RedWonHandle);
		RedWonHandle=INVALID_HANDLE;
	}

	if(SuperZombiesTimerHandle!=INVALID_HANDLE) {
		CloseHandle(SuperZombiesTimerHandle);
		SuperZombiesTimerHandle=INVALID_HANDLE;
	}

	if(InfectionHandle!=INVALID_HANDLE) {
		CloseHandle(InfectionHandle);
		InfectionHandle=INVALID_HANDLE;
	}

	if(CountDownHandle!=INVALID_HANDLE) {
		CloseHandle(CountDownHandle);
		CountDownHandle=INVALID_HANDLE;
	}

	if(CountDownStartHandle!=INVALID_HANDLE) {
		CloseHandle(CountDownStartHandle);
		CountDownStartHandle=INVALID_HANDLE;
	}
	
    if (TimerHandle != INVALID_HANDLE) {
        CloseHandle(TimerHandle);
    }
	
    InPreparation = true;
    RemainingTime = GetConVarFloat(zve_setup_time);

	ActualRoundTime = GetConVarFloat(zve_round_time)+GetConVarFloat(zve_setup_time);
	RedWonHandle = CreateTimer(ActualRoundTime,RedWon);
	if(GetConVarFloat(zve_super_zombies)>0.0) {
		SuperZombiesTimerHandle = CreateTimer(ActualRoundTime-GetConVarFloat(zve_super_zombies), SuperZombiesTimer);
	}

	InfectionHandle = CreateTimer(setupTime, Infection);
	if(setupTime>11.0) {
		CountDownStartHandle = CreateTimer(setupTime-4.0, CountDownStart);
	}


	function_PrepareMap();
	
	CPrintToChatAll("%t", "version");

	g_bShowTimeHud = GetConVarBool(zve_timehud);
	g_fTimeHudX = GetConVarFloat(zve_timehud_x);
	g_fTimeHudY = GetConVarFloat(zve_timehud_z);
	char colorStr[32];
	GetConVarString(zve_timehud_color, colorStr, sizeof(colorStr));
	ParseColorString(colorStr, g_iTimeHudColor);

	int nohudFlags = GetConVarBool(zve_nohud) ? HIDEHUD_MISCSTATUS : 0;
	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i) && !IsFakeClient(i)) {
			Client_SetHideHud(i, nohudFlags);
		}
	}

    TimerHandle = CreateTimer(1.0, UpdateHud, _, TIMER_REPEAT);
    return Plugin_Continue;
}
// ----------------------------- Tutorials ------------------------------------

// Exibidor do menu (Tutorial)...
public void ShowZombieTutorial(int client) {
    Menu menu = CreateMenu(MenuHandler_ZombieTutorial);

    char title[64];
    Format(title, sizeof(title), "%t", "ZombieTutorial_Menu");
    menu.SetTitle(title);

    char line1[128], line2[128], line3[128];

    Format(line1, sizeof(line1), "%t", "ZombieTutorial_Line1");
    Format(line2, sizeof(line2), "%t", "ZombieTutorial_Line2");
    Format(line3, sizeof(line3), "%t", "ZombieTutorial_Line3");

    menu.AddItem("1", line1);
    menu.AddItem("2", line2);
    menu.AddItem("3", line3);

    menu.Display(client, 20);
}

public int MenuHandler_ZombieTutorial(Menu menu, MenuAction action, int client, int item) {
    if (action == MenuAction_End) {
        menu.Close();
    }
    return 0;
}

public Action Command_ZombieTutorial(int client, int args) {
    if (!IsClientInGame(client)) {
	return Plugin_Continue;
    }

    ShowZombieTutorial(client);
    return Plugin_Continue;
}

public Action Command_EngieTutorial(int client, int args) {
    ShowEngieTutorial(client);
    return Plugin_Continue;
}

public void ShowEngieTutorial(int client) {
    Menu menu = CreateMenu(MenuHandler_EngieTutorial);

    if (!IsClientInGame(client)) {
        return;
    }

    char title[64];
    Format(title, sizeof(title), "%t", "EngieTutorial_Menu");
    menu.SetTitle(title);

    char line1[128], line2[128], line3[128], line4[128], line5[128];

    Format(line1, sizeof(line1), "%t", "EngieTutorial_Line1");
    Format(line2, sizeof(line2), "%t", "EngieTutorial_Line2");
    Format(line3, sizeof(line3), "%t", "EngieTutorial_Line3");
	Format(line4, sizeof(line4), "%t", "EngieTutorial_Line4");
	Format(line5, sizeof(line5), "%t", "EngieTutorial_Line5");


    menu.AddItem("1", line1);
    menu.AddItem("2", line2);
    menu.AddItem("3", line3);
	menu.AddItem("4", line4);
	menu.AddItem("5", line5);

    menu.Display(client, 20);
}

public int MenuHandler_EngieTutorial(Menu menu, MenuAction action, int client, int item) {
    if (action == MenuAction_End) {
        menu.Close();
    }
    return 0;
}

// ----------------------------- Hud Timer ------------------------------------
public Action UpdateHud(Handle timer) {
    char timeText[32];
    char message[128];

    if (RemainingTime > 0) {
        FormatTime(timeText, sizeof(timeText), "%M:%S", RoundToZero(RemainingTime));

        for (int i = 1; i <= MaxClients; i++) {
            if (IsClientInGame(i) && !IsFakeClient(i)) {
                if (InPreparation) {
                    FormatEx(message, sizeof(message), "%T: %s", "hud_preparation", i, timeText);
                } else {
                    FormatEx(message, sizeof(message), "%T: %s", "hud_round", i, timeText);
                }

                if (g_bShowTimeHud) {
                    SetHudTextParams(
                        g_fTimeHudX, 
                        g_fTimeHudY, 
                        1.0, 
                        g_iTimeHudColor[0], 
                        g_iTimeHudColor[1], 
                        g_iTimeHudColor[2], 
                        g_iTimeHudColor[3], 
                        0, 
                        0.0, 
                        0.0, 
                        0.0
                    );
                    ShowHudText(i, -1, message);
                }
            }
        }

        RemainingTime -= 1.0;
    } else {
        if (InPreparation) {
            InPreparation = false;
            RemainingTime = GetConVarFloat(zve_round_time);
        } else {
            CloseHandle(TimerHandle);
            TimerHandle = INVALID_HANDLE;
        }
    }

    return Plugin_Continue;
}
// ------------------------------ Metal Regen Core ------------------------------

public void StartRegenTimer()
{
    if (g_hRegenTimer != INVALID_HANDLE)
    {
        CloseHandle(g_hRegenTimer);
    }

    g_hRegenTimer = CreateTimer(GetConVarFloat(g_hMetalRegenTime), RegenMetalTimer, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

public void OnMetalRegenTimeChanged(ConVar conVar, const char[] oldValue, const char[] newValue)
{
    StartRegenTimer();
}

// Parte de scripting do DarthNinja em 'Metal Regen' adaptada para o gamemode...
public Action RegenMetalTimer(Handle timer)
{
    if (GetConVarInt(g_hMetalRegen) == 0)
    {
        return Plugin_Continue;
    }

    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && GetClientTeam(i) > 1 && TF2_GetPlayerClass(i) == TFClass_Engineer)
        {
            int iCurrentMetal = GetEntProp(i, Prop_Data, "m_iAmmo", 4, 3);
            int iMaxMetal = GetConVarInt(g_hMaxMetal);
            int iMetalToAdd = GetConVarInt(g_hMetalRegenAmount);

            int iNewMetal = iCurrentMetal + iMetalToAdd;
            if (iNewMetal > iMaxMetal)
            {
                iNewMetal = iMaxMetal;
            }

            SetEntProp(i, Prop_Data, "m_iAmmo", iNewMetal, 4, 3);
        }
    }

    return Plugin_Continue;
}
// ----------------------------- Double Jump -------------------------------

public void OnGameFrame()
{
    if (!GetConVarBool(zve_zombiedoublejump)) return;

    for (int client = 1; client <= MaxClients; client++)
    {
        if (!IsClientInGame(client) || !IsPlayerAlive(client)) continue;
        if (TF2_GetClientTeam(client) != TFTeam_Blue) continue;
        
        DoubleJump(client);
    }
}

void DoubleJump(int client)
{
    int fCurFlags = GetEntityFlags(client);
    int fCurButtons = GetClientButtons(client);
    int lastFlags = g_fLastFlags[client];
    int lastButtons = g_fLastButtons[client];

    if ((lastFlags & FL_ONGROUND) && !(fCurFlags & FL_ONGROUND) && 
        !(lastButtons & IN_JUMP) && (fCurButtons & IN_JUMP))
    {
        g_iJumps[client] = 1;
    }
    else if (fCurFlags & FL_ONGROUND)
    {
        g_iJumps[client] = 0;
    }
    else if (!(lastButtons & IN_JUMP) && (fCurButtons & IN_JUMP) && g_iJumps[client] > 0)
    {
        PerformDoubleJump(client);
    }

    g_fLastFlags[client] = fCurFlags;
    g_fLastButtons[client] = fCurButtons;
}

void PerformDoubleJump(int client)
{
    g_iJumps[client] = 0;
    float vVel[3];
    GetEntPropVector(client, Prop_Data, "m_vecVelocity", vVel);
    vVel[2] = GetConVarFloat(zve_zombiedoublejump_boost);
    TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, vVel);
}

// ----------------------------- Timers ------------------------------------
public Action reCollide(Handle timer, any client){

	if(Client_IsIngame(client) && Client_IsValid(client)){

		if(TF2_GetClientTeam(client)==TFTeam_Red){
			SetEntProp(client, Prop_Data, "m_CollisionGroup",3);
		}else if(TF2_GetClientTeam(client)==TFTeam_Blue){
			SetEntProp(client, Prop_Data, "m_CollisionGroup", 5);
		}

	}

    return Plugin_Handled;
}

public Action OpenDoors(Handle timer){

	function_sendEntitiesInput("func_door","Open");
	
    return Plugin_Handled;
}

public Action CountDownStart(Handle timer){

	CountDownHandle = CreateTimer(1.0, CountDown, _, TIMER_REPEAT);
	CountDownStartHandle = INVALID_HANDLE;
	
    return Plugin_Handled;
}

public Action SuperZombiesTimer(Handle timer){
    CPrintToChatAll("%t", "power_up");
    SuperZombies = true;

    for (int client = 1; client <= MaxClients; client++) {
        if (!IsClientInGame(client) || !IsPlayerAlive(client) || TF2_GetClientTeam(client) != TFTeam_Blue) {
            continue;
        }

        if (!IsClientConnected(client)) {
            continue;
        }

        if (IsFakeClient(client)) {
            continue;
        }

        function_MakeSuperZombie(client);

        TF2_AddCondition(client, TFCond_CritOnDamage);

        TF2_AddCondition(client, TFCond_HalloweenSpeedBoost);
		
		TF2_AddCondition(client, TFCond_SpawnOutline);
		
		TF2_AddCondition(client, TFCond_BalloonHead);
    }

    SuperZombiesTimerHandle = INVALID_HANDLE;
    return Plugin_Handled;
}


public Action CountDown(Handle timer){
    if (CountDownCounter < 3) {
        char message[] = "";
        char timeLeft[3];
        IntToString(3 - CountDownCounter, timeLeft, 3);
        StrCat(message, sizeof(message) + 3, timeLeft);
        CPrintToChatAll(message);
        CountDownCounter++;
        return Plugin_Continue;
    } else {
        CountDownCounter = 0;
        CountDownHandle = INVALID_HANDLE;
        return Plugin_Stop;
    }
}


public Action ExtraCountDown(Handle timer) {
    char extraMessage[] = "{white}A {red}Infecção {white}começara daqui a pouco...";
    CPrintToChatAll(extraMessage);
    return Plugin_Stop;
}

public Action Infection(Handle timer){
	function_SelectFirstZombies();

	CPrintToChatAll("%t", "infection_unleashed");
	ServerCommand("sm_cvar tf_boost_drain_time 999");
	InfectionStarted = true;
	function_sendEntitiesInput("func_regenerate", "Disable");
	InfectionHandle = INVALID_HANDLE;
	
	return Plugin_Handled;

}

public Action RedWon(Handle timer){
	function_teamWin(TFTeam_Red)
	RedWonHandle=INVALID_HANDLE;
    return Plugin_Handled;
}

// ----------------------------- Functions ------------------------------------
public function_sendEntitiesInput(const char[] entityname, const char[] input){

	int x = -1
	int EntIndex;
	bool HasFound = true;

	while(HasFound) {

		EntIndex = FindEntityByClassname (x, entityname); //finds doors

		if(EntIndex==-1) {//breaks the loop if no matching entity has been found

			HasFound=false;

		}else{

			if (IsValidEntity(EntIndex)) {

				AcceptEntityInput(EntIndex, input); //Deletes the door it.
				x = EntIndex;
			}
		}
	}
}


public void function_AllEngineers(){
	//loop from smlib
	for (new client=1; client <= MaxClients; client++) {

		if (!IsClientConnected(client)) {
			continue;
		}

		if (!IsClientInGame(client)) {
			continue;
		}
		
		if (IsFakeClient(client)) {
			continue;
		}

		function_SafeTeamChange(client,TFTeam_Red);
		TF2_RespawnPlayer(client);

	}

}

public void function_StripToMelee(int client){
	if(Client_IsValid(client) && Client_IsIngame(client)){

		TF2_AddCondition(client, view_as<TFCond>(85), TFCondDuration_Infinite, 0);
		TF2_AddCondition(client, view_as<TFCond>(41), TFCondDuration_Infinite, 0);
		TF2_RemoveCondition(client, view_as<TFCond>(85) );
		TF2_RemoveWeaponSlot(client, TFWeaponSlot_Primary);
		TF2_RemoveWeaponSlot(client, TFWeaponSlot_Secondary);


	}


}

public void function_MakeSuperZombie(int client){

}

public void function_SafeTeamChange(int client, TFTeam team){

    if (IsClientReplay(client)) {
        return;
    }

	if(IsValidEntity(client) && IsClientInGame(client)) {

		int EntProp = GetEntProp(client, Prop_Send, "m_lifeState");
		SetEntProp(client, Prop_Send, "m_lifeState", 2);
		ChangeClientTeam(client, view_as<int>(team) );
		SetEntProp(client, Prop_Send, "m_lifeState", EntProp);


	}
}
public void function_SafeRespawn(int client){
	if(IsValidEntity(client) && IsClientInGame(client)) {

		int EntProp = GetEntProp(client, Prop_Send, "m_lifeState");
		SetEntProp(client, Prop_Send, "m_lifeState", 2);
		TF2_RespawnPlayer(client);
		SetEntProp(client, Prop_Send, "m_lifeState", EntProp);


	}


}

public void function_CheckVictory(){
	/*PrintToServer("Checking victory conditions...");
	if(!InfectionStarted){
		PrintToServer("The infection hasn't started, no one can win yet !");
		return;
	}
	bool AllEngineersDead = true;
	bool AllMedicsDead = true;
	bool NoPlayer = true;
	for (new client=1; client <= MaxClients; client++) {

		if( !(IsClientConnected(client) && IsClientInGame(client) ) ){
			continue;
		}

		if(NoPlayer){
			PrintToServer("One player is in the game...");
		}
		NoPlayer = false;


		TFTeam team = TF2_GetClientTeam(client);

		if(team==TFTeam_Blue){
			AllMedicsDead = false;
		}else if(team==TFTeam_Blue){
			AllEngineersDead = false;
		}

	}

	if(NoPlayer){
		PrintToServer("No player has been found, aborting...");
		return;
	}

	if(InfectionStarted){
		if(AllMedicsDead){
			PrintToServer("Red team has won !");
			function_teamWin(TFTeam_Red);
			return;
		}

		if(AllEngineersDead){
			PrintToServer("Blue team has won !");
			function_teamWin(TFTeam_Blue);

		}

	}*/

	if(InfectionStarted==false) {
		return;
	}
	bool AllEngineersDead = true;
	bool AllMedicsDead = true;
	//loop from smlib
	for (new client=1; client <= MaxClients; client++) {

		if (!IsClientConnected(client)) {
			continue;
		}

		if (!IsClientInGame(client)) {
			continue;
		}



		TFTeam team = TF2_GetClientTeam(client);

		if(team==TFTeam_Blue){
			AllMedicsDead = false;

		}else if(team==TFTeam_Red){
			AllEngineersDead = false;
		}

	}

	if(AllEngineersDead && AllMedicsDead){
		PrintToServer("Tried to trigger victory on an empty server !");
		return;
	}

	if(InfectionStarted){

		if(AllMedicsDead){
			PrintToServer("Red team won !");
			function_teamWin(TFTeam_Red);
			return;
		}

		if(AllEngineersDead){
			PrintToServer("Blue team won !");
			function_teamWin(TFTeam_Blue);

		}

	}




}

public void function_SelectFirstZombies(){


	int PlayerCount = Client_GetCount(true,true);

	//following code will compute the needed starting blue Medics, depending on the player count.
	int StartingMedics = 0;
	if(PlayerCount > 1) { //if there is 2 or more players

		StartingMedics=1;

	}
	if(PlayerCount>5) {

		StartingMedics=2;

	}
	if(PlayerCount >10) {

		StartingMedics=3;

	}
	if(PlayerCount >18) {

		StartingMedics=4;

	}

	//following code will make needed players start as medic
	while(StartingMedics>0) {
			int client = Client_GetRandom(CLIENTFILTER_INGAMEAUTH);
            if (IsClientReplay(client) || TF2_GetClientTeam(client) == TFTeam_Blue) {
            continue;
            }
			function_makeZombie(client,true);
			StartingMedics--;

	}

}
public function_PrepareMap(){

//Disabling all other game related entities
	SetVariantInt(0);
	function_sendEntitiesInput("filter_activator_tfteam", "Kill");
	function_sendEntitiesInput("trigger_capture_area","SetTeam");
	function_sendEntitiesInput("trigger_capture_area","Disable");
	function_sendEntitiesInput("item_teamflag","Disable");
	function_sendEntitiesInput("func_respawnroomvisualizer","Disable");
	function_sendEntitiesInput("trigger_teleport","Enable");
	function_sendEntitiesInput("func_respawnroom","Kill");
	function_sendEntitiesInput("func_nobuild", "Kill");
	function_sendEntitiesInput("func_door", "Open");
	SetVariantInt(3);




}

public void function_makeZombie(int client, bool firstInfected){
	int EntProp = GetEntProp(client, Prop_Send, "m_lifeState");
	SetEntProp(client, Prop_Send, "m_lifeState", 2);
	ChangeClientTeam(client, view_as<int>(TFTeam_Blue) );
	TF2_SetPlayerClass(client, TFClass_Medic, true, true);
	SetEntProp(client, Prop_Send, "m_lifeState", EntProp);
	TF2_RegeneratePlayer(client);
	function_StripToMelee(client);
				
	SetEntProp(client, Prop_Send, "m_iHealth", ZombieHealth);
	SetEntProp(client, Prop_Data, "m_iHealth", ZombieHealth);
	CreateTimer(3.5,reCollide,client);

	float clientPos[3];
	GetEntPropVector(client, Prop_Send, "m_vecOrigin", clientPos);
	Explode(clientPos, 0.0, 500.0, "merasmus_bomb_explosion_blast", "vo/medic_medic03.mp3");
	if(firstInfected){
		TF2_AddCondition(client, view_as<TFCond>(29), 40.0);
		TF2_AddCondition(client, view_as<TFCond>(5), 15.0);
		TF2_StunPlayer(client, 15.0, 0.0, TF_STUNFLAGS_BIGBONK, 0);
		SetEntProp(client, Prop_Send, "m_iHealth", ZombieHealth+500);
		SetEntProp(client, Prop_Data, "m_iHealth", ZombieHealth+500);
	}
	
    if (!isZombie[client]) { 
        CPrintToChat(client, "%t", "infected");
        ShowZombieTutorial(client);
        isZombie[client] = true;
    }
}
//code found in snippets section of the forum
public void Explode(float flPos[3], float flDamage, float flRadius, const char[] strParticle, const char[] strSound)
{
    int iBomb = CreateEntityByName("tf_generic_bomb");
    DispatchKeyValueVector(iBomb, "origin", flPos);
    DispatchKeyValueFloat(iBomb, "damage", flDamage);
    DispatchKeyValueFloat(iBomb, "radius", flRadius);
    DispatchKeyValue(iBomb, "health", "1");
    DispatchKeyValue(iBomb, "explode_particle", strParticle);
    DispatchKeyValue(iBomb, "sound", strSound);
    DispatchSpawn(iBomb);

    AcceptEntityInput(iBomb, "Detonate");
}
public void function_teamWin(TFTeam team) //modified version of code in smlib
{
    for (int i = 1; i <= MaxClients; i++) {
        if (IsClientInGame(i) && !IsFakeClient(i)) {
            TF2_RegeneratePlayer(i);
        }
    }
	
	InfectionStarted = false;
	new game_round_win = FindEntityByClassname(-1, "game_round_win");

	if (game_round_win == -1) {
		game_round_win = CreateEntityByName("game_round_win");

		if (game_round_win == -1) {
			ThrowError("Unable to find or create entity \"game_round_win\"");
		}
	}

	SetEntProp(game_round_win, Prop_Data,"m_bForceMapReset",1);
	SetEntProp(game_round_win, Prop_Data,"m_bSwitchTeamsOnWin",0);

	SetVariantInt(view_as<int>(team));
	AcceptEntityInput(game_round_win, "SetTeam");
	AcceptEntityInput(game_round_win, "RoundWin");
}

public OnPluginEnd()
{
    if (g_hRegenTimer != INVALID_HANDLE)
    {
        CloseHandle(g_hRegenTimer);
    }
	
    PrintToServer("Unloading Engineer VS Medics...");
	ServerCommand("sm_gravity @all 1");
	ServerCommand("sm_cvar tf_boost_drain_time 15.0");
	
	CPrintToChatAll("%t", "unload_plugin");
	Stalemate();
}