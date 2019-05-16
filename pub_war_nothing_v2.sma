#include <amxmodx>
#include <amxmisc>
#include <cstrike>
#include <fun>
#include <fakemeta>
#include <hamsandwich>
#include <reapi>
#include <csx>
#include <engine>

#if AMXX_VERSION_NUM < 183
	#include <dhudmessage>
	#include <colorchat>
#endif

#define PLUGIN "||ECS|| PuB War"
#define VERSION "2.0"
#define AUTHOR "||ECS||nUy aka Abhishek Deshkar"

//Sound Control You must uncomment #define Sound in order to work sound.
// Double Slash is comment

//#define SOUND
#define LIVE_DHUD
#define warcfg "war.cfg"

#if defined SOUND
new sound_files[5][]=
{
	"sound/war_captain.mp3", //0 captain select
	"sound/war_playerselection.mp3", //1 player select
	"sound/war_firsthalf.mp3", //2 first half
	"sound/war_secondhalf.mp3", //3 second half
	"sound/war_end.mp3" //4 match end score board
	// these files are example update according to your needs.
}
#endif

//Set frags.
new Frags[33], Deaths[33];

//======= Overtime Declarations ==================
new bool:g_OverTime     = false
new OTCount             = 0
new cvar_overtime;

//Game Description
new amx_warname

// AFK BOMB
// comment to avoid autodisabling the plugin on maps which not contain bomb targets
//#define BOMB_MAP_CHECK

// float value, hud messages display time (in seconds)
#define MSG_TIME 7.0

// CVAR name, affects on spawned AFK bomb carrier which never moved after spawn
new CVAR_SPAWN[] = "afk_bombtransfer_spawn"

// CVAR value, max. allowed bomb carrier AFK time (in seconds)
new DEFAULT_SPAWN[] = "7"

// CVAR name, affects on any AFK bomb carrier except one which obey previous CVAR
new CVAR_TIME[] = "afk_bombtransfer_time"

// CVAR value, max. allowed bomb carrier AFK time (in seconds)
new DEFAULT_TIME[] = "15"

// do not set this value less than "maxplayers"
#define MAX_PLAYERS 32

// initial AMXX version number supported CVAR pointers in get/set_pcvar_* natives
#define CVAR_POINTERS_AMXX_INIT_VER_NUM 170

// determine if get/set_pcvar_* natives can be used
#if defined AMXX_VERSION_NUM && AMXX_VERSION_NUM >= CVAR_POINTERS_AMXX_INIT_VER_NUM
	#define CVAR_POINTERS
	new g_pcvar_spawn
	new g_pcvar_time
#endif

new TEAM[] = "TERRORIST"
new WEAPON[] = "weapon_c4"

#define	FL_ONGROUND (1<<9)

new bool:g_freezetime = true
new bool:g_spawn
new bool:g_planting

new g_carrier

new g_pos[MAX_PLAYERS + 1][3]
new g_time[MAX_PLAYERS + 1]

new g_maxplayers
// AFK BOMB END

//Ranking system.
new g_TotalKills[33]
new g_TotalDeaths[33]
new g_BombPlants[33]
new g_BombDefusions[33]
new g_TotalLeaves
new gMaxPlayers
new msgToDisplay[456] 

//get the current status of the HALF. By default false because no half started.
new bool:isFirstHalfStarted = false
new bool:isSecondHalfStarted = false

new gCptT
new gCptCT
new CaptainCount = 0
new bool:g_KnifeRound  = false

// Is Match Initialized ?
new bool:g_MatchInit = false

//Owner of: who started the match
new MatchStarterOwner = 0

//Check if captain is choosen
new bool:CaptainSChosen

// Is Match started !
new bool:g_MatchStarted = false

//Set main match started to true: useful for leaving players + Count for leaving players.
new bool:g_MainMatchStarted = false

//By default first half if the second half is false.
new bool:is_secondHalf = false

//Handle the score. By default to: 0 score.
new ScoreFtrstTeam = 0
new ScoreScondteam = 0

//Show menu to the first captain == winner
new ShowMenuFirst
new ShowMenuSecond

//Captains Chosen Teams.- 2 == CT & 1 == T
new FirstCaptainTeamName
new SecondCaptainTeamName

//Store the name of the Captains.
new FirstCaptainName[52]
new SecondCaptainName[52]

//Store the Auth ID of the captains.
new FirstCaptainAuthID[128]
new SecondCaptainAuthID[128]

//Temp captain Names !
new TempFirstCaptain[32]
new TempSecondCaptain[32]

//Store current map.
new szMapname[32]

new RoundCounter = 0

// 1 = first captain 2 = second captain.
new CaptainChoosenID
new WhoChoseThePlayer

new cvar_prefix;
new prefix[64];
new cvar_noreset;

#if defined LIVE_DHUD
new iXYPos;
new const Float:HUD_XY_POS[ ][ ] =
{
	{ -1.0, 0.98 },
	{ -1.0, 0.91 },
	{ -1.0, 0.84 },
	{ -1.0, 0.77 },
	{ -1.0, 0.70 },
	{ -1.0, 0.63 },
	{ -1.0, 0.56 },
	{ -1.0, 0.49 },
	{ -1.0, 0.42 },
	{ -1.0, 0.35 },
	{ -1.0, 0.28 },
	{ -1.0, 0.21 },
	{ -1.0, 0.14 },
	{ -1.0, 0.07 },
	{ -1.0, 0.00 }
};
#endif

//Auto Map Vote Variables
new g_gVoteMenu;
new g_gVotes[5]
new g_Maps_Ini_File[64]
new g_MapsCounter
new g_MapsAvailable[30][20]
new g_MapsChosen[4][20]
new g_DoneMaps
new g_ChangeMapTo

new cvar_automap;

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);

	register_clcmd("say /rs", "reset_block");
	register_clcmd("amx_startmatch", "ShowMenu", ADMIN_KICK, "Get All The players");
	register_clcmd("amx_stopmatch", "StopMatch", ADMIN_KICK, "Stop the Match!");
	register_clcmd("amx_restartmatch", "RestartMatch", ADMIN_KICK, "Restart the Match!");  

    //CVARS
	cvar_prefix = register_cvar("amx_warprefix", "||Pub WAR||");
	cvar_overtime = register_cvar("amx_overtime", "0");
	cvar_noreset = register_cvar("amx_noreset", "0");
	cvar_automap = register_cvar("amx_automap", "1");

	//Set Game Desc
	amx_warname = register_cvar( "amx_warname", "|| WAR About To Start! ||" ); 
	register_forward( FM_GetGameDescription, "GameDesc" );
	set_pcvar_string(amx_warname, "|| WAR About to Start ||");

	// AFK declaration
#if defined CVAR_POINTERS
	g_pcvar_spawn = register_cvar(CVAR_SPAWN, DEFAULT_SPAWN)
	g_pcvar_time = register_cvar(CVAR_TIME, DEFAULT_TIME)
#else
	register_cvar(CVAR_SPAWN, DEFAULT_SPAWN)
	register_cvar(CVAR_TIME, DEFAULT_TIME)
#endif

#if defined BOMB_MAP_CHECK
	// is current map not contain bomb targets?
	if (!engfunc(EngFunc_FindEntityByString, -1, "classname", "func_bomb_target"))
		return
#endif

	register_event("WeapPickup", "event_got_bomb", "be", "1=6")
	register_event("BarTime", "event_bar_time", "be")
	register_event("TextMsg", "event_bomb_drop", "bc", "2=#Game_bomb_drop")
	register_event("TextMsg", "event_bomb_drop", "a", "2=#Bomb_Planted")
	register_event("HLTV", "event_new_round", "a", "1=0", "2=0")

	set_task(1.0, "task_afk_check", _, _, _, "b") // plugin's core loop

	g_maxplayers = get_maxplayers()
	// AFK End

    //block advertise by cs
	set_msg_block(get_user_msgid("HudTextArgs"), BLOCK_SET);

    //Register Death.
	register_event("DeathMsg", "Event_DeathMsg_Knife", "a", "1>0")

    //For Knife round.
	register_event("CurWeapon", "Event_CurWeapon_NotKnife", "be", "1=1", "2!29")  
    
    //Round end event.
	register_logevent("round_end", 2, "1=Round_End")

    //Round start event.
	register_logevent("logevent_round_start", 2, "1=Round_Start")

    //Do not allow clients to join the team when they manually tries to join the team.
	register_clcmd("chooseteam", "cmdChooseTeam")
	register_clcmd("jointeam", "GoToTheSpec");

    // T OR CT WIN.
	register_event( "SendAudio","on_TerroristWin","a","2=%!MRAD_terwin");
	register_event( "SendAudio","on_CTWin","a","2=%!MRAD_ctwin");

    //show score.
	register_clcmd("say !score", "ShowScoreToUser")


    //Get Team Players menu.
	register_clcmd("say /getmenu","GetMatchMenu")
   
	get_mapname(szMapname, charsmax(szMapname))

    get_pcvar_string(cvar_prefix, prefix, charsmax(prefix))

    gMaxPlayers = get_maxplayers()

    get_configsdir(g_Maps_Ini_File, 63); 
	formatex(g_Maps_Ini_File, 63, "%s/maps_war.ini", g_Maps_Ini_File);
}


//Reset Block
public reset_block(id)
{
	if(get_pcvar_num(cvar_noreset) == 1 && g_MatchStarted)
	{
		client_print_color(id, 0, "You cannot reset your score during match");
		return PLUGIN_HANDLED;
	}
	return PLUGIN_CONTINUE;
}

// Sound Declaration
#if defined SOUND
public plugin_precache()
{
	for(new i=0 ; i < sizeof sound_files; i++)
    {
        precache_generic(sound_files[i]);
    }
}

public PlaySound(soundcode)
{
	switch(soundcode)
	{
		case 0: 
		{
			client_cmd(0, "mp3 play %s", sound_files[0]);
		}
		case 1:
		{
			client_cmd(0, "mp3 play %s", sound_files[1]);
		}
		case 2:
		{
			client_cmd(0, "mp3 play %s", sound_files[2]);
		}
		case 3:
		{
			client_cmd(0, "mp3 play %s", sound_files[3]);
		}
		case 4:
		{
			client_cmd(0, "mp3 play %s", sound_files[4]);
		}
	}
}
#endif

//Bomb afk transfer declarations.
public event_new_round() {
	g_freezetime = true
	g_spawn = true
	g_planting = false
	g_carrier = 0
}

public event_got_bomb(id) {
	g_carrier = id
}

public event_bar_time(id) {
	if (id == g_carrier) {
		g_planting = bool:read_data(1)
		get_user_origin(id, g_pos[id])
		g_time[id] = 0
	}
}

public event_bomb_drop() {
	g_spawn = false
	g_planting = false
	g_carrier = 0
}

