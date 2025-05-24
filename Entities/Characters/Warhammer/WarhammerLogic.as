// Warhammer logic

#include "ThrowCommon.as"
#include "WarhammerCommon.as";
#include "RunnerCommon.as";
#include "Hitters.as";
#include "ShieldCommon.as";
#include "KnockedCommon.as"
#include "Requirements.as"


//attacks limited to the one time per-actor before reset.

void warhammer_actorlimit_setup(CBlob@ this)
{
	u16[] networkIDs;
	this.set("LimitedActors", networkIDs);
}

bool warhammer_has_hit_actor(CBlob@ this, CBlob@ actor)
{
	u16[]@ networkIDs;
	this.get("LimitedActors", @networkIDs);
	return networkIDs.find(actor.getNetworkID()) >= 0;
}

u32 warhammer_hit_actor_count(CBlob@ this)
{
	u16[]@ networkIDs;
	this.get("LimitedActors", @networkIDs);
	return networkIDs.length;
}

void warhammer_add_actor_limit(CBlob@ this, CBlob@ actor)
{
	this.push("LimitedActors", actor.getNetworkID());
}

void warhammer_clear_actor_limits(CBlob@ this)
{
	this.clear("LimitedActors");
}

void onInit(CBlob@ this)
{
	WarhammerInfo warhammer;

	warhammer.state = WarhammerStates::normal;
	warhammer.hammerTimer = 0;
	warhammer.flail_down = getGameTime();
	warhammer.tileDestructionLimiter = 0;
	warhammer.flail = false;

	this.set("warhammerInfo", @warhammer);

	WarhammerState@[] states;
	states.push_back(NormalState());
	states.push_back(FlailState());
	states.push_back(FlailThrowState());
	states.push_back(HammerDrawnState());
	states.push_back(CutState(WarhammerStates::hammer_cut_up));
	states.push_back(CutState(WarhammerStates::hammer_cut_mid));
	states.push_back(CutState(WarhammerStates::hammer_cut_mid_down));
	states.push_back(CutState(WarhammerStates::hammer_cut_mid));
	states.push_back(CutState(WarhammerStates::hammer_cut_down));
	states.push_back(SlashState());
	states.push_back(ResheathState(WarhammerStates::resheathing_cut, WarhammerVars::resheath_cut_time));
	states.push_back(ResheathState(WarhammerStates::resheathing_slash, WarhammerVars::resheath_slash_time));

	this.set("warhammerStates", @states);
	this.set_s32("currentWarhammerState", 0);

	this.set_f32("gib health", -1.5f);
	warhammer_actorlimit_setup(this);
	this.getShape().SetRotationsAllowed(false);
	this.getShape().getConsts().net_threshold_multiplier = 0.5f;
	this.Tag("player");
	this.Tag("flesh");

	//centered on inventory
	this.set_Vec2f("inventory offset", Vec2f(0.0f, 0.0f));

	this.addCommandID(flail_sync_cmd);
	this.addCommandID("flail hit map");

	this.getCurrentScript().runFlags |= Script::tick_not_attached;
	this.getCurrentScript().removeIfTag = "dead";
}

void onSetPlayer(CBlob@ this, CPlayer@ player)
{
	if (player !is null)
	{
		player.SetScoreboardVars("LWBScoreboardIcons.png", 7, Vec2f(16, 16));
	}
}


