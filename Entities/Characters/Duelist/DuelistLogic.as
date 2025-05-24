// Duelist logic

#include "DuelistCommon.as"
#include "ThrowCommon.as"
#include "KnockedCommon.as"
#include "Hitters.as"
#include "RunnerCommon.as"
#include "ShieldCommon.as";
#include "RedBarrierCommon.as"

//attacks limited to the one time per-actor before reset.

void duelist_actorlimit_setup(CBlob@ this)
{
	u16[] networkIDs;
	this.set("LimitedActors", networkIDs);
}

bool duelist_has_hit_actor(CBlob@ this, CBlob@ actor)
{
	u16[]@ networkIDs;
	this.get("LimitedActors", @networkIDs);
	return networkIDs.find(actor.getNetworkID()) >= 0;
}

u32 duelist_hit_actor_count(CBlob@ this)
{
	u16[]@ networkIDs;
	this.get("LimitedActors", @networkIDs);
	return networkIDs.length;
}

void duelist_add_actor_limit(CBlob@ this, CBlob@ actor)
{
	this.push("LimitedActors", actor.getNetworkID());
}

void duelist_clear_actor_limits(CBlob@ this)
{
	this.clear("LimitedActors");
	this.set_u8("specialhit", 0);
}

void onInit(CBlob@ this)
{
	DuelistInfo duelist;
	this.set("duelistInfo", @duelist);

	duelist.state = DuelistStates::normal;
	duelist.rapierTimer = 0;
	duelist.tileDestructionLimiter = 0;
	duelist.decrease = false;

	this.set("duelistInfo", @duelist);
	
	DuelistState@[] states;
	states.push_back(NormalState());
	states.push_back(RapierDrawnState());
	states.push_back(CutState(DuelistStates::rapier_cut));
	states.push_back(SlashState(DuelistStates::rapier_power));
	states.push_back(ResheathState(DuelistStates::resheathing_cut, DuelistVars::resheath_cut_time));
	states.push_back(ResheathState(DuelistStates::resheathing_slash, DuelistVars::resheath_slash_time));

	this.set("duelistStates", @states);
	this.set_s32("currentDuelistState", 0);

	this.set_f32("gib health", -1.5f);
	//no spinning
	this.getShape().SetRotationsAllowed(false);
	this.getShape().getConsts().net_threshold_multiplier = 0.5f;
	duelist_actorlimit_setup(this);
	this.Tag("player");
	this.Tag("flesh");

	//centered on arrows
	//this.set_Vec2f("inventory offset", Vec2f(0.0f, 122.0f));
	//centered on items
	this.set_Vec2f("inventory offset", Vec2f(0.0f, 0.0f));


	this.addCommandID(grapple_sync_cmd);

	this.getCurrentScript().runFlags |= Script::tick_not_attached;
	this.getCurrentScript().removeIfTag = "dead";
}

void onSetPlayer(CBlob@ this, CPlayer@ player)
{
	if (player !is null)
	{
		player.SetScoreboardVars("LWBScoreboardIcons.png", 8, Vec2f(16, 16));
	}
}

