// ArcherShop.as

#include "Requirements.as"
#include "ShopCommon.as"
#include "Descriptions.as"
#include "CheckSpam.as"
#include "Costs.as"
#include "GenericButtonCommon.as"
#include "ClassSelectMenu.as"
#include "ClassesConfig.as"
#include "LWBCosts.as";
#include "StandardRespawnCommand.as";

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
	this.set_Vec2f("shop menu size", Vec2f(4, 4));
	this.set_string("shop description", "Buy");
	this.set_u8("shop icon", 25);

	// CLASS
	this.set_Vec2f("class offset", Vec2f(-6, 0));

	// CLASS CHANGE
	if(ClassesConfig::archer) addPlayerClass(this, "Archer", "$archer_class_icon$", "archer", ClassesDescriptions::archer);
	if(ClassesConfig::crossbowman) addPlayerClass(this, "Crossbowman", "$crossbowman_class_icon$", "crossbowman", ClassesDescriptions::crossbowman);
	if(ClassesConfig::musketman) addPlayerClass(this, "Musketman", "$musketman_class_icon$", "musketman", ClassesDescriptions::musketman);
	if(ClassesConfig::weaponthrower) addPlayerClass(this, "Weapon Thrower", "$weaponthrower_class_icon$", "weaponthrower", ClassesDescriptions::weaponthrower);
	if(ClassesConfig::firelancer) addPlayerClass(this, "Fire Lancer", "$firelancer_class_icon$", "firelancer", ClassesDescriptions::firelancer);
	if(ClassesConfig::gunner) addPlayerClass(this, "Gunner", "$gunner_class_icon$", "gunner", ClassesDescriptions::gunner);
	this.Tag("multi classes");

	{
		ShopItem@ s = addShopItem(this, "Arrows", "$mat_arrows$", "mat_arrows", Descriptions::arrows, true);
		AddRequirement(s.requirements, "coin", "", "Coins", CTFCosts::arrows);
	}
	{
		ShopItem@ s = addShopItem(this, "Water Arrows", "$mat_waterarrows$", "mat_waterarrows", Descriptions::waterarrows, true);
		AddRequirement(s.requirements, "coin", "", "Coins", CTFCosts::waterarrows);
	}
	{
		ShopItem@ s = addShopItem(this, "Fire Arrows", "$mat_firearrows$", "mat_firearrows", Descriptions::firearrows, true);
		AddRequirement(s.requirements, "coin", "", "Coins", CTFCosts::firearrows);
	}
	{
		ShopItem@ s = addShopItem(this, "Bomb Arrows", "$mat_bombarrows$", "mat_bombarrows", Descriptions::bombarrows, true);
		AddRequirement(s.requirements, "coin", "", "Coins", CTFCosts::bombarrows);
	}
	if(ClassesConfig::musketman || ClassesConfig::gunner)
	{
		ShopItem@ s = addShopItem(this, "Bullets", "$mat_bullets$", "mat_bullets", "Lead ball and gunpowder in a paper for Musketman and Gunner.", true);
		AddRequirement(s.requirements, "coin", "", "Coins", LWB_CTFCosts::bullets);
	}
	if(ClassesConfig::musketman)
	{
		ShopItem@ s = addShopItem(this, "Barricade Frames", "$mat_barricades$", "mat_barricades", "Ballicade frames for Musketman.", true);
		AddRequirement(s.requirements, "coin", "", "Coins", LWB_CTFCosts::barricadeframes);
	}
	if(ClassesConfig::weaponthrower)
	{
		{
			ShopItem@ s = addShopItem(this, "Boomerangs", "$mat_boomerangs$", "mat_boomerangs", "Boomerangs for Weapon Thrower.\nReal battle boomerangs don't return because it is danger.", true);
			AddRequirement(s.requirements, "coin", "", "Coins", LWB_CTFCosts::boomerangs);
		}
		{
			ShopItem@ s = addShopItem(this, "Chakrams", "$mat_chakrams$", "mat_chakrams", "Chakrams for Weapon Thrower.\nHas no long range but powerful and can break blocks.", true);
			AddRequirement(s.requirements, "coin", "", "Coins", LWB_CTFCosts::chakrams);
		}
	}
	if(ClassesConfig::firelancer)
	{
		{
			ShopItem@ s = addShopItem(this, "Fire Lances", "$mat_firelances$", "mat_firelances", "Chinese boomsticks for Fire Lancer.", true);
			AddRequirement(s.requirements, "coin", "", "Coins", LWB_CTFCosts::firelances);
		}
		{
			ShopItem@ s = addShopItem(this, "Flame Throwers", "$mat_flamethrowers$", "mat_flamethrowers", "Fire Lance shaped flame thrower for Fire Lancer.", true);
			AddRequirement(s.requirements, "coin", "", "Coins", LWB_CTFCosts::flamethrowers);
		}
	}
}

void GetButtonsFor(CBlob@ this, CBlob@ caller)
{
	AddIconToken("$archer_class_icon$", "GUI/MenuItems.png", Vec2f(32, 32), 16, caller.getTeamNum());
	AddIconToken("$crossbowman_class_icon$", "GUI/LWBClassIcons.png", Vec2f(32, 32), 4, caller.getTeamNum());
	AddIconToken("$musketman_class_icon$", "GUI/LWBClassIcons.png", Vec2f(32, 32), 5, caller.getTeamNum());
	AddIconToken("$weaponthrower_class_icon$", "GUI/LWBClassIcons.png", Vec2f(32, 32), 12, caller.getTeamNum());
	AddIconToken("$firelancer_class_icon$", "GUI/LWBClassIcons.png", Vec2f(32, 32), 13, caller.getTeamNum());
	AddIconToken("$gunner_class_icon$", "GUI/LWBClassIcons.png", Vec2f(32, 32), 14, caller.getTeamNum());
	if (!canSeeButtons(this, caller)) return;
	PlayerClass[]@ classes;
	if (this.get("playerclasses", @classes) && classes.length() > 0)
	{
		this.set_Vec2f("shop offset", Vec2f(6, 0));
	}
	else
	{
		this.set_Vec2f("shop offset", Vec2f_zero);
	}
	this.set_bool("shop available", this.isOverlapping(caller));
}

void onCommand(CBlob@ this, u8 cmd, CBitStream @params)
{
	if (cmd == this.getCommandID("shop made item client") && isClient())
	{
		this.getSprite().PlaySound("/ChaChing.ogg");
	}
}