public task_afk_check() {
	if (g_freezetime) // is freezetime right now?
		return

	// afk check
	new id[32], num, x, origin[3]
	get_players(id, num, "ae", TEAM)
	for (new i = 0; i < num; ++i) {
		x = id[i]
		get_user_origin(x, origin)
		if (origin[0] != g_pos[x][0] || origin[1] != g_pos[x][1] || (x == g_carrier && g_planting)) {
			g_time[x] = 0
			g_pos[x][0] = origin[0]
			g_pos[x][1] = origin[1]
			if (g_spawn && x == g_carrier)
				g_spawn = false
		}
		else
			g_time[x]++
	}

	// is bomb not currently carried or Ts number less than 2?
	if (!g_carrier || num < 2)
		return

#if defined CVAR_POINTERS
	new max_time = get_pcvar_num(g_spawn ? g_pcvar_spawn : g_pcvar_time)
#else
	new max_time = get_cvar_num(g_spawn ? CVAR_SPAWN : CVAR_TIME)
#endif

	// is plugin disabled (cvar <= 0) or carrier isn't afk?
	if (max_time <= 0 || g_time[g_carrier] < max_time)
		return

	// find who from non-afk Ts is the closest to the afk carrier
	get_user_origin(g_carrier, origin)
	new min_dist = 999999, dist, recipient, origin2[3]
	for (new i = 0; i < num; ++i) {
		x = id[i]
		if (g_time[x] < max_time) {
			get_user_origin(x, origin2)
			dist = get_distance(origin, origin2)
			if (dist < min_dist) {
				min_dist = dist
				recipient = x
			}
		}
	}

	if (!recipient) // is all Ts afk?
		return

	new carrier = g_carrier
	engclient_cmd(carrier, "drop", WEAPON) // drop the backpack
	new c4 = engfunc(EngFunc_FindEntityByString, -1, "classname", WEAPON) // find weapon_c4 entity
	if (!c4)
		return

	new backpack = pev(c4, pev_owner) // get backpack entity
	if (backpack <= g_maxplayers)
		return

	// my backpack transfer trick (improved)
	set_pev(backpack, pev_flags, pev(backpack, pev_flags) | FL_ONGROUND)
	dllfunc(DLLFunc_Touch, backpack, recipient)

	// hud messages stuff below
	set_hudmessage(0, 255, 0, 0.35, 0.8, _, _, MSG_TIME)
	new message[128], c_name[32], r_name[32]
	get_user_name(carrier, c_name, 31)
	get_user_name(recipient, r_name, 31)
	format(message, 127, "Bomb transferred to ^"%s^"^nsince ^"%s^" is AFK", r_name, c_name)
	for (new i = 0; i < num; ++i)
		show_hudmessage(id[i], "%s", message)

	set_hudmessage(255, 255, 0, 0.42, 0.3, _, _, MSG_TIME, _, _, 3)
	show_hudmessage(recipient, "You got the bomb!")
}
// AFK END

//Game description forward.
public GameDesc() 
{ 
	static gamename[32]; 
	get_pcvar_string( amx_warname, gamename, 31 ); 
	forward_return( FMV_STRING, gamename ); 
	return FMRES_SUPERCEDE; 
}  


//Event death.
public Event_DeathMsg_Knife()
{
	if(g_MatchStarted)
	{
		new attacker_one = read_data(1) 
		new victim_one = read_data(2) 

		if(g_MatchStarted)
		{
			if( victim_one != attacker_one && cs_get_user_team(attacker_one) != cs_get_user_team(victim_one)) 
			{ 
				g_TotalKills[attacker_one]++
				g_TotalDeaths[victim_one]++
			}
		}
	}
	return PLUGIN_HANDLED
}

public bomb_planted( id )
{
	if ( g_MatchStarted )
	{
		g_BombPlants[id]++
	}
}

public bomb_defused( id )
{
	if ( g_MatchStarted )
	{
		g_BombDefusions[id]++
    }
}

public GetMatchMenu(id)
{  
    if(CaptainSChosen)
    {
        if(id != CaptainChoosenID)
        {
          
            if(WhoChoseThePlayer == 1)
            {
                LetsSecondChoosePlayers(ShowMenuSecond)
            }

            if(WhoChoseThePlayer == 2)
            {
                LetsFirstChoosePlayers(ShowMenuFirst)
            }
        }
      
    }

    return PLUGIN_HANDLED
}

public RestartMatch(id,lvl,cid)
{
    if(!cmd_access(id,lvl,cid,0))
        return PLUGIN_HANDLED
    
    if(g_MatchInit || g_MatchStarted || g_KnifeRound)
    {
        //Log AMX, Who stopped the match!.
        new MatchRestarterName[32] 
        get_user_name(id, MatchRestarterName, charsmax(MatchRestarterName)) 

        new MatchRestarterAuthID[128] 
        get_user_authid(id, MatchRestarterAuthID, 127)

        log_amx("Admin %s with ID = %i and AuthID %s has restarted the Match !",MatchRestarterName,id,MatchRestarterAuthID)

        server_cmd("mp_freezetime 999");

        set_dhudmessage(0, 255, 0, -1.0, -1.0, 0, 2.0, 6.0, 0.8, 0.8)
        show_dhudmessage(0,"Admin has restarted the Match ! ^n Captains will be chosen shortly..")

        set_task(8.0,"RestartMatchTask",id)

        return PLUGIN_HANDLED
    } 
    return PLUGIN_HANDLED
}

public RestartMatchTask(id)
{

    LoadPubSettings()
    ShowMenuSpecial(id)   
}

//Stop the Match.
public StopMatch(id,lvl, cid)
{
    if(!cmd_access(id, lvl, cid, 0))
		return PLUGIN_HANDLED;


    if(g_MatchInit || g_MatchStarted || g_KnifeRound)
    {
        //Log AMX, Who stopped the match!.
        new MatchStopperName[32] 
        get_user_name(id, MatchStopperName, charsmax(MatchStopperName)) 

        new MatchStopperAuthID[128] 
        get_user_authid(id, MatchStopperAuthID, 128)

        log_amx("Admin %s with AuthID %s has stopped the Match !",MatchStopperName,MatchStopperAuthID)

        server_cmd("mp_freezetime 999");

        set_dhudmessage(0, 255, 0, -1.0, -1.0, 0, 2.0, 6.0, 0.8, 0.8)
        show_dhudmessage(0,"Admin has Stopped the Match ! ^n Server will restart now.")

        set_task(8.0,"RestartServerForStoppingMatch")

        return PLUGIN_HANDLED
    } 
    return PLUGIN_HANDLED
}


//Stop match special when owner is not there.
public StopMatchSpecial()
{
    if(g_MatchInit || g_MatchStarted || g_KnifeRound)
    {
        server_cmd("mp_freezetime 999");

        set_dhudmessage(0, 255, 0, -1.0, -1.0, 0, 2.0, 6.0, 0.8, 0.8)
        show_dhudmessage(0,"Match Lord has Left the Game ! ^n Server will restart now.")

        set_task(4.0,"RestartServerForStoppingMatch")
    } 
    return PLUGIN_HANDLED
}

public RestartServerForStoppingMatch()
{
    new CurrentMap[33]
    get_mapname(CurrentMap,32)

    server_cmd("changelevel %s",CurrentMap)

    return PLUGIN_HANDLED
}


public GoToTheSpec(id)
{
    if(g_MatchInit || g_KnifeRound)
    {   
        if(is_user_connected(id))
        {
            set_task(3.0,"TransferToSpec",id)
        }
    }
}


//Terrorist Win event.
public on_TerroristWin()
{
    //Terrorrist Knife round winner.
    if(g_KnifeRound == true)
    {
        // T WOWN.
        ShowMenuFirst = gCptT
        ShowMenuSecond = gCptCT

        //Set Names of the Captain. because captain may leave the game.
        get_user_name(ShowMenuFirst, FirstCaptainName, charsmax(FirstCaptainName)) 
        get_user_name(ShowMenuSecond, SecondCaptainName, charsmax(SecondCaptainName))

        set_task( 3.0, "GiveRestartRound", _, _, _, "a", 1 ); 

        set_task(2.0,"FirstCaptainWonKnifeRoundMessage",gCptT)

        g_KnifeRound = false
        LoadMatchSettings()
    }

    if(g_MatchStarted)
    {
        if(isFirstHalfStarted)
        {
            if(FirstCaptainTeamName == 1)
            {
                ScoreFtrstTeam++
            }
            else
            {
                ScoreScondteam++
            }

            //Change description of the game.
            if(ScoreFtrstTeam > ScoreScondteam)
            {
                new GameDescBuffer[32]
                if(g_OverTime)
                {
                    formatex(GameDescBuffer,charsmax(GameDescBuffer),"OT- 1st-H: %d To %d",ScoreFtrstTeam,ScoreScondteam)
                }
                else
                {
                    formatex(GameDescBuffer,charsmax(GameDescBuffer),"1st-H: %d To %d",ScoreFtrstTeam,ScoreScondteam)
                }
                
                set_cvar_string("amx_warname",GameDescBuffer)
            }

            if(ScoreScondteam > ScoreFtrstTeam)
            {
                new GameDescBuffer[32]
                if(g_OverTime)
                {
                    formatex(GameDescBuffer,charsmax(GameDescBuffer),"OT- 1st-H: %d To %d",ScoreScondteam,ScoreFtrstTeam)
                }
                else
                {
                    formatex(GameDescBuffer,charsmax(GameDescBuffer),"1st-H: %d To %d",ScoreScondteam,ScoreFtrstTeam)
                }
                set_cvar_string("amx_warname",GameDescBuffer)
            }

            if(ScoreFtrstTeam == ScoreScondteam)
            {
                new GameDescBuffer[32]
                if(g_OverTime)
                {
                    formatex(GameDescBuffer,charsmax(GameDescBuffer),"OT- 1st-H: %d To %d",ScoreScondteam,ScoreFtrstTeam)
                }
                else
                {
                    formatex(GameDescBuffer,charsmax(GameDescBuffer),"1st-H: %d To %d",ScoreScondteam,ScoreFtrstTeam)
                }
                set_cvar_string("amx_warname",GameDescBuffer)
            }

        }
        if(isSecondHalfStarted)
        {
            if(FirstCaptainTeamName == 1)
            {
                ScoreScondteam++
            }
            else
            {
                ScoreFtrstTeam++
            }

            //Change description of the game.
            if(ScoreFtrstTeam > ScoreScondteam)
            {
                new GameDescBuffer[32]
                if(g_OverTime)
                {
                    formatex(GameDescBuffer,charsmax(GameDescBuffer),"OT- 2nd-H: %d To %d",ScoreFtrstTeam,ScoreScondteam)
                }
                else
                {
                    formatex(GameDescBuffer,charsmax(GameDescBuffer),"2nd-H: %d To %d",ScoreFtrstTeam,ScoreScondteam)
                }

                set_cvar_string("amx_warname",GameDescBuffer)
            }

            if(ScoreScondteam > ScoreFtrstTeam)
            {
                new GameDescBuffer[32]
                if(g_OverTime)
                {
                    formatex(GameDescBuffer,charsmax(GameDescBuffer),"OT- 2nd-H: %d To %d",ScoreScondteam,ScoreFtrstTeam)
                }
                else
                {
                    formatex(GameDescBuffer,charsmax(GameDescBuffer),"2nd-H: %d To %d",ScoreScondteam,ScoreFtrstTeam)
                }
                set_cvar_string("amx_warname",GameDescBuffer)
            }

            if(ScoreFtrstTeam == ScoreScondteam)
            {
                new GameDescBuffer[32]

                if(g_OverTime)
                {
                    formatex(GameDescBuffer,charsmax(GameDescBuffer),"OT- 2nd-H: %d To %d",ScoreScondteam,ScoreFtrstTeam)
                }
                else
                {
                    formatex(GameDescBuffer,charsmax(GameDescBuffer),"2nd-H: %d To %d",ScoreScondteam,ScoreFtrstTeam)
                }
                set_cvar_string("amx_warname",GameDescBuffer)
            }
        }
    }
}

