// ChopperCommon.as
#include "RunnerCommon.as";

//use it when use axe, not mattock
namespace ChopperStates
{
	enum States
	{
		normal = 0,
		axe_drawn,
		chop,
		chop_power,
		resheathing
	}
}

namespace ChopperVars
{
	const ::s32 resheath_time = 2;

	const ::s32 slash_charge = 15;
	const ::s32 slash_charge_limit = slash_charge + 10;
	const ::s32 slash_move_time = 4;
	const ::s32 slash_time = 13;

	const ::f32 slash_move_max_speed = 3.5f;
}

shared class ChopperInfo
{
	u8 axeTimer;
	bool decreasing;
	u8 tileDestructionLimiter;

	//u8 tool_type;

	u8 state;
	Vec2f slash_direction;
};

void ClientSendToolState(CBlob@ this)
{
	if (!isClient()) { return; }
	if (isServer()) { return; } // no need to sync on localhost

	CBitStream params;
	params.write_u8(this.get_u8("tool_type"));

	this.SendCommand(this.getCommandID("tool sync"), params);
}

bool ReceiveToolState(CBlob@ this, CBitStream@ params)
{
	// valid both on client and server

	if (isServer() && isClient()) { return false; }

	u8 tool_type;
	if (!params.saferead_u8(tool_type)) { return false; }
	this.set_u8("tool_type", tool_type);

	if (isServer())
	{
		CBitStream reserialized;
		reserialized.write_u8(this.get_u8("tool_type"));

		this.SendCommand(this.getCommandID("tool sync client"), reserialized);
	}

	return true;
}

shared class ChopperState
{
	u32 stateEnteredTime = 0;

	ChopperState() {}
	u8 getStateValue() { return 0; }
	void StateEntered(CBlob@ this, ChopperInfo@ chopper, u8 previous_state) {}
	// set chopper.state to change states
	// return true if we should tick the next state right away
	bool TickState(CBlob@ this, ChopperInfo@ chopper, RunnerMoveVars@ moveVars) { return false; }
	void StateExited(CBlob@ this, ChopperInfo@ chopper, u8 next_state) {}
}

bool isStrikeAnim(CSprite@ this)
{
	return this.isAnimation("strike") || this.isAnimation("strike_fast") || this.isAnimation("strike_chop") || this.isAnimation("strike_chop_fast");
}

namespace ToolType
{
	enum type
	{
		axe = 0,
		mattock,
		count
	};
}

const string[] toolNames = { "Axe",
                             "Mattock for mining"
                           };

const string[] toolIcons = { "$Chopper_Axe$",
                             "$Mattock$"
                           };
                           
const int DELTA_BEGIN_ATTACK = 2;
const int DELTA_END_ATTACK = 5;
const f32 DEFAULT_ATTACK_DISTANCE = 16.0f;
const f32 MAX_ATTACK_DISTANCE = 18.0f;