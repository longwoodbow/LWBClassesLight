//Musketman Include
#include "Requirements.as";

namespace MusketmanParams
{
	enum Aim
	{
		not_aiming = 0,
		readying,
		charging,
		discharging,
		no_bullets,
		digging
	}
	const ::s32 ready_time = 11;
	
	const ::s32 shoot_period = 75;
	const ::s32 charge_limit = 30;

	const ::f32 shoot_max_vel = 50.0f;//35.18f;
}

shared class MusketmanInfo
{
	s8 charge_time;
	u8 charge_state;
	bool has_bullet;
	bool has_barricade;
	u8 dig_delay;
	u8 buildmode;

	MusketmanInfo()
	{
		charge_time = 0;
		charge_state = 0;
		has_bullet = false;
		has_barricade = false;
		buildmode = MusketmanBuilding::nothing;
	}
};

namespace MusketmanBuilding
{
	enum Building
	{
		nothing,
		barricade,
		count
	}
}

bool hasBullets(CBlob@ this)
{
	return this.getBlobCount("mat_bullets") > 0;
}

bool hasBarricades(CBlob@ this)
{
	return this.getBlobCount("mat_barricades") > 0;
}

bool isBuildTime(CBlob@ this)
{
	return getBuildMode(this) > MusketmanBuilding::nothing;
}

u8 getBuildMode(CBlob@ this)
{	
	MusketmanInfo@ musketman;
	if (!this.get("musketmanInfo", @musketman))
	{
		return 0;
	}
	return musketman.buildmode;
}