void RunStateMachine(CBlob@ this, WarhammerInfo@ warhammer, RunnerMoveVars@ moveVars)
{
	WarhammerState@[]@ states;
	if (!this.get("warhammerStates", @states))
	{
		return;
	}

	s32 currentStateIndex = this.get_s32("currentWarhammerState");

	if (getNet().isClient())
	{
		if (this.exists("serverWarhammerState"))
		{
			s32 serverStateIndex = this.get_s32("serverWarhammerState");
			this.set_s32("serverWarhammerState", -1);
			if (serverStateIndex != -1 && serverStateIndex != currentStateIndex)
			{
				WarhammerState@ serverState = states[serverStateIndex];
				u8 net_state = states[serverStateIndex].getStateValue();
				if (this.isMyPlayer())
				{
					if (net_state >= WarhammerStates::hammer_cut_mid && net_state <= WarhammerStates::hammer_power)
					{
						if (warhammer.state != WarhammerStates::hammer_drawn && warhammer.state != WarhammerStates::resheathing_cut && warhammer.state != WarhammerStates::resheathing_slash)
						{
							if ((getGameTime() - serverState.stateEnteredTime) > 20)
							{
								warhammer.state = net_state;
								serverState.stateEnteredTime = getGameTime();
								serverState.StateEntered(this, warhammer, serverState.getStateValue());
								this.set_s32("currentWarhammerState", serverStateIndex);
								currentStateIndex = serverStateIndex;
							}

						}

					}
				}
				else
				{
					warhammer.state = net_state;
					serverState.stateEnteredTime = getGameTime();
					serverState.StateEntered(this, warhammer, serverState.getStateValue());
					this.set_s32("currentWarhammerState", serverStateIndex);
					currentStateIndex = serverStateIndex;
				}

			}
		}
	}



	u8 state = warhammer.state;
	WarhammerState@ currentState = states[currentStateIndex];

	bool tickNext = false;
	tickNext = currentState.TickState(this, warhammer, moveVars);

	if (state != warhammer.state)
	{
		for (s32 i = 0; i < states.size(); i++)
		{
			if (states[i].getStateValue() == warhammer.state)
			{
				s32 nextStateIndex = i;
				WarhammerState@ nextState = states[nextStateIndex];
				currentState.StateExited(this, warhammer, nextState.getStateValue());

				nextState.stateEnteredTime = getGameTime();
				nextState.StateEntered(this, warhammer, currentState.getStateValue());
				this.set_s32("currentWarhammerState", nextStateIndex);
				if (getNet().isServer() && warhammer.state >= WarhammerStates::hammer_drawn && warhammer.state <= WarhammerStates::hammer_power)
				{
					this.set_s32("serverWarhammerState", nextStateIndex);
					this.Sync("serverWarhammerState", true);
				}

				if (tickNext)
				{
					RunStateMachine(this, warhammer, moveVars);

				}
				break;
			}
		}
	}
}

void onTick(CBlob@ this)
{
	bool knocked = isKnocked(this);
	CHUD@ hud = getHUD();

	//warhammer logic stuff
	//get the vars to turn various other scripts on/off
	RunnerMoveVars@ moveVars;
	if (!this.get("moveVars", @moveVars))
	{
		return;
	}

	WarhammerInfo@ warhammer;
	if (!this.get("warhammerInfo", @warhammer))
	{
		return;
	}

	if (this.isInInventory())
	{
		//prevent players from insta-slashing when exiting crates
		warhammer.state = 0;
		warhammer.hammerTimer = 0;
		hud.SetCursorFrame(0);
		this.set_s32("currentWarhammerState", 0);
		warhammer.flail = false;
		return;
	}

	Vec2f pos = this.getPosition();
	Vec2f vel = this.getVelocity();
	Vec2f aimpos = this.getAimPos();
	const bool inair = (!this.isOnGround() && !this.isOnLadder());

	Vec2f vec;

	const int direction = this.getAimDirection(vec);
	const f32 side = (this.isFacingLeft() ? 1.0f : -1.0f);
	bool flailState = isFlailState(warhammer.state);
	bool hammerState = isHammerState(warhammer.state);
	bool pressed_a1 = this.isKeyPressed(key_action1);
	bool pressed_a2 = this.isKeyPressed(key_action2);
	bool walking = (this.isKeyPressed(key_left) || this.isKeyPressed(key_right));

	const bool myplayer = this.isMyPlayer();

	if (getNet().isClient() && !this.isInInventory() && myplayer)  //Warhammer charge cursor
	{
		HammerCursorUpdate(this, warhammer);
	}

	if (knocked)
	{
		warhammer.state = WarhammerStates::normal; //cancel any attacks or shielding
		warhammer.hammerTimer = 0;
		warhammer.decreasing = false;
		warhammer.flail = false;
		this.set_s32("currentWarhammerState", 0);

		pressed_a1 = false;
		pressed_a2 = false;
		walking = false;

	}
	else
	{
		RunStateMachine(this, warhammer, moveVars);

	}

	if (!hammerState && !flailState)
	{
		warhammer_clear_actor_limits(this);
	}

}

void FlailMovement(WarhammerInfo@ warhammer, RunnerMoveVars@ moveVars)
{
	bool strong = (warhammer.hammerTimer > WarhammerVars::flail_charge);
	moveVars.jumpFactor *= (strong ? 0.5f : 0.7f);
	moveVars.walkFactor *= (strong ? 0.5f : 0.7f);
}

class NormalState : WarhammerState
{
	u8 getStateValue() { return WarhammerStates::normal; }
	void StateEntered(CBlob@ this, WarhammerInfo@ warhammer, u8 previous_state)
	{
		warhammer.hammerTimer = 0;
		this.set_u8("swordSheathPlayed", 0);
	}

	bool TickState(CBlob@ this, WarhammerInfo@ warhammer, RunnerMoveVars@ moveVars)
	{
		if (this.isKeyPressed(key_action1) && !moveVars.wallsliding)
		{
			warhammer.state = WarhammerStates::hammer_drawn;
			return true;
		}
		else if (this.isKeyPressed(key_action2))
		{
			warhammer.state = WarhammerStates::flail;
			return true;
		}

		return false;
	}
}

