// Workbench
// added new items and water source.

#include "Requirements.as"
#include "ShopCommon.as"
#include "Descriptions.as"
#include "Costs.as"
#include "CheckSpam.as"
#include "LWBCosts.as";

void onInit(CBlob@ this)
{
	this.getSprite().SetZ(-50); //background
	this.getShape().getConsts().mapCollisions = false;

	ShopMadeItem@ onMadeItem = @onShopMadeItem;
	this.set("onShopMadeItem handle", @onMadeItem);

	this.Tag("can settle"); //for DieOnCollapse to prevent 2 second life :)

	InitWorkshop(this);
}


void InitWorkshop(CBlob@ this)
{
	InitCosts(); //read from cfg

	CRules@ rules = getRules();
	string gamemode = rules.gamemode_name;
	/*if (gamemode_override != "")
	{
		gamemode = gamemode_override;

	}*/

	const bool TTH = gamemode == "TTH";

	AddIconToken("$_buildershop_filled_bucket$", "Bucket.png", Vec2f(16, 16), 1);

	this.set_Vec2f("shop offset", Vec2f_zero);
	this.set_Vec2f("shop menu size", Vec2f(5, 5));

	{
		ShopItem@ s = addShopItem(this, "Lantern", "$lantern$", "lantern", Descriptions::lantern, false);
		AddRequirement(s.requirements, "blob", "mat_wood", "Wood", WARCosts::lantern_wood);
	}
	{
		ShopItem@ s = addShopItem(this, "Bucket", "$_buildershop_filled_bucket$", "filled_bucket", Descriptions::filled_bucket, false);
		AddRequirement(s.requirements, "blob", "mat_wood", "Wood", WARCosts::bucket_wood);
	}
	{
		ShopItem@ s = addShopItem(this, "Sponge", "$sponge$", "sponge", Descriptions::sponge, false);
		AddRequirement(s.requirements, "blob", "mat_wood", "Wood", WARCosts::sponge_wood);
	}
	{
		ShopItem@ s = addShopItem(this, "Trampoline", "$trampoline$", "trampoline", Descriptions::trampoline, false);
		AddRequirement(s.requirements, "blob", "mat_wood", "Wood", WARCosts::trampoline_wood);
	}
	{
		ShopItem@ s = addShopItem(this, "Crate", "$crate$", "crate", Descriptions::crate, false);
		AddRequirement(s.requirements, "blob", "mat_wood", "Wood", WARCosts::crate_wood);
	}
	{
		ShopItem@ s = addShopItem(this, "Drill", "$drill$", "drill", Descriptions::drill + "\n\nRock Thrower, War Crafter and Demolitionist can use this too.", false);
		AddRequirement(s.requirements, "blob", "mat_stone", "Stone", WARCosts::drill_stone);
		if (TTH) AddRequirement(s.requirements, "tech", "drill", "Drill Technology");
	}
	{
		ShopItem@ s = addShopItem(this, "Saw", "$saw$", "saw", Descriptions::saw, false);
		AddRequirement(s.requirements, "blob", "mat_wood", "Wood", WARCosts::saw_wood);
		if (!TTH) AddRequirement(s.requirements, "blob", "mat_stone", "Stone", CTFCosts::saw_stone);
		if (TTH) AddRequirement(s.requirements, "tech", "saw", "Saw Technology");
	}
	{
		ShopItem@ s = addShopItem(this, "Dinghy", "$dinghy$", "dinghy", Descriptions::dinghy, false);
		AddRequirement(s.requirements, "blob", "mat_wood", "Wood", WARCosts::dinghy_wood);
		if (TTH) AddRequirement(s.requirements, "tech", "dinghy", "Dinghy Technology");
	}
	{
		ShopItem@ s = addShopItem(this, "Boulder", "$boulder$", "boulder", Descriptions::boulder, false);
		AddRequirement(s.requirements, "blob", "mat_stone", "Stone", WARCosts::boulder_stone);
	}
	{
		ShopItem@ s = addShopItem(this, "Mounted Bow", "$mounted_bow$", "mounted_bow", Descriptions::mounted_bow, false, true);
		s.crate_icon = 6;
		AddRequirement(s.requirements, "blob", "mat_wood", "Wood", LWB_WARCosts::mountedbow_wood);
		if (TTH) AddRequirement(s.requirements, "tech", "mounted_bow", "Camping Technology");
	}
	if (TTH)
	{
		{
			ShopItem@ s = addShopItem(this, "Mounted Gun", "$mounted_gun$", "mounted_gun", "Gun edition of mounted bow. Has decent accuracy and fire rate.", false, true);
			s.crate_icon = 11;
			AddRequirement(s.requirements, "blob", "mat_wood", "Wood", LWB_WARCosts::mountedgun_wood);
			AddRequirement(s.requirements, "blob", "mat_stone", "Stone", LWB_WARCosts::mountedgun_stone);
			AddRequirement(s.requirements, "tech", "mounted_bow", "Camping Technology");
		}

		{
			ShopItem@ s = addShopItem(this, "Light Ballista", "$lightballista$", "lightballista", "Can't shoot bomb ammo, but cheap. Useful to attack enemy and make arrow ladders.", false, true);
			s.crate_icon = 23;
			s.customButton = true;
			s.buttonwidth = 2;
			s.buttonheight = 1;
			AddRequirement(s.requirements, "blob", "mat_wood", "Wood", LWB_WARCosts::lightballista_wood);
			AddRequirement(s.requirements, "tech", "ballista", "Ballista Technology");
		}
	}
}

