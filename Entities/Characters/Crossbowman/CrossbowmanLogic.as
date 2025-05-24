// Knight logic

#include "ActivationThrowCommon.as"
#include "CrossbowmanCommon.as";
#include "RunnerCommon.as";
#include "Hitters.as";
#include "ShieldCommon.as";
#include "KnockedCommon.as"
#include "StandardControlsCommon.as";


const int FLETCH_COOLDOWN = 45;
const int PICKUP_COOLDOWN = 15;
const int fletch_num_arrows = 1;

// code for the following is a bit stupid, TODO: make it normal
// x = WEAKSHOT_CHARGE
const int WEAKSHOT_CHARGE = 11; // 12 (x+1) in reality
const int MIDSHOT_CHARGE = 13; // 24 (x+13) in reality
const int FULLSHOT_CHARGE = 25; // 36 (x+25) in reality
const int TRIPLESHOT_CHARGE = 119; // 130 (x+119) in reality 

//attacks limited to the one time per-actor before reset.

void crossbowman_actorlimit_setup(CBlob@ this)
{
	u16[] networkIDs;
	this.set("LimitedActors", networkIDs);
}

bool crossbowman_has_hit_actor(CBlob@ this, CBlob@ actor)
{
	u16[]@ networkIDs;
	this.get("LimitedActors", @networkIDs);
	return networkIDs.find(actor.getNetworkID()) >= 0;
}

u32 crossbowman_hit_actor_count(CBlob@ this)
{
	u16[]@ networkIDs;
	this.get("LimitedActors", @networkIDs);
	return networkIDs.length;
}

void crossbowman_add_actor_limit(CBlob@ this, CBlob@ actor)
{
	this.push("LimitedActors", actor.getNetworkID());
}

void crossbowman_clear_actor_limits(CBlob@ this)
{
	this.clear("LimitedActors");
	this.Untag("fletched_this_attack");
}

void onInit(CBlob@ this)
{
	CrossbowmanInfo crossbowman;

	crossbowman.state = CrossbowmanVars::not_aiming;
	crossbowman.swordTimer = 0;
	crossbowman.tileDestructionLimiter = 0;

	this.set("crossbowmanInfo", @crossbowman);

	this.set_f32("gib health", -1.5f);
	crossbowman_actorlimit_setup(this);
	this.getShape().SetRotationsAllowed(false);
	this.getShape().getConsts().net_threshold_multiplier = 0.5f;
	this.Tag("player");
	this.Tag("flesh");

	ControlsSwitch@ controls_switch = @onSwitch;
	this.set("onSwitch handle", @controls_switch);

	ControlsCycle@ controls_cycle = @onCycle;
	this.set("onCycle handle", @controls_cycle);

	this.getSprite().SetEmitSound("Entities/Characters/Archer/BowPull.ogg");
	this.addCommandID("play fire sound");
	this.addCommandID("pickup arrow");
	this.addCommandID("pickup arrow client");
	this.addCommandID("request shoot");
	this.addCommandID("arrow sync");
	this.addCommandID("arrow sync client");
	this.addCommandID("make arrow");
	for (uint i = 0; i < arrowTypeNames.length; i++)
	{
		this.addCommandID("pick " + arrowTypeNames[i]);
	}

	//centered on bomb select
	//this.set_Vec2f("inventory offset", Vec2f(0.0f, 122.0f));
	//centered on inventory
	this.set_Vec2f("inventory offset", Vec2f(0.0f, 0.0f));
	//AddIconToken("$Help_Bayonet$", "LWBHelpIcons.png", Vec2f(16, 16), 10);
	//AddIconToken("$Help_Arrow3$", "LWBHelpIcons.png", Vec2f(8, 16), 22);

	this.getCurrentScript().runFlags |= Script::tick_not_attached;
	this.getCurrentScript().removeIfTag = "dead";
}

void onSetPlayer(CBlob@ this, CPlayer@ player)
{
	if (player !is null)
	{
		player.SetScoreboardVars("LWBScoreboardIcons.png", 2, Vec2f(16, 16));
	}
}

