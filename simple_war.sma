#include <amxmodx>
#include <amxmisc>
#include <cstrike>
#include <fun>
#include <reapi>
#include <fakemeta>
#include <hamsandwich>
#include <csx>
#include <engine> 

#if AMXX_VERSION_NUM < 183
#include <dhudmessage>
#endif 

#define PLUGIN "Clan War"
#define VERSION "2.0"
#define AUTHOR "Abhishek Deshkar || Joy Mendonca || blu_knite"
#define SVNUM 1

#define ACCESS ADMIN_KICK

//Set frags.
new Frags[33], Deaths[33]

//======= Overtime Declarations ==================

new bool:g_OverTime	 = false
new OTCount			 = 0

//=====================  Players Selection. =====================================

//Debug
//new DEBUG = 1

//Game Description
new amx_warname

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

new bool:g_Paused = false
new bool:g_bTerroristWinners = false

// Is Match Initialized ?
new bool:g_MatchInit = false

// Is Match started !
new bool:g_MatchStarted = false

//Set main match started to true: useful for leaving players + Count for leaving players.
new bool:g_MainMatchStarted = false

//By default first half if the second half is false.

//Handle the score. By default to: 0 score.
new ScoreFtrstTeam = 0
new ScoreScondteam = 0

//Show menu to the first captain == winner
new ShowMenuFirst
new ShowMenuSecond

//Captains Chosen Teams.- 2 == CT & 1 == T
new FirstCaptainTeamName

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

new g_iVotesTT = 0
new g_iVotesCT = 0

new RoundCounter = 0

//Cvars
new g_Hostname,g_Prefix,g_Rounds,g_OtRounds;
new g_szHostname[64],g_szPrefix[64];


public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);

	register_clcmd("say /start", "ShowMenu", ADMIN_KICK, "Get All The players");
	register_clcmd("say /stop", "StopMatch", ADMIN_KICK, "Stop the Match!");
	register_clcmd("say /pause", "PauseMatch", ADMIN_KICK, "Pause the Match");
	register_clcmd("say /unpause", "Unpause", ADMIN_KICK, "Unpause the Match");
	
	register_clcmd("amx_startmatch", "ShowMenu", ADMIN_KICK, "Get All The players");
	register_clcmd("amx_stopmatch", "StopMatch", ADMIN_KICK, "Stop the Match!");
	register_clcmd("amx_pausematch", "PauseMatch", ADMIN_KICK, "Pause the Match");
	register_clcmd("amx_unpausematch", "Unpause", ADMIN_KICK, "Unpause the Match");

	//Cvars
	g_Hostname = register_cvar("war_hostname", "[WAR]");
	g_Prefix = register_cvar("war_prefix", "[WAR]");
	g_Rounds = register_cvar("war_rounds", "15");
	g_OtRounds = register_cvar("war_otrounds", "3");
	
	gMaxPlayers = get_maxplayers()

	//Change Game Description.
	amx_warname = register_cvar( "amx_warname", "=[ War not Started ]=" ); 
	register_forward( FM_GetGameDescription, "GameDesc" ); 

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
	register_clcmd("chooseteam", "cmdChooseTeam");
	
	// T OR CT WIN.
	RegisterHookChain(RG_RoundEnd, "CS_RoundEnd", false);

	//show score.
	register_clcmd("say !score", "ShowScoreToUser")
   
	get_mapname(szMapname, charsmax(szMapname))
}

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

		server_cmd("mp_freezetime 6");

		set_dhudmessage(0, 255, 0, -1.0, -1.0, 0, 2.0, 6.0, 0.8, 0.8)
		show_dhudmessage(0,"Admin has Stopped the Match ! ^n Server will restart now.")

		set_task(8.0,"RestartServerForStoppingMatch")

		return PLUGIN_HANDLED
	} 
	return PLUGIN_HANDLED
}

public PauseMatch(id,lvl, cid)
{
	if(!cmd_access(id, lvl, cid, 0))
		return PLUGIN_HANDLED;

	if(g_MatchInit || g_MatchStarted || g_KnifeRound)
	{
		g_Paused = true;
		
		new MatchPauserName[32] 
		get_user_name(id, MatchPauserName, charsmax(MatchPauserName)) 

		new MatchPauserAuthID[128] 
		get_user_authid(id, MatchPauserAuthID, 128)

		log_amx("Admin %s with AuthID %s has Paused the Match !",MatchPauserName,MatchPauserAuthID)

		server_cmd("mp_freezetime 999");

		set_dhudmessage(0, 255, 0, -1.0, -1.0, 0, 2.0, 6.0, 0.8, 0.8)
		show_dhudmessage(0,"Admin has Paused the Match^n Server will be Unpaused in a minute")
		
		ColorChat(0,"!t%s !g The Match has been !tPaused !yby Admin",g_szPrefix)
		set_task(60.0,"Unpause")

		ForceEnd()
		return PLUGIN_HANDLED
	} 
	return PLUGIN_HANDLED
}

public Unpause()
{
	if(g_Paused)
	{
		LoadMatchSettings()
		ForceEnd()
		ColorChat(0,"!t%s !g The Match is !tUnPaused !yNow",g_szPrefix)
		ColorChat(0,"!t%s !g Match is Live !",g_szPrefix)
		ColorChat(0,"!t%s !g LIVE LIVE LIVE",g_szPrefix)
		g_Paused = false;
	}
	return PLUGIN_HANDLED
}

public ForceEnd()
{
	new g_players[32], num;
	get_players(g_players, num);
	
	new x;
	for(new i = 0; i < num; i++)
	{
		x = g_players[i];
		
		user_silentkill(x);
		cs_set_user_deaths(x, get_user_deaths(x) - 1);
	}
}

