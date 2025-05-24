// REQUIRES:
//
//      onRespawnCommand() to be called in onCommand()
//
//  implementation of:
//
//      bool canChangeClass( CBlob@ this, CBlob @caller )
//
// Tag: "change class sack inventory" - if you want players to have previous items stored in sack on class change
// Tag: "change class store inventory" - if you want players to store previous items in this respawn blob

#include "ClassSelectMenu.as"
#include "KnockedCommon.as"
#include "ClassesConfig.as"

bool canChangeClass(CBlob@ this, CBlob@ blob)
{
    if (blob.hasTag("switch class")) return false;

	Vec2f tl, br, _tl, _br;
	this.getShape().getBoundingRect(tl, br);
	blob.getShape().getBoundingRect(_tl, _br);
	return br.x > _tl.x
	       && br.y > _tl.y
	       && _br.x > tl.x
	       && _br.y > tl.y;

}

namespace ClassesDescriptions
{
	const string
	builder = "Build ALL the towers.\nStill important class for keeping battlefront by building.",
	rockthrower = "Basic Tactics.\nThis class can make rain of rocks for obstruct enemies and build ladder for help allies. Also can dig using classic hammer.\n\n[LMB] to throw/build(change action at inventory)\n[RMB] to use hammer\n[SPACE] to make boulder(throw state) or rotate(build state)",
	medic = "Medical and Chemical.\nThis class can heal allies and spray liquid to enemies. Also can use grapple.\n\n[LMB] to heal ally\n[RMB] to use grapple\n[SPACE] to use spray, can buy jars at builder shop",
	warcrafter = "Build 'n' Kill.\nThis class can build some goods and makeshift barricades. Especially can spam fire using torch.\n\nControl is as same as builder, tap [F] to switch weapon mode\nIn weapon mode, [LMB] to throw makeshift axe, [SPACE] near fireplace to make torch",
	butcher = "Human Resources.\nThis class can make steaks and poisonous meat from corpses. Also can throw poisonous meat for poison spam.\n\n[LMB] to use knife to butch corpses\n[RMB] to throw meat\n[SPACE] to use oil to ignite and cook steak or fishy, can buy at builder shop",
	demolitionist = "Demolish be Smart.\nThis class can use bomb box, pickaxe, grapple and barricades.\n\n[LMB] to build/use pickaxe(change action at inventory)\n[RMB] to use grapple",
	knight = "Hack and Slash.\nStill important class for making and pushing battlefront.",
	spearman = "Omnipotent Weapon.\nThis class can do strong melee attack and throw to mid range.\n\n[LMB] to do melee attack like knight\n[RMB] to jab/throw/double throw\n[SHIFT]+[SPACE] to pickup thrown spear",
	assassin = "Nothing can Escape.\nThis class can stab and stun enemy and use grapple. Also can use smoke ball to stun enemies.\n\n[LMB] to stab\n[RMB] to use grapple\n[SPACE] to use smoke ball, can buy at knight shop",
	chopper = "Familiar with Wood.\nThis class can use axe for strong melee attack and build wooden buildings.\n\n[LMB] to build\n[RMB] to use axe/mattock(change at inventory)\n[SPACE] to rotate blocks",
	warhammer = "Break Everything.\nThis class can use slow but powerful weapons.\n\n[LMB] to jab/slash hammer\n[RMB] to throw flail, can glide air while spinning the flail",
	duelist = "Dodge and Pick.\nThis class can do quick melee attack with rapier and use grapple.\n\n[LMB] to jab/slash rapier\n[RMB] to use grapple",
	archer = "The Ranged Advantage.\nNow archer can use poison arrows, poison causes DoT damage and slow. Also can use grapple, water and bomb arrows that crossbowman can't use.",
	crossbowman = "Heavy Mechanical Weapon.\nThis class can do long range triple shoot like old archer. Also can use bayonet to attack enemies and make arrows from wooden things.\n\n[LMB] to shoot\n[RMB] to use bayonet, also can pickup arrow",
	musketman = "New Era of War.\nThis class can use musket to snipe enemy and build barricades.\n\n[LMB] to shoot/build(change at inventory), can buy barricade frames at archer shop\n[RMB] to use shovel",
	weaponthrower = "Skill of Human.\nThis class can throw boomerang or chakram, and use shield.\n\n[LMB] to do nothing/throw/double throw\n[RMB] to use shield\n[SHIFT]+[SPACE] to pickup thrown chakram",
	firelancer = "Chinese Boomstick.\nThis class can shoot fragments like shotgun. Also can use stick as melee weapon.\n\n[LMB] to shoot\n[RMB] to hit enemies using stick",
	gunner = "Smaller is more useful.\nThis class can use guns that can load more quickly than musket, but have lower accuracy. Also can use grapple.\n\n[LMB] to shoot, you can do sniping/double shooting on full charge(change at inventory)\n[RMB] to use grapple";
}

