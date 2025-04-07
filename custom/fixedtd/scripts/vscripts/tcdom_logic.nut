////////// VARIABLES: You can tweak these! //////////

// Should points lock when capped?
local var_lockOnCap = false

// Should we force respawn on a team that loses a control point?
local var_respawnOnCap = true

// How many seconds should the timer start with?
local var_timerTimeInit = 185

// How many seconds should the timer max out at?
local var_timerTimeMax = 185

// How many seconds should capturing a point add to the timer?
local var_capTimeMod = 59

// How many seconds should the initial respawn time be?
local var_respawnTimeInit = 6

// By how many seconds should capping a point change your team's respawn time? (applied in reverse to the losing team.)
local var_respawnTimeMod = 1

// Should sudden death occur?
local var_suddenDeath = false

// How many seconds should the sudden death timer start with? (use -1 for server default.)
local var_suddenDeathTimer = 180

////////// VARIABLES: You can tweak these! //////////





////////// GLOBALS: Do not edit! //////////

// Tracks which teams are capturing which points
local global_isRedCapturingPoint = [false, false, false]
local global_isBluCapturingPoint = [false, false, false]

////////// GLOBALS: Do not edit! //////////

// Get the owner of a capture point (-1 for unowned)
function getCapOwner(cap) {
    local owner = Entities.FindByName(null, ["cap_a", "cap_b", "cap_c"][cap]).GetTeam() - 2
    if (owner == -2) {
        owner = -1
    }
    return owner
}

// Teleportation helper function
function tpFromTo(from, to) {
    local whichTrigger = [
        [null, "tp_trigger_a_b", "tp_trigger_a_c"],
        ["tp_trigger_b_a", null, "tp_trigger_b_c"],
        ["tp_trigger_c_a", "tp_trigger_c_b", null]
    ][from][to]
    if (whichTrigger) {
        EntFire(whichTrigger, "Enable", null, 0)
        EntFire(whichTrigger, "Disable", null, 0.01)
    }
}

// Respawn room teleport handler
function tpHandleOnCap(cap, team) {
    local to = -1
    for (local i = 0; i <= 2; i += 1) {
        local owner = getCapOwner(i)
        if (owner == [1, 0][team]) {
            to = i
        }
    }
    if (to != -1) {
        tpFromTo(cap, to)
    }
}

// Timer end logic
function timerEndHandle(justCaptured = false) {

    // Find current winner (represented as capSum)
    local capSum = 0
    local unownedCapExists = false
    local owner = -1
    for (local i = 0; i <= 2; i += 1) {
        owner = getCapOwner(i)
        if (owner == -1) {
            unownedCapExists = true
        } else {
            capSum += owner
        }
    }

    // Determine if overtime should happen
    local shouldOvertime = false
    if (unownedCapExists || var_suddenDeath) {
        shouldOvertime = (global_isRedCapturingPoint[0] || global_isRedCapturingPoint[1] || global_isRedCapturingPoint[2] || global_isBluCapturingPoint[0] || global_isBluCapturingPoint[1] || global_isBluCapturingPoint[2])
    } else {
        local whichTeamWinning = (capSum >= 2).tointeger()
        // Check if losing team is capping
        local isLosingTeamCapturingPoint = [global_isBluCapturingPoint, global_isRedCapturingPoint][whichTeamWinning]
        shouldOvertime = (isLosingTeamCapturingPoint[0] || isLosingTeamCapturingPoint[1] || isLosingTeamCapturingPoint[2])
    }

    // If necessary, enable overtime (otherwise, handle round win)
    if (shouldOvertime) {
        SetOvertimeAllowedForCTF(true)
    } else if (!justCaptured) {
        if (var_suddenDeath) {
            // Activate sudden death
            EntFire("tcdom_round_win_sd", "RoundWin", null, 0, activator)
        } else {
            // Declare winner
            EntFire("tcdom_wins_red", "Trigger", null, 0, activator)
            EntFire("tcdom_wins_blu", "Trigger", null, 0, activator)
            EntFire("tcdom_wins_stalemate", "Trigger", null, 0, activator)
        }
    }

}

// A player has started capturing, so adjust appropriate global
function startCapturing(cap, team) {
    [global_isRedCapturingPoint, global_isBluCapturingPoint][team][cap] = true
}

// Player capture expired, so adjust appropriate global, and trigger timer end logic if need be
function endCapturing(cap, team, justCaptured = false) {
    [global_isRedCapturingPoint, global_isBluCapturingPoint][team][cap] = false
    if (InOvertime()) {
        timerEndHandle(justCaptured)
    }
}