//CT WIN Event.
public on_CTWin()
{
	if(g_KnifeRound)
	{
			// CT WON.
			ShowMenuFirst = gCptCT
			ShowMenuSecond = gCptT

			//Set Names of the Captain. because captain may leave the game.
 			get_user_name(ShowMenuFirst, FirstCaptainName, charsmax(FirstCaptainName)) 
			get_user_name(ShowMenuSecond, SecondCaptainName, charsmax(SecondCaptainName)) 

			get_user_authid(ShowMenuFirst, FirstCaptainAuthID, 127)
			get_user_authid(ShowMenuSecond, SecondCaptainAuthID, 127)

			g_KnifeRound = false
        

			set_task( 3.0, "GiveRestartRound", _, _, _, "a", 1 ); 

			set_task(2.0,"SecondCaptWonKnifeRoundWonMessage",gCptCT)
            
			LoadMatchSettings()
	}

	if(g_MatchStarted)
    {
        if(isFirstHalfStarted)
        {
            if(FirstCaptainTeamName == 2)
            {
                ScoreFtrstTeam++
            }
            else
            {
                ScoreScondteam++
            }

            //Change description of the game.
            if(ScoreFtrstTeam > ScoreScondteam)
            {
                new GameDescBuffer[32]
                if(g_OverTime)
                {
                    formatex(GameDescBuffer,charsmax(GameDescBuffer),"OT- 1st-H: %d To %d",ScoreFtrstTeam,ScoreScondteam)
                }
                else
                {
                    formatex(GameDescBuffer,charsmax(GameDescBuffer),"1st-H: %d To %d",ScoreFtrstTeam,ScoreScondteam)
                }
                
                set_cvar_string("amx_warname",GameDescBuffer)
            }

            if(ScoreScondteam > ScoreFtrstTeam)
            {
                new GameDescBuffer[32]
                if(g_OverTime)
                {
                    formatex(GameDescBuffer,charsmax(GameDescBuffer),"OT- 1st-H: %d To %d",ScoreScondteam,ScoreFtrstTeam)
                }
                else
                {
                    formatex(GameDescBuffer,charsmax(GameDescBuffer),"1st-H: %d To %d",ScoreScondteam,ScoreFtrstTeam)
                }
                set_cvar_string("amx_warname",GameDescBuffer)
            }

            if(ScoreFtrstTeam == ScoreScondteam)
            {
                new GameDescBuffer[32]
                if(g_OverTime)
                {
                    formatex(GameDescBuffer,charsmax(GameDescBuffer),"OT- 1st-H: %d To %d",ScoreScondteam,ScoreFtrstTeam)
                }
                else
                {
                    formatex(GameDescBuffer,charsmax(GameDescBuffer),"1st-H: %d To %d",ScoreScondteam,ScoreFtrstTeam)
                }
                
                set_cvar_string("amx_warname",GameDescBuffer)
            }
        }

        if(isSecondHalfStarted)
        {
            if(FirstCaptainTeamName == 2)
            {
                ScoreScondteam++
            }
            else
            {
                ScoreFtrstTeam++
            }

            //Change description of the game.
            if(ScoreFtrstTeam > ScoreScondteam)
            {
                new GameDescBuffer[32]
                if(g_OverTime)
                {
                    formatex(GameDescBuffer,charsmax(GameDescBuffer),"OT- 2nd-H: %d To %d",ScoreFtrstTeam,ScoreScondteam)
                }
                else
                {
                    formatex(GameDescBuffer,charsmax(GameDescBuffer),"2nd-H: %d To %d",ScoreFtrstTeam,ScoreScondteam)
                }

                set_cvar_string("amx_warname",GameDescBuffer)
            }

            if(ScoreScondteam > ScoreFtrstTeam)
            {
                new GameDescBuffer[32]
                if(g_OverTime)
                {
                    formatex(GameDescBuffer,charsmax(GameDescBuffer),"OT- 2nd-H: %d To %d",ScoreScondteam,ScoreFtrstTeam)
                }
                else
                {
                    formatex(GameDescBuffer,charsmax(GameDescBuffer),"2nd-H: %d To %d",ScoreScondteam,ScoreFtrstTeam)
                }

                set_cvar_string("amx_warname",GameDescBuffer)
            }

            if(ScoreFtrstTeam == ScoreScondteam)
            {
                new GameDescBuffer[32]
                if(g_OverTime)
                {
                    formatex(GameDescBuffer,charsmax(GameDescBuffer),"OT- 2nd-H: %d To %d",ScoreScondteam,ScoreFtrstTeam)
                }
                else
                {
                    formatex(GameDescBuffer,charsmax(GameDescBuffer),"2nd-H: %d To %d",ScoreScondteam,ScoreFtrstTeam)
                }

                set_cvar_string("amx_warname",GameDescBuffer)
            }
        }
    }
}


//ROUND START Event.
public logevent_round_start()
{

    if(g_KnifeRound)
    {

        set_dhudmessage(255, 255, 255, -1.0, -1.0, 0, 2.0, 6.0, 0.8, 0.8)
        show_dhudmessage(0,"-= Knife Round Begins =- ^n Captain: %s ^n Vs. ^n Captain: %s",TempFirstCaptain,TempSecondCaptain)  

        client_print_color(0, print_team_default, "^3%s ^4 ^3Knife Round ^1has ^4been started ! ", prefix)
        client_print_color(0, print_team_default, "^3%s ^4 Knife War: ^1Captain- ^3 %s ^4Vs. ^1Captain- ^3%s", prefix, TempFirstCaptain,TempSecondCaptain)
        client_print_color(0, print_team_default, "^3%s ^4 Knife War: ^1Captain- ^3 %s ^4Vs. ^1Captain- ^3%s", prefix, TempFirstCaptain,TempSecondCaptain)
     
    }
    
	if(g_MatchStarted)
	{
        //Show Score info in Hud on every round start.
		ShowScoreHud()
		set_task(3.0,"ShowScoreOnRoundStart")
	}

	new id[32], num
	get_players(id, num, "ae", TEAM)

	if (!num) // is server empty?
		return

	g_freezetime = false

	// update afk timers and current positions
	new x
	for (new i = 0; i < num; ++i) {
		x = id[i]
		get_user_origin(x, g_pos[x])
		g_time[x] = 0
	}
}

//When Client join the server and if match is initialized or Knife round is running transfer player to spec.
public client_putinserver(id)
{

    if(g_MainMatchStarted)
    {
        Frags[id] = 0
        Deaths[id] = 0
    }

    g_TotalKills[id]    = 0
    g_TotalDeaths[id]   = 0
    g_BombPlants[id]    = 0
    g_BombDefusions[id] = 0

    if(g_MatchInit || g_KnifeRound)
    {
        set_task(7.0,"TransferToSpec",id)
    }

}

//Menu for restart !
public ShowMenuSpecial(id)
{
	

    //Store who started the match!.
    MatchStarterOwner = id

    //Log AMX, Who stopped the match!.
    new MatchStarterName[32] 
    get_user_name(id, MatchStarterName, charsmax(MatchStarterName)) 

    new MatchStarterAuthID[128] 
    get_user_authid(id, MatchStarterAuthID, 127)


    // Match has been initialized! 
    g_MatchInit = true


    // TASK 1 - To Move All the players in Spec.
	cmdTransferAllInSpec();

    //Send message to players about message.
	MatchInitHudMessage()


    //Task 2 - Show Players Menu to who started the match.
	set_task(5.0, "ShowMenuPlayers", id)


	return PLUGIN_HANDLED;
}



//Choose Captains and Initialize Match.
public ShowMenu(id, lvl, cid)
{
	if(!cmd_access(id, lvl, cid, 0))
		return PLUGIN_HANDLED;

	if(g_MatchInit || g_MatchStarted)
	return PLUGIN_HANDLED


	MatchStarterOwner = id

    //Match initialized. 
	set_cvar_string("amx_warname","Initialized!")

    //Log AMX, Who stopped the match!.
	new MatchStarterName[32] 
	get_user_name(id, MatchStarterName, charsmax(MatchStarterName)) 

	new MatchStarterAuthID[128] 
	get_user_authid(id, MatchStarterAuthID, 127)

    // Match has been initialized! 
	g_MatchInit = true

    // TASK 1 - To Move All the players in Spec.
	cmdTransferAllInSpec();

    //Send message to players about message.
	MatchInitHudMessage()


    //Task 2 - Show Players Menu to who started the match.
	set_task(3.0, "ShowMenuPlayers", id)

	#if defined SOUND
	PlaySound(0);
	#endif

	return PLUGIN_HANDLED;
}

//Show HUD Message and Print message to inform player about match started !
public MatchInitHudMessage()
{
	set_dhudmessage(0, 255, 0, -1.0, -1.0, 0, 2.0, 6.0, 0.8, 0.8)
	show_dhudmessage(0,"The Match has been Initialized ! ^n Captains will be chosen by the Match Lord.")

	client_print_color(0, print_team_default, "^3%s ^4 The Match has been ^3Initialized.", prefix)
	client_print_color(0, print_team_default, "^3%s ^4 The Match has been ^3Initialized.", prefix)
	client_print_color(0, print_team_default, "^3%s ^4 Captains will be ^3chosen.", prefix)
}

public ShowMenuPlayers(id)
{
    set_cvar_string("amx_warname","Captain Selection!")

    new iMenu = MakePlayerMenu("Choose a Captain", "PlayersMenuHandler");
    menu_setprop( iMenu, MPROP_NUMBER_COLOR, "\y" );
    menu_display( id, iMenu );

    return PLUGIN_CONTINUE;
}

MakePlayerMenu(const szMenuTitle[], const szMenuHandler[] )
{
    new iMenu = menu_create( szMenuTitle, szMenuHandler );
    new iPlayers[32], iNum, iPlayer, szPlayerName[32], szUserId[33];
    get_players( iPlayers, iNum, "h" );

    new PlayerWithPoints[128]

    for(new i=0;i<iNum;i++)
    {
        iPlayer = iPlayers[i];
        
        //Add user in the menu if - CONNECTED and TEAM IS T.
        if(get_user_team(iPlayer) == 3 )
        {
            
            get_user_name( iPlayer, szPlayerName, charsmax( szPlayerName ) );

            formatex(PlayerWithPoints,127,"%s",szPlayerName)

            formatex( szUserId, charsmax( szUserId ), "%d", get_user_userid( iPlayer ) );
            menu_additem( iMenu, PlayerWithPoints, szUserId, 0 );

        }

        
    }


    return iMenu;
}

