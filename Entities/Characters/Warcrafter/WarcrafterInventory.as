// Warcrafter logic

#include "BuilderCommon.as";
#include "PlacementCommon.as";
#include "Help.as";
#include "CommonWarcrafterBlocks.as";
#include "KnockedCommon.as";
#include "Requirements_Tech.as"
#include "LWBCosts.as"
#include "StandardControlsCommon.as";

namespace Warcrafter
{
	enum Page
	{
		PAGE_BUILD = 0,
		PAGE_CRAFT,
		PAGE_COUNT
	};
}

const string[] PAGE_NAME =
{
	"Building",
	"Crafting"
};

const u8 GRID_SIZE = 48;
const u8 GRID_PADDING = 12;

const Vec2f MENU_SIZE(3, 6);
const u32 SHOW_NO_BUILD_TIME = 90;

void onInit(CInventory@ this)
{
	AddIconToken("$pyro$", "Fireplace.png", Vec2f(16, 16), 0);

	CBlob@ blob = this.getBlob();
	if (blob is null) return;

	//ControlsSwitch@ controls_switch = @onSwitch;
	//blob.set("onSwitch handle", @controls_switch);

	ControlsCycle@ controls_cycle = @onCycle;
	blob.set("onCycle handle", @controls_cycle);

	if (!blob.exists(blocks_property))
	{
		BuildBlock[][] blocks;
		addCommonWarcrafterBlocks(blocks, blob.getTeamNum());
		blob.set(blocks_property, blocks);
	}

	if (!blob.exists(inventory_offset))
	{
		blob.set_Vec2f(inventory_offset, Vec2f(0, 174));
	}

	AddIconToken("$BUILDER_CLEAR$", "BuilderIcons.png", Vec2f(32, 32), 2);
	AddIconToken("$WARCRAFTER_WEAPONS$", "WarcrafterIcons.png", Vec2f(32, 32), 0);

	for(u8 i = 0; i < Warcrafter::PAGE_COUNT; i++)
	{
		AddIconToken("$"+PAGE_NAME[i]+"$", "WarcrafterPageIcons.png", Vec2f(48, 24), i);
	}

	blob.addCommandID("make block");
	blob.addCommandID("make block client");
	blob.addCommandID("tool clear");
	blob.addCommandID("tool clear client");
	blob.addCommandID("weapon mode");
	blob.addCommandID("weapon mode client");
	blob.addCommandID("page select");
	blob.addCommandID("page select client");

	blob.set_Vec2f("backpack position", Vec2f_zero);

	blob.set_u8("build page", 0);

	blob.set_u8("buildblob", 255);
	blob.set_TileType("buildtile", 0);

	blob.set_bool("weapon_mode", false);
	blob.set_u8("axe_delay", 0);
	blob.set_u8("torch_delay", 0);

	blob.set_u32("cant build time", 0);
	blob.set_u32("show build time", 0);

	this.getCurrentScript().removeIfTag = "dead";
}

