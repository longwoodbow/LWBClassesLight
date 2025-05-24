// Musketman logic

#include "BuilderCommon.as";
#include "MusketmanCommon.as"
#include "ActivationThrowCommon.as"
#include "KnockedCommon.as"
#include "Hitters.as"
#include "RunnerCommon.as"
#include "ShieldCommon.as";
#include "Requirements.as"
#include "PlacementCommon.as";

void onInit(CBlob@ this)
{
	MusketmanInfo musketman;
	this.set("musketmanInfo", @musketman);

	this.set_bool("has_bullet", false);
	this.set_f32("gib health", -1.5f);
	this.Tag("player");
	this.Tag("flesh");

	//centered on bullets
	//this.set_Vec2f("inventory offset", Vec2f(0.0f, 122.0f));
	//centered on items
	this.set_Vec2f("inventory offset", Vec2f(0.0f, 0.0f));

	//no spinning
	this.getShape().SetRotationsAllowed(false);
	this.getSprite().SetEmitSound("musketman_bow_pull.ogg");
	this.addCommandID("play fire sound");
	this.addCommandID("request shoot");
	this.getShape().getConsts().net_threshold_multiplier = 0.5f;

	//add a command ID for each bullet type

	this.getCurrentScript().runFlags |= Script::tick_not_attached;
	this.getCurrentScript().removeIfTag = "dead";
}

void onSetPlayer(CBlob@ this, CPlayer@ player)
{
	if (player !is null)
	{
		player.SetScoreboardVars("LWBScoreboardIcons.png", 3, Vec2f(16, 16));
	}
}

