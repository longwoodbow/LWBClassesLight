// Builder logic

#include "BuilderCommon.as";
#include "RockthrowerCommon.as";
#include "PlacementCommon.as";
#include "BuildBlock.as";
#include "Requirements.as";
#include "Costs.as";
#include "KnockedCommon.as";
#include "StandardControlsCommon.as";

const Vec2f MENU_SIZE(Action::count, 2);
const u32 SHOW_NO_BUILD_TIME = 90;
void onInit(CInventory@ this)
{
	CBlob@ blob = this.getBlob();
	if (blob is null) return;

	ControlsSwitch@ controls_switch = @onSwitch;
	blob.set("onSwitch handle", @controls_switch);

	ControlsCycle@ controls_cycle = @onCycle;
	blob.set("onCycle handle", @controls_cycle);

	if (!blob.exists("blocks"))
	{
		InitCosts();
		BuildBlock[][] blocks;
		BuildBlock[] page_0;
		blocks.push_back(page_0);
		{
			BuildBlock b(0, "ladder", "$ladder$", "Ladder\nAnyone can climb it");
			AddRequirement(b.reqs, "blob", "mat_wood", "Wood", BuilderCosts::ladder);
			blocks[0].push_back(b);
		}
		blob.set("blocks", blocks);
	}

	if (!blob.exists("inventory offset"))
	{
		blob.set_Vec2f("inventory offset", Vec2f(0, 174));
	}

	blob.set_Vec2f("backpack position", Vec2f_zero);

	blob.set_u8("build page", 0);// for other scripts, no changing situation

	blob.set_u8("buildblob", 255);

	blob.set_u32("cant build time", 0);
	blob.set_u32("show build time", 0);

	blob.addCommandID("setnothing");
	blob.addCommandID("setthrow");
	blob.addCommandID("setladder");
	blob.addCommandID("setnothing client");
	blob.addCommandID("setthrow client");
	blob.addCommandID("setladder client");

	const string texName = "Entities/Characters/Rockthorwer/RockthrowerIcons.png";
	AddIconToken("$RockthrowerNothing$", texName, Vec2f(16, 32), 4);
	AddIconToken("$RockthrowerThrow$", texName, Vec2f(16, 32), 1);

	this.getCurrentScript().removeIfTag = "dead";
}

void onCreateInventoryMenu(CInventory@ this, CBlob@ forBlob, CGridMenu@ gridmenu)
{
	CBlob@ blob = this.getBlob();
	if (blob is null) return;

	AddIconToken("$RockthrowerLadder$", "Entities/Characters/Rockthorwer/RockthrowerIcons.png", Vec2f(16, 32), 2, blob.getTeamNum());

	Vec2f pos(gridmenu.getUpperLeftPosition().x + 0.5f * (gridmenu.getLowerRightPosition().x - gridmenu.getUpperLeftPosition().x),
	          gridmenu.getUpperLeftPosition().y - 32 * 1 - 2 * 24);// yes as same as knight and archer

	CGridMenu@ menu = CreateGridMenu(pos, blob, MENU_SIZE, "Throw or Build");


	RockthrowerInfo@ rockthrower;
	if (!blob.get("rockthrowerInfo", @rockthrower))
	{
		return;
	}
	const u8 actionSel = rockthrower.action;

	if (menu !is null)
	{
		menu.deleteAfterClick = false;
		{
			CGridButton @button = menu.AddButton("$RockthrowerNothing$", "Stop Action", blob.getCommandID("setnothing"));
			if (button !is null)
			{
				button.selectOneOnClick = true;
				if (actionSel == Action::nothing) button.SetSelected(1);
			}
		}
		{
			CGridButton @button = menu.AddButton("$RockthrowerThrow$", "Throw Rocks", blob.getCommandID("setthrow"));
			if (button !is null)
			{
				button.selectOneOnClick = true;
				if (actionSel == Action::throw) button.SetSelected(1);
			}
		}
		{
			CGridButton @button = menu.AddButton("$RockthrowerLadder$", "Build Ladders", blob.getCommandID("setladder"));
			if (button !is null)
			{
				button.selectOneOnClick = true;
				if (actionSel == Action::ladder) button.SetSelected(1);
			}
		}
	}
}

// clientside
void onCycle(CBitStream@ params)
{
	u16 this_id;
	if (!params.saferead_u16(this_id)) return;

	CBlob@ this = getBlobByNetworkID(this_id);
	if (this is null) return;

	// cycle actions
	RockthrowerInfo@ rockthrower;
	if (!this.get("rockthrowerInfo", @rockthrower))
	{
		return;
	}

	u8 type = rockthrower.action;

	type++;
	if (type >= Action::count)
	{
		type = 0;
	}

	CycleToActionType(this, rockthrower, type);
}

