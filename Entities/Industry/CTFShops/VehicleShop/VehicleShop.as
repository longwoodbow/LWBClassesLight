// Vehicle Workshop

#include "Requirements.as"
#include "Requirements_Tech.as"
#include "ShopCommon.as"
#include "Descriptions.as"
#include "Costs.as"
#include "CheckSpam.as"
#include "TeamIconToken.as"
#include "LWBCosts.as";

void onInit(CBlob@ this)
{
	this.set_TileType("background tile", CMap::tile_wood_back);

	this.getSprite().SetZ(-50); //background
	this.getShape().getConsts().mapCollisions = false;

	this.Tag("has window");

	//INIT COSTS
	InitCosts();

	// SHOP
	this.set_Vec2f("shop offset", Vec2f_zero);
	this.set_Vec2f("shop menu size", Vec2f(6, 5));
	this.set_string("shop description", "Buy");
	this.set_u8("shop icon", 25);

	int team_num = this.getTeamNum();

	{
		string cata_icon = getTeamIcon("catapult", "VehicleIcons.png", team_num, Vec2f(32, 32), 0);
		ShopItem@ s = addShopItem(this, "Catapult", cata_icon, "catapult", cata_icon + "\n\n\n" + Descriptions::catapult, false, true);
		s.crate_icon = 4;
		AddRequirement(s.requirements, "coin", "", "Coins", CTFCosts::catapult);
	}
	{
		string ballista_icon = getTeamIcon("ballista", "VehicleIcons.png", team_num, Vec2f(32, 32), 1);
		ShopItem@ s = addShopItem(this, "Ballista", ballista_icon, "ballista", ballista_icon + "\n\n\n" + Descriptions::ballista, false, true);
		s.crate_icon = 5;
		AddRequirement(s.requirements, "coin", "", "Coins", CTFCosts::ballista);
	}
	{
		string outpost_icon = getTeamIcon("outpost", "VehicleIcons.png", team_num, Vec2f(32, 32), 6);
		ShopItem@ s = addShopItem(this, "Outpost", outpost_icon, "outpost", outpost_icon + "\n\n\n" + Descriptions::outpost, false, true);
		s.crate_icon = 7;
		AddRequirement(s.requirements, "coin", "", "Coins", CTFCosts::outpost_coins);
		AddRequirement(s.requirements, "blob", "mat_gold", "Gold", CTFCosts::outpost_gold);
	}
	{
		ShopItem@ s = addShopItem(this, "Ballista Bolts", "$mat_bolts$", "mat_bolts", "$mat_bolts$\n\n\n" + Descriptions::ballista_ammo, false, false);
		s.crate_icon = 5;
		s.customButton = true;
		s.buttonwidth = 2;
		s.buttonheight = 1;
		AddRequirement(s.requirements, "coin", "", "Coins", CTFCosts::ballista_ammo);
	}
	{
		ShopItem@ s = addShopItem(this, "Ballista Shells", "$mat_bomb_bolts$", "mat_bomb_bolts", "$mat_bomb_bolts$\n\n\n" + Descriptions::ballista_bomb_ammo, false, false);
		s.crate_icon = 5;
		s.customButton = true;
		s.buttonwidth = 2;
		s.buttonheight = 1;
		AddRequirement(s.requirements, "coin", "", "Coins", CTFCosts::ballista_bomb_ammo);
	}
	{
		ShopItem@ s = addShopItem(this, "Light Ballista", "$lightballista$", "lightballista", "$lightballista$\n\n\nCan't shoot bomb ammo, but cheap. Useful to attack enemy and make arrow ladders.", false, true);
		s.crate_icon = 23;
		s.customButton = true;
		s.buttonwidth = 2;
		s.buttonheight = 1;
		AddRequirement(s.requirements, "coin", "", "Coins", LWB_CTFCosts::lightballista);
	}
	{
		ShopItem@ s = addShopItem(this, "Mounted Bow", "$mounted_bow$", "mounted_bow", "$mounted_bow$\n\n\n" + Descriptions::mounted_bow, false, true);
		s.crate_icon = 6;
		AddRequirement(s.requirements, "coin", "", "Coins", LWB_CTFCosts::mountedbow);
	}
	{
		string mounted_gun_icon = getTeamIcon("mounted_gun", "MountedGun.png", team_num, Vec2f(16, 16), 6);
		ShopItem@ s = addShopItem(this, "Mounted Gun", mounted_gun_icon, "mounted_gun", mounted_gun_icon + "\n\n\n" + "Gun edition of mounted bow. Has decent accuracy and fire rate.", false, true);
		s.crate_icon = 11;
		AddRequirement(s.requirements, "coin", "", "Coins", LWB_CTFCosts::mountedgun);
	}
	{
		string crankedgun_icon = getTeamIcon("crankedgun", "GunpowderWeaponIcons.png", team_num, Vec2f(32, 16), 1);
		ShopItem@ s = addShopItem(this, "Cranked Gun", crankedgun_icon , "crankedgun", crankedgun_icon + "\n\n\n" + "Manual machine gun. This a little overtechnology weapon can shoot a lot of bullets.", false, true);
		s.crate_icon = 21;
		s.customButton = true;
		s.buttonwidth = 2;
		s.buttonheight = 1;
		AddRequirement(s.requirements, "coin", "", "Coins", LWB_CTFCosts::crankedgun);
	}
	{
		string cannon_icon = getTeamIcon("cannon", "GunpowderWeaponIcons.png", team_num, Vec2f(32, 16), 0);
		ShopItem@ s = addShopItem(this, "Cannon", cannon_icon, "cannon", cannon_icon + "\n\n\n" + "Very powerful siege, it makes you to break dense walls easier.", false, true);
		s.crate_icon = 22;
		s.customButton = true;
		s.buttonwidth = 2;
		s.buttonheight = 1;
		AddRequirement(s.requirements, "coin", "", "Coins", LWB_CTFCosts::cannon);
	}
	{
		ShopItem@ s = addShopItem(this, "Cannon Balls", "$mat_cannonballs$", "mat_cannonballs", "The ammo for cannon.", false, false);
		AddRequirement(s.requirements, "coin", "", "Coins", LWB_CTFCosts::cannonballs);
	}
	{
		ShopItem@ s = addShopItem(this, "Bomb Ball", "$bombball$", "bombball", "Explode when drop or launch by catapult.\nIt doesn't hurt allies, but be careful.", false, false);
		AddRequirement(s.requirements, "coin", "", "Coins", LWB_CTFCosts::bombball);
	}
}

void GetButtonsFor(CBlob@ this, CBlob@ caller)
{
	this.set_bool("shop available", this.isOverlapping(caller));
}

void onCommand(CBlob@ this, u8 cmd, CBitStream @params)
{
	if (cmd == this.getCommandID("shop made item client") && isClient())
	{
		this.getSprite().PlaySound("/ChaChing.ogg");
	}
}
