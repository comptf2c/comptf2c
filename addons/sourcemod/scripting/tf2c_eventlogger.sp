#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <tf2_stocks>

#define PLUGIN_VERSION "1.0.0"

public Plugin myinfo =
{
    name = "TF2C Event Logger",
    author = "Xinayder",
    description = "adds TF2C related events to the event log",
    version = PLUGIN_VERSION,
    url = "https://github.com/Xinayder/comptf2c/"
}

public void OnPluginStart()
{
    HookEvent("vip_boost", Event_VipBoost);
    HookEvent("vip_death", Event_VipDeath);
    HookEvent("vip_assigned", Event_VipAssigned);
}

public Action Event_VipBoost(Event event, const char[] name, bool dontBroadcast)
{
    char vipName[128];
    char vipSteamId[64];
    char vipTeam[64];

    char targetName[128];
    char targetSteamId[64];
    char targetTeam[64];

    int vipId = GetClientOfUserId(event.GetInt("provider"));
    int targetId = GetClientOfUserId(event.GetInt("target"));
    int condition = event.GetInt("condition");

    // Get VIP steam ID and display name
    GetClientAuthId(vipId, AuthId_Engine, vipSteamId, sizeof(vipSteamId));
    GetClientName(vipId, vipName, sizeof(vipName));
    GetTeamName(GetClientTeam(vipId), vipTeam, sizeof(vipTeam));

    // Get target steam ID and display name
    GetClientAuthId(targetId, AuthId_Engine, targetSteamId, sizeof(targetSteamId));
    GetClientName(targetId, targetName, sizeof(targetName));
    GetTeamName(GetClientTeam(targetId), targetTeam, sizeof(targetTeam));


    LogToGame("\"%s<%d><%s><%s>\" triggered \"vip_boost\" against \"%s<%d><%s><%s>\" (condition \"%d\")",
        vipName,
        vipId,
        vipSteamId,
        vipTeam,
        targetName,
        targetId,
        targetSteamId,
        targetTeam,
        condition
    );

    return Plugin_Continue;
}

public Action Event_VipAssigned(Event event, const char[] name, bool dontBroadcast)
{
    char vipName[128];
    char vipSteamId[64];
    char vipTeam[64];

    int vipId = GetClientOfUserId(event.GetInt("userid"));
    int vipTeamId = event.GetInt("team");

    // Get VIP steam ID and display name
    GetClientAuthId(vipId, AuthId_Engine, vipSteamId, sizeof(vipSteamId));
    GetClientName(vipId, vipName, sizeof(vipName));
    GetTeamName(vipTeamId, vipTeam, sizeof(vipTeam));


    LogToGame("Team %s has assigned \"%s<%d><%s><%s>\" as the VIP",
        vipTeam,
        vipName,
        vipId,
        vipSteamId,
        vipTeam
    );

    return Plugin_Continue;
}

public Action Event_VipDeath(Event event, const char[] name, bool dontBroadcast)
{
    char vipName[128];
    char vipSteamId[64];
    char vipTeam[64];

    char attackerName[128];
    char attackerSteamId[64];
    char attackerTeam[64];

    char assisterName[128];
    char assisterSteamId[64];
    char assisterTeam[64];

    int vipId = event.GetInt("victim"); // victim entity id
    int assister = event.GetInt("assister");
    int attackerId = GetClientOfUserId(event.GetInt("userid"));
    int headshot = event.GetInt("headshot");

    // Get VIP steam ID and display name
    GetClientAuthId(vipId, AuthId_Engine, vipSteamId, sizeof(vipSteamId));
    GetClientName(vipId, vipName, sizeof(vipName));
    GetTeamName(GetClientTeam(vipId), vipTeam, sizeof(vipTeam));

    // Get attacker steam ID and display name
    GetClientAuthId(attackerId, AuthId_Engine, attackerSteamId, sizeof(attackerSteamId));
    GetClientName(attackerId, attackerName, sizeof(attackerName));
    GetTeamName(GetClientTeam(attackerId), attackerTeam, sizeof(attackerTeam));

    char assisterString[320];
    if (assister != 0)
    {
        int assisterId = assister;
        GetClientAuthId(assisterId, AuthId_Engine, assisterSteamId, sizeof(assisterSteamId));
        GetClientName(assisterId, assisterName, sizeof(assisterName));
        GetTeamName(GetClientTeam(assisterId), assisterTeam, sizeof(assisterTeam));

        FormatEx(assisterString,
            sizeof(assisterString),
            "(assister \"%s<%d><%s><%s>\") ",
            assisterName,
            assisterId,
            assisterSteamId,
            assisterTeam
        );
    }

    LogToGame("\"%s<%d><%s><%s>\" triggered \"vip_death\" against \"%s<%d><%s><%s>\" %s(headshot %d)",
        vipName,
        vipId,
        vipSteamId,
        vipTeam,
        attackerName,
        attackerId,
        attackerSteamId,
        attackerTeam,
        assisterString,
        headshot
    );

    return Plugin_Continue;
}