class FlailState : WarhammerState
{
	u8 getStateValue() { return WarhammerStates::flail; }
	void StateEntered(CBlob@ this, WarhammerInfo@ warhammer, u8 previous_state)
	{
		warhammer.hammerTimer = 0;
	}

	bool TickState(CBlob@ this, WarhammerInfo@ warhammer, RunnerMoveVars@ moveVars)
	{
		if (moveVars.wallsliding)
		{
			warhammer.state = WarhammerStates::normal;
			return false;

		}

		Vec2f pos = this.getPosition();
		// sound scripts is in anim
		/*
		if (getNet().isClient())
		{
			const bool myplayer = this.isMyPlayer();
			if (warhammer.hammerTimer == WarhammerVars::slash_charge && !warhammer.decreasing)
			{
				Sound::Play("SwordSheath.ogg", pos, myplayer ? 1.3f : 0.7f);
				this.set_u8("swordSheathPlayed",  1);
			}
		}*/

		if (warhammer.hammerTimer >= WarhammerVars::flail_charge_limit)
		{
			warhammer.decreasing = true;
		}

		s32 delta = getHammerTimerDelta(warhammer);

		if (!this.isKeyPressed(key_action2))
		{
			if (delta < WarhammerVars::flail_ready)// not enough charge
			{
				warhammer.state = WarhammerStates::normal;
			}
			else// enough so thorw, but how strong?
			{
				warhammer.state = WarhammerStates::flailthrow;
				if (delta >= WarhammerVars::flail_charge) warhammer.flail_power = true;
				else warhammer.flail_power = false;
				ManageFlail(this, warhammer);
			}
		}

		//gliding
		if (getInAir(this) && !this.isInWater() && delta >= WarhammerVars::flail_ready)
		{
			Vec2f vel = this.getVelocity();

			moveVars.stoppingFactor *= 0.5f;
			f32 glide_amount = delta >= WarhammerVars::flail_charge ? 1.0f : 0.5f;// - (moveVars.fallCount / f32(WarhammerVars::glide_down_time * 2));

			if (vel.y > -1.0f)
			{
				this.AddForce(Vec2f(0, -20.0f * glide_amount));
			}
		}

		FlailMovement(warhammer, moveVars);

		return false;
	}
}

class FlailThrowState : WarhammerState
{
	u8 getStateValue() { return WarhammerStates::flailthrow; }
	void StateEntered(CBlob@ this, WarhammerInfo@ warhammer, u8 previous_state)
	{
		warhammer_clear_actor_limits(this);
		warhammer.hammerTimer = 0;
		warhammer.flail_hit_map = false;
	}

	bool TickState(CBlob@ this, WarhammerInfo@ warhammer, RunnerMoveVars@ moveVars)
	{
		ManageFlail(this, warhammer);

		this.Tag("prevent crouch");

		if(!warhammer.flail)//pop in flail
		{
			warhammer.state = WarhammerStates::normal;
			return true;
		}

		FlailMovement(warhammer, moveVars);

		return false;
	}
}


