#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>
#include <multicolors>
#include <myjailbreak>
#include <smartjaildoors>
#include <openjailmessage>
#include <emitsoundany>

#define MAX_BUTTONS 5
#define MAX_SOUNDS 10
//#define DEBUG

enum struct Entities
{
	char entity_name[100];
	int entity_hammerid;
}

Entities g_ButtonEntities[MAX_BUTTONS];
int g_iButtonEntitiesSize = 0;

bool g_bJailAlreadyOpen;

int g_iClientOpened = -1;

char g_sFilePath[PLATFORM_MAX_PATH];
char g_sPathConfig[PLATFORM_MAX_PATH];
char g_sPathSound[PLATFORM_MAX_PATH];

enum struct Sound
{
	char path[PLATFORM_MAX_PATH];
	int team;
}

Sound g_Sounds[MAX_SOUNDS];
int g_iSoundsSize = 0;

Handle g_hOnOpen  = null;

public Plugin myinfo =
{
	name = "OpenJailMessage",
	author = "azalty/rlevet edited by Trayz",
	description = "Sends a message in the chat saying who opened jails",
	version = "1.0.6",
	url = "TheWalkingJail https://discord.gg/Q7b57yk"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    g_hOnOpen = CreateGlobalForward("OJM_OnJailOpened", ET_Event, Param_Cell, Param_Array);
    
    CreateNative("OJM_IsJailAlreadyOpen", Native_IsJailAlreadyOpen);
    CreateNative("OJM_GetClientJailOpen", Native_GetClientJailOpen);
    
    RegPluginLibrary("openjailmessage");
    
    return APLRes_Success;
}

public void OnPluginStart()
{
	HookEntityOutput("func_button", "OnPressed", Button_Pressed);

	HookEvent("round_prestart", OnRoundPreStart);

	LoadTranslations("openjailmessage.phrases");

	BuildPath(Path_SM, g_sFilePath, sizeof(g_sFilePath), "logs/openjailmessage.txt");

	g_bJailAlreadyOpen = false;
	g_iClientOpened = -1;
}

public void OnMapStart()
{
	BuildPath(Path_SM, g_sPathSound, sizeof(g_sPathSound), "configs/openjailmessage_sounds.cfg");
	ReadSounds();

	BuildPath(Path_SM, g_sPathConfig, sizeof(g_sPathConfig), "configs/openjailmessage.cfg");
	ReadConfig();
}

public void OnRoundPreStart(Handle event, const char[] name, bool dontBroadcast)
{
	g_iClientOpened = -1;
	if (GameRules_GetProp("m_bWarmupPeriod") == 0)
	{
		g_bJailAlreadyOpen = false;
	}
	else
	{
		g_bJailAlreadyOpen = true; //warmup
	}
}

public void MyJailbreak_OnEventDayStart(char[] EventDayName)
{
	g_bJailAlreadyOpen = true;
	g_iClientOpened = -1;
}

public void Button_Pressed(const char[] output, int caller, int activator, float delay)
{
	if(g_iButtonEntitiesSize == 0) return;

	if (!IsValidClient(activator) || !IsValidEntity(caller)) return;

	if (g_bJailAlreadyOpen) return;

	char entityName[100];
	GetEntPropString(caller, Prop_Data, "m_iName", entityName, sizeof(entityName));
	
	#if defined DEBUG

	char entityClassName[50];
	GetEdictClassname(caller, entityClassName, sizeof(entityClassName));
	LogToFileEx(g_sFilePath, "Ingame Entity Name: %s | Entity ID: %i | Entity Classname: %s", entityName, caller, entityClassName);

	#endif

	bool validButton = CheckButtonValidByConfig(caller, entityName);
	
	if(!validButton) return;

	Action res = Plugin_Continue;
	Call_StartForward(g_hOnOpen);
	Call_PushCell(activator);
	Call_Finish(res);

	if (res == Plugin_Handled || res == Plugin_Stop)
	{
		return;
	}

	g_iClientOpened = activator;

	g_bJailAlreadyOpen = true;
	
	ShowMessageToClients(activator);
}

public void SJD_ButtonPressed(int activator)
{
	if (!IsValidClient(activator)) return;
	
	if (g_bJailAlreadyOpen) return;

	Action res = Plugin_Continue;
	Call_StartForward(g_hOnOpen);
	Call_PushCell(activator);
	Call_Finish(res);

	if (res == Plugin_Handled || res == Plugin_Stop)
	{
		return;
	}

	g_iClientOpened = activator;

	g_bJailAlreadyOpen = true;
	
	ShowMessageToClients(activator);
}

