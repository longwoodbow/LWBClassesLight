// BuilderShop.as

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
	InitCosts(); //read from cfg

	AddIconToken("$_buildershop_filled_bucket$", "Bucket.png", Vec2f(16, 16), 1);

	this.set_TileType("background tile", CMap::tile_wood_back);

	this.getSprite().SetZ(-50); //background
	this.getShape().getConsts().mapCollisions = false;

	ShopMadeItem@ onMadeItem = @onShopMadeItem;
	this.set("onShopMadeItem handle", @onMadeItem);

	this.Tag("has window");

	// SHOP
	this.set_Vec2f("shop offset", Vec2f_zero);
	this.set_Vec2f("shop menu size", Vec2f(6, 4));
	this.set_string("shop description", "Buy");
	this.set_u8("shop icon", 25);

	// CLASS
	this.set_Vec2f("class offset", Vec2f(-6, 0));

	int team_num = this.getTeamNum();

	// CLASS CHANGE
	if(ClassesConfig::builder) addPlayerClass(this, "Builder", "$builder_class_icon$", "builder", ClassesDescriptions::builder);
	if(ClassesConfig::rockthrower) addPlayerClass(this, "Rock Thrower", "$rockthrower_class_icon$", "rockthrower", ClassesDescriptions::rockthrower);
	if(ClassesConfig::medic) addPlayerClass(this, "Medic", "$medic_class_icon$", "medic", ClassesDescriptions::medic);
	if(ClassesConfig::warcrafter) addPlayerClass(this, "War Crafter", "$warcrafter_class_icon$", "warcrafter", ClassesDescriptions::warcrafter);
	if(ClassesConfig::butcher) addPlayerClass(this, "Butcher", "$butcher_class_icon$", "butcher", ClassesDescriptions::butcher);
	if(ClassesConfig::demolitionist) addPlayerClass(this, "Demolitionist", "$demolitionist_class_icon$", "demolitionist", ClassesDescriptions::demolitionist);
	this.Tag("multi classes");
	
	if(ClassesConfig::builder || ClassesConfig::rockthrower || ClassesConfig::warcrafter || ClassesConfig::demolitionist)
	{
		ShopItem@ s = addShopItem(this, "Drill", getTeamIcon("drill", "Drill.png", team_num, Vec2f(32, 16), 0), "drill", Descriptions::drill + "\n\nRock Thrower, War Crafter and Demolitionist can use this too.", false);
		AddRequirement(s.requirements, "blob", "mat_stone", "Stone", CTFCosts::drill_stone);
		AddRequirement(s.requirements, "coin", "", "Coins", CTFCosts::drill);
	}
	{
		ShopItem@ s = addShopItem(this, "Sponge", "$sponge$", "sponge", Descriptions::sponge, false);
		AddRequirement(s.requirements, "coin", "", "Coins", CTFCosts::sponge);
	}
	{
		ShopItem@ s = addShopItem(this, "Bucket", "$_buildershop_filled_bucket$", "filled_bucket", Descriptions::filled_bucket, false);
		AddRequirement(s.requirements, "blob", "mat_wood", "Wood", CTFCosts::bucket_wood);
	}
	{
		ShopItem@ s = addShopItem(this, "Boulder", "$boulder$", "boulder", Descriptions::boulder, false);
		s.customButton = true;
		s.buttonwidth = 2;
		s.buttonheight = 1;
		AddRequirement(s.requirements, "blob", "mat_stone", "Stone", CTFCosts::boulder_stone);
	}
	{
		ShopItem@ s = addShopItem(this, "Wood", "$mat_wood$", "mat_wood", Descriptions::wood, true);//"It's used for building bridges, shops, and more."
		AddRequirement(s.requirements, "coin", "", "Coins", LWB_CTFCosts::woods);
	}
	{
		ShopItem@ s = addShopItem(this, "Stone", "$mat_stone$", "mat_stone", Descriptions::stone, true);//"It's used for building defence, trap, and more."
		AddRequirement(s.requirements, "coin", "", "Coins", LWB_CTFCosts::stones);
	}
	{
		ShopItem@ s = addShopItem(this, "Gold", "$mat_gold$", "mat_gold", "Raw gold material.", true);//"It's used for building advance shops."
		AddRequirement(s.requirements, "coin", "", "Coins", LWB_CTFCosts::gold);
	}
	{
		ShopItem@ s = addShopItem(this, "Lantern", "$lantern$", "lantern", Descriptions::lantern, false);
		AddRequirement(s.requirements, "blob", "mat_wood", "Wood", CTFCosts::lantern_wood);
	}
	{
		ShopItem@ s = addShopItem(this, "Trampoline", getTeamIcon("trampoline", "Trampoline.png", team_num, Vec2f(32, 16), 3), "trampoline", Descriptions::trampoline, false);
		AddRequirement(s.requirements, "blob", "mat_wood", "Wood", CTFCosts::trampoline_wood);
	}
	{
		ShopItem@ s = addShopItem(this, "Saw", getTeamIcon("saw", "VehicleIcons.png", team_num, Vec2f(32, 32), 3), "saw", Descriptions::saw, false);
		s.customButton = true;
		s.buttonwidth = 2;
		s.buttonheight = 1;
		AddRequirement(s.requirements, "blob", "mat_wood", "Wood", CTFCosts::saw_wood);
		AddRequirement(s.requirements, "blob", "mat_stone", "Stone", CTFCosts::saw_stone);
	}
	{
		ShopItem@ s = addShopItem(this, "Crate (wood)", getTeamIcon("crate", "Crate.png", team_num, Vec2f(32, 16), 5), "crate", Descriptions::crate, false);
		AddRequirement(s.requirements, "blob", "mat_wood", "Wood", CTFCosts::crate_wood);
	}
	{
		ShopItem@ s = addShopItem(this, "Crate (coins)", getTeamIcon("crate", "Crate.png", team_num, Vec2f(32, 16), 5), "crate", Descriptions::crate, false);
		AddRequirement(s.requirements, "coin", "", "Coins", CTFCosts::crate);
	}
	if(ClassesConfig::medic)
	{
		{
			ShopItem@ s = addShopItem(this, "Med Kit", "$mat_medkits$", "mat_medkits", "Med kit for Medic. Can be used 10 times.", true);
			AddRequirement(s.requirements, "coin", "", "Coins", LWB_CTFCosts::medkits);
		}
		{
			ShopItem@ s = addShopItem(this, "Water in a Jar", "$mat_waterjar$", "mat_waterjar", "Water for Medic Spray.", true);
			AddRequirement(s.requirements, "coin", "", "Coins", LWB_CTFCosts::waterjar);
		}
		{
			ShopItem@ s = addShopItem(this, "Acid in a Jar", "$mat_acidjar$", "mat_acidjar", "Acid for Medic Spray.\nCan damage blocks and enemies.", true);
			AddRequirement(s.requirements, "coin", "", "Coins", LWB_CTFCosts::acidjar);
		}
	}
	if(ClassesConfig::butcher)
	{
		ShopItem@ s = addShopItem(this, "Oil Bottles", "$mat_cookingoils$", "mat_cookingoils", "Cooking Oil Bottle for Butcher.\nCan ignite somethings and cook steak and fishy to save.", true);
		AddRequirement(s.requirements, "coin", "", "Coins", LWB_CTFCosts::oilbottles);
	}
	if(ClassesConfig::demolitionist)
	{
		ShopItem@ s = addShopItem(this, "Bomb Box", "$mat_bombboxes$", "mat_bombboxes", "Bomb Box for Demolitionist.", true);
		AddRequirement(s.requirements, "coin", "", "Coins", LWB_CTFCosts::bombboxes);
	}
}

