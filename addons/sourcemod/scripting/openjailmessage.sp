#include <sdktools>
#include <sdkhooks>
#include <sourcemod>
#include <multicolors>
#include <myjailbreak>
#include <smartjaildoors>
#include <openjailmessage>
#include <emitsoundany>

#define MAX_BUTTONS 5
//#define DEBUG

enum struct Entities
{
	char entity_name[100];
	int entity_id;
}

Entities g_ButtonEntities[MAX_BUTTONS];
int g_iButtonEntitiesSize = 0;

bool g_bJailAlreadyOpen;

int g_iClientOpened = -1;

char g_sFilePath[PLATFORM_MAX_PATH];

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

	BuildPath(Path_SM, g_sFilePath, sizeof(g_sFilePath), "logs/openjailmessage.txt");

	g_bJailAlreadyOpen = false;
	g_iClientOpened = -1;
}


public void OnMapStart()
{
	g_iButtonEntitiesSize = 0;

	AddFileToDownloadsTable("sound/ptrunners/openjail/freeday.mp3");
	AddFileToDownloadsTable("sound/ptrunners/openjail/freeday2.mp3");
//	AddFileToDownloadsTable("sound/ptrunners/openjail/opencells.mp3");
	PrecacheSoundAny("ptrunners/openjail/freeday.mp3");
	PrecacheSoundAny("ptrunners/openjail/freeday2.mp3");
//	PrecacheSoundAny("ptrunners/openjail/opencells.mp3");

	char mapName[128];
	GetCurrentMap(mapName, sizeof(mapName));

	char file[256];
	BuildPath(Path_SM, file, sizeof(file), "configs/openjailmessage.cfg");

	Handle kv = CreateKeyValues("OpenJailMessage");
	FileToKeyValues(kv, file);

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

	KvGetString(kv, "entity_id", buffer, 20);
	g_ButtonEntities[g_iButtonEntitiesSize].entity_id = !StrEqual(buffer, "") ? StringToInt(buffer) : -1;

	#if defined DEBUG
	LogToFileEx(g_sFilePath, "Entity Name: %s | Entity ID: %i", g_ButtonEntities[g_iButtonEntitiesSize].entity_name, g_ButtonEntities[g_iButtonEntitiesSize].entity_id);
	#endif

	g_iButtonEntitiesSize++;
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

bool CheckButtonValidByConfig(int caller, const char[] entityName)
{
	for(int i = 0; i < g_iButtonEntitiesSize; i++)
	{
		if(
			(g_ButtonEntities[i].entity_id != -1 && caller == g_ButtonEntities[i].entity_id) ||
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
	if (GetClientTeam(activator) == 2)
	{
		CPrintToChatAll("> {default}O prisioneiro {darkred}%N {default}abriu as celas. É {orange}FreeDay{default}.", activator);

		new randomint = GetRandomInt(1, 2);
		if (randomint == 1)
		{
			EmitSoundToAllAny("ptrunners/openjail/freeday.mp3");
		}
		if (randomint == 2)
		{
			EmitSoundToAllAny("ptrunners/openjail/freeday2.mp3");
		}
	}
	else
	{
		CPrintToChatAll("> {default}O guarda {darkblue}%N {default}abriu as celas.", activator);
	}
}

stock bool IsValidClient(int client) 
{ 
    if ( !( 1 <= client <= MaxClients ) || !IsClientInGame(client) || !IsPlayerAlive(client) ) 
        return false; 
     
    return true; 
}