public RestartServerForStoppingMatch()
{
	new CurrentMap[33]
	get_mapname(CurrentMap,32)

	server_cmd("changelevel %s",CurrentMap)
	return PLUGIN_HANDLED
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

		FirstCaptainTeamName = 1
		
		g_bTerroristWinners = true;
		set_task( 5.5,"TTVoting" );
		set_task( 2.0, "GiveRestartRound", _, _, _, "a", 1 ); 
		set_task( 4.0, "FCWKRM", gCptT)
		set_task( 30.0, "VoteResult");

		g_KnifeRound = false
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

public CS_RoundEnd(WinStatus:status, ScenarioEventEndRound:event, Float:tmDelay)
{
	if (g_Paused)
	{
		return PLUGIN_CONTINUE;
	}
	else if (status == WINSTATUS_TERRORISTS)
	{
		on_TerroristWin()
	}
	else if (status == WINSTATUS_CTS || status == WINSTATUS_DRAW)
	{
		on_CTWin()
	}
	return PLUGIN_CONTINUE;
}

//CT WIN Event.
public on_CTWin()
{
	if(g_KnifeRound == true)
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
			FirstCaptainTeamName = 2
			
			set_task(5.5, "CTVoting");
			set_task(2.0, "GiveRestartRound", _, _, _, "a", 1 ); 
			set_task(4.0, "SCWKRWM", gCptCT)
			set_task(30.0, "VoteResult");
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
	get_pcvar_string(g_Prefix, g_szPrefix, charsmax(g_szPrefix));

	if(g_KnifeRound)
	{
		set_dhudmessage(255, 255, 255, -1.0, -1.0, 0, 2.0, 6.0, 0.8, 0.8)
		show_dhudmessage(0,"-= Knife Round Begins =- ^n Team: %s ^n |v/s| ^n Team: %s",TempFirstCaptain,TempSecondCaptain)  

		ColorChat(0,"!t%s !g !tKnife Round !yhas !gbeen started ! ",g_szPrefix)
		ColorChat(0,"!t%s !g Knife War: !yTeam- !t %s !g|v/s| !yTeam- !t%s",g_szPrefix,TempFirstCaptain,TempSecondCaptain)
		ColorChat(0,"!t%s !g Knife War: !yTeam- !t %s !g|v/s| !yTeam- !t%s",g_szPrefix,TempFirstCaptain,TempSecondCaptain)
	}
	
	if(g_MatchStarted)
	{
		//Show Score info in Hud on every round start.
		ShowScoreHud()
		set_task(3.0,"ShowScoreOnRoundStart")
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

	g_TotalKills[id]	= 0
	g_TotalDeaths[id]   = 0
	g_BombPlants[id]	= 0
	g_BombDefusions[id] = 0
}

public TTVoting()
{
	new mPlayers[32];
	new mCount;
	get_players(mPlayers, mCount, "ehc", "TERRORIST");
	for(new i = 0; i < mCount;i++)
	{
		new id = mPlayers[i];
		new TeamChooser = MakeTeamSelectorMenu( id, "Please Choose the Team.", "TeamHandler" );
		menu_setprop( TeamChooser, MPROP_NUMBER_COLOR, "\y" );
		menu_display( id, TeamChooser, 0 );
	}
}

public CTVoting()
{
	new mPlayers[32];
	new mCount;
	get_players(mPlayers, mCount, "ehc", "CT");
	for(new i = 0; i < mCount;i++)
	{
		new id = mPlayers[i];
		new TeamChooser = MakeTeamSelectorMenu( id, "Please Choose the Team.", "TeamHandler" );
		menu_setprop( TeamChooser, MPROP_NUMBER_COLOR, "\y" );
		menu_display( id, TeamChooser, 0 );
	}
}

//Choose Captains and Initialize Match.
public ShowMenu(id, lvl, cid)
{
	if(!cmd_access(id, lvl, cid, 0))
		return PLUGIN_HANDLED;

	if(g_MatchInit || g_MatchStarted)
	return PLUGIN_HANDLED

	//Match initialized. 
	set_cvar_string("amx_warname","=[ War Initialized ]=")

	//Log AMX, Who stopped the match!.
	new MatchStarterName[32] 
	get_user_name(id, MatchStarterName, charsmax(MatchStarterName)) 

	new MatchStarterAuthID[128] 
	get_user_authid(id, MatchStarterAuthID, 127)

	// Match has been initialized! 
	g_MatchInit = true

	// TASK 1 - To Move All the players in Spec.

	//Send message to players about message.
	MatchInitHudMessage()

	//Task 2 - Show Players Menu to who started the match.
	set_task(3.0, "ShowMenuPlayers", id)
	
	return PLUGIN_HANDLED;
}

//Show HUD Message and Print message to inform player about match started !
public MatchInitHudMessage()
{
	set_dhudmessage(0, 255, 0, -1.0, -1.0, 0, 2.0, 6.0, 0.8, 0.8)
	show_dhudmessage(0,"The Match has been Initialized ! ^n Captains will be chosen by the Admin")

	ColorChat(0,"!t%s !g The Match has been !tInitialized.",g_szPrefix)
	ColorChat(0,"!t%s !g Captains will be !tchosen.",g_szPrefix)
}


public ShowMenuPlayers(id)
{
	set_cvar_string("amx_warname","=[ Captain Selection ]=")

	new iMenu = MakePlayerMenu( id, "Choose a Captain", "PlayersMenuHandler" );
	menu_setprop( iMenu, MPROP_NUMBER_COLOR, "\y" );
	menu_display( id, iMenu );

	return PLUGIN_CONTINUE;
}

public MakePlayerMenu( id, const szMenuTitle[], const szMenuHandler[] )
{
	new iMenu = menu_create( szMenuTitle, szMenuHandler );
	new iPlayers[32], iNum, iPlayer, szPlayerName[32], szUserId[33];
	get_players( iPlayers, iNum, "h" );

	new PlayerWithPoints[128]

	for(new i=0;i<iNum;i++)
	{
		iPlayer = iPlayers[i];
		if(gCptCT == 0)
		{
			if(get_user_team(iPlayer) == 2 )
			{
				get_user_name( iPlayer, szPlayerName, charsmax( szPlayerName ) );
				formatex(PlayerWithPoints,127,"%s",szPlayerName)

				formatex( szUserId, charsmax( szUserId ), "%d", get_user_userid( iPlayer ) );
				menu_additem( iMenu, PlayerWithPoints, szUserId, 0 );
			}
		}
		else
		{
			if(get_user_team(iPlayer) == 1 )
			{
				get_user_name( iPlayer, szPlayerName, charsmax( szPlayerName ) );
				formatex(PlayerWithPoints,127,"%s",szPlayerName)

				formatex( szUserId, charsmax( szUserId ), "%d", get_user_userid( iPlayer ) );
				menu_additem( iMenu, PlayerWithPoints, szUserId, 0 );
			}
		}
	}
	return iMenu;
}

public PlayersMenuHandler( id, iMenu, iItem )
{
	if ( iItem == MENU_EXIT )
	{
		// Recreate menu because user's team has been changed.
		new iMenu = MakePlayerMenu( id, "Choose a Captain", "PlayersMenuHandler" );
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
			cs_set_user_team(iPlayer, CS_TEAM_CT)

			new ChosenCaptain[32] 
			get_user_name(iPlayer, ChosenCaptain, charsmax(ChosenCaptain)) 
			ColorChat(0,"!t%s !gPlayer !t%s chosen !yas  First !tCaptain! ",g_szPrefix, ChosenCaptain)  

			CaptainCount++  

			//Temp captain name.
			get_user_name(iPlayer, TempFirstCaptain, charsmax(TempFirstCaptain)) 
		  
			//Assign CT Captain
			gCptCT = iPlayer

			//Recreate menu.
			menu_destroy(iMenu)
			new iMenu = MakePlayerMenu( id, "Choose a Captain", "PlayersMenuHandler" );
			menu_setprop( iMenu, MPROP_NUMBER_COLOR, "\y" );
			menu_display( id, iMenu );

			return PLUGIN_HANDLED;
		}

		if(CaptainCount == 1)
		{
			cs_set_user_team(iPlayer, CS_TEAM_T)

			new ChosenCaptain[32] 
			get_user_name(iPlayer, ChosenCaptain, charsmax(ChosenCaptain)) 
			ColorChat(0,"!t%s !gPlayer !t%s chosen !yas Second !tCaptain! ",g_szPrefix, ChosenCaptain)

			CaptainCount++

			 //Temp captain name.
			get_user_name(iPlayer, TempSecondCaptain, charsmax(TempSecondCaptain)) 

			//Assign T Captain
			gCptT = iPlayer

			set_dhudmessage(255, 0, 0, -1.0, -1.0, 0, 2.0, 6.0, 0.8, 0.8)
			show_dhudmessage(0,"Get Ready Teams! ^n The Knife Round will Start in 10 seconds....")
			ColorChat(0,"!t%s !gAttention ! !yThe !tKnife Round !gWill Start in 10 seconds!",g_szPrefix)

			//Start knife round.
			set_task(10.0,"Knife_Round")
			
			//Captain choosing is over so destroy menu.
			menu_destroy(iMenu)
			return PLUGIN_HANDLED;
		}
	}
	
	// Recreate menu because user's team has been changed.
	new iMenu = MakePlayerMenu( id, "Choose a Captain", "PlayersMenuHandler" );
	menu_setprop( iMenu, MPROP_NUMBER_COLOR, "\y" );
	menu_display( id, iMenu );

	return PLUGIN_HANDLED;
}

public Knife_Round()
{
	set_cvar_string("amx_warname","=[ Knife War ]=")
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
			if(RoundCounter == get_pcvar_num(g_OtRounds))
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
			if(RoundCounter == get_pcvar_num(g_Rounds))
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

public FirstHalfHUDMessage()
{
	set_task(1.0, "HUD_firstLive", _, _, _, "a", 3)
}

public SecondHalfHUDMessage()
{
	set_task(1.0, "HUD_secondLive", _, _, _, "a", 3)
}

public HUD_firstLive()
{
	set_dhudmessage( random_num( 0, 255 ), random_num( 0, 255 ), random_num( 0, 255 ), -1.0, 0.90 , 0, 0.5, 0.5, 0.2, 0.4);
	show_dhudmessage(0, "[  F   I   R   S   T  ]          [  H   A   L   F  ]          [  S   T   A   R   T   E   D  ]" );
	set_dhudmessage( random_num( 0, 255 ), random_num( 0, 255 ), random_num( 0, 255 ), -1.0, 0.80 , 0, 1.0, 0.5, 0.2, 0.4);
	show_dhudmessage(0, "[  F   I   R   S   T  ]          [  H   A   L   F  ]          [  S   T   A   R   T   E   D  ]" );
	set_dhudmessage( random_num( 0, 255 ), random_num( 0, 255 ), random_num( 0, 255 ), -1.0, 0.70 , 0, 0.5, 0.5, 0.2, 0.4);
	show_dhudmessage(0, "[  F   I   R   S   T  ]          [  H   A   L   F  ]          [  S   T   A   R   T   E   D  ]" );
	set_dhudmessage( random_num( 0, 255 ), random_num( 0, 255 ), random_num( 0, 255 ), -1.0, 0.60 , 0, 0.5, 0.5, 0.2, 0.4);
	show_dhudmessage(0, "[  F   I   R   S   T  ]          [  H   A   L   F  ]          [  S   T   A   R   T   E   D  ]" );
	set_dhudmessage( random_num( 0, 255 ), random_num( 0, 255 ), random_num( 0, 255 ), -1.0, 0.50 , 0, 0.5, 0.5, 0.2, 0.4);
	show_dhudmessage(0, "[  F   I   R   S   T  ]          [  H   A   L   F  ]          [  S   T   A   R   T   E   D  ]" );
	set_dhudmessage( random_num( 0, 255 ), random_num( 0, 255 ), random_num( 0, 255 ), -1.0, 0.40 , 0, 0.5, 0.5, 0.2, 0.4);
	show_dhudmessage(0, "[  F   I   R   S   T  ]          [  H   A   L   F  ]          [  S   T   A   R   T   E   D  ]" );
	set_dhudmessage( random_num( 0, 255 ), random_num( 0, 255 ), random_num( 0, 255 ), -1.0, 0.30 , 0, 0.5, 0.5, 0.2, 0.4);
	show_dhudmessage(0, "[  F   I   R   S   T  ]          [  H   A   L   F  ]          [  S   T   A   R   T   E   D  ]" );
	set_dhudmessage( random_num( 0, 255 ), random_num( 0, 255 ), random_num( 0, 255 ), -1.0, 0.20 , 0, 0.5, 0.5, 0.2, 0.4);
	show_dhudmessage(0, "[  F   I   R   S   T  ]          [  H   A   L   F  ]          [  S   T   A   R   T   E   D  ]" );
	set_dhudmessage( random_num( 0, 255 ), random_num( 0, 255 ), random_num( 0, 255 ), -1.0, 0.10 , 0, 0.5, 0.5, 0.2, 0.4);
	show_dhudmessage(0, "[  F   I   R   S   T  ]          [  H   A   L   F  ]          [  S   T   A   R   T   E   D  ]" );
}

public HUD_secondLive()
{
	set_dhudmessage( random_num( 0, 255 ), random_num( 0, 255 ), random_num( 0, 255 ), -1.0, 0.90 , 0, 0.5, 0.5, 0.2, 0.4);
	show_dhudmessage(0, "[  S   E   C   O   N   D  ]          [  H   A   L   F  ]          [  S   T   A   R   T   E   D  ]" );
	set_dhudmessage( random_num( 0, 255 ), random_num( 0, 255 ), random_num( 0, 255 ), -1.0, 0.80 , 0, 1.0, 0.5, 0.2, 0.4);
	show_dhudmessage(0, "[  S   E   C   O   N   D  ]          [  H   A   L   F  ]          [  S   T   A   R   T   E   D  ]" );
	set_dhudmessage( random_num( 0, 255 ), random_num( 0, 255 ), random_num( 0, 255 ), -1.0, 0.70 , 0, 0.5, 0.5, 0.2, 0.4);
	show_dhudmessage(0, "[  S   E   C   O   N   D  ]          [  H   A   L   F  ]          [  S   T   A   R   T   E   D  ]" );
	set_dhudmessage( random_num( 0, 255 ), random_num( 0, 255 ), random_num( 0, 255 ), -1.0, 0.60 , 0, 0.5, 0.5, 0.2, 0.4);
	show_dhudmessage(0, "[  S   E   C   O   N   D  ]          [  H   A   L   F  ]          [  S   T   A   R   T   E   D  ]" );
	set_dhudmessage( random_num( 0, 255 ), random_num( 0, 255 ), random_num( 0, 255 ), -1.0, 0.50 , 0, 0.5, 0.5, 0.2, 0.4);
	show_dhudmessage(0, "[  S   E   C   O   N   D  ]          [  H   A   L   F  ]          [  S   T   A   R   T   E   D  ]" );
	set_dhudmessage( random_num( 0, 255 ), random_num( 0, 255 ), random_num( 0, 255 ), -1.0, 0.40 , 0, 0.5, 0.5, 0.2, 0.4);
	show_dhudmessage(0, "[  S   E   C   O   N   D  ]          [  H   A   L   F  ]          [  S   T   A   R   T   E   D  ]" );
	set_dhudmessage( random_num( 0, 255 ), random_num( 0, 255 ), random_num( 0, 255 ), -1.0, 0.30 , 0, 0.5, 0.5, 0.2, 0.4);
	show_dhudmessage(0, "[  S   E   C   O   N   D  ]          [  H   A   L   F  ]          [  S   T   A   R   T   E   D  ]" );
	set_dhudmessage( random_num( 0, 255 ), random_num( 0, 255 ), random_num( 0, 255 ), -1.0, 0.20 , 0, 0.5, 0.5, 0.2, 0.4);
	show_dhudmessage(0, "[  S   E   C   O   N   D  ]          [  H   A   L   F  ]          [  S   T   A   R   T   E   D  ]" );
	set_dhudmessage( random_num( 0, 255 ), random_num( 0, 255 ), random_num( 0, 255 ), -1.0, 0.10 , 0, 0.5, 0.5, 0.2, 0.4);
	show_dhudmessage(0, "[  S   E   C   O   N   D  ]          [  H   A   L   F  ]          [  S   T   A   R   T   E   D  ]" );
}

public MakeTeamSelectorMenu( id, const szMenuTitle[], const szMenuHandler[])
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
		new TeamChooser = MakeTeamSelectorMenu( id, "Please Choose the Team.", "TeamHandler" );
		menu_setprop( TeamChooser, MPROP_NUMBER_COLOR, "\y" );
		menu_display( id, TeamChooser );

		return PLUGIN_HANDLED;
	}

	switch(iItem)
	{
		case 0:
		{
			g_iVotesCT++;
			new pName[32]
			get_user_name(id, pName, charsmax(pName))
			ColorChat(0,"!g%s !t%s !ychose Team - !gCounter-Terrorist",g_szPrefix,pName)
		}
		case 1:
		{
			g_iVotesTT++;
			new pName[32]
			get_user_name(id, pName, charsmax(pName))
			ColorChat(0,"!g%s !t%s !ychose Team - !gTerrorist",g_szPrefix,pName)
		}
	}
	menu_destroy( TeamChooser );
	return PLUGIN_HANDLED;
}