void ManageFlail(CBlob@ this, WarhammerInfo@ warhammer)
{
	CSprite@ sprite = this.getSprite();
	Vec2f pos = this.getPosition();

	if ((canSend(this) || isServer()) && !warhammer.flail) //just throwing
	{
		warhammer.flail = true;
		warhammer.flail_pos = pos;

		warhammer.flail_ratio = warhammer.flail_power ? 1.0f : 0.8f; //allow fully extended

		Vec2f direction = this.getAimPos() - pos;

		//aim in direction of cursor
		f32 distance = direction.Normalize();
		if (distance > 1.0f)
		{
			warhammer.flail_vel = direction * warhammer_flail_throw_speed * (warhammer.flail_power ? 1.0f : 0.5f);
		}
		else
		{
			warhammer.flail_vel = Vec2f_zero;
		}

		Sound::Play("/ArgLong", this.getPosition());
		Sound::Play("/SwordSlash", this.getPosition());

		SyncFlail(this);
	}

	if (warhammer.flail)
	{
		//update flail
		//TODO move to its own script?

		const f32 warhammer_flail_range = warhammer_flail_length * warhammer.flail_ratio;
		const f32 warhammer_flail_force_limit = this.getMass() * warhammer_flail_accel_limit;

		CMap@ map = this.getMap();

		//reel in
		//TODO: sound
		if (warhammer.flail_ratio > 0.1f)// from 0.2f
			warhammer.flail_ratio -= 1.0f / getTicksASecond();

		//get the force and offset vectors
		Vec2f force;
		Vec2f offset;
		f32 dist;
		{
			force = warhammer.flail_pos - this.getPosition();
			dist = force.Normalize();
			f32 offdist = dist - warhammer_flail_range;
			if (offdist > 0)
			{
				offset = force * Maths::Min(8.0f, offdist * warhammer_flail_stiffness);
				force *= Maths::Min(warhammer_flail_force_limit, Maths::Max(0.0f, offdist + warhammer_flail_slack) * warhammer_flail_force);
			}
			else
			{
				force.Set(0, 0);
			}
		}

		//left map? too long? close flail
		if (warhammer.flail_pos.x < 0 ||
		        warhammer.flail_pos.x > (map.tilemapwidth)*map.tilesize ||
		        dist > warhammer_flail_length * 3.0f)
		{
			if (canSend(this) || isServer())
			{
				warhammer.flail = false;
				SyncFlail(this);
			}
		}
		else// if (warhammer.flail_id == 0xffff) //not stuck
		{
			const f32 drag = map.isInWater(warhammer.flail_pos) ? 0.7f : 0.90f;
			//const Vec2f gravity(0, 1);

			warhammer.flail_vel = (warhammer.flail_vel * drag) - (force * (2 / this.getMass()));// + gravity

			Vec2f next = warhammer.flail_pos + warhammer.flail_vel;
			next -= offset;

			Vec2f dir = next - warhammer.flail_pos;
			f32 delta = dir.Normalize();
			bool found = false;
			const f32 step = map.tilesize * 0.5f;
			while (delta > 0 && !found) //fake raycast
			{
				if (delta > step)
				{
					warhammer.flail_pos += dir * step;
				}
				else
				{
					warhammer.flail_pos = next;
				}
				delta -= step;
				found = checkFlailStep(this, warhammer, map, dist);//need bool?
			}

		}
	}

}

// also check hit
bool checkFlailStep(CBlob@ this, WarhammerInfo@ warhammer, CMap@ map, const f32 dist)
{
	if (map.getSectorAtPosition(warhammer.flail_pos, "barrier") !is null)  //red barrier
	{
		if (canSend(this) || isServer())
		{
			warhammer.flail = false;
			SyncFlail(this);
		}
		return true;
	}
	if (flailHitMap(this, warhammer, map, dist))// map damage is in
	{
		warhammer.flail_ratio = Maths::Max(0.1, Maths::Min(warhammer.flail_ratio, dist / warhammer_flail_length));

		warhammer.flail_pos.y = Maths::Max(0.0, warhammer.flail_pos.y);

		// bring from ManageFlail
		const f32 warhammer_flail_range = warhammer_flail_length * warhammer.flail_ratio;
		Vec2f force = warhammer.flail_pos - this.getPosition();
		f32 dist = force.Length();
		if (dist >= warhammer_flail_range)// stop flail if it's not reel in time
		{
			warhammer.flail_vel = Vec2f_zero;
		}

		if (canSend(this) || isServer()) SyncFlail(this);

		return true;
	}
	
	// blob damage
	CBlob@[] blist;
	bool dontHitMoreLogs = false;
	if (map.getBlobsAtPosition(warhammer.flail_pos, @blist))
	{
		for (int i = 0; i < blist.size(); i++)
		{
			CBlob@ b = blist[i];
			if (b is null) continue;

			if (b is this)
			{
				//can't flail self if not reeled in
				if (warhammer.flail_ratio > 0.5f)
					return false;

				if (canSend(this) || isServer())
				{
					warhammer.flail = false;
					SyncFlail(this);
				}

				return true;
			}
			else
			{
				f32 temp_damage = warhammer.flail_power ? 2.0f : 1.0f;
				

				if (getNet().isServer() && b.getTeamNum() != this.getTeamNum() && !warhammer_has_hit_actor(this, b) && canHit(this, b))
				{
					if (b.getName() == "log")
					{
						if (!dontHitMoreLogs)
						{
							temp_damage /= 3;
							dontHitMoreLogs = true; // set this here to prevent from hitting more logs on the same tick
							CBlob@ wood = server_CreateBlobNoInit("mat_wood");
							if (wood !is null)
							{
								int quantity = Maths::Ceil(float(temp_damage) * 20.0f);
								int max_quantity = b.getHealth() / 0.024f; // initial log health / max mats
								
								quantity = Maths::Max(
									Maths::Min(quantity, max_quantity),
									0
								);

								wood.Tag('custom quantity');
								wood.Init();
								wood.setPosition(warhammer.flail_pos);
								wood.server_SetQuantity(quantity);
							}
						}
						else 
						{
							// print("passed a log on " + getGameTime());
							continue; // don't hit the log
						}
					}
					warhammer_add_actor_limit(this, b);

					Vec2f velocity = b.getPosition() - this.getPosition();
					velocity.Normalize();
					velocity *= 12; // knockback force is same regardless of distance

					this.server_Hit(b, b.getPosition(), velocity, temp_damage, Hitters::shield, true);
				}

				if (b.hasTag("blocks sword") || (b.hasTag("barricade") && b.getTeamNum() != this.getTeamNum()) && !b.isAttached() && b.isCollidable())// same with sword and more
				{
					//TODO: Maybe figure out a way to flail moving blobs
					//		without massive desync + forces :)
			
					warhammer.flail_ratio = Maths::Max(0.2, Maths::Min(warhammer.flail_ratio, b.getDistanceTo(this) / warhammer_flail_length));
			
					// bring from ManageFlail
					const f32 warhammer_flail_range = warhammer_flail_length * warhammer.flail_ratio;
					Vec2f force = warhammer.flail_pos - this.getPosition();
					f32 dist = force.Length();
					if (dist >= warhammer_flail_range)// stop flail if it's not reel in time
					{
						warhammer.flail_vel = Vec2f_zero;
					}

					if (canSend(this) || isServer())
					{
						SyncFlail(this);
					}
			
					return true;
				}
			}
		}
	}
	

	return false;
}

