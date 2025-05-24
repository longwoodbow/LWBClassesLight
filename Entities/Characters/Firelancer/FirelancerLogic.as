// Firelancer logic

#include "FirelancerCommon.as"
#include "ActivationThrowCommon.as"
#include "KnockedCommon.as"
#include "Hitters.as"
#include "RunnerCommon.as"
#include "ShieldCommon.as";
#include "BombCommon.as";
#include "StandardControlsCommon.as";

const int FLETCH_COOLDOWN = 45;
const int PICKUP_COOLDOWN = 15;
const int fletch_num_lances = 1;
const int STAB_DELAY = 12;
const int STAB_TIME = 20;

void onInit(CBlob@ this)
{
	FirelancerInfo firelancer;
	this.set("firelancerInfo", @firelancer);

	this.set_s8("charge_time", 0);
	this.set_u8("charge_state", FirelancerParams::not_aiming);
	this.set_bool("has_lance", false);
	this.set_f32("gib health", -1.5f);
	this.Tag("player");
	this.Tag("flesh");

	ControlsSwitch@ controls_switch = @onSwitch;
	this.set("onSwitch handle", @controls_switch);

	ControlsCycle@ controls_cycle = @onCycle;
	this.set("onCycle handle", @controls_cycle);

	//centered on lances
	//this.set_Vec2f("inventory offset", Vec2f(0.0f, 122.0f));
	//centered on items
	this.set_Vec2f("inventory offset", Vec2f(0.0f, 0.0f));

	//no spinning
	this.getShape().SetRotationsAllowed(false);
	this.getSprite().SetEmitSound("/Sparkle.ogg");
	this.addCommandID("play fire sound");
	this.addCommandID("sync ignite");
	this.addCommandID("sync ignite client");
	this.addCommandID("request shoot");
	this.addCommandID("lance sync");
	this.addCommandID("lance sync client");
	this.addCommandID("stick attack");
	this.getShape().getConsts().net_threshold_multiplier = 0.5f;

	AddIconToken("$Firelance$", "Entities/Characters/Firelancer/FirelancerIcons.png", Vec2f(16, 32), 0, this.getTeamNum());
	AddIconToken("$Flamethrower$", "Entities/Characters/Firelancer/FirelancerIcons.png", Vec2f(16, 32), 1, this.getTeamNum());

	//add a command ID for each lance type
	for (uint i = 0; i < lanceTypeNames.length; i++)
	{
		this.addCommandID("pick " + lanceTypeNames[i]);
	}

	this.getCurrentScript().runFlags |= Script::tick_not_attached;
	this.getCurrentScript().removeIfTag = "dead";
}

void onSetPlayer(CBlob@ this, CPlayer@ player)
{
	if (player !is null)
	{
		player.SetScoreboardVars("LWBScoreboardIcons.png", 10, Vec2f(16, 16));
	}
}

