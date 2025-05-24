// Assassin logic

#include "AssassinCommon.as"
#include "ThrowCommon.as"
#include "KnockedCommon.as"
#include "Hitters.as"
#include "RunnerCommon.as"
#include "ShieldCommon.as";
#include "Help.as";
#include "Requirements.as"
#include "EmotesCommon.as";
#include "RedBarrierCommon.as"

u8 delay_between_hit = 10;

void onInit(CBlob@ this)
{
	AssassinInfo assassin;
	this.set("assassinInfo", @assassin);

	this.set_f32("gib health", -1.5f);
	this.Tag("player");
	this.Tag("flesh");

	//centered on arrows
	//this.set_Vec2f("inventory offset", Vec2f(0.0f, 122.0f));
	//centered on items
	this.set_Vec2f("inventory offset", Vec2f(0.0f, 0.0f));

	//no spinning
	this.getShape().SetRotationsAllowed(false);
	this.getShape().getConsts().net_threshold_multiplier = 0.5f;

	this.addCommandID(grapple_sync_cmd);
	this.addCommandID("smokeball");
	this.addCommandID("knife");

	AddIconToken("$AssassinGrapple$", "LWBHelpIcons.png", Vec2f(16, 16), 9);

	SetHelp(this, "help self action", "assassin", getTranslatedString("$Daggar$Stab        $LMB$"), "", 255);
	SetHelp(this, "help self hide", "assassin", getTranslatedString("Hide    $KEY_S$"), "", 255);
	SetHelp(this, "help self action2", "assassin", getTranslatedString("$AssassinGrapple$ Grappling hook    $RMB$"), "", 255);

	this.getCurrentScript().runFlags |= Script::tick_not_attached;
	this.getCurrentScript().removeIfTag = "dead";
}

void onSetPlayer(CBlob@ this, CPlayer@ player)
{
	if (player !is null)
	{
		player.SetScoreboardVars("ScoreboardIcons.png", 3, Vec2f(16, 16));
	}
}