void MakeBlocksMenu(CInventory@ this, const Vec2f &in INVENTORY_CE)
{
	CBlob@ blob = this.getBlob();
	if (blob is null) return;

	BuildBlock[][]@ blocks;
	blob.get(blocks_property, @blocks);
	if (blocks is null) return;

	const Vec2f MENU_CE = Vec2f(0, MENU_SIZE.y * -GRID_SIZE - GRID_PADDING) + INVENTORY_CE;

	CGridMenu@ menu = CreateGridMenu(MENU_CE, blob, MENU_SIZE, getTranslatedString("Build"));
	if (menu !is null)
	{
		menu.deleteAfterClick = false;

		const u8 PAGE = blob.get_u8("build page");

		for(u8 i = 0; i < blocks[PAGE].length; i++)
		{
			BuildBlock@ b = blocks[PAGE][i];
			if (b is null) continue;
			string block_desc = getTranslatedString(b.description);
			CBitStream params;
			params.write_u8(i);
			CGridButton@ button = menu.AddButton(b.icon, "\n" + block_desc, blob.getCommandID("make block"), params);
			if (button is null) continue;

			button.selectOneOnClick = true;

			CBitStream missing;
			bool craftable = false;
			if (PAGE == Warcrafter::PAGE_CRAFT) craftable = hasRequirements_Tech(this, null, b.reqs, missing);
			else craftable = hasRequirements(this, b.reqs, missing, not b.buildOnGround);
			if (craftable)
			{
				button.hoverText = block_desc + "\n" + getButtonRequirementsText(b.reqs, false);
			}
			else
			{
				button.hoverText = block_desc + "\n" + getButtonRequirementsText(missing, true);
				button.SetEnabled(false);
			}

			CBlob@ carryBlob = blob.getCarriedBlob();
			if (carryBlob !is null && carryBlob.getName() == b.name)
			{
				button.SetSelected(1);
			}
			else if (b.tile == blob.get_TileType("buildtile") && b.tile != 0)
			{
				button.SetSelected(1);
			}
		}

		Vec2f TOOL_POS = menu.getUpperLeftPosition() - Vec2f(GRID_PADDING, 0) + Vec2f(-1, 1) * GRID_SIZE / 2;

		CGridMenu@ tool = CreateGridMenu(TOOL_POS, blob, Vec2f(1, 1), "");
		if (tool !is null)
		{
			tool.SetCaptionEnabled(false);

			CGridButton@ clear = tool.AddButton("$BUILDER_CLEAR$", "", blob.getCommandID("tool clear"), Vec2f(1, 1));
			if (clear !is null)
			{
				clear.SetHoverText(getTranslatedString("Stop building\n"));
			}
		}

		CGridMenu@ weapon = CreateGridMenu(TOOL_POS + Vec2f(0.0f, 64.0f), blob, Vec2f(1, 1), "");
		if (weapon !is null)
		{
			weapon.SetCaptionEnabled(false);

			CGridButton@ clear = weapon.AddButton("$WARCRAFTER_WEAPONS$", "", blob.getCommandID("weapon mode"), Vec2f(1, 1));
			if (clear !is null)
			{
				clear.SetHoverText("Making Weapon\n\n[LMB] to make and throw makeshift axe:\n" + 
					LWBClassesCosts::warcrafter_axe_wood +
					" Wood and " +
					LWBClassesCosts::warcrafter_axe_stone +
					" Stone\n\n[SPACE] near fireplace to make torch:\n" +
					LWBClassesCosts::warcrafter_torch +
					" Wood");
			}
		}

		const Vec2f INDEX_POS = Vec2f(menu.getLowerRightPosition().x + GRID_PADDING + GRID_SIZE, menu.getUpperLeftPosition().y + GRID_SIZE * Warcrafter::PAGE_COUNT / 2);

		CGridMenu@ index = CreateGridMenu(INDEX_POS, blob, Vec2f(2, Warcrafter::PAGE_COUNT), "Type");
		if (index !is null)
		{
			index.deleteAfterClick = false;

			for(u8 i = 0; i < Warcrafter::PAGE_COUNT; i++)
			{
				CBitStream params;
				params.write_u8(i);
				CGridButton@ button = index.AddButton("$"+PAGE_NAME[i]+"$", PAGE_NAME[i], blob.getCommandID("page select"), Vec2f(2, 1), params);
				if (button is null) continue;

				button.selectOneOnClick = true;

				if (i == PAGE)
				{
					button.SetSelected(1);
				}
			}
		}
	}
}

void onCreateInventoryMenu(CInventory@ this, CBlob@ forBlob, CGridMenu@ menu)
{
	CBlob@ blob = this.getBlob();
	if (blob is null) return;

	const Vec2f INVENTORY_CE = this.getInventorySlots() * GRID_SIZE / 2 + menu.getUpperLeftPosition();
	blob.set_Vec2f("backpack position", INVENTORY_CE);

	blob.ClearGridMenusExceptInventory();

	MakeBlocksMenu(this, INVENTORY_CE);
}

// clientside
void onCycle(CBitStream@ params)
{
	u16 this_id;
	if (!params.saferead_u16(this_id)) return;

	CBlob@ this = getBlobByNetworkID(this_id);
	if (this is null) return;

	// cycle actions
	if (this.get_bool("weapon_mode"))
	{
		this.set_bool("weapon_mode", false);
		this.SendCommand(this.getCommandID("tool clear"));
	}
	else
	{
		this.set_bool("weapon_mode", true);
		this.SendCommand(this.getCommandID("weapon mode"));
	}

	if (this.isMyPlayer())
	{
		Sound::Play("/CycleInventory.ogg");
	}
}

