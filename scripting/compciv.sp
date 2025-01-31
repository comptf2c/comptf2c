#include <sourcemod>
#include <tf2c>
#include <sdktools>

#pragma semicolon 1
#pragma newdecls required

public Plugin myinfo =
{
	name = "Competitive Civilian",
	author = "Jaws",
	description = "Makes any player who changes class to Civilian become the VIP",
	version = "1.0",
	url = ""
};


public void OnPluginStart()
{
	HookEvent("player_spawn", event_Player_Spawn_Pre, EventHookMode_Pre);
}

public Action event_Player_Spawn_Pre(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	int team = event.GetInt("team");
	TFClassType class = view_as<TFClassType>(event.GetInt("class"));
	if(class == TFClass_Civilian)
	{
		if(IsTeamEscorting(team))
		{
			SetEntProp(GetTeamEntity(team), Prop_Send, "m_iVIP", client);
		}
		else
		{
			TF2_SetPlayerClass(client, TFClass_Unknown, false, false);
			if (IsPlayerAlive(client))
			{
				// Hack to prevent the player from suiciding when they change teams.
				SetEntProp(client, Prop_Send, "m_lifeState", 2);
			}
			ChangeClientTeam(client, 1);
			ChangeClientTeam(client, team);

		}

	}
	return Plugin_Continue;
}

/**
* Check if the given team is escorting a VIP.
*
* @param team    Index of the team to check.
* @return        true if the team is escorting a VIP.
*/
bool IsTeamEscorting(int team) {
	return GetEntProp(GetTeamEntity(team), Prop_Send, "m_bEscorting") ? true : false;
}