bool flailHitMap(CBlob@ this, WarhammerInfo@ warhammer, CMap@ map, const f32 dist = 16.0f)
{
	Vec2f pos = warhammer.flail_pos + Vec2f(0, -3);//fake quad
	if (map.isTileSolid(pos))
	{
		flailDamageMap(this, warhammer, map, pos);
		return true;
	}
	pos = warhammer.flail_pos + Vec2f(3, 0);
	if (map.isTileSolid(pos))
	{
		flailDamageMap(this, warhammer, map, pos);
		return true;
	}
	pos = warhammer.flail_pos + Vec2f(-3, 0);
	if (map.isTileSolid(pos))
	{
		flailDamageMap(this, warhammer, map, pos);
		return true;
	}
	pos = warhammer.flail_pos + Vec2f(0, 3);
	if (map.isTileSolid(pos))
	{
		flailDamageMap(this, warhammer, map, pos);
		return true;
	}
	return false;
	        //(dist > 10.0f && map.getSectorAtPosition(warhammer.flail_pos, "tree") !is null);   //tree stick
}

void flailDamageMap(CBlob@ this, WarhammerInfo@ warhammer, CMap@ map, Vec2f pos)
{
	if (!(canSend(this) || isServer()) || warhammer.flail_hit_map) return;

	uint16 tile = map.getTile(pos).type;

	bool ground = map.isTileGround(tile);
	bool dirt_stone = map.isTileStone(tile);
	bool dirt_thick_stone = map.isTileThickStone(tile);
	bool gold = map.isTileGold(tile);
	bool wood = map.isTileWood(tile);
	bool stone = map.isTileCastle(tile);
	if (ground || wood || dirt_stone || gold || stone)
	{
		/*
		//detect corner

		int check_x = -(offset.x > 0 ? -1 : 1);
		int check_y = -(offset.y > 0 ? -1 : 1);
		if (map.isTileSolid(hi.hitpos - Vec2f(map.tilesize * check_x, 0)) &&
		        map.isTileSolid(hi.hitpos - Vec2f(0, map.tilesize * check_y)))
			continue;*/

		//dont dig through no build zones
		bool canhit = map.getSectorAtPosition(pos, "no build") is null;

		if (!warhammer.flail_power) //fake damage
		{
			warhammer.tileDestructionLimiter++;
			canhit = ((warhammer.tileDestructionLimiter % ((stone) ? 3 : 2)) == 0);
		}
		else //reset fake dmg for next time
		{
			warhammer.tileDestructionLimiter = 0;
		}

		warhammer.flail_hit_map = true;

		if (canhit)
		{
			CBitStream bt;
			bt.write_Vec2f(pos);
			this.SendCommand(this.getCommandID("flail hit map"), bt);
		}
	}
}

bool canSend(CBlob@ this)
{
	return (this.isMyPlayer() || this.getPlayer() is null || this.getPlayer().isBot());
}

void onCommand(CBlob@ this, u8 cmd, CBitStream @params)
{
	if (cmd == this.getCommandID(flail_sync_cmd) && isClient())
	{
		HandleFlail(this, params, !canSend(this));
	}
	else if (cmd == this.getCommandID("flail hit map") && isServer())
	{
		Vec2f pos;
		if (!params.saferead_Vec2f(pos))
		{
			return;
		}

		CMap@ map = this.getMap();

		uint16 tile = map.getTile(pos).type;

		bool ground = map.isTileGround(tile);
		bool dirt_stone = map.isTileStone(tile);
		bool dirt_thick_stone = map.isTileThickStone(tile);
		bool gold = map.isTileGold(tile);
		bool wood = map.isTileWood(tile);
		bool stone = map.isTileCastle(tile);
		if (ground || wood || dirt_stone || gold || stone)
		{
			map.server_DestroyTile(pos, 0.1f, this);
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
					ore.setPosition(pos);
					ore.server_SetQuantity(quantity);
				}
			}
		}
	}
}