void onCommand(CInventory@ this, u8 cmd, CBitStream@ params)
{
	CBlob@ blob = this.getBlob();
	if (blob is null) return;

	if (cmd == blob.getCommandID("make block") && isServer())
	{
		CPlayer@ callerp = getNet().getActiveCommandPlayer();
		if (callerp is null) return;

		CBlob@ callerb = callerp.getBlob();
		if (callerb is null) return;
		if (callerb !is blob) return;
		BuildBlock[][]@ blocks;
		if (!blob.get(blocks_property, @blocks)) return;

		u8 i;
		if (!params.saferead_u8(i)) return; 

		CBitStream sparams;
		sparams.write_u8(i);
		blob.SendCommand(blob.getCommandID("make block client"), sparams);

		blob.set_bool("weapon_mode", false);

		const u8 PAGE = blob.get_u8("build page");
		if (blocks !is null && i >= 0 && i < blocks[PAGE].length)
		{
			BuildBlock@ block = @blocks[PAGE][i];
			bool canBuildBlock = canBuild(blob, @blocks[PAGE], i) && !isKnocked(blob);

			if (PAGE == Warcrafter::PAGE_CRAFT)
			{
				CBitStream missing;
				canBuildBlock = hasRequirements_Tech(this, null, block.reqs, missing);
			}

			CBlob@ carryBlob = blob.getCarriedBlob();
			if (carryBlob !is null)
			{
				// check if this isn't what we wanted to create
				if (carryBlob.getName() == block.name)
				{
					return;
				}

				if (carryBlob.hasTag("temp blob"))
				{
					carryBlob.Untag("temp blob");
					carryBlob.server_Die();
				}
				else
				{
					// try put into inventory whatever was in hands
					// creates infinite mats duplicating if used on build block, not great :/
					if (!block.buildOnGround && !blob.server_PutInInventory(carryBlob))
					{
						carryBlob.server_DetachFromAll();
					}
				}
			}
			
			if (PAGE == Warcrafter::PAGE_CRAFT)
			{
				server_CraftBlob(blob, @blocks[PAGE], i);
			}
			else if (block.tile == 0)
			{
				server_BuildBlob(blob, @blocks[PAGE], i);
			}
			else
			{
				blob.set_TileType("buildtile", block.tile);
			}
		}
	}
	else if (cmd == blob.getCommandID("make block client") && isClient())
	{
		BuildBlock[][]@ blocks;
		if (!blob.get(blocks_property, @blocks)) return;

		u8 i;
		if (!params.saferead_u8(i)) return; 

		blob.set_bool("weapon_mode", false);

		const u8 PAGE = blob.get_u8("build page");
		if (blocks !is null && i >= 0 && i < blocks[PAGE].length)
		{
			BuildBlock@ block = @blocks[PAGE][i];
			bool canBuildBlock = canBuild(blob, @blocks[PAGE], i) && !isKnocked(blob);
			if (!canBuildBlock)
			{
				if (blob.isMyPlayer())
				{
					blob.getSprite().PlaySound("/NoAmmo", 0.5);
				}
				return;
			}

			if (PAGE == Warcrafter::PAGE_CRAFT)
			{
				server_CraftBlob(blob, @blocks[PAGE], i);
			}
			else if (block.tile == 0)
			{
				server_BuildBlob(blob, @blocks[PAGE], i);
			}
			else
			{
				blob.set_TileType("buildtile", block.tile);
			}

			if (blob.isMyPlayer())
			{
				SetHelp(blob, "help self action", "warcrafter", getTranslatedString("$Build$Build/Place  $LMB$"), "", 3);
			}
		}
	}
	else if (cmd == blob.getCommandID("tool clear") && isServer())
	{
		CPlayer@ callerp = getNet().getActiveCommandPlayer();
		if (callerp is null) return;

		CBlob@ callerb = callerp.getBlob();
		if (callerb is null) return;
		if (callerb !is blob) return;

		ClearCarriedBlock(blob);

		blob.set_bool("weapon_mode", false);

		blob.server_SendCommandToPlayer(blob.getCommandID("tool clear client"), callerp);
	}
	else if (cmd == blob.getCommandID("tool clear client") && isClient())
	{
		blob.ClearGridMenus();

		blob.set_bool("weapon_mode", false);

		ClearCarriedBlock(blob);
	}
	else if (cmd ==  blob.getCommandID("weapon mode") && isServer())
	{
		CPlayer@ callerp = getNet().getActiveCommandPlayer();
		if (callerp is null) return;

		CBlob@ callerb = callerp.getBlob();
		if (callerb is null) return;
		if (callerb !is blob) return;

		ClearCarriedBlock(blob);

		blob.set_bool("weapon_mode", true);

		blob.server_SendCommandToPlayer(blob.getCommandID("weapon mode client"), callerp);
	}
	else if (cmd == blob.getCommandID("weapon mode client") && isClient())
	{
		blob.ClearGridMenus();

		blob.set_bool("weapon_mode", true);

		ClearCarriedBlock(blob);
	}
	else if (cmd == blob.getCommandID("page select") && isServer())
	{
		CPlayer@ callerp = getNet().getActiveCommandPlayer();
		if (callerp is null) return;

		CBlob@ callerb = callerp.getBlob();
		if (callerb is null) return;
		if (callerb !is blob) return;

		u8 page;
		if (!params.saferead_u8(page)) return;

		blob.set_u8("build page", page);

		ClearCarriedBlock(blob);

		CBitStream sparams;
		sparams.write_u8(page);
		blob.server_SendCommandToPlayer(blob.getCommandID("page select client"), sparams, callerp);
	}
	else if (cmd == blob.getCommandID("page select client") && isClient())
	{
		u8 page;
		if (!params.saferead_u8(page)) return;

		blob.ClearGridMenus();
		blob.set_u8("build page", page);

		ClearCarriedBlock(blob);

		if (blob is getLocalPlayerBlob())
		{
			blob.CreateInventoryMenu(blob.get_Vec2f("backpack position"));
		}
	}
}