void ManageGrapple(CBlob@ this, AssassinInfo@ assassin)
{
	CSprite@ sprite = this.getSprite();
	Vec2f pos = this.getPosition();

	const bool right_click = this.isKeyJustPressed(key_action2);
	if (right_click)
	{
		if (canSend(this) || isServer()) //otherwise grapple
		{
			assassin.grappling = true;
			assassin.grapple_id = 0xffff;
			assassin.grapple_pos = pos;

			assassin.grapple_ratio = 1.0f; //allow fully extended

			Vec2f direction = this.getAimPos() - pos;

			//aim in direction of cursor
			f32 distance = direction.Normalize();
			if (distance > 1.0f)
			{
				assassin.grapple_vel = direction * assassin_grapple_throw_speed;
			}
			else
			{
				assassin.grapple_vel = Vec2f_zero;
			}

			SyncGrapple(this);
		}
	}

	if (assassin.grappling)
	{
		//update grapple
		//TODO move to its own script?

		if (!this.isKeyPressed(key_action2))
		{
			if (canSend(this) || isServer())
			{
				assassin.grappling = false;
				SyncGrapple(this);
			}
		}
		else
		{
			const f32 assassin_grapple_range = assassin_grapple_length * assassin.grapple_ratio;
			const f32 assassin_grapple_force_limit = this.getMass() * assassin_grapple_accel_limit;

			CMap@ map = this.getMap();

			//reel in
			//TODO: sound
			if (assassin.grapple_ratio > 0.2f)
				assassin.grapple_ratio -= 1.0f / getTicksASecond();

			//get the force and offset vectors
			Vec2f force;
			Vec2f offset;
			f32 dist;
			{
				force = assassin.grapple_pos - this.getPosition();
				dist = force.Normalize();
				f32 offdist = dist - assassin_grapple_range;
				if (offdist > 0)
				{
					offset = force * Maths::Min(8.0f, offdist * assassin_grapple_stiffness);
					force *= Maths::Min(assassin_grapple_force_limit, Maths::Max(0.0f, offdist + assassin_grapple_slack) * assassin_grapple_force);
				}
				else
				{
					force.Set(0, 0);
				}
			}

			//left map? too long? close grapple
			if (assassin.grapple_pos.x < 0 ||
			        assassin.grapple_pos.x > (map.tilemapwidth)*map.tilesize ||
			        dist > assassin_grapple_length * 3.0f)
			{
				if (canSend(this) || isServer())
				{
					assassin.grappling = false;
					SyncGrapple(this);
				}
			}
			else if (assassin.grapple_id == 0xffff) //not stuck
			{
				const f32 drag = map.isInWater(assassin.grapple_pos) ? 0.7f : 0.90f;
				const Vec2f gravity(0, 1);

				assassin.grapple_vel = (assassin.grapple_vel * drag) + gravity - (force * (2 / this.getMass()));

				Vec2f next = assassin.grapple_pos + assassin.grapple_vel;
				next -= offset;

				Vec2f dir = next - assassin.grapple_pos;
				f32 delta = dir.Normalize();
				bool found = false;
				const f32 step = map.tilesize * 0.5f;
				while (delta > 0 && !found) //fake raycast
				{
					if (delta > step)
					{
						assassin.grapple_pos += dir * step;
					}
					else
					{
						assassin.grapple_pos = next;
					}
					delta -= step;
					found = checkGrappleStep(this, assassin, map, dist);
				}

			}
			else //stuck -> pull towards pos
			{

				//wallrun/jump reset to make getting over things easier
				//at the top of grapple
				if (this.isOnWall()) //on wall
				{
					//close to the grapple point
					//not too far above
					//and moving downwards
					Vec2f dif = pos - assassin.grapple_pos;
					if (this.getVelocity().y > 0 &&
					        dif.y > -10.0f &&
					        dif.Length() < 24.0f)
					{
						//need move vars
						RunnerMoveVars@ moveVars;
						if (this.get("moveVars", @moveVars))
						{
							moveVars.walljumped_side = Walljump::NONE;
						}
					}
				}

				CBlob@ b = null;
				if (assassin.grapple_id != 0)
				{
					@b = getBlobByNetworkID(assassin.grapple_id);
					if (b is null)
					{
						assassin.grapple_id = 0;
					}
				}

				if (b !is null)
				{
					assassin.grapple_pos = b.getPosition();
					if (b.isKeyJustPressed(key_action1) ||
					        b.isKeyJustPressed(key_action2) ||
					        this.isKeyPressed(key_use))
					{
						if (canSend(this) || isServer())
						{
							assassin.grappling = false;
							SyncGrapple(this);
						}
					}
				}
				else if (shouldReleaseGrapple(this, assassin, map))
				{
					if (canSend(this) || isServer())
					{
						assassin.grappling = false;
						SyncGrapple(this);
					}
				}

				this.AddForce(force);
				Vec2f target = (this.getPosition() + offset);
				if (!map.rayCastSolid(this.getPosition(), target) &&
					(this.getVelocity().Length() > 2 || !this.isOnMap()))
				{
					this.setPosition(target);
				}

				if (b !is null)
					b.AddForce(-force * (b.getMass() / this.getMass()));

			}
		}

	}
}

void onTick(CBlob@ this)
{
	AssassinInfo@ assassin;
	if (!this.get("assassinInfo", @assassin))
	{
		return;
	}

	if (isKnocked(this) || this.isInInventory())
	{
		assassin.grappling = false;
		this.getSprite().SetEmitSoundPaused(true);
		return;
	}

	ManageGrapple(this, assassin);
	
	// like builder's pickaxe
	if (assassin.stab_timer >= delay_between_hit)
	{
		assassin.stab_timer = 0;
	}

	if (this.isKeyPressed(key_action1) || assassin.stab_timer > 0)
	{
		assassin.stab_timer++;

		RunnerMoveVars@ moveVars;
		if (this.get("moveVars", @moveVars))
		{
			moveVars.walkFactor = 0.5f;
			moveVars.jumpFactor = 0.5f;
		}
		this.Tag("prevent crouch");
	}

	if(this.isMyPlayer())
	{
		// description
		/*
		if (u_showtutorial && !this.hasTag("spoke description"))
		{
			this.maxChatBubbleLines = 255;
			this.Chat("Quick stabbing!\n\n[LMB] to stab, has long stun\n[RMB] to grapple\n[SPACE] to use smoke ball and stun nearby enemies, buy at knight shop");
			this.set_u8("emote", Emotes::off);
			this.set_u32("emotetime", getGameTime() + 300);
			this.Tag("spoke description");
		}
		*/

		// void ManageKnife(CBlob@ this)
		if (assassin.stab_timer == 3)
		{
			this.SendCommand(this.getCommandID("knife"));
		}

		//void SmokeBall(CBlob@ this)
		// space

		if (this.isKeyJustPressed(key_action3))
		{
			client_SendThrowOrActivateCommandSmoke(this);
		}
	}
}