s32 getHammerTimerDelta(WarhammerInfo@ warhammer)
{
	s32 delta = warhammer.hammerTimer;
	if (warhammer.decreasing && warhammer.hammerTimer > 0)
	{
		warhammer.hammerTimer--;
		if (warhammer.hammerTimer == 0) warhammer.decreasing = false;
	}
	else// if (warhammer.hammerTimer < 128)
	{
		warhammer.hammerTimer++;
	}
	return delta;
}

void AttackMovement(CBlob@ this, WarhammerInfo@ warhammer, RunnerMoveVars@ moveVars)
{
	Vec2f vel = this.getVelocity();

	bool strong = (warhammer.hammerTimer > WarhammerVars::slash_charge);
	moveVars.jumpFactor *= (strong ? 0.5f : 0.7f);
	moveVars.walkFactor *= (strong ? 0.5f : 0.7f);

	bool inair = getInAir(this);
	if (!inair)
	{
		this.AddForce(Vec2f(vel.x * -5.0, 0.0f));   //horizontal slowing force (prevents SANICS)
	}

	moveVars.canVault = false;
}

class HammerDrawnState : WarhammerState
{
	u8 getStateValue() { return WarhammerStates::hammer_drawn; }
	void StateEntered(CBlob@ this, WarhammerInfo@ warhammer, u8 previous_state)
	{
		warhammer.hammerTimer = 0;
		this.set_u8("swordSheathPlayed", 0);
	}

	bool TickState(CBlob@ this, WarhammerInfo@ warhammer, RunnerMoveVars@ moveVars)
	{
		if (moveVars.wallsliding)
		{
			warhammer.state = WarhammerStates::normal;
			return false;

		}

		Vec2f pos = this.getPosition();

		if (getNet().isClient())
		{
			const bool myplayer = this.isMyPlayer();
			if (warhammer.hammerTimer == WarhammerVars::slash_charge && !warhammer.decreasing)
			{
				Sound::Play("SwordSheath.ogg", pos, myplayer ? 1.3f : 0.7f);
				this.set_u8("swordSheathPlayed",  1);
			}
		}

		if (warhammer.hammerTimer >= WarhammerVars::slash_charge_limit)
		{
			warhammer.decreasing = true;
		}

		AttackMovement(this, warhammer, moveVars);
		s32 delta = getHammerTimerDelta(warhammer);

		if (!this.isKeyPressed(key_action1))
		{
			if (delta < WarhammerVars::slash_charge)
			{
				Vec2f vec;
				const int direction = this.getAimDirection(vec);

				if (direction == -1)
				{
					warhammer.state = WarhammerStates::hammer_cut_up;
				}
				else if (direction == 0)
				{
					Vec2f aimpos = this.getAimPos();
					Vec2f pos = this.getPosition();
					if (aimpos.y < pos.y)
					{
						warhammer.state = WarhammerStates::hammer_cut_mid;
					}
					else
					{
						warhammer.state = WarhammerStates::hammer_cut_mid_down;
					}
				}
				else
				{
					warhammer.state = WarhammerStates::hammer_cut_down;
				}
			}
			else// if (delta < WarhammerVars::slash_charge_level2)
			{
				warhammer.state = WarhammerStates::hammer_power;
			}
		}

		return false;
	}
}

class CutState : WarhammerState
{
	u8 state;
	CutState(u8 s) { state = s; }
	u8 getStateValue() { return state; }
	void StateEntered(CBlob@ this, WarhammerInfo@ warhammer, u8 previous_state)
	{
		warhammer_clear_actor_limits(this);
		warhammer.hammerTimer = 0;
	}

	bool TickState(CBlob@ this, WarhammerInfo@ warhammer, RunnerMoveVars@ moveVars)
	{
		if (moveVars.wallsliding)
		{
			warhammer.state = WarhammerStates::normal;
			return false;

		}

		this.Tag("prevent crouch");

		AttackMovement(this, warhammer, moveVars);
		s32 delta = getHammerTimerDelta(warhammer);

		if (delta == DELTA_BEGIN_ATTACK)
		{
			Sound::Play("/SwordSlash", this.getPosition());
		}
		else if (delta > DELTA_BEGIN_ATTACK && delta < DELTA_END_ATTACK)
		{
			f32 attackarc = 90.0f;
			f32 attackAngle = getCutAngle(this, warhammer.state);

			if (warhammer.state == WarhammerStates::hammer_cut_down)
			{
				attackarc *= 0.9f;
			}

			DoAttack(this, 1.5f, attackAngle, attackarc, Hitters::shield, delta, warhammer);
		}
		else if (delta >= 17)
		{
			warhammer.state = WarhammerStates::resheathing_cut;
		}

		return false;

	}
}