public PlayersMenuHandler( id, iMenu, iItem )
{
    if ( iItem == MENU_EXIT )
    {
        // Recreate menu because user's team has been changed.
        new iMenu = MakePlayerMenu("Choose a Captain", "PlayersMenuHandler" );
        menu_setprop( iMenu, MPROP_NUMBER_COLOR, "\y" );
        menu_display( id, iMenu );

		return PLUGIN_HANDLED;
	}

	new szUserId[32], szPlayerName[32], iPlayer, iCallback;

	menu_item_getinfo( iMenu, iItem, iCallback, szUserId, charsmax( szUserId ), szPlayerName, charsmax( szPlayerName ), iCallback );

	if ( ( iPlayer = find_player( "k", str_to_num( szUserId ) ) )  )
	{

		if(CaptainCount == 0)
		{

            //cs_set_user_team(iPlayer, CS_TEAM_CT)
			rg_set_user_team(iPlayer,TEAM_CT,MODEL_AUTO,true)

			new ChosenCaptain[32] 
			get_user_name(iPlayer, ChosenCaptain, charsmax(ChosenCaptain)) 
			client_print_color(0, print_team_default, "^3%s ^4Player  ^3%s chosen ^1as  First ^3Captain! ", prefix, ChosenCaptain)  

			CaptainCount++  

            //Temp captain name.
			get_user_name(iPlayer, TempFirstCaptain, charsmax(TempFirstCaptain)) 

            //Assign CT Captain
			gCptCT = iPlayer

            //Recreate menu.
			menu_destroy(iMenu)
			new iMenu = MakePlayerMenu("Choose a Captain", "PlayersMenuHandler" );
			menu_setprop( iMenu, MPROP_NUMBER_COLOR, "\y" );
 			menu_display( id, iMenu );

			return PLUGIN_HANDLED;

		}

		if(CaptainCount == 1)
		{

            //cs_set_user_team(iPlayer, CS_TEAM_T)
			rg_set_user_team(iPlayer,TEAM_TERRORIST,MODEL_AUTO,true)


			new ChosenCaptain[32] 
			get_user_name(iPlayer, ChosenCaptain, charsmax(ChosenCaptain)) 
			client_print_color(0, print_team_default, "^3%s ^4Player  ^3%s chosen ^1as Second ^3Captain! ", prefix, ChosenCaptain)

			CaptainCount++


             //Temp captain name.
			get_user_name(iPlayer, TempSecondCaptain, charsmax(TempSecondCaptain)) 

            //Assign T Captain
			gCptT = iPlayer

            //Set it to true because captains have been chosen.
			CaptainSChosen = true

            //Announcement.
			set_dhudmessage(255, 0, 0, -1.0, -1.0, 0, 2.0, 6.0, 0.8, 0.8)
			show_dhudmessage(0,"Get Ready Captains! ^n The Knife Round will Start in 10 seconds....")
			client_print_color(0, print_team_default, "^3%s ^4Attention ! ^1The ^3Knife Round ^4Will Start in 10 seconds!", prefix)

            //Start knife round.
			set_task(10.0,"Knife_Round")

            //Captain choosing is over so destroy menu.
			menu_destroy(iMenu)
			return PLUGIN_HANDLED;
        }
        
    }
    
    // Recreate menu because user's team has been changed.
	new iMenu = MakePlayerMenu("Choose a Captain", "PlayersMenuHandler" );
	menu_setprop( iMenu, MPROP_NUMBER_COLOR, "\y" );
	menu_display( id, iMenu );

    return PLUGIN_HANDLED;
}

public Knife_Round()
{

    set_cvar_string("amx_warname","Captain Knife WAR")
    server_cmd("mp_autokick 0")
    server_cmd("mp_autoteambalance 0")
    set_task( 3.0, "GiveRestartRound", _, _, _, "a", 3 ); 
    set_task(10.0,"SetKnifeRoundTrue")
}

public SetKnifeRoundTrue()
{
    g_KnifeRound = true
}

//Round end Checker
public round_end()
{

	new Players[ MAX_PLAYERS ], iNum;
	get_players( Players, iNum, "h" );

	if(g_MatchStarted)
    {
       //Increment rounds.
        RoundCounter++


        ShowScoreHud()
        CheckForWinningTeam()


        if(g_OverTime)
        {
            //Over time logic.
            if(RoundCounter == 3)
            {

                //Loop through users and set user score + death.
                new players[32], num
                get_players(players, num,"h")
                
                new player
                for(new i = 0; i < num; i++)
                {
                    player = players[i]
                    if(is_user_connected(player))
                    {
						Frags[player] = get_user_frags(player)
						Deaths[player] = cs_get_user_deaths(player)
                    }

                }

                server_cmd("mp_freezetime 999")
                set_task(7.0,"SwapTeamsOverTimeMessage")
            }
        }
        else
        {
            if(RoundCounter == 15)
            {
                
                //Loop through users and set user score + death.
                new players[32], num
                get_players(players, num,"h")
                
                new player
                for(new i = 0; i < num; i++)
                {
                    player = players[i]
                    if(is_user_connected(player))
                    {
						Frags[player] = get_user_frags(player)
						Deaths[player] = cs_get_user_deaths(player)
                    }

                }

                server_cmd("mp_freezetime 999")
                set_task(7.0,"SwapTeamsMessage")

                
            }
        }

    }
}

//Choose the team.
public ChooseTeam(id)
{
	set_cvar_string("amx_warname","Captain Team Selection")

	set_dhudmessage(255, 255, 255, -1.0, -1.0, 0, 2.0, 6.0, 0.8, 0.8)
	show_dhudmessage(0,"Captain %s will Choose Team and Players First !",FirstCaptainName)
    
	new TeamChooser = MakeTeamSelectorMenu("Please Choose the Team.", "TeamHandler" );
	menu_setprop( TeamChooser, MPROP_NUMBER_COLOR, "\y" );
	menu_display( id, TeamChooser );

}

MakeTeamSelectorMenu(const szMenuTitle[], const szMenuHandler[])
{
     new TeamChooser = menu_create( szMenuTitle, szMenuHandler );
     menu_additem( TeamChooser, "Counter-Terrorist" );
     menu_additem( TeamChooser, "Terrorist");

     return TeamChooser;
}

public TeamHandler(id, TeamChooser, iItem )
{
    if ( iItem == MENU_EXIT )
    {
        // Recreate menu because user's team has been changed.
        new TeamChooser = MakeTeamSelectorMenu("Please Choose the Team.", "TeamHandler" );
        menu_setprop( TeamChooser, MPROP_NUMBER_COLOR, "\y" );
        menu_display( id, TeamChooser );

        return PLUGIN_HANDLED;
    }


    switch(iItem)
    {
        //Chosen CT.
        case 0:
        {
            client_print_color(0, print_team_default, "^3%s ^4Captain ^3%s ^1chosen Team- ^4Counter-Terrorist", prefix, FirstCaptainName)

           
            FirstCaptainTeamName = 2
            SecondCaptainTeamName = 1

            if(get_user_team(id) != 2)
            {
                SwapPlayer()
            
            }
            set_cvar_string("amx_warname","=[ Players Selection ]=")         

            set_task(5.0,"LetsFirstChoosePlayers",id)


        }
        //Chosen T.
        case 1:
        {

            FirstCaptainTeamName = 1
            SecondCaptainTeamName = 2

            client_print_color(0, print_team_default, "^3%s ^4Captain ^3%s ^1chosen Team- ^4Terrorist", prefix, FirstCaptainName)

            if(get_user_team(id) != 1)
            {
                SwapPlayer()
            }

            set_cvar_string("amx_warname","=[ Players Selection ]=")

          

            set_task(5.0,"LetsFirstChoosePlayers",id)
        }
    }
    return PLUGIN_HANDLED;
}

// MENU TO CHOOSE PLAYERS !!!
public LetsFirstChoosePlayers(id)
{
	#if defined SOUND
	PlaySound(1);
	#endif

	new players[32], count;     
	get_players(players, count,"eh","SPECTATOR"); 

	if(count > 0)
	{
		new iChoosePlayers = LetsFirstChoosePlayersMenu("Choose A player.", "LetsFirstChoosePlayersHandler" );
		menu_setprop( iChoosePlayers, MPROP_NUMBER_COLOR, "\y" );
		menu_display( id, iChoosePlayers );
        
		return PLUGIN_HANDLED;
	}
	else
    {

		set_cvar_string("amx_warname","Teams Are Set!")

		set_dhudmessage(0,255, 0, -1.0, -1.0, 0, 2.0, 6.0, 0.8, 0.8)
		show_dhudmessage(0,"Teams are SET ! ^n ^n First Half will start Now.......")

		set_task(2.0, "GiveRestartRound"); 

		set_task(4.0,"LiveOnThreeRestart");

		set_task(8.0,"StartMatch")

		return PLUGIN_HANDLED;
    }
}

LetsFirstChoosePlayersMenu(const szMenuTitle[], const szMenuHandler[])
{


    new iChoosePlayers = menu_create( szMenuTitle, szMenuHandler );
    new iPlayers[32], iNum, iPlayer, szPlayerName[32], szUserId[32];
    get_players( iPlayers, iNum, "h" );

    new PlayerWithPoints[128]

    for(new i = 0 ;i<iNum;i++)
    {
        iPlayer = iPlayers[i];
       
        //Add user in the menu if - CONNECTED and TEAM IS T.
        if(get_user_team(iPlayer) == 3 )
        {             
            get_user_name( iPlayer, szPlayerName, charsmax( szPlayerName ) );

            formatex(PlayerWithPoints,127,"%s",szPlayerName)

            formatex( szUserId, charsmax( szUserId ), "%d", get_user_userid( iPlayer ) );
            menu_additem( iChoosePlayers, PlayerWithPoints, szUserId, 0 );

        }
        
    
    }
    return iChoosePlayers;
}

public LetsFirstChoosePlayersHandler( id, iChoosePlayers, iItem )
{
    if ( iItem == MENU_EXIT )
    {
        new iChoosePlayers = LetsFirstChoosePlayersMenu("Choose A player.", "LetsFirstChoosePlayersHandler" );
        menu_setprop( iChoosePlayers, MPROP_NUMBER_COLOR, "\y" );
        menu_display( id, iChoosePlayers );
        
        return PLUGIN_HANDLED;
    }

    new szUserId[32], szPlayerName[32], iPlayer,  iCallback;
    menu_item_getinfo( iChoosePlayers, iItem, iCallback, szUserId, charsmax( szUserId ), szPlayerName, charsmax( szPlayerName ), iCallback );

    if ( ( iPlayer = find_player( "k", str_to_num( szUserId ) ) )  )
    {


        new ChoosenPlayer[32] 
        get_user_name(iPlayer, ChoosenPlayer, charsmax(ChoosenPlayer)) 
     

        client_print_color(0, print_team_default, "^3%s ^4Captain ^3%s ^4chose ^1Player ^4%s ", prefix, FirstCaptainName,ChoosenPlayer);

        

		if(!is_user_connected(iPlayer))
		{
			new iChoosePlayers = LetsFirstChoosePlayersMenu("Choose A player.", "LetsFirstChoosePlayersHandler" );
			menu_setprop( iChoosePlayers, MPROP_NUMBER_COLOR, "\y" );
			menu_display( id, iChoosePlayers );
            
			return PLUGIN_HANDLED;
		}
		else
		{
			CaptainChoosenID = id
			WhoChoseThePlayer = 1
            //cs_set_user_team(iPlayer, cs_get_user_team(id))

			new CsTeams:team = cs_get_user_team(id)

			if(team == CS_TEAM_CT)
			{
                //transfer player to ct.
				rg_set_user_team(iPlayer,TEAM_CT,MODEL_AUTO,true)
			}

			if(team == CS_TEAM_T)
			{
                //transfer player to Terrorist.
				rg_set_user_team(iPlayer,TEAM_TERRORIST,MODEL_AUTO,true)
			}


			LetsSecondChoosePlayers(ShowMenuSecond)
			return PLUGIN_HANDLED;
		}
	}
	return PLUGIN_HANDLED;
}



// MENU TO CHOOSE PLAYERS !!!
public LetsSecondChoosePlayers(id)
{


    new players[32], count;     
    get_players(players, count,"eh","SPECTATOR"); 

    if(count > 0)
    {
        new iChoosePlayers = LetsSecondChoosePlayersMenu("Choose A player.", "LetsSecondChoosePlayersHandler" );
        menu_setprop( iChoosePlayers, MPROP_NUMBER_COLOR, "\y" );
        menu_display( id, iChoosePlayers );

        return PLUGIN_HANDLED;
    }
    else
    {
        //TEAMS ARE SET BECAUSE NO PLAYERS IN SPEC!

		set_dhudmessage(0, 255, 0, -1.0, -1.0, 0, 2.0, 6.0, 0.8, 0.8)
		show_dhudmessage(0,"Teams are SET ! ^n ^n First Half will start Now.......")
        
		set_task(2.0, "GiveRestartRound"); 

		set_task(4.0,"LiveOnThreeRestart");

		set_task(8.0,"StartMatch")

		return PLUGIN_HANDLED;
    }
    
}

