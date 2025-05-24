// Spearman logic

#include "ActivationThrowCommon.as"
#include "SpearmanCommon.as";
#include "RunnerCommon.as";
#include "Hitters.as";
#include "ShieldCommon.as";
#include "KnockedCommon.as"
#include "Requirements.as"
#include "StandardControlsCommon.as";

//attacks limited to the one time per-actor before reset.

void spearman_actorlimit_setup(CBlob@ this)
{
	u16[] networkIDs;
	this.set("LimitedActors", networkIDs);
}

bool spearman_has_hit_actor(CBlob@ this, CBlob@ actor)
{
	u16[]@ networkIDs;
	this.get("LimitedActors", @networkIDs);
	return networkIDs.find(actor.getNetworkID()) >= 0;
}

u32 spearman_hit_actor_count(CBlob@ this)
{
	u16[]@ networkIDs;
	this.get("LimitedActors", @networkIDs);
	return networkIDs.length;
}

void spearman_add_actor_limit(CBlob@ this, CBlob@ actor)
{
	this.push("LimitedActors", actor.getNetworkID());
}

void spearman_clear_actor_limits(CBlob@ this)
{
	this.clear("LimitedActors");
	this.set_u8("specialhit", 0);
}

void onInit(CBlob@ this)
{
	SpearmanInfo spearman;

	spearman.state = SpearmanStates::normal;
	spearman.spearTimer = 0;
	spearman.doubleslash = false;
	spearman.tileDestructionLimiter = 0;
	spearman.spear_type = SpearType::normal;
	spearman.throwing = false;

	this.set("spearmanInfo", @spearman);
	
	SpearmanState@[] states;
	states.push_back(NormalState());
	states.push_back(SpearDrawnState());
	states.push_back(CutState(SpearmanStates::spear_cut_up));
	states.push_back(CutState(SpearmanStates::spear_cut_mid));
	states.push_back(CutState(SpearmanStates::spear_cut_mid_down));
	states.push_back(CutState(SpearmanStates::spear_cut_mid));
	states.push_back(CutState(SpearmanStates::spear_cut_down));
	states.push_back(SlashState(SpearmanStates::spear_power));
	states.push_back(SlashState(SpearmanStates::spear_power_super));
	states.push_back(ThrowState(SpearmanStates::spear_throw));
	states.push_back(ThrowState(SpearmanStates::spear_throw_super));
	states.push_back(ResheathState(SpearmanStates::resheathing_cut, SpearmanVars::resheath_cut_time));
	states.push_back(ResheathState(SpearmanStates::resheathing_slash, SpearmanVars::resheath_slash_time));
	states.push_back(ResheathState(SpearmanStates::resheathing_throw, SpearmanVars::resheath_throw_time));

	this.set("spearmanStates", @states);
	this.set_s32("currentSpearmanState", 0);
	
	this.set_f32("gib health", -1.5f);
	spearman_actorlimit_setup(this);
	this.getShape().SetRotationsAllowed(false);
	this.getShape().getConsts().net_threshold_multiplier = 0.5f;
	this.Tag("player");
	this.Tag("flesh");

	ControlsSwitch@ controls_switch = @onSwitch;
	this.set("onSwitch handle", @controls_switch);

	ControlsCycle@ controls_cycle = @onCycle;
	this.set("onCycle handle", @controls_cycle);

	this.addCommandID("pickup spear");
	this.addCommandID("pickup spear client");
	this.addCommandID("spear sync");
	this.addCommandID("spear sync client");

	//add a command ID for each spear type
	for (uint i = 0; i < spearTypeNames.length; i++)
	{
		this.addCommandID("pick " + spearTypeNames[i]);
	}

	this.set_u8("specialhit", 0);

	//centered on spear select
	//this.set_Vec2f("inventory offset", Vec2f(0.0f, 122.0f));
	//centered on inventory
	this.set_Vec2f("inventory offset", Vec2f(0.0f, 0.0f));

	const string texName = "Entities/Characters/Spearman/SpearmanIcons.png";
	AddIconToken("$Spear$", texName, Vec2f(16, 32), 0);
	AddIconToken("$FireSpear$", texName, Vec2f(16, 32), 1);
	AddIconToken("$PoisonSpear$", texName, Vec2f(16, 32), 2);

	this.getCurrentScript().runFlags |= Script::tick_not_attached;
	this.getCurrentScript().removeIfTag = "dead";
}

void onSetPlayer(CBlob@ this, CPlayer@ player)
{
	if (player !is null)
	{
		player.SetScoreboardVars("LWBScoreboardIcons.png", 4, Vec2f(16, 16));
	}
}


