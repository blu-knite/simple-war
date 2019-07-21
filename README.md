# PubWAR 2.1
Match Plugin for Pub servers CS/CZ

This is first popular plugin of pub , which has captain selection, team selection, player selection feature, every thing is automated and its quite like a automix.

### Console Command
amx_startmatch
amx_stopmatch
amx_restartmatch

### Updated Cvars
    amx_warprefix "||Pub WAR||" // Your Server Tag
    amx_overtime "0" // 1 - To enable | 0 - To disable
    amx_noreset "0" //0 - To allow reset during match | 1 - To block reset
    amx_automap "1" // 0- Disable | 1- Enable

### Installations
> Put .amxx in amxmodx/plugins/
> Put war folder in addons/amxmodx/configs/
> Edit cvars in war/cvars.cfg 

### Requirements:
AMX 1.9.0+ Dev or ReAMX
ReAPI
ReHLDS & ReGameDLL

### Changelog 2.1:
-Updated config folder for easy access
-Added cvars.cfg/maps.ini/war.cfg in config/war/ folder
-More Updates coming

### Changelog 2.0:
-Added Prefix Support
-Added AMX 1.9.0+ Color Chat support
-Added Support for AMX 1.8.2 - Not Tested.
-Improved code
-Updated start & stop match command flags
-Added warcfg execution if you want to use your own config for war
-Added Overtime Enable Disable Support
-Fixed Most of the Errors
-Added NEW LIVE DHUD which can be enabled by uncomment line #define LIVE_DHUD
-Added Sound Support , to use it uncomment line #define SOUND
-Renamed OT cvar to amx_overtime "0"
-Added /rs block feature
-Updated code and Optimised
-Updated to 2.0 Version
-Added Auto Map Vote feature at the end of rank display
-Added Cvar Control Auto Vote amx_automap "1" //1 Enable and 0 Disable 
-Added Map file amxmodx/configs/maps_war.ini use this file to read war auto maps vote
-Removed Unwanted Modules/Codes
-Added Support REAPI Enable or Disable Just comment #define USE_REAPI to disable using reapi feature
-Added Logging for moderators & server owners

### NOTE: You can run v2 version of pub war with any mod any map.
