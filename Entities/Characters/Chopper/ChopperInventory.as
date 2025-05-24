// Chopper logic

#include "BuilderCommon.as";
#include "ChopperCommon.as";
#include "PlacementCommon.as";
#include "CommonChopperBlocks.as";
#include "KnockedCommon.as";
#include "StandardControlsCommon.as";

const u8 GRID_SIZE = 48;
const u8 GRID_PADDING = 36;

const Vec2f MENU_SIZE(3, 3);
const u32 SHOW_NO_BUILD_TIME = 90;

void onInit(CInventory@ this)
{
	CBlob@ blob = this.getBlob();
	if (blob is null) return;

	ControlsSwitch@ controls_switch = @onSwitch;
	blob.set("onSwitch handle", @controls_switch);

	ControlsCycle@ controls_cycle = @onCycle;
	blob.set("onCycle handle", @controls_cycle);

	if (!blob.exists(blocks_property))
	{
		BuildBlock[][] blocks;
		addCommonChopperBlocks(blocks, blob.getTeamNum());
		blob.set(blocks_property, blocks);
	}

	if (!blob.exists(inventory_offset))
	{
		blob.set_Vec2f(inventory_offset, Vec2f(0, 174));
	}

	AddIconToken("$BUILDER_CLEAR$", "BuilderIcons.png", Vec2f(32, 32), 2);

	blob.addCommandID("make block");
	blob.addCommandID("make block client");
	blob.addCommandID("tool clear");
	blob.addCommandID("tool clear client");
	blob.addCommandID("tool sync");
	blob.addCommandID("tool sync client");

	blob.set_Vec2f("backpack position", Vec2f_zero);

	blob.set_u8("build page", 0);

	blob.set_u8("buildblob", 255);
	blob.set_TileType("buildtile", 0);

	blob.set_u32("cant build time", 0);
	blob.set_u32("show build time", 0);

	for (uint i = 0; i < toolNames.length; i++)
	{
		blob.addCommandID("pick " + toolNames[i]);
	}
	const string texName = "Entities/Characters/Chopper/ChopperIcons.png";
	AddIconToken("$Chopper_Axe$", texName, Vec2f(16, 32), 0);
	AddIconToken("$Mattock$", texName, Vec2f(16, 32), 1);

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
			if (hasRequirements(this, b.reqs, missing, not b.buildOnGround))
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

		const Vec2f TOOL_POS = menu.getUpperLeftPosition() - Vec2f(GRID_PADDING, 0) + Vec2f(-1, 1) * GRID_SIZE / 2;

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

		//tool menu
		if(ToolType::count == 0) return;

		ChopperInfo@ chopper;
		if (!blob.get("chopperInfo", @chopper)) return;

		const Vec2f WEAPON_POS = menu.getUpperLeftPosition() + (menu.getLowerRightPosition() - menu.getUpperLeftPosition()) / 2 + Vec2f(0, -160);

		CGridMenu@ weapon = CreateGridMenu(WEAPON_POS, blob, Vec2f(ToolType::count, 2), "Tool");
		if (weapon !is null)
		{
			weapon.deleteAfterClick = false;
		
			for (uint i = 0; i < ToolType::count; i++)
			{
				CBitStream params;
				params.write_u8(i);
				CGridButton @button = weapon.AddButton(toolIcons[i], toolNames[i], "ChopperInventory.as", "Callback_PickTool", params);
		
				if (button !is null)
				{
					if (blob.get_u8("tool_type") == i)
					{
						button.SetSelected(1);
					}
				}
			}
		}
	}
}

void Callback_PickTool(CBitStream@ params)
{
	CPlayer@ player = getLocalPlayer();
	if (player is null) return;

	CBlob@ blob = player.getBlob();
	if (blob is null) return;

	u8 tool_id;
	if (!params.saferead_u8(tool_id)) return;

	string toolname = toolNames[tool_id];
	blob.set_u8("tool_type", tool_id);

	blob.SendCommand(blob.getCommandID("pick " + toolname));
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

	if (toolNames.length == 0) return;

	// cycle tools
	u8 type = this.get_u8("tool_type");
	type++;
	if (type >= toolNames.length)
		type = 0;
	CycleToToolType(this, type);
}

void onSwitch(CBitStream@ params)
{
	u16 this_id;
	if (!params.saferead_u16(this_id)) return;

	CBlob@ this = getBlobByNetworkID(this_id);
	if (this is null) return;

	if (toolNames.length == 0) return;

	u8 type;
	if (!params.saferead_u8(type)) return;

	CycleToToolType(this, type);
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

		const u8 PAGE = blob.get_u8("build page");
		if (blocks !is null && i >= 0 && i < blocks[PAGE].length)
		{
			BuildBlock@ block = @blocks[PAGE][i];
			bool canBuildBlock = canBuild(blob, @blocks[PAGE], i) && !isKnocked(blob);
			if (!canBuildBlock)
			{
				return;
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

			if (block.tile == 0)
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

			if (block.tile == 0)
			{
				server_BuildBlob(blob, @blocks[PAGE], i);
			}
			else
			{
				blob.set_TileType("buildtile", block.tile);
			}

			if (blob.isMyPlayer())
			{
				SetHelp(blob, "help self action", "builder", getTranslatedString("$Build$Build/Place  $LMB$"), "", 3);
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

		blob.server_SendCommandToPlayer(blob.getCommandID("tool clear client"), callerp);
	}
	else if (cmd == this.getCommandID("tool sync") && isServer())
	{
		ReceiveToolState(this, params);
	}
	else if (cmd == blob.getCommandID("tool clear client") && isClient())
	{
		blob.ClearGridMenus();

		ClearCarriedBlock(blob);
	}
	else if (cmd == blob.getCommandID("tool sync") && isServer())
	{
		ReceiveToolState(blob, params);
	}
	else if (cmd == blob.getCommandID("tool sync client") && isClient())
	{
		ReceiveToolState(blob, params);
	}
	else if (isServer())
	{
		for (uint i = 0; i < toolNames.length; i++)
		{
			if (cmd == blob.getCommandID("pick " + toolNames[i]))
			{
				CBitStream params;
				params.write_u8(i);
				blob.set_u8("tool_type", i);
				blob.SendCommand(blob.getCommandID("tool sync client"), params);
				break;
			}
		}
	}
}

void CycleToToolType(CBlob@ this, u8 toolType)
{
	this.set_u8("tool_type", toolType);
	if (this.isMyPlayer())
	{
		Sound::Play("/CycleInventory.ogg");
	}
	ClientSendToolState(this);
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
