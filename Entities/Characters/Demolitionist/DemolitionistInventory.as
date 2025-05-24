// Demolitionist logic

#include "BuilderCommon.as";
#include "DemolitionistCommon.as";
#include "PlacementCommon.as";
#include "Help.as";
#include "BuildBlock.as";
#include "Requirements.as";
#include "Costs.as";
#include "KnockedCommon.as";
#include "LWBCosts.as";
#include "StandardControlsCommon.as";

const Vec2f MENU_SIZE(ActionType::count, 2);
const u32 SHOW_NO_BUILD_TIME = 90;

const string inventory_offset = "inventory offset";

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
			BuildBlock b(0, "bombbox", "$bombbox$", "Sticky Bomb Box");
			AddRequirement(b.reqs, "blob", "mat_bombboxes", "Bomb Box", 1);
			blocks[0].push_back(b);
		}
		{
			BuildBlock b(0, "makeshift_barricade", "$makeshift_barricade$", "Wooden Barricade\nblock anyone's passing\neveryone can break");
			AddRequirement(b.reqs, "blob", "mat_wood", "Wood", LWBClassesCosts::wooden_barricade);
			blocks[0].push_back(b);
		}
		{
			BuildBlock b(0, "stone_barricade", "$stone_barricade$", "Stone Barricade\nblock anyone's passing\neveryone can break");
			AddRequirement(b.reqs, "blob", "mat_stone", "Stone", LWBClassesCosts::stone_barricade);
			blocks[0].push_back(b);
		}
		blob.set("blocks", blocks);
	}

	if (!blob.exists(inventory_offset))
	{
		blob.set_Vec2f(inventory_offset, Vec2f(0, 174));
	}

	blob.set_Vec2f("backpack position", Vec2f_zero);

	blob.set_u8("build page", 0);

	blob.set_u8("buildblob", 255);

	blob.set_u32("cant build time", 0);
	blob.set_u32("show build time", 0);

	blob.addCommandID("setnothing");
	blob.addCommandID("setpickaxe");
	blob.addCommandID("setbomb");
	blob.addCommandID("setwood");
	blob.addCommandID("setstone");
	blob.addCommandID("setnothing client");
	blob.addCommandID("setpickaxe client");
	blob.addCommandID("setbomb client");
	blob.addCommandID("setwood client");
	blob.addCommandID("setstone client");


	const string texName = "Entities/Characters/Demolitionist/DemolitionistIcons.png";
	AddIconToken("$DemolitionistNothing$", texName, Vec2f(16, 32), 0);
	AddIconToken("$DemolitionistPickaxe$", texName, Vec2f(16, 32), 1);
	AddIconToken("$DemolitionistBomb$", texName, Vec2f(16, 32), 2);
	AddIconToken("$DemolitionistWood$", texName, Vec2f(16, 32), 3);
	AddIconToken("$DemolitionistStone$", texName, Vec2f(16, 32), 4);

	this.getCurrentScript().removeIfTag = "dead";
}