void client_SendThrowOrActivateCommandSmoke(CBlob@ this)
{
    if (this.isMyPlayer())
    {
        CBitStream params;
        this.SendCommand(this.getCommandID("smokeball"), params);
    }
}

bool checkGrappleBarrier(Vec2f pos)
{
	CRules@ rules = getRules();
	if (!shouldBarrier(@rules)) { return false; }

	Vec2f tl, br;
	getBarrierRect(@rules, tl, br);

	return (pos.x > tl.x && pos.x < br.x);
}


bool checkGrappleStep(CBlob@ this, AssassinInfo@ assassin, CMap@ map, const f32 dist)
{
	if (checkGrappleBarrier(assassin.grapple_pos)) // red barrier
	{
		if (canSend(this) || isServer())
		{
			assassin.grappling = false;
			SyncGrapple(this);
		}
	}
	else if (grappleHitMap(assassin, map, dist))
	{
		assassin.grapple_id = 0;

		assassin.grapple_ratio = Maths::Max(0.2, Maths::Min(assassin.grapple_ratio, dist / assassin_grapple_length));

		assassin.grapple_pos.y = Maths::Max(0.0, assassin.grapple_pos.y);

		if (canSend(this) || isServer()) SyncGrapple(this);

		return true;
	}
	else
	{
		CBlob@ b = map.getBlobAtPosition(assassin.grapple_pos);
		if (b !is null)
		{
			if (b is this)
			{
				//can't grapple self if not reeled in
				if (assassin.grapple_ratio > 0.5f)
					return false;

				if (canSend(this) || isServer())
				{
					assassin.grappling = false;
					SyncGrapple(this);
				}

				return true;
			}
			else if (b.isCollidable() && b.getShape().isStatic() && !b.hasTag("ignore_arrow"))
			{
				//TODO: Maybe figure out a way to grapple moving blobs
				//		without massive desync + forces :)

				assassin.grapple_ratio = Maths::Max(0.2, Maths::Min(assassin.grapple_ratio, b.getDistanceTo(this) / assassin_grapple_length));

				assassin.grapple_id = b.getNetworkID();
				if (canSend(this) || isServer())
				{
					SyncGrapple(this);
				}

				return true;
			}
		}
	}

	return false;
}

bool grappleHitMap(AssassinInfo@ assassin, CMap@ map, const f32 dist = 16.0f)
{
	return  map.isTileSolid(assassin.grapple_pos + Vec2f(0, -3)) ||			//fake quad
	        map.isTileSolid(assassin.grapple_pos + Vec2f(3, 0)) ||
	        map.isTileSolid(assassin.grapple_pos + Vec2f(-3, 0)) ||
	        map.isTileSolid(assassin.grapple_pos + Vec2f(0, 3)) ||
	        (dist > 10.0f && map.getSectorAtPosition(assassin.grapple_pos, "tree") !is null);   //tree stick
}

bool shouldReleaseGrapple(CBlob@ this, AssassinInfo@ assassin, CMap@ map)
{
	return !grappleHitMap(assassin, map) || this.isKeyPressed(key_use);
}