// fill bucket on collision
void onCollision(CBlob@ this, CBlob@ blob, bool solid)
{
	if (blob !is null)
	{
		if (blob.getName() == "bucket")
		{
			u8 filled = this.get_u8("filled");
			if (filled < 2)
			{
				blob.set_u8("filled", 2);
				blob.set_u8("water_delay", 30);
				Animation@ animation = blob.getSprite().getAnimation("default");
				if (animation !is null)
				{
					u8 index = 1;
					animation.SetFrameIndex(index);
					blob.inventoryIconFrame = index;
				}
			}
		}
		else
		{
			CBlob@ b = blob.getCarriedBlob();
			if (b !is null)
			{
				if (b.getName() == "bucket")
				{
					u8 filled = b.get_u8("filled");
					if (filled < 2)
					{
						b.set_u8("filled", 2);
						b.set_u8("water_delay", 30);
						Animation@ animation = b.getSprite().getAnimation("default");
						if (animation !is null)
						{
							u8 index = 1;
							animation.SetFrameIndex(index);
							b.inventoryIconFrame = index;
						}
					}
				}
			}
		}
	}
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

	CBlob@ caller = getBlobByNetworkID(caller_id);
	if (caller is null) return;

	if (name == "filled_bucket")
	{
		CBlob@ b = server_CreateBlobNoInit("bucket");
		b.setPosition(caller.getPosition());
		b.server_setTeamNum(caller.getTeamNum());
		b.Tag("_start_filled");
		b.Init();
		caller.server_Pickup(b);
	}
}

void onCommand(CBlob@ this, u8 cmd, CBitStream @params)
{
	if (cmd == this.getCommandID("shop made item client") && isClient())
	{
		this.getSprite().PlaySound("/ConstructShort");
	}
}

//sprite - planks layer

void onInit(CSprite@ this)
{
	this.SetZ(50); //foreground

	CBlob@ blob = this.getBlob();
	CSpriteLayer@ planks = this.addSpriteLayer("planks", this.getFilename() , 16, 16, blob.getTeamNum(), blob.getSkinNum());

	if (planks !is null)
	{
		Animation@ anim = planks.addAnimation("default", 0, false);
		anim.AddFrame(6);
		planks.SetOffset(Vec2f(3.0f, -7.0f));
		planks.SetRelativeZ(-100);
	}
}