// default classes
void InitClasses(CBlob@ this)
{
	AddIconToken("$change_class$", "/GUI/InteractionIcons.png", Vec2f(32, 32), 12, 2);
	if(ClassesConfig::builder) addPlayerClass(this, "Builder", "$builder_class_icon$", "builder", ClassesDescriptions::builder);
	if(ClassesConfig::rockthrower) addPlayerClass(this, "Rock Thrower", "$rockthrower_class_icon$", "rockthrower", ClassesDescriptions::rockthrower);
	if(ClassesConfig::medic) addPlayerClass(this, "Medic", "$medic_class_icon$", "medic", ClassesDescriptions::medic);
	if(ClassesConfig::warcrafter) addPlayerClass(this, "War Crafter", "$warcrafter_class_icon$", "warcrafter", ClassesDescriptions::warcrafter);
	if(ClassesConfig::butcher) addPlayerClass(this, "Butcher", "$butcher_class_icon$", "butcher", ClassesDescriptions::butcher);
	if(ClassesConfig::demolitionist) addPlayerClass(this, "Demolitionist", "$demolitionist_class_icon$", "demolitionist", ClassesDescriptions::demolitionist);
	if(ClassesConfig::knight) addPlayerClass(this, "Knight", "$knight_class_icon$", "knight", ClassesDescriptions::knight);
	if(ClassesConfig::spearman) addPlayerClass(this, "Spearman", "$spearman_class_icon$", "spearman", ClassesDescriptions::spearman);
	if(ClassesConfig::assassin) addPlayerClass(this, "Assassin", "$assassin_class_icon$", "assassin", ClassesDescriptions::assassin);
	if(ClassesConfig::chopper) addPlayerClass(this, "Chopper", "$chopper_class_icon$", "chopper", ClassesDescriptions::chopper);
	if(ClassesConfig::warhammer) addPlayerClass(this, "War Hammer", "$warhammer_class_icon$", "warhammer", ClassesDescriptions::warhammer);
	if(ClassesConfig::duelist) addPlayerClass(this, "Duelist", "$duelist_class_icon$", "duelist", ClassesDescriptions::duelist);
	if(ClassesConfig::archer) addPlayerClass(this, "Archer", "$archer_class_icon$", "archer", ClassesDescriptions::archer);
	if(ClassesConfig::crossbowman) addPlayerClass(this, "Crossbowman", "$crossbowman_class_icon$", "crossbowman", ClassesDescriptions::crossbowman);
	if(ClassesConfig::musketman) addPlayerClass(this, "Musketman", "$musketman_class_icon$", "musketman", ClassesDescriptions::musketman);
	if(ClassesConfig::weaponthrower) addPlayerClass(this, "Weapon Thrower", "$weaponthrower_class_icon$", "weaponthrower", ClassesDescriptions::weaponthrower);
	if(ClassesConfig::firelancer) addPlayerClass(this, "Fire Lancer", "$firelancer_class_icon$", "firelancer", ClassesDescriptions::firelancer);
	if(ClassesConfig::gunner) addPlayerClass(this, "Gunner", "$gunner_class_icon$", "gunner", ClassesDescriptions::gunner);
	this.Tag("all_classes_loaded");
	this.addCommandID("change class");
}

