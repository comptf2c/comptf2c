#include <sourcemod>
#include <tf2c>
#include <sdktools>

#pragma semicolon 1
#pragma newdecls required

public Plugin myinfo =
{
	name = "Classic Competitive",
	author = "Jaws",
	description = "Some tweaks to TF2 Classic to facilitate competitive play",
	version = "1.1",
	url = ""
};

//---------------------------------------------GLOBALS---------------------------------------------

bool g_ReadyAllowed = false;	// True if ready is available to players.
int g_Players = 0;				// Total voters connected. Doesn't include fake clients.
int g_Readied = 0;				// Total number of "say rtv" votes
bool g_Ready[MAXPLAYERS+1] = {false, ...};
int g_Vips[4] = {0,...};
bool g_GameInProgress = false;
bool g_FirstRound = true;
bool g_AllowMaptimeReset;
bool g_PlayerTeam_Suppress = false;

Handle g_GameStartTimer;
Handle g_GameConf;

Address m_bResetTeamScores;
Address m_bResetPlayerScores;
Address m_bResetRoundsPlayed;

//---------------------------------------------CONVARS---------------------------------------------

static ConVar s_ConVar_Restart;
static ConVar s_ConVar_MaptimeReset;

//---------------------------------------------BUILT-IN FUNCTIONS---------------------------------------------

public void OnPluginStart()
{
	RegConsoleCmd("sm_ready", Command_Ready);
	RegConsoleCmd("sm_unready", Command_Unready);
	RegConsoleCmd("sm_unclass", Command_Unclass);

	s_ConVar_Restart = FindConVar("mp_restartgame");
	s_ConVar_MaptimeReset = FindConVar("tf2c_allow_maptime_reset");

	HookEvent("player_team", event_PlayerTeam_Pre, EventHookMode_Pre);
	HookEvent("player_changeclass", event_Player_ChangeClass_Pre, EventHookMode_Pre);
	HookEvent("teamplay_round_win", event_Round_Win_Post, EventHookMode_Post);
	HookEvent("teamplay_round_start", event_Round_Start_Post, EventHookMode_Post);

	g_GameConf = LoadGameConfigFile("classiccompetitive");

	OnMapEnd();

	/* Handle late load */
	for (int i=1; i<=MaxClients; i++)
	{
		if (IsClientConnected(i))
		{
			if(GetClientTeam(i) > 1)
			{
				g_Players++;
			}
		}
	}
}

public void OnMapEnd()
{
	g_GameInProgress = false;
	g_FirstRound = true;
	g_ReadyAllowed = false;
	g_Players = 0;
	g_Readied = 0;
	g_Vips = {0, 0, 0, 0};
}

public void OnConfigsExecuted()
{
	CreateTimer(15.0, Timer_DelayReady, _, TIMER_FLAG_NO_MAPCHANGE);
	g_AllowMaptimeReset = s_ConVar_MaptimeReset.BoolValue;
	Address pGameRules = GameConfGetAddress(g_GameConf, "GameRules");
	m_bResetTeamScores = pGameRules + view_as<Address>(593);
	m_bResetPlayerScores = pGameRules + view_as<Address>(594);
	m_bResetRoundsPlayed = pGameRules + view_as<Address>(595);
}

public void OnClientDisconnect(int client)
{
    if(!IsFakeClient(client) && GetClientTeam(client) > 1)
    {
        g_Players--;
    }

    int team = GetClientTeam(client);
    if(team > 1 && g_Vips[team - 2] == client)
    {
		SetTeamVIP(team, 0);
    }

    if (g_Ready[client])
	{
		UnreadyClient(client);
	}
}

//---------------------------------------------HOOK FUNCTIONS---------------------------------------------

public Action event_Player_ChangeClass_Pre(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	TFClassType class = view_as<TFClassType>(event.GetInt("class"));
	TFClassType oldClass = TF2_GetPlayerClass(client);
	int team = GetClientTeam(client);
	if(class != oldClass)
	{
		if (g_Ready[client])
		{
			UnreadyClient(client);
		}
	}
	if(team > 1)
	{
		if(class == TFClass_Civilian)
		{
			if (g_Vips[team-2] != 0 && g_Vips[team-2] != client)
			{
				if(!IsFakeClient(client))
				{
					PrintToChat(client, "Failed to become VIP, taken by %N", g_Vips[team-2]);
				}
				if(oldClass != TFClass_Civilian)
				{
					TF2_SetPlayerClass(client, oldClass, false, true);
				}
				else
				{
					TF2_SetPlayerClass(client, TFClass_Unknown, false, true);
				}
				return Plugin_Continue;
			}
			if(IsTeamEscorting(team))
			{
				SetTeamVIP(team, client);
			}
			else
			{
				SetEntProp(client, Prop_Send, "m_iObserverMode", 5);
				TF2_SetPlayerClass(client, TFClass_Unknown, false, true);
				if (IsPlayerAlive(client))
				{
					// Hack to prevent the player from suiciding when they change teams.
					SetEntProp(client, Prop_Send, "m_lifeState", 2);
				}
				g_PlayerTeam_Suppress = true;
				ChangeClientTeam(client, 1);
				ChangeClientTeam(client, team);
				g_PlayerTeam_Suppress = false;
				g_Vips[team - 2] = client;
			}
		}
		else
		{
			if(g_Vips[team - 2] == client)
			{
				SetTeamVIP(team, 0);
			}
		}
	}
	return Plugin_Continue;
}

