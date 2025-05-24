//common warhammer header
#include "RunnerCommon.as";

namespace WarhammerStates
{
	enum States
	{
		normal = 0,
		flail,
		flailthrow,
		hammer_drawn,
		hammer_cut_mid,
		hammer_cut_mid_down,
		hammer_cut_up,
		hammer_cut_down,
		hammer_power,
		resheathing_cut,
		resheathing_slash
	}
}

namespace WarhammerVars
{
	const ::s32 resheath_cut_time = 2;
	const ::s32 resheath_slash_time = 2;

	const ::s32 slash_charge = 22;
	const ::s32 slash_charge_limit = slash_charge + 15;
	const ::s32 slash_move_time = 4;
	const ::s32 slash_time = 17;

	const ::f32 slash_move_max_speed = 7.0f;//from 3.5

	const ::s32 flail_ready = 20;
	const ::s32 flail_charge = flail_ready + 20;
	const ::s32 flail_charge_limit = flail_charge + 30;
}

const f32 warhammer_flail_length = 72.0f;
const f32 warhammer_flail_slack = 16.0f;
const f32 warhammer_flail_throw_speed = 20.0f;

const f32 warhammer_flail_force = 2.0f;
const f32 warhammer_flail_accel_limit = 1.5f;
const f32 warhammer_flail_stiffness = 0.1f;

shared class WarhammerInfo
{
	u16 hammerTimer;
	u8 tileDestructionLimiter;
	bool decreasing;

	u8 state;
	Vec2f slash_direction;
	s32 flail_down;

	bool flail;
	f32 flail_ratio;
	f32 cache_angle;
	Vec2f flail_pos;
	Vec2f flail_vel;
	bool flail_power;
	bool flail_hit_map;
};

shared class WarhammerState
{
	u32 stateEnteredTime = 0;

	WarhammerState() {}
	u8 getStateValue() { return 0; }
	void StateEntered(CBlob@ this, WarhammerInfo@ warhammer, u8 previous_state) {}
	// set warhammer.state to change states
	// return true if we should tick the next state right away
	bool TickState(CBlob@ this, WarhammerInfo@ warhammer, RunnerMoveVars@ moveVars) { return false; }
	void StateExited(CBlob@ this, WarhammerInfo@ warhammer, u8 next_state) {}
}


bool getInAir(CBlob@ this)// from knight "logic", but i used it on anim too
{
	bool inair = (!this.isOnGround() && !this.isOnLadder());
	return inair;

}

const string flail_sync_cmd = "flail sync";

void SyncFlail(CBlob@ this)
{
	WarhammerInfo@ warhammer;
	if (!this.get("warhammerInfo", @warhammer)) { return; }

	if (isClient()) return;

	CBitStream bt;
	bt.write_bool(warhammer.flail);

	if (warhammer.flail)
	{
		bt.write_u8(u8(warhammer.flail_ratio * 250));
		bt.write_Vec2f(warhammer.flail_pos);
		bt.write_Vec2f(warhammer.flail_vel);
	}

	this.SendCommand(this.getCommandID(flail_sync_cmd), bt);
}

//TODO: saferead
void HandleFlail(CBlob@ this, CBitStream@ bt, bool apply)
{
	WarhammerInfo@ warhammer;
	if (!this.get("warhammerInfo", @warhammer)) { return; }

	bool flail;
	f32 flail_ratio;
	Vec2f flail_pos;
	Vec2f flail_vel;

	flail = bt.read_bool();

	if (flail)
	{
		u8 temp = bt.read_u8();
		flail_ratio = temp / 250.0f;
		flail_pos = bt.read_Vec2f();
		flail_vel = bt.read_Vec2f();
	}

	if (apply)
	{
		warhammer.flail = flail;
		if (warhammer.flail)
		{
			warhammer.flail_ratio = flail_ratio;
			warhammer.flail_pos = flail_pos;
			warhammer.flail_vel = flail_vel;
		}
	}
}

//checking state stuff

bool isFlailState(u8 state)
{
	return (state >= WarhammerStates::flail && state <= WarhammerStates::flailthrow);
}

bool isHammerState(u8 state)
{
	return (state >= WarhammerStates::hammer_drawn && state <= WarhammerStates::resheathing_slash);
}

bool inMiddleOfAttack(u8 state)
{
	return ((state > WarhammerStates::hammer_drawn && state <= WarhammerStates::hammer_power));
}

//checking angle stuff

f32 getCutAngle(CBlob@ this, u8 state)
{
	f32 attackAngle = (this.isFacingLeft() ? 180.0f : 0.0f);

	if (state == WarhammerStates::hammer_cut_mid)
	{
		attackAngle += (this.isFacingLeft() ? 30.0f : -30.0f);
	}
	else if (state == WarhammerStates::hammer_cut_mid_down)
	{
		attackAngle -= (this.isFacingLeft() ? 30.0f : -30.0f);
	}
	else if (state == WarhammerStates::hammer_cut_up)
	{
		attackAngle += (this.isFacingLeft() ? 80.0f : -80.0f);
	}
	else if (state == WarhammerStates::hammer_cut_down)
	{
		attackAngle -= (this.isFacingLeft() ? 80.0f : -80.0f);
	}

	return attackAngle;
}

f32 getCutAngle(CBlob@ this)
{
	Vec2f aimpos = this.getMovement().getVars().aimpos;
	int tempState;
	Vec2f vec;
	int direction = this.getAimDirection(vec);

	if (direction == -1)
	{
		tempState = WarhammerStates::hammer_cut_up;
	}
	else if (direction == 0)
	{
		if (aimpos.y < this.getPosition().y)
		{
			tempState = WarhammerStates::hammer_cut_mid;
		}
		else
		{
			tempState = WarhammerStates::hammer_cut_mid_down;
		}
	}
	else
	{
		tempState = WarhammerStates::hammer_cut_down;
	}

	return getCutAngle(this, tempState);
}

//shared attacking/bashing constants (should be in WarhammerVars but used all over)

const int DELTA_BEGIN_ATTACK = 3;
const int DELTA_END_ATTACK = 7;
const f32 DEFAULT_ATTACK_DISTANCE = 20.0f;//from 16
const f32 MAX_ATTACK_DISTANCE = 24.0f;//from 18
