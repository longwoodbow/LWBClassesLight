// Knight Workshop

#include "Requirements.as"
#include "ShopCommon.as"
#include "Descriptions.as"
#include "Costs.as"
#include "CheckSpam.as"
#include "GenericButtonCommon.as"
#include "TeamIconToken.as"
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
	this.set_Vec2f("shop menu size", Vec2f(4, 3));
	this.set_string("shop description", "Buy");
	this.set_u8("shop icon", 25);

	// CLASS
	this.set_Vec2f("class offset", Vec2f(-6, 0));

	int team_num = this.getTeamNum();

	// CLASS CHANGE
	if(ClassesConfig::knight) addPlayerClass(this, "Knight", "$knight_class_icon$", "knight", ClassesDescriptions::knight);
	if(ClassesConfig::spearman) addPlayerClass(this, "Spearman", "$spearman_class_icon$", "spearman", ClassesDescriptions::spearman);
	if(ClassesConfig::assassin) addPlayerClass(this, "Assassin", "$assassin_class_icon$", "assassin", ClassesDescriptions::assassin);
	if(ClassesConfig::chopper) addPlayerClass(this, "Chopper", "$chopper_class_icon$", "chopper", ClassesDescriptions::chopper);
	if(ClassesConfig::warhammer) addPlayerClass(this, "War Hammer", "$warhammer_class_icon$", "warhammer", ClassesDescriptions::warhammer);
	if(ClassesConfig::duelist) addPlayerClass(this, "Duelist", "$duelist_class_icon$", "duelist", ClassesDescriptions::duelist);
	this.Tag("multi classes");
	
	if(ClassesConfig::knight)
	{
		ShopItem@ s = addShopItem(this, "Bomb", "$bomb$", "mat_bombs", Descriptions::bomb, true);
		AddRequirement(s.requirements, "coin", "", "Coins", CTFCosts::bomb);
	}
	if(ClassesConfig::knight)
	{
		ShopItem@ s = addShopItem(this, "Water Bomb", "$waterbomb$", "mat_waterbombs", Descriptions::waterbomb, true);
		AddRequirement(s.requirements, "coin", "", "Coins", CTFCosts::waterbomb);
	}
	{
		ShopItem@ s = addShopItem(this, "Mine", getTeamIcon("mine", "Mine.png", team_num, Vec2f(16, 16), 1), "mine", Descriptions::mine, false);
		AddRequirement(s.requirements, "coin", "", "Coins", CTFCosts::mine);
	}
	if(ClassesConfig::knight)
	{
		ShopItem@ s = addShopItem(this, "Keg", getTeamIcon("keg", "Keg.png", team_num, Vec2f(16, 16), 0), "keg", Descriptions::keg, false);
		AddRequirement(s.requirements, "coin", "", "Coins", CTFCosts::keg);
	}
	//new items
	if(ClassesConfig::spearman)
	{
		{
			ShopItem@ s = addShopItem(this, "Spears", "$mat_spears$", "mat_spears", "Spare Spears for Spearman. Throw them to enemies.", true);
			AddRequirement(s.requirements, "coin", "", "Coins", LWB_CTFCosts::spears);
		}
		{
			ShopItem@ s = addShopItem(this, "Fire Spear", "$mat_firespears$", "mat_firespears", "Fire Spear for Spearman. Make spear attacking or thrown spear ignitable once.", true);
			AddRequirement(s.requirements, "coin", "", "Coins", LWB_CTFCosts::firespears);
		}
	}
	if(ClassesConfig::assassin)
	{
		ShopItem@ s = addShopItem(this, "Smoke Ball", "$mat_smokeball$", "mat_smokeball", "Smoke Ball for Assassin. Can stun nearly enemies.", true);
		AddRequirement(s.requirements, "coin", "", "Coins", LWB_CTFCosts::smokeball);
	}
}

void GetButtonsFor(CBlob@ this, CBlob@ caller)
{
	AddIconToken("$knight_class_icon$", "GUI/MenuItems.png", Vec2f(32, 32), 12, caller.getTeamNum());
	AddIconToken("$spearman_class_icon$", "GUI/LWBClassIcons.png", Vec2f(32, 32), 2, caller.getTeamNum());
	AddIconToken("$assassin_class_icon$", "GUI/LWBClassIcons.png", Vec2f(32, 32), 3, caller.getTeamNum());
	AddIconToken("$chopper_class_icon$", "GUI/LWBClassIcons.png", Vec2f(32, 32), 9, caller.getTeamNum());
	AddIconToken("$warhammer_class_icon$", "GUI/LWBClassIcons.png", Vec2f(32, 32), 10, caller.getTeamNum());
	AddIconToken("$duelist_class_icon$", "GUI/LWBClassIcons.png", Vec2f(32, 32), 11, caller.getTeamNum());
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