The required SM server plugin, config pack and the vscript to run a PuG game with CompTF2C ruleset and settings.

Different from the main/official comptf2c pack (master branch on GitHub), the comptf2c-PuG pack through the SM plugin allows players to start the game with !ready command typed on chat, or !unready before the game starts.
Note that once the game starts, both commands lose their function and only regain if the map is restarted with the "changelevel" server command. ("mp_restartgame X" command can still be used to start the game, as is the usual way for the main/official pack.)

cc_9v9.cfg and cc_9v9plus.cfg config files in comptf2c-PuG pack have class limit 1, whereas those of the main/official pack do not (except the Civilian limit which may break the game if not present) since class switch then requires players to go Spectator, which is a rule violation.