void BuildRespawnMenuFor(CBlob@ this, CBlob @caller)
{
	PlayerClass[]@ classes;
	this.get("playerclasses", @classes);
	// TODO: make melee, ranged and support classes menu
	if (caller !is null && caller.isMyPlayer() && classes !is null)
	{
		if (this.hasTag("all_classes_loaded"))
		{
			PlayerClass[] supportclasses;
			PlayerClass[] meleeclasses;
			PlayerClass[] rangedclasses;
			for (uint i = 0 ; i < classes.length; i++)
			{
				string name = classes[i].configFilename;
				if (name == "builder" || name == "rockthrower" || name == "medic" || name == "warcrafter" || name == "butcher" || name == "demolitionist")
					supportclasses.push_back(classes[i]);
				else if (name == "knight" || name == "spearman" || name == "assassin" || name == "chopper" || name == "warhammer" || name == "duelist")
					meleeclasses.push_back(classes[i]);
				else if (name == "archer" || name == "crossbowman" || name == "musketman" || name == "weaponthrower" || name == "firelancer" || name == "gunner")
					rangedclasses.push_back(classes[i]);
			}

			if (supportclasses.length >= 1)
			{
				CGridMenu@ menu = CreateGridMenu(caller.getScreenPos() + Vec2f(24.0f, caller.getRadius() * 1.0f - 80.0f), this, Vec2f(supportclasses.length * CLASS_BUTTON_SIZE, CLASS_BUTTON_SIZE), "Support classes");
				if (menu !is null)
				{
					for (uint i = 0 ; i < supportclasses.length; i++)
					{
						PlayerClass @pclass = supportclasses[i];

						CBitStream params;
						params.write_u8(i);

						CGridButton@ button = menu.AddButton(pclass.iconName, getTranslatedString(pclass.name), this.getCommandID("change class"), Vec2f(CLASS_BUTTON_SIZE, CLASS_BUTTON_SIZE), params);
						button.SetHoverText(pclass.description);
					}
				}
			}

			if (meleeclasses.length >= 1)
			{
				CGridMenu@ menu = CreateGridMenu(caller.getScreenPos() + Vec2f(24.0f, caller.getRadius() * 1.0f + 48.0f), this, Vec2f(meleeclasses.length * CLASS_BUTTON_SIZE, CLASS_BUTTON_SIZE), "Melee classes");
				if (menu !is null)
				{
					for (uint i = 0 ; i < meleeclasses.length; i++)
					{
						PlayerClass @pclass = meleeclasses[i];

						CBitStream params;
						params.write_u8(supportclasses.length + i);

						CGridButton@ button = menu.AddButton(pclass.iconName, getTranslatedString(pclass.name), this.getCommandID("change class"), Vec2f(CLASS_BUTTON_SIZE, CLASS_BUTTON_SIZE), params);
						button.SetHoverText(pclass.description);
					}
				}
			}

			if (rangedclasses.length >= 1)
			{
				CGridMenu@ menu = CreateGridMenu(caller.getScreenPos() + Vec2f(24.0f, caller.getRadius() * 1.0f + 176.0f), this, Vec2f(rangedclasses.length * CLASS_BUTTON_SIZE, CLASS_BUTTON_SIZE), "Ranged classes");
				if (menu !is null)
				{
					for (uint i = 0 ; i < rangedclasses.length; i++)
					{
						PlayerClass @pclass = rangedclasses[i];

						CBitStream params;
						params.write_u8(supportclasses.length + meleeclasses.length + i);

						CGridButton@ button = menu.AddButton(pclass.iconName, getTranslatedString(pclass.name), this.getCommandID("change class"), Vec2f(CLASS_BUTTON_SIZE, CLASS_BUTTON_SIZE), params);
						button.SetHoverText(pclass.description);
					}
				}
			}
		}
		else
		{
			CGridMenu@ menu = CreateGridMenu(caller.getScreenPos() + Vec2f(24.0f, caller.getRadius() * 1.0f + 48.0f), this, Vec2f(classes.length * CLASS_BUTTON_SIZE, CLASS_BUTTON_SIZE), getTranslatedString("Swap class"));
			if (menu !is null)
			{
				for (uint i = 0 ; i < classes.length; i++)
				{
					PlayerClass @pclass = classes[i];

					CBitStream params;
					params.write_u8(i);

					CGridButton@ button = menu.AddButton(pclass.iconName, getTranslatedString(pclass.name), this.getCommandID("change class"), Vec2f(CLASS_BUTTON_SIZE, CLASS_BUTTON_SIZE), params);
					button.SetHoverText(pclass.description);
				}
			}
		}
	}
}