void GetButtonsFor(CBlob@ this, CBlob@ caller)
{
	AddIconToken("$builder_class_icon$", "GUI/MenuItems.png", Vec2f(32, 32), 8, caller.getTeamNum());
	AddIconToken("$rockthrower_class_icon$", "GUI/LWBClassIcons.png", Vec2f(32, 32), 0, caller.getTeamNum());
	AddIconToken("$medic_class_icon$", "GUI/LWBClassIcons.png", Vec2f(32, 32), 1, caller.getTeamNum());
	AddIconToken("$warcrafter_class_icon$", "GUI/LWBClassIcons.png", Vec2f(32, 32), 6, caller.getTeamNum());
	AddIconToken("$butcher_class_icon$", "GUI/LWBClassIcons.png", Vec2f(32, 32), 7, caller.getTeamNum());
	AddIconToken("$demolitionist_class_icon$", "GUI/LWBClassIcons.png", Vec2f(32, 32), 8, caller.getTeamNum());
	if (!canSeeButtons(this, caller)) return;
	PlayerClass[]@ classes;
	if (this.get("playerclasses", @classes) && classes.length() > 0)
	{
		this.set_Vec2f("shop offset", Vec2f_zero);
	}
	else
	{
		this.set_Vec2f("shop offset", Vec2f(6, 0));
	}
	this.set_bool("shop available", this.isOverlapping(caller));
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
		this.getSprite().PlaySound("/ChaChing.ogg");
	}
}
