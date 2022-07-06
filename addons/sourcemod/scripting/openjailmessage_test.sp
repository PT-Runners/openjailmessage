#include <sourcemod>
#include <multicolors>
#include <openjailmessage>

public Plugin myinfo =
{
    name = "OpenJailMessage Teste",
    author = "Trayz",
    description = "",
    version = "1.0.0",
    url = "ptrunners.net"
};

public void OnPluginStart()
{
    RegConsoleCmd("sm_celas", Cmd_StatusCells);
}

public Action Cmd_StatusCells(int client, int args)
{
    if(OJM_IsJailAlreadyOpen())
    {
        int clientJailOpen = OJM_GetClientJailOpen();
        if(IsValidClient(clientJailOpen))
        {
            CPrintToChat(client, "{darkred}> {default}O {darkblue}%N{default} abriu as celas.", clientJailOpen);
        }
        else
        {
            CPrintToChat(client, "{darkred}> {default}As celas já estão abertas.");
        }
    }
    else
    {
        CPrintToChat(client, "{darkred}> {default}As celas ainda não estão abertas.");
    }

    return Plugin_Handled;
}

public Action OJM_OnJailOpened(int client)
{
    //PrintToChatAll("OJM_OnJailOpened: %N", client);
    return Plugin_Continue;
}

stock bool IsValidClient(int client) 
{ 
    if ( !( 1 <= client <= MaxClients ) || !IsClientInGame(client)) 
        return false; 
     
    return true; 
}