LetsSecondChoosePlayersMenu(const szMenuTitle[], const szMenuHandler[])
{
    new iChoosePlayers = menu_create( szMenuTitle, szMenuHandler );
    new iPlayers[32], iNum, iPlayer, szPlayerName[32], szUserId[32];
    get_players( iPlayers, iNum, "h" );

    new PlayerWithPoints[128]

    for(new i = 0;i<iNum;i++)
    {
        iPlayer = iPlayers[i];    
 
        //Add user in the menu if - CONNECTED and TEAM IS T.
        if(get_user_team(iPlayer) == 3 )
        {
             
            get_user_name( iPlayer, szPlayerName, charsmax( szPlayerName ) );

            formatex(PlayerWithPoints,127,"%s",szPlayerName)

            formatex( szUserId, charsmax( szUserId ), "%d", get_user_userid( iPlayer ) );
            menu_additem( iChoosePlayers, PlayerWithPoints, szUserId, 0 );

        }
      
        
    }
    return iChoosePlayers;
}

public LetsSecondChoosePlayersHandler( id, iChoosePlayers, iItem )
{
    if ( iItem == MENU_EXIT )
    {
        new iChoosePlayers = LetsSecondChoosePlayersMenu("Choose A player.", "LetsSecondChoosePlayersHandler" );
        menu_setprop( iChoosePlayers, MPROP_NUMBER_COLOR, "\y" );
        menu_display( id, iChoosePlayers ); 
        return PLUGIN_HANDLED;
    }

    new szUserId[32], szPlayerName[32], iPlayer, iCallback;
    menu_item_getinfo( iChoosePlayers, iItem, iCallback, szUserId, charsmax( szUserId ), szPlayerName, charsmax( szPlayerName ), iCallback );

    if ( ( iPlayer = find_player( "k", str_to_num( szUserId ) ) )  )
    {
       

        new ChoosenPlayer[32] 
        get_user_name(iPlayer, ChoosenPlayer, charsmax(ChoosenPlayer)) 
     

        client_print_color(0, print_team_default, "^3%s ^4Captain ^3%s ^4chose ^1Player ^4%s", prefix, SecondCaptainName,ChoosenPlayer);

        if(!is_user_connected(iPlayer))
        {
            new iChoosePlayers = LetsSecondChoosePlayersMenu("Choose A player.", "LetsSecondChoosePlayersHandler" );
            menu_setprop( iChoosePlayers, MPROP_NUMBER_COLOR, "\y" );
            menu_display( id, iChoosePlayers ); 
            return PLUGIN_HANDLED;
        }
        else
        {   
            WhoChoseThePlayer = 2
            CaptainChoosenID = id
            //cs_set_user_team(iPlayer, cs_get_user_team(id))
            
            new CsTeams:team = cs_get_user_team(id)

            if(team == CS_TEAM_CT)
            {
                //transfer player to ct.
                rg_set_user_team(iPlayer,TEAM_CT,MODEL_AUTO,true)
            }

            if(team == CS_TEAM_T)
            {
                //transfer player to Terrorist.
                rg_set_user_team(iPlayer,TEAM_TERRORIST,MODEL_AUTO,true)
            }

            
            LetsFirstChoosePlayers(ShowMenuFirst);
            return PLUGIN_HANDLED;
        }
        
    }

    return PLUGIN_HANDLED;
}


public client_disconnected(id)
{
    if(CaptainSChosen || g_KnifeRound)
    {
        if(id == gCptCT || id == gCptT)
        {

            if(is_user_connected(MatchStarterOwner))
            {
                set_hudmessage(0, 255, 0, -1.0, -1.0, 0, 2.0, 6.0, 0.8, 0.8, -1)
                show_hudmessage(0,"Restarting the Match! ^n One of the Captain left the Game.")

                RestartMatchTask(MatchStarterOwner)
            }
            else
            {

                StopMatchSpecial()
            }

        }
    }


    if(g_MainMatchStarted)
    {

        //Set score and death to zero.
        Frags[id] = 0
        Deaths[id] = 0

        g_TotalLeaves++
        
    }
}

public DoRanking()
{
	new KillerName[256], DeathsName[256], BombPName[256], BombDName[256]
	new players[32], pnum, tempid
	new topKillerID, topDeathsID, topBombPID, topBombDID
	new topKills, topDeaths, topBombP, topBombD

	get_players(players, pnum)

	for ( new i ; i < pnum ; i++ )
	{
		tempid = players[i]
		
		if ( g_TotalKills[tempid] >= topKills && g_TotalKills[tempid] )
		{
			topKills = g_TotalKills[tempid]
			topKillerID = tempid
		}
		
		if ( g_TotalDeaths[tempid] >= topDeaths && g_TotalDeaths[tempid] )
		{
			topDeaths = g_TotalDeaths[tempid]
			topDeathsID = tempid
		}
		
		if ( g_BombPlants[tempid] >= topBombP && g_BombPlants[tempid] )
		{
			topBombP = g_BombPlants[tempid]
			topBombPID = tempid
		}
		
		if ( g_BombDefusions[tempid] >= topBombD && g_BombDefusions[tempid] )
		{
			topBombD = g_BombDefusions[tempid]
			topBombDID = tempid
		}
	}
	
	if ( 1 <= topKillerID <= gMaxPlayers )
		get_user_name(topKillerID, KillerName, charsmax(KillerName))
	if ( 1 <= topDeathsID <= gMaxPlayers )
		get_user_name(topDeathsID, DeathsName, charsmax(DeathsName))
	if ( 1 <= topBombPID <= gMaxPlayers )
		get_user_name(topBombPID, BombPName, charsmax(BombPName))
	if ( 1 <= topBombDID <= gMaxPlayers )
		get_user_name(topBombDID, BombDName, charsmax(BombDName))
	
	for ( new i ; i < pnum ; i++ )
	{
		tempid = players[i]
		
		if ( g_TotalKills[tempid] == topKills && tempid != topKillerID && g_TotalKills[tempid]  )
		{
			new lineToAdd[65] = ", "
			new pName[64]
			get_user_name(tempid, pName, charsmax(pName))
			add(lineToAdd, charsmax(lineToAdd), pName)
			add(KillerName, charsmax(KillerName) - strlen(BombDName) , lineToAdd)
		}
		
		if ( g_TotalDeaths[tempid] == topDeaths && tempid != topDeathsID && g_TotalDeaths[tempid]  )
		{
			new lineToAdd[65] = ", "
			new pName[64]
			get_user_name(tempid, pName, charsmax(pName))
			add(lineToAdd, charsmax(lineToAdd), pName)
			add(DeathsName, charsmax(DeathsName) - strlen(DeathsName) , lineToAdd)
		}
		
		if ( g_BombPlants[tempid] == topBombP && tempid != topBombPID && g_BombPlants[tempid]  )
		{
			new lineToAdd[65] = ", "
			new pName[64]
			get_user_name(tempid, pName, charsmax(pName))
			add(lineToAdd, charsmax(lineToAdd), pName)
			add(BombPName, charsmax(BombPName) - strlen(BombPName) , lineToAdd)
		}
		
		if ( g_BombDefusions[tempid] == topBombD && tempid != topBombDID && g_BombDefusions[tempid]  )
		{
			new lineToAdd[65] = ", "
			new pName[64]
			get_user_name(tempid, pName, charsmax(pName))
			add(lineToAdd, charsmax(lineToAdd), pName)
			add(BombDName, charsmax(BombDName) - strlen(BombDName) , lineToAdd)
		}
	}
	

	msgToDisplay = "Match Player Rankings^n-----------------------------^n^nTop Kills - %s [%d Kills]^nTop Deaths - %s [%d Deaths]^nTop Bomb Plants - %s [%d Bomb Plants]^nTop Bomb Defusions - %s [%d Bomb Defusions]^n%s Total Leavers - %d"
	format(msgToDisplay, charsmax(msgToDisplay), msgToDisplay, strlen(KillerName) ? KillerName : "NONE", topKills, strlen(DeathsName) ? DeathsName : "NONE", topDeaths,
			strlen(BombPName) ? BombPName : "NONE", topBombP, strlen(BombDName) ? BombDName : "NONE", topBombD, prefix, g_TotalLeaves)
			
	new taskId = 6969        
	set_task(1.0, "displayRankingTable", taskId, msgToDisplay, strlen(msgToDisplay), "b")

	#if defined SOUND
    PlaySound(4);
    #endif

    //Take Vote Now
    if(get_pcvar_num(cvar_automap) == 1)
    {
    	set_task(0.5, "StartVote")
    }
}

public displayRankingTable(msgToDisplay[], taskId)
{
	set_hudmessage(135, 135, 135, -1.0, -1.0,  0, 6.0, 6.0, 0.5, 0.15, -1)
	show_hudmessage(0, msgToDisplay)
}


// ====================== FUNCTIONS!! ===========================================================================================

//Prevent from choosing team while match is going on.
public cmdChooseTeam(id)
{
    if(g_MatchInit || g_KnifeRound || g_MatchStarted)
    {
        
        if (cs_get_user_team(id) == CS_TEAM_SPECTATOR)
        return PLUGIN_HANDLED;
        client_print_color(id, print_team_default, "^4%s ^3You cannot ^4choose ^3a team ^1while ^4Match ^1is ^3going on.", prefix);
        return PLUGIN_HANDLED;
    }
	
    return PLUGIN_CONTINUE;
}

//Checking for knife
public Event_CurWeapon_NotKnife(id)
{
	if(!g_KnifeRound) 
		return 

	if(!user_has_weapon(id, CSW_KNIFE))
		give_item(id, "weapon_knife") 
		engclient_cmd(id, "weapon_knife")
}


//Swap teams.
public cmdTeamSwap()
{
	
	new players[32], num
	get_players(players, num)
	
	new player
	for(new i = 0; i < num; i++)
	{
		player = players[i]

        
        //rg_set_user_team(iPlayer,TEAM_CT,MODEL_AUTO,true)
		rg_set_user_team(player, cs_get_user_team(player) == CS_TEAM_T ? TEAM_CT:TEAM_TERRORIST,MODEL_AUTO,true)
	}
	
	return PLUGIN_HANDLED
}

public SwapPlayer()
{

	new players[32], num
	get_players(players, num)

	new player
	for(new i = 0; i < num; i++)
	{
		player = players[i]
		if(get_user_team(player) != 3)
        {

            rg_set_user_team(player, cs_get_user_team(player) == CS_TEAM_T ? TEAM_CT:TEAM_TERRORIST,MODEL_AUTO,true)
             //cs_set_user_team(player, cs_get_user_team(player) == CS_TEAM_T ? CS_TEAM_CT:CS_TEAM_T)
        }
	}
	
	return PLUGIN_HANDLED
}

public cmdTransferAllInSpec()
{

	new Players[32] 
	new playerCount, player 
	get_players(Players, playerCount, "h")

	for(new i=0; i < playerCount; i++)
	{  
        player = Players[i]

        if(is_user_connected(player))
        {
            new CsTeams:team = cs_get_user_team(player)

            if(!(team == CS_TEAM_UNASSIGNED) || !(team == CS_TEAM_SPECTATOR) )
            {
                user_kill(player)
                //cs_set_user_team(player, CS_TEAM_SPECTATOR)
                set_task(3.0,"DoTransferSpec",player)
            }
            else
            {
                user_kill(player)
            }
        }

	}

	return PLUGIN_HANDLED;
}


public DoTransferSpec(id)
{
    if(is_user_connected(id))
    {
        user_kill(id)
        rg_set_user_team(id, TEAM_SPECTATOR,MODEL_AUTO,true)
    }
    
}

