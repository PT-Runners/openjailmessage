#include <sdktools>
#include <sourcemod>
#include <multicolors>
#include <myjailbreak>

#define MAX_BUTTONS 5

enum struct Entities
{
	char entity_name[100];
	int entity_id;
}

Entities g_ButtonEntities[MAX_BUTTONS];
int g_iButtonEntitiesSize = 0;

bool g_bJailAlreadyOpen;
bool g_bIsWarmup;

public Plugin myinfo =
{
	name = "OpenJailMessage",
	author = "azalty/rlevet edited by Trayz",
	description = "Sends a message in the chat saying who opened jails",
	version = "1.0.6",
	url = "TheWalkingJail https://discord.gg/Q7b57yk"
};

public void OnPluginStart()
{
	HookEntityOutput("func_button", "OnPressed", Button_Pressed);

	HookEvent("round_start", OnRoundStart);

	g_bJailAlreadyOpen = false;
}

public void OnMapStart()
{
	g_iButtonEntitiesSize = 0;

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

	g_iButtonEntitiesSize++;
}

public void OnRoundStart(Handle event, const char[] name, bool dontBroadcast)
{
	g_bJailAlreadyOpen = false;

	if (GameRules_GetProp("m_bWarmupPeriod") == 0)
	{
		g_bIsWarmup = false;
	}
	else
	{
		g_bIsWarmup = true;
	}
}

public void Button_Pressed(const char[] output, int caller, int activator, float delay)
{
	if(g_iButtonEntitiesSize == 0)
	{
		return;
	}

	if (!IsValidClient(activator) || !IsValidEntity(caller)) return;
	
	if (g_bJailAlreadyOpen) return;
	
	char entity[512];
	GetEntPropString(caller, Prop_Data, "m_iName", entity, sizeof(entity));

	bool validButton = false;
	
	for(int i = 0; i < g_iButtonEntitiesSize; i++)
	{
		if(
			(g_ButtonEntities[i].entity_id != -1 && caller == g_ButtonEntities[i].entity_id) ||
			(!StrEqual(g_ButtonEntities[i].entity_name, "") && StrEqual(g_ButtonEntities[i].entity_name, entity))
		)
		{
			validButton = true;
			break;
		}
	}
	
	if(!validButton)
	{
		return;
	}

	g_bJailAlreadyOpen = true;
	
	if (GetClientTeam(activator) == 2)
	{
		char eventDayName[60];
		MyJailbreak_GetEventDayName(eventDayName);

		if(!MyJailbreak_IsEventDayRunning() && !g_bIsWarmup)
		{
			CPrintToChatAll("> {default}O {red}prisioneiro %N {default}abriu as celas. É {orange}FreeDay{default}.", activator);
		}
	}
	else
	{
		CPrintToChatAll("> {default}O {darkblue}guarda %N {default}abriu as celas.", activator);
	}
}

public bool IsValidClient( int client ) 
{ 
    if ( !( 1 <= client <= MaxClients ) || !IsClientInGame(client) || !IsPlayerAlive(client) ) 
        return false; 
     
    return true; 
}