void onCreateInventoryMenu(CInventory@ this, CBlob@ forBlob, CGridMenu@ gridmenu)
{
	CBlob@ blob = this.getBlob();
	if (blob is null) return;

	Vec2f pos(gridmenu.getUpperLeftPosition().x + 0.5f * (gridmenu.getLowerRightPosition().x - gridmenu.getUpperLeftPosition().x),
	          gridmenu.getUpperLeftPosition().y - 32 * 1 - 2 * 24);// yes as same as knight and archer

	CGridMenu@ menu = CreateGridMenu(pos, blob, MENU_SIZE, "Pickaxe or Build");


	DemolitionistInfo@ demolitionist;
	if (!blob.get("demolitionistInfo", @demolitionist))
	{
		return;
	}
	const u8 actionSel = demolitionist.action_type;

	if (menu !is null)
	{
		menu.deleteAfterClick = false;

		for (uint i = 0; i < ActionType::count; i++)
		{
			string iconName, actionName, commandName;

			switch(i)
			{
				case ActionType::nothing:
				{
					iconName = "$DemolitionistNothing$";
					actionName = "Stop Action";
					commandName = "setnothing";
				}
				break;

				case ActionType::pickaxe:
				{
					iconName = "$DemolitionistPickaxe$";
					actionName = "Pixkaxe";
					commandName = "setpickaxe";
				}
				break;

				case ActionType::bomb:
				{
					iconName = "$DemolitionistBomb$";
					actionName = "Sticky Bomb Box";
					commandName = "setbomb";
				}
				break;

				case ActionType::wood:
				{
					iconName = "$DemolitionistWood$";
					actionName = "Wooden Barricade\nBlocks everything\nEveryone can break";
					commandName = "setwood";
				}
				break;

				case ActionType::stone:
				{
					iconName = "$DemolitionistStone$";
					actionName = "Stone Barricade\nBlocks everything\nEveryone can break";
					commandName = "setstone";
				}
				break;
			}

			CGridButton @button = menu.AddButton(iconName, actionName, blob.getCommandID(commandName));

			if (button !is null)
			{
				button.selectOneOnClick = true;

				//if (enabled && i == ArrowType::fire && !hasReqs(this, i))
				//{
				//	button.hoverText = "Requires a fire source $lantern$";
				//	//button.SetEnabled( false );
				//}

				if (actionSel == i)
				{
					button.SetSelected(1);
				}
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
	DemolitionistInfo@ demolitionist;
	if (!this.get("demolitionistInfo", @demolitionist))
	{
		return;
	}

	u8 type = demolitionist.action_type;

	type++;
	if (type >= ActionType::count)
	{
		type = 0;
	}

	CycleToActionType(this, demolitionist, type);
}

void onSwitch(CBitStream@ params)
{
	u16 this_id;
	if (!params.saferead_u16(this_id)) return;

	CBlob@ this = getBlobByNetworkID(this_id);
	if (this is null) return;

	u8 type;
	if (!params.saferead_u8(type)) return;

	DemolitionistInfo@ demolitionist;
	if (!this.get("demolitionistInfo", @demolitionist))
	{
		return;
	}

	CycleToActionType(this, demolitionist, type);
}

void onCommand(CInventory@ this, u8 cmd, CBitStream@ params)
{
	CBlob@ blob = this.getBlob();
	if (blob is null) return;
	DemolitionistInfo@ demolitionist;
	if (!blob.get("demolitionistInfo", @demolitionist))
	{
		return;
	}
	BuildBlock[][]@ blocks;
	if (!blob.get("blocks", @blocks)) return;

	if (cmd == blob.getCommandID("setnothing") && isServer())
	{
		ProcessingToolClear(blob);
		demolitionist.action_type = ActionType::nothing;
		blob.SendCommand(blob.getCommandID("setnothing client"));
	}
	else if (cmd == blob.getCommandID("setpickaxe") && isServer())
	{
		ProcessingToolClear(blob);
		demolitionist.action_type = ActionType::pickaxe;
		blob.SendCommand(blob.getCommandID("setpickaxe client"));
	}
	else if (cmd == blob.getCommandID("setbomb") && isServer())
	{
		demolitionist.action_type = ActionType::bomb;
		ProcessingTempBlob(blob, @blocks[0], 0);
		blob.SendCommand(blob.getCommandID("setbomb client"));
	}
	else if (cmd == blob.getCommandID("setwood") && isServer())
	{
		demolitionist.action_type = ActionType::wood;
		ProcessingTempBlob(blob, @blocks[0], 1);
		blob.SendCommand(blob.getCommandID("setwood client"));
	}
	else if (cmd == blob.getCommandID("setstone") && isServer())
	{
		demolitionist.action_type = ActionType::stone;
		ProcessingTempBlob(blob, @blocks[0], 2);
		blob.SendCommand(blob.getCommandID("setstone client"));
	}
	if (cmd == blob.getCommandID("setnothing client") && isClient())
	{
		blob.ClearGridMenus();

		ClearCarriedBlock(blob);

		demolitionist.action_type = ActionType::nothing;
	}
	else if (cmd == blob.getCommandID("setpickaxe client") && isClient())
	{
		blob.ClearGridMenus();

		ClearCarriedBlock(blob);

		demolitionist.action_type = ActionType::pickaxe;
	}
	else if (cmd == blob.getCommandID("setbomb client") && isClient())
	{
		demolitionist.action_type = ActionType::bomb;
		ProcessingTempBlob_client(blob, @blocks[0], 0);
	}
	else if (cmd == blob.getCommandID("setwood client") && isClient())
	{
		demolitionist.action_type = ActionType::wood;
		ProcessingTempBlob_client(blob, @blocks[0], 1);
	}
	else if (cmd == blob.getCommandID("setstone client") && isClient())
	{
		demolitionist.action_type = ActionType::stone;
		ProcessingTempBlob_client(blob, @blocks[0], 2);
	}
}

void CycleToActionType(CBlob@ this, DemolitionistInfo@ demolitionist, u8 actionType)
{
	demolitionist.action_type = actionType;
	if (this.isMyPlayer())
	{
		Sound::Play("/CycleInventory.ogg");
	}

	if (!isClient()) { return; }
	if (isServer()) { return; } // no need to sync on localhost

	string commandname;
	switch(actionType)
	{
		case ActionType::nothing:
			commandname = "setnothing";
		break;

		case ActionType::pickaxe:
			commandname = "setpickaxe";
		break;

		case ActionType::bomb:
			commandname = "setbomb";
		break;

		case ActionType::wood:
			commandname = "setwood";
		break;

		case ActionType::stone:
			commandname = "setstone";
		break;
	}
	
	this.SendCommand(this.getCommandID(commandname));
}

void ProcessingTempBlob(CBlob@ blob, BuildBlock[]@ blocks, uint i)
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

	server_BuildBlob(blob, @blocks, i);
}

void ProcessingTempBlob_client(CBlob@ blob, BuildBlock[]@ blocks, uint i)
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
		SetHelp(blob, "help self action", "demolitionist", getTranslatedString("$Build$Build/Place  $LMB$"), "", 3);
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