void onTick(CBlob@ this)
{
	bool knocked = isKnocked(this);
	CHUD@ hud = getHUD();

	//knight logic stuff
	//get the vars to turn various other scripts on/off
	RunnerMoveVars@ moveVars;
	if (!this.get("moveVars", @moveVars))
	{
		return;
	}

	CrossbowmanInfo@ crossbowman;
	if (!this.get("crossbowmanInfo", @crossbowman))
	{
		return;
	}

	if (this.isInInventory())
	{
		//prevent players from insta-slashing when exiting crates
		crossbowman.state = 0;
		crossbowman.swordTimer = 0;
		crossbowman.charge_time = 0;
		hud.SetCursorFrame(0);
		return;
	}

	Vec2f pos = this.getPosition();
	Vec2f vel = this.getVelocity();
	Vec2f aimpos = this.getAimPos();
	const bool inair = (!this.isOnGround() && !this.isOnLadder());

	Vec2f vec;

	const int direction = this.getAimDirection(vec);
	const f32 side = (this.isFacingLeft() ? 1.0f : -1.0f);
	bool swordState = isSwordState(crossbowman.state);
	bool pressed_a1 = this.isKeyPressed(key_action1);
	bool pressed_a2 = this.isKeyPressed(key_action2);
	bool walking = (this.isKeyPressed(key_left) || this.isKeyPressed(key_right));

	const bool myplayer = this.isMyPlayer();

	// cancel charging
	if (this.isKeyJustPressed(key_action2) && crossbowman.state != CrossbowmanVars::not_aiming && !swordState)
	{
		CSprite@ sprite = this.getSprite();
		crossbowman.state = CrossbowmanVars::not_aiming;
		crossbowman.charge_time = 0;
		sprite.SetEmitSoundPaused(true);
		sprite.PlaySound("PopIn.ogg");
	}

	if (knocked)
	{
		crossbowman.state = CrossbowmanVars::not_aiming; //cancel any attacks or shielding
		crossbowman.swordTimer = 0;
		crossbowman.charge_time = 0;
		this.getSprite().SetEmitSoundPaused(true);
		getHUD().SetCursorFrame(0);

		pressed_a1 = false;
		pressed_a2 = false;
		walking = false;

	}
	else
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
		bool hasarrow = crossbowman.has_arrow;
		bool hasnormal = hasArrows(this, ArrowType::normal);
		s8 charge_time = crossbowman.charge_time;
		u8 state = crossbowman.state;
		if (responsible)
		{
			hasarrow = hasArrows(this);

			if (!hasarrow && hasnormal)
			{
				// set back to default
				crossbowman.arrow_type = ArrowType::normal;
				ClientSendArrowState(this);
				hasarrow = hasnormal;

				if (ismyplayer)
				{
					Sound::Play("/CycleInventory.ogg");
				}
			}

			if (hasarrow != this.get_bool("has_arrow"))
			{
				this.set_bool("has_arrow", hasarrow);
				this.Sync("has_arrow", isServer());
			}
		}

		if (state == CrossbowmanVars::legolas_charging) // fast arrows
		{
			if (!hasarrow)
			{
				state = CrossbowmanVars::not_aiming;
				charge_time = 0;
			}
			else
			{
				state = CrossbowmanVars::legolas_ready;
			}
		}

		if (swordState)
		{
			if (moveVars.wallsliding)
			{
				state = CrossbowmanVars::not_aiming;
				crossbowman.swordTimer = 0;
			}
			else
			{
				this.Tag("prevent crouch");
	
				AttackMovement(this, crossbowman, moveVars);
				s32 delta = getSwordTimerDelta(crossbowman);
	
				if (delta == DELTA_BEGIN_ATTACK)
				{
					Sound::Play("/SwordSlash", this.getPosition());
				}
				else if (delta > DELTA_BEGIN_ATTACK && delta < DELTA_END_ATTACK)
				{
					f32 attackarc = 90.0f;
					f32 attackAngle = getCutAngle(this, crossbowman.state);
	
					if (state == CrossbowmanVars::sword_cut_down)
					{
						attackarc *= 0.9f;
					}
	
					DoAttack(this, 1.0f, attackAngle, attackarc, Hitters::sword, delta, crossbowman);
				}
				else if (delta >= 18)
				{
					state = CrossbowmanVars::not_aiming;
					if (pressed_a1)
					{
						moveVars.walkFactor *= 0.75f;
						moveVars.canVault = false;

						state = CrossbowmanVars::readying;
						hasarrow = hasArrows(this);

						if (!hasarrow && hasnormal)
						{
							crossbowman.arrow_type = ArrowType::normal;
							hasarrow = hasnormal;

						}

						if (responsible)
						{
							this.set_bool("has_arrow", hasarrow);
							this.Sync("has_arrow", isServer());
						}

						charge_time = 0;

						if (!hasarrow)
						{
							state = CrossbowmanVars::no_arrows;

							if (ismyplayer)   // playing annoying no ammo sound
							{
								this.getSprite().PlaySound("Entities/Characters/Sounds/NoAmmo.ogg", 0.5);
							}

						}
						else
						{
							if (ismyplayer)
							{
								if (pressed_a1)
								{
									const u8 type = crossbowman.arrow_type;

									if (type == ArrowType::fire)
									{
										sprite.PlaySound("SparkleShort.ogg");
									}
								}
							}

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
		}
		//charged - no else (we want to check the very same tick)
		else if (state == CrossbowmanVars::legolas_ready) // fast arrows
		{
			moveVars.walkFactor *= 0.75f;

			crossbowman.legolas_time--;
			if (!hasarrow || crossbowman.legolas_time == 0)
			{
				bool pressed = this.isKeyPressed(key_action1);
				state = pressed ? CrossbowmanVars::readying : CrossbowmanVars::not_aiming;
				charge_time = 0;
				//didn't fire
				if (crossbowman.legolas_arrows == CrossbowmanVars::legolas_arrows_count)
				{
					Sound::Play("/Stun", pos, 1.0f, this.getSexNum() == 0 ? 1.0f : 1.5f);
					setKnocked(this, 15);
				}
				else if (pressed)
				{
					sprite.RewindEmitSound();
					sprite.SetEmitSoundPaused(false);
				}
			}
			else if (this.isKeyJustPressed(key_action1) ||
			         (crossbowman.legolas_arrows == CrossbowmanVars::legolas_arrows_count &&
			          !pressed_a1 &&
			          this.wasKeyPressed(key_action1)))
			{
				ClientFire(this, charge_time, state);

				state = CrossbowmanVars::legolas_charging;
				charge_time = CrossbowmanVars::shoot_period - CrossbowmanVars::legolas_charge_time;
				Sound::Play("FastBowPull.ogg", pos);
				crossbowman.legolas_arrows--;

				if (crossbowman.legolas_arrows == 0)
				{
					state = CrossbowmanVars::readying;// it's readying, not not_aiming. old archer, too.
					charge_time = 5;

					sprite.RewindEmitSound();
					sprite.SetEmitSoundPaused(false);
				}
			}

		}
		else if (pressed_a1)
		{
			moveVars.walkFactor *= 0.75f;
			moveVars.canVault = false;

			bool just_action1 = this.isKeyJustPressed(key_action1);

			//	printf("charge_state " + state );
			if (hasarrow && state == CrossbowmanVars::no_arrows)
			{
				// (when key_action1 is down) reset charge state when:
				// * the player has picks up arrows when inventory is empty
				// * the player switches arrow type while charging bow
				state = CrossbowmanVars::not_aiming;
				just_action1 = true;
			}

			if ((just_action1 || this.wasKeyPressed(key_action2) && !pressed_a2) &&
			        (state == CrossbowmanVars::not_aiming || state == CrossbowmanVars::fired))
			{
				state = CrossbowmanVars::readying;
				hasarrow = hasArrows(this);

				if (!hasarrow && hasnormal)
				{
					crossbowman.arrow_type = ArrowType::normal;
					ClientSendArrowState(this);
					hasarrow = hasnormal;

					if (ismyplayer)
					{
						Sound::Play("/CycleInventory.ogg");
					}
				}

				if (responsible)
				{
					this.set_bool("has_arrow", hasarrow);
					this.Sync("has_arrow", isServer());
				}

				charge_time = 0;

				if (!hasarrow)
				{
					state = CrossbowmanVars::no_arrows;

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
							const u8 type = crossbowman.arrow_type;

							if (type == ArrowType::fire)
							{
								sprite.PlaySound("SparkleShort.ogg");
							}
						}
					}

					sprite.RewindEmitSound();
					sprite.SetEmitSoundPaused(false);

					if (!ismyplayer)   // lower the volume of other players charging  - ooo good idea
					{
						sprite.SetEmitSoundVolume(0.5f);
					}
				}
			}
			else if (state == CrossbowmanVars::readying)
			{
				charge_time++;

				if (charge_time > CrossbowmanVars::ready_time)
				{
					charge_time = 1;
					state = CrossbowmanVars::charging;
				}
			}
			else if (state == CrossbowmanVars::charging)
			{
				if(!hasarrow)
				{
					state = CrossbowmanVars::no_arrows;
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

				if (charge_time >= TRIPLESHOT_CHARGE)
				{
					// Legolas state

					Sound::Play("AnimeSword.ogg", pos, ismyplayer ? 1.3f : 0.7f);
					Sound::Play("FastBowPull.ogg", pos);
					state = CrossbowmanVars::legolas_charging;
					charge_time = CrossbowmanVars::shoot_period - CrossbowmanVars::legolas_charge_time;

					crossbowman.legolas_arrows = CrossbowmanVars::legolas_arrows_count;
					crossbowman.legolas_time = CrossbowmanVars::legolas_time;
				}

				if (charge_time >= CrossbowmanVars::shoot_period)
				{
					sprite.SetEmitSoundPaused(true);
				}
			}
			else if (state == CrossbowmanVars::no_arrows)
			{
				if (charge_time < CrossbowmanVars::ready_time)
				{
					charge_time++;
				}
			}
		}
		else
		{
			if (state > CrossbowmanVars::readying)
			{
				if (state < CrossbowmanVars::fired)
				{
					ClientFire(this, charge_time, state);
					charge_time = CrossbowmanVars::fired_time;
					state = CrossbowmanVars::fired;
				}
				else //fired..
				{
					charge_time--;

					if (charge_time <= 0)
					{
						state = CrossbowmanVars::not_aiming;
						charge_time = 0;
					}
				}
			}
			else
			{
				state = CrossbowmanVars::not_aiming;    //set to not aiming either way
				charge_time = 0;
			}

			sprite.SetEmitSoundPaused(true);
			if (pressed_a2 && !moveVars.wallsliding)
			{
				crossbowman_clear_actor_limits(this);
				crossbowman.swordTimer = 0;
				Vec2f vec;
				const int direction = this.getAimDirection(vec);

				if (direction == -1)
				{
					state = CrossbowmanVars::sword_cut_up;
				}
				else if (direction == 0)
				{
					Vec2f aimpos = this.getAimPos();
					Vec2f pos = this.getPosition();
					if (aimpos.y < pos.y)
					{
						state = CrossbowmanVars::sword_cut_mid;
					}
					else
					{
						state = CrossbowmanVars::sword_cut_mid_down;
					}
				}
				else
				{
					state = CrossbowmanVars::sword_cut_down;
				}
			}
		}

		// my player!

		if (responsible)
		{
			// set cursor
			if (ismyplayer && !getHUD().hasButtons())
			{
				int frame = 0;
				if (crossbowman.state != CrossbowmanVars::readying && crossbowman.state != CrossbowmanVars::charging && crossbowman.state != CrossbowmanVars::legolas_charging && crossbowman.state != CrossbowmanVars::legolas_ready)
				{
					frame = 0;
				}
				else if (crossbowman.state == CrossbowmanVars::readying) // Charging weak shot
				{
					frame = 0 + int(crossbowman.charge_time / 2);
				}
				else if (crossbowman.charge_time > 0 && crossbowman.state == CrossbowmanVars::charging)
				{
					if (crossbowman.charge_time >= 1 && crossbowman.charge_time <= 2) // Weakest shot charged (charge_time resets to 0 when that happens for some reason..)
					{
						frame = 6;
					}
					else if (crossbowman.state != CrossbowmanVars::legolas_ready && crossbowman.charge_time <= FULLSHOT_CHARGE) // Charging midshot & fullshot
					{
						frame = 6 + int((crossbowman.charge_time - 1) / 2);
					}
					else if (crossbowman.state != CrossbowmanVars::legolas_ready && crossbowman.charge_time > FULLSHOT_CHARGE) // Charging 3x
					{
						frame = 18 + int((crossbowman.charge_time - FULLSHOT_CHARGE) / 6);
					}
				}
				else // 3x charged
				{
					frame = 34;
				}
				getHUD().SetCursorFrame(frame);
			}

			// activate/throw

			if (this.isKeyJustPressed(key_action3))
			{
				client_SendThrowOrActivateCommand(this);
			}

			// pick up arrow

			if (crossbowman.fletch_cooldown > 0)
			{
				crossbowman.fletch_cooldown--;
			}

			// pickup from ground
			// from clientside right now, could probably move to a simple call and
			// pray that fletch_cooldown is synced correctly

			if (isClient() && crossbowman.fletch_cooldown == 0 && pressed_a2)
			{
				if (getPickupArrow(this) !is null)   // pickup arrow from ground
				{
					this.SendCommand(this.getCommandID("pickup arrow"));
					crossbowman.fletch_cooldown = PICKUP_COOLDOWN;
				}
			}
		}

		crossbowman.charge_time = charge_time;
		crossbowman.state = state;
		crossbowman.has_arrow = hasarrow;
	}

	if (!swordState && getNet().isServer())
	{
		crossbowman_clear_actor_limits(this);
	}

}

bool getInAir(CBlob@ this)
{
	bool inair = (!this.isOnGround() && !this.isOnLadder());
	return inair;

}

s32 getSwordTimerDelta(CrossbowmanInfo@ crossbowman)
{
	s32 delta = crossbowman.swordTimer;
	if (crossbowman.swordTimer < 128)
	{
		crossbowman.swordTimer++;
	}
	return delta;
}

void AttackMovement(CBlob@ this, CrossbowmanInfo@ crossbowman, RunnerMoveVars@ moveVars)
{
	Vec2f vel = this.getVelocity();

	moveVars.jumpFactor *= 0.8f;
	moveVars.walkFactor *= 0.9f;

	bool inair = getInAir(this);
	if (!inair)
	{
		this.AddForce(Vec2f(vel.x * -5.0, 0.0f));   //horizontal slowing force (prevents SANICS)
	}

	moveVars.canVault = false;
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

CBlob@ getPickupArrow(CBlob@ this)
{
	CBlob@[] blobsInRadius;
	if (this.getMap().getBlobsInRadius(this.getPosition(), this.getRadius() * 1.5f, @blobsInRadius))
	{
		for (uint i = 0; i < blobsInRadius.length; i++)
		{
			CBlob @b = blobsInRadius[i];
			if (b.getName() == "arrow")
			{
				return b;
			}
		}
	}
	return null;
}

bool canPickSpriteArrow(CBlob@ this, bool takeout)
{
	CBlob@[] blobsInRadius;
	if (this.getMap().getBlobsInRadius(this.getPosition(), this.getRadius() * 1.5f, @blobsInRadius))
	{
		for (uint i = 0; i < blobsInRadius.length; i++)
		{
			CBlob @b = blobsInRadius[i];
			{
				CSprite@ sprite = b.getSprite();
				if (sprite.getSpriteLayer("arrow") !is null)
				{
					if (takeout)
						sprite.RemoveSpriteLayer("arrow");
					return true;
				}
			}
		}
	}
	return false;
}

CBlob@ CreateArrow(CBlob@ this, Vec2f arrowPos, Vec2f arrowVel, u8 arrowType)
{
	CBlob@ arrow = server_CreateBlobNoInit("arrow");
	if (arrow !is null)
	{
		// fire arrow?
		arrow.set_u8("arrow type", getActualArrowNumber(arrowType));
		arrow.SetDamageOwnerPlayer(this.getPlayer());
		arrow.Init();

		arrow.IgnoreCollisionWhileOverlapped(this);
		arrow.server_setTeamNum(this.getTeamNum());
		arrow.setPosition(arrowPos);
		arrow.setVelocity(arrowVel);
	}
	return arrow;
}

// clientside
void onCycle(CBitStream@ params)
{
	u16 this_id;
	if (!params.saferead_u16(this_id)) return;

	CBlob@ this = getBlobByNetworkID(this_id);
	if (this is null) return;

	if (arrowTypeNames.length == 0) return;

	// cycle arrows
	CrossbowmanInfo@ crossbowman;
	if (!this.get("crossbowmanInfo", @crossbowman))
	{
		return;
	}
	u8 type = crossbowman.arrow_type;

	int count = 0;
	while (count < arrowTypeNames.length)
	{
		type++;
		count++;
		if (type >= arrowTypeNames.length)
		{
			type = 0;
		}
		if (hasArrows(this, type))
		{
			CycleToArrowType(this, crossbowman, type);
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

	if (arrowTypeNames.length == 0) return;

	u8 type;
	if (!params.saferead_u8(type)) return;

	CrossbowmanInfo@ crossbowman;
	if (!this.get("crossbowmanInfo", @crossbowman))
	{
		return;
	}

	if (hasArrows(this, type))
	{
		CycleToArrowType(this, crossbowman, type);
	}
}

void ShootArrow(CBlob@ this)
{
	CrossbowmanInfo@ crossbowman;
	if (!this.get("crossbowmanInfo", @crossbowman))
	{
		return;
	}

	u8 arrow_type = crossbowman.arrow_type;

	if (arrow_type >= arrowTypeNames.length) return;

	if (!hasArrows(this, arrow_type)) return; 
	
	s8 charge_time = crossbowman.charge_time;
	u8 charge_state = crossbowman.state;

	f32 arrowspeed;

	if (charge_time < MIDSHOT_CHARGE)
	{
		arrowspeed = CrossbowmanVars::shoot_max_vel * (1.0f / 3.0f);
	}
	else if (charge_time < FULLSHOT_CHARGE)
	{
		arrowspeed = CrossbowmanVars::shoot_max_vel * (4.0f / 5.0f);
	}
	else
	{
		arrowspeed = CrossbowmanVars::shoot_max_vel;
	}

	Vec2f offset(this.isFacingLeft() ? 2 : -2, -2);

	Vec2f arrowPos = this.getPosition() + offset;
	Vec2f aimpos = this.getAimPos();
	Vec2f arrowVel = (aimpos - arrowPos);
	arrowVel.Normalize();
	arrowVel *= arrowspeed;

	bool legolas = false;
	if (charge_state == CrossbowmanVars::legolas_ready) legolas = true;

	if (legolas)
	{
		f32 randomInn = -4.0f + (( f32(XORRandom(2048)) / 2048.0f) * 8.0f);
		arrowVel.RotateBy(randomInn,Vec2f(0,0));
	}

	CreateArrow(this, arrowPos, arrowVel, arrow_type);

	this.SendCommand(this.getCommandID("play fire sound"));
	this.TakeBlob(arrowTypeNames[ arrow_type ], 1);

	crossbowman.fletch_cooldown = FLETCH_COOLDOWN; // just don't allow shoot + make arrow
}

void onSendCreateData(CBlob@ this, CBitStream@ params)
{
	CrossbowmanInfo@ crossbowman;
	if (!this.get("crossbowmanInfo", @crossbowman)) { return; }

	params.write_u8(crossbowman.arrow_type);
}

bool onReceiveCreateData(CBlob@ this, CBitStream@ params)
{
	return ReceiveArrowState(this, params);
}

void onCommand(CBlob@ this, u8 cmd, CBitStream @params)
{
	if (cmd == this.getCommandID("play fire sound") && isClient())
	{
		this.getSprite().PlaySound("Entities/Characters/Archer/BowFire.ogg");
	}
	else if (cmd == this.getCommandID("request shoot") && isServer())
	{
		s8 charge_time;
		if (!params.saferead_u8(charge_time)) { return; }

		u8 charge_state;
		if (!params.saferead_u8(charge_state)) { return; }

		CrossbowmanInfo@ crossbowman;
		if (!this.get("crossbowmanInfo", @crossbowman)) { return; }

		crossbowman.charge_time = charge_time;
		crossbowman.state = charge_state;

		ShootArrow(this);
	}
	else if (cmd == this.getCommandID("arrow sync") && isServer())
	{
		ReceiveArrowState(this, params);
	}
	else if (cmd == this.getCommandID("arrow sync client") && isClient())
	{
		ReceiveArrowState(this, params);
	}
	else if (cmd == this.getCommandID("pickup arrow") && isServer())
	{
		// TODO: missing cooldown check
		CBlob@ arrow = getPickupArrow(this);
		// bool spriteArrow = canPickSpriteArrow(this, false); // unnecessary

		if (arrow !is null/* || spriteArrow*/)
		{
			if (arrow !is null)
			{
				CrossbowmanInfo@ crossbowman;
				if (!this.get("crossbowmanInfo", @crossbowman))
				{
					return;
				}
				const u8 arrowType = crossbowman.arrow_type;
			}

			CBlob@ mat_arrows = server_CreateBlobNoInit('mat_arrows');

			if (mat_arrows !is null)
			{
				mat_arrows.Tag('custom quantity');
				mat_arrows.Init();

				mat_arrows.server_SetQuantity(1); // unnecessary

				if (not this.server_PutInInventory(mat_arrows))
				{
					mat_arrows.setPosition(this.getPosition());
				}

				if (arrow !is null)
				{
					arrow.server_Die();
				}
				else
				{
					//canPickSpriteArrow(this, true);
				}
			}

			this.SendCommand(this.getCommandID("pickup arrow client"));
		}
	}
	else if (cmd == this.getCommandID("pickup arrow client") && isClient())
	{
		this.getSprite().PlaySound("Entities/Items/Projectiles/Sounds/ArrowHitGround.ogg");
	}
	else if (cmd == this.getCommandID("make arrow") && isClient())
	{
		this.getSprite().PlaySound("Entities/Items/Projectiles/Sounds/ArrowHitGround.ogg");
	}
	else
	{
		CrossbowmanInfo@ crossbowman;
		if (!this.get("crossbowmanInfo", @crossbowman))
		{
			return;
		}
		for (uint i = 0; i < arrowTypeNames.length; i++)
		{
			if (cmd == this.getCommandID("pick " + arrowTypeNames[i]))
			{
				CBitStream params;
				params.write_u8(i);
				crossbowman.arrow_type = i;
				this.SendCommand(this.getCommandID("arrow sync client"), params);
				break;
			}
		}
	}
}

/////////////////////////////////////////////////

bool isJab(f32 damage)
{
	return damage < 1.5f;
}

void DoAttack(CBlob@ this, f32 damage, f32 aimangle, f32 arcdegrees, u8 type, int deltaInt, CrossbowmanInfo@ info)
{
	if (!getNet().isServer())
	{
		return;
	}

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

	f32 attack_distance = Maths::Min(DEFAULT_ATTACK_DISTANCE + Maths::Max(0.0f, 1.75f * this.getShape().vellen * (vel * thinghy)), MAX_ATTACK_DISTANCE);

	f32 radius = this.getRadius();
	CMap@ map = this.getMap();
	bool dontHitMore = false;
	bool dontHitMoreMap = false;
	const bool jab = isJab(damage);
	bool dontHitMoreLogs = false;

	//get the actual aim angle
	f32 exact_aimangle = (this.getAimPos() - blobPos).Angle();

	// this gathers HitInfo objects which contain blob or tile hit information
	HitInfo@[] hitInfos;
	if (map.getHitInfosFromArc(pos, aimangle, arcdegrees, radius + attack_distance, this, @hitInfos))
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
				    || (!canHit(this, b) && b.getName() != "mat_wood")
				    || crossbowman_has_hit_actor(this, b)) 
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
					if (b.hasTag("ignore sword")) continue;
					if (!this.hasTag("fletched_this_attack") && rayb.getName() == "mat_wood")	// make arrow from wood
					{
						u16 quantity = rayb.getQuantity();
						if (quantity > 4)
						{
							rayb.server_SetQuantity(quantity-4);
						}
						else
						{
							rayb.server_Die();

						}
						makeMatArrow(this);
						dontHitMoreLogs = true;
						continue;
					}
					if (!canHit(this, rayb)) continue;

					bool large = (rayb.hasTag("blocks sword") || (rayb.hasTag("barricade") && rayb.getTeamNum() != this.getTeamNum())// added here
								 && !rayb.isAttached() && rayb.isCollidable()); // usually doors, but can also be boats/some mechanisms
								 
					if (crossbowman_has_hit_actor(this, rayb)) 
					{
						// check if we hit any of these on previous ticks of slash
						if (large) break;
						if (rayb.getName() == "log")
						{
							dontHitMoreLogs = true;
						}
						continue;
					}

					f32 temp_damage = damage;
					
					if (rayb.getName() == "log")
					{
						if (!dontHitMoreLogs)
						{
							dontHitMoreLogs = true; // set this here to prevent from hitting more logs on the same tick
							// little hack, don't hit any logs if fletching target is found
							if (this.hasTag("fletched_this_attack"))
							{
								continue;
							}
							temp_damage /= 3;
							// don"t make wood
						}
						else 
						{
							// print("passed a log on " + getGameTime());
							continue; // don't hit the log
						}
					}
					
					crossbowman_add_actor_limit(this, rayb);

					
					Vec2f velocity = rayb.getPosition() - pos;
					velocity.Normalize();
					velocity *= 12; // knockback force is same regardless of distance

					if (rayb.getTeamNum() != this.getTeamNum() || rayb.hasTag("dead player"))
					{
						this.server_Hit(rayb, rayInfos[j].hitpos, velocity, temp_damage, type, true);
						
						if (!this.hasTag("fletched_this_attack") && (rayb.hasTag("tree") || rayb.hasTag("wooden")))	// make arrow from tree
						{
							makeMatArrow(this);
						}
					}

					if (large)
					{
						break; // don't raycast past the door after we do damage to it
					}
				}
			}
			else  // hitmap
				if (!dontHitMoreMap && (deltaInt == DELTA_BEGIN_ATTACK + 1))
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

							bool canhit = true; //default true if not jab

							info.tileDestructionLimiter++;
							canhit = ((info.tileDestructionLimiter % ((wood || dirt_stone) ? 3 : 2)) == 0);

							dontHitMoreMap = true;
							if (wood && !this.hasTag("fletched_this_attack"))
							{
								makeMatArrow(this);
							}
							if (canhit)
							{
								map.server_DestroyTile(hi.hitpos, 0.1f, this);
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
								info.tileDestructionLimiter = 0;
							}
						}
					}
				}
		}
	}

	// destroy grass

	if (((aimangle >= 0.0f && aimangle <= 180.0f) || damage > 1.0f) &&    // aiming down or slash
	        (deltaInt == DELTA_BEGIN_ATTACK + 1)) // hit only once
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
					map.server_DestroyTile(tilepos, damage, this);

					if (damage <= 1.0f)
					{
						return;
					}
				}
			}
	}
}

