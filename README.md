# PubWAR 2.1
Match Plugin for Pub servers CS/CZ<br/>

This is first popular plugin of pub , which has captain selection, team selection, player selection feature, every thing is automated and its quite like a automix.<br/>

### Console Command
amx_startmatch<br/>
amx_stopmatch<br/>
amx_restartmatch<br/>

### Updated Cvars
    amx_warprefix "||Pub WAR||" // Your Server Tag
    amx_overtime "0" // 1 - To enable | 0 - To disable
    amx_noreset "0" //0 - To allow reset during match | 1 - To block reset
    amx_automap "1" // 0- Disable | 1- Enable

### Installations
> Put .amxx in amxmodx/plugins/<br/>
> Put war folder in addons/amxmodx/configs/<br/>
> Edit cvars in war/cvars.cfg 

### Requirements:
AMX 1.9.0+ Dev or ReAMX<br/>
ReAPI<br/>
ReHLDS & ReGameDLL<br/>

### Changelog 2.1:
-Updated config folder for easy access<br/>
-Added cvars.cfg/maps.ini/war.cfg in config/war/ folder<br/>
-More Updates coming<br/>

### Changelog 2.0:
-Added Prefix Support<br/>
-Added AMX 1.9.0+ Color Chat support<br/>
-Added Support for AMX 1.8.2 - Not Tested.
-Improved code<br/>
-Updated start & stop match command flags<br/>
-Added warcfg execution if you want to use your own config for war<br/>
-Added Overtime Enable Disable Support<br/>
-Fixed Most of the Errors<br/>
-Added NEW LIVE DHUD which can be enabled by uncomment line #define LIVE_DHUD<br/>
-Added Sound Support , to use it uncomment line #define SOUND<br/>
-Renamed OT cvar to amx_overtime "0"<br/>
-Added /rs block feature<br/>
-Updated code and Optimised<br/>
-Updated to 2.0 Version<br/>
-Added Auto Map Vote feature at the end of rank display<br/>
-Added Cvar Control Auto Vote amx_automap "1" //1 Enable and 0 Disable <br/>
-Added Map file amxmodx/configs/maps_war.ini use this file to read war auto maps vote<br/>
-Removed Unwanted Modules/Codes<br/>
-Added Support REAPI Enable or Disable Just comment #define USE_REAPI to disable using reapi feature<br/>
-Added Logging for moderators & server owners<br/>

### NOTE: You can run v2 version of pub war with any mod any map.