void ManageLance(CBlob@ this, FirelancerInfo@ firelancer, RunnerMoveVars@ moveVars)
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
	bool haslance = firelancer.has_lance;
	bool hasnormal = hasLances(this, LanceType::normal);
	s8 charge_time = firelancer.charge_time;
	u8 charge_state = firelancer.charge_state;
	const bool pressed_action2 = this.isKeyPressed(key_action2);
	Vec2f pos = this.getPosition();

	if (responsible)
	{
		haslance = hasLances(this);

		if (!haslance && hasnormal)
		{
			// set back to default
			firelancer.lance_type = LanceType::normal;
			ClientSendLanceState(this);
			haslance = hasnormal;

			if (ismyplayer)
			{
				Sound::Play("/CycleInventory.ogg");
			}
		}

		if (haslance != this.get_bool("has_lance"))
		{
			this.set_bool("has_lance", haslance);
			this.Sync("has_lance", isServer());
		}
	}

	if (charge_state == FirelancerParams::ignited) // fast lances
	{
		if (!haslance)
		{
			charge_state = FirelancerParams::not_aiming;
			charge_time = 0;
		}
		else
		{
			charge_state = FirelancerParams::firing;
			this.set_s32("shoot time", getGameTime() + FirelancerParams::shoot_period);
			if (isServer()) this.SendCommand(this.getCommandID("sync ignite"));
		}
	}
	//charged - no else (we want to check the very same tick)
	if (charge_state == FirelancerParams::firing) // based legolas system
	{
		moveVars.walkFactor *= 0.5f;

		if(charge_time < FirelancerParams::ignite_period + FirelancerParams::shoot_period) charge_time++;//for cursor
		if(!haslance || this.get_s32("shoot time") <= getGameTime())//lance lost or shoot time passed
		{
			if (this.get_s32("shoot time") == getGameTime())//just time
				ClientFire(this);

			bool pressed = this.isKeyPressed(key_action1);
			charge_state = pressed ? FirelancerParams::igniting : FirelancerParams::not_aiming;
			charge_time = 0;

			//mute fuse sound
			sprite.RewindEmitSound();
			sprite.SetEmitSoundPaused(true);
		}

	}
	else if (this.isKeyPressed(key_action1))
	{
		moveVars.walkFactor *= 0.5f;
		moveVars.canVault = false;

		bool just_action1 = this.isKeyJustPressed(key_action1);

		//	printf("charge_state " + charge_state );
		if (haslance && charge_state == FirelancerParams::no_lances)
		{
			// (when key_action1 is down) reset charge state when:
			// * the player has picks up arrows when inventory is empty
			// * the player switches arrow type while charging bow
			charge_state = FirelancerParams::not_aiming;
			just_action1 = true;
		}

		if ((just_action1 || this.wasKeyPressed(key_action2) && !pressed_action2) &&
		        charge_state == FirelancerParams::not_aiming)
		{
			charge_state = FirelancerParams::igniting;
			haslance = hasLances(this);

			if (!haslance && hasnormal)
			{
				firelancer.lance_type = LanceType::normal;
				ClientSendLanceState(this);
				haslance = hasnormal;

				if (ismyplayer)
				{
					Sound::Play("/CycleInventory.ogg");
				}
			}

			if (responsible)
			{
				this.set_bool("has_lance", haslance);
				this.Sync("has_lance", isServer());
			}

			charge_time = 0;

			if (!haslance)
			{
				charge_state = FirelancerParams::no_lances;

				if (ismyplayer && !this.wasKeyPressed(key_action1))   // playing annoying no ammo sound
				{
					this.getSprite().PlaySound("Entities/Characters/Sounds/NoAmmo.ogg", 0.5);
				}

			}
			else
			{
				if (ismyplayer)
				{
					if (just_action1)
					{
						sprite.PlaySound("SparkleShort.ogg");// fire arrow sound
					}
				}

				sprite.RewindEmitSound();
				sprite.SetEmitSoundPaused(true);

				if (!ismyplayer)   // lower the volume of other players charging  - ooo good idea
				{
					sprite.SetEmitSoundVolume(0.5f);
				}
			}
		}
		else if (charge_state == FirelancerParams::igniting)
		{
			if(!haslance)
			{
				charge_state = FirelancerParams::no_lances;
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

			if (charge_time >= FirelancerParams::ignite_period)
			{
				// ignited, readying to shoot

				sprite.RewindEmitSound();
				sprite.SetEmitSoundPaused(false);
				charge_state = FirelancerParams::ignited;
			}
		}
		else if (charge_state == FirelancerParams::no_lances)
		{
			if (charge_time < FirelancerParams::ready_time)
			{
				charge_time++;
			}
		}
	}
	else
	{
		charge_state = FirelancerParams::not_aiming;
		charge_time = 0;
	}

	// my player!

	if (responsible)
	{
		// set cursor

		if (ismyplayer && !getHUD().hasButtons())
		{
			int frame = 0;
			// print("firelancer.charge_time " + firelancer.charge_time + " / " + FirelancerParams::shoot_period );
			if (firelancer.charge_state == FirelancerParams::igniting)
			{
				//readying shot
				frame = 0 + int((float(firelancer.charge_time) / float(FirelancerParams::ignite_period + 1)) * 18);
			}
			else if (firelancer.charge_state == FirelancerParams::firing || firelancer.charge_state == FirelancerParams::ignited)
			{
				//charging legolas
				frame = 18 + int((float(firelancer.charge_time - FirelancerParams::ignite_period) / float(FirelancerParams::shoot_period)) * 16);
			}
			getHUD().SetCursorFrame(frame);
		}

		// activate/throw

		if (this.isKeyJustPressed(key_action3))
		{
			client_SendThrowOrActivateCommand(this);
		}
	}

	firelancer.charge_time = charge_time;
	firelancer.charge_state = charge_state;
	firelancer.has_lance = haslance;

}

