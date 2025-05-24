#include "VehicleCommon.as"
#include "KnockedCommon.as";
#include "GenericButtonCommon.as";
#include "Requirements.as"
#include "ShopCommon.as"
#include "CheckSpam.as"
#include "GenericButtonCommon.as"

// Cart anim

void onInit(CSprite@ this)
{
	ReloadSprites(this);
}

void ReloadSprites(CSprite@ sprite)
{
	string filename = sprite.getFilename();

	sprite.SetZ(-25.0f);
	sprite.ReloadSprite(filename);

	// (re)init arm and cage sprites
	sprite.RemoveSpriteLayer("rollcage");
	CSpriteLayer@ rollcage = sprite.addSpriteLayer("rollcage", filename, 48, 32);

	if (rollcage !is null)
	{
		Animation@ anim = rollcage.addAnimation("default", 0, false);
		anim.AddFrame(3);
		rollcage.SetOffset(Vec2f(0, -4.0f));
		rollcage.SetRelativeZ(-0.01f);
	}
}

// Cart logic

void onInit(CBlob@ this)
{
	ShopMadeItem@ onMadeItem = @onShopMadeItem;
	this.set("onShopMadeItem handle", @onMadeItem);

	Vehicle_Setup(this,
	              40.0f, // move speed
	              0.5f,  // turn speed
	              Vec2f(0.0f, 0.0f), // jump out velocity
	              false  // inventory access
	             );
	VehicleInfo@ v;
	if (!this.get("VehicleInfo", @v)) return;

	Vehicle_SetupGroundSound(this, v, "WoodenWheelsRolling",  // movement sound
	                         1.0f, // movement sound volume modifier   0.0f = no manipulation
	                         1.0f // movement sound pitch modifier     0.0f = no manipulation
	                        );
	Vehicle_addWheel(this, v, "WoodenWheels.png", 16, 16, 0, Vec2f(-10.0f, 10.0f));
	Vehicle_addWheel(this, v, "WoodenWheels.png", 16, 16, 0, Vec2f(8.0f, 10.0f));

	this.getShape().SetOffset(Vec2f(0, 6));

	this.Tag("short raid time");// from VehicleConvert, should incrude and use const value?

	this.set_Vec2f("shop offset", Vec2f(0, 0));
	this.set_Vec2f("shop menu size", Vec2f(4, 2));
	this.set_string("shop description", "Upgrade");
	this.set_u8("shop icon", 12);
	this.Tag(SHOP_AUTOCLOSE);

	{
		ShopItem@ s = addShopItem(this, "Ram", "$cart_ram$", "cart_ram", "Install big hammer. It has long melee range and massive damage.");
		s.customButton = true;
		s.buttonwidth = 2;
		s.buttonheight = 2;
		AddRequirement(s.requirements, "blob", "log", "Logs", 3);
	}
	{
		ShopItem@ s = addShopItem(this, "Tower Siege", "$cart_tower$", "cart_tower", "Make it bigger! It can be a ladder and allow you to climb an enemy wall.");
		s.customButton = true;
		s.buttonwidth = 2;
		s.buttonheight = 2;
		AddRequirement(s.requirements, "blob", "mat_wood", "Wood", 1500);
	}
}

void onTick(CBlob@ this)
{
	VehicleInfo@ v;
	if (!this.get("VehicleInfo", @v)) return;

	Vehicle_StandardControls(this, v); //just make sure it's updated
}

void GetButtonsFor(CBlob@ this, CBlob@ caller)
{
	if (!canSeeButtons(this, caller)) return;

	//upgrade button
	if (
		!Vehicle_AddFlipButton(this, caller) &&
		this.getTeamNum() == caller.getTeamNum() &&
	    this.getDistanceTo(caller) < this.getRadius() &&
		!caller.isAttached() 
	)
		this.set_bool("shop available", true);
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
	if (item.getName() == "cart_tower")
	{
		item.setPosition(item.getPosition() + Vec2f(0.0f, -70.0f));
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
			this.getSprite().PlaySound("/ConstructShort.ogg");
			this.getSprite().getVars().gibbed = true;
			caller.ClearMenus();
		}
	}
}

bool doesCollideWithBlob(CBlob@ this, CBlob@ blob)
{
	return Vehicle_doesCollideWithBlob_ground(this, blob);
}

void onCollision(CBlob@ this, CBlob@ blob, bool solid)
{
	if (blob !is null)
	{
		TryToAttachVehicle(this, blob);
	}
}