// CommonBuilderBlocks.as

//////////////////////////////////////
// Builder menu documentation
//////////////////////////////////////

// To add a new page;

// 1) initialize a new BuildBlock array,
// example:
// BuildBlock[] my_page;
// blocks.push_back(my_page);

// 2)
// Add a new string to PAGE_NAME in
// BuilderInventory.as
// this will be what you see in the caption
// box below the menu

// 3)
// Extend BuilderPageIcons.png with your new
// page icon, do note, frame index is the same
// as array index

// To add new blocks to a page, push_back
// in the desired order to the desired page
// example:
// BuildBlock b(0, "name", "icon", "description");
// blocks[3].push_back(b);

#include "BuildBlock.as"
#include "Requirements.as"
#include "Costs.as"
#include "TeamIconToken.as"
#include "LWBCosts.as"

const string blocks_property = "blocks";
const string inventory_offset = "inventory offset";

void addCommonChopperBlocks(BuildBlock[][]@ blocks, int team_num = 0, const string&in gamemode_override = "")
{
	AddIconToken("$dirt_block$", "Sprites/World.png", Vec2f(8, 8), CMap::tile_ground);
	AddIconToken("$icon_nursery$", "MiniIcons.png", Vec2f(16, 16), 27);
	InitCosts();

	BuildBlock[] page_0;
	blocks.push_back(page_0);
	{
		BuildBlock b(CMap::tile_wood, "wood_block", "$wood_block$", "Wood Block\nCheap block\nwatch out for fire!");
		AddRequirement(b.reqs, "blob", "mat_wood", "Wood", BuilderCosts::wood_block);
		blocks[0].push_back(b);
	}
	{
		BuildBlock b(CMap::tile_wood_back, "back_wood_block", "$back_wood_block$", "Back Wood Wall\nCheap extra support");
		AddRequirement(b.reqs, "blob", "mat_wood", "Wood", BuilderCosts::back_wood_block);
		blocks[0].push_back(b);
	}
	{
		BuildBlock b(0, "wooden_door", getTeamIcon("wooden_door", "1x1WoodDoor.png", team_num, Vec2f(16, 8)), "Wooden Door\nPlace next to walls");
		AddRequirement(b.reqs, "blob", "mat_wood", "Wood", BuilderCosts::wooden_door);
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
		BuildBlock b(0, "wooden_spikes", "$wooden_spikes$", "Wooden Spikes\nHalf damage\nNo falling attack");
		AddRequirement(b.reqs, "blob", "mat_wood", "Wood", LWBClassesCosts::wooden_spikes);
		blocks[0].push_back(b);
	}
	{
		BuildBlock b(CMap::tile_ground, "dirt_block", "$dirt_block$", "Dirt Block\nCan place on background dirt");
		AddRequirement(b.reqs, "blob", "mat_wood", "Wood",  LWBClassesCosts::planter_block_wood);
		AddRequirement(b.reqs, "blob", "mat_stone", "Stone",  LWBClassesCosts::planter_block_stone);
		blocks[0].push_back(b);
	}
	if (LWBClassesCosts::allow_nursery)
	{
		BuildBlock b(0, "nursery_chopper", "$icon_nursery$", "Nursery");
		AddRequirement(b.reqs, "blob", "mat_wood", "Wood", LWBClassesCosts::nursery);
		b.buildOnGround = true;
		b.size.Set(40, 32);
		blocks[0].push_back(b);
	}
}