// TDM Ruins logic
// added new classes.
#include "ClassSelectMenu.as"
#include "StandardRespawnCommand.as"
#include "StandardControlsCommon.as"
#include "GenericButtonCommon.as"
#include "ClassesConfig.as"

void onInit(CBlob@ this)
{
	CRules@ rules = getRules();
	string gamemode = rules.gamemode_name;

	this.CreateRespawnPoint("ruins", Vec2f(0.0f, 16.0f));
	AddIconToken("$change_class$", "/GUI/InteractionIcons.png", Vec2f(32, 32), 12, 2);
	//TDM classes
	if(ClassesConfig::rockthrower) addPlayerClass(this, "Rock Thrower", "$rockthrower_class_icon$", "rockthrower", ClassesDescriptions::rockthrower);
	if(ClassesConfig::medic) addPlayerClass(this, "Medic", "$medic_class_icon$", "medic", ClassesDescriptions::medic);
	if(ClassesConfig::warcrafter && gamemode == "DTS") addPlayerClass(this, "War Crafter", "$warcrafter_class_icon$", "warcrafter", ClassesDescriptions::warcrafter);
	if(ClassesConfig::butcher) addPlayerClass(this, "Butcher", "$butcher_class_icon$", "butcher", ClassesDescriptions::butcher);
	if(ClassesConfig::knight) addPlayerClass(this, "Knight", "$knight_class_icon$", "knight", ClassesDescriptions::knight);
	if(ClassesConfig::spearman) addPlayerClass(this, "Spearman", "$spearman_class_icon$", "spearman", ClassesDescriptions::spearman);
	if(ClassesConfig::assassin) addPlayerClass(this, "Assassin", "$assassin_class_icon$", "assassin", ClassesDescriptions::assassin);
	if(ClassesConfig::warhammer) addPlayerClass(this, "War Hammer", "$warhammer_class_icon$", "warhammer", ClassesDescriptions::warhammer);
	if(ClassesConfig::duelist) addPlayerClass(this, "Duelist", "$duelist_class_icon$", "duelist", ClassesDescriptions::duelist);
	if(ClassesConfig::archer) addPlayerClass(this, "Archer", "$archer_class_icon$", "archer", ClassesDescriptions::archer);
	if(ClassesConfig::crossbowman) addPlayerClass(this, "Crossbowman", "$crossbowman_class_icon$", "crossbowman", ClassesDescriptions::crossbowman);
	if(ClassesConfig::musketman) addPlayerClass(this, "Musketman", "$musketman_class_icon$", "musketman", ClassesDescriptions::musketman);
	if(ClassesConfig::weaponthrower) addPlayerClass(this, "Weapon Thrower", "$weaponthrower_class_icon$", "weaponthrower", ClassesDescriptions::weaponthrower);
	if(ClassesConfig::firelancer) addPlayerClass(this, "Fire Lancer", "$firelancer_class_icon$", "firelancer", ClassesDescriptions::firelancer);
	if(ClassesConfig::gunner) addPlayerClass(this, "Gunner", "$gunner_class_icon$", "gunner", ClassesDescriptions::gunner);

	this.getShape().SetStatic(true);
	this.getShape().getConsts().mapCollisions = false;
	this.addCommandID("change class");
	this.Tag("all_classes_loaded");

	this.Tag("change class drop inventory");

	this.getSprite().SetZ(-50.0f);   // push to background

	// minimap
	this.SetMinimapOutsideBehaviour(CBlob::minimap_snap);
	this.SetMinimapVars("GUI/Minimap/MinimapIcons.png", 29, Vec2f(8, 8));
	this.SetMinimapRenderAlways(true);
}

void onTick(CBlob@ this)
{
	if (enable_quickswap)
	{
		//quick switch class
		CBlob@ blob = getLocalPlayerBlob();
		if (blob !is null && blob.isMyPlayer())
		{
			if (
				isInRadius(this, blob) && //blob close enough to ruins
				blob.isKeyJustReleased(key_use) && //just released e
				isTap(blob, 7) && //tapped e
				blob.getTickSinceCreated() > 1 //prevents infinite loop of swapping class
			) {
				CycleClass(this, blob);
			}
		}
	}
}

void onCommand(CBlob@ this, u8 cmd, CBitStream @params)
{
	onRespawnCommand(this, cmd, params);
}

void GetButtonsFor(CBlob@ this, CBlob@ caller)
{
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
	AddIconToken("$warhammer_class_icon$", "GUI/LWBClassIcons.png", Vec2f(32, 32), 10, caller.getTeamNum());
	AddIconToken("$duelist_class_icon$", "GUI/LWBClassIcons.png", Vec2f(32, 32), 11, caller.getTeamNum());
	AddIconToken("$weaponthrower_class_icon$", "GUI/LWBClassIcons.png", Vec2f(32, 32), 12, caller.getTeamNum());
	AddIconToken("$firelancer_class_icon$", "GUI/LWBClassIcons.png", Vec2f(32, 32), 13, caller.getTeamNum());
	AddIconToken("$gunner_class_icon$", "GUI/LWBClassIcons.png", Vec2f(32, 32), 14, caller.getTeamNum());
	if (!canSeeButtons(this, caller)) return;

	if (canChangeClass(this, caller))
	{
		if (isInRadius(this, caller))
		{
			BuildRespawnMenuFor(this, caller);
		}
		else
		{
			CBitStream params;
			caller.CreateGenericButton("$change_class$", Vec2f(0, 0), this, buildSpawnMenu, getTranslatedString("Change class"));
		}
	}

	// warning: if we don't have this button just spawn menu here we run into that infinite menus game freeze bug
}

bool isInRadius(CBlob@ this, CBlob @caller)
{
	return (this.getPosition() - caller.getPosition()).Length() < this.getRadius();
}
