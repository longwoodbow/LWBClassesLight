
//TDM gamemode logic script
//now you don't spawn as knight or archer if disabled in config.

#define SERVER_ONLY

#include "DTS_Structs.as";
#include "RulesCore.as";
#include "RespawnSystem.as";
#include "DTSConfig.as";
#include "ClassesConfig.as";

//edit the variables in the config file below to change the basics
// no scripting required!

void Config(DTSCore@ this)
{
	CRules@ rules = getRules();

	//load cfg
	this.warmUpTime = (getTicksASecond() * DTSConfig::warmUpTimeSeconds);
	this.gametime = getGameTime() + this.warmUpTime;// need?

	//how long to wait for everyone to spawn in?
	if (DTSConfig::gameDurationMinutes <= 0)
	{
		this.gameDuration = 0;
		getRules().set_bool("no timer", true);
	}
	else
	{
		this.gameDuration = (getTicksASecond() * 60 * DTSConfig::gameDurationMinutes) + this.warmUpTime;
	}

	//spawn after death time - set in gamemode.cfg, or override here
	this.spawnTime = (getTicksASecond() * DTSConfig::spawnTimeSeconds);

	//how many players have to be in for the game to start
	this.minimum_players_in_team = 1;

	//whether to scramble each game or not
	this.scramble_teams = DTSConfig::scramble_teams;

	s32 scramble_maps = DTSConfig::scramble_maps;
	if(scramble_maps != -1) {
		sv_mapcycle_shuffle = (scramble_maps != 0);
	}

	// modifies if the fall damage velocity is higher or lower - TDM has lower velocity
	rules.set_f32("fall vel modifier", DTSConfig::fall_dmg_nerf);
}

//TDM spawn system