void ManageGrapple(CBlob@ this, DuelistInfo@ duelist)
{
	CSprite@ sprite = this.getSprite();
	Vec2f pos = this.getPosition();

	const bool right_click = this.isKeyJustPressed(key_action2);
	if (right_click)
	{
		if (canSend(this) || isServer()) //otherwise grapple
		{
			duelist.grappling = true;
			duelist.grapple_id = 0xffff;
			duelist.grapple_pos = pos;

			duelist.grapple_ratio = 1.0f; //allow fully extended

			Vec2f direction = this.getAimPos() - pos;

			//aim in direction of cursor
			f32 distance = direction.Normalize();
			if (distance > 1.0f)
			{
				duelist.grapple_vel = direction * duelist_grapple_throw_speed;
			}
			else
			{
				duelist.grapple_vel = Vec2f_zero;
			}

			SyncGrapple(this);
		}
	}

	if (duelist.grappling)
	{
		//update grapple
		//TODO move to its own script?

		if (!this.isKeyPressed(key_action2))
		{
			if (canSend(this) || isServer())
			{
				duelist.grappling = false;
				SyncGrapple(this);
			}
		}
		else
		{
			const f32 duelist_grapple_range = duelist_grapple_length * duelist.grapple_ratio;
			const f32 duelist_grapple_force_limit = this.getMass() * duelist_grapple_accel_limit;

			CMap@ map = this.getMap();

			//reel in
			//TODO: sound
			if (duelist.grapple_ratio > 0.2f)
				duelist.grapple_ratio -= 1.0f / getTicksASecond();

			//get the force and offset vectors
			Vec2f force;
			Vec2f offset;
			f32 dist;
			{
				force = duelist.grapple_pos - this.getPosition();
				dist = force.Normalize();
				f32 offdist = dist - duelist_grapple_range;
				if (offdist > 0)
				{
					offset = force * Maths::Min(8.0f, offdist * duelist_grapple_stiffness);
					force *= Maths::Min(duelist_grapple_force_limit, Maths::Max(0.0f, offdist + duelist_grapple_slack) * duelist_grapple_force);
				}
				else
				{
					force.Set(0, 0);
				}
			}

			//left map? too long? close grapple
			if (duelist.grapple_pos.x < 0 ||
			        duelist.grapple_pos.x > (map.tilemapwidth)*map.tilesize ||
			        dist > duelist_grapple_length * 3.0f)
			{
				if (canSend(this) || isServer())
				{
					duelist.grappling = false;
					SyncGrapple(this);
				}
			}
			else if (duelist.grapple_id == 0xffff) //not stuck
			{
				const f32 drag = map.isInWater(duelist.grapple_pos) ? 0.7f : 0.90f;
				const Vec2f gravity(0, 1);

				duelist.grapple_vel = (duelist.grapple_vel * drag) + gravity - (force * (2 / this.getMass()));

				Vec2f next = duelist.grapple_pos + duelist.grapple_vel;
				next -= offset;

				Vec2f dir = next - duelist.grapple_pos;
				f32 delta = dir.Normalize();
				bool found = false;
				const f32 step = map.tilesize * 0.5f;
				while (delta > 0 && !found) //fake raycast
				{
					if (delta > step)
					{
						duelist.grapple_pos += dir * step;
					}
					else
					{
						duelist.grapple_pos = next;
					}
					delta -= step;
					found = checkGrappleStep(this, duelist, map, dist);
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
					Vec2f dif = pos - duelist.grapple_pos;
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
				if (duelist.grapple_id != 0)
				{
					@b = getBlobByNetworkID(duelist.grapple_id);
					if (b is null)
					{
						duelist.grapple_id = 0;
					}
				}

				if (b !is null)
				{
					duelist.grapple_pos = b.getPosition();
					if (b.isKeyJustPressed(key_action1) ||
					        b.isKeyJustPressed(key_action2) ||
					        this.isKeyPressed(key_use))
					{
						if (canSend(this) || isServer())
						{
							duelist.grappling = false;
							SyncGrapple(this);
						}
					}
				}
				else if (shouldReleaseGrapple(this, duelist, map))
				{
					if (canSend(this) || isServer())
					{
						duelist.grappling = false;
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

void RunStateMachine(CBlob@ this, DuelistInfo@ duelist, RunnerMoveVars@ moveVars)
{
	DuelistState@[]@ states;
	if (!this.get("duelistStates", @states))
	{
		return;
	}

	s32 currentStateIndex = this.get_s32("currentDuelistState");

	if (getNet().isClient())
	{
		if (this.exists("serverDuelistState"))
		{
			s32 serverStateIndex = this.get_s32("serverDuelistState");
			this.set_s32("serverDuelistState", -1);
			if (serverStateIndex != -1 && serverStateIndex != currentStateIndex)
			{
				DuelistState@ serverState = states[serverStateIndex];
				u8 net_state = states[serverStateIndex].getStateValue();
				if (this.isMyPlayer())
				{
					if (net_state >= DuelistStates::rapier_cut && net_state <= DuelistStates::rapier_power)
					{
						if ((getGameTime() - serverState.stateEnteredTime) > 20)
						{
							if (duelist.state != DuelistStates::rapier_drawn && duelist.state != DuelistStates::resheathing_cut && duelist.state != DuelistStates::resheathing_slash)
							{
								duelist.state = net_state;
								serverState.stateEnteredTime = getGameTime();
								serverState.StateEntered(this, duelist, serverState.getStateValue());
								this.set_s32("currentDuelistState", serverStateIndex);
								currentStateIndex = serverStateIndex;
							}
						}

					}
				}
				else
				{
					duelist.state = net_state;
					serverState.stateEnteredTime = getGameTime();
					serverState.StateEntered(this, duelist, serverState.getStateValue());
					this.set_s32("currentDuelistState", serverStateIndex);
					currentStateIndex = serverStateIndex;
				}

			}
		}
	}



	u8 state = duelist.state;
	DuelistState@ currentState = states[currentStateIndex];

	bool tickNext = false;
	tickNext = currentState.TickState(this, duelist, moveVars);

	if (state != duelist.state)
	{
		for (s32 i = 0; i < states.size(); i++)
		{
			if (states[i].getStateValue() == duelist.state)
			{
				s32 nextStateIndex = i;
				DuelistState@ nextState = states[nextStateIndex];
				currentState.StateExited(this, duelist, nextState.getStateValue());
				nextState.StateEntered(this, duelist, currentState.getStateValue());
				this.set_s32("currentDuelistState", nextStateIndex);
				if (getNet().isServer() && duelist.state >= DuelistStates::rapier_drawn && duelist.state <= DuelistStates::rapier_power)
				{
					this.set_s32("serverDuelistState", nextStateIndex);
					this.Sync("serverDuelistState", true);
				}

				if (tickNext)
				{
					RunStateMachine(this, duelist, moveVars);

				}
				break;
			}
		}
	}
}

void onTick(CBlob@ this)
{
	DuelistInfo@ duelist;
	if (!this.get("duelistInfo", @duelist))
	{
		return;
	}

	ManageGrapple(this, duelist);

	const bool myplayer = this.isMyPlayer();

	if(myplayer)
	{
		// space
		if (this.isKeyJustPressed(key_action3))
		{
			client_SendThrowOrActivateCommand(this);
		}
	}

	bool knocked = isKnocked(this);
	CHUD@ hud = getHUD();

	//duelist logic stuff
	//get the vars to turn various other scripts on/off
	RunnerMoveVars@ moveVars;
	if (!this.get("moveVars", @moveVars))
	{
		return;
	}

	if (this.isInInventory())
	{
		//prevent players from insta-slashing when exiting crates
		duelist.state = 0;
		duelist.rapierTimer = 0;
		hud.SetCursorFrame(0);
		this.set_s32("currentDuelistState", 0);
		duelist.grappling = false;
		return;
	}

	Vec2f pos = this.getPosition();
	Vec2f vel = this.getVelocity();
	Vec2f aimpos = this.getAimPos();
	const bool inair = (!this.isOnGround() && !this.isOnLadder());

	Vec2f vec;

	const int direction = this.getAimDirection(vec);
	const f32 side = (this.isFacingLeft() ? 1.0f : -1.0f);
	bool rapierState = isRapierState(duelist.state);
	bool pressed_a1 = this.isKeyPressed(key_action1);
	bool pressed_a2 = this.isKeyPressed(key_action2);
	bool walking = (this.isKeyPressed(key_left) || this.isKeyPressed(key_right));

	if (getNet().isClient() && !this.isInInventory() && myplayer)  //duelist charge cursor
	{
		RapierCursorUpdate(this, duelist);
	}

	if (knocked)
	{
		duelist.state = DuelistStates::normal; //cancel any attacks or shielding
		duelist.rapierTimer = 0;
		this.set_s32("currentDuelistState", 0);

		pressed_a1 = false;
		pressed_a2 = false;
		walking = false;
		duelist.grappling = false;

	}
	else
	{
		RunStateMachine(this, duelist, moveVars);

	}


	if (!rapierState && getNet().isServer())
	{
		duelist_clear_actor_limits(this);
	}
}

bool getInAir(CBlob@ this)
{
	bool inair = (!this.isOnGround() && !this.isOnLadder());
	return inair;

}

class NormalState : DuelistState
{
	u8 getStateValue() { return DuelistStates::normal; }
	void StateEntered(CBlob@ this, DuelistInfo@ duelist, u8 previous_state)
	{
		duelist.rapierTimer = 0;
		this.set_u8("rapierSheathPlayed", 0);
		this.set_u8("animeRapierPlayed", 0);
	}

	bool TickState(CBlob@ this, DuelistInfo@ duelist, RunnerMoveVars@ moveVars)
	{
		if (this.isKeyPressed(key_action1))
		{
			duelist.state = DuelistStates::rapier_drawn;
			return true;
		}

		return false;
	}
}


s32 getRapierTimerDelta(DuelistInfo@ duelist, bool decrease = false)
{
	s32 delta = duelist.rapierTimer;
	if (duelist.rapierTimer < 128 && !decrease)
	{
		duelist.rapierTimer++;
	}
	else if (duelist.rapierTimer > 0 && decrease)
	{
		duelist.rapierTimer--;
	}
	return delta;
}

void AttackMovement(CBlob@ this, DuelistInfo@ duelist, RunnerMoveVars@ moveVars)
{
	Vec2f vel = this.getVelocity();

	//bool strong = (duelist.rapierTimer > DuelistVars::slash_charge_level2);
	moveVars.jumpFactor *= (0.8f);
	moveVars.walkFactor *= (0.9f);

	bool inair = getInAir(this);
	if (!inair)
	{
		this.AddForce(Vec2f(vel.x * -5.0, 0.0f));   //horizontal slowing force (prevents SANICS)
	}

	moveVars.canVault = false;
}

class RapierDrawnState : DuelistState
{
	u8 getStateValue() { return DuelistStates::rapier_drawn; }
	void StateEntered(CBlob@ this, DuelistInfo@ duelist, u8 previous_state)
	{
		duelist.rapierTimer = 0;
		duelist.decrease = false;
		this.set_u8("rapierSheathPlayed", 0);
		this.set_u8("animeRapierPlayed", 0);
	}

	bool TickState(CBlob@ this, DuelistInfo@ duelist, RunnerMoveVars@ moveVars)
	{
		if (moveVars.wallsliding)
		{
			duelist.state = DuelistStates::normal;
			return false;

		}

		Vec2f pos = this.getPosition();

		if (getNet().isClient())
		{
			const bool myplayer = this.isMyPlayer();
			if (duelist.rapierTimer == DuelistVars::slash_charge)
			{
				Sound::Play("SwordSheath.ogg", pos, myplayer ? 1.3f : 0.7f);
				this.set_u8("animeRapierPlayed", 1);
			}
		}

		if (duelist.rapierTimer >= DuelistVars::slash_charge_limit)// begin discharging, other classes will be knocked when at the time like it
		{
			duelist.rapierTimer = DuelistVars::slash_charge;
			duelist.decrease = true;
		}
		else if (duelist.rapierTimer == 0)
		{
			duelist.decrease = false;
		}

		AttackMovement(this, duelist, moveVars);
		s32 delta = getRapierTimerDelta(duelist, duelist.decrease);

		if (!this.isKeyPressed(key_action1))
		{
			if (delta < DuelistVars::slash_charge)
			{
				duelist.state = DuelistStates::rapier_cut;
			}
			else if(delta < DuelistVars::slash_charge_limit)
			{
				duelist.state = DuelistStates::rapier_power;
			}
		}

		return false;
	}
}

class CutState : DuelistState
{
	u8 state;
	CutState(u8 s) { state = s; }
	u8 getStateValue() { return state; }
	void StateEntered(CBlob@ this, DuelistInfo@ duelist, u8 previous_state)
	{
		duelist_clear_actor_limits(this);
		duelist.rapierTimer = 0;
	}

	bool TickState(CBlob@ this, DuelistInfo@ duelist, RunnerMoveVars@ moveVars)
	{
		if (moveVars.wallsliding)
		{
			duelist.state = DuelistStates::normal;
			return false;

		}

		this.Tag("prevent crouch");

		AttackMovement(this, duelist, moveVars);
		s32 delta = getRapierTimerDelta(duelist);

		if (delta == DELTA_BEGIN_ATTACK)
		{
			Sound::Play("/SwordSlash", this.getPosition());
		}
		else if (delta > DELTA_BEGIN_ATTACK && delta < DELTA_END_ATTACK)
		{
			Vec2f vec;
			this.getAimDirection(vec);
			DoAttack(this, 1.0f, -(vec.Angle()), 60.0f, Hitters::sword, delta, duelist);//half arc
		}
		else if (delta >= 7)//from 9
		{
			duelist.state = DuelistStates::resheathing_cut;
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

class SlashState : DuelistState
{
	u8 state;
	SlashState(u8 s) { state = s; }
	u8 getStateValue() { return state; }
	void StateEntered(CBlob@ this, DuelistInfo@ duelist, u8 previous_state)
	{
		duelist_clear_actor_limits(this);
		duelist.rapierTimer = 0;
		duelist.slash_direction = getSlashDirection(this);
	}

	bool TickState(CBlob@ this, DuelistInfo@ duelist, RunnerMoveVars@ moveVars)
	{
		if (moveVars.wallsliding)
		{
			duelist.state = DuelistStates::normal;
			return false;

		}

		/*if (getNet().isClient())
		{
			const bool myplayer = this.isMyPlayer();
			Vec2f pos = this.getPosition();
			if (duelist.state == DuelistStates::rapier_power_super && this.get_u8("animeRapierPlayed") == 0)
			{
				Sound::Play("AnimeRapier.ogg", pos, myplayer ? 1.3f : 0.7f);
				this.set_u8("animeRapierPlayed", 1);
				this.set_u8("rapierSheathPlayed", 1);

			}
			else if (duelist.state == DuelistStates::rapier_power && this.get_u8("rapierSheathPlayed") == 0)
			{
				Sound::Play("RapierSheath.ogg", pos, myplayer ? 1.3f : 0.7f);
				this.set_u8("rapierSheathPlayed",  1);
			}
		}*/

		this.Tag("prevent crouch");

		AttackMovement(this, duelist, moveVars);
		s32 delta = getRapierTimerDelta(duelist);

		if (delta == 2)
		{
			Sound::Play("/ArgLong", this.getPosition());
			Sound::Play("/SwordSlash", this.getPosition());
		}
		else if (delta > DELTA_BEGIN_ATTACK && delta < DELTA_END_ATTACK)
		{
			Vec2f vec;
			this.getAimDirection(vec);
			DoAttack(this, 1.5f, -(vec.Angle()), 60.0f, Hitters::sword, delta, duelist);//half arc
		}
		else if (delta >= DuelistVars::slash_time)
		{
			duelist.state = DuelistStates::resheathing_slash;
		}

		Vec2f vel = this.getVelocity();
		if (duelist.state == DuelistStates::rapier_power &&
				delta < DuelistVars::slash_move_time)
		{

			if (Maths::Abs(vel.x) < DuelistVars::slash_move_max_speed &&
					vel.y > -DuelistVars::slash_move_max_speed)
			{
				Vec2f slash_vel =  duelist.slash_direction * this.getMass() * 0.5f;
				this.AddForce(slash_vel);
			}
		}

		return false;

	}
}

class ResheathState : DuelistState
{
	u8 state;
	s32 time;
	ResheathState(u8 s, s32 t) { state = s; time = t; }
	u8 getStateValue() { return state; }
	void StateEntered(CBlob@ this, DuelistInfo@ duelist, u8 previous_state)
	{
		duelist.rapierTimer = 0;
		this.set_u8("rapierSheathPlayed", 0);
		this.set_u8("animeRapierPlayed", 0);
	}

	bool TickState(CBlob@ this, DuelistInfo@ duelist, RunnerMoveVars@ moveVars)
	{
		if (moveVars.wallsliding)
		{
			duelist.state = DuelistStates::normal;
			return false;

		}
		else if (this.isKeyPressed(key_action1))
		{
			duelist.state = DuelistStates::rapier_drawn;
			return true;
		}

		AttackMovement(this, duelist, moveVars);
		s32 delta = getRapierTimerDelta(duelist);

		if (delta > time)
		{
			duelist.state = DuelistStates::normal;
		}

		return false;
	}
}

void RapierCursorUpdate(CBlob@ this, DuelistInfo@ duelist)
{
		if (duelist.rapierTimer >= DuelistVars::slash_charge && duelist.state == DuelistStates::rapier_drawn)
		{
			getHUD().SetCursorFrame(9);
		}
		// the yellow circle stays for the duration of a slash, helpful for newplayers (note: you cant attack while its yellow)
		else if (duelist.state == DuelistStates::normal || duelist.state == DuelistStates::resheathing_cut || duelist.state == DuelistStates::resheathing_slash) // disappear after slash is done
		// the yellow circle dissapears after mouse button release, more intuitive for improving slash timing
		// else if (duelist.rapierTimer == 0) (disappear right after mouse release)
		{
			getHUD().SetCursorFrame(0);
		}
		else if (duelist.rapierTimer < DuelistVars::slash_charge && duelist.state == DuelistStates::rapier_drawn)
		{
			int frame = 1 + int((float(duelist.rapierTimer) / (DuelistVars::slash_charge)) * 8);
			if (duelist.rapierTimer <= DuelistVars::resheath_cut_time) //prevent from appearing when jabbing/jab spamming
			{
				getHUD().SetCursorFrame(0);
			}
			else
			{
				getHUD().SetCursorFrame(frame);
			}
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

bool checkGrappleStep(CBlob@ this, DuelistInfo@ duelist, CMap@ map, const f32 dist)
{
	if (checkGrappleBarrier(duelist.grapple_pos)) // red barrier
	{
		if (canSend(this) || isServer())
		{
			duelist.grappling = false;
			SyncGrapple(this);
		}
	}
	else if (grappleHitMap(duelist, map, dist))
	{
		duelist.grapple_id = 0;

		duelist.grapple_ratio = Maths::Max(0.2, Maths::Min(duelist.grapple_ratio, dist / duelist_grapple_length));

		duelist.grapple_pos.y = Maths::Max(0.0, duelist.grapple_pos.y);

		if (canSend(this) || isServer()) SyncGrapple(this);

		return true;
	}
	else
	{
		CBlob@ b = map.getBlobAtPosition(duelist.grapple_pos);
		if (b !is null)
		{
			if (b is this)
			{
				//can't grapple self if not reeled in
				if (duelist.grapple_ratio > 0.5f)
					return false;

				if (canSend(this) || isServer())
				{
					duelist.grappling = false;
					SyncGrapple(this);
				}

				return true;
			}
			else if (b.isCollidable() && b.getShape().isStatic() && !b.hasTag("ignore_arrow"))
			{
				//TODO: Maybe figure out a way to grapple moving blobs
				//		without massive desync + forces :)

				duelist.grapple_ratio = Maths::Max(0.2, Maths::Min(duelist.grapple_ratio, b.getDistanceTo(this) / duelist_grapple_length));

				duelist.grapple_id = b.getNetworkID();
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

bool grappleHitMap(DuelistInfo@ duelist, CMap@ map, const f32 dist = 16.0f)
{
	return  map.isTileSolid(duelist.grapple_pos + Vec2f(0, -3)) ||			//fake quad
	        map.isTileSolid(duelist.grapple_pos + Vec2f(3, 0)) ||
	        map.isTileSolid(duelist.grapple_pos + Vec2f(-3, 0)) ||
	        map.isTileSolid(duelist.grapple_pos + Vec2f(0, 3)) ||
	        (dist > 10.0f && map.getSectorAtPosition(duelist.grapple_pos, "tree") !is null);   //tree stick
}

bool shouldReleaseGrapple(CBlob@ this, DuelistInfo@ duelist, CMap@ map)
{
	return !grappleHitMap(duelist, map) || this.isKeyPressed(key_use);
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
}

bool isJab(f32 damage)
{
	return damage < 1.5f;
}

void DoAttack(CBlob@ this, f32 damage, f32 aimangle, f32 arcdegrees, u8 type, int deltaInt, DuelistInfo@ info)
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
				    || !canHit(this, b)
				    || duelist_has_hit_actor(this, b)) 
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
								 
					if (duelist_has_hit_actor(this, rayb)) 
					{
						// check if we hit any of these on previous ticks of slash
						if (large) break;
						if (rayb.getName() == "log")
						{
							dontHitMoreLogs = true;
						}
						continue;
					}

					f32 temp_damage = b.hasTag("flesh") ? damage : damage / 2;
					
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
					
					duelist_add_actor_limit(this, rayb);

					
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

							info.tileDestructionLimiter++; //fake damage
							if (!jab) //double damage on slash
							{
								info.tileDestructionLimiter++;
							}

							canhit = ((info.tileDestructionLimiter >= ((wood || dirt_stone) ? 5 : 3)));

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

void onHitBlob(CBlob@ this, Vec2f worldPoint, Vec2f velocity, f32 damage, CBlob@ hitBlob, u8 customData)
{
	DuelistInfo@ duelist;
	if (!this.get("duelistInfo", @duelist))
	{
		return;
	}

	if (customData == Hitters::sword && duelist.state == DuelistStates::rapier_cut && blockAttack(hitBlob, velocity, 0.0f))
	{
		if (blockAttack(hitBlob, velocity, 0.0f))
		{
			this.getSprite().PlaySound("/Stun", 1.0f, this.getSexNum() == 0 ? 1.0f : 1.5f);
			setKnocked(this, 20, true);
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

void onAttach(CBlob@ this, CBlob@ attached, AttachmentPoint @attachedPoint)
{
	DuelistInfo@ duelist;
	if (!this.get("duelistInfo", @duelist))
	{
		return;
	}

	if (this.isAttached() && (canSend(this) || isServer()))
	{
		duelist.grappling = false;
		SyncGrapple(this);

		duelist.state = DuelistStates::normal; //cancel any attacks or shielding
		duelist.rapierTimer = 0;
		this.set_s32("currentDuelistState", 0);
	}
}
