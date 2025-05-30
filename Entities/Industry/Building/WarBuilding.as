﻿// Genreic building
// add barracks, kitchen and nursery.

#include "Requirements.as"
#include "ShopCommon.as"
#include "Descriptions.as"
#include "Costs.as"
#include "CheckSpam.as"
#include "GenericButtonCommon.as"
#include "TeamIconToken.as"

//are builders the only ones that can finish construction?
const bool builder_only = false;

void onInit(CBlob@ this)
{
	AddIconToken("$stonequarry$", "../Mods/Entities/Industry/CTFShops/Quarry/Quarry.png", Vec2f(40, 24), 4);
	this.set_TileType("background tile", CMap::tile_wood_back);
	//this.getSprite().getConsts().accurateLighting = true;

	ShopMadeItem@ onMadeItem = @onShopMadeItem;
	this.set("onShopMadeItem handle", @onMadeItem);

	this.getSprite().SetZ(-50); //background
	this.getShape().getConsts().mapCollisions = false;

	this.Tag("has window");

	//INIT COSTS
	InitCosts();

	// SHOP
	this.set_Vec2f("shop offset", Vec2f(0, 0));
	this.set_Vec2f("shop menu size", Vec2f(2, 2));
	this.set_string("shop description", "Construct");
	this.set_u8("shop icon", 12);
	this.Tag(SHOP_AUTOCLOSE);
	this.Tag("builder always hit");

	int team_num = this.getTeamNum();

	{
		ShopItem@ s = addShopItem(this, "Factory", "$factory$", "factory", Descriptions::factory);
		//AddRequirement(s.requirements, "blob", "mat_wood", "Wood", 50);
	}
	//{
	//	ShopItem@ s = addShopItem(this, "Dorm", "$dorm$", "fixeddorm", Descriptions::dorm);
	//	AddRequirement(s.requirements, "blob", "mat_stone", "Stone", 50);
	//	AddRequirement(s.requirements, "blob", "mat_wood", "Wood", 50);
	//}
	/*{
		ShopItem@ s = addShopItem(this, "Nursery", "$nursery$", "nursery", Descriptions::nursery);
		AddRequirement(s.requirements, "blob", "mat_wood", "Wood", 300);
	}
	{
		ShopItem@ s = addShopItem(this, "Barracks", "$barracks$", "barracks", Descriptions::barracks);
		AddRequirement(s.requirements, "blob", "mat_stone", "Stone", 50);
		AddRequirement(s.requirements, "blob", "mat_wood", "Wood", 50);
	}
	{
		ShopItem@ s = addShopItem(this, "Research", "$research$", "research", Descriptions::research);
		AddRequirement(s.requirements, "blob", "mat_gold", "Gold", 1000);
		AddRequirement(s.requirements, "blob", "mat_stone", "Stone", 250);
		AddRequirement(s.requirements, "blob", "mat_wood", "Wood", 100);
	}
	{
		ShopItem@ s = addShopItem(this, "Kitchen", "$kitchen$", "kitchen", Descriptions::kitchen);
		AddRequirement(s.requirements, "blob", "mat_stone", "Stone", 100);
		AddRequirement(s.requirements, "blob", "mat_wood", "Wood", 100);
	}*/
	{
		ShopItem@ s = addShopItem(this, "Stone Quarry", "$stonequarry$", "quarry", Descriptions::quarry);
		AddRequirement(s.requirements, "blob", "mat_stone", "Stone", CTFCosts::quarry_stone);
		AddRequirement(s.requirements, "blob", "mat_gold", "Gold", CTFCosts::quarry_gold);
		AddRequirement(s.requirements, "no more", "quarry", "Stone Quarry", CTFCosts::quarry_count);
	}
}

void GetButtonsFor(CBlob@ this, CBlob@ caller)
{
	if (!canSeeButtons(this, caller)) return;

	if (this.isOverlapping(caller))
		this.set_bool("shop available", !builder_only || caller.getName() == "builder");
	else
		this.set_bool("shop available", false);
}

void onShopMadeItem(CBitStream@ params)
{
	if (!isServer()) return;

	u16 this_id, caller_id, item_id;
	string name;

	if (!params.saferead_u16(this_id) || !params.saferead_u16(caller_id) || !params.saferead_u16(item_id) || !params.saferead_string(name))
	{
		return;
	}

	CBlob@ this = getBlobByNetworkID(this_id);
	if (this is null) return;

	CBlob@ caller = getBlobByNetworkID(caller_id);
	if (caller is null) return;

	CBlob@ item = getBlobByNetworkID(item_id);
	if (item is null) return;

	this.Tag("shop disabled"); //no double-builds
	this.Sync("shop disabled", true);

	this.server_Die();

	// open factory upgrade menu immediately
	if (item.getName() == "factory")
	{
		CBitStream factoryParams;
		factoryParams.write_netid(caller.getNetworkID());
		item.SendCommand(item.getCommandID("upgrade factory menu"), factoryParams); // NOT SANITIZED; TTH
	}
}

void onCommand(CBlob@ this, u8 cmd, CBitStream @params)
{
	if (cmd == this.getCommandID("shop made item client") && isClient())
	{
		u16 this_id, caller_id, item_id;
		string name;

		if (!params.saferead_u16(this_id) || !params.saferead_u16(caller_id) || !params.saferead_u16(item_id) || !params.saferead_string(name))
		{
			return;
		}

		CBlob@ caller = getBlobByNetworkID(caller_id);
		CBlob@ item = getBlobByNetworkID(item_id);

		if (item !is null && caller !is null)
		{
			this.getSprite().PlaySound("/Construct.ogg");
			this.getSprite().getVars().gibbed = true;
			caller.ClearMenus();
		}
	}
}