Vec2f getSlashDirection(CBlob@ this)
{
	Vec2f vel = this.getVelocity();
	Vec2f aiming_direction = vel;
	aiming_direction.y *= 2;
	aiming_direction.Normalize();

	return aiming_direction;
}

class SlashState : WarhammerState
{
	u8 getStateValue() { return WarhammerStates::hammer_power; }
	void StateEntered(CBlob@ this, WarhammerInfo@ warhammer, u8 previous_state)
	{
		warhammer_clear_actor_limits(this);
		warhammer.hammerTimer = 0;
		warhammer.slash_direction = getSlashDirection(this);
	}

	bool TickState(CBlob@ this, WarhammerInfo@ warhammer, RunnerMoveVars@ moveVars)
	{
		if (moveVars.wallsliding)
		{
			warhammer.state = WarhammerStates::normal;
			return false;

		}

		if (getNet().isClient())
		{
			const bool myplayer = this.isMyPlayer();
			Vec2f pos = this.getPosition();
			if (warhammer.state == WarhammerStates::hammer_power && this.get_u8("swordSheathPlayed") == 0)
			{
				Sound::Play("SwordSheath.ogg", pos, myplayer ? 1.3f : 0.7f);
				this.set_u8("swordSheathPlayed",  1);
			}
		}

		this.Tag("prevent crouch");

		AttackMovement(this, warhammer, moveVars);
		s32 delta = getHammerTimerDelta(warhammer);

		if (delta == 2)
		{
			Sound::Play("/ArgLong", this.getPosition());
			Sound::Play("/SwordSlash", this.getPosition());
		}
		else if (delta > DELTA_BEGIN_ATTACK && delta < 13)
		{
			Vec2f vec;
			this.getAimDirection(vec);
			DoAttack(this, 3.0f, -(vec.Angle()), 120.0f, Hitters::shield, delta, warhammer);
		}
		else if (delta >= WarhammerVars::slash_time)
		{
			warhammer.state = WarhammerStates::resheathing_slash;
		}

		Vec2f vel = this.getVelocity();
		if (warhammer.state == WarhammerStates::hammer_power &&
				delta < WarhammerVars::slash_move_time)
		{

			if (Maths::Abs(vel.x) < WarhammerVars::slash_move_max_speed &&
					vel.y > -WarhammerVars::slash_move_max_speed)
			{
				Vec2f slash_vel =  warhammer.slash_direction * this.getMass();// * 0.5f
				this.AddForce(slash_vel);
			}
		}

		return false;

	}
}

class ResheathState : WarhammerState
{
	u8 state;
	s32 time;
	ResheathState(u8 s, s32 t) { state = s; time = t; }
	u8 getStateValue() { return state; }
	void StateEntered(CBlob@ this, WarhammerInfo@ warhammer, u8 previous_state)
	{
		warhammer.hammerTimer = 0;
		this.set_u8("swordSheathPlayed", 0);
	}

	bool TickState(CBlob@ this, WarhammerInfo@ warhammer, RunnerMoveVars@ moveVars)
	{
		if (moveVars.wallsliding)
		{
			warhammer.state = WarhammerStates::normal;
			return false;

		}
		else if (this.isKeyPressed(key_action1))
		{
			warhammer.state = WarhammerStates::hammer_drawn;
			return true;
		}
		else if (this.isKeyPressed(key_action2))
		{
			warhammer.state = WarhammerStates::flail;
			return true;
		}

		AttackMovement(this, warhammer, moveVars);
		s32 delta = getHammerTimerDelta(warhammer);

		if (delta > time)
		{
			warhammer.state = WarhammerStates::normal;
		}

		return false;
	}
}

