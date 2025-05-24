#include "TradingCommon.as"
#include "Descriptions.as"
#include "GameplayEventsCommon.as";
#include "ClassesConfig.as";
#include "DTSConfig.as"

#define SERVER_ONLY

bool kill_traders_and_shops = false;

void onBlobCreated(CRules@ this, CBlob@ blob)
{
	if (blob.getName() == "tradingpost")
	{
		if (kill_traders_and_shops)
		{
			blob.server_Die();
			KillTradingPosts();
		}
		else
		{
			MakeTradeMenu(blob);
		}
	}
}

TradeItem@ addItemForCoin(CBlob@ this, const string &in name, int cost, const bool instantShipping, const string &in iconName, const string &in configFilename, const string &in description)
{
	if(cost <= 0) {
		return null;
	}

	TradeItem@ item = addTradeItem(this, name, 0, instantShipping, iconName, configFilename, description);
	if (item !is null)
	{
		AddRequirement(item.reqs, "coin", "", "Coins", cost);
		item.buyIntoInventory = true;
	}
	return item;
}

void MakeTradeMenu(CBlob@ trader)
{
	// build menu
	CreateTradeMenu(trader, Vec2f(DTSConfig::menu_width, DTSConfig::menu_height), "Buy weapons");

	//
	addTradeSeparatorItem(trader, "$MENU_GENERIC$", Vec2f(3, 1));

	//yummy stuff
	addItemForCoin(trader, "Burger", DTSConfig::cost_burger, true, "$food$", "food", Descriptions::food);
	//knighty stuff
	if(ClassesConfig::knight)addItemForCoin(trader, "Bomb", DTSConfig::cost_bombs, true, "$mat_bombs$", "mat_bombs", Descriptions::bomb);
	if(ClassesConfig::knight)addItemForCoin(trader, "Water Bomb", DTSConfig::cost_waterbombs, true, "$mat_waterbombs$", "mat_waterbombs", Descriptions::waterbomb);
	if(ClassesConfig::knight)addItemForCoin(trader, "Keg", DTSConfig::cost_keg, true, "$keg$", "keg", Descriptions::keg);
	if(ClassesConfig::spearman)addItemForCoin(trader, "Spears", DTSConfig::cost_spears, true, "$mat_spears$", "mat_spears", "Spare Spears for Spearman. Throw them to enemies.");
	if(ClassesConfig::spearman)addItemForCoin(trader, "Fire Spear", DTSConfig::cost_firespears, true, "$mat_firespears$", "mat_firespears", "Fire Spear for Spearman. Make spear attacking or thrown spear ignitable once.");
	if(ClassesConfig::assassin)addItemForCoin(trader, "Smoke Ball", DTSConfig::cost_smokeball, true, "$mat_smokeball$", "mat_smokeball", "Smoke Ball for Assassin. Can stun nearly enemies.");
	addItemForCoin(trader, "Mine", DTSConfig::cost_mine, true, "$mine$", "mine", Descriptions::mine);
	//archery stuff
	addItemForCoin(trader, "Arrows", DTSConfig::cost_arrows, true, "$mat_arrows$", "mat_arrows", Descriptions::arrows);
	addItemForCoin(trader, "Water Arrows", DTSConfig::cost_waterarrows, true, "$mat_waterarrows$", "mat_waterarrows", Descriptions::waterarrows);
	addItemForCoin(trader, "Fire Arrows", DTSConfig::cost_firearrows, true, "$mat_firearrows$", "mat_firearrows", Descriptions::firearrows);
	addItemForCoin(trader, "Bomb Arrow", DTSConfig::cost_bombarrows, true, "$mat_bombarrows$", "mat_bombarrows", Descriptions::bombarrows);
	if(ClassesConfig::musketman || ClassesConfig::gunner)addItemForCoin(trader, "Bullets", DTSConfig::cost_bullets, true, "$mat_bullets$", "mat_bullets", "Lead ball and gunpowder in a paper for Musketman.");
	if(ClassesConfig::musketman)addItemForCoin(trader, "Barricade ", DTSConfig::cost_barricades, true, "$mat_barricades$", "mat_barricades", "Ballicade frames for Musketman.");
	if(ClassesConfig::weaponthrower)addItemForCoin(trader, "Boomerangs", DTSConfig::cost_boomerangs, true, "$mat_boomerangs$", "mat_boomerangs", "Boomerangs for Weapon Thrower.\nReal battle boomerangs don't return because it is danger.");
	if(ClassesConfig::weaponthrower)addItemForCoin(trader, "Chakrams", DTSConfig::cost_chakrams, true, "$mat_chakrams$", "mat_chakrams", "Chakrams for Weapon Thrower.\nHas no long range but powerful and can break blocks.");
	if(ClassesConfig::firelancer)addItemForCoin(trader, "Fire Lances", DTSConfig::cost_firelances, true, "$mat_firelances$", "mat_firelances", "Chinese boomsticks for Fire Lancer.");
	if(ClassesConfig::firelancer)addItemForCoin(trader, "Flame Thrower", DTSConfig::cost_flamethrowers, true, "$mat_flamethrowers$", "mat_flamethrowers", "Fire Lance shaped flame thrower for Fire Lancer.");
	//utility stuff
	if(ClassesConfig::rockthrower)addItemForCoin(trader, "Wood", DTSConfig::cost_wood, true, "$mat_wood$", "mat_wood", Descriptions::wood);
	if(ClassesConfig::rockthrower)addItemForCoin(trader, "Stone", DTSConfig::cost_stone, true, "$mat_stone$", "mat_stone", Descriptions::stone);
	if(ClassesConfig::medic)addItemForCoin(trader, "Med Kit", DTSConfig::cost_medkit, true, "$mat_medkits$", "mat_medkits", "Med kit for Medic. Can be used 10 times.");
	if(ClassesConfig::medic)addItemForCoin(trader, "Water in a Jar", DTSConfig::cost_waterjar, true, "$mat_waterjar$", "mat_waterjar", "Water for Medic Spray.");
	if(ClassesConfig::medic)addItemForCoin(trader, "Acid in a Jar", DTSConfig::cost_acidjar, true, "$mat_acidjar$", "mat_acidjar", "Acid for Medic Spray.\nCan damage blocks and enemies.");
	addItemForCoin(trader, "Sponge", DTSConfig::cost_sponge, true, "$sponge$", "sponge", Descriptions::sponge);
	addItemForCoin(trader, "Mounted Bow", DTSConfig::cost_mountedbow, true, "$mounted_bow$", "mounted_bow", Descriptions::mounted_bow);
	addItemForCoin(trader, "Mounted Gun", DTSConfig::cost_mountedgun, false, "$mounted_gun$", "mounted_gun", "Gun edition of mounted bow. Has decent accuracy and fire rate.");
	if(ClassesConfig::rockthrower)addItemForCoin(trader, "Drill", DTSConfig::cost_drill, true, "$drill$", "drill", Descriptions::drill + "\n\nRock Thrower can use this too.");
	addItemForCoin(trader, "Boulder", DTSConfig::cost_boulder, true, "$boulder$", "boulder", Descriptions::boulder);
	if(ClassesConfig::butcher)addItemForCoin(trader, "Oil Bottles", DTSConfig::cost_cookingoils, true, "$mat_cookingoils$", "mat_cookingoils", "Cooking Oil Bottle for Butcher.\nCan ignite somethings and cook steak and fishy to save.");
	if(ClassesConfig::butcher)addItemForCoin(trader, "Poisonous Meat", DTSConfig::cost_poisonmeats, true, "$mat_poisonmeats$", "mat_poisonmeats", "Poisonous Meat for Butcher.\nRight Click to throw.");
	//addItemForCoin(trader, "Bomb Box", DTSConfig::cost_bombboxes, true, "$mat_bombboxes$", "mat_bombboxes", "Bomb Box for Demolitionist.");
	//vehicles
	addItemForCoin(trader, "Catapult", DTSConfig::cost_catapult, false, "$catapult$", "catapult", Descriptions::catapult);
	addItemForCoin(trader, "Ballista", DTSConfig::cost_ballista, false, "$ballista$", "ballista", Descriptions::ballista);
	addItemForCoin(trader, "Cranked Gun", DTSConfig::cost_cannon, false, "$crankedgun$", "crankedgun", "Manual machine gun. This a little overtechnology weapon can shoot a lot of bullets.");
	addItemForCoin(trader, "Cannon", DTSConfig::cost_cannon, false, "$cannon$", "cannon", "Very powerful siege, it makes you to break dense walls easier.");

}

