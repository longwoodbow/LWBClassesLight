namespace DTSConfig
{
	// dts base config

	// how long to wait per-spawn
	const int spawnTimeSeconds	    = 5;

	// how long before the game
	const int warmUpTimeSeconds 	= 1;

	// how long the game runs for
	const float gameDurationMinutes   = -1.0f;

	// whether to scramble each game
	const bool scramble_teams		= true;

	// whether to scramble the mapcycle
	//  0 = no
	//  1 = yes
	// -1 = let autoconfig decide
	const int scramble_maps 		= -1;

	// how much to nerf fall damage for
	// easy movement (1.0 is normal)
	const float fall_dmg_nerf		    = 1.2f;

	// dts coin economy

	// coins for performing various actions
	// during the game - can be spent at trader.
	const int coinsOnDamageAdd      = 2;
	const int coinsOnKillAdd        = 10;
	const int coinsOnDeathLose      = 20;

	const int coinsOnHitSiege       = 2; //per heart of damage
	const int coinsOnKillSiege      = 20;

	const int coinsOnHitStatue      = 2; //per heart of damage
	const int coinsOnKillStatue     = 100;
	const int coinsOnMedicHeal		= 1;

	// health of statues
	const float statueHealth        = 50.0f;

	// heal cooldown of heal spots
	const int healCooldown          = 45;

	// dts trading

	// enable/disable shops completely

	// costs
	// (you cant add custom items by default,
	//  see DTS_Trading for how it's done)

	// set to <= 0 to remove the item
	// from the trading menu completely
	const int cost_bombs            = 20;
	const int cost_waterbombs       = 30;
	const int cost_keg              = 80;
	const int cost_spears           = 10;
	const int cost_firespears       = 30;
	const int cost_smokeball        = 50;
	const int cost_mine             = 50;
    
	const int cost_arrows           = 10;
	const int cost_waterarrows      = 30;
	const int cost_firearrows       = 30;
	const int cost_bombarrows       = 50;
	const int cost_bullets          = 10;
	const int cost_barricades       = 50;
	const int cost_boomerangs       = 10;
	const int cost_chakrams         = 20;
	const int cost_firelances       = 10;
	const int cost_flamethrowers    = 40;
    
	const int cost_boulder          = 40;
	const int cost_burger           = 30;
	const int cost_sponge           = 15;
    
	const int cost_wood             = 50;
	const int cost_stone            = 100;
	const int cost_medkit           = 10;
	const int cost_waterjar         = 30;
	const int cost_acidjar          = 30;
	const int cost_mountedbow       = 50;
	const int cost_mountedgun       = 75;
	const int cost_drill            = 50;
	const int cost_cookingoils      = 40;
	const int cost_poisonmeats      = 30;
	const int cost_catapult         = 80;
	const int cost_ballista         = -1;
	const int cost_crankedgun       = 250;
	const int cost_cannon           = 100;

	// enable/disable shops completely

	const bool spawn_traders_ever    = true;

	// menu size
	const int menu_width            = 8;
	const int menu_height           = 7;
}