void onSwitch(CBitStream@ params)
{
	u16 this_id;
	if (!params.saferead_u16(this_id)) return;

	CBlob@ this = getBlobByNetworkID(this_id);
	if (this is null) return;

	u8 type;
	if (!params.saferead_u8(type)) return;

	RockthrowerInfo@ rockthrower;
	if (!this.get("rockthrowerInfo", @rockthrower))
	{
		return;
	}

	CycleToActionType(this, rockthrower, type);
}

void onCommand(CInventory@ this, u8 cmd, CBitStream@ params)
{
	CBlob@ blob = this.getBlob();
	if (blob is null) return;
	RockthrowerInfo@ rockthrower;
	if (!blob.get("rockthrowerInfo", @rockthrower))
	{
		return;
	}
	BuildBlock[][]@ blocks;
	if (!blob.get("blocks", @blocks)) return;

	if (cmd == blob.getCommandID("setnothing") && isServer())
	{
		ProcessingToolClear(blob);
		rockthrower.action = Action::nothing;
		blob.SendCommand(blob.getCommandID("setnothing client"));
	}
	else if (cmd == blob.getCommandID("setthrow") && isServer())
	{
		ProcessingToolClear(blob);
		rockthrower.action = Action::throw;
		blob.SendCommand(blob.getCommandID("setthrow client"));
	}
	else if (cmd == blob.getCommandID("setladder") && isServer())
	{
		rockthrower.action = Action::ladder;
		processingTempBlob(blob, @blocks[0], 0);
		blob.SendCommand(blob.getCommandID("setladder client"));
	}
	if (cmd == blob.getCommandID("setnothing client") && isClient())
	{
		blob.ClearGridMenus();

		ClearCarriedBlock(blob);

		rockthrower.action = Action::nothing;
	}
	else if (cmd == blob.getCommandID("setthrow client") && isClient())
	{
		blob.ClearGridMenus();

		ClearCarriedBlock(blob);

		rockthrower.action = Action::throw;
		//rockHelp(blob);
	}
	else if (cmd == blob.getCommandID("setladder client") && isClient())
	{
		rockthrower.action = Action::ladder;
		processingTempBlob_client(blob, @blocks[0], 0);
	}
}

void CycleToActionType(CBlob@ this, RockthrowerInfo@ rockthrower, u8 actionType)
{
	rockthrower.action = actionType;
	if (this.isMyPlayer())
	{
		Sound::Play("/CycleInventory.ogg");
	}

	if (!isClient()) { return; }
	if (isServer()) { return; } // no need to sync on localhost

	string commandname;
	switch(actionType)
	{
		case Action::nothing:
			commandname = "setnothing";
		break;

		case Action::throw:
			commandname = "setthrow";
		break;

		case Action::ladder:
			commandname = "setladder";
		break;
	}
	
	this.SendCommand(this.getCommandID(commandname));
}

void processingTempBlob(CBlob@ blob, BuildBlock[]@ blocks, uint i)
{
	CPlayer@ callerp = getNet().getActiveCommandPlayer();
	if (callerp is null) return;

	CBlob@ callerb = callerp.getBlob();
	if (callerb is null) return;
	if (callerb !is blob) return;

	BuildBlock@ block = @blocks[i];

	bool canBuildBlock = canBuild(blob, @blocks, i) && !isKnocked(blob);
	if (!canBuildBlock)
	{
		return;
	}
	
	// put carried in inventory thing first
	
	if (getNet().isServer())
	{
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
				if (!blob.server_PutInInventory(carryBlob))
				{
					carryBlob.server_DetachFromAll();
				}
			}
		}
	}

	server_BuildBlob(blob, @blocks, i);
}

void processingTempBlob_client(CBlob@ blob, BuildBlock[]@ blocks, uint i)
{
	BuildBlock@ block = @blocks[i];

	bool canBuildBlock = canBuild(blob, @blocks, i) && !isKnocked(blob);
	if (!canBuildBlock)
	{
		if (blob.isMyPlayer())
		{
			blob.getSprite().PlaySound("/NoAmmo", 0.5);
		}
		return;
	}
	
	server_BuildBlob(blob, @blocks, i);

	if (blob.isMyPlayer())
	{
		SetHelp(blob, "help self action", "rockthrower", getTranslatedString("$Build$Build/Place  $LMB$"), "", 3);
	}
}

void ProcessingToolClear(CBlob@ blob)
{
	CPlayer@ callerp = getNet().getActiveCommandPlayer();
	if (callerp is null) return;

	CBlob@ callerb = callerp.getBlob();
	if (callerb is null) return;
	if (callerb !is blob) return;

	ClearCarriedBlock(blob);
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
		if ((blob.isKeyPressed(key_action1) && isBuildTime(blob)) || blob.get_u32("show build time") + 15 > getGameTime())
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