void onTick(CBlob@ this)
{
	FirelancerInfo@ firelancer;
	if (!this.get("firelancerInfo", @firelancer))
	{
		return;
	}

	if ((isKnocked(this) || this.isInInventory()) && firelancer.charge_state != FirelancerParams::firing)
	{
		firelancer.charge_state = 0;
		firelancer.charge_time = 0;
		this.getSprite().SetEmitSoundPaused(true);
		getHUD().SetCursorFrame(0);
		return;
	}

	// stick
	if(this.isKeyPressed(key_action2)
		&& firelancer.charge_state != FirelancerParams::ignited
		&& firelancer.charge_state != FirelancerParams::firing
		&& !this.isKeyPressed(key_action1))
	{
		firelancer.charge_state = FirelancerParams::stick;
	}

	CSprite@ sprite = this.getSprite();

	if (this.isKeyPressed(key_action2) && firelancer.charge_state != FirelancerParams::stick)
	{
		// cancel charging
		if (firelancer.charge_state != FirelancerParams::not_aiming &&
		    firelancer.charge_state != FirelancerParams::ignited &&
		    firelancer.charge_state != FirelancerParams::firing)// no cancel for ignited firelance
		{
			firelancer.charge_state = FirelancerParams::not_aiming;
			firelancer.charge_time = 0;
			sprite.SetEmitSoundPaused(true);
			sprite.PlaySound("PopIn.ogg");
		}
	}

	//print("state before: " + firelancer.charge_state);

	RunnerMoveVars@ moveVars;
	if (!this.get("moveVars", @moveVars))
	{
		return;
	}

	if (firelancer.charge_state == FirelancerParams::stick)
	{
		firelancer.stick_timer++;

		moveVars.jumpFactor *= 0.6f;
		moveVars.walkFactor *= 0.6f;

		if (firelancer.stick_timer == 6)// like builder's pickaxe
		{
			Sound::Play("/SwordSlash", this.getPosition());
			if (canSend(this))
			{
				this.SendCommand(this.getCommandID("stick attack"));
			}
		}
		if (firelancer.stick_timer >= 25)
		{
			firelancer.charge_state = this.isKeyPressed(key_action2) ? FirelancerParams::stick : this.isKeyPressed(key_action1) ? FirelancerParams::igniting : FirelancerParams::not_aiming;
			firelancer.stick_timer = 0;
		}
		return;
	}

	ManageLance(this, firelancer, moveVars);

	//print("state after: " + firelancer.charge_state);
}

bool canSend(CBlob@ this)
{
	return (this.isMyPlayer() || this.getPlayer() is null || this.getPlayer().isBot());
}

void ClientFire(CBlob@ this)
{
	//time to fire!
	if (canSend(this))  // client-logic
	{
		this.SendCommand(this.getCommandID("request shoot"));
	}
}

CBlob@ CreateFrag(CBlob@ this, Vec2f lancePos, Vec2f lanceVel, u8 lanceType)
{
	CBlob@ frag = server_CreateBlobNoInit(lanceShootBlob[lanceType]);
	if (frag !is null)
	{
		// fire lance?
		frag.set_u8("lance type", lanceType);
		frag.SetDamageOwnerPlayer(this.getPlayer());
		frag.Init();

		frag.IgnoreCollisionWhileOverlapped(this);
		frag.server_setTeamNum(this.getTeamNum());
		frag.setPosition(lancePos);
		frag.setVelocity(lanceVel * lanceShootVelocity[lanceType]);
	}
	return frag;
}

// clientside
void onCycle(CBitStream@ params)
{
	u16 this_id;
	if (!params.saferead_u16(this_id)) return;

	CBlob@ this = getBlobByNetworkID(this_id);
	if (this is null) return;

	if (lanceTypeNames.length == 0) return;

	// cycle lances
	FirelancerInfo@ firelancer;
	if (!this.get("firelancerInfo", @firelancer))
	{
		return;
	}
	u8 type = firelancer.lance_type;

	int count = 0;
	while (count < lanceTypeNames.length)
	{
		type++;
		count++;
		if (type >= lanceTypeNames.length)
		{
			type = 0;
		}
		if (hasLances(this, type))
		{
			CycleToLanceType(this, firelancer, type);
			break;
		}
	}
}