shared class DTSSpawns : RespawnSystem
{
	DTSCore@ TDM_core;

	bool force;

	void SetCore(RulesCore@ _core)
	{
		RespawnSystem::SetCore(_core);
		@TDM_core = cast < DTSCore@ > (core);
	}

	void Update()
	{
		for (uint team_num = 0; team_num < TDM_core.teams.length; ++team_num)
		{
			DTSTeamInfo@ team = cast < DTSTeamInfo@ > (TDM_core.teams[team_num]);

			for (uint i = 0; i < team.spawns.length; i++)
			{
				DTSPlayerInfo@ info = cast < DTSPlayerInfo@ > (team.spawns[i]);

				UpdateSpawnTime(info, i);
				DoSpawnPlayer(info);
			}
		}
	}

	void UpdateSpawnTime(DTSPlayerInfo@ info, int i)
	{
		//default
		u8 spawn_property = 254;

		//flag for no respawn
		bool huge_respawn = info.can_spawn_time >= 0x00ffffff;

		if (i == 0 && info !is null && info.can_spawn_time > 0)
		{
			if (huge_respawn)
			{
				info.can_spawn_time = 5;
			}

			info.can_spawn_time--;
			// Round time up (except for final few ticks)
			spawn_property = u8(Maths::Min(250, ((info.can_spawn_time + getTicksASecond() - 5) / getTicksASecond())));
		}

		string propname = "dts spawn time " + info.username;
		TDM_core.rules.set_u8(propname, spawn_property);
		if (info !is null && info.can_spawn_time >= 0)
		{
			TDM_core.rules.SyncToPlayer(propname, getPlayerByUsername(info.username));
		}
	}

	void DoSpawnPlayer(PlayerInfo@ p_info)
	{
		if (force || canSpawnPlayer(p_info))
		{
			CPlayer@ player = getPlayerByUsername(p_info.username); // is still connected?

			if (player is null)
			{
				RemovePlayerFromSpawn(p_info);
				return;
			}
			if (player.getTeamNum() != int(p_info.team))
			{
				player.server_setTeamNum(p_info.team);
			}

			// remove previous players blob
			if (player.getBlob() !is null)
			{
				CBlob @blob = player.getBlob();
				blob.server_SetPlayer(null);
				blob.server_Die();
			}

			CBlob@ playerBlob = SpawnPlayerIntoWorld(getSpawnLocation(p_info), p_info);

			if (playerBlob !is null)
			{
				// spawn resources
				p_info.spawnsCount++;
				RemovePlayerFromSpawn(player);
			}
		}
	}

	bool canSpawnPlayer(PlayerInfo@ p_info)
	{
		DTSPlayerInfo@ info = cast < DTSPlayerInfo@ > (p_info);

		if (info is null) { warn("TDM LOGIC: Couldn't get player info ( in bool canSpawnPlayer(PlayerInfo@ p_info) ) "); return false; }

		if (force) { return true; }

		return info.can_spawn_time == 0;
	}

	Vec2f getSpawnLocation(PlayerInfo@ p_info)
	{
		CBlob@[] spawns;
		CBlob@[] teamspawns;

		if (getBlobsByName("tdm_spawn", @spawns))
		{
			for (uint step = 0; step < spawns.length; ++step)
			{
				if (spawns[step].getTeamNum() == s32(p_info.team))
				{
					teamspawns.push_back(spawns[step]);
				}
			}
		}

		if (teamspawns.length > 0)
		{
			int spawnindex = XORRandom(997) % teamspawns.length;
			return teamspawns[spawnindex].getPosition();
		}

		return Vec2f(0, 0);
	}

	void RemovePlayerFromSpawn(CPlayer@ player)
	{
		RemovePlayerFromSpawn(core.getInfoFromPlayer(player));
	}

	void RemovePlayerFromSpawn(PlayerInfo@ p_info)
	{
		DTSPlayerInfo@ info = cast < DTSPlayerInfo@ > (p_info);

		if (info is null) { warn("TDM LOGIC: Couldn't get player info ( in void RemovePlayerFromSpawn(PlayerInfo@ p_info) )"); return; }

		string propname = "dts spawn time " + info.username;

		for (uint i = 0; i < TDM_core.teams.length; i++)
		{
			DTSTeamInfo@ team = cast < DTSTeamInfo@ > (TDM_core.teams[i]);
			int pos = team.spawns.find(info);

			if (pos != -1)
			{
				team.spawns.erase(pos);
				break;
			}
		}

		TDM_core.rules.set_u8(propname, 255);   //not respawning
		TDM_core.rules.SyncToPlayer(propname, getPlayerByUsername(info.username));

		info.can_spawn_time = 0;
	}

	void AddPlayerToSpawn(CPlayer@ player)
	{
		RemovePlayerFromSpawn(player);
		if (player.getTeamNum() == core.rules.getSpectatorTeamNum())
			return;

		u32 tickspawndelay = u32(TDM_core.spawnTime);

//		print("ADD SPAWN FOR " + player.getUsername());
		DTSPlayerInfo@ info = cast < DTSPlayerInfo@ > (core.getInfoFromPlayer(player));

		if (info is null) { warn("TDM LOGIC: Couldn't get player info  ( in void AddPlayerToSpawn(CPlayer@ player) )"); return; }

		if (info.team < TDM_core.teams.length)
		{
			DTSTeamInfo@ team = cast < DTSTeamInfo@ > (TDM_core.teams[info.team]);

			info.can_spawn_time = tickspawndelay;
			team.spawns.push_back(info);
		}
		else
		{
			error("PLAYER TEAM NOT SET CORRECTLY!");
		}
	}

	bool isSpawning(CPlayer@ player)
	{
		DTSPlayerInfo@ info = cast < DTSPlayerInfo@ > (core.getInfoFromPlayer(player));
		for (uint i = 0; i < TDM_core.teams.length; i++)
		{
			DTSTeamInfo@ team = cast < DTSTeamInfo@ > (TDM_core.teams[i]);
			int pos = team.spawns.find(info);

			if (pos != -1)
			{
				return true;
			}
		}
		return false;
	}

};