public Action event_PlayerTeam_Pre(Event event, const char[] name, bool dontBroadcast) {
	if(g_PlayerTeam_Suppress)
	{
		event.SetBool("silent", true);
		return Plugin_Continue;
	}
	if(!event.GetBool("disconnect"))
	{
		int client = GetClientOfUserId(event.GetInt("userid"));
		int team = event.GetInt("team");
		int oldTeam = event.GetInt("oldteam");
		if(team != oldTeam)
		{
			bool fromSpec = (oldTeam <= 1);
			bool toSpec = (team <= 1);
			if(event.GetBool("silent"))
			{
				if(!fromSpec && g_Vips[oldTeam - 2] == client)
				{
					g_Vips[oldTeam - 2] = 0;
					if(!toSpec)
					{
						if(IsTeamEscorting(team))
						{
							TF2_SetPlayerClass(client, TFClass_Civilian, false, true);
							SetTeamVIP(team, client);
						}
						else
						{
							SetEntProp(client, Prop_Send, "m_iObserverMode", 5);
							TF2_SetPlayerClass(client, TFClass_Unknown, false, true);
							if (IsPlayerAlive(client))
							{
								SetEntProp(client, Prop_Send, "m_lifeState", 2);
							}
							g_PlayerTeam_Suppress = true;
							ChangeClientTeam(client, 1);
							ChangeClientTeam(client, team);
							g_PlayerTeam_Suppress = false;
							g_Vips[team - 2] = client;
						}
					}
				}
			}
			else
			{
				TF2_SetPlayerClass(client, TFClass_Unknown, false, true);
				if (g_Ready[client])
				{
					UnreadyClient(client);
				}
				if(!fromSpec && g_Vips[oldTeam - 2] == client)
				{
					SetTeamVIP(oldTeam, 0);
				}
			}
			if(!IsFakeClient(client))
			{
				if(toSpec && !fromSpec)
				{
					g_Players--;
				}
				else if (fromSpec && !toSpec)
				{
					g_Players++;
				}
			}
		}
	}

	return Plugin_Continue;
}

public Action event_Round_Start_Post(Event event, const char[] name, bool dontBroadcast)
{
	s_ConVar_MaptimeReset.BoolValue = g_AllowMaptimeReset;
	for(int i = 0; i < GetPlayTeamCount(); i++)
	{
		if(g_Vips[i] != 0)
		{
			if(IsTeamEscorting(i + 2))
			{
				TF2_SetPlayerClass(g_Vips[i], TFClass_Civilian, false, true);
				SetTeamVIP(i+2, g_Vips[i]);
			}
		}
	}
	if(!g_GameInProgress)
	{
		ServerCommand("mp_tournament_restart");
		bool result = AttemptStartGame();
		if(!result)
		{
			if(g_FirstRound)
			{
				PrintToChatAll("[SM] Round will start when players are ready");
			}
			else
			{
				PrintToChatAll("[SM] Game paused. Round will start when players are ready");
			}
		}
	}
	return Plugin_Continue;
}

public Action event_Round_Win_Post(Event event, const char[] name, bool dontBroadcast)
{
	g_GameInProgress = false;
	g_FirstRound = false;
	return Plugin_Continue;
}

//---------------------------------------------COMMAND FUNCTIONS---------------------------------------------

public Action Command_Unclass(int client, int args)
{
	int team = GetClientTeam(client);
	TF2_SetPlayerClass(client, TFClass_Unknown, false, true);
	if (IsPlayerAlive(client))
	{
		// Hack to prevent the player from suiciding when they change teams.
		SetEntProp(client, Prop_Send, "m_lifeState", 2);
	}
	SetEntProp(client, Prop_Send, "m_iObserverMode", 5);
	g_PlayerTeam_Suppress = true;
	ChangeClientTeam(client, 1);
	ChangeClientTeam(client, team);
	g_PlayerTeam_Suppress = false;
	ClientCommand(client, "changeclass");

	if (g_Ready[client])
	{
		UnreadyClient(client);
	}
	if(team > 1 && g_Vips[team - 2] == client)
	{
		SetTeamVIP(team, 0);
	}

	return Plugin_Handled;
}

public Action Command_Ready(int client, int args)
{
	if (!client)
	{
		return Plugin_Handled;
	}

	if (!g_ReadyAllowed)
	{
		ReplyToCommand(client, "[SM] Command not available at this time");
		return Plugin_Handled;
	}

	if(GetClientTeam(client) <= 1)
	{
		ReplyToCommand(client, "[SM] Only players on teams can ready up");
		return Plugin_Handled;
	}

	if (g_Ready[client])
	{
		ReplyToCommand(client, "[SM] Already readied up! [%i/%i] (use 'unready' to undo)", g_Readied, g_Players);
		return Plugin_Handled;
	}

	ReadyClient(client);

	return Plugin_Handled;
}