public VoteResult()
{
	if (g_iVotesTT > g_iVotesCT)
	{
		if (g_bTerroristWinners)
		{
			set_task( 1.0, "NoTeamChange");
		}
		else 
		{
			cmdTeamSwap()
			FirstCaptainTeamName = 1
			set_task( 1.0, "TeamSwap");
		}
	}
	else if (g_iVotesCT > g_iVotesTT)
	{
		if (!g_bTerroristWinners)
		{
			set_task( 1.0, "NoTeamChange");
		}
		else 
		{
			cmdTeamSwap()
			FirstCaptainTeamName = 2
			set_task( 1.0, "TeamSwap");
		}
	}
	else if (g_iVotesCT == g_iVotesTT && g_iVotesTT > 0)
	{
		set_task( 1.0, "NoTeamChange");
	}
	else 
	{
		set_task( 1.0, "NoTeamChange");
	}
	
	LoadMatchSettings()
	
	set_task(5.0, "GiveRestartRound"); 

	set_task(7.0,"LiveOnThreeRestart");

	set_task(11.0,"StartMatch")
}

public client_disconnected(id)
{
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

	msgToDisplay = "||Match Player Stats||^n----------------------^n^nTop Kills -- %s [%d Kills]^nTop Deaths -- %s [%d Deaths]^nTop Bomb Plants -- %s [%d Bomb Plants]^nTop Bomb Defusions -- %s [%d Bomb Defusions]"
    format(msgToDisplay, charsmax(msgToDisplay), msgToDisplay, strlen(KillerName) ? KillerName : "NONE", topKills, strlen(DeathsName) ? DeathsName : "NONE", topDeaths,
            strlen(BombPName) ? BombPName : "NONE", topBombP, strlen(BombDName) ? BombDName : "NONE", topBombD)
            
    new taskId = 6969		
	set_task(1.0, "displayRankingTable", taskId, msgToDisplay, strlen(msgToDisplay), "b")

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
	if(g_KnifeRound || g_MatchStarted)
	{
		if (cs_get_user_team(id) == CS_TEAM_SPECTATOR)
		return PLUGIN_HANDLED;
		ColorChat(id, "!g%s !tYou cannot !gchoose !ta team !ywhile !gMatch !yis !tgoing on.",g_szPrefix);
		return PLUGIN_HANDLED;
	}
	return PLUGIN_CONTINUE;
}