shared class DTSCore : RulesCore
{
	s32 warmUpTime;
	s32 gameDuration;
	s32 spawnTime;
	s32 minimum_players_in_team;

	s32 players_in_small_team;
	bool scramble_teams;

	DTSSpawns@ tdm_spawns;

	DTSCore() {}

	DTSCore(CRules@ _rules, RespawnSystem@ _respawns)
	{
		super(_rules, _respawns);
	}

	void Setup(CRules@ _rules = null, RespawnSystem@ _respawns = null)
	{
		RulesCore::Setup(_rules, _respawns);
		gametime = getGameTime() + 100;
		@tdm_spawns = cast < DTSSpawns@ > (_respawns);
		server_CreateBlob("Entities/Meta/TDMMusic.cfg");
		players_in_small_team = -1;

		sv_mapautocycle = true;
	}

	int gametime;
	void Update()
	{
		//HUD
		// lets save the CPU and do this only once in a while
		if (getGameTime() % 16 == 0)
		{
			updateHUD();
		}
		
		if (rules.isGameOver()) { return; }

		s32 ticksToStart = gametime - getGameTime();

		tdm_spawns.force = false;

		if (ticksToStart <= 0 && (rules.isWarmup()))
		{
			rules.SetCurrentState(GAME);
		}
		else if (ticksToStart > 0 && rules.isWarmup()) //is the start of the game, spawn everyone
		{
			rules.SetGlobalMessage("Match starts in {SEC}");
			rules.AddGlobalMessageReplacement("SEC", "" + ((ticksToStart / 30) + 1));
			tdm_spawns.force = true;
		}

		if ((rules.isIntermission() || rules.isWarmup()) && (!allTeamsHavePlayers()))  //CHECK IF TEAMS HAVE ENOUGH PLAYERS
		{
			gametime = getGameTime() + warmUpTime;
			rules.set_u32("game_end_time", gametime + gameDuration);
			rules.SetGlobalMessage("Not enough players in each team for the game to start.\nPlease wait for someone to join...");
			tdm_spawns.force = true;
		}
		else if (rules.isMatchRunning())
		{
			rules.SetGlobalMessage("");
		}

		//  SpawnPowerups();
		RulesCore::Update(); //update respawns
		CheckTeamWon();

		if (getGameTime() % 2000 == 0)
			SpawnBombs();
	}
	
	void updateHUD()
	{
        DTSUIData@ ui;
        rules.get("uidata", @ui);

        if(ui is null) return;

        for(int i = 0; i < ui.statueIds.size(); i++)
        {
            CBlob@ blob = getBlobByNetworkID(ui.statueIds[i]);
            if(blob !is null)
            {
				ui.statueHealth[i] = blob.getHealth();
            }
        }

	    rules.set("uidata", @ui);

	    CBitStream bt = ui.serialize();

		rules.set_CBitStream("dts_serialised_team_hud", bt);
		rules.Sync("dts_serialised_team_hud", true);
	}
	//HELPERS

	// as same as TDM
	bool allTeamsHavePlayers()
	{
		for (uint i = 0; i < teams.length; i++)
		{
			if (teams[i].players_count < minimum_players_in_team)
			{
				return false;
			}
		}

		return true;
	}

	//team stuff

	// as same as TDM
	void AddTeam(CTeam@ team)
	{
		DTSTeamInfo t(teams.length, team.getName());
		teams.push_back(t);
	}

	// as same as TDM
	void AddPlayer(CPlayer@ player, u8 team = 0, string default_config = "")
	{
		DTSPlayerInfo p(player.getUsername(), player.getTeamNum(), player.isBot() ? "knight" : randomClass(false));
		players.push_back(p);
		ChangeTeamPlayerCount(p.team, 1);
	}

	// as same as CTF
	// not need to count death
	void onPlayerDie(CPlayer@ victim, CPlayer@ killer, u8 customData)
	{
		if (!getNet().isServer())
			return;

		if (victim !is null)
		{
			if (killer !is null && killer.getTeamNum() != victim.getTeamNum())
			{
				addKill(killer.getTeamNum());
			}
		}
	}
	// as same as TDM
	void onSetPlayer(CBlob@ blob, CPlayer@ player)
	{
		if (blob !is null && player !is null)
		{
			GiveSpawnResources(blob, player);
		}
	}

	//setup the TDM bases

	void SetupBase(CBlob@ base)
	{
		if (base is null)
		{
			return;
		}

		//nothing to do
	}

	// as same as TDM
	void SetupBases()
	{
		const string base_name = "tdm_spawn";
		// destroy all previous spawns if present
		CBlob@[] oldBases;
		getBlobsByName(base_name, @oldBases);

		for (uint i = 0; i < oldBases.length; i++)
		{
			oldBases[i].server_Die();
		}

		//spawn the spawns :D
		CMap@ map = getMap();

		if (map !is null)
		{
			// team 0 ruins
			Vec2f[] respawnPositions;
			Vec2f respawnPos;

			if (!getMap().getMarkers("blue main spawn", respawnPositions))
			{
				warn("TDM: Blue spawn marker not found on map");
				respawnPos = Vec2f(150.0f, map.getLandYAtX(150.0f / map.tilesize) * map.tilesize - 32.0f);
				respawnPos.y -= 16.0f;
				SetupBase(server_CreateBlob(base_name, 0, respawnPos));
			}
			else
			{
				for (uint i = 0; i < respawnPositions.length; i++)
				{
					respawnPos = respawnPositions[i];
					respawnPos.y -= 16.0f;
					SetupBase(server_CreateBlob(base_name, 0, respawnPos));
				}
			}

			respawnPositions.clear();


			// team 1 ruins
			if (!getMap().getMarkers("red main spawn", respawnPositions))
			{
				warn("TDM: Red spawn marker not found on map");
				respawnPos = Vec2f(map.tilemapwidth * map.tilesize - 150.0f, map.getLandYAtX(map.tilemapwidth - (150.0f / map.tilesize)) * map.tilesize - 32.0f);
				respawnPos.y -= 16.0f;
				SetupBase(server_CreateBlob(base_name, 1, respawnPos));
			}
			else
			{
				for (uint i = 0; i < respawnPositions.length; i++)
				{
					respawnPos = respawnPositions[i];
					respawnPos.y -= 16.0f;
					SetupBase(server_CreateBlob(base_name, 1, respawnPos));
				}
			}

			respawnPositions.clear();
		}

		rules.SetCurrentState(WARMUP);
	}

	//checks
	// IMPORTANT IN THIS MODE
	// almost as same as CTF
	void CheckTeamWon()
	{
		if (!rules.isMatchRunning()) { return; }

		// get all the statues
		CBlob@[] statues;
		getBlobsByName("statue", @statues);

		int winteamIndex = -1;
		DTSTeamInfo@ winteam = null;
		s8 team_wins_on_end = -1;
		f32 best_statue_health = 0.0f;

		for (uint team_num = 0; team_num < teams.length; ++team_num)
		{
			DTSTeamInfo@ team = cast < DTSTeamInfo@ > (teams[team_num]);

			bool win = true;
			f32 team_statue_health = 0.0f;
			for (uint i = 0; i <statues.length; i++)
			{
				if (statues[i].getTeamNum() == team_num)
				{
					team_statue_health += statues[i].getHealth();
				}
				else//if there exists an enemy flag, we didn't win yet
				{
					win = false;
				}
			}

			if (win)
			{
				winteamIndex = team_num;
				@winteam = team;
			}
			else//let's check which team's statue is not more damaged to check which team wins on end
			{
				if (team_statue_health == best_statue_health)//it's a tie!
				{
					team_wins_on_end = -1;
				}
				else if (team_statue_health > best_statue_health)//better than other team!
				{
					best_statue_health = team_statue_health;
					team_wins_on_end = team_num;
				}
			}

		}

		rules.set_s8("team_wins_on_end", team_wins_on_end);

		if (winteamIndex >= 0)
		{
			// add winning team coins
			if (rules.isMatchRunning())
			{
				CBlob@[] players;
				getBlobsByTag("player", @players);
				for (uint i = 0; i < players.length; i++)
				{
					CPlayer@ player = players[i].getPlayer();
					if (player !is null && players[i].getTeamNum() == winteamIndex)
					{
						player.server_setCoins(player.getCoins() + 10);
					}
				}
			}

			rules.SetTeamWon(winteamIndex);   //game over!
			rules.SetCurrentState(GAME_OVER);
		}
	}
	// as same as TDM
	void giveCoinsBack(CPlayer@ player, CBlob@ blob, ConfigFile cfg)
	{
		if (blob.exists("buyer"))
		{
			u16 buyerID = blob.get_u16("buyer");

			CPlayer@ buyer = getPlayerByNetworkId(buyerID);
			if (buyer !is null && player is buyer)
			{
				string blobName = blob.getName();
				string costName = "cost_" + blobName;
				if (cfg.exists(costName) && blobName != "mat_arrows")
				{
					s32 cost = cfg.read_s32(costName);
					if (cost > 0)
					{
						player.server_setCoins(player.getCoins() + Maths::Round(cost / 2));
					}
				}
			}
		}
	}

	void addKill(int team)
	{
		if (team >= 0 && team < int(teams.length))
		{
			DTSTeamInfo@ team_info = cast < DTSTeamInfo@ > (teams[team]);
			// not need team_info.kills++;
		}
	}
	// following is almost as same as TDM

	void SpawnPowerups()
	{
		if (getGameTime() % 200 == 0 && XORRandom(12) == 0)
		{
			SpawnPowerup();
		}
	}

	void SpawnPowerup()
	{
		CBlob@ powerup = server_CreateBlob("powerup", -1, Vec2f(getMap().tilesize * 0.5f * getMap().tilemapwidth, 50.0f));
	}

	void SpawnBombs()
	{
		Vec2f[] bombPlaces;
		if (getMap().getMarkers("bombs", bombPlaces))
		{
			for (uint i = 0; i < bombPlaces.length; i++)
			{
				server_CreateBlob("mat_bombs", -1, bombPlaces[i]);
			}
		}
	}


	void GiveSpawnResources(CBlob@ blob, CPlayer@ player)
	{
		// give archer arrows

		string className = blob.getName();

		if (className == "archer" ||
			className == "crossbowman" ||
			className == "musketman" ||
			//className == "rockthrower" ||
			className == "medic" ||
			className == "spearman" ||
			className == "weaponthrower" ||
			className == "firelancer" ||
			className == "gunner")
		{
			string ammoName = getClassAmmo(className);
			// first check if its in surroundings
			CBlob@[] blobsInRadius;
			CMap@ map = getMap();
			bool found = false;
			if (map.getBlobsInRadius(blob.getPosition(), 60.0f, @blobsInRadius))
			{
				for (uint i = 0; i < blobsInRadius.length; i++)
				{
					CBlob @b = blobsInRadius[i];
					if (b.getName() == ammoName)
					{
						found = true;
						if (!found)
						{
							blob.server_PutInInventory(b);
						}
						else
						{
							b.server_Die();
						}
					}
				}
			}

			if (!found)
			{
				CBlob@ mat = server_CreateBlob(ammoName);
				if (mat !is null)
				{
					if (!blob.server_PutInInventory(mat))
					{
						mat.setPosition(blob.getPosition());
					}
				}
			}
		}
	}

	string getClassAmmo(string name)
	{
		if(name == "archer" || name == "crossbowman") return "mat_arrows";
		else if(name == "musketman" || name == "gunner") return "mat_bullets";
		//else if(name == "rockthrower") return "mat_stone";
		else if(name == "medic") return "mat_medkits";
		else if(name == "spearman") return"mat_spears";
		else if(name == "weaponthrower") return"mat_boomerangs";
		else if(name == "firelancer") return"mat_firelances";
		else return "";
	}
};

//pass stuff to the core from each of the hooks

void Reset(CRules@ this)
{
	printf("Restarting rules script: " + getCurrentScriptName());
	DTSSpawns spawns();
	DTSCore core(this, spawns);
	Config(core);
	core.SetupBases();
	this.set("core", @core);
	this.set("start_gametime", getGameTime() + core.warmUpTime);
	this.set_u32("game_end_time", getGameTime() + core.gameDuration); //for TimeToEnd.as
	this.set_s32("restart_rules_after_game_time", (core.spawnTime < 0 ? 5 : 10) * 30 );
}

void onRestart(CRules@ this)
{
	Reset(this);
}

void onInit(CRules@ this)
{
	Reset(this);
}