bool canSend(CBlob@ this)
{
	return (this.isMyPlayer() || this.getPlayer() is null || this.getPlayer().isBot());
}
void onCommand(CBlob@ this, u8 cmd, CBitStream @params)
{
	if (cmd == this.getCommandID(grapple_sync_cmd) && isClient())
	{
		HandleGrapple(this, params, !canSend(this));
	}
	else if (cmd == this.getCommandID("smokeball") && isServer())
	{
		Vec2f pos = this.getVelocity();
		Vec2f vector = this.getAimPos() - this.getPosition();
		Vec2f vel = this.getVelocity();

		CBlob @carried = this.getCarriedBlob();

		if (carried !is null)
		{
			if (carried.getName() == "smokeball")
			{
				carried.server_Die();
			}
			else
			{
				ActivateBlob(this, carried, pos, vector, vel);
			}
		}
		else if (hasItem(this, "mat_smokeball"))
		{
			CBlob @blob = server_CreateBlob("smokeball", this.getTeamNum(), this.getPosition());
			if (blob !is null)
			{
				TakeItem(this, "mat_smokeball");
				this.server_Pickup(blob);
			}
		}
		else // search in inv, from ActivateHeldObject.as
		{
			CInventory@ inv = this.getInventory();
			for (int i = 0; i < inv.getItemsCount(); i++)
			{
				CBlob @blob = inv.getItem(i);
				if (ActivateBlob(this, blob, pos, vector, vel))
					return;
			}
		}
	}
	else if (cmd == this.getCommandID("knife") && isServer())
	{
		AssassinInfo@ assassin;
		if (!this.get("assassinInfo", @assassin))
		{
			return;
		}

		Vec2f blobPos = this.getPosition();
		Vec2f vel = this.getVelocity();
		Vec2f vec;
		this.getAimDirection(vec);
		Vec2f thinghy(1, 0);
		f32 aimangle = -(vec.Angle());
		if (aimangle < 0.0f)
		{
			aimangle += 360.0f;
		}
		thinghy.RotateBy(aimangle);
		vel.Normalize();
		Vec2f pos = blobPos - thinghy * 6.0f + vel + Vec2f(0, -2);

		f32 radius = this.getRadius();
		CMap@ map = this.getMap();
		//get the actual aim angle
		f32 exact_aimangle = (this.getAimPos() - blobPos).Angle();
		bool notAddTimer = true;

		CBlob@ secondBestHittable;// player is first
		uint id = 0;
		bool foundSecondBest = false;
		bool foundMine = false;
		bool dontHitMoreMap = false;
		bool hitBest = false;


		// this gathers HitInfo objects which contain blob or tile hit information
		HitInfo@[] hitInfos;
		if (map.getHitInfosFromArc(pos, aimangle, 90.0f, radius + 12.0f, this, @hitInfos))
		{
			//HitInfo objects are sorted, first come closest hits
			// start from furthest ones to avoid doing too many redundant raycasts
			for (int i = hitInfos.size() - 1; i >= 0; i--)
			{
				HitInfo@ hi = hitInfos[i];
				CBlob@ b = hi.blob;
				if (b !is null && (!hitBest))
				{
					if (b.hasTag("ignore sword") 
					    || !canHit(this, b)) 
					{
						continue;
					}

					Vec2f hitvec = hi.hitpos - pos;

					// we do a raycast to given blob and hit everything hittable between knight and that blob
					// raycast is stopped if it runs into a "large" blob (typically a door)
					// raycast length is slightly higher than hitvec to make sure it reaches the blob it's directed at
					HitInfo@[] rayInfos;
					map.getHitInfosFromRay(pos, -(hitvec).getAngleDegrees(), hitvec.Length() + 2.0f, this, rayInfos);

					for (int j = 0; j < rayInfos.size(); j++)
					{
						CBlob@ rayb = rayInfos[j].blob;
						
						if (rayb is null) break; // means we ran into a tile, don't need blobs after it if there are any
						if (rayb.hasTag("ignore sword") || !canHit(this, rayb)) continue;

						bool large = (rayb.hasTag("blocks sword") || (rayb.hasTag("barricade") && rayb.getTeamNum() != this.getTeamNum())// added here
									 && !rayb.isAttached() && rayb.isCollidable()); // usually doors, but can also be boats/some mechanisms

						if (rayb.getTeamNum() != this.getTeamNum() || rayb.hasTag("dead player"))
						{
							if (rayb.hasTag("player") && !rayb.hasTag("dead"))// it is best hittable, not need to compare
							{
								Vec2f velocity = rayb.getPosition() - pos;
								// lesser knock back
								this.server_Hit(rayb, hi.hitpos, velocity, rayb.hasTag("flesh") ? 1.0f : 0.5f, Hitters::stab, true);  // server_Hit() is server-side only
								hitBest = true;
								break;
							}
							// second best hittable, mine and traps are more important
							else if (((!foundMine) &&  rayb.getName() == "mine" && !rayb.hasScript("StoneStructureHit.as")) || rayb.getName() == "beartrap")// found better hittable
							{
								@secondBestHittable = rayb;
								id = i;
								foundMine = true;
								foundSecondBest = true;//also dont need to find other thing
							}
							// actually third...
							// e.g. catapults, shark... also chicken gets true
							else if ((!foundSecondBest) && (rayb.hasTag("vehicle") || (rayb.hasTag("flesh") && !rayb.hasTag("dead"))) && !rayb.hasScript("StoneStructureHit.as"))// found better hittable
							{
								@secondBestHittable = rayb;
								id = i;
								foundSecondBest = true;
							}
							else if (secondBestHittable is null && !rayb.hasScript("StoneStructureHit.as"))// is not exist
							{
								@secondBestHittable = rayb;
								id = i;
							}
							
						}
						
						if (large)
						{
							break; // don't raycast past the door after we do damage to it
						}
					}
				}
				else if (!dontHitMoreMap) // hitmap
				{
					bool ground = map.isTileGround(hi.tile);
					bool dirt_stone = map.isTileStone(hi.tile);
					bool dirt_thick_stone = map.isTileThickStone(hi.tile);
					bool gold = map.isTileGold(hi.tile);
					bool wood = map.isTileWood(hi.tile);
					if (ground || wood || dirt_stone || gold)
					{
						Vec2f tpos = map.getTileWorldPosition(hi.tileOffset) + Vec2f(4, 4);
						Vec2f offset = (tpos - blobPos);
						f32 tileangle = offset.Angle();
						f32 dif = Maths::Abs(exact_aimangle - tileangle);
						if (dif > 180)
							dif -= 360;
						if (dif < -180)
							dif += 360;

						dif = Maths::Abs(dif);
						//print("dif: "+dif);

						if (dif < 20.0f)
						{
							//detect corner

							int check_x = -(offset.x > 0 ? -1 : 1);
							int check_y = -(offset.y > 0 ? -1 : 1);
							if (map.isTileSolid(hi.hitpos - Vec2f(map.tilesize * check_x, 0)) &&
									map.isTileSolid(hi.hitpos - Vec2f(0, map.tilesize * check_y)))
								continue;

							bool canhit = true;
							if(notAddTimer)
							{
								assassin.tileDestructionLimiter++;
								notAddTimer = false;
							}
							canhit = ((assassin.tileDestructionLimiter % ((wood || dirt_stone) ? 5 : 3)) == 0);

							//dont dig through no build zones
							canhit = canhit && map.getSectorAtPosition(tpos, "no build") is null;
							
							dontHitMoreMap = true;
							if (canhit)
							{
								map.server_DestroyTile(hi.hitpos, 0.1f, this);
								assassin.tileDestructionLimiter = 0;// reset
								if (gold)
								{
									// Note: 0.1f damage doesn't harvest anything I guess
									// This puts it in inventory - include MaterialCommon
									//Material::fromTile(this, hi.tile, 1.f);

									CBlob@ ore = server_CreateBlobNoInit("mat_gold");
									if (ore !is null)
									{
										ore.Tag('custom quantity');
		     							ore.Init();
	     								ore.setPosition(hi.hitpos);
		     							ore.server_SetQuantity(4);
		     						}
								}
								else if (dirt_stone)
								{
									int quantity = 4;
									if(dirt_thick_stone)
									{
										quantity = 6;
									}
									CBlob@ ore = server_CreateBlobNoInit("mat_stone");
									if (ore !is null)
									{
										ore.Tag('custom quantity');
										ore.Init();
										ore.setPosition(hi.hitpos);
										ore.server_SetQuantity(quantity);
									}
								}
							}
						}
					}
				}
			}
			if (secondBestHittable !is null && (!hitBest))// hit nothing but found second best
			{
				if (secondBestHittable.getName() == "log")
				{
					CBlob@ wood = server_CreateBlobNoInit("mat_wood");
					if (wood !is null)
					{
						int quantity = Maths::Ceil(0.5f * 20.0f);
						int max_quantity = secondBestHittable.getHealth() / 0.024f; // initial log health / max mats

						quantity = Maths::Max(
							Maths::Min(quantity, max_quantity),
							0
						);

						wood.Tag('custom quantity');
						wood.Init();
						wood.setPosition(hitInfos[id].hitpos);
						wood.server_SetQuantity(quantity);
					}

				}
				Vec2f velocity = secondBestHittable.getPosition() - pos;
				this.server_Hit(secondBestHittable, hitInfos[id].hitpos, velocity, secondBestHittable.hasTag("flesh") ? 1.0f : 0.5f, Hitters::stab, true);  // server_Hit() is server-side only
			}
		}
	}
}