//Checking for knife
public Event_CurWeapon_NotKnife(id)
{
	if ( !g_KnifeRound ) 
		return 

	if( !user_has_weapon(id, CSW_KNIFE ) )
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

		//cs_set_user_team(iPlayer, CS_TEAM_CT)
		//rg_set_user_team(player, cs_get_user_team(player) == CS_TEAM_T ? TEAM_CT:TEAM_TERRORIST,MODEL_AUTO,true)
		cs_set_user_team(player, cs_get_user_team(player) == CS_TEAM_T ? CS_TEAM_CT:CS_TEAM_T)
	}
	return PLUGIN_HANDLED
}

public StartMatch()
{
	server_cmd("mp_forcechasecam 2")
	server_cmd("mp_forcecamera 2")
	set_cvar_string("amx_warname","=[ War Started ]=")
	
	set_task( 3.0, "GiveRestartRound", _, _, _, "a", 3 ); 

	g_MatchInit = false
	
	ColorChat(0,"!t%s !yPlease !gTry !yNot to !tLeave !gThe Match!",g_szPrefix)
	ColorChat(0,"!t%s !tFirst Half !gStarted",g_szPrefix)
	ColorChat(0,"!t%s !gAttention ! !yThe !tMatch !yHas Been !g STARTED !",g_szPrefix)

	new ServerName[512]
	get_pcvar_string(g_Hostname, g_szHostname, charsmax(g_szHostname));
	formatex(ServerName,charsmax(ServerName),"%s %s |v/s| %s In Progress",g_szHostname,FirstCaptainName,SecondCaptainName)

	server_cmd("hostname ^"%s^"",ServerName)
	ServerName[0] = 0

	set_task(11.0,"MatchStartedTrue")

	//Set the status of half to first half.
	isFirstHalfStarted = true
	set_task(12.0,"FirstHalfHUDMessage")
}