// load coins amount

void Reset(CRules@ this)
{
	kill_traders_and_shops = !(DTSConfig::spawn_traders_ever);

	if (kill_traders_and_shops)
	{
		KillTradingPosts();
	}

	//reset coins
	for (int i = 0; i < getPlayersCount(); i++)
	{
		CPlayer@ player = getPlayer(i);
		if (player is null) continue;

		player.server_setCoins(0);
	}

}

void onRestart(CRules@ this)
{
	CGameplayEvent@ func = @awardCoins;
	getRules().set("awardCoins handle", @func );

	Reset(this);
}

void onInit(CRules@ this)
{
	CGameplayEvent@ func = @awardCoins;
	getRules().set("awardCoins handle", @func );

	Reset(this);
}


void KillTradingPosts()
{
	CBlob@[] tradingposts;
	bool found = false;
	if (getBlobsByName("tradingpost", @tradingposts))
	{
		for (uint i = 0; i < tradingposts.length; i++)
		{
			CBlob @b = tradingposts[i];
			b.server_Die();
		}
	}
}

// give coins for killing

void onPlayerDie(CRules@ this, CPlayer@ victim, CPlayer@ killer, u8 customData)
{
	if (victim !is null)
	{
		if (killer !is null)
		{
			if (killer !is victim && killer.getTeamNum() != victim.getTeamNum())
			{
				killer.server_setCoins(killer.getCoins() + DTSConfig::coinsOnKillAdd);
			}
		}

		victim.server_setCoins(victim.getCoins() - DTSConfig::coinsOnDeathLose);
		CBlob@ blob = victim.getBlob();
		if (blob !is null)
			server_DropCoins(blob.getPosition(), XORRandom(DTSConfig::coinsOnDeathLose));
	}
}