CBlob@ server_CraftBlob(CBlob@ this, BuildBlock[]@ blocks, uint index)
{
	if (index >= blocks.length)
	{
		return null;
	}

	this.set_u32("cant build time", 0);

	CInventory@ inv = this.getInventory();
	BuildBlock@ b = @blocks[index];

	this.set_TileType("buildtile", 0);

	Vec2f pos = this.getPosition();

	this.set_u8("buildblob", 255);

	this.ClearGridMenus();

	if (getNet().isServer())
	{
		server_TakeRequirements(inv, b.reqs);
		CBlob@ blockBlob = server_CreateBlob(b.name, this.getTeamNum(), Vec2f(0,0));
		if (blockBlob !is null)
		{
			CShape@ shape = blockBlob.getShape();
			shape.SetStatic(false);
			blockBlob.setPosition(pos);
			//blockBlob.
			if (!b.buildOnGround) this.server_Pickup(blockBlob);
			blockBlob.Tag("builder always hit");

			return blockBlob;
		}
	}
	// cart plays this sound because of Shop.as
	if (b.name != "cart") this.getSprite().PlaySound("/ConstructShort");

	return null;
}

void onRender(CSprite@ this)
{
	CMap@ map = getMap();

	CBlob@ blob = this.getBlob();
	CBlob@ localBlob = getLocalPlayerBlob();
	if (localBlob is blob)
	{
		// no build zone show
		const bool onground = blob.isOnGround();
		const u32 time = blob.get_u32( "cant build time" );
		if (time + SHOW_NO_BUILD_TIME > getGameTime())
		{
			Vec2f space = blob.get_Vec2f( "building space" );
			Vec2f offsetPos = getBuildingOffsetPos(blob, map, space);

			const f32 scalex = getDriver().getResolutionScaleFactor();
			const f32 zoom = getCamera().targetDistance * scalex;
			Vec2f aligned = getDriver().getScreenPosFromWorldPos( offsetPos );

			for (f32 step_x = 0.0f; step_x < space.x ; ++step_x)
			{
				for (f32 step_y = 0.0f; step_y < space.y ; ++step_y)
				{
					Vec2f temp = ( Vec2f( step_x + 0.5, step_y + 0.5 ) * map.tilesize );
					Vec2f v = offsetPos + temp;
					Vec2f pos = aligned + (temp - Vec2f(0.5f,0.5f)* map.tilesize) * 2 * zoom;
					if (!onground || map.getSectorAtPosition(v , "no build") !is null || map.isTileSolid(v) || blobBlockingBuilding(map, v))
					{
						// draw red
						GUI::DrawIcon( "CrateSlots.png", 5, Vec2f(8,8), pos, zoom );
					}
					else
					{
						// draw white
						GUI::DrawIcon( "CrateSlots.png", 9, Vec2f(8,8), pos, zoom );
					}
				}
			}
		}

		// show cant build
		if (blob.isKeyPressed(key_action1) || blob.get_u32("show build time") + 15 > getGameTime())
		{
			if (blob.isKeyPressed(key_action1))
			{
				blob.set_u32( "show build time", getGameTime());
			}

			Vec2f cam_offset = getCamera().getInterpolationOffset();

			BlockCursor @bc;
			blob.get("blockCursor", @bc);
			if (bc !is null)
			{
				if (bc.blockActive || bc.blobActive)
				{
					Vec2f pos = blob.getPosition();
					Vec2f myPos =  blob.getInterpolatedScreenPos() + Vec2f(0.0f,(pos.y > blob.getAimPos().y) ? -blob.getRadius() : blob.getRadius());
					Vec2f aimPos2D = getDriver().getScreenPosFromWorldPos( blob.getAimPos() + cam_offset );

					if (!bc.hasReqs)
					{
						const string missingText = getButtonRequirementsText( bc.missing, true );
						Vec2f boxpos( myPos.x, myPos.y - 120.0f );
						GUI::DrawText( getTranslatedString("Requires\n") + missingText, Vec2f(boxpos.x - 50, boxpos.y - 15.0f), Vec2f(boxpos.x + 50, boxpos.y + 15.0f), color_black, false, false, true );
					}
					else if (bc.cursorClose)
					{
						if (bc.rayBlocked)
						{
							Vec2f blockedPos2D = getDriver().getScreenPosFromWorldPos(bc.rayBlockedPos + cam_offset);
							GUI::DrawArrow2D( aimPos2D, blockedPos2D, SColor(0xffdd2212) );
						}

						if (!bc.buildableAtPos && !bc.sameTileOnBack) //no build indicator drawing
						{
							CMap@ map = getMap();
							Vec2f middle = blob.getAimPos() + Vec2f(map.tilesize*0.5f, map.tilesize*0.5f);
							CMap::Sector@ sector = map.getSectorAtPosition( middle, "no build");
							if (sector !is null)
							{
								GUI::DrawRectangle( getDriver().getScreenPosFromWorldPos(sector.upperleft), getDriver().getScreenPosFromWorldPos(sector.lowerright), SColor(0x65ed1202) );
							}
							else
							{
								CBlob@[] blobsInRadius;
								if (map.getBlobsInRadius( middle, map.tilesize, @blobsInRadius ))
								{
									for (uint i = 0; i < blobsInRadius.length; i++)
									{
										CBlob @b = blobsInRadius[i];
										if (!b.isAttached())
										{
											Vec2f bpos = b.getInterpolatedPosition();
											float w = b.getWidth();
											float h = b.getHeight();

											if (b.getAngleDegrees() % 180 != 0) //swap dimentions
											{
												float t = w;
												w = h;
												h = t;
											}

											GUI::DrawRectangle( getDriver().getScreenPosFromWorldPos(bpos + Vec2f(w/-2.0f, h/-2.0f)),
																getDriver().getScreenPosFromWorldPos(bpos + Vec2f(w/2.0f, h/2.0f)),
																SColor(0x65ed1202) );
										}
									}
								}
							}
						}
					}
					else if (blob.getCarriedBlob() is null || blob.getCarriedBlob().hasTag("temp blob")) // only display the red arrow while we are building
					{
						const f32 maxDist = getMaxBuildDistance(blob) + 8.0f;
						Vec2f norm = aimPos2D - myPos;
						const f32 dist = norm.Normalize();
						norm *= (maxDist - dist);
						GUI::DrawArrow2D( aimPos2D, aimPos2D + norm, SColor(0xffdd2212) );
					}
				}
			}
		}
	}
}

bool blobBlockingBuilding(CMap@ map, Vec2f v)
{
	CBlob@[] overlapping;
	map.getBlobsAtPosition(v, @overlapping);
	for(uint i = 0; i < overlapping.length; i++)
	{
		CBlob@ o_blob = overlapping[i];
		CShape@ o_shape = o_blob.getShape();
		if (o_blob !is null &&
			o_shape !is null &&
			!o_blob.isAttached() &&
			o_shape.isStatic() &&
			!o_shape.getVars().isladder)
		{
			return true;
		}
	}
	return false;
}