void ManageBow(CBlob@ this, MusketmanInfo@ musketman, RunnerMoveVars@ moveVars)
{
	//are we responsible for this actor?
	bool ismyplayer = this.isMyPlayer();
	bool responsible = ismyplayer;
	if (isServer() && !ismyplayer)
	{
		CPlayer@ p = this.getPlayer();
		if (p !is null)
		{
			responsible = p.isBot();
		}
	}
	//
	CSprite@ sprite = this.getSprite();
	bool hasbullet = musketman.has_bullet;
	s8 charge_time = musketman.charge_time;
	u8 charge_state = musketman.charge_state;
	const bool pressed_action2 = this.isKeyPressed(key_action2);
	Vec2f pos = this.getPosition();
	bool isNotBuilding = !isBuildTime(this);

	// cancel charging
	if (this.isKeyJustPressed(key_action2) && charge_state != MusketmanParams::not_aiming && charge_state != MusketmanParams::digging)
	{
		charge_state = MusketmanParams::not_aiming;
		musketman.charge_time = 0;
		sprite.SetEmitSoundPaused(true);
		sprite.PlaySound("PopIn.ogg");
	}

	if (responsible)
	{
		hasbullet = hasBullets(this);

		if (hasbullet != this.get_bool("has_bullet"))
		{
			this.set_bool("has_bullet", hasbullet);
			this.Sync("has_bullet", isServer());
		}
	}

	if (charge_state == MusketmanParams::digging)
	{
		moveVars.walkFactor *= 0.5f;
		moveVars.jumpFactor *= 0.5f;
		moveVars.canVault = false;
		musketman.dig_delay--;
		if(musketman.dig_delay == 0)
		{
			charge_state = MusketmanParams::not_aiming;
			if(this.isKeyPressed(key_action1))
			{
				charge_state = MusketmanParams::readying;
				hasbullet = hasBullets(this);

				if (responsible)
				{
					this.set_bool("has_bullet", hasbullet);
					this.Sync("has_bullet", isServer());
				}

				charge_time = 0;

				if (!hasbullet)
				{
					charge_state = MusketmanParams::no_bullets;

					if (ismyplayer)   // playing annoying no ammo sound
					{
						this.getSprite().PlaySound("Entities/Characters/Sounds/NoAmmo.ogg", 0.5);
					}

				}
				else
				{
					sprite.PlaySound("musketman_arrow_draw_end.ogg");
					sprite.RewindEmitSound();
					sprite.SetEmitSoundPaused(false);

					if (!ismyplayer)   // lower the volume of other players charging  - ooo good idea
					{
						sprite.SetEmitSoundVolume(0.5f);
					}
				}
			}
		}
	}
	else if (this.isKeyPressed(key_action1) && isNotBuilding)
	{
		moveVars.walkFactor *= 0.5f;
		moveVars.jumpFactor *= 0.5f;
		moveVars.canVault = false;

		bool just_action1 = this.isKeyJustPressed(key_action1);

		//	printf("charge_state " + charge_state );
		if (hasbullet && charge_state == MusketmanParams::no_bullets)
		{
			// (when key_action1 is down) reset charge state when:
			// * the player has picks up arrows when inventory is empty
			// * the player switches arrow type while charging bow
			charge_state = MusketmanParams::not_aiming;
			just_action1 = true;
		}

		if ((just_action1 || this.wasKeyPressed(key_action2) && !pressed_action2) &&
		        charge_state == MusketmanParams::not_aiming)
		{
			charge_state = MusketmanParams::readying;
			hasbullet = hasBullets(this);

			if (responsible)
			{
				this.set_bool("has_bullet", hasbullet);
				this.Sync("has_bullet", isServer());
			}

			charge_time = 0;

			if (!hasbullet)
			{
				charge_state = MusketmanParams::no_bullets;

				if (ismyplayer && !this.wasKeyPressed(key_action1))   // playing annoying no ammo sound
				{
					this.getSprite().PlaySound("Entities/Characters/Sounds/NoAmmo.ogg", 0.5);
				}

			}
			else
			{
				sprite.PlaySound("musketman_arrow_draw_end.ogg");
				sprite.RewindEmitSound();
				sprite.SetEmitSoundPaused(false);

				if (!ismyplayer)   // lower the volume of other players charging  - ooo good idea
				{
					sprite.SetEmitSoundVolume(0.5f);
				}
			}
		}
		else if (charge_state == MusketmanParams::readying)
		{

			if(!hasbullet)
			{
				charge_state = MusketmanParams::no_bullets;
				charge_time = 0;
				
				if (ismyplayer)   // playing annoying no ammo sound
				{
					this.getSprite().PlaySound("Entities/Characters/Sounds/NoAmmo.ogg", 0.5);
				}
			}
			else
			{
				charge_time++;
			}

			if (charge_time >= MusketmanParams::shoot_period)
			{
				//sprite.PlaySound("musketman_charged.ogg");
				charge_state = MusketmanParams::charging;
				sprite.SetEmitSoundPaused(true);
			}
		}
		else if (charge_state == MusketmanParams::charging)
		{
			if(!hasbullet)
			{
				charge_state = MusketmanParams::no_bullets;
				charge_time = 0;
				
				if (ismyplayer)   // playing annoying no ammo sound
				{
					this.getSprite().PlaySound("Entities/Characters/Sounds/NoAmmo.ogg", 0.5);
				}
			}
			else
			{
				charge_time++;
			}

			if (charge_time >= MusketmanParams::shoot_period + MusketmanParams::charge_limit)
			{
				charge_state = MusketmanParams::discharging;
				charge_time = MusketmanParams::shoot_period;
			}
		}
		else if (charge_state == MusketmanParams::discharging)
		{
			if(!hasbullet)
			{
				charge_state = MusketmanParams::no_bullets;
				charge_time = 0;
				
				if (ismyplayer)   // playing annoying no ammo sound
				{
					this.getSprite().PlaySound("Entities/Characters/Sounds/NoAmmo.ogg", 0.5);
				}
			}
			else if (charge_time >= 0)
			{
				charge_time--;
				if (charge_time > 0)//twice
				{
					charge_time--;
				}
				if (charge_time <= 0)
				{
					charge_state = MusketmanParams::readying;
					sprite.RewindEmitSound();
					sprite.SetEmitSoundPaused(false);

					if (!ismyplayer)   // lower the volume of other players charging  - ooo good idea
					{
						sprite.SetEmitSoundVolume(0.5f);
					}
				}
			}
		}
		else if (charge_state == MusketmanParams::no_bullets)
		{
			if (charge_time < MusketmanParams::ready_time) charge_time++;

		}
	}
	else
	{
		if (charge_state == MusketmanParams::charging || charge_state == MusketmanParams::discharging)
		{
			ClientFire(this, charge_time, charge_state);
		}
		charge_state = MusketmanParams::not_aiming;    //set to not aiming either way
		charge_time = 0;

		sprite.SetEmitSoundPaused(true);
		if(pressed_action2)
		{
			charge_state = MusketmanParams::digging;
			musketman.dig_delay = 25;
			DoDig(this);
		}
	}

	// my player!

	if (responsible)
	{
		// set cursor

		if (ismyplayer && !getHUD().hasButtons())
		{
			int frame = 0;
			//	print("musketman.charge_time " + musketman.charge_time + " / " + MusketmanParams::shoot_period );
			if (musketman.charge_state == MusketmanParams::readying || musketman.charge_state == MusketmanParams::discharging)
			{
				//charging shot
				frame = 0 + int((float(musketman.charge_time) / float(MusketmanParams::shoot_period + 1) * 18));
			}
			else if (musketman.charge_state == MusketmanParams::charging)
			{
				//charging legolas
				frame = 18;// + int((float(musketman.charge_time - MusketmanParams::shoot_period) / MusketmanParams::charge_limit) * 9) * 2;
			}
			getHUD().SetCursorFrame(frame);
		}

		// activate/throw

		if (this.isKeyJustPressed(key_action3))
		{
			client_SendThrowOrActivateCommand(this);
		}
	}

	musketman.charge_time = charge_time;
	musketman.charge_state = charge_state;
	musketman.has_bullet = hasbullet;

}

