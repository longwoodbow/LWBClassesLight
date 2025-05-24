// CommonWarcrafterBlocks.as

#include "BuildBlock.as"
#include "Requirements.as"
#include "Costs.as"
#include "TeamIconToken.as"
#include "LWBCosts.as"

const string blocks_property = "blocks";
const string inventory_offset = "inventory offset";

void addCommonWarcrafterBlocks(BuildBlock[][]@ blocks, int team_num = 0, const string&in gamemode_override = "")
{
	InitCosts();

	CRules@ rules = getRules();

	string gamemode = rules.gamemode_name;
	if (gamemode_override != "")
	{
		gamemode = gamemode_override;

	}
	
	const bool TTH = gamemode == "TTH";

	const bool CTF = gamemode == "CTF";
	const bool SCTF = gamemode == "SmallCTF";
	const bool SBX = gamemode == "Sandbox";

	BuildBlock[] page_0;
	blocks.push_back(page_0);
	{
		BuildBlock b(0, "makeshift_barricade", "$makeshift_barricade$", "Makeshift Wooden Barricade\nto block anyone's passing\nCan't be support of spikes");
		AddRequirement(b.reqs, "blob", "mat_wood", "Wood", LWBClassesCosts::wooden_barricade);
		blocks[0].push_back(b);
	}
	{
		BuildBlock b(0, "stone_barricade", "$stone_barricade$", "Makeshift Stone Barricade");
		AddRequirement(b.reqs, "blob", "mat_stone", "Stone", LWBClassesCosts::stone_barricade);
		blocks[0].push_back(b);
	}
	{
		BuildBlock b(0, "bridge", getTeamIcon("bridge", "Bridge.png", team_num), "Trap Bridge\nOnly your team can stand on it");
		AddRequirement(b.reqs, "blob", "mat_wood", "Wood", BuilderCosts::bridge);
		blocks[0].push_back(b);
	}
	{
		BuildBlock b(0, "ladder", "$ladder$", "Ladder\nAnyone can climb it");
		AddRequirement(b.reqs, "blob", "mat_wood", "Wood", BuilderCosts::ladder);
		blocks[0].push_back(b);
	}
	{
		BuildBlock b(0, "wooden_platform", "$wooden_platform$", "Wooden Platform\nOne way platform");
		AddRequirement(b.reqs, "blob", "mat_wood", "Wood", BuilderCosts::wooden_platform);
		blocks[0].push_back(b);
	}
	{
		BuildBlock b(0, "spikes", "$spikes$", "Spikes\nPlace on Stone Block\nfor Retracting Trap");
		AddRequirement(b.reqs, "blob", "mat_stone", "Stone", BuilderCosts::spikes);
		blocks[0].push_back(b);
	}
	{
		BuildBlock b(0, "wooden_spikes", "$wooden_spikes$", "Wooden Spikes\nHalf damage\nNo falling attack");
		AddRequirement(b.reqs, "blob", "mat_wood", "Wood", LWBClassesCosts::wooden_spikes);
		blocks[0].push_back(b);
	}
	{
		BuildBlock b(0, "wallspikes", getTeamIcon("wallspikes", "WallSpikes.png", team_num), "Wall Spikes Trap");
		AddRequirement(b.reqs, "blob", "mat_stone", "Stone", LWBClassesCosts::wallspikes);
		blocks[0].push_back(b);
	}
	{
		BuildBlock b(0, "beartrap", getTeamIcon("beartrap", "Beartrap.png", team_num), "Bear Trap\nWorks against enemies only");
		AddRequirement(b.reqs, "blob", "mat_stone", "Stone", LWBClassesCosts::beartrap);
		blocks[0].push_back(b);
	}
	{
		BuildBlock b(0, "workbench", "$workbench$", "Workbench\nCreate trampolines, saws, and more");
		AddRequirement(b.reqs, "blob", "mat_wood", "Wood", WARCosts::workbench_wood);
		b.buildOnGround = true;
		b.size.Set(32, 16);
		blocks[0].push_back(b);
	}

	if (CTF || SCTF || SBX)
	{
		BuildBlock b(0, "building", "$building$", "Workshop\nStand in an open space\nand tap this button.");
		AddRequirement(b.reqs, "blob", "mat_wood", "Wood", CTFCosts::workshop_wood);
		b.buildOnGround = true;
		b.size.Set(40, 24);
		blocks[0].push_back(b);
	}

	{
		BuildBlock b(0, "warcrafter_barricade", getTeamIcon("warcrafter_barricade", "2x2Barricade.png", team_num, Vec2f(16, 16)), "2x2 Barricade");
		AddRequirement(b.reqs, "blob", "mat_wood", "Wood", LWBClassesCosts::warcrafter_barricade);
		b.buildOnGround = true;
		b.temporaryBlob = false;
		b.size.Set(16, 16);
		blocks[0].push_back(b);
	}
	{
		BuildBlock b(0, "4_barricade", getTeamIcon("4_barricade", "1x4Barricade.png", team_num, Vec2f(16, 16), 1), "1x4 Barricade");
		AddRequirement(b.reqs, "blob", "mat_wood", "Wood", LWBClassesCosts::barricade_4);
		b.buildOnGround = true;
		b.temporaryBlob = false;
		b.size.Set(8, 32);
		blocks[0].push_back(b);
	}
	{
		BuildBlock b(0, "6_barricade", getTeamIcon("6_barricade", "1x6Barricade.png", team_num, Vec2f(16, 16), 1), "1x6 Barricade");
		AddRequirement(b.reqs, "blob", "mat_wood", "Wood", LWBClassesCosts::barricade_6);
		b.buildOnGround = true;
		b.temporaryBlob = false;
		b.size.Set(8, 48);
		blocks[0].push_back(b);
	}
	{
		BuildBlock b(0, "8_barricade", getTeamIcon("8_barricade", "1x8Barricade.png", team_num, Vec2f(16, 16), 1), "1x8 Barricade");
		AddRequirement(b.reqs, "blob", "mat_wood", "Wood", LWBClassesCosts::barricade_8);
		b.buildOnGround = true;
		b.temporaryBlob = false;
		b.size.Set(8, 64);
		blocks[0].push_back(b);
	}
	{
		BuildBlock b(0, "10_barricade", getTeamIcon("10_barricade", "1x10Barricade.png", team_num, Vec2f(16, 16), 1), "1x10 Barricade");
		AddRequirement(b.reqs, "blob", "mat_wood", "Wood", LWBClassesCosts::barricade_10);
		b.buildOnGround = true;
		b.temporaryBlob = false;
		b.size.Set(8, 80);
		blocks[0].push_back(b);
	}
	
	//from here, they are craft type blob
	//buildOnGround means don't pickup on craft

	BuildBlock[] page_1;
	blocks.push_back(page_1);
	{
		BuildBlock b(0, "fireplace", "$fireplace$", "Fireplace\nLarge lighting and make arrow fire\nIt's not static blob, beware");
		AddRequirement(b.reqs, "blob", "mat_wood", "Wood", LWBClassesCosts::fireplace_wood);
		AddRequirement(b.reqs, "blob", "mat_stone", "Stone", LWBClassesCosts::fireplace_stone);
		if (TTH) AddRequirement(b.reqs, "tech", "pyro", "Pyrotechnics Technology");
		b.buildOnGround = true;
		blocks[1].push_back(b);
	}
	{
		BuildBlock b(0, "raft", "$log$", "Raft\nOr Ram?");
		AddRequirement(b.reqs, "blob", "log", "Wood Log", LWBClassesCosts::raft);
		blocks[1].push_back(b);
	}
	{
		BuildBlock b(0, "makeshift_catapult", "$makeshift_catapult$", "Catapult\nHalf throwing amount\nHalf throwing power except for rocks");
		AddRequirement(b.reqs, "blob", "mat_wood", "Wood", LWBClassesCosts::makeshiftcatapult_wood);
		AddRequirement(b.reqs, "blob", "mat_stone", "Stone", LWBClassesCosts::makeshiftcatapult_stone);
		if (TTH) AddRequirement(b.reqs, "tech", "catapult", "Catapult Technology");
		blocks[1].push_back(b);
	}
	{
		BuildBlock b(0, "cart", "$cart$", "Cart\nCan be upgraded to tower or ram");
		AddRequirement(b.reqs, "blob", "mat_wood", "Wood", LWBClassesCosts::cart);
		b.buildOnGround = true;
		blocks[1].push_back(b);
	}
}