//Swap teams for Overtime message.
public SwapTeamsOverTimeMessage()
{
	GiveRestartRound()
	set_task(3.0,"TeamSwapMessage")
	set_task(7.0,"FHOTCHUDM")
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

	ColorChat(0,"!t%s !gTeams !yHave Been !gSwapped !",g_szPrefix);
	ColorChat(0,"!t%s !gOver Time !y- !t%i !gSecond half !yhas been !gStarted !",g_szPrefix,OTCount);
	ColorChat(0,"!t%s !gOver Time !y- !t%i !gSecond half !yhas been !gStarted !",g_szPrefix,OTCount);

	isFirstHalfStarted = false
	isSecondHalfStarted = true
	set_task(14.0,"SecondHalfHUDMessage")

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

	ColorChat(0,"!t%s !gTeams !yHave Been !gSwapped !",g_szPrefix);
	ColorChat(0,"!t%s !gSecond half !yhas been !gStarted !",g_szPrefix);
	
	isFirstHalfStarted = false
	isSecondHalfStarted = true
	set_task(14.0,"SecondHalfHUDMessage")

	LoadMatchSettings()
}

public ShowScoreHud()
{
    new score_message[1024]
    if(ScoreFtrstTeam > ScoreScondteam)
        {
            format(score_message, 1023, "Team %s^n[  %i  ]  --||||--  [  %i  ]",FirstCaptainName,ScoreFtrstTeam,ScoreScondteam)

            set_dhudmessage(random(256), random(256), random(256), -1.0, 0.05, 0, 2.0, 5.0, 0.8, 0.8)
            show_dhudmessage(0, score_message)
            set_dhudmessage(random(256), random(256), random(256), -1.0, 0.0, 0, 2.0, 5.0, 0.8, 0.8)
            show_dhudmessage(0,"-----|| M A T C H    L E A D E R ||------")
        }

        if(ScoreScondteam > ScoreFtrstTeam)
        {
            format(score_message, 1023, "Team %s^n[  %i  ]  --||||--  [  %i  ]",SecondCaptainName,ScoreScondteam,ScoreFtrstTeam)

            set_dhudmessage(random(256), random(256), random(256), -1.0, 0.05, 0, 2.0, 5.0, 0.8, 0.8)
            show_dhudmessage(0, score_message)
            set_dhudmessage(random(256), random(256), random(256), -1.0, 0.0, 0, 2.0, 5.0, 0.8, 0.8)
            show_dhudmessage(0,"-----|| M A T C H    L E A D E R ||------")
        }

        if(ScoreFtrstTeam == ScoreScondteam)
        {
            format(score_message, 1023, "Both Teams^n[  %i  ]  --||||--  [  %i  ]",ScoreScondteam,ScoreFtrstTeam)

            set_dhudmessage(random(256), random(256), random(256), -1.0, 0.05, 0, 2.0, 5.0, 0.8, 0.8)
            show_dhudmessage(0, score_message)
            set_dhudmessage(random(256), random(256), random(256), -1.0, 0.0, 0, 2.0, 5.0, 0.8, 0.8)
            show_dhudmessage(0,"-----|| S C O R E S    T I E ||------")
        }
}