void onSwitch(CBitStream@ params)
{
	u16 this_id;
	if (!params.saferead_u16(this_id)) return;

	CBlob@ this = getBlobByNetworkID(this_id);
	if (this is null) return;

	if (lanceTypeNames.length == 0) return;

	u8 type;
	if (!params.saferead_u8(type)) return;

	FirelancerInfo@ firelancer;
	if (!this.get("firelancerInfo", @firelancer))
	{
		return;
	}

	if (hasLances(this, type))
	{
		CycleToLanceType(this, firelancer, type);
	}
}

void ShootLance(CBlob@ this)
{
	FirelancerInfo@ firelancer;
	if (!this.get("firelancerInfo", @firelancer))
	{
		return;
	}

	u8 lance_type = firelancer.lance_type;

	if (lance_type >= lanceTypeNames.length) return;

	if (!hasLances(this, lance_type)) return; 

	Vec2f offset(this.isFacingLeft() ? 2 : -2, -2);

	Vec2f fragPos = this.getPosition() + offset;
	Vec2f aimpos = this.getAimPos();
	Vec2f fragVel = (aimpos - fragPos);
	fragVel.Normalize();
	fragVel *= lanceShootVelocity[lance_type];

	int r = 0;
	for (int i = 0; i < lanceShootVolley[lance_type]; i++)
	{
		CBlob@ frag = CreateFrag(this, fragPos, fragVel, lance_type);

		r = r > 0 ? -(r + 1) : (-r) + 1;

		fragVel = fragVel.RotateBy(lanceShootDeviation[lance_type] * r, Vec2f());
	}

	this.TakeBlob(lanceTypeNames[ lance_type ], 1);

	fragVel.Normalize();
	Vec2f knockback_vel = -fragVel * this.getMass() * 4.0f;
	this.AddForce(knockback_vel);

	CBitStream params;
	params.write_Vec2f(knockback_vel);
	this.SendCommand(this.getCommandID("play fire sound"), params);
}

void onSendCreateData(CBlob@ this, CBitStream@ params)
{
	FirelancerInfo@ firelancer;
	if (!this.get("firelancerInfo", @firelancer)) { return; }

	params.write_u8(firelancer.lance_type);
}

bool onReceiveCreateData(CBlob@ this, CBitStream@ params)
{
	return ReceiveLanceState(this, params);
}

void onCommand(CBlob@ this, u8 cmd, CBitStream @params)
{
	if (cmd == this.getCommandID("play fire sound") && isClient())
	{
		this.getSprite().PlaySound("Bomb.ogg");

		if (isServer()) return;
		Vec2f knockback_vel;
		if (params is null) return;
		if (!params.saferead_Vec2f(knockback_vel)) return;

		this.AddForce(knockback_vel);
	}
	else if (cmd == this.getCommandID("request shoot") && isServer())
	{
		FirelancerInfo@ firelancer;
		if (!this.get("firelancerInfo", @firelancer)) { return; }

		ShootLance(this);
	}
	else if (cmd == this.getCommandID("lance sync") && isServer())
	{
		ReceiveLanceState(this, params);
	}
	else if (cmd == this.getCommandID("lance sync client") && isClient())
	{
		ReceiveLanceState(this, params);
	}
	else if (cmd == this.getCommandID("sync ignite") && isServer())
	{
		FirelancerInfo@ firelancer;
		if (!this.get("firelancerInfo", @firelancer))
		{
			return;
		}
		if (firelancer.charge_state != FirelancerParams::firing)// sync shoot state
		{
			firelancer.charge_state = FirelancerParams::firing;
			firelancer.charge_time = FirelancerParams::ignite_period;
			this.set_s32("shoot time", getGameTime() + FirelancerParams::shoot_period);
			this.getSprite().SetEmitSoundPaused(false);
		}

		this.SendCommand(this.getCommandID("sync ignite client"));
	}
	else if (cmd == this.getCommandID("sync ignite client") && isClient())
	{
		FirelancerInfo@ firelancer;
		if (!this.get("firelancerInfo", @firelancer))
		{
			return;
		}
		if (firelancer.charge_state != FirelancerParams::firing)// sync shoot state
		{
			firelancer.charge_state = FirelancerParams::firing;
			firelancer.charge_time = FirelancerParams::ignite_period;
			this.set_s32("shoot time", getGameTime() + FirelancerParams::shoot_period);
			this.getSprite().SetEmitSoundPaused(false);
		}
	}
	else if (cmd == this.getCommandID("stick attack") && isServer())
	{
		FirelancerInfo@ firelancer;
		if (!this.get("firelancerInfo", @firelancer))
		{
			return;
		}
		DoAttack(this, firelancer);
	}
	else if (isServer())
	{
		FirelancerInfo@ firelancer;
		if (!this.get("firelancerInfo", @firelancer))
		{
			return;
		}
		for (uint i = 0; i < lanceTypeNames.length; i++)
		{
			if (cmd == this.getCommandID("pick " + lanceTypeNames[i]))
			{
				CBitStream params;
				params.write_u8(i);
				firelancer.lance_type = i;
				this.SendCommand(this.getCommandID("lance sync client"), params);
				break;
			}
		}
	}
}

