//Duelist Include
const f32 duelist_grapple_length = 72.0f;
const f32 duelist_grapple_slack = 16.0f;
const f32 duelist_grapple_throw_speed = 20.0f;

const f32 duelist_grapple_force = 2.0f;
const f32 duelist_grapple_accel_limit = 1.5f;
const f32 duelist_grapple_stiffness = 0.1f;

namespace DuelistVars
{
	const ::s32 resheath_cut_time = 2;
	const ::s32 resheath_slash_time = 2;

	const ::s32 slash_charge = 10;// from 15
	//const ::s32 slash_charge_level2 = 38; // no double slash
	const ::s32 slash_charge_limit = /*slash_charge_level2 +*/ slash_charge + 20; // knight's limit summary is slash_charge_level2(38) + slash_charge(15) + 10
	const ::s32 slash_move_time = 4;
	const ::s32 slash_time = 9;// from 13

	const ::f32 slash_move_max_speed = 3.5f;
}

namespace DuelistStates
{
	enum States
	{
		normal = 0,
		rapier_drawn,
		rapier_cut,
		rapier_power,
		resheathing_cut,
		resheathing_slash
	}
}

shared class DuelistInfo
{
	u8 rapierTimer;
	u8 tileDestructionLimiter;
	u8 state;
	Vec2f slash_direction;
	bool decrease;

	bool grappling;
	u16 grapple_id;
	f32 grapple_ratio;
	f32 cache_angle;
	Vec2f grapple_pos;
	Vec2f grapple_vel;

	DuelistInfo()
	{
		grappling = false;
	}
};

shared class DuelistState
{
	u32 stateEnteredTime = 0;

	DuelistState() {}
	u8 getStateValue() { return 0; }
	void StateEntered(CBlob@ this, DuelistInfo@ duelist, u8 previous_state) {}
	// set knight.state to change states
	// return true if we should tick the next state right away
	bool TickState(CBlob@ this, DuelistInfo@ duelist, RunnerMoveVars@ moveVars) { return false; }
	void StateExited(CBlob@ this, DuelistInfo@ duelist, u8 next_state) {}
}

//checking state stuff

bool isRapierState(u8 state)
{
	return (state >= DuelistStates::rapier_drawn && state <= DuelistStates::resheathing_slash);
}

bool inMiddleOfAttack(u8 state)
{
	return (state > DuelistStates::rapier_drawn && state <= DuelistStates::rapier_power);
}

const string grapple_sync_cmd = "grapple sync";

void SyncGrapple(CBlob@ this)
{
	DuelistInfo@ duelist;
	if (!this.get("duelistInfo", @duelist)) { return; }

	if (isClient()) return;

	CBitStream bt;
	bt.write_bool(duelist.grappling);

	if (duelist.grappling)
	{
		bt.write_u16(duelist.grapple_id);
		bt.write_u8(u8(duelist.grapple_ratio * 250));
		bt.write_Vec2f(duelist.grapple_pos);
		bt.write_Vec2f(duelist.grapple_vel);
	}

	this.SendCommand(this.getCommandID(grapple_sync_cmd), bt);
}

//TODO: saferead
void HandleGrapple(CBlob@ this, CBitStream@ bt, bool apply)
{
	DuelistInfo@ duelist;
	if (!this.get("duelistInfo", @duelist)) { return; }

	bool grappling;
	u16 grapple_id;
	f32 grapple_ratio;
	Vec2f grapple_pos;
	Vec2f grapple_vel;

	grappling = bt.read_bool();

	if (grappling)
	{
		grapple_id = bt.read_u16();
		u8 temp = bt.read_u8();
		grapple_ratio = temp / 250.0f;
		grapple_pos = bt.read_Vec2f();
		grapple_vel = bt.read_Vec2f();
	}

	if (apply)
	{
		duelist.grappling = grappling;
		if (duelist.grappling)
		{
			duelist.grapple_id = grapple_id;
			duelist.grapple_ratio = grapple_ratio;
			duelist.grapple_pos = grapple_pos;
			duelist.grapple_vel = grapple_vel;
		}
	}
}

bool isRapierAnim(CSprite@ this)
{
	return this.isAnimation("stab_up") ||
	this.isAnimation("stab_up_left") ||
	this.isAnimation("stab_mid");
}

//shared attacking/bashing constants (should be in DuelistVars but used all over)

const int DELTA_BEGIN_ATTACK = 2;
const int DELTA_END_ATTACK = 5;
const f32 DEFAULT_ATTACK_DISTANCE = 16.0f;
const f32 MAX_ATTACK_DISTANCE = 18.0f;