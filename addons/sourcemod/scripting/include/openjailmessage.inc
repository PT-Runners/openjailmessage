#if defined _openjailmessage_included
 #endinput
#endif
#define _openjailmessage_included

native bool OJM_IsJailAlreadyOpen();
native int OJM_GetClientJailOpen();

forward Action OJM_OnJailOpened(int client);

public SharedPlugin __pl_discord =
{
	name = "openjailmessage",
	file = "openjailmessage.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN

public __pl_discord_SetNTVOptional()
{
	MarkNativeAsOptional("OJM_IsJailAlreadyOpen");
	MarkNativeAsOptional("OJM_GetClientJailOpen");
}
#endif