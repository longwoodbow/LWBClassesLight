// spawn resources
// added mats for new classes

#include "RulesCore.as";
#include "CTF_Structs.as";
#include "CTF_Common.as"; // resupply stuff

bool SetMaterials(CBlob@ blob,  const string &in name, const int quantity, bool drop = false)
{
	CInventory@ inv = blob.getInventory();

	//avoid over-stacking arrows
	/*
	if (name == "mat_arrows")
	{
		inv.server_RemoveItems(name, quantity);
	}
	*/

	CBlob@ mat = server_CreateBlobNoInit(name);

	if (mat !is null)
	{
		mat.Tag('custom quantity');
		mat.Init();

		mat.server_SetQuantity(quantity);

		if (drop || not blob.server_PutInInventory(mat))
		{
			mat.setPosition(blob.getPosition());
		}
	}

	return true;
}

//when the player is set, give materials if possible
void onSetPlayer(CRules@ this, CBlob@ blob, CPlayer@ player)
{
	if (!isServer()) return;
	
	if (blob is null) return;
	if (player is null) return;
	
	doGiveSpawnMats(this, player, blob);
}

//when player dies, unset archer flag so he can get arrows if he really sucks :)
//give a guy a break :)
void onPlayerDie(CRules@ this, CPlayer@ victim, CPlayer@ attacker, u8 customData)
{
	if (victim !is null)
	{
		SetCTFTimer(this, victim, 0, "archer");
		SetCTFTimer(this, victim, 0, "medic");
		SetCTFTimer(this, victim, 0, "spearman");
		SetCTFTimer(this, victim, 0, "musketman");
		SetCTFTimer(this, victim, 0, "weaponthrower");
		SetCTFTimer(this, victim, 0, "firelancer");
	}
}

//takes into account and sets the limiting timer
//prevents dying over and over, and allows getting more mats throughout the game
void doGiveSpawnMats(CRules@ this, CPlayer@ p, CBlob@ b)
{
	s32 gametime = getGameTime();
	string name = b.getName();
	
	if (name == "builder" || name == "rockthrower" || name == "warcrafter" || name == "demolitionist" || name == "chopper" || this.isWarmup()) 
	{
		if (gametime > getCTFTimer(this, p, "builder")) 
		{
			int wood_amount = matchtime_wood_amount;
			int stone_amount = matchtime_stone_amount;
			
			if (this.isWarmup()) 
			{
				wood_amount = warmup_wood_amount;
				stone_amount = warmup_stone_amount;
			}

			bool drop_mats = (name != "builder");
			
			bool did_give_wood = SetMaterials(b, "mat_wood", wood_amount, drop_mats);
			bool did_give_stone = SetMaterials(b, "mat_stone", stone_amount, drop_mats);
			
			if (did_give_wood || did_give_stone)
			{
				SetCTFTimer(this, p, gametime + (this.isWarmup() ? materials_wait_warmup : materials_wait)*getTicksASecond(), "builder");
			}
		}
	} 

	if (name == "archer" || name == "crossbowman") 
	{
		if (gametime > getCTFTimer(this, p, "archer")) 
		{
			/* disabled this in this mod
			CInventory@ inv = b.getInventory();
			if (inv.isInInventory("mat_arrows", 30)) 
			{
				return; // don't give arrows if they have 30 already
			}
			else */if (SetMaterials(b, "mat_arrows", 30)) 
			{
				SetCTFTimer(this, p, gametime + (this.isWarmup() ? materials_wait_warmup : materials_wait)*getTicksASecond(), "archer");
			}
		}
	}
	else if (name == "medic") 
	{
		if (gametime > getCTFTimer(this, p, "medic")) 
		{
			if (SetMaterials(b, "mat_medkits", 10)) 
			{
				SetCTFTimer(this, p, gametime + (this.isWarmup() ? materials_wait_warmup : materials_wait)*getTicksASecond(), "medic");
			}
		}
	}
	else if (name == "spearman") 
	{
		if (gametime > getCTFTimer(this, p, "spearman")) 
		{
			if (SetMaterials(b, "mat_spears", 10)) 
			{
				SetCTFTimer(this, p, gametime + (this.isWarmup() ? materials_wait_warmup : materials_wait)*getTicksASecond(), "spearman");
			}
		}
	}
	else if (name == "musketman" || name == "gunner") 
	{
		if (gametime > getCTFTimer(this, p, "musketman")) 
		{
			if (SetMaterials(b, "mat_bullets", 15)) 
			{
				SetCTFTimer(this, p, gametime + (this.isWarmup() ? materials_wait_warmup : materials_wait)*getTicksASecond(), "musketman");
			}
		}
	}
	else if (name == "weaponthrower") 
	{
		if (gametime > getCTFTimer(this, p, "weaponthrower")) 
		{
			if (SetMaterials(b, "mat_boomerangs", 15)) 
			{
				SetCTFTimer(this, p, gametime + (this.isWarmup() ? materials_wait_warmup : materials_wait)*getTicksASecond(), "weaponthrower");
			}
		}
	}
	else if (name == "firelancer") 
	{
		if (gametime > getCTFTimer(this, p, "firelancer")) 
		{
			if (SetMaterials(b, "mat_firelances", 5)) 
			{
				SetCTFTimer(this, p, gametime + (this.isWarmup() ? materials_wait_warmup : materials_wait)*getTicksASecond(), "firelancer");
			}
		}
	}
}