void RunStateMachine(CBlob@ this, SpearmanInfo@ spearman, RunnerMoveVars@ moveVars)
{
	SpearmanState@[]@ states;
	if (!this.get("spearmanStates", @states))
	{
		return;
	}

	s32 currentStateIndex = this.get_s32("currentSpearmanState");

	if (getNet().isClient())
	{
		if (this.exists("serverSpearmanState"))
		{
			s32 serverStateIndex = this.get_s32("serverSpearmanState");
			this.set_s32("serverSpearmanState", -1);
			if (serverStateIndex != -1 && serverStateIndex != currentStateIndex)
			{
				SpearmanState@ serverState = states[serverStateIndex];
				u8 net_state = states[serverStateIndex].getStateValue();
				if (this.isMyPlayer())
				{
					if (net_state >= SpearmanStates::spear_cut_mid && net_state <= SpearmanStates::spear_power_super)
					{
						if ((getGameTime() - serverState.stateEnteredTime) > 20)
						{
							if (spearman.state != SpearmanStates::spear_drawn && spearman.state != SpearmanStates::resheathing_cut && spearman.state != SpearmanStates::resheathing_slash && spearman.state != SpearmanStates::resheathing_throw)
							{
								spearman.state = net_state;
								serverState.stateEnteredTime = getGameTime();
								serverState.StateEntered(this, spearman, serverState.getStateValue());
								this.set_s32("currentSpearmanState", serverStateIndex);
								currentStateIndex = serverStateIndex;
							}
						}

					}
				}
				else
				{
					spearman.state = net_state;
					serverState.stateEnteredTime = getGameTime();
					serverState.StateEntered(this, spearman, serverState.getStateValue());
					this.set_s32("currentSpearmanState", serverStateIndex);
					currentStateIndex = serverStateIndex;
				}

			}
		}
	}



	u8 state = spearman.state;
	SpearmanState@ currentState = states[currentStateIndex];

	bool tickNext = false;
	tickNext = currentState.TickState(this, spearman, moveVars);

	if (state != spearman.state)
	{
		for (s32 i = 0; i < states.size(); i++)
		{
			if (states[i].getStateValue() == spearman.state)
			{
				s32 nextStateIndex = i;
				SpearmanState@ nextState = states[nextStateIndex];
				currentState.StateExited(this, spearman, nextState.getStateValue());
				nextState.StateEntered(this, spearman, currentState.getStateValue());
				this.set_s32("currentSpearmanState", nextStateIndex);
				if (getNet().isServer() && spearman.state >= SpearmanStates::spear_drawn && spearman.state <= SpearmanStates::spear_throw_super)
				{
					this.set_s32("serverSpearmanState", nextStateIndex);
					this.Sync("serverSpearmanState", true);
				}

				if (tickNext)
				{
					RunStateMachine(this, spearman, moveVars);

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

	//spearman logic stuff
	//get the vars to turn various other scripts on/off
	RunnerMoveVars@ moveVars;
	if (!this.get("moveVars", @moveVars))
	{
		return;
	}

	SpearmanInfo@ spearman;
	if (!this.get("spearmanInfo", @spearman))
	{
		return;
	}

	if (this.isInInventory())
	{
		//prevent players from insta-slashing when exiting crates
		spearman.state = 0;
		spearman.spearTimer = 0;
		spearman.doubleslash = false;
		spearman.throwing = false;
		hud.SetCursorFrame(0);
		this.set_s32("currentSpearmanState", 0);
		return;
	}


	Vec2f pos = this.getPosition();
	Vec2f vel = this.getVelocity();
	Vec2f aimpos = this.getAimPos();
	const bool inair = (!this.isOnGround() && !this.isOnLadder());

	Vec2f vec;

	const int direction = this.getAimDirection(vec);
	bool spearState = isSpearState(spearman.state);
	bool pressed_a1 = this.isKeyPressed(key_action1);
	bool pressed_a2 = this.isKeyPressed(key_action2);
	bool walking = (this.isKeyPressed(key_left) || this.isKeyPressed(key_right));

	const bool myplayer = this.isMyPlayer();

	if (getNet().isClient() && !this.isInInventory() && myplayer)  //Spearman charge cursor
	{
		SpearCursorUpdate(this, spearman);
	}

	//with the code about menus and myplayer you can slash-cancel;
	//we'll see if spearmans dmging stuff while in menus is a real issue and go from there
	if (knocked)// || myplayer && getHUD().hasMenus())
	{
		spearman.state = SpearmanStates::normal; //cancel any attacks or shielding
		spearman.spearTimer = 0;
		spearman.doubleslash = false;
		spearman.throwing = false;// for cursor
		this.set_s32("currentSpearmanState", 0);

		pressed_a1 = false;
		pressed_a2 = false;
		walking = false;

	}
	else
	{
		RunStateMachine(this, spearman, moveVars);

	}

	bool responsible = myplayer;
	if (isServer() && !myplayer)
	{
		CPlayer@ p = this.getPlayer();
		if (p !is null)
		{
			responsible = p.isBot();
		}
	}
	if (responsible)
	{
		// from ArcherLogic.as
		bool hasspear = hasSpears(this);
		bool hasnormal = hasSpears(this, SpearType::normal);

		if (!hasspear && hasnormal)
		{
			spearman.spear_type = SpearType::normal;
			ClientSendSpearState(this);

			if (this.isMyPlayer())
			{
				Sound::Play("/CycleInventory.ogg");
			}
		}
	}

	if (myplayer)
	{
		if (spearman.fletch_cooldown > 0)
		{
			spearman.fletch_cooldown--;
		}

		// space

		CControls@ controls = getControls();
		if (this.isKeyPressed(key_action3) && controls.ActionKeyPressed(AK_BUILD_MODIFIER))
		{
			// pickup from ground

			if (spearman.fletch_cooldown == 0)
			{
				if (getPickupSpear(this) !is null)   // pickup spear from ground
				{
					this.SendCommand(this.getCommandID("pickup spear"));
					spearman.fletch_cooldown = PICKUP_COOLDOWN;
				}
			}
		}
		else if (this.isKeyJustPressed(key_action3))
			client_SendThrowOrActivateCommand(this);
	}

	if (!spearState && getNet().isServer())
	{
		spearman_clear_actor_limits(this);
	}

}

bool getInAir(CBlob@ this)
{
	bool inair = (!this.isOnGround() && !this.isOnLadder());
	return inair;

}

class NormalState : SpearmanState
{
	u8 getStateValue() { return SpearmanStates::normal; }
	void StateEntered(CBlob@ this, SpearmanInfo@ spearman, u8 previous_state)
	{
		spearman.spearTimer = 0;
		this.set_u8("spearSheathPlayed", 0);
		this.set_u8("animeSpearPlayed", 0);
	}

	bool TickState(CBlob@ this, SpearmanInfo@ spearman, RunnerMoveVars@ moveVars)
	{
		if (this.isKeyPressed(key_action1))
		{
			spearman.state = SpearmanStates::spear_drawn;
			spearman.throwing = false;
			return true;
		}
		else if (this.isKeyPressed(key_action2))
		{
			spearman.state = SpearmanStates::spear_drawn;
			spearman.throwing = true;
			return true;
		}

		return false;
	}
}


s32 getSpearTimerDelta(SpearmanInfo@ spearman)
{
	s32 delta = spearman.spearTimer;
	if (spearman.spearTimer < 128)
	{
		spearman.spearTimer++;
	}
	return delta;
}

void AttackMovement(CBlob@ this, SpearmanInfo@ spearman, RunnerMoveVars@ moveVars)
{
	Vec2f vel = this.getVelocity();

	bool strong = (spearman.spearTimer > SpearmanVars::slash_charge_level2);
	moveVars.jumpFactor *= (strong ? 0.6f : 0.8f);
	moveVars.walkFactor *= (strong ? 0.8f : 0.9f);

	bool inair = getInAir(this);
	if (!inair)
	{
		this.AddForce(Vec2f(vel.x * -5.0, 0.0f));   //horizontal slowing force (prevents SANICS)
	}

	moveVars.canVault = false;
}

class SpearDrawnState : SpearmanState
{
	u8 getStateValue() { return SpearmanStates::spear_drawn; }
	void StateEntered(CBlob@ this, SpearmanInfo@ spearman, u8 previous_state)
	{
		spearman.spearTimer = 0;
		this.set_u8("spearSheathPlayed", 0);
		this.set_u8("animeSpearPlayed", 0);
	}

	bool TickState(CBlob@ this, SpearmanInfo@ spearman, RunnerMoveVars@ moveVars)
	{
		if (moveVars.wallsliding)
		{
			spearman.state = SpearmanStates::normal;
			spearman.throwing = false;
			return false;

		}

		Vec2f pos = this.getPosition();

		if (getNet().isClient())
		{
			const bool myplayer = this.isMyPlayer();
			if (spearman.spearTimer == SpearmanVars::slash_charge_level2)
			{
				Sound::Play("AnimeSword.ogg", pos, myplayer ? 1.3f : 0.7f);
				this.set_u8("spearSheathPlayed", 1);
			}
			else if (spearman.spearTimer == SpearmanVars::slash_charge)
			{
				Sound::Play("SwordSheath.ogg", pos, myplayer ? 1.3f : 0.7f);
				this.set_u8("animeSpearPlayed", 1);
			}
		}

		if (spearman.spearTimer >= SpearmanVars::slash_charge_limit)
		{
			Sound::Play("/Stun", pos, 1.0f, this.getSexNum() == 0 ? 1.0f : 1.5f);
			setKnocked(this, 15);
			spearman.state = SpearmanStates::normal;
			spearman.throwing = false;
		}

		if (this.isKeyPressed(key_action1) && spearman.throwing)// cancel throwing
		{
			spearman.state = SpearmanStates::normal;
			spearman.throwing = false;
			this.getSprite().PlaySound("PopIn.ogg");
			return false;
		}

		AttackMovement(this, spearman, moveVars);
		s32 delta = getSpearTimerDelta(spearman);

		if ((!this.isKeyPressed(key_action1) && !spearman.throwing) || // releaced LMB on melee charge
			(!this.isKeyPressed(key_action2) && spearman.throwing)) // releaced RMB on throw charge
		{
			if (delta < SpearmanVars::slash_charge)
			{
				Vec2f vec;
				const int direction = this.getAimDirection(vec);

				if (direction == -1)
				{
					spearman.state = SpearmanStates::spear_cut_up;
				}
				else if (direction == 0)
				{
					Vec2f aimpos = this.getAimPos();
					Vec2f pos = this.getPosition();
					if (aimpos.y < pos.y)
					{
						spearman.state = SpearmanStates::spear_cut_mid;
					}
					else
					{
						spearman.state = SpearmanStates::spear_cut_mid_down;
					}
				}
				else
				{
					spearman.state = SpearmanStates::spear_cut_down;
				}
			}
			else if (delta < SpearmanVars::slash_charge_level2)
			{
				spearman.state = spearman.throwing ? SpearmanStates::spear_throw : SpearmanStates::spear_power;
			}
			else if(delta < SpearmanVars::slash_charge_limit)
			{
				spearman.state = spearman.throwing ? SpearmanStates::spear_throw_super : SpearmanStates::spear_power_super;
			}
		}

		return false;
	}
}

class CutState : SpearmanState
{
	u8 state;
	CutState(u8 s) { state = s; }
	u8 getStateValue() { return state; }
	void StateEntered(CBlob@ this, SpearmanInfo@ spearman, u8 previous_state)
	{
		spearman_clear_actor_limits(this);
		spearman.spearTimer = 0;
	}

	bool TickState(CBlob@ this, SpearmanInfo@ spearman, RunnerMoveVars@ moveVars)
	{
		if (moveVars.wallsliding)
		{
			spearman.state = SpearmanStates::normal;
			spearman.throwing = false;
			return false;

		}

		this.Tag("prevent crouch");

		AttackMovement(this, spearman, moveVars);
		s32 delta = getSpearTimerDelta(spearman);

		if (delta == DELTA_BEGIN_ATTACK)
		{
			Sound::Play("/SwordSlash", this.getPosition());
		}
		else if (delta > DELTA_BEGIN_ATTACK && delta < DELTA_END_ATTACK)
		{
			f32 attackarc = 90.0f;
			f32 attackAngle = getCutAngle(this, spearman.state);

			if (spearman.state == SpearmanStates::spear_cut_down)
			{
				attackarc *= 0.9f;
			}

			DoAttack(this, 1.0f, attackAngle, attackarc, Hitters::sword, delta, spearman);
		}
		else if (delta >= 9)
		{
			spearman.state = SpearmanStates::resheathing_cut;
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

class SlashState : SpearmanState
{
	u8 state;
	SlashState(u8 s) { state = s; }
	u8 getStateValue() { return state; }
	void StateEntered(CBlob@ this, SpearmanInfo@ spearman, u8 previous_state)
	{
		spearman_clear_actor_limits(this);
		spearman.spearTimer = 0;
		spearman.slash_direction = getSlashDirection(this);
	}

	bool TickState(CBlob@ this, SpearmanInfo@ spearman, RunnerMoveVars@ moveVars)
	{
		if (moveVars.wallsliding)
		{
			spearman.state = SpearmanStates::normal;
			spearman.throwing = false;
			return false;

		}

		/*if (getNet().isClient())
		{
			const bool myplayer = this.isMyPlayer();
			Vec2f pos = this.getPosition();
			if (spearman.state == SpearmanStates::spear_power_super && this.get_u8("animeSpearPlayed") == 0)
			{
				Sound::Play("AnimeSword.ogg", pos, myplayer ? 1.3f : 0.7f);
				this.set_u8("animeSpearPlayed", 1);
				this.set_u8("spearSheathPlayed", 1);

			}
			else if (spearman.state == SpearmanStates::spear_power && this.get_u8("spearSheathPlayed") == 0)
			{
				Sound::Play("SwordSheath.ogg", pos, myplayer ? 1.3f : 0.7f);
				this.set_u8("spearSheathPlayed",  1);
			}
		}*/

		this.Tag("prevent crouch");

		AttackMovement(this, spearman, moveVars);
		s32 delta = getSpearTimerDelta(spearman);

		if (spearman.state == SpearmanStates::spear_power_super
			&& this.isKeyJustPressed(key_action1))
		{
			spearman.doubleslash = true;
		}

		if (delta == 2)
		{
			Sound::Play("/ArgLong", this.getPosition());
			Sound::Play("/SwordSlash", this.getPosition());
		}
		else if (delta > DELTA_BEGIN_ATTACK && delta < 10)
		{
			Vec2f vec;
			this.getAimDirection(vec);
			DoAttack(this, 2.0f, -(vec.Angle()), 60.0f, Hitters::sword, delta, spearman);//half arc
		}
		else if (delta >= SpearmanVars::slash_time
			|| (spearman.doubleslash && delta >= SpearmanVars::double_slash_time))
		{
			if (spearman.doubleslash)
			{
				spearman.doubleslash = false;
				spearman.state = SpearmanStates::spear_power;
			}
			else
			{
				spearman.state = SpearmanStates::resheathing_slash;
			}
		}

		Vec2f vel = this.getVelocity();
		if ((spearman.state == SpearmanStates::spear_power ||
				spearman.state == SpearmanStates::spear_power_super) &&
				delta < SpearmanVars::slash_move_time)
		{

			if (Maths::Abs(vel.x) < SpearmanVars::slash_move_max_speed &&
					vel.y > -SpearmanVars::slash_move_max_speed)
			{
				Vec2f slash_vel =  spearman.slash_direction * this.getMass() * 0.65f;//from 0.5f
				this.AddForce(slash_vel);
			}
		}

		return false;

	}
}

class ThrowState : SpearmanState
{
	u8 state;
	ThrowState(u8 s) { state = s; }
	u8 getStateValue() { return state; }
	void StateEntered(CBlob@ this, SpearmanInfo@ spearman, u8 previous_state)
	{
		spearman_clear_actor_limits(this);
		spearman.spearTimer = 0;
	}

	bool TickState(CBlob@ this, SpearmanInfo@ spearman, RunnerMoveVars@ moveVars)
	{
		if (moveVars.wallsliding)
		{
			spearman.state = SpearmanStates::normal;
			spearman.throwing = false;
			return false;
		}

		/*if (getNet().isClient())
		{
			const bool myplayer = this.isMyPlayer();
			Vec2f pos = this.getPosition();
			if (spearman.state == SpearmanStates::spear_throw_super && this.get_u8("animeSpearPlayed") == 0)
			{
				Sound::Play("AnimeSword.ogg", pos, myplayer ? 1.3f : 0.7f);
				this.set_u8("animeSpearPlayed", 1);
				this.set_u8("spearSheathPlayed", 1);

			}
			else if (spearman.state == SpearmanStates::spear_throw && this.get_u8("spearSheathPlayed") == 0)
			{
				Sound::Play("SwordSheath.ogg", pos, myplayer ? 1.3f : 0.7f);
				this.set_u8("spearSheathPlayed",  1);
			}
		}*/

		this.Tag("prevent crouch");

		AttackMovement(this, spearman, moveVars);
		s32 delta = getSpearTimerDelta(spearman);

		if (spearman.state == SpearmanStates::spear_throw_super
			&& this.isKeyJustPressed(key_action2))
		{
			spearman.doubleslash = true;
		}

		if (delta == 2)
		{
			if(hasSpears(this, spearman.spear_type))
			{
				Sound::Play("/ArgLong", this.getPosition());
				Sound::Play("/SwordSlash", this.getPosition());
				if(spearman.spear_type == SpearType::fire)
					Sound::Play("/SparkleShort.ogg", this.getPosition());
			}
			else if(this.isMyPlayer())
			{
				Sound::Play("/NoAmmo");
			}
		}
		else if (delta == DELTA_BEGIN_ATTACK + 1)
		{
			DoThrow(this, spearman);
			spearman.fletch_cooldown = FLETCH_COOLDOWN; // just don't allow shoot + make spear
		}
		else if ((delta >= SpearmanVars::slash_time
		    || (spearman.doubleslash && delta >= SpearmanVars::double_slash_time)) && !(delta < 10))
		{
			if (spearman.doubleslash)
			{
				spearman.doubleslash = false;
				spearman.state = SpearmanStates::spear_throw;
			}
			else
			{
				spearman.state = SpearmanStates::resheathing_throw;
			}
		}

		return false;

	}
}

class ResheathState : SpearmanState
{
	u8 state;
	s32 time;
	ResheathState(u8 s, s32 t) { state = s; time = t; }
	u8 getStateValue() { return state; }
	void StateEntered(CBlob@ this, SpearmanInfo@ spearman, u8 previous_state)
	{
		spearman.spearTimer = 0;
		this.set_u8("spearSheathPlayed", 0);
		this.set_u8("animeSpearPlayed", 0);
	}

	bool TickState(CBlob@ this, SpearmanInfo@ spearman, RunnerMoveVars@ moveVars)
	{
		if (moveVars.wallsliding)
		{
			spearman.state = SpearmanStates::normal;
			spearman.throwing = false;
			return false;

		}
		else if (this.isKeyPressed(key_action1))
		{
			spearman.state = SpearmanStates::spear_drawn;
			spearman.throwing = false;
			return true;
		}
		else if (this.isKeyPressed(key_action2))
		{
			spearman.state = SpearmanStates::spear_drawn;
			spearman.throwing = true;
			return true;
		}

		AttackMovement(this, spearman, moveVars);
		s32 delta = getSpearTimerDelta(spearman);

		if (delta > time)
		{
			spearman.state = SpearmanStates::normal;
			spearman.throwing = false;
		}

		return false;
	}
}

CBlob@ getPickupSpear(CBlob@ this)
{
	CBlob@[] blobsInRadius;
	if (this.getMap().getBlobsInRadius(this.getPosition(), this.getRadius() * 1.5f, @blobsInRadius))
	{
		for (uint i = 0; i < blobsInRadius.length; i++)
		{
			CBlob @b = blobsInRadius[i];
			if (b.getName() == "spear")
			{
				return b;
			}
		}
	}
	return null;
}

bool canPickSpriteSpear(CBlob@ this, bool takeout)
{
	CBlob@[] blobsInRadius;
	if (this.getMap().getBlobsInRadius(this.getPosition(), this.getRadius() * 1.5f, @blobsInRadius))
	{
		for (uint i = 0; i < blobsInRadius.length; i++)
		{
			CBlob @b = blobsInRadius[i];
			{
				CSprite@ sprite = b.getSprite();
				if (sprite.getSpriteLayer("spear") !is null)
				{
					if (takeout)
						sprite.RemoveSpriteLayer("spear");
					return true;
				}
			}
		}
	}
	return false;
}

void SpearCursorUpdate(CBlob@ this, SpearmanInfo@ spearman)
{
		if (spearman.spearTimer >= SpearmanVars::slash_charge_level2 || spearman.doubleslash || spearman.state == SpearmanStates::spear_power_super || spearman.state == SpearmanStates::spear_throw_super)
		{
			getHUD().SetCursorFrame(isThrowing(this) ? 34 : 19);
		}
		else if (spearman.spearTimer >= SpearmanVars::slash_charge)
		{
			int frame = isThrowing(this) ?  (18 + int((float(spearman.spearTimer - SpearmanVars::slash_charge) / (SpearmanVars::slash_charge_level2 - SpearmanVars::slash_charge)) * 16)) :
						(1 + int((float(spearman.spearTimer - SpearmanVars::slash_charge) / (SpearmanVars::slash_charge_level2 - SpearmanVars::slash_charge)) * 9) * 2);
			getHUD().SetCursorFrame(frame);
		}
		// the yellow circle stays for the duration of a slash, helpful for newplayers (note: you cant attack while its yellow)
		else if (spearman.state == SpearmanStates::normal || spearman.state == SpearmanStates::resheathing_cut || spearman.state == SpearmanStates::resheathing_slash || spearman.state == SpearmanStates::resheathing_throw) // disappear after slash is done
		// the yellow circle dissapears after mouse button release, more intuitive for improving slash timing
		// else if (spearman.spearTimer == 0) (disappear right after mouse release)
		{
			getHUD().SetCursorFrame(0);
		}
		else if (spearman.spearTimer < SpearmanVars::slash_charge && spearman.state == SpearmanStates::spear_drawn)
		{
			int frame = isThrowing(this) ?  (0 + int((float(spearman.spearTimer) / SpearmanVars::slash_charge) * 18)) :
						(2 + int((float(spearman.spearTimer) / SpearmanVars::slash_charge) * 8) * 2);
			if (spearman.spearTimer <= SpearmanVars::resheath_cut_time) //prevent from appearing when jabbing/jab spamming
			{
				getHUD().SetCursorFrame(0);
			}
			else
			{
				getHUD().SetCursorFrame(frame);
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

	if (spearTypeNames.length == 0) return;

	// cycle spears
	SpearmanInfo@ spearman;
	if (!this.get("spearmanInfo", @spearman))
	{
		return;
	}
	u8 type = spearman.spear_type;

	int count = 0;
	while (count < spearTypeNames.length)
	{
		type++;
		count++;
		if (type >= spearTypeNames.length)
		{
			type = 0;
		}
		if (hasSpears(this, type))
		{
			CycleToSpearType(this, spearman, type);
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

	if (spearTypeNames.length == 0) return;

	u8 type;
	if (!params.saferead_u8(type)) return;

	SpearmanInfo@ spearman;
	if (!this.get("spearmanInfo", @spearman))
	{
		return;
	}

	if (hasSpears(this, type))
	{
		CycleToSpearType(this, spearman, type);
	}
}

void onSendCreateData(CBlob@ this, CBitStream@ params)
{
	SpearmanInfo@ spearman;
	if (!this.get("spearmanInfo", @spearman)) { return; }

	params.write_u8(spearman.spear_type);
}

bool onReceiveCreateData(CBlob@ this, CBitStream@ params)
{
	return ReceiveSpearState(this, params);
}

void onCommand(CBlob@ this, u8 cmd, CBitStream @params)
{
	if (cmd == this.getCommandID("spear sync") && isServer())
	{
		ReceiveSpearState(this, params);
	}
	else if (cmd == this.getCommandID("spear sync client") && isClient())
	{
		ReceiveSpearState(this, params);
	}
	else if (cmd == this.getCommandID("pickup spear") && isServer())
	{
		CBlob@ spear = getPickupSpear(this);

		if (spear !is null)
		{
			CBlob@ mat_spears = server_CreateBlobNoInit('mat_spears');

			if (mat_spears !is null)
			{
				mat_spears.Tag('custom quantity');
				mat_spears.Init();

				mat_spears.server_SetQuantity(1); // unnecessary

				if (not this.server_PutInInventory(mat_spears))
				{
					mat_spears.setPosition(this.getPosition());
				}

				if (spear !is null)
				{
					spear.server_Die();
				}
				else
				{
					canPickSpriteSpear(this, true);
				}
			}
			
			this.SendCommand(this.getCommandID("pickup spear client"));
		}
	}
	else if (cmd == this.getCommandID("pickup spear client") && isClient())
	{
		this.getSprite().PlaySound("Entities/Items/Projectiles/Sounds/ArrowHitGround.ogg");
	}
	else if (isServer())
	{
		SpearmanInfo@ spearman;
		if (!this.get("spearmanInfo", @spearman))
		{
			return;
		}
		for (uint i = 0; i < spearTypeNames.length; i++)
		{
			if (cmd == this.getCommandID("pick " + spearTypeNames[i]))
			{
				CBitStream params;
				params.write_u8(i);
				spearman.spear_type = i;
				this.SendCommand(this.getCommandID("spear sync client"), params);
				break;
			}
		}
	}
}

void CycleToSpearType(CBlob@ this, SpearmanInfo@ spearman, u8 spearType)
{
	spearman.spear_type = spearType;
	if (this.isMyPlayer())
	{
		Sound::Play("/CycleInventory.ogg");
	}
	ClientSendSpearState(this);
}


/////////////////////////////////////////////////

bool isJab(f32 damage)
{
	return damage < 1.5f;
}

void DoAttack(CBlob@ this, f32 damage, f32 aimangle, f32 arcdegrees, u8 type, int deltaInt, SpearmanInfo@ info)
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

	u8 attackType = info.spear_type;
	if(!hasSpears(this, attackType))
		attackType = 0;
	if(this.get_u8("specialhit") != 0)
		attackType = this.get_u8("specialhit");
	switch(attackType)
	{
		case SpearType::fire: type = Hitters::fire; break;
		default: type = Hitters::sword;
	}
	bool usedSpecialSpear = false;

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
				    || spearman_has_hit_actor(this, b)) 
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
					
					if (spearman_has_hit_actor(this, rayb)) 
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
					
					spearman_add_actor_limit(this, rayb);

					
					Vec2f velocity = rayb.getPosition() - pos;
					velocity.Normalize();
					velocity *= 12; // knockback force is same regardless of distance

					if (rayb.getTeamNum() != this.getTeamNum() || rayb.hasTag("dead player"))
					{
						// special hit
						// do it first, because of stun
						if ((type == Hitters::fire && rayb.hasScript("IsFlammable.as")) &&
							!(rayb.hasTag("shielded") && blockAttack(rayb, velocity, 0.0f)))// it works if it's not blocked with shield
						{
							usedSpecialSpear = true;
							this.server_Hit(rayb, rayInfos[j].hitpos, velocity, 0.0f, type, true);
						}

						this.server_Hit(rayb, rayInfos[j].hitpos, velocity, temp_damage, Hitters::sword, true);// normal hit
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
							//dont dig through no build zones
							canhit = map.getSectorAtPosition(tpos, "no build") is null;// check before checking jab, for fire spear

							if(wood && type == Hitters::fire)
							{
								map.server_setFireWorldspace(hi.hitpos, true);
								usedSpecialSpear = true;
							}

							if (jab) //fake damage
							{
								info.tileDestructionLimiter++;
								canhit = canhit && ((info.tileDestructionLimiter % ((wood || dirt_stone) ? 3 : 2)) == 0);
							}
							else //reset fake dmg for next time
							{
								info.tileDestructionLimiter = 0;
							}

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
					if(type == Hitters::fire)
					{
						map.server_setFireWorldspace(tilepos, true);
						usedSpecialSpear = true;
					}

					if (damage <= 1.0f)
					{
						break;
					}
				}
			}
	}

	if(!(type == Hitters::sword) && usedSpecialSpear && this.get_u8("specialhit") == 0)
	{
		this.TakeBlob(spearTypeNames[info.spear_type], 1);
		this.set_u8("specialhit", info.spear_type);
		if(this.getBlobCount(spearTypeNames[info.spear_type]) == 0)
			this.SendCommand(this.getCommandID("pick mat_spears"));
	}
}

void DoThrow(CBlob@ this, SpearmanInfo info)
{
	if (!getNet().isServer())
	{
		return;
	}

	if (!hasSpears(this, info.spear_type))
	{
		return;
	}

	CBlob@ spear = server_CreateBlobNoInit("spear");
	if (spear !is null)
	{
		// fire spear?
		spear.set_u8("spear type", info.spear_type);
		spear.SetDamageOwnerPlayer(this.getPlayer());
		spear.Init();

		Vec2f offset(this.isFacingLeft() ? 2 : -2, -2);
		Vec2f spearPos = this.getPosition() + offset;
		Vec2f spearVel = this.getAimPos() - spearPos;
		spearVel.Normalize();
		Vec2f spearOffset = spearVel;
		spearVel *= SpearmanVars::shoot_max_vel;

		spear.IgnoreCollisionWhileOverlapped(this);
		spear.server_setTeamNum(this.getTeamNum());
		spear.setPosition(spearPos + spearOffset * 2);
		spear.setVelocity(spearVel);
		this.TakeBlob(spearTypeNames[info.spear_type], 1);
	}
	if(this.getBlobCount(spearTypeNames[info.spear_type]) == 0)
		this.SendCommand(this.getCommandID("pick mat_spears"));
	//return spear;
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

void onHitBlob(CBlob@ this, Vec2f worldPoint, Vec2f velocity, f32 damage, CBlob@ hitBlob, u8 customData)
{
	SpearmanInfo@ spearman;
	if (!this.get("spearmanInfo", @spearman))
	{
		return;
	}

	if ((customData == Hitters::sword || customData == Hitters::fire) &&
	        ( //is a jab - note we dont have the dmg in here at the moment :/
	            spearman.state == SpearmanStates::spear_cut_mid ||
	            spearman.state == SpearmanStates::spear_cut_mid_down ||
	            spearman.state == SpearmanStates::spear_cut_up ||
	            spearman.state == SpearmanStates::spear_cut_down
	        )
	        && blockAttack(hitBlob, velocity, 0.0f))
	{
		this.getSprite().PlaySound("/Stun", 1.0f, this.getSexNum() == 0 ? 1.0f : 1.5f);
		setKnocked(this, 30, true);
	}
	if (customData == Hitters::fire && hitBlob.getName() == "keg" && !hitBlob.hasTag("exploding"))
	{
		hitBlob.SendCommand(hitBlob.getCommandID("activate"));
	}
}

void Callback_PickSpear(CBitStream@ params)
{
	CPlayer@ player = getLocalPlayer();
	if (player is null) return;

	CBlob@ blob = player.getBlob();
	if (blob is null) return;

	u8 spear_id;
	if (!params.saferead_u8(spear_id)) return;

	SpearmanInfo@ spearman;
	if (!blob.get("spearmanInfo", @spearman))
	{
		return;
	}

	spearman.spear_type = spear_id;

	string matname = spearTypeNames[spear_id];
	blob.SendCommand(blob.getCommandID("pick " + matname));
}

// spear pick menu
void onCreateInventoryMenu(CBlob@ this, CBlob@ forBlob, CGridMenu @gridmenu)
{
	if (spearTypeNames.length == 0)
	{
		return;
	}

	this.ClearGridMenusExceptInventory();
	Vec2f pos(gridmenu.getUpperLeftPosition().x + 0.5f * (gridmenu.getLowerRightPosition().x - gridmenu.getUpperLeftPosition().x),
	          gridmenu.getUpperLeftPosition().y - 32 * 1 - 2 * 24);
	CGridMenu@ menu = CreateGridMenu(pos, this, Vec2f(spearTypeNames.length, 2), "Current spear");

	SpearmanInfo@ spearman;
	if (!this.get("spearmanInfo", @spearman))
	{
		return;
	}
	const u8 spearSel = spearman.spear_type;

	if (menu !is null)
	{
		menu.deleteAfterClick = false;

		for (uint i = 0; i < spearTypeNames.length; i++)
		{
			CBitStream params;
			params.write_u8(i);
			CGridButton @button = menu.AddButton(spearIcons[i], spearNames[i], "SpearmanLogic.as", "Callback_PickSpear", params);

			if (button !is null)
			{
				bool enabled = this.getBlobCount(spearTypeNames[i]) > 0 || i == SpearType::normal;// normal spear always selectable
				button.SetEnabled(enabled);
				button.selectOneOnClick = true;

				//if (enabled && i == SpearType::fire && !hasReqs(this, i))
				//{
				//	button.hoverText = "Requires a fire source $lantern$";
				//	//button.SetEnabled( false );
				//}

				if (spearSel == i)
				{
					button.SetSelected(1);
				}
			}
		}
	}
}

void onAttach(CBlob@ this, CBlob@ attached, AttachmentPoint @ap)
{
	if (!ap.socket) {
		SpearmanInfo@ spearman;
		if (!this.get("spearmanInfo", @spearman))
		{
			return;
		}

		spearman.state = SpearmanStates::normal; //cancel any attacks or shielding
		spearman.spearTimer = 0;
		spearman.doubleslash = false;
		this.set_s32("currentSpearmanState", 0);
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