// give coins for damage

f32 onPlayerTakeDamage(CRules@ this, CPlayer@ victim, CPlayer@ attacker, f32 DamageScale)
{
	if (attacker !is null && attacker !is victim)
	{
		attacker.server_setCoins(attacker.getCoins() + DamageScale * DTSConfig::coinsOnDamageAdd / this.attackdamage_modifier);
	}

	return DamageScale;
}

// Gameplay events stuff

void awardCoins(CBitStream@ params)
{
	if (!isServer()) return;

	params.ResetBitIndex();

	u8 event_id;
	if (!params.saferead_u8(event_id)) return;

	u16 player_id;
	if (!params.saferead_u16(player_id)) return;

	CPlayer@ p = getPlayerByNetworkId(player_id);
	if (p is null) return;

	u32 coins = 0;

	if (event_id == CGameplayEvent_IDs::HitVehicle)
	{
		f32 damage; 
		if (!params.saferead_f32(damage)) return;

		coins = DTSConfig::coinsOnHitSiege * damage;
	}
	else if (event_id == CGameplayEvent_IDs::KillVehicle)
	{
		coins = DTSConfig::coinsOnKillSiege;
	}
	else if (event_id == CGameplayEvent_IDs::HitStatue)
	{
		f32 damage; 
		if (!params.saferead_f32(damage)) return;

		coins = DTSConfig::coinsOnHitSiege * damage;
	}
	else if (event_id == CGameplayEvent_IDs::KillStatue)
	{
		coins = DTSConfig::coinsOnKillSiege;
	}
	else if (event_id == CGameplayEvent_IDs::MedicHeal)
	{
		f32 amount; 
		if (!params.saferead_f32(amount)) return;

		coins = DTSConfig::coinsOnMedicHeal * amount;
	}

	if (coins > 0)
	{
		p.server_setCoins(p.getCoins() + coins);
	}
}