// Set capture point owner and manage related entity states
function setPoint(cap, team, delay = 0, capturedByPlayer = true) {

    // Disable potential overtime and handle end of capture
    SetOvertimeAllowedForCTF(false)
    endCapturing(cap, team, true)

    // Set miscellaneous single entity states
    local whichCap = ["cap_a", "cap_b", "cap_c"][cap]
    local whichCapProp = ["cap_a_prop", "cap_b_prop", "cap_c_prop"][cap]
    local whichCapRoom = ["cap_a_room", "cap_b_room", "cap_c_room"][cap]
    local whichCapRoomSign = ["cap_a_room_sign", "cap_b_room_sign", "cap_c_room_sign"][cap]
    local whichCapRoomSignCover = ["cap_a_room_sign_cover", "cap_b_room_sign_cover", "cap_c_room_sign_cover"][cap]
    local whichCapDoorBlock = ["cap_a_door_block", "cap_b_door_block", "cap_c_door_block"][cap]
    EntFire(whichCap, "SetOwner", [2, 3][team], delay, activator)
    EntFire(whichCapProp, "Skin", [1, 2][team], delay, activator)
    EntFire(whichCapRoom, "SetTeam", [2, 3][team], delay, activator)
    EntFire(whichCapRoomSign, "Skin", [5, 4][team], delay, activator)
    EntFire(whichCapRoomSignCover, "Disable", null, delay, activator)

    // Handle door blocks
    local blockDelay = delay
    if (!capturedByPlayer) {
        blockDelay = 0.5
    }
    EntFire(whichCapDoorBlock, "Open", null, blockDelay, activator)

    // Enable/disable spawns
    local whichCapSpawns = [
        ["red_spawn_a", "blu_spawn_a"],
        ["red_spawn_b", "blu_spawn_b"],
        ["red_spawn_c", "blu_spawn_c"]
    ]
    EntFire(whichCapSpawns[cap][team], "Enable", null, 0, activator)
    EntFire(whichCapSpawns[cap][[1, 0][team]], "Disable", null, 0, activator)

    // Enable/disable respawn room door triggers
    local whichCapDoorTriggers = [
        ["cap_a_door_trigger_red", "cap_a_door_trigger_blu"],
        ["cap_b_door_trigger_red", "cap_b_door_trigger_blu"],
        ["cap_c_door_trigger_red", "cap_c_door_trigger_blu"]
    ][cap]
    EntFire(whichCapDoorTriggers[team], "Enable", null, delay, activator)
    EntFire(whichCapDoorTriggers[[1, 0][team]], "Disable", null, delay, activator)

    // Adjust respawn wave time
    local whichCapWaveActions = ["AddRedTeamRespawnWaveTime", "AddBluTeamRespawnWaveTime"]
    EntFire("tcdom_gamerules", whichCapWaveActions[team], var_respawnTimeMod, delay, activator)
    EntFire("tcdom_gamerules", whichCapWaveActions[[1, 0][team]], -1 * var_respawnTimeMod, delay, activator)

    // Trigger appropriate owns relay
    local ownsRelay = [
        ["tcdom_owns_a_red", "tcdom_owns_a_blu"],
        ["tcdom_owns_b_red", "tcdom_owns_b_blu"],
        ["tcdom_owns_c_red", "tcdom_owns_c_blu"]
    ][cap][team]
    EntFire(ownsRelay, "Trigger", null, delay, activator)

    // If point captured by player, make appropriate adjustments
    if (capturedByPlayer) {

        // Add time to timer
        EntFire("tcdom_timer", "AddTime", var_capTimeMod, delay, activator)

        // Enable/disable win relays
        local whichWinRelays = ["tcdom_wins_red", "tcdom_wins_blu"]
        EntFire(whichWinRelays[team], "Enable", null, delay, activator)
        EntFire(whichWinRelays[[1, 0][team]], "Disable", null, delay, activator)
        EntFire("tcdom_wins_stalemate", "Disable", null, delay, activator)

        // Handle teleports between spawnrooms
        tpHandleOnCap(cap, team)

        // Lock/unlock point areas
        local areas = ["cap_a_area", "cap_b_area", "cap_c_area"]
        foreach(i, area in areas) {
            if ((var_lockOnCap) && (i == cap)) {
                EntFire(area, "SetTeamCanCap", "2 0", delay, null)
                EntFire(area, "SetTeamCanCap", "3 0", delay, null)
            } else {
                EntFire(area, "SetTeamCanCap", "2 1", delay, null)
                EntFire(area, "SetTeamCanCap", "3 1", delay, null)
            }
        }

        // If respawn on cap enabled, do so
        if (var_respawnOnCap) {
            local capownerA = getCapOwner(0)
            local capownerB = getCapOwner(1)
            local capownerC = getCapOwner(2)
            
            if (capownerA != capownerB || capownerA != capownerC || capownerB != capownerC) {
                EntFire("tcdom_force_respawn", "ForceTeamRespawn", [3, 2][team], delay, activator)
            }
        }

    }

    // Recalculate bot nav
    EntFire("tcdom_nav", "RecomputeBlockers", null, delay, activator)

}