void makeMatArrow(CBlob@ this)
{
	this.Tag("fletched_this_attack");

	CBlob@ arrow = server_CreateBlobNoInit("mat_arrows");
	if (arrow !is null)
	{
		arrow.Tag('custom quantity');
		arrow.Init();
		arrow.server_SetQuantity(1);
		if (not this.server_PutInInventory(arrow))
		{
			arrow.setPosition(this.getPosition());
		}
	}
	
	this.SendCommand(this.getCommandID("make arrow"));
}

void onHitBlob(CBlob@ this, Vec2f worldPoint, Vec2f velocity, f32 damage, CBlob@ hitBlob, u8 customData)
{
	CrossbowmanInfo@ crossbowman;
	if (!this.get("crossbowmanInfo", @crossbowman))
	{
		return;
	}

	if (customData == Hitters::sword)
	{
		if(( //is a jab - note we dont have the dmg in here at the moment :/
		    crossbowman.state == CrossbowmanVars::sword_cut_mid ||
		    crossbowman.state == CrossbowmanVars::sword_cut_mid_down ||
		    crossbowman.state == CrossbowmanVars::sword_cut_up ||
		    crossbowman.state == CrossbowmanVars::sword_cut_down
		    )
		    && blockAttack(hitBlob, velocity, 0.0f))
		{
			this.getSprite().PlaySound("/Stun", 1.0f, this.getSexNum() == 0 ? 1.0f : 1.5f);
			setKnocked(this, 15, true);
		}
	}
}