public CheckForWinningTeam()
{

	if(g_OverTime)
	{
		//Check for the overtime winners.
		if(ScoreFtrstTeam >= get_pcvar_num(g_OtRounds)+1)
		{
			//First team won the match!
			//Change description of the game.
			
			new GameDescBuffer[32]
			formatex(GameDescBuffer,charsmax(GameDescBuffer),"GG! %d To %d",ScoreFtrstTeam,ScoreScondteam)

			set_cvar_string("amx_warname",GameDescBuffer)
		   
			server_cmd("mp_freezetime 99999");
			set_task(7.0,"FirstTeamWinnerMessage")
		}

		if(ScoreScondteam >= get_pcvar_num(g_OtRounds)+1)
		{
			//Second team won the match.
			new GameDescBuffer[32]
			formatex(GameDescBuffer,charsmax(GameDescBuffer),"GG! %d To %d",ScoreScondteam,ScoreFtrstTeam)
			set_cvar_string("amx_warname",GameDescBuffer)

			// set_task(8.0,"StartSongForAll")

		   
			server_cmd("mp_freezetime 99999");
			set_task(7.0,"SecondTeamWinnerMessage") 
		}

		if((ScoreFtrstTeam == get_pcvar_num(g_OtRounds)) & (ScoreScondteam == get_pcvar_num(g_OtRounds)))
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
		if(ScoreFtrstTeam >= get_pcvar_num(g_Rounds)+1)
		{
			//Change description of the game.
			
			new GameDescBuffer[32]
			formatex(GameDescBuffer,charsmax(GameDescBuffer),"GG! %d To %d",ScoreFtrstTeam,ScoreScondteam)

			// set_task(8.0,"StartSongForAll")

			set_cvar_string("amx_warname",GameDescBuffer)
			
			server_cmd("mp_freezetime 99999");
			set_task(7.0,"FirstTeamWinnerMessage")
			
		}

		if(ScoreScondteam >= get_pcvar_num(g_Rounds)+1)
		{   

			new GameDescBuffer[32]
			formatex(GameDescBuffer,charsmax(GameDescBuffer),"GG! %d To %d",ScoreScondteam,ScoreFtrstTeam)
			set_cvar_string("amx_warname",GameDescBuffer)

			
			server_cmd("mp_freezetime 99999");
			set_task(7.0,"SecondTeamWinnerMessage") 
		}
	
		if((ScoreFtrstTeam == get_pcvar_num(g_Rounds)) & (ScoreScondteam == get_pcvar_num(g_Rounds)))
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


//Winner message. - First team won!
public FirstTeamWonTheMatch()
{
	set_dhudmessage(255, 255, 255, -1.0, 0.40, 0, 2.0, 6.0, 0.8, 0.8)
    show_dhudmessage(0,"O==[]======- ||Match Winner|| -=====[]==O")
    set_dhudmessage(0, 255, 0, -1.0, -1.0, 0, 2.0, 6.0, 0.8, 0.8)
    show_dhudmessage(0,"[ Team -- %s ]",FirstCaptainName)

	set_cvar_string("amx_warname","=[ War not Started ]=")
}

//Winner message. - Second team won!
public SecondTeamWonTheMatch()
{
	set_dhudmessage(255, 255, 255, -1.0, 0.40, 0, 2.0, 6.0, 0.8, 0.8)
    show_dhudmessage(0,"O==[]======- ||Match Winner|| -=====[]==O")
    set_dhudmessage(0, 255, 0, -1.0, -1.0, 0, 2.0, 6.0, 0.8, 0.8)
    show_dhudmessage(0,"[ Team -- %s ]",SecondCaptainName)

	set_cvar_string("amx_warname","=[ War not Started ]=")
}

//Load Match settings because match has been started !
public LoadMatchSettings()
{

	server_cmd("sv_alltalk 0")
	server_cmd("mp_autoteambalance 0")
	server_cmd("mp_freezetime 8")
}

//Load PuB settings because Match is over!
public LoadPubSettings()
{
	set_cvar_string("amx_warname","=[ War not Started ]=")

	//Set some zero.
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
	g_KnifeRound = false

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
	set_task(7.0,"OverTimeStartMessage")

	//OT STEP 2
	OverTimeSettings()
	set_task(13.0,"STASOTF")
}

// Over time Draw Message.
public MatchDrawMessageOT()
{
	set_task(3.0,"MatchIsDrawOTHUDMessage")
	set_task(7.0,"OverTimeStartMessage")

	set_task(13.0,"STASOTF")
}

public OverTimeSettings()
{
	ScoreFtrstTeam = 0
	ScoreScondteam = 0
	g_OverTime = true
	RoundCounter = 0
	OTCount++
}

public STASOTF()
{
	//Swap Teams.
	cmdTeamSwap()

	GiveRestartRound();
	set_task(2.0,"LiveOnThreeRestart");

	//Give Restart
	set_task(4.0, "GiveRestartRound", _, _, _, "a", 3 ); 

	ColorChat(0,"!t%s !gTeams !yHave Been !gSwapped !",g_szPrefix);
	ColorChat(0,"!t%s !gOver Time !y- !t%i !gFirst Half !yhas been !gStarted !",g_szPrefix,OTCount);
	ColorChat(0,"!t%s !gOver Time !y- !t%i !gFirst Half !yhas been !gStarted !",g_szPrefix,OTCount);
	ColorChat(0,"!t%s !gOverTime Number !y: !t%i",g_szPrefix,OTCount);

	g_MatchStarted = true

	isFirstHalfStarted = true
	isSecondHalfStarted = false
	set_task(14.0,"FirstHalfHUDMessage")

	LoadMatchSettings()
}

public OverTimeStartMessage()
{
	set_dhudmessage(0,255, 0, -1.0, -1.0, 0, 2.0, 4.0, 0.8, 0.8)
	show_dhudmessage(0, "Teams will be Swapped Automatically. ^n OverTime [%i] Will Start Now!",OTCount) 
}

public SCWKRWM()
{
	set_dhudmessage(255, 255, 255, -1.0, -1.0, 0, 2.0, 3.0, 0.8, 0.8)
	show_dhudmessage(0,"Team [ %s ] Won the Knife Round^n|| They will Choose Team Now ||",FirstCaptainName)

	ColorChat(0,"!t%s !gTeam !t%s !gWon !ythe !tKnife Round !",g_szPrefix,FirstCaptainName)
	ColorChat(0,"!t%s !gTeam !t%s !gWill !ychoose thier !tSide Now !",g_szPrefix,FirstCaptainName)
	ColorChat(0,"!t%s !gVoting Started",g_szPrefix)

	//Match Stats: Step -2 : Insert the Knife winner in the database.========
	new KnifeRoundWonSteamID[128] 
	get_user_authid(gCptCT, KnifeRoundWonSteamID, 127)
}

public FCWKRM()
{
	set_dhudmessage(255, 255, 255, -1.0, -1.0, 0, 2.0, 3.0, 0.8, 0.8)
	show_dhudmessage(0,"Team [ %s ] Won the Knife Round^n|| They will Choose Team Now ||",FirstCaptainName)
	ColorChat(0,"!t%s !gTeam !t%s !gWon !ythe !tKnife Round !",g_szPrefix,FirstCaptainName)
	ColorChat(0,"!t%s !gTeam !t%s !gWill !ychoose thier !tSide Now !",g_szPrefix,FirstCaptainName)
	ColorChat(0,"!t%s !gVoting Started",g_szPrefix)
}

public ShowScoreToUser(id)
{
	if(g_MatchStarted)
	{
		if(isFirstHalfStarted)
		{
			if(( FirstCaptainTeamName == 1) && (get_user_team(id) == 2))
			{
				ColorChat(id,"!y[!tScoreboard!y] !gYour Team's Score!y-->> !t[ !g%i !t]  !y-||-  !gOpponent Team's Score!y-->> !t[ !g%i !t]",ScoreScondteam,ScoreFtrstTeam)
			}
			
			if(( FirstCaptainTeamName == 1 ) && (get_user_team(id) == 1)  )
			{    
				ColorChat(id,"!y[!tScoreboard!y] !gYour Team's Score!y-->> !t[ !g%i !t]  !y-||-  !gOpponent Team's Score!y-->> !t[ !g%i !t]",ScoreFtrstTeam,ScoreScondteam)
			}
			
			if((FirstCaptainTeamName == 2) && (get_user_team(id)) == 2)
			{
				ColorChat(id,"!y[!tScoreboard!y] !gYour Team's Score!y-->> !t[ !g%i !t]  !y-||-  !gOpponent Team's Score!y-->> !t[ !g%i !t]",ScoreFtrstTeam,ScoreScondteam)
			}
			
			if( (FirstCaptainTeamName == 2) && (get_user_team(id) == 1) )
			{
				ColorChat(id,"!y[!tScoreboard!y] !gYour Team's Score!y-->> !t[ !g%i !t]  !y-||-  !gOpponent Team's Score!y-->> !t[ !g%i !t]",ScoreScondteam,ScoreFtrstTeam)
			}
		}

		if(isSecondHalfStarted)
		{
			if(( FirstCaptainTeamName == 1) && (get_user_team(id) == 2))
			{
                ColorChat(id,"!y[!tScoreboard!y] !gYour Team's Score!y-->> !t[ !g%i !t]  !y-||-  !gOpponent Team's Score!y-->> !t[ !g%i !t]",ScoreFtrstTeam,ScoreScondteam)
			}
			
			if(( FirstCaptainTeamName == 1 ) && (get_user_team(id) == 1)  )
			{    
				ColorChat(id,"!y[!tScoreboard!y] !gYour Team's Score!y-->> !t[ !g%i !t]  !y-||-  !gOpponent Team's Score!y-->> !t[ !g%i !t]",ScoreScondteam,ScoreFtrstTeam)
			}
			
			if((FirstCaptainTeamName == 2) && (get_user_team(id)) == 2)
			{
				ColorChat(id,"!y[!tScoreboard!y] !gYour Team's Score!y-->> !t[ !g%i !t]  !y-||-  !gOpponent Team's Score!y-->> !t[ !g%i !t]",ScoreScondteam,ScoreFtrstTeam)
			}

			if( (FirstCaptainTeamName == 2) && (get_user_team(id) == 1) )
			{
				ColorChat(id,"!y[!tScoreboard!y] !gYour Team's Score!y-->> !t[ !g%i !t]  !y-||-  !gOpponent Team's Score!y-->> !t[ !g%i !t]",ScoreFtrstTeam,ScoreScondteam)
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
				ColorChat(iPlayer,"!y[!tScoreboard!y] !gYour Team's Score!y-->> !t[ !g%i !t]  !y-||-  !gOpponent Team's Score!y-->> !t[ !g%i !t]",ScoreScondteam,ScoreFtrstTeam)
			}
			
			if(( FirstCaptainTeamName == 1 ) && (get_user_team(iPlayer) == 1)  )
			{    
				ColorChat(iPlayer,"!y[!tScoreboard!y] !gYour Team's Score!y-->> !t[ !g%i !t]  !y-||-  !gOpponent Team's Score!y-->> !t[ !g%i !t]",ScoreFtrstTeam,ScoreScondteam)
			}
			
			if((FirstCaptainTeamName == 2) && (get_user_team(iPlayer)) == 2)
			{
				ColorChat(iPlayer,"!y[!tScoreboard!y] !gYour Team's Score!y-->> !t[ !g%i !t]  !y-||-  !gOpponent Team's Score!y-->> !t[ !g%i !t]",ScoreFtrstTeam,ScoreScondteam)
			}
			
			if( (FirstCaptainTeamName == 2) && (get_user_team(iPlayer) == 1) )
			{
				ColorChat(iPlayer,"!y[!tScoreboard!y] !gYour Team's Score!y-->> !t[ !g%i !t]  !y-||-  !gOpponent Team's Score!y-->> !t[ !g%i !t]",ScoreScondteam,ScoreFtrstTeam)
			}
        }
		
		if(isSecondHalfStarted)
		{
			if(( FirstCaptainTeamName == 1) && (get_user_team(iPlayer) == 2))
			{
				ColorChat(iPlayer,"!y[!tScoreboard!y] !gYour Team's Score!y-->> !t[ !g%i !t]  !y-||-  !gOpponent Team's Score!y-->> !t[ !g%i !t]",ScoreFtrstTeam,ScoreScondteam)
			}
			
			if(( FirstCaptainTeamName == 1 ) && (get_user_team(iPlayer) == 1)  )
			{    
				ColorChat(iPlayer,"!y[!tScoreboard!y] !gYour Team's Score!y-->> !t[ !g%i !t]  !y-||-  !gOpponent Team's Score!y-->> !t[ !g%i !t]",ScoreScondteam,ScoreFtrstTeam)
			}
			
			if((FirstCaptainTeamName == 2) && (get_user_team(iPlayer)) == 2)
			{
				ColorChat(iPlayer,"!y[!tScoreboard!y] !gYour Team's Score!y-->> !t[ !g%i !t]  !y-||-  !gOpponent Team's Score!y-->> !t[ !g%i !t]",ScoreScondteam,ScoreFtrstTeam)
			}
			
			if( (FirstCaptainTeamName == 2) && (get_user_team(iPlayer) == 1) )
			{
				ColorChat(iPlayer,"!y[!tScoreboard!y] !gYour Team's Score!y-->> !t[ !g%i !t]  !y-||-  !gOpponent Team's Score!y-->> !t[ !g%i !t]",ScoreFtrstTeam,ScoreScondteam)
			}
		}
	} 
}

//To restart the round.
public GiveRestartRound( ) 
{ 
	server_cmd( "sv_restartround ^"1^"" ); 
} 

public FHOTCHUDM()
{
	new score_message[1024]
	if(ScoreFtrstTeam > ScoreScondteam)
	{
		format(score_message, 1023, "--=|| First Half Score ||=-- ^n^n^n %s - -[ %i ] ^n^n LEADING TO^n ^n %s -- [ %i ]",FirstCaptainName,ScoreFtrstTeam,SecondCaptainName,ScoreScondteam)

		set_dhudmessage(0,255, 0, -1.0, -1.0, 0, 2.0, 4.0, 0.8, 0.8)
		show_dhudmessage(0, score_message)
	}

	if(ScoreScondteam > ScoreFtrstTeam)
	{
		format(score_message, 1023, "--=|| First Half Score ||=-- ^n^n^n %s - -[ %i ] ^n^n LEADING TO^n ^n %s -- [ %i ]",SecondCaptainName,ScoreScondteam,FirstCaptainName,ScoreFtrstTeam)

		set_dhudmessage(0,255, 0, -1.0, -1.0, 0, 2.0, 4.0, 0.8, 0.8)
		show_dhudmessage(0, score_message)
	}
	
	if(ScoreFtrstTeam == ScoreScondteam)
	{
		format(score_message, 1023, "[[ Both teams have Won [ %i ] rounds till now ]]",ScoreScondteam)
		
		set_dhudmessage(0,255, 0, -1.0, -1.0, 0, 2.0, 4.0, 0.8, 0.8)
		show_dhudmessage(0, score_message)
    }
}

public FirstHalfCompletedHUDMessage()
{
	new score_message[1024]
	if(ScoreFtrstTeam > ScoreScondteam)
	{
		format(score_message, 1023, "--=|| First Half Score ||=-- ^n^n^n %s - -[ %i ] ^n^n LEADING TO^n ^n %s -- [ %i ]",FirstCaptainName,ScoreFtrstTeam,SecondCaptainName,ScoreScondteam)

		set_dhudmessage(0,255, 0, -1.0, -1.0, 0, 2.0, 4.0, 0.8, 0.8)
		show_dhudmessage(0, score_message)
	}

	if(ScoreScondteam > ScoreFtrstTeam)
	{
		format(score_message, 1023, "--=|| First Half Score ||=-- ^n^n^n %s - -[ %i ] ^n^n LEADING TO^n ^n %s -- [ %i ]",SecondCaptainName,ScoreScondteam,FirstCaptainName,ScoreFtrstTeam)

		set_dhudmessage(0,255, 0, -1.0, -1.0, 0, 2.0, 4.0, 0.8, 0.8)
		show_dhudmessage(0, score_message)
	}
	
	if(ScoreFtrstTeam == ScoreScondteam)
	{
		format(score_message, 1023, "[[ Both teams have Won [ %i ] rounds till now ]]",ScoreScondteam)
		
		set_dhudmessage(0,255, 0, -1.0, -1.0, 0, 2.0, 4.0, 0.8, 0.8)
		show_dhudmessage(0, score_message)
    }
}

public SecondHalfCompletedHUDMessage()
{
	new score_message[1024]
	if(ScoreFtrstTeam > ScoreScondteam)
	{
		format(score_message, 1023, "--=|| Second Half Score ||=-- ^n^n^n %s - -[ %i ] ^n^n LEADING TO^n ^n %s -- [ %i ]",FirstCaptainName,ScoreFtrstTeam,SecondCaptainName,ScoreScondteam)
		
		set_dhudmessage(0,255, 0, -1.0, -1.0, 0, 2.0, 4.0, 0.8, 0.8)
		show_dhudmessage(0, score_message)
	}
	
    if(ScoreScondteam > ScoreFtrstTeam)
	{
		format(score_message, 1023, "--=|| Second Half Score ||=-- ^n^n^n %s - -[ %i ] ^n^n LEADING TO^n ^n %s -- [ %i ]",SecondCaptainName,ScoreScondteam,FirstCaptainName,ScoreFtrstTeam)
		
		set_dhudmessage(0,255, 0, -1.0, -1.0, 0, 2.0, 4.0, 0.8, 0.8)
		show_dhudmessage(0, score_message)
	}
	
	if(ScoreFtrstTeam == ScoreScondteam)
    {
		format(score_message, 1023, "[[ Both teams have Won [ %i ] rounds till now ]]",ScoreScondteam)
		
		set_dhudmessage(0,255, 0, -1.0, -1.0, 0, 2.0, 6.0, 0.8, 0.8)
		show_dhudmessage(0, score_message)
	}
}

public MatchIsOverHUDMessage()
{
    set_dhudmessage(213,255, 0, -1.0, -1.0, 0, 2.0, 3.0, 0.8, 0.8)
    show_dhudmessage(0,"||||-----------------------------||||^nM A T C H  --  O V E R^n||||-----------------------------||||")
}

public MatchIsDrawHUDMessage()
{
	set_dhudmessage(0,255, 0, -1.0, -1.0, 0, 2.0, 3.0, 0.8, 0.8)
	show_dhudmessage(0,"[-- Match Is Draw!--]")
}

public MatchIsDrawOTHUDMessage()
{
	set_dhudmessage(0,255, 0, -1.0, -1.0, 0, 2.0, 3.0, 0.8, 0.8)
	show_dhudmessage(0,"[-- OverTime Match Draw --]]^n|| Next OverTime Will start Now ||")  
}

public TeamSwapMessage()
{
    set_dhudmessage(255, 255, 0, -1.0, -1.0, 0, 2.0, 3.0, 0.8, 0.8)
    show_dhudmessage(0,"[-- First Half Is Over --]]^n|| Teams will be Swapped Automatically || ^n|| Second Half will Begin Now ||")
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
	set_dhudmessage(random(256), random(256), random(256), -1.0, -1.0, 0, 2.0, 3.0, 0.8, 0.8)
    show_dhudmessage(0,">>--------------------------------<<^n       Live On Three Restarts       ^n>>--------------------------------<<")
}

public NoTeamChange()
{
	set_dhudmessage(255, 255, 0, -1.0, -1.0, 0, 2.0, 3.0, 0.8, 0.8)
    show_dhudmessage(0,"[-- Voting Ended --]]^n|| Teams will Reamin Same ||")
}

public TeamSwap()
{
	set_dhudmessage(255, 255, 0, -1.0, -1.0, 0, 2.0, 3.0, 0.8, 0.8)
    show_dhudmessage(0,"[-- Voting Ended --]]^n|| Teams will be Swapped Mutually ||")
}


/*
*	STOCKS
*
*/
//For color chat

stock ColorChat(const id, const input[], any:...) 
{ 
	new count = 1, players[32]; 
	static msg[191]; 
	vformat(msg, 190, input, 3); 
	
	replace_all(msg, 190, "!y", "^x01");
	replace_all(msg, 190, "!g", "^x04");	 
	replace_all(msg, 190, "!t", "^x03");
	
	if (id) players[0] = id; else get_players(players, count, "ch"); { 
		for (new i = 0; i < count; i++) 
		{ 
			if (is_user_connected(players[i])) 
			{ 
				message_begin(MSG_ONE_UNRELIABLE, get_user_msgid("SayText"), _, players[i]); 
				write_byte(players[i]); 
				write_string(msg); 
				message_end(); 
			} 
		} 
	} 
}

public fnSortFunc(elem1, elem2, const array[], const data[], data_size) 
{
    new iNum = random_num(0, 60)
    if (iNum < 30)
        return -1
    else if (iNum == 30)
        return 0
    
    return 1
}

/* AMXX-Studio Notes - DO NOT MODIFY BELOW HERE
*{\\ rtf1\\ ansi\\ deff0{\\ fonttbl{\\ f0\\ fnil Tahoma;}}\n\\ viewkind4\\ uc1\\ pard\\ lang1033\\ f0\\ fs16 \n\\ par }
*/
