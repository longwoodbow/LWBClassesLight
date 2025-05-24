#include "TradingCommon.as"
#include "Descriptions.as"
#include "ClassesConfig.as";
#include "LWBCosts.as";
//added new items.

#define SERVER_ONLY

int coinsOnDamageAdd = 2;
int coinsOnKillAdd = 10;
int coinsOnDeathLose = 10;
int min_coins = 50;
int max_coins = 100;

//
string cost_config_file = "tdm_vars.cfg";
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
	//load config

	if (getRules().exists("tdm_costs_config"))
		cost_config_file = getRules().get_string("tdm_costs_config");

	ConfigFile cfg = ConfigFile();
	cfg.loadFile(cost_config_file);

	s32 cost_bombs = cfg.read_s32("cost_bombs", 20);
	s32 cost_waterbombs = cfg.read_s32("cost_waterbombs", 40);
	s32 cost_keg = cfg.read_s32("cost_keg", 80);
	s32 cost_mine = cfg.read_s32("cost_mine", 50);

	s32 cost_arrows = cfg.read_s32("cost_arrows", 10);
	s32 cost_waterarrows = cfg.read_s32("cost_waterarrows", 40);
	s32 cost_firearrows = cfg.read_s32("cost_firearrows", 30);
	s32 cost_bombarrows = cfg.read_s32("cost_bombarrows", 50);

	s32 cost_boulder = cfg.read_s32("cost_boulder", 50);
	s32 cost_burger = cfg.read_s32("cost_burger", 40);
	s32 cost_sponge = cfg.read_s32("cost_sponge", 20);

	s32 cost_mountedbow = cfg.read_s32("cost_mountedbow", -1);
	//s32 cost_drill = cfg.read_s32("cost_drill", -1);//uses LWBCosts.as
	s32 cost_catapult = cfg.read_s32("cost_catapult", -1);
	s32 cost_ballista = cfg.read_s32("cost_ballista", -1);

	//don't use genuine default
	//s32 menu_width = cfg.read_s32("trade_menu_width", 3);
	//s32 menu_height = cfg.read_s32("trade_menu_height", 5);

	// build menu
	CreateTradeMenu(trader, Vec2f(LWB_TDMCosts::menu_width, LWB_TDMCosts::menu_height), "Buy weapons");

	//
	addTradeSeparatorItem(trader, "$MENU_GENERIC$", Vec2f(3, 1));

	//yummy stuff
	addItemForCoin(trader, "Burger", cost_burger, true, "$food$", "food", Descriptions::food);
	//knighty stuff
	if(ClassesConfig::knight)addItemForCoin(trader, "Bomb", cost_bombs, true, "$mat_bombs$", "mat_bombs", Descriptions::bomb);
	if(ClassesConfig::knight)addItemForCoin(trader, "Water Bomb", cost_waterbombs, true, "$mat_waterbombs$", "mat_waterbombs", Descriptions::waterbomb);
	if(ClassesConfig::knight)addItemForCoin(trader, "Keg", cost_keg, true, "$keg$", "keg", Descriptions::keg);
	if(ClassesConfig::spearman)addItemForCoin(trader, "Spears", LWB_TDMCosts::cost_spears, true, "$mat_spears$", "mat_spears", "Spare Spears for Spearman. Throw them to enemies.");
	if(ClassesConfig::spearman)addItemForCoin(trader, "Fire Spear", LWB_TDMCosts::cost_firespears, true, "$mat_firespears$", "mat_firespears", "Fire Spear for Spearman. Make spear attacking or thrown spear ignitable once.");
	if(ClassesConfig::assassin)addItemForCoin(trader, "Smoke Ball", LWB_TDMCosts::cost_smokeball, true, "$mat_smokeball$", "mat_smokeball", "Smoke Ball for Assassin. Can stun nearly enemies.");
	addItemForCoin(trader, "Mine", cost_mine, true, "$mine$", "mine", Descriptions::mine);
	//archery stuff
	addItemForCoin(trader, "Arrows", cost_arrows, true, "$mat_arrows$", "mat_arrows", Descriptions::arrows);
	addItemForCoin(trader, "Water Arrows", cost_waterarrows, true, "$mat_waterarrows$", "mat_waterarrows", Descriptions::waterarrows);
	addItemForCoin(trader, "Fire Arrows", cost_firearrows, true, "$mat_firearrows$", "mat_firearrows", Descriptions::firearrows);
	addItemForCoin(trader, "Bomb Arrow", cost_bombarrows, true, "$mat_bombarrows$", "mat_bombarrows", Descriptions::bombarrows);
	if(ClassesConfig::musketman || ClassesConfig::gunner)addItemForCoin(trader, "Bullets", LWB_TDMCosts::cost_bullets, true, "$mat_bullets$", "mat_bullets", "Lead ball and gunpowder in a paper for Musketman.");
	if(ClassesConfig::musketman)addItemForCoin(trader, "Barricade ", LWB_TDMCosts::cost_barricades, true, "$mat_barricades$", "mat_barricades", "Ballicade frames for Musketman.");
	if(ClassesConfig::weaponthrower)addItemForCoin(trader, "Boomerangs", LWB_TDMCosts::cost_boomerangs, true, "$mat_boomerangs$", "mat_boomerangs", "Boomerangs for Weapon Thrower.\nReal battle boomerangs don't return because it is danger.");
	if(ClassesConfig::weaponthrower)addItemForCoin(trader, "Chakrams", LWB_TDMCosts::cost_chakrams, true, "$mat_chakrams$", "mat_chakrams", "Chakrams for Weapon Thrower.\nHas no long range but powerful and can break blocks.");
	if(ClassesConfig::firelancer)addItemForCoin(trader, "Fire Lances", LWB_TDMCosts::cost_firelances, true, "$mat_firelances$", "mat_firelances", "Chinese boomsticks for Fire Lancer.");
	if(ClassesConfig::firelancer)addItemForCoin(trader, "Flame Thrower", LWB_TDMCosts::cost_flamethrowers, true, "$mat_flamethrowers$", "mat_flamethrowers", "Fire Lance shaped flame thrower for Fire Lancer.");
	//utility stuff
	if(ClassesConfig::rockthrower)addItemForCoin(trader, "Wood", LWB_TDMCosts::cost_wood, true, "$mat_wood$", "mat_wood", Descriptions::wood);
	if(ClassesConfig::rockthrower)addItemForCoin(trader, "Stone", LWB_TDMCosts::cost_stone, true, "$mat_stone$", "mat_stone", Descriptions::stone);
	if(ClassesConfig::medic)addItemForCoin(trader, "Med Kit", LWB_TDMCosts::cost_medkit, true, "$mat_medkits$", "mat_medkits", "Med kit for Medic. Can be used 10 times.");
	if(ClassesConfig::medic)addItemForCoin(trader, "Water in a Jar", LWB_TDMCosts::cost_waterjar, true, "$mat_waterjar$", "mat_waterjar", "Water for Medic Spray.");
	if(ClassesConfig::medic)addItemForCoin(trader, "Acid in a Jar", LWB_TDMCosts::cost_acidjar, true, "$mat_acidjar$", "mat_acidjar", "Acid for Medic Spray.\nCan damage blocks and enemies.");
	addItemForCoin(trader, "Sponge", cost_sponge, true, "$sponge$", "sponge", Descriptions::sponge);
	addItemForCoin(trader, "Mounted Bow", cost_mountedbow, true, "$mounted_bow$", "mounted_bow", Descriptions::mounted_bow);
	if(ClassesConfig::rockthrower)addItemForCoin(trader, "Drill", LWB_TDMCosts::cost_drill, true, "$drill$", "drill", Descriptions::drill + "\n\nRock Thrower can use this too.");
	addItemForCoin(trader, "Boulder", cost_boulder, true, "$boulder$", "boulder", Descriptions::boulder);
	if(ClassesConfig::butcher)addItemForCoin(trader, "Oil Bottles", LWB_TDMCosts::cost_oil, true, "$mat_cookingoils$", "mat_cookingoils", "Cooking Oil Bottle for Butcher.\nCan ignite somethings and cook steak and fishy to save.");
	if(ClassesConfig::butcher)addItemForCoin(trader, "Poisonous Meat", LWB_TDMCosts::cost_poisonmeats, true, "$mat_poisonmeats$", "mat_poisonmeats", "Poisonous Meat for Butcher.\nRight Click to throw.");
	//addItemForCoin(trader, "Bomb Box", cost_bombboxes, true, "$mat_bombboxes$", "mat_bombboxes", "Bomb Box for Demolitionist.");
	//vehicles
	addItemForCoin(trader, "Catapult", cost_catapult, true, "$catapult$", "catapult", Descriptions::catapult);
	addItemForCoin(trader, "Ballista", cost_ballista, true, "$ballista$", "ballista", Descriptions::ballista);
}