void CycleToLanceType(CBlob@ this, FirelancerInfo@ firelancer, u8 lanceType)
{
	firelancer.lance_type = lanceType;
	if (this.isMyPlayer())
	{
		Sound::Play("/CycleInventory.ogg");
	}
	ClientSendLanceState(this);
}

void DoAttack(CBlob@ this, FirelancerInfo@ info)
{
	if (!getNet().isServer())
	{
		return;
	}

	Vec2f vec;
	this.getAimDirection(vec);
	f32 aimangle = -(vec.Angle());

	if (aimangle < 0.0f)
	{
		aimangle += 360.0f;
	}

	Vec2f blobPos = this.getPosition();
	Vec2f vel = this.getVelocity();
	Vec2f thinghy(1, 0);
	thinghy.RotateBy(aimangle);
	Vec2f pos = blobPos - thinghy * 6.0f + vel + Vec2f(0, -2);
	vel.Normalize();

	f32 attack_distance = Maths::Min(16.0f + Maths::Max(0.0f, 1.75f * this.getShape().vellen * (vel * thinghy)), 18.0f);

	f32 radius = this.getRadius();
	CMap@ map = this.getMap();
	bool dontHitMore = false;
	bool dontHitMoreMap = false;
	bool dontHitMoreLogs = false;

	//get the actual aim angle
	f32 exact_aimangle = (this.getAimPos() - blobPos).Angle();

	// this gathers HitInfo objects which contain blob or tile hit information
	HitInfo@[] hitInfos;
	if (map.getHitInfosFromArc(pos, aimangle, 120.0f, radius + attack_distance, this, @hitInfos))
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

					f32 temp_damage = 0.25f;
					
					if (rayb.getName() == "log")
					{
						if (!dontHitMoreLogs)
						{
							temp_damage /= 3;
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
						this.server_Hit(rayb, rayInfos[j].hitpos, velocity, temp_damage, Hitters::shield, true);
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
					//bool wood = map.isTileWood(hi.tile);
					if (ground || dirt_stone || gold)
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

							bool canhit = true; //default true if not jab
							info.tileDestructionLimiter++;
							canhit = ((info.tileDestructionLimiter % (dirt_stone ? 3 : 2)) == 0);

							//dont dig through no build zones
							canhit = canhit && map.getSectorAtPosition(tpos, "no build") is null;

							dontHitMoreMap = true;
							if (canhit)
							{
								map.server_DestroyTile(hi.hitpos, 0.1f, this);
								info.tileDestructionLimiter = 0;
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
	}

	// destroy grass

	if (aimangle >= 0.0f && aimangle <= 180.0f)    // aiming down or slash
	{
		f32 tilesize = map.tilesize;
		int steps = Maths::Ceil(2 * radius / tilesize);
		int sign = this.isFacingLeft() ? -1 : 1;

		for (int y = 0; y < steps; y++)
			for (int x = 0; x < steps; x++)
			{
				Vec2f tilepos = blobPos + Vec2f(x * tilesize * sign, y * tilesize);
				TileType tile = map.getTile(tilepos).type;

				if (map.isTileGrass(tile))
				{
					map.server_DestroyTile(tilepos, 0.25, this);
					return;
				}
			}
	}
}

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

void Callback_PickLance(CBitStream@ params)
{
	CPlayer@ player = getLocalPlayer();
	if (player is null) return;

	CBlob@ blob = player.getBlob();
	if (blob is null) return;

	u8 lance_id;
	if (!params.saferead_u8(lance_id)) return;

	FirelancerInfo@ firelancer;
	if (!blob.get("firelancerInfo", @firelancer))
	{
		return;
	}

	firelancer.lance_type = lance_id;

	string matname = lanceTypeNames[lance_id];
	blob.SendCommand(blob.getCommandID("pick " + matname));
}

// lance pick menu
void onCreateInventoryMenu(CBlob@ this, CBlob@ forBlob, CGridMenu @gridmenu)
{
	if (lanceTypeNames.length == 0)
	{
		return;
	}

	this.ClearGridMenusExceptInventory();
	Vec2f pos(gridmenu.getUpperLeftPosition().x + 0.5f * (gridmenu.getLowerRightPosition().x - gridmenu.getUpperLeftPosition().x),
	          gridmenu.getUpperLeftPosition().y - 32 * 1 - 2 * 24);
	CGridMenu@ menu = CreateGridMenu(pos, this, Vec2f(lanceTypeNames.length, 2), getTranslatedString("Current lance"));

	FirelancerInfo@ firelancer;
	if (!this.get("firelancerInfo", @firelancer))
	{
		return;
	}
	const u8 lanceSel = firelancer.lance_type;

	if (menu !is null)
	{
		menu.deleteAfterClick = false;

		for (uint i = 0; i < lanceTypeNames.length; i++)
		{
			CBitStream params;
			params.write_u8(i);
			CGridButton @button = menu.AddButton(lanceIcons[i], lanceNames[i], "FirelancerLogic.as", "Callback_PickLance", params);

			if (button !is null)
			{
				bool enabled = hasLances(this, i);
				button.SetEnabled(enabled);
				button.selectOneOnClick = true;

				//if (enabled && i == LanceType::fire && !hasReqs(this, i))
				//{
				//	button.hoverText = "Requires a fire source $lantern$";
				//	//button.SetEnabled( false );
				//}

				if (lanceSel == i)
				{
					button.SetSelected(1);
				}
			}
		}
	}
}

// auto-switch to appropriate lance when picked up
void onAddToInventory(CBlob@ this, CBlob@ blob)
{
	string itemname = blob.getName();

	CInventory@ inv = this.getInventory();
	if (inv.getItemsCount() == 0)
	{
		FirelancerInfo@ firelancer;
		if (!this.get("firelancerInfo", @firelancer))
		{
			return;
		}

		for (uint i = 0; i < lanceTypeNames.length; i++)
		{
			if (itemname == lanceTypeNames[i])
			{
				firelancer.lance_type = i;
			}
		}
	}
}

void onHitBlob(CBlob@ this, Vec2f worldPoint, Vec2f velocity, f32 damage, CBlob@ hitBlob, u8 customData)
{
	if (customData == Hitters::shield)
	{
		if (blockAttack(hitBlob, velocity, 0.0f) && isKnockable(hitBlob))
		{
			this.getSprite().PlaySound("/Stun", 1.0f, this.getSexNum() == 0 ? 1.0f : 1.5f);
			setKnocked(hitBlob, 10, true);
		}
	}
}

void onAttach( CBlob@ this, CBlob@ attached, AttachmentPoint @attachedPoint )//cancel fuse sound
{
	this.getSprite().SetEmitSoundPaused(true);
}
void onDetach( CBlob@ this, CBlob@ detached, AttachmentPoint@ attachedPoint )//replay fuse sound
{
	FirelancerInfo@ firelancer;
	if (!this.get("firelancerInfo", @firelancer))
	{
		return;
	}

	if (firelancer.charge_state == FirelancerParams::firing)
	{
		this.getSprite().SetEmitSoundPaused(false);
	}
}