void buildSpawnMenu(CBlob@ this, CBlob@ caller)
{
	AddIconToken("$builder_class_icon$", "GUI/MenuItems.png", Vec2f(32, 32), 8, caller.getTeamNum());
	AddIconToken("$knight_class_icon$", "GUI/MenuItems.png", Vec2f(32, 32), 12, caller.getTeamNum());
	AddIconToken("$archer_class_icon$", "GUI/MenuItems.png", Vec2f(32, 32), 16, caller.getTeamNum());
	AddIconToken("$rockthrower_class_icon$", "GUI/LWBClassIcons.png", Vec2f(32, 32), 0, caller.getTeamNum());
	AddIconToken("$medic_class_icon$", "GUI/LWBClassIcons.png", Vec2f(32, 32), 1, caller.getTeamNum());
	AddIconToken("$spearman_class_icon$", "GUI/LWBClassIcons.png", Vec2f(32, 32), 2, caller.getTeamNum());
	AddIconToken("$assassin_class_icon$", "GUI/LWBClassIcons.png", Vec2f(32, 32), 3, caller.getTeamNum());
	AddIconToken("$crossbowman_class_icon$", "GUI/LWBClassIcons.png", Vec2f(32, 32), 4, caller.getTeamNum());
	AddIconToken("$musketman_class_icon$", "GUI/LWBClassIcons.png", Vec2f(32, 32), 5, caller.getTeamNum());
	AddIconToken("$warcrafter_class_icon$", "GUI/LWBClassIcons.png", Vec2f(32, 32), 6, caller.getTeamNum());
	AddIconToken("$butcher_class_icon$", "GUI/LWBClassIcons.png", Vec2f(32, 32), 7, caller.getTeamNum());
	AddIconToken("$demolitionist_class_icon$", "GUI/LWBClassIcons.png", Vec2f(32, 32), 8, caller.getTeamNum());
	AddIconToken("$chopper_class_icon$", "GUI/LWBClassIcons.png", Vec2f(32, 32), 9, caller.getTeamNum());
	AddIconToken("$warhammer_class_icon$", "GUI/LWBClassIcons.png", Vec2f(32, 32), 10, caller.getTeamNum());
	AddIconToken("$duelist_class_icon$", "GUI/LWBClassIcons.png", Vec2f(32, 32), 11, caller.getTeamNum());
	AddIconToken("$weaponthrower_class_icon$", "GUI/LWBClassIcons.png", Vec2f(32, 32), 12, caller.getTeamNum());
	AddIconToken("$firelancer_class_icon$", "GUI/LWBClassIcons.png", Vec2f(32, 32), 13, caller.getTeamNum());
	AddIconToken("$gunner_class_icon$", "GUI/LWBClassIcons.png", Vec2f(32, 32), 14, caller.getTeamNum());
	BuildRespawnMenuFor(this, caller);
}