void onHitBlob(CBlob@ this, Vec2f worldPoint, Vec2f velocity, f32 damage, CBlob@ hitBlob, u8 customData)
{
	if (customData == Hitters::stab)
	{
		if (damage > 0.0f && hitBlob.hasTag("flesh"))
		{
			this.getSprite().PlaySound("KnifeStab.ogg");
			if (isKnockable(hitBlob)) setKnocked(hitBlob, 20, true);
		}

		if (blockAttack(hitBlob, velocity, 0.0f))
		{
			this.getSprite().PlaySound("/Stun", 1.0f, this.getSexNum() == 0 ? 1.0f : 1.5f);
			setKnocked(this, 10, true);
		}
	}
}

// as same as knight
// Blame Fuzzle.
bool canHit(CBlob@ this, CBlob@ b)
{
	if (b.hasTag("invincible") || b.hasTag("temp blob"))
		return false;
	
	// don't hit picked up items (except players and specially tagged items)
	return b.hasTag("player") || b.hasTag("slash_while_in_hand") || !isBlobBeingCarried(b);
}

bool isBlobBeingCarried(CBlob@ b)
{	
	CAttachment@ att = b.getAttachments();
	if (att is null)
	{
		return false;
	}

	// Look for a "PICKUP" attachment point where socket=false and occupied=true
	return att.getAttachmentPoint("PICKUP", false, true) !is null;
}