void CycleToArrowType(CBlob@ this, CrossbowmanInfo@ crossbowman, u8 arrowType)
{
	crossbowman.arrow_type = arrowType;
	if (this.isMyPlayer())
	{
		Sound::Play("/CycleInventory.ogg");
	}
	ClientSendArrowState(this);
}

void Callback_PickArrow(CBitStream@ params)
{
	CPlayer@ player = getLocalPlayer();
	if (player is null) return;

	CBlob@ blob = player.getBlob();
	if (blob is null) return;

	u8 arrow_id;
	if (!params.saferead_u8(arrow_id)) return;

	CrossbowmanInfo@ crossbowman;
	if (!blob.get("crossbowmanInfo", @crossbowman))
	{
		return;
	}

	crossbowman.arrow_type = arrow_id;

	string matname = arrowTypeNames[arrow_id];
	blob.SendCommand(blob.getCommandID("pick " + matname));
}

// arrow pick menu
void onCreateInventoryMenu(CBlob@ this, CBlob@ forBlob, CGridMenu @gridmenu)
{
	AddIconToken("$Arrow$", "Entities/Characters/Archer/ArcherIcons.png", Vec2f(16, 32), 0, this.getTeamNum());
	AddIconToken("$FireArrow$", "Entities/Characters/Archer/ArcherIcons.png", Vec2f(16, 32), 2, this.getTeamNum());
	AddIconToken("$PoisonArrow$", "Entities/Characters/Archer/ArcherIcons.png", Vec2f(16, 32), 4, this.getTeamNum());

	if (arrowTypeNames.length == 0)
	{
		return;
	}

	this.ClearGridMenusExceptInventory();
	Vec2f pos(gridmenu.getUpperLeftPosition().x + 0.5f * (gridmenu.getLowerRightPosition().x - gridmenu.getUpperLeftPosition().x),
	          gridmenu.getUpperLeftPosition().y - 32 * 1 - 2 * 24);
	CGridMenu@ menu = CreateGridMenu(pos, this, Vec2f(ArrowType::count, 2), getTranslatedString("Current arrow"));

	CrossbowmanInfo@ crossbowman;
	if (!this.get("crossbowmanInfo", @crossbowman))
	{
		return;
	}
	const u8 arrowSel = crossbowman.arrow_type;

	if (menu !is null)
	{
		menu.deleteAfterClick = false;

		for (uint i = 0; i < arrowTypeNames.length; i++)
		{
			CBitStream params;
			params.write_u8(i);
			CGridButton @button = menu.AddButton(arrowIcons[i], getTranslatedString(arrowNames[i]), "CrossbowmanLogic.as", "Callback_PickArrow", params);

			if (button !is null)
			{
				bool enabled = this.getBlobCount(arrowTypeNames[i]) > 0;
				button.SetEnabled(enabled);
				button.selectOneOnClick = true;
		
				//if (enabled && i == ArrowType::fire && !hasReqs(this, i))
				//{
				//	button.hoverText = "Requires a fire source $lantern$";
				//	//button.SetEnabled( false );
				//}
		
				if (arrowSel == i)
				{
					button.SetSelected(1);
				}
			}
		}
	}
}

void onAddToInventory(CBlob@ this, CBlob@ blob)
{
	string itemname = blob.getName();
	
	CInventory@ inv = this.getInventory();
	if (inv.getItemsCount() == 0)
	{
		CrossbowmanInfo@ crossbowman;
		if (!this.get("crossbowmanInfo", @crossbowman))
		{
			return;
		}

		for (uint i = 0; i < arrowTypeNames.length; i++)
		{
			if (itemname == arrowTypeNames[i])
			{
				crossbowman.arrow_type = i;
				ClientSendArrowState(this);
				if (this.isMyPlayer())
				{
					Sound::Play("/CycleInventory.ogg");
				}
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

//reset charge
void onAttach(CBlob@ this, CBlob@ attached, AttachmentPoint @ap)
{
	if (!ap.socket) {
		CrossbowmanInfo@ crossbowman;
		if (!this.get("crossbowmanInfo", @crossbowman))
		{
			return;
		}
		crossbowman.state = 0;
		crossbowman.charge_time = 0;
	}
}