// ALL remaining code is the original logic script of EMINOMA. Below function (and Line 273) is the edition of CompTF2C (by Güven).
// Defines round start spawn point logic per map
function getSeed()
{
    local mapName = GetMapName()
    if (mapName == "td_sunnyside") {
        local seed = 2 // Point A is RED, point B is uncapped, point C is BLU.
        return seed
    } else if (mapName == "td_caper") {
        local seed = 4 // Point A is RED, point B is BLU, point C is uncapped.
        return seed
    } else {
        local seed = RandomInt(0,5)
        return seed
    }
}

// Initialization logic
function randomStart() {

    // Set timer times
    EntFire("tcdom_timer", "SetTime", var_timerTimeInit, 0, activator)
    EntFire("tcdom_timer", "SetMaxTime", var_timerTimeMax, 0, activator)

    // Set respawn wave times
    EntFire("tcdom_gamerules", "SetBlueTeamRespawnWaveTime", var_respawnTimeInit, 0, activator)
    EntFire("tcdom_gamerules", "SetRedTeamRespawnWaveTime", var_respawnTimeInit, 0, activator)

    EntFire("tcdom_round_win*", "AddOutput", "switch_teams 0", 0, activator)
	EntFire("tcdom_points*", "AddOutput", "switch_teams 0", 0, activator)

    // Set point ownership, and lock owned points
    local areas = ["cap_a_area", "cap_b_area", "cap_c_area"]
    local seed = getSeed()
    local pointValues = [
        [-1, 0, 1], // 0 - Point A is uncapped, point B is RED, point C is BLU.
        [-1, 1, 0], // 1 - Point A is uncapped, point B is BLU, point C is RED.
        [0, -1, 1], // 2 - Point A is RED, point B is uncapped, point C is BLU.
        [1, -1, 0], // 3 - Point A is BLU, point B is uncapped, point C is RED.
        [0, 1, -1], // 4 - Point A is RED, point B is BLU, point C is uncapped.
        [1, 0, -1]  // 5 - Point A is BLU, point B is RED, point C is uncapped.
    ]
    foreach(i, v in pointValues[seed]) {
        if (v != -1) {
            setPoint(i, v, 5.01, false)
            EntFire(areas[i], "SetTeamCanCap", "2 0", 5.01, activator)
            EntFire(areas[i], "SetTeamCanCap", "3 0", 5.01, activator)
        } else {
            // Trigger appropriate startcap relay (based on cap initially unowned)
            EntFire(["tcdom_owns_a_unowned", "tcdom_owns_b_unowned", "tcdom_owns_c_unowned"][i], "Trigger", null, 5.01, activator)
        }
    }

    // Force respawn players from the void
    EntFire("red_spawn_init", "Disable", null, 0.01, activator)
    EntFire("blu_spawn_init", "Disable", null, 0.01, activator)
    EntFire("tcdom_force_respawn", "ForceRespawn", null, 0.05, activator)

}

// Sets convars on map spawn
function mapSpawn() {

    // Set sudden death convar if requested and allowed, otherwise revert to server preference
    if (Convars.IsConVarOnAllowList("mp_stalemate_enable")) {
        Convars.SetValue("mp_stalemate_enable", var_suddenDeath.tointeger())
    } else {
        var_suddenDeath = Convars.GetBool("mp_stalemate_enable")
    }

    // Set sudden death timer convar if request and allowed
    if ((var_suddenDeathTimer != -1) && Convars.IsConVarOnAllowList("mp_stalemate_timelimit")) {
        Convars.SetValue("mp_stalemate_timelimit", var_suddenDeathTimer)
    }

}