public StartMatch()
{

    server_cmd("mp_forcechasecam 2")
    server_cmd("mp_forcecamera 2")


    set_cvar_string("amx_warname","Started!")

    set_task( 3.0, "GiveRestartRound", _, _, _, "a", 3 ); 

    g_MatchInit = false
    
    CaptainSChosen = false
    
    client_print_color(0, print_team_default, "^3%s ^1Please ^4Try ^1Not to ^3Leave ^4The Match!", prefix)
    client_print_color(0, print_team_default, "^3%s ^3First Half ^4Started", prefix)
    client_print_color(0, print_team_default, "^3%s ^4Attention ! ^1The ^3Match ^1Has Been ^4 STARTED !", prefix)

    new ServerName[512]

    //change server name
    formatex(ServerName,charsmax(ServerName),"%s- %s VS. %s In Progress", prefix, FirstCaptainName,SecondCaptainName)

    server_cmd("hostname ^"%s^"",ServerName)

    ServerName[0] = 0

    set_task(11.0,"MatchStartedTrue")


    //Set the status of half to first half.
    isFirstHalfStarted = true

    #if defined LIVE_DHUD
    set_task(12.0, "ShowHUD_LiveLive");
    #else
    set_task(12.0,"FirstHalfHUDMessage")
    #endif

    #if defined SOUND
    PlaySound(2);
    #endif
}

//Swap teams for Overtime message.
public SwapTeamsOverTimeMessage()
{
    GiveRestartRound()

    set_task(3.0,"TeamSwapMessage")

    set_task(7.0,"FirstHalfOvertimeCompletedHUDMessage")

    set_task(12.0,"SwapTeamsAndRestartMatchOT") 
}

//Swap Team Message !.
public SwapTeamsMessage()
{

    GiveRestartRound()

    set_task(3.0,"TeamSwapMessage")

    set_task(7.0,"FirstHalfCompletedHUDMessage")

    set_task(12.0,"SwapTeamsAndRestartMatch")
}

//Swap teams and restart the match OT.
public SwapTeamsAndRestartMatchOT()
{
    //Swap Teams.
    cmdTeamSwap()

    GiveRestartRound();

    set_task(2.0,"LiveOnThreeRestart");

    //Give Restart
    set_task(4.0, "GiveRestartRound", _, _, _, "a", 3 ); 

    client_print_color(0, print_team_default, "^3%s OT ^4Teams ^1Have Been ^4Swapped !", prefix);
    client_print_color(0, print_team_default, "^3%s OT ^4Over Time ^1- ^3%i ^4Second half ^1has been ^4Started !", prefix, OTCount);
    client_print_color(0, print_team_default, "^3%s OT ^4Over Time ^1- ^3%i ^4Second half ^1has been ^4Started !", prefix, OTCount);

    is_secondHalf = true

    //Set first half status to zero.
    isFirstHalfStarted = false
    isSecondHalfStarted = true
    set_task(14.0,"SecondHalfOverTimeHUDMessage")

    LoadMatchSettings()
}

//Swap teams and restart the match.
public SwapTeamsAndRestartMatch()
{
    //Swap Teams.
    cmdTeamSwap()

    GiveRestartRound();

    set_task(2.0,"LiveOnThreeRestart");

    //Give Restart
    set_task(4.0, "GiveRestartRound", _, _, _, "a", 3 ); 

    client_print_color(0, print_team_default, "^3%s ^4Teams ^1Have Been ^4Swapped !", prefix);
    client_print_color(0, print_team_default, "^3%s ^4Second half ^1has been ^4Started !", prefix);
    
    is_secondHalf = true

    //Set first half status to zero.
    isFirstHalfStarted = false
    isSecondHalfStarted = true

    #if defined LIVE_DHUD
    set_task(12.0, "ShowHUD_LiveLive");
    #else
    set_task(14.0,"SecondHalfHUDMessage")
    #endif

    LoadMatchSettings()

    #if defined SOUND
	PlaySound(3);
	#endif
}


public ShowScoreHud()
{

    new score_message[1024]

    if(ScoreFtrstTeam > ScoreScondteam)
    {
        format(score_message, 1023, "* %s Team [ %s ] winning %i to  %i ", prefix, FirstCaptainName,ScoreFtrstTeam,ScoreScondteam)

        set_dhudmessage(255, 255, 0, 0.0, 0.90, 0, 2.0, 5.0, 0.8, 0.8)
        show_dhudmessage(0, score_message)
    }

    if(ScoreScondteam > ScoreFtrstTeam)
    {
        format(score_message, 1023, "* %s Team [ %s ] winning %i To %i", prefix, SecondCaptainName,ScoreScondteam,ScoreFtrstTeam)

        set_dhudmessage(255, 255, 0, 0.0, 0.90, 0, 2.0, 5.0, 0.8, 0.8)
        show_dhudmessage(0, score_message)
    }

    if(ScoreFtrstTeam == ScoreScondteam)
    {
        format(score_message, 1023, "* %s Both Teams Have Won %i Rounds.", prefix, ScoreScondteam)

        set_dhudmessage(255, 255, 0, 0.0, 0.90, 0, 2.0, 5.0, 0.8, 0.8)
        show_dhudmessage(0, score_message)
    }
}

public CheckForWinningTeam()
{

    if(g_OverTime)
    {
        //Check for the overtime winners.
        if(ScoreFtrstTeam >= 4)
        {
            //First team won the match!
            //Change description of the game.
            
            new GameDescBuffer[32]
            formatex(GameDescBuffer,charsmax(GameDescBuffer),"GG! %d To %d",ScoreFtrstTeam,ScoreScondteam)

            set_cvar_string("amx_warname",GameDescBuffer)
           
            server_cmd("mp_freezetime 99999");
            set_task(7.0,"FirstTeamWinnerMessage")
        }

        if(ScoreScondteam >= 4)
        {
            //Second team won the match.
            new GameDescBuffer[32]
            formatex(GameDescBuffer,charsmax(GameDescBuffer),"GG! %d To %d",ScoreScondteam,ScoreFtrstTeam)
            set_cvar_string("amx_warname",GameDescBuffer)

            // set_task(8.0,"StartSongForAll")

           
            server_cmd("mp_freezetime 99999");
            set_task(7.0,"SecondTeamWinnerMessage") 
        }

        if((ScoreFtrstTeam == 3) & (ScoreScondteam == 3))
        {


            //Draw. Start next OT. & OT count++.
            OTCount++
            RoundCounter = 0
            ScoreFtrstTeam = 0
            ScoreScondteam = 0
        
            new GameDescBuffer[32]
            formatex(GameDescBuffer,charsmax(GameDescBuffer),"Draw! Over-Time: %i",OTCount)

            set_cvar_string("amx_warname",GameDescBuffer)

            server_cmd("mp_freezetime 99999");
            server_cmd("sv_restart 1");
            
            set_task(2.0,"MatchDrawMessageOT")
        }

    }
    else
    {
        if(ScoreFtrstTeam >= 16)
        {
            //Change description of the game.
            
            new GameDescBuffer[32]
            formatex(GameDescBuffer,charsmax(GameDescBuffer),"GG! %d To %d",ScoreFtrstTeam,ScoreScondteam)

            // set_task(8.0,"StartSongForAll")

            set_cvar_string("amx_warname",GameDescBuffer)
            
            server_cmd("mp_freezetime 99999");
            set_task(7.0,"FirstTeamWinnerMessage")
            
        }

        if(ScoreScondteam >= 16)
        {   

            new GameDescBuffer[32]
            formatex(GameDescBuffer,charsmax(GameDescBuffer),"GG! %d To %d",ScoreScondteam,ScoreFtrstTeam)
            set_cvar_string("amx_warname",GameDescBuffer)

            
            server_cmd("mp_freezetime 99999");
            set_task(7.0,"SecondTeamWinnerMessage") 
        }
    
        if((ScoreFtrstTeam == 15) & (ScoreScondteam == 15))
        {

            set_cvar_string("amx_warname","Draw! Over-Time 1")

            server_cmd("mp_freezetime 99999");
            server_cmd("sv_restart 1");

            g_MatchStarted = false
            
            //OT STEP 1
            set_task(2.0,"MatchDrawMessage")
        }
    }

}
// Transfer a player to spec.
public TransferToSpec(id)
{
    if(is_user_connected(id))
    {
        new CsTeams:team = cs_get_user_team(id)
   
        if( is_user_connected(id) && (team != CS_TEAM_UNASSIGNED) && (team != CS_TEAM_SPECTATOR) )
        {
            new TransferedName[32] 
            get_user_name(id, TransferedName, charsmax(TransferedName))

            user_kill(id)
            //cs_set_user_team(id, CS_TEAM_SPECTATOR)
            //rg_set_user_team(id, TEAM_SPECTATOR,MODEL_AUTO,true)

            set_task(3.0,"DoTransferSpec",id)

        }
    }
    
    
    return PLUGIN_HANDLED
}


//Winner message. - First team won!
public FirstTeamWonTheMatch()
{
	set_dhudmessage(0, 255, 0, -1.0, -1.0, 0, 2.0, 6.0, 0.8, 0.8)
	show_dhudmessage(0,"Team [ %s ]  Won The Match !! ^n GG WP To Team %s ..",FirstCaptainName,FirstCaptainName)

	set_cvar_string("amx_warname","|| WAR About To Start! ||")
}

//Winner message. - Second team won!
public SecondTeamWonTheMatch()
{
	set_dhudmessage(0, 255, 0, -1.0, -1.0, 0, 2.0, 6.0, 0.8, 0.8)
	show_dhudmessage(0,"Team [ %s ] Won The Match !! ^n GG WP To Team %s  !",SecondCaptainName,SecondCaptainName)


	set_cvar_string("amx_warname","|| WAR About To Start! ||")
}

//Load Match settings because match has been started !
public LoadMatchSettings()
{
	server_cmd("exec %s", warcfg)
	server_cmd("sv_alltalk 0")
	server_cmd("mp_autoteambalance 2")
	server_cmd("mp_freezetime 8")
}

//Load PuB settings because Match is over!
public LoadPubSettings()
{

	set_cvar_string("amx_warname","|| WAR About To Start! ||")

	//Set some zero.
	CaptainChoosenID = 0
	WhoChoseThePlayer = 0
	g_TotalLeaves = 0
	g_TotalKills[0] = 0
	g_TotalDeaths[0] = 0
	g_BombPlants[0] = 0
	g_BombDefusions[0] = 0
	msgToDisplay[0] = 0
	remove_task(6969)

	//ALL HALF STATUS TO FALSE.
	isFirstHalfStarted = false
	isSecondHalfStarted = false

	FirstCaptainTeamName = 0
	SecondCaptainTeamName = 0

	MatchStarterOwner = 0
	CaptainSChosen = false

	g_KnifeRound = false

	is_secondHalf = false
	g_MatchInit = false
	g_MatchStarted = false
	g_MainMatchStarted = false
	RoundCounter = 0

	gCptT = 0
	gCptCT = 0
	CaptainCount = 0

	ScoreFtrstTeam = 0
	ScoreScondteam = 0

	ShowMenuFirst = 0
	ShowMenuSecond = 0



	FirstCaptainName[0] = 0
	SecondCaptainName[0] = 0

	TempFirstCaptain[0] = 0
	TempSecondCaptain[0] = 0

	server_cmd("exec server.cfg")
	set_task( 3.0, "GiveRestartRound", _, _, _, "a", 1 ); 
}

public FirstTeamWinnerMessage()
{

    GiveRestartRound()


    set_task(3.0,"MatchIsOverHUDMessage")
    set_task(7.0,"SecondHalfCompletedHUDMessage")
    set_task(13.0,"FirstTeamWonTheMatch")
    set_task(20.0,"DoRanking")
    set_task(32.0,"LoadPubSettings")
}