void onTick(CBlob@ this)
{
	MusketmanInfo@ musketman;
	if (!this.get("musketmanInfo", @musketman))
	{
		return;
	}

	if (isKnocked(this) || this.isInInventory())
	{
		musketman.charge_state = 0;
		musketman.charge_time = 0;
		this.getSprite().SetEmitSoundPaused(true);
		getHUD().SetCursorFrame(0);
		return;
	}

	RunnerMoveVars@ moveVars;
	if (!this.get("moveVars", @moveVars))
	{
		return;
	}

	ManageBow(this, musketman, moveVars);

	if(this.isMyPlayer() && this.getCarriedBlob() is null &&  getBuildMode(this) == MusketmanBuilding::barricade && this.isKeyJustPressed(key_action1))// reload barricade
		this.SendCommand(this.getCommandID("barricade"));
}

void DoDig(CBlob@ this)
{

	if (!getNet().isServer())
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
	bool dontHitMore = false;
	bool dontHitMoreMap = false;
	bool dontHitMoreLogs = false;
	//get the actual aim angle
	f32 exact_aimangle = (this.getAimPos() - blobPos).Angle();
	
	// this gathers HitInfo objects which contain blob or tile hit information
	HitInfo@[] hitInfos;
	if (map.getHitInfosFromArc(pos, aimangle, 30.0f, radius + 16.0f, this, @hitInfos))
	{
		//HitInfo objects are sorted, first come closest hits
		// start from furthest ones to avoid doing too many redundant raycasts
		for (int i = hitInfos.size() - 1; i >= 0; i--)
		{
			HitInfo@ hi = hitInfos[i];
			CBlob@ b = hi.blob;

			if (b !is null)
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

					f32 temp_damage = 0.5f;
					
					if (rayb.getName() == "log")
					{
						if (!dontHitMoreLogs)
						{
							//temp_damage /= 3;
							dontHitMoreLogs = true; // set this here to prevent from hitting more logs on the same tick
							CBlob@ wood = server_CreateBlobNoInit("mat_wood");
							if (wood !is null)
							{
								int quantity = Maths::Ceil(float(temp_damage) * 20.0f);
								int max_quantity = rayb.getHealth() / 0.024f; // initial log health / max mats
								
								quantity = Maths::Max(
									Maths::Min(quantity, max_quantity),
									0
								);

								wood.Tag('custom quantity');
								wood.Init();
								wood.setPosition(rayInfos[j].hitpos);
								wood.server_SetQuantity(quantity);
							}
						}
						else 
						{
							// print("passed a log on " + getGameTime());
							continue; // don't hit the log
						}
					}

					
					Vec2f velocity = rayb.getPosition() - pos;
					velocity.Normalize();
					velocity *= 12; // knockback force is same regardless of distance

					if (rayb.getTeamNum() != this.getTeamNum() || rayb.hasTag("dead player"))
					{
						this.server_Hit(rayb, rayInfos[j].hitpos, velocity, temp_damage, Hitters::stab, true);
					}
					
					if (large)
					{
						break; // don't raycast past the door after we do damage to it
					}
				}
			}
			else  // hitmap
				if (!dontHitMoreMap)
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


							bool canhit = map.getSectorAtPosition(tpos, "no build") is null;

							dontHitMoreMap = true;

							if (canhit)
							{
								map.server_DestroyTile(hi.hitpos, 0.1f, this);
								if (ground) map.server_DestroyTile(hi.hitpos, 0.1f, this);
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
	     								ore.setPosition(pos);
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
	}
}

bool canSend(CBlob@ this)
{
	return (this.isMyPlayer() || this.getPlayer() is null || this.getPlayer().isBot());
}