//ball management

bool hasItem(CBlob@ this, const string &in name)
{
	CBitStream reqs, missing;
	AddRequirement(reqs, "blob", name, "Smoke Balls", 1);
	CInventory@ inv = this.getInventory();

	if (inv !is null)
	{
		return hasRequirements(inv, reqs, missing);
	}
	else
	{
		warn("our inventory was null! AssassinLogic.as");
	}

	return false;
}

void TakeItem(CBlob@ this, const string &in name)
{
	CBlob@ carried = this.getCarriedBlob();
	if (carried !is null)
	{
		if (carried.getName() == name)
		{
			carried.server_Die();
			return;
		}
	}

	CBitStream reqs, missing;
	AddRequirement(reqs, "blob", name, "Smoke Balls", 1);
	CInventory@ inv = this.getInventory();

	if (inv !is null)
	{
		if (hasRequirements(inv, reqs, missing))
		{
			server_TakeRequirements(inv, reqs);
		}
		else
		{
			warn("took a ball even though we dont have one! AssassinLogic.as");
		}
	}
	else
	{
		warn("our inventory was null! AssassinLogic.as");
	}
}

void onAddToInventory(CBlob@ this, CBlob@ blob)
{
	if (blob.getName() == "mat_smokeball")
		SetHelp(this, "help inventory", "assassin", "$mat_smokeball$ Activate/Smoke around $KEY_SPACE$", "", 255);
}

void onAttach(CBlob@ this, CBlob@ attached, AttachmentPoint @attachedPoint)
{
	AssassinInfo@ assassin;
	if (!this.get("assassinInfo", @assassin))
	{
		return;
	}

	if (this.isAttached() && (canSend(this) || isServer()))
	{
		assassin.grappling = false;
		SyncGrapple(this);
	}
}
