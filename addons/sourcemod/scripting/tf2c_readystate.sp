#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <morecolors>
#include <sdktools>
#include <sdkhooks>
#include <tf2_stocks>
#include <regex>

#define PLUGIN_VERSION "1.0.0"

public Plugin myinfo =
{
    name = "TF2C Comp Fixes - Ready State",
    author = "Xinayder",
    description = "attempts to fix some broken competitive gameplay behavior on TF2C",
    version = PLUGIN_VERSION,
    url = "https://github.com/Xinayder/comptf2c"
}

#define RED 2
#define BLU 3
#define GRN 4
#define YLW 5

ConVar g_cvarTournament = null;

public void OnPluginStart()
{
    g_cvarTournament = FindConVar("mp_tournament");
    g_cvarTournament.AddChangeHook(OnTournamentCVarChanged);

    char cTournamentEnabled[1];
    g_cvarTournament.GetString(cTournamentEnabled, 1);

    if (!!StringToInt(cTournamentEnabled) == true)
    {
        // hook to team ready events
        PrintToServer("Registering event hooks because tournament mode is enabled");
        HookEvent("tournament_stateupdate", Event_TeamReady);
        HookEvent("player_team", Event_PrePlayerTeam);
    }
}

public void OnTournamentCVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
    bool newBool = !!StringToInt(newValue);

    if (newBool)
    {
        // hook to team ready events
        PrintToServer("Registering event hooks because tournament mode is enabled");
        HookEvent("tournament_stateupdate", Event_TeamReady);
        HookEvent("player_team", Event_PrePlayerTeam);
    }
    else
    {
        // unhook to team ready events
        PrintToServer("Removing event hooks because tournament mode is disabled");
        UnhookEvent("tournament_stateupdate", Event_TeamReady);
        UnhookEvent("player_team", Event_PrePlayerTeam);
    }
}

public void Event_TeamReady(Handle event, const char[] name, bool dontBroadcast)
{

    setTeamReady(GRN, true);
    setTeamReady(YLW, true);
}

// Hook into playerteam event (when a player changes teams) and trigger a tournament_stateupdate
// to reset ready states for both teams
public Action Event_PrePlayerTeam(Event event, const char[] name, bool dontBroadcast)
{
    int userId = event.GetInt("userid");

    // create a new tournament_stateupdate event
    Event tournamentEvt = CreateEvent("tournament_stateupdate", true);
    SetEventInt(tournamentEvt, "readystate", 0);
    SetEventInt(tournamentEvt, "userid", 0);

    // get user's client id based on his user id
    int clientId = GetClientOfUserId(userId);
    if (IsClientInGame(clientId))
    {
        SetEventInt(tournamentEvt, "userid", clientId);
    }

    // Fire a 500ms timer after player has changed teams so we can trigger the tournament state update again
    // this time, for the team the player has joined.
    CreateTimer(0.5, Timer_PlayerSwapTeam, clientId);


    MC_PrintToChatAll("Resetting {red}RED{default} and {blue}BLU{default} team states to {olive}NOT READY{default}: player team change");
    
    // fire the tournament_stateupdate event
    tournamentEvt.Fire();

    return Plugin_Continue;
}

public Action Timer_PlayerSwapTeam(Handle timer, int clientId)
{
    // check if client is in game before creating and sending the new event
    if (clientId && IsClientInGame(clientId))
    {
        Event event = CreateEvent("tournament_stateupdate", true);
        SetEventInt(event, "readystate", 0);
        SetEventInt(event, "userid", clientId);
        event.Fire();

    }

    return Plugin_Continue;
}

void setTeamReady(int teamNumber, bool readyState)
{
    GameRules_SetProp("m_bTeamReady", readyState, 1, teamNumber);
}