void ClientFire(CBlob@ this, s8 charge_time, u8 charge_state)
{
	//time to fire!
	if (canSend(this))  // client-logic
	{
		CBitStream params;
		params.write_s8(charge_time);
		params.write_u8(charge_state);

		this.SendCommand(this.getCommandID("request shoot"), params);
	}
}

CBlob@ CreateBullet(CBlob@ this, Vec2f bulletPos, Vec2f bulletVel)
{
	CBlob@ bullet = server_CreateBlobNoInit("bullet");
	if (bullet !is null)
	{
		bullet.SetDamageOwnerPlayer(this.getPlayer());
		bullet.Init();

		bullet.IgnoreCollisionWhileOverlapped(this);
		bullet.server_setTeamNum(this.getTeamNum());
		Vec2f bulletOffset = bulletVel;
		bulletOffset.Normalize();
		bullet.setPosition(bulletPos + bulletOffset * 4);
		bullet.setVelocity(bulletVel);
	}
	return bullet;
}

void ShootBullet(CBlob@ this)
{
	MusketmanInfo@ musketman;
	if (!this.get("musketmanInfo", @musketman))
	{
		return;
	}

	if (!hasBullets(this)) return; 
	
	s8 charge_time = musketman.charge_time;
	u8 charge_state = musketman.charge_state;

	f32 bulletspeed = MusketmanParams::shoot_max_vel;

	Vec2f offset(this.isFacingLeft() ? 2 : -2, -2);

	Vec2f bulletPos = this.getPosition() + offset;
	Vec2f aimpos = this.getAimPos();
	Vec2f bulletVel = (aimpos - bulletPos);
	bulletVel.Normalize();
	bulletVel *= bulletspeed;

	f32 randomInn = 0.0f;
	if(charge_state == MusketmanParams::discharging)
	{
		randomInn = -3.0f + (( f32(XORRandom(2048)) / 2048.0f) * 6.0f);
	}

	bulletVel.RotateBy(randomInn,Vec2f(0,0));

	CreateBullet(this, bulletPos, bulletVel);

	this.SendCommand(this.getCommandID("play fire sound"));
	this.TakeBlob("mat_bullets", 1);

}

void onCommand(CBlob@ this, u8 cmd, CBitStream @params)
{
	if (cmd == this.getCommandID("play fire sound") && isClient())
	{
		this.getSprite().PlaySound("M16Fire.ogg");
	}
	else if (cmd == this.getCommandID("request shoot") && isServer())
	{
		s8 charge_time;
		if (!params.saferead_u8(charge_time)) { return; }

		u8 charge_state;
		if (!params.saferead_u8(charge_state)) { return; }

		MusketmanInfo@ musketman;
		if (!this.get("musketmanInfo", @musketman)) { return; }

		musketman.charge_time = charge_time;
		musketman.charge_state = charge_state;

		ShootBullet(this);
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

void onDetach(CBlob@ this, CBlob@ detached, AttachmentPoint@ attachedPoint)
{
	// ignore collision for built blob
	BuildBlock[][]@ blocks;
	if (!this.get("blocks", @blocks))
	{
		return;
	}

	for (u8 i = 0; i < blocks[0].length; i++)
	{
		BuildBlock@ block = blocks[0][i];
		if (block !is null && block.name == detached.getName())
		{
			this.IgnoreCollisionWhileOverlapped(null);
			detached.IgnoreCollisionWhileOverlapped(null);
		}
	}

	// BUILD BLOB
	// take requirements from blob that is built and play sound
	// put out another one of the same
	if (detached.hasTag("temp blob"))
	{
		detached.Untag("temp blob");
		
		if (!detached.hasTag("temp blob placed"))
		{
			detached.server_Die();
			return;
		}

		uint i = this.get_u8("buildblob");
		if (i >= 0 && i < blocks[0].length)
		{
			BuildBlock@ b = blocks[0][i];
			if (b.name == detached.getName())
			{
				this.set_u8("buildblob", 255);

				CInventory@ inv = this.getInventory();

				CBitStream missing;
				if (hasRequirements(inv, b.reqs, missing, not b.buildOnGround))
				{
					server_TakeRequirements(inv, b.reqs);
				}
				// take out another one if in inventory
				server_BuildBlob(this, blocks[0], i);
			}
		}
	}
	else if (detached.getName() == "seed")
	{
		if (not detached.hasTag('temp blob placed')) return;

		CBlob@ anotherBlob = this.getInventory().getItem(detached.getName());
		if (anotherBlob !is null)
		{
			this.server_Pickup(anotherBlob);
		}
	}
}