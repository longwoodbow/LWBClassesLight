//common weaponthrower header
#include "RunnerCommon.as";

namespace WeaponthrowerStates
{
	enum States
	{
		normal = 0,
		shielding,
		shielddropping,
		shieldgliding,
		weapon_drawn,
		weapon_throw,
		weapon_throw_super,
		resheathing_throw
	}
}

namespace WeaponthrowerVars
{
	const ::s32 resheath_throw_time = 2;

	const ::s32 throw_charge = 15;
	const ::s32 throw_charge_level2 = 38;
	const ::s32 throw_charge_limit = throw_charge_level2 + throw_charge + 10;
	const ::s32 throw_time = 13;
	const ::s32 double_throw_time = 8;

	const u32 glide_down_time = 50;

	//// OLD MOD COMPATIBILITY ////
	// These have no purpose in the current code base other then
	// to allow old mods to still run without needing manual fixing
	const f32 resheath_time = 2.0f;
}

shared class WeaponthrowerInfo
{
	u8 weaponTimer;
	bool doublethrow;
	u32 slideTime;

	u8 state;
	s32 shield_down;

	u8 weapon_type;
	u8 fletch_cooldown;
};

shared class WeaponthrowerState
{
	u32 stateEnteredTime = 0;

	WeaponthrowerState() {}
	u8 getStateValue() { return 0; }
	void StateEntered(CBlob@ this, WeaponthrowerInfo@ weaponthrower, u8 previous_state) {}
	// set weaponthrower.state to change states
	// return true if we should tick the next state right away
	bool TickState(CBlob@ this, WeaponthrowerInfo@ weaponthrower, RunnerMoveVars@ moveVars) { return false; }
	void StateExited(CBlob@ this, WeaponthrowerInfo@ weaponthrower, u8 next_state) {}
}

void ClientSendWeaponState(CBlob@ this)
{
	if (!isClient()) { return; }
	if (isServer()) { return; } // no need to sync on localhost

	WeaponthrowerInfo@ weaponthrower;
	if (!this.get("weaponthrowerInfo", @weaponthrower)) { return; }

	CBitStream params;
	params.write_u8(weaponthrower.weapon_type);

	this.SendCommand(this.getCommandID("weapon sync"), params);
}

bool ReceiveWeaponState(CBlob@ this, CBitStream@ params)
{
	// valid both on client and server

	if (isServer() && isClient()) { return false; }

	WeaponthrowerInfo@ weaponthrower;
	if (!this.get("weaponthrowerInfo", @weaponthrower)) { return false; }

	weaponthrower.weapon_type = 0;
	if (!params.saferead_u8(weaponthrower.weapon_type)) { return false; }

	if (isServer())
	{
		CBitStream reserialized;
		reserialized.write_u8(weaponthrower.weapon_type);

		this.SendCommand(this.getCommandID("weapon sync client"), reserialized);
	}

	return true;
}

namespace WeaponType
{
	enum type
	{
		boomerang = 0,
		chakram,
		count
	};
}

const string[] weaponNames = { "Boomerang",
                             "Chakram"
                           };

const string[] weaponIcons = { "$Boomerang$",
                             "$Chakram$"
                           };

const string[] weaponTypeNames = { "mat_boomerangs",
                                 "mat_chakrams"
                               };


bool hasWeapons(CBlob@ this)
{
	WeaponthrowerInfo@ weaponthrower;
	if (!this.get("weaponthrowerInfo", @weaponthrower))
	{
		return false;
	}
	if (weaponthrower.weapon_type >= 0 && weaponthrower.weapon_type < weaponTypeNames.length)
	{
		return this.getBlobCount(weaponTypeNames[weaponthrower.weapon_type]) > 0;
	}
	return false;
}

bool hasWeapons(CBlob@ this, u8 weaponType)
{
	if (this is null) return false;
	
	return weaponType < weaponTypeNames.length && this.hasBlob(weaponTypeNames[weaponType], 1);
}

void SetWeaponType(CBlob@ this, const u8 type)
{
	WeaponthrowerInfo@ weaponthrower;
	if (!this.get("weaponthrowerInfo", @weaponthrower))
	{
		return;
	}
	weaponthrower.weapon_type = type;
}

u8 getWeaponType(CBlob@ this)
{
	WeaponthrowerInfo@ weaponthrower;
	if (!this.get("weaponthrowerInfo", @weaponthrower))
	{
		return 0;
	}
	return weaponthrower.weapon_type;
}

//checking state stuff

bool isShieldState(u8 state)
{
	return (state >= WeaponthrowerStates::shielding && state <= WeaponthrowerStates::shieldgliding);
}

bool isSpecialShieldState(u8 state)
{
	return (state > WeaponthrowerStates::shielding && state <= WeaponthrowerStates::shieldgliding);
}

bool isWeaponState(u8 state)
{
	return (state >= WeaponthrowerStates::weapon_drawn && state <= WeaponthrowerStates::resheathing_throw);
}

bool inMiddleOfAttack(u8 state)
{
	return ((state > WeaponthrowerStates::weapon_drawn && state <= WeaponthrowerStates::weapon_throw_super));
}

//shared attacking/bashing constants (should be in WeaponthrowerVars but used all over)

const int DELTA_BEGIN_ATTACK = 2;
const int DELTA_END_ATTACK = 5;
const f32 SHIELD_KNOCK_VELOCITY = 3.0f;

const f32 SHIELD_BLOCK_ANGLE = 175.0f;
const f32 SHIELD_BLOCK_ANGLE_GLIDING = 140.0f;
const f32 SHIELD_BLOCK_ANGLE_SLIDING = 160.0f;

const int FLETCH_COOLDOWN = 45;
const int PICKUP_COOLDOWN = 15;