public Action Command_Unready(int client, int args)
{
	if (!client)
	{
		return Plugin_Handled;
	}

	if (!g_ReadyAllowed)
	{
		ReplyToCommand(client, "[SM] Command not available at this time");
		return Plugin_Handled;
	}

	if(GetClientTeam(client) <= 1)
	{
		ReplyToCommand(client, "[SM] Only players on teams can ready up");
		return Plugin_Handled;
	}

	if (!g_Ready[client])
	{
		ReplyToCommand(client, "[SM] You haven't readied up yet");
		return Plugin_Handled;
	}

	UnreadyClient(client);

	return Plugin_Handled;
}

//---------------------------------------------TIMER FUNCTIONS-------------------------------------------------------

public Action Timer_StartGame(Handle timer)
{
	if(g_FirstRound)
	{
		RestartGame();
	}
	else
	{
		ContinueGame();
	}
	g_GameStartTimer = INVALID_HANDLE;
	return Plugin_Continue;
}

public Action Timer_DelayReady(Handle timer)
{
	g_ReadyAllowed = true;

	return Plugin_Continue;
}

//---------------------------------------------PLUGIN FUNCTIONS---------------------------------------------

/**
 * @return true if the game is in the setup phase.
 */
bool IsInSetup() {
	return GameRules_GetProp("m_bInSetup") ? true : false;
}

/**
 * @return the number of playable teams.
 */
int GetPlayTeamCount() {
	return GameRules_GetProp("m_bFourTeamMode") ? 4 : 2;
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

void SetTeamVIP(int team, int client) {
	SetEntProp(GetTeamEntity(team), Prop_Send, "m_iVIP", client);
	if(client == g_Vips[team-2])
	{
		return;
	}
	g_Vips[team-2] = client;
	if(client == 0)
	{
		switch(team)
		{
			case 2:
			{
				PrintToChatAll("RED no longer have a VIP");
			}
			case 3:
			{
				PrintToChatAll("BLU no longer have a VIP");
			}
			case 4:
			{
				PrintToChatAll("GRN no longer have a VIP");
			}
			case 5:
			{
				PrintToChatAll("YLW no longer have a VIP");
			}
		}
		return;
	}
	Event eventVipChange = CreateEvent("vip_assigned");
	eventVipChange.SetInt("userid", GetClientUserId(client));
	eventVipChange.SetInt("team", team);
	eventVipChange.Fire();
}

/**
 * Gets the VIP of the given team.
 *
 * @param team    Index of the team to get the VIP of.
 * @return        Client index of the team's VIP or 0 if none.
 */
int GetTeamVIP(int team) {
	return GetEntProp(GetTeamEntity(team), Prop_Send, "m_iVIP");
}

void ReadyClient(int client)
{
	g_Readied++;
	g_Ready[client] = true;

	PrintToChatAll("[SM] %N is ready to go! [%i/%i]", client, g_Readied, g_Players);
	AttemptStartGame();
}

void UnreadyClient(int client)
{
	g_Readied--;
	g_Ready[client] = false;

	PrintToChatAll("[SM] %N is no longer ready [%i/%i]", client, g_Readied, g_Players);
	CancelStartGame();
}

bool AttemptStartGame()
{
	if(g_GameInProgress)
	{
		return false;
	}
	if (g_Readied < g_Players || g_Players <= 0)
	{
		return false;
	}
	for(int i = 0; i < GetPlayTeamCount();i++)
	{
		if(IsTeamEscorting(i + 2))
		{
			if(GetTeamVIP(i + 2) == 0)
			{
				PrintToChatAll("[SM] All players ready but a team is missing a VIP.");
				return false;
			}
		}
	}
	PrintToChatAll("[SM] All players ready! Starting the round in 5 seconds (unready to cancel)");
	g_GameStartTimer = CreateTimer(5.0, Timer_StartGame, _, TIMER_FLAG_NO_MAPCHANGE);
	g_GameInProgress = true;
	return true;
}

void CancelStartGame()
{
	if(g_GameInProgress)
	{
		if(g_GameStartTimer != INVALID_HANDLE)
		{
			delete g_GameStartTimer;
			PrintToChatAll("[SM] Round start cancelled");
		}
		else if(IsInSetup())
		{
			PrintToChatAll("[SM] Round start cancelled during setup");
			ServerCommand("mp_tournament_restart");
		}
		else
		{
			PrintToChatAll("[SM] Game will pause after this round");
		}
		g_GameInProgress = false;
	}
}

void ContinueGame()
{
	s_ConVar_Restart.IntValue = 1;
	s_ConVar_MaptimeReset.BoolValue = false;
	StoreToAddress(m_bResetPlayerScores, 0, NumberType_Int8);
	StoreToAddress(m_bResetRoundsPlayed, 0, NumberType_Int8);
	StoreToAddress(m_bResetTeamScores, 0, NumberType_Int8);
}

void RestartGame()
{
	s_ConVar_Restart.IntValue = 1;
}