public SecondTeamWinnerMessage()
{
    GiveRestartRound()

    set_task(3.0,"MatchIsOverHUDMessage")
    set_task(7.0,"SecondHalfCompletedHUDMessage")
    set_task(13.0,"SecondTeamWonTheMatch")
    set_task(20.0,"DoRanking")
    set_task(32.0,"LoadPubSettings")
}

public MatchDrawMessage()
{
    set_task(3.0,"MatchIsDrawHUDMessage")
    
    if(get_pcvar_num(cvar_overtime) == 1)
    {
	    set_task(7.0,"OverTimeStartMessage")

	    //OT STEP 2
	    OverTimeSettings()
	    set_task(13.0,"SwapTeamsAndStartOverTimeFirstHalf")
	}
	else 
	{
		set_task(7.0,"DoRanking")
		set_task(13.0,"LoadPubSettings")
	}
}

// Over time Draw Message.
public MatchDrawMessageOT()
{
    set_task(3.0,"MatchIsDrawOTHUDMessage")
    set_task(7.0,"OverTimeStartMessage")

    set_task(13.0,"SwapTeamsAndStartOverTimeFirstHalf")
}

public OverTimeSettings()
{
    ScoreFtrstTeam = 0
    ScoreScondteam = 0
    g_OverTime = true
    RoundCounter = 0
    OTCount++
}

public SwapTeamsAndStartOverTimeFirstHalf()
{

    //OT STEP 3

    //Swap Teams.
    cmdTeamSwap()

    GiveRestartRound();

    set_task(2.0,"LiveOnThreeRestart");

    //Give Restart
    set_task(4.0, "GiveRestartRound", _, _, _, "a", 3 ); 

    client_print_color(0, print_team_default, "^3%s OT ^4Teams ^1Have Been ^4Swapped !", prefix);
    client_print_color(0, print_team_default, "^3%s OT ^4Over Time ^1- ^3%i ^4First Half ^1has been ^4Started !", prefix, OTCount);
    client_print_color(0, print_team_default, "^3%s OT ^4Over Time ^1- ^3%i ^4First Half ^1has been ^4Started !", prefix, OTCount);
    client_print_color(0, print_team_default, "^3%s OT ^4OverTime Number ^1: ^3%i", prefix, OTCount);

    g_MatchStarted = true

    is_secondHalf = false

    //Set first half status to zero.
    isFirstHalfStarted = true
    isSecondHalfStarted = false
    set_task(14.0,"OverTimeFirstHalfLiveMessage")

    LoadMatchSettings()

}

public OverTimeStartMessage()
{
    set_dhudmessage(0,255, 0, -1.0, -1.0, 0, 2.0, 4.0, 0.8, 0.8)
    show_dhudmessage(0, "Teams will be Swapped Automatically. ^n OverTime [%i] Will Start Now!",OTCount) 
}

public SecondCaptWonKnifeRoundWonMessage(id)
{
    set_dhudmessage(255, 255, 255, -1.0, -1.0, 0, 2.0, 3.0, 0.8, 0.8)
    show_dhudmessage(0,"Captain [ %s ] Won the Knife Round !",FirstCaptainName)

    client_print_color(0, print_team_default, "^3%s ^4Captain ^3%s ^4Won ^1the ^3Knife Round !", prefix, FirstCaptainName)

    //Match Stats: Step -2 : Insert the Knife winner in the database.========
    new KnifeRoundWonSteamID[128] 
    get_user_authid(gCptCT, KnifeRoundWonSteamID, 127)

    set_task(5.0,"ChooseTeam",gCptCT)
    
}

public FirstCaptainWonKnifeRoundMessage(id)
{
	set_dhudmessage(255, 255, 255, -1.0, -1.0, 0, 2.0, 3.0, 0.8, 0.8)
	show_dhudmessage(0,"Captain [ %s ] Won the Knife Round !",FirstCaptainName)

	client_print_color(0, print_team_default, "^3%s ^4Captain ^3%s ^4Won ^1the ^3Knife Round !", prefix, FirstCaptainName)

	set_task(5.0,"ChooseTeam",gCptT)
    
}

public ShowScoreToUser(id)
{
    if(g_MatchStarted)
    {

        if(isFirstHalfStarted)
        {
            if(( FirstCaptainTeamName == 1) && (get_user_team(id) == 2))
            {
                client_print_color(id, print_team_default, "^3%s ^1Your ^4Team's Score ^1is: ^3%i | ^4Opponent's Team ^3Score: ^3 %i", prefix, ScoreScondteam,ScoreFtrstTeam)
            }
            
            if(( FirstCaptainTeamName == 1 ) && (get_user_team(id) == 1)  )
            {    
                client_print_color(id, print_team_default, "^3%s ^1Your ^4Team's Score ^1is: ^3%i | ^4Opponent's Team ^3Score: ^3 %i", prefix, ScoreFtrstTeam,ScoreScondteam)
            }

            if((FirstCaptainTeamName == 2) && (get_user_team(id)) == 2)
            {
               client_print_color(id, print_team_default, "^3%s ^1Your ^4Team's Score ^1is: ^3%i | ^4Opponent's Team ^3Score: ^3 %i", prefix, ScoreFtrstTeam,ScoreScondteam)
            }

            if( (FirstCaptainTeamName == 2) && (get_user_team(id) == 1) )
            {
                client_print_color(id, print_team_default, "^3%s ^1Your ^4Team's Score ^1is: ^3%i | ^4Opponent's Team ^3Score: ^3 %i", prefix, ScoreScondteam,ScoreFtrstTeam)
            }
        }

        if(isSecondHalfStarted)
        {
            if(( FirstCaptainTeamName == 1) && (get_user_team(id) == 2))
            {
                client_print_color(id, print_team_default, "^3%s ^1Your ^4Team's Score ^1is: ^3%i | ^4Opponent's Team ^3Score: ^3 %i", prefix, ScoreFtrstTeam,ScoreScondteam)
            }
            
            if(( FirstCaptainTeamName == 1 ) && (get_user_team(id) == 1)  )
            {    
                client_print_color(id, print_team_default, "^3%s ^1Your ^4Team's Score ^1is: ^3%i | ^4Opponent's Team ^3Score: ^3 %i", prefix, ScoreScondteam,ScoreFtrstTeam)
            }

            if((FirstCaptainTeamName == 2) && (get_user_team(id)) == 2)
            {
                client_print_color(id, print_team_default, "^3%s ^1Your ^4Team's Score ^1is: ^3%i | ^4Opponent's Team ^3Score: ^3 %i", prefix, ScoreScondteam,ScoreFtrstTeam)
            }

            if( (FirstCaptainTeamName == 2) && (get_user_team(id) == 1) )
            {
                client_print_color(id, print_team_default, "^3%s ^1Your ^4Team's Score ^1is: ^3%i | ^4Opponent's Team ^3Score: ^3 %i", prefix, ScoreFtrstTeam,ScoreScondteam)
            }
        }
    }
}

public ShowScoreOnRoundStart()
{

    new players[32],num,iPlayer
    get_players(players,num,"h");
    

    for(new i=0;i<num;i++)
    {
        iPlayer = players[i];

        if(isFirstHalfStarted)
        {
            if(( FirstCaptainTeamName == 1) && (get_user_team(iPlayer) == 2))
            {
                client_print_color(iPlayer, print_team_default, "^3%s ^1Your ^4Team's Score ^1is: ^3%i | ^4Opponent's Team ^3Score: ^3 %i", prefix, ScoreScondteam,ScoreFtrstTeam)
            }
            
            if(( FirstCaptainTeamName == 1 ) && (get_user_team(iPlayer) == 1)  )
            {    
                client_print_color(iPlayer, print_team_default, "^3%s ^1Your ^4Team's Score ^1is: ^3%i | ^4Opponent's Team ^3Score: ^3 %i", prefix, ScoreFtrstTeam,ScoreScondteam)
            }

            if((FirstCaptainTeamName == 2) && (get_user_team(iPlayer)) == 2)
            {
                client_print_color(iPlayer, print_team_default, "^3%s ^1Your ^4Team's Score ^1is: ^3%i | ^4Opponent's Team ^3Score: ^3 %i", prefix, ScoreFtrstTeam,ScoreScondteam)
            }

            if( (FirstCaptainTeamName == 2) && (get_user_team(iPlayer) == 1) )
            {
                client_print_color(iPlayer, print_team_default, "^3%s ^1Your ^4Team's Score ^1is: ^3%i | ^4Opponents ^3Score: ^3 %i", prefix, ScoreScondteam,ScoreFtrstTeam)
            }
        }

        if(isSecondHalfStarted)
        {
            if(( FirstCaptainTeamName == 1) && (get_user_team(iPlayer) == 2))
            {
                client_print_color(iPlayer, print_team_default, "^3%s ^1Your ^4Team's Score ^1is: ^3%i | ^4Opponent's Team ^3Score: ^3 %i", prefix, ScoreFtrstTeam,ScoreScondteam)
            }
            
            if(( FirstCaptainTeamName == 1 ) && (get_user_team(iPlayer) == 1)  )
            {    
                client_print_color(iPlayer, print_team_default, "^3%s ^1Your ^4Team's Score ^1is: ^3%i | ^4Opponent's Team ^3Score: ^3 %i", prefix, ScoreScondteam,ScoreFtrstTeam)
            }

            if((FirstCaptainTeamName == 2) && (get_user_team(iPlayer)) == 2)
            {
                client_print_color(iPlayer, print_team_default, "^3%s ^1Your ^4Team's Score ^1is: ^3%i | ^4Opponent's Team ^3Score: ^3 %i", prefix, ScoreScondteam,ScoreFtrstTeam)
            }

            if( (FirstCaptainTeamName == 2) && (get_user_team(iPlayer) == 1) )
            {
                client_print_color(iPlayer, print_team_default, "^3%s ^1Your ^4Team's Score ^1is: ^3%i | ^4Opponent's Team ^3Score: ^3 %i", prefix, ScoreFtrstTeam,ScoreScondteam)
            }
        }
    }
    
}

//To restart the round.
public GiveRestartRound( ) 
{ 
    server_cmd( "sv_restartround ^"1^"" ); 
} 

//All MESSAGES.
public FirstHalfHUDMessage()
{
    set_dhudmessage(0, 255, 255, -1.0, -1.0, 0, 2.0, 3.0, 0.8, 0.8)
    show_dhudmessage(0,"={ First Half Started ! }=^n --[ %s ]--^n--[ %s ]--^n--[ %s ]--","LIVE !!! GL & HF","LIVE !!! GL & HF","LIVE !!! GL & HF")
}

public SecondHalfHUDMessage()
{

    new players[32], num
    get_players(players, num,"h")
    
    new player
    for(new i = 0; i < num; i++)
    {
        player = players[i]
        if(is_user_connected(player))
        {
            set_user_frags(player,Frags[player])
            cs_set_user_deaths(player,Deaths[player])
        }

    }

    set_dhudmessage(0, 255, 255, -1.0, -1.0, 0, 2.0, 3.0, 0.8, 0.8)
    show_dhudmessage(0,"={ Second Half Started ! }=^n --[ %s ]--^n--[ %s ]--^n--[ %s ]--","LIVE !!!","LIVE !!! ","LIVE !!! ")
}