void HammerCursorUpdate(CBlob@ this, WarhammerInfo@ warhammer)
{
	if (warhammer.state == WarhammerStates::flail)// flail
	{
		int frame;
		if (warhammer.hammerTimer >= WarhammerVars::flail_charge)
		{
			frame = 34;
		}
		else if (warhammer.hammerTimer >= WarhammerVars::flail_ready)
		{
			frame = 18 + int((float(warhammer.hammerTimer - WarhammerVars::flail_ready) / (WarhammerVars::flail_charge - WarhammerVars::flail_ready)) * 16);
		}
		else
		{
			frame = 0 + int((float(warhammer.hammerTimer) / WarhammerVars::flail_ready) * 18);
		}
		getHUD().SetCursorFrame(frame);
	}
	else if (warhammer.state == WarhammerStates::flailthrow)
	{
		// no update?
	}
	// and other
	else if (warhammer.hammerTimer >= WarhammerVars::slash_charge)
	{
		getHUD().SetCursorFrame(1);
	}
	// the yellow circle stays for the duration of a slash, helpful for newplayers (note: you cant attack while its yellow)
	else if (warhammer.state == WarhammerStates::normal || warhammer.state == WarhammerStates::resheathing_cut || warhammer.state == WarhammerStates::resheathing_slash) // disappear after slash is done
	// the yellow circle dissapears after mouse button release, more intuitive for improving slash timing
	// else if (warhammer.hammerTimer == 0) (disappear right after mouse release)
	{
		getHUD().SetCursorFrame(0);
	}
	else if (warhammer.hammerTimer < WarhammerVars::slash_charge && warhammer.state == WarhammerStates::hammer_drawn)
	{
		int frame = 2 + int((float(warhammer.hammerTimer) / WarhammerVars::slash_charge) * 8) * 2;
		if (warhammer.hammerTimer <= WarhammerVars::resheath_cut_time) //prevent from appearing when jabbing/jab spamming
		{
			getHUD().SetCursorFrame(0);
		}
		else
		{
			getHUD().SetCursorFrame(frame);
		}
	}
}
/////////////////////////////////////////////////

bool isJab(f32 damage)
{
	return damage < 2.0f;
}

void DoAttack(CBlob@ this, f32 damage, f32 aimangle, f32 arcdegrees, u8 type, int deltaInt, WarhammerInfo@ info)
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
		// HitInfo objects are sorted, first come closest hits
		// start from furthest ones to avoid doing too many redundant raycasts
		for (int i = hitInfos.size() - 1; i >= 0; i--)
		{
			HitInfo@ hi = hitInfos[i];
			CBlob@ b = hi.blob;

			if (b !is null)
			{
				if (b.hasTag("ignore sword") 
				    || !canHit(this, b)
				    || warhammer_has_hit_actor(this, b)) 
				{
					continue;
				}

				Vec2f hitvec = hi.hitpos - pos;

				// we do a raycast to given blob and hit everything hittable between warhammer and that blob
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
					if (warhammer_has_hit_actor(this, rayb)) 
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
					
					warhammer_add_actor_limit(this, rayb);

					
					Vec2f velocity = rayb.getPosition() - pos;
					velocity.Normalize();
					velocity *= 12; // knockback force is same regardless of distance

					if (rayb.getTeamNum() != this.getTeamNum() || rayb.hasTag("dead player"))
					{
						this.server_Hit(rayb, rayInfos[j].hitpos, velocity, temp_damage, type, true);
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
					bool stone = map.isTileCastle(hi.tile);
					if (ground || wood || dirt_stone || gold || stone)
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
							if (jab) //fake damage
							{
								info.tileDestructionLimiter++;
								canhit = ((info.tileDestructionLimiter % ((stone) ? 3 : 2)) == 0);
							}
							else //reset fake dmg for next time
							{
								info.tileDestructionLimiter = 0;
							}

							//dont dig through no build zones
							canhit = canhit && map.getSectorAtPosition(tpos, "no build") is null;

							dontHitMoreMap = true;
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

//a little push forward

void pushForward(CBlob@ this, f32 normalForce, f32 pushingForce, f32 verticalForce)
{
	f32 facing_sign = this.isFacingLeft() ? -1.0f : 1.0f ;
	bool pushing_in_facing_direction =
	    (facing_sign < 0.0f && this.isKeyPressed(key_left)) ||
	    (facing_sign > 0.0f && this.isKeyPressed(key_right));
	f32 force = normalForce;

	if (pushing_in_facing_direction)
	{
		force = pushingForce;
	}

	this.AddForce(Vec2f(force * facing_sign , verticalForce));
}
/*
void onHitBlob(CBlob@ this, Vec2f worldPoint, Vec2f velocity, f32 damage, CBlob@ hitBlob, u8 customData)
{
	WarhammerInfo@ warhammer;
	if (!this.get("warhammerInfo", @warhammer))
	{
		return;
	}

	if (customData == Hitters::warhammer &&
	        ( //is a jab - note we dont have the dmg in here at the moment :/
	            warhammer.state == WarhammerStates::hammer_cut_mid ||
	            warhammer.state == WarhammerStates::hammer_cut_mid_down ||
	            warhammer.state == WarhammerStates::hammer_cut_up ||
	            warhammer.state == WarhammerStates::hammer_cut_down
	        )
	        && blockAttack(hitBlob, velocity, 0.0f))
	{
		this.getSprite().PlaySound("/Stun", 1.0f, this.getSexNum() == 0 ? 1.0f : 1.5f);
		setKnocked(this, 30, true);
	}
}
*/
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