void onRespawnCommand(CBlob@ this, u8 cmd, CBitStream @params)
{
	if (cmd == this.getCommandID("change class") && isServer())
	{
		CPlayer@ callerp = getNet().getActiveCommandPlayer();
		if (callerp is null) return;

		CBlob@ caller = callerp.getBlob();
		if (caller is null) return;

		if (!canChangeClass(this, caller)) return;

		u8 id;
		if (!params.saferead_u8(id)) return;

		string classconfig = "knight";

		PlayerClass[]@ classes;
		if (this.get("playerclasses", @classes)) // Multiple classes available?
		{
			if (id >= classes.size())
			{
				string player_username = "(couldn't determine)";
				if (this.getPlayer() !is null)
				{
					player_username = this.getPlayer().getUsername();
				}
				warn("Bad class ID " + id + ", ignoring request of player " + player_username);
				return;
			}

			classconfig = classes[id].configFilename;
		}
		else if (this.exists("required class")) // Maybe single class available?
		{
			classconfig = this.get_string("required class");
		}
		else // No classes available?
		{
			return;
		}

		// Caller overlapping?
		if (!caller.isOverlapping(this)) return;

		// Don't spam the server with class change
		if (caller.getTickSinceCreated() < 10) return;

		CBlob @newBlob = server_CreateBlob(classconfig, caller.getTeamNum(), this.getRespawnPosition());

		if (newBlob !is null)
		{
			// copy health and inventory
			// make sack
			CInventory @inv = caller.getInventory();

			if (inv !is null)
			{
				if (this.hasTag("change class drop inventory"))
				{
					while (inv.getItemsCount() > 0)
					{
						CBlob @item = inv.getItem(0);
						caller.server_PutOutInventory(item);
					}
				}
				else if (this.hasTag("change class store inventory"))
				{
					if (this.getInventory() !is null)
					{
						caller.MoveInventoryTo(this);
					}
					else // find a storage
					{
						PutInvInStorage(caller);
					}
				}
				else
				{
					// keep inventory if possible
					caller.MoveInventoryTo(newBlob);
				}
			}

			// set health to be same ratio
			float healthratio = caller.getHealth() / caller.getInitialHealth();
			newBlob.server_SetHealth(newBlob.getInitialHealth() * healthratio);

			//copy air
			if (caller.exists("air_count"))
			{
				newBlob.set_u8("air_count", caller.get_u8("air_count"));
				newBlob.Sync("air_count", true);
			}

			//copy stun
			if (isKnockable(caller))
			{
				setKnocked(newBlob, getKnockedRemaining(caller));
			}

			// plug the soul
			newBlob.server_SetPlayer(caller.getPlayer());
			newBlob.setPosition(caller.getPosition());

			// no extra immunity after class change
			if (caller.exists("spawn immunity time"))
			{
				newBlob.set_u32("spawn immunity time", caller.get_u32("spawn immunity time"));
				newBlob.Sync("spawn immunity time", true);
			}

			caller.Tag("switch class");
			caller.server_SetPlayer(null);
			caller.server_Die();
		}
	}
}

void PutInvInStorage(CBlob@ blob)
{
	CBlob@[] storages;
	if (getBlobsByTag("storage", @storages))
		for (uint step = 0; step < storages.length; ++step)
		{
			CBlob@ storage = storages[step];
			if (storage.getTeamNum() == blob.getTeamNum())
			{
				blob.MoveInventoryTo(storage);
				return;
			}
		}
}

const bool enable_quickswap = false;
void CycleClass(CBlob@ this, CBlob@ blob)
{
	//get available classes
	PlayerClass[]@ classes;
	if (this.get("playerclasses", @classes))
	{
		CBitStream params;
		PlayerClass @newclass;

		u8 new_i = 0;

		//find current class
		for (uint i = 0; i < classes.length; i++)
		{
			PlayerClass @pclass = classes[i];
			if (pclass.name.toLower() == blob.getName())
			{
				//cycle to next class
				new_i = (i + 1) % classes.length;
				break;
			}
		}

		if (classes[new_i] is null)
		{
			//select default class
			new_i = 0;
		}

		//switch to class
		this.SendCommand(this.getCommandID("change class"), params);
	}
}