public SecondHalfOverTimeHUDMessage()
{

    new players[32], num
    get_players(players, num,"h")
    
    new player
    for(new i = 0; i < num; i++)
    {
        player = players[i]
        if(is_user_connected(player))
        {
            set_user_frags(player,Frags[player])
            cs_set_user_deaths(player,Deaths[player])
        }

    }

    set_dhudmessage(0, 255, 255, -1.0, -1.0, 0, 2.0, 3.0, 0.8, 0.8)
    show_dhudmessage(0,"={ OT Second Half Started ! }=^n --[ %s ]--^n--[ %s ]--^n--[ %s ]--","LIVE !!!","LIVE !!! ","LIVE !!! ")
}

public OverTimeFirstHalfLiveMessage()
{
    set_dhudmessage(0, 255, 255, -1.0, -1.0, 0, 2.0, 3.0, 0.8, 0.8)
    show_dhudmessage(0,"={ OT First Half Started ! }=^n --[ %s ]--^n--[ %s ]--^n--[ %s ]--","LIVE !!!","LIVE !!! ","LIVE !!! ")
}

//FirstHalfOvertimeCompletedHUDMessage
//SwapTeamsOverTimeMessage
public FirstHalfOvertimeCompletedHUDMessage()
{

    new score_message[1024]

    if(ScoreFtrstTeam > ScoreScondteam)
    {
        format(score_message, 1023, "={ First Half OT }= ^n %s - %i ^n Winning to ^n %s - %i",FirstCaptainName,ScoreFtrstTeam,SecondCaptainName,ScoreScondteam)


        set_dhudmessage(0,255, 0, -1.0, -1.0, 0, 2.0, 4.0, 0.8, 0.8)
        show_dhudmessage(0, score_message)
    }

    if(ScoreScondteam > ScoreFtrstTeam)
    {
        format(score_message, 1023, "={ First Falf OT }= ^n %s - %i ^n Winning to ^n %s - %i",SecondCaptainName,ScoreScondteam,FirstCaptainName,ScoreFtrstTeam)


        set_dhudmessage(0,255, 0, -1.0, -1.0, 0, 2.0, 4.0, 0.8, 0.8)
        show_dhudmessage(0, score_message)
    }

    if(ScoreFtrstTeam == ScoreScondteam)
    {
        format(score_message, 1023, "OT - Both Teams Have Won %i Rounds.",ScoreScondteam)

        set_dhudmessage(0,255, 0, -1.0, -1.0, 0, 2.0, 4.0, 0.8, 0.8)
        show_dhudmessage(0, score_message)
    }

}

public FirstHalfCompletedHUDMessage()
{
    new score_message[1024]

    if(ScoreFtrstTeam > ScoreScondteam)
    {
        format(score_message, 1023, "={ First Half Score }= ^n %s - %i ^n Winning to ^n %s - %i",FirstCaptainName,ScoreFtrstTeam,SecondCaptainName,ScoreScondteam)

        set_dhudmessage(0,255, 0, -1.0, -1.0, 0, 2.0, 4.0, 0.8, 0.8)
        show_dhudmessage(0, score_message)
    }

    if(ScoreScondteam > ScoreFtrstTeam)
    {
        format(score_message, 1023, "={ First Falf Score }= ^n %s - %i ^n Winning to ^n %s - %i",SecondCaptainName,ScoreScondteam,FirstCaptainName,ScoreFtrstTeam)

        set_dhudmessage(0,255, 0, -1.0, -1.0, 0, 2.0, 4.0, 0.8, 0.8)
        show_dhudmessage(0, score_message)
    }

    if(ScoreFtrstTeam == ScoreScondteam)
    {
        format(score_message, 1023, "Both Teams Have Won %i Rounds.",ScoreScondteam)

        set_dhudmessage(0,255, 0, -1.0, -1.0, 0, 2.0, 4.0, 0.8, 0.8)
        show_dhudmessage(0, score_message)
    }
}

public SecondHalfCompletedHUDMessage()
{
    new score_message[1024]

    if(ScoreFtrstTeam > ScoreScondteam)
    {
        format(score_message, 1023, "={ Match Score }=^n %s - %i ^n Winning To ^n %s - %i",FirstCaptainName,ScoreFtrstTeam,SecondCaptainName,ScoreScondteam)

        set_dhudmessage(0,255, 0, -1.0, -1.0, 0, 2.0, 4.0, 0.8, 0.8)
        show_dhudmessage(0, score_message)
    }

    if(ScoreScondteam > ScoreFtrstTeam)
    {
        format(score_message, 1023, "={ Match Score }=^n %s - %i ^n Winning to ^n %s - %i",SecondCaptainName,ScoreScondteam,FirstCaptainName,ScoreFtrstTeam)

        set_dhudmessage(0,255, 0, -1.0, -1.0, 0, 2.0, 4.0, 0.8, 0.8)
        show_dhudmessage(0, score_message)
    }

    if(ScoreFtrstTeam == ScoreScondteam)
    {
        format(score_message, 1023, "={ Match Score }=^n Both Teams Have Won %i Rounds.")

        set_dhudmessage(0,255, 0, -1.0, -1.0, 0, 2.0, 6.0, 0.8, 0.8)
        show_dhudmessage(0, score_message)
    }

}

public MatchIsOverHUDMessage()
{
    set_dhudmessage(0,255, 0, -1.0, -1.0, 0, 2.0, 3.0, 0.8, 0.8)
    show_dhudmessage(0,"={ Match Is Over }=")
}

public MatchIsDrawHUDMessage()
{

    set_dhudmessage(0,255, 0, -1.0, -1.0, 0, 2.0, 3.0, 0.8, 0.8)
    show_dhudmessage(0,"={ Match Is Draw!! }=")
}
//IF OT Match is Draw!
public MatchIsDrawOTHUDMessage()
{
    set_dhudmessage(0,255, 0, -1.0, -1.0, 0, 2.0, 3.0, 0.8, 0.8)
    show_dhudmessage(0,"={ OverTime Match Draw!!^n Next OverTime Will start Now! }=")  
}

public TeamSwapMessage()
{
    set_dhudmessage(255, 255, 0, -1.0, -1.0, 0, 2.0, 3.0, 0.8, 0.8)
    show_dhudmessage(0,"First Half Over! ^n Teams will be swapped Automatically. Please do not change the Team! ^n Second Half will start Now!")
}

public MatchStartedTrue()
{
    server_cmd("mp_autokick 1")
    g_MatchStarted = true

    set_task(30.0,"SetMainMatchStartedTrue")

}


public SetMainMatchStartedTrue()
{
    g_MainMatchStarted = true
}


public LiveOnThreeRestart()
{

    set_dhudmessage(42, 255, 212, -1.0, -1.0, 0, 2.0, 3.0, 0.8, 0.8)
    show_dhudmessage(0,"-{ LiVe On 3 RestartS }- ^n-= LO3 =-")
}

#if defined LIVE_DHUD
public ShowHUD_LiveLive()
{
	set_task( 0.2, "HUD_LiveLive", _, _, _, "a", sizeof( HUD_XY_POS ) * 2 );
}

public HUD_LiveLive( index )
{
	if( iXYPos >= sizeof( HUD_XY_POS ) ) iXYPos = 0;
	set_dhudmessage( random_num( 0, 255 ), random_num( 0, 255 ), random_num( 0, 255 ), HUD_XY_POS[ iXYPos ][ 0 ], HUD_XY_POS[ iXYPos ][ 1 ], 0, 50.0, 0.3, 0.4, 0.4 );
	show_dhudmessage( index, "[   L   I   V   E   ]          [   %s   ]          [   %s   ]             [   L   I   V   E   ]", isFirstHalfStarted ? "FIRST HALF" : "SECOND HALF" , isFirstHalfStarted ? "FIRST HALF" : "SECOND HALF" );
	iXYPos++;
}
#endif

// Auto Map Vote
public StartVote()  
{  
	getmaps() 
	new rnd 
	while (g_DoneMaps != 4 && g_MapsCounter > 0) { 
		rnd = random(g_MapsCounter) 
		copy(g_MapsChosen[g_DoneMaps++], 19, g_MapsAvailable[rnd]) 
		g_MapsAvailable[rnd] = g_MapsAvailable[--g_MapsCounter] 
	}         

	new title[64], extend[64]
	formatex(title, charsmax(title), "Auto Change Map^n")
	formatex(extend, charsmax(extend), "Extend Current Map")
	g_gVoteMenu = menu_create(title,"votemap")
	
	new num[11] 
	for(new i = 0; i < g_DoneMaps; i++)  { 
		num_to_str(i, num, 10) 
		menu_additem(g_gVoteMenu, g_MapsChosen[i], num, 0)
	}
	menu_additem(g_gVoteMenu, extend, "4", 0) 
	menu_setprop(g_gVoteMenu, MPROP_EXIT, MEXIT_NEVER)
	
	new players[32], pnum, tempid; 
	get_players(players, pnum, "ch"); 
	
	for( new i; i<pnum; i++)
	{ 
		tempid = players[i]; 
		menu_display(tempid, g_gVoteMenu); 
	}

	client_cmd(0, "spk ^"get red(e80) ninety(s45) to check(e20) use bay(s18) mass(e42) cap(s50)^"") 
	set_task(10.0, "EndVote");
	return PLUGIN_HANDLED;
} 

public votemap(id, menu, item) {

	if(item == MENU_EXIT) 
	{
		return PLUGIN_HANDLED
	}
	
	new data[6], szName[64];
	new access, callback;
	menu_item_getinfo(menu, item, access, data,charsmax(data), szName,charsmax(szName), callback);
	new voteid = str_to_num(data);
	new playerna[32]
	get_user_name(id, playerna, 31)
	
	if(voteid != 4)
		client_print_color(0, 0, "^4%s ^3%s ^1voted for ^4[ ^3%s ^4]", prefix, playerna, g_MapsChosen[voteid])
	else 
		client_print_color(0, 0, "^4%s ^3%s ^1voted to ^4extend ^3the ^1current map.", prefix, playerna)
	
	g_gVotes[voteid]++;
	return PLUGIN_HANDLED;
}

public getmaps() { 
	new mapsfile = fopen(g_Maps_Ini_File, "r") 
	new linefortest[50] 
     
	while (g_MapsCounter < sizeof(g_MapsAvailable) && !feof(mapsfile)) { 
		fgets(mapsfile, linefortest, 49) 
		trim(linefortest) 
		
		new getcurrentmap[32]
		get_mapname(getcurrentmap, 31)
		
		if ((is_map_valid(linefortest)) && (!equali(linefortest, getcurrentmap))) 
			copy(g_MapsAvailable[g_MapsCounter++], 24, linefortest)  
	} 
     
	fclose(mapsfile) 
} 

public EndVote() { 
	show_menu(0, 0, "^n", 1); 
	new best = 0; 
	for(new i = 1; i < sizeof(g_gVotes); i++) { 
		if(g_gVotes[i] > g_gVotes[best]) 
		best = i; 
	}
	
	g_gVotes[0] = 0
	g_gVotes[1] = 0
	g_gVotes[2] = 0
	g_gVotes[3] = 0
	g_gVotes[4] = 0
	
	if(best == 4) { 
		client_print_color(0, 0, "^4%s ^3The ^1current map ^4will be ^3extended ^1for this match.", prefix); 
		//TeamsVote()
	} 
	else { 
		client_print_color(0, 0, "^4%s ^3The ^1map ^4will be ^3changed ^1within 10 ^4seconds. Nextmap ^3[ ^4%s ^3].", prefix, g_MapsChosen[best]); 
		g_ChangeMapTo = best;

		set_task(10.0, "ChangeMap"); 
	} 
	
	return PLUGIN_HANDLED
}

public ChangeMap() {
	new maptochangeto[25]
	
	copy(maptochangeto, 24, g_MapsChosen[g_ChangeMapTo])
	server_cmd("changelevel %s", maptochangeto)
	return PLUGIN_CONTINUE
}
// End