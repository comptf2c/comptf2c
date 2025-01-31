
#include <sourcemod>

#pragma semicolon 1
#pragma newdecls required

public Plugin myinfo =
{
	name = "Ready Up",
	author = "Jaws",
	description = "Ends tournament mode when all players are ready",
	version = "1.0",
	url = ""
};

bool g_ReadyAllowed = false;	// True if RTV is available to players. Used to delay rtv votes.
int g_Players = 0;				// Total voters connected. Doesn't include fake clients.
int g_Readied = 0;				// Total number of "say rtv" votes
bool g_Ready[MAXPLAYERS+1] = {false, ...};

static ConVar s_ConVar_Restart;

public void OnPluginStart()
{
	LoadTranslations("common.phrases");

	RegConsoleCmd("sm_ready", Command_Ready);
	RegConsoleCmd("sm_unready", Command_Unready);

	s_ConVar_Restart = FindConVar("mp_restartgame_immediate");

	HookEvent("player_team", event_PlayerTeam_Pre, EventHookMode_Pre);

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
	g_ReadyAllowed = false;
	g_Players = 0;
	g_Readied = 0;
}

public void OnConfigsExecuted()
{
	CreateTimer(15.0, Timer_DelayReady, _, TIMER_FLAG_NO_MAPCHANGE);
}

static Action event_PlayerTeam_Pre(Event event, const char[] name, bool dontBroadcast) {
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(IsFakeClient(client))
	{
        return Plugin_Continue;
	}
	int team = event.GetInt("team");
	int oldTeam = event.GetInt("oldteam");
	if(team != oldTeam)
	{
		if (g_Ready[client])
		{
			g_Readied--;
			g_Ready[client] = false;
			if(g_ReadyAllowed)
			{
                PrintToChatAll("[SM] %N is no longer ready [%i/%i]", client, g_Readied, g_Players);
			}
		}
		if (team == 1 && oldTeam > 1)
		{
			g_Players--;
			if (g_Readied >= g_Players && g_Players > 0)
            {
                StartGame();
            }
		}
		else if(team > 1 && oldTeam <= 1)
		{
			g_Players++;
		}
		PrintToServer("players: %i, ready: %i", g_Players, g_Readied);
	}

	return Plugin_Handled;
}

public void OnClientDisconnect(int client)
{
    if(!IsFakeClient(client) && GetClientTeam(client) > 1)
    {
        g_Players--;
    }

    if (g_Ready[client])
    {
        g_Readied--;
        g_Ready[client] = false;
    }

    if (g_Readied >= g_Players && g_Players > 0)
	{
		StartGame();
	}
}


public Action Command_Ready(int client, int args)
{
	if (!client)
	{
		return Plugin_Handled;
	}

	AttemptReady(client);

	return Plugin_Handled;
}

public Action Command_Unready(int client, int args)
{
	if (!client)
	{
		return Plugin_Handled;
	}

	AttemptUnready(client);

	return Plugin_Handled;
}

void AttemptReady(int client)
{

	if (!g_ReadyAllowed)
	{
		ReplyToCommand(client, "[SM] Command not available at this time");
		return;
	}

	if(GetClientTeam(client) <= 1)
	{
		ReplyToCommand(client, "[SM] Only players on teams can ready up");
		return;
	}

	if (g_Ready[client])
	{
		ReplyToCommand(client, "[SM] Already readied up! [%i/%i] (use 'unready' to undo)", g_Readied, g_Players);
		return;
	}

	g_Readied++;
	g_Ready[client] = true;

	PrintToChatAll("[SM] %N is ready to go! [%i/%i]", client, g_Readied, g_Players);

	if (g_Readied >= g_Players && g_Players > 0)
	{
		StartGame();
	}
}

void AttemptUnready(int client)
{

	if (!g_ReadyAllowed)
	{
		ReplyToCommand(client, "[SM] Command not available at this time");
		return;
	}

	if(GetClientTeam(client) <= 1)
	{
		ReplyToCommand(client, "[SM] Only players on teams can ready up");
		return;
	}

	if (!g_Ready[client])
	{
		ReplyToCommand(client, "[SM] You haven't readied up yet");
		return;
	}

	g_Readied--;
	g_Ready[client] = false;

	PrintToChatAll("[SM] %N is no longer ready [%i/%i]", client, g_Readied, g_Players);

}

public Action Timer_DelayReady(Handle timer)
{
	g_ReadyAllowed = true;

	return Plugin_Continue;
}

void StartGame()
{
	PrintToChatAll("[SM] All players ready! Starting the round");
	g_ReadyAllowed = false;
	s_ConVar_Restart.BoolValue = true;
}