// load coins amount

void Reset(CRules@ this)
{
	//load the coins vars now, good a time as any
	if (this.exists("tdm_costs_config"))
		cost_config_file = this.get_string("tdm_costs_config");

	ConfigFile cfg = ConfigFile();
	cfg.loadFile(cost_config_file);

	coinsOnDamageAdd = cfg.read_s32("coinsOnDamageAdd", coinsOnDamageAdd);
	coinsOnKillAdd = cfg.read_s32("coinsOnKillAdd", coinsOnKillAdd);
	coinsOnDeathLose = cfg.read_s32("coinsOnDeathLose", coinsOnDeathLose);
	min_coins = cfg.read_s32("minCoinsOnRestart", min_coins);
	max_coins = cfg.read_s32("maxCoinsOnRestart", max_coins);

	kill_traders_and_shops = !(cfg.read_bool("spawn_traders_ever", true));

	if (kill_traders_and_shops)
	{
		KillTradingPosts();
	}

	//clamp coin vars each round
	for (int i = 0; i < getPlayersCount(); i++)
	{
		CPlayer@ player = getPlayer(i);
		if (player is null) continue;

		s32 coins = player.getCoins();
		if (min_coins >= 0) coins = Maths::Max(coins, min_coins);
		if (max_coins >= 0) coins = Maths::Min(coins, max_coins);
		player.server_setCoins(coins);
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
				killer.server_setCoins(killer.getCoins() + coinsOnKillAdd);
			}
		}

		victim.server_setCoins(victim.getCoins() - coinsOnDeathLose);
	}
}

// give coins for damage

f32 onPlayerTakeDamage(CRules@ this, CPlayer@ victim, CPlayer@ attacker, f32 DamageScale)
{
	if (attacker !is null && attacker !is victim)
	{
		attacker.server_setCoins(attacker.getCoins() + DamageScale * coinsOnDamageAdd / this.attackdamage_modifier);
	}

	return DamageScale;
}