public int Native_IsJailAlreadyOpen(Handle plugin, int numParams)
{
	return view_as<int>(g_bJailAlreadyOpen);
}

public int Native_GetClientJailOpen(Handle plugin, int numParams)
{
    return g_iClientOpened;
}

void ReadSounds() {
	
	char buffer[PLATFORM_MAX_PATH];
	char download[PLATFORM_MAX_PATH];
	Handle kv;

	g_iSoundsSize = 0;

	kv = CreateKeyValues("OpenJailMessageSounds");
	FileToKeyValues(kv, g_sPathSound);

	if (!KvGotoFirstSubKey(kv)) {

		SetFailState("CFG File not found: %s", g_sPathSound);
		CloseHandle(kv);
	}
	do {

		KvGetString(kv, "path", buffer, sizeof(buffer));
		
		PrecacheSoundAny(buffer);

		Format(download, sizeof(download), "sound/%s", buffer);
		AddFileToDownloadsTable(download);

		Format(g_Sounds[g_iSoundsSize].path, PLATFORM_MAX_PATH, "%s", buffer);

		g_Sounds[g_iSoundsSize].team = KvGetNum(kv, "team", 0);
		
		g_iSoundsSize++;

	} while (KvGotoNextKey(kv));

	CloseHandle(kv);
}

void ReadConfig()
{
	g_iButtonEntitiesSize = 0;

	char mapName[128];
	GetCurrentMap(mapName, sizeof(mapName));

	Handle kv = CreateKeyValues("OpenJailMessage");
	FileToKeyValues(kv, g_sPathConfig);

	if(!KvGotoFirstSubKey(kv))
	{
		return;
	}

	KvRewind(kv);

	if(!KvJumpToKey(kv, mapName))
	{
		return;
	}

	char buffer[255];

	KvGetString(kv, "entity_name", buffer, 100);
	strcopy(g_ButtonEntities[g_iButtonEntitiesSize].entity_name, 100, buffer);

	KvGetString(kv, "entity_hammerid", buffer, 20);
	g_ButtonEntities[g_iButtonEntitiesSize].entity_hammerid = !StrEqual(buffer, "") ? StringToInt(buffer) : -1;

	#if defined DEBUG
	LogToFileEx(g_sFilePath, "Entity Name: %s | Entity HammerID: %i", g_ButtonEntities[g_iButtonEntitiesSize].entity_name, g_ButtonEntities[g_iButtonEntitiesSize].entity_hammerid);
	#endif

	g_iButtonEntitiesSize++;
}

void GetRandomSound(char[] soundPath, int soundLength, int team)
{
	int maxtries = 5;

	for(int i = 0; i < maxtries; i++) {

		int randomSound = GetRandomInt(0, g_iSoundsSize-1);
		if(g_Sounds[randomSound].team == team || g_Sounds[randomSound].team == 0) {
			strcopy(soundPath, soundLength, g_Sounds[randomSound].path);
			break;
		}

	}
}

bool CheckButtonValidByConfig(int caller, const char[] entityName)
{
	int hammerId = GetEntProp(caller, Prop_Data, "m_iHammerID");

	for(int i = 0; i < g_iButtonEntitiesSize; i++)
	{
		if(
			(g_ButtonEntities[i].entity_hammerid != -1 && hammerId == g_ButtonEntities[i].entity_hammerid) ||
			(!StrEqual(g_ButtonEntities[i].entity_name, "") && StrEqual(g_ButtonEntities[i].entity_name, entityName))
		)
		{
			return true;
		}
	}

	return false;
}

void ShowMessageToClients(activator)
{
	int team = GetClientTeam(activator);

	if(team != CS_TEAM_T && team != CS_TEAM_CT)
		return;

	switch(team)
	{
		case CS_TEAM_T:
		{
			CPrintToChatAll("%t", "Prisoner opened cells", activator);
		}

		case CS_TEAM_CT:
		{
			CPrintToChatAll("%t", "Guard opened cells", activator);
		}
	}

	if(!g_iSoundsSize)
		return;

	char randomSound[PLATFORM_MAX_PATH];
	GetRandomSound(randomSound, sizeof(randomSound), team);
	EmitSoundToAllAny(randomSound, _, SNDCHAN_VOICE);
}

stock bool IsValidClient(int client) 
{ 
    if ( !( 1 <= client <= MaxClients ) || !IsClientInGame(client) || !IsPlayerAlive(client) ) 
        return false; 
     
    return true; 
}