void Reset(CRules@ this)
{
	//restart everyone's timers
	for (uint i = 0; i < getPlayersCount(); ++i) {
		SetCTFTimer(this, getPlayer(i), 0, "builder");
		SetCTFTimer(this, getPlayer(i), 0, "archer");
	}
}

void onRestart(CRules@ this)
{
	Reset(this);
}

void onInit(CRules@ this)
{
	Reset(this);
}

void onTick(CRules@ this)
{
	if (!isServer())
		return;
	
	s32 gametime = getGameTime();
	
	if ((gametime % 15) != 5)
		return;
	
	if (this.isWarmup()) 
	{
		// during building time, give everyone resupplies no matter where they are
		for (int i = 0; i < getPlayerCount(); i++) 
		{
			CPlayer@ player = getPlayer(i);
			CBlob@ blob = player.getBlob();
			if (blob !is null) 
			{
				doGiveSpawnMats(this, player, blob);
			}
		}
	}
	else 
	{
		CBlob@[] spots;
		getBlobsByName(base_name(),   @spots);
		getBlobsByName("outpost",	@spots);
		getBlobsByName("warboat",	 @spots);
		getBlobsByName("buildershop", @spots);
		getBlobsByName("archershop",  @spots);
		getBlobsByName("knightshop",  @spots);
		for (uint step = 0; step < spots.length; ++step) 
		{
			CBlob@ spot = spots[step];
			if (spot is null) continue;

			CBlob@[] overlapping;
			if (!spot.getOverlapping(overlapping)) continue;

			string name = spot.getName();
			bool isShop = (name.find("shop") != -1);

			for (uint o_step = 0; o_step < overlapping.length; ++o_step) 
			{
				CBlob@ overlapped = overlapping[o_step];
				if (overlapped is null) continue;
				
				if (!overlapped.hasTag("player")) continue;
				CPlayer@ p = overlapped.getPlayer();
				if (p is null) continue;

				string class_name = overlapped.getName();
				
				//new style does not fit for my mod
				//if (isShop && name.find(class_name) == -1) continue; // NOTE: builder doesn't get wood+stone at archershop, archer doesn't get arrows at buildershop

				if (!(isShop && name.find(class_name) == -1) || // for other mods
					(name == "buildershop" && 
						(class_name == "builder"         ||
						 class_name == "rockthrower"     ||
						 class_name == "medic"           ||
						 class_name == "warcrafter"      ||
						 class_name == "butcher"         ||
						 class_name == "demolitionist")) ||
					(name == "knightshop" && 
						(class_name == "knight"    ||
						 class_name == "spearman"  ||
						 class_name == "assassin"  ||
						 class_name == "chopper"   ||
						 class_name == "warhammer" ||
						 class_name == "duelist")) ||
					(name == "archershop" &&
						(class_name == "archer"        ||
						 class_name == "crossbowman"   ||
						 class_name == "musketman"     ||
						 class_name == "weaponthrower" ||
						 class_name == "firelancer"    ||
						 class_name == "gunner")))
					doGiveSpawnMats(this, p, overlapped);
			}
		}
	}
}

// Reset timer in case player who joins has an outdated timer
void onNewPlayerJoin(CRules@ this, CPlayer@ player)
{
	s32 next_add_time = getGameTime() + (this.isWarmup() ? materials_wait_warmup : materials_wait) * getTicksASecond();

	if (next_add_time < getCTFTimer(this, player, "builder") ||
		next_add_time < getCTFTimer(this, player, "archer") ||
		next_add_time < getCTFTimer(this, player, "medic") ||
		next_add_time < getCTFTimer(this, player, "spearman") ||
		next_add_time < getCTFTimer(this, player, "musketman") ||
		next_add_time < getCTFTimer(this, player, "weaponthrower") ||
		next_add_time < getCTFTimer(this, player, "firelancer"))
	{
		SetCTFTimer(this, player, getGameTime(), "builder");
		SetCTFTimer(this, player, getGameTime(), "archer");
		SetCTFTimer(this, player, getGameTime(), "medic");
		SetCTFTimer(this, player, getGameTime(), "spearman");
		SetCTFTimer(this, player, getGameTime(), "musketman");
		SetCTFTimer(this, player, getGameTime(), "weaponthrower");
		SetCTFTimer(this, player, getGameTime(), "firelancer");
	}
}