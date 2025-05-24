//Gunner Include

namespace GunnerParams
{
	enum Aim
	{
		not_aiming = 0,
		readying,
		charging,
		fired,
		no_bullets,
		legolas_ready,
		legolas_charging
	}
	const ::s32 ready_time = 11;
	
	const ::s32 shoot_period = 50;
	const ::s32 legolas_period = GunnerParams::shoot_period * 3;
	const ::s32 snipe_period = GunnerParams::shoot_period * 2;
	const ::s32 legolas_charge_time = 5;
	const ::s32 legolas_time = 60;
	const ::s32 fired_time = 7;

	const ::f32 shoot_max_vel = 50.0f;//35.18f;
}
//TODO: move vars into gunner params namespace
const f32 gunner_grapple_length = 72.0f;
const f32 gunner_grapple_slack = 16.0f;
const f32 gunner_grapple_throw_speed = 20.0f;

const f32 gunner_grapple_force = 2.0f;
const f32 gunner_grapple_accel_limit = 1.5f;
const f32 gunner_grapple_stiffness = 0.1f;

namespace ShootType
{
	enum type
	{
		snipe = 0,
		doubleshoot,
		count
	};
}

const string[] shootNames = { "Snipe",
                              "Double Pistol"
                            };

const string[] shootIcons = { "$SnipeShoot$",
                              "$DoubleShoot$"
                            };

shared class GunnerInfo
{
	s16 charge_time;
	u8 charge_state;
	bool has_bullet;
	u8 shoot_type;

	u8 legolas_bullets;
	u8 legolas_time;

	bool grappling;
	u16 grapple_id;
	f32 grapple_ratio;
	f32 cache_angle;
	Vec2f grapple_pos;
	Vec2f grapple_vel;

	GunnerInfo()
	{
		charge_time = 0;
		charge_state = 0;
		has_bullet = false;
		shoot_type = ShootType::snipe;
		grappling = false;
	}
};

void ClientSendShootState(CBlob@ this)
{
	if (!isClient()) { return; }
	if (isServer()) { return; } // no need to sync on localhost

	GunnerInfo@ gunner;
	if (!this.get("gunnerInfo", @gunner)) { return; }

	CBitStream params;
	params.write_u8(gunner.shoot_type);

	this.SendCommand(this.getCommandID("style sync"), params);
}

bool ReceiveShootState(CBlob@ this, CBitStream@ params)
{
	// valid both on client and server

	if (isServer() && isClient()) { return false; }

	GunnerInfo@ gunner;
	if (!this.get("gunnerInfo", @gunner)) { return false; }

	gunner.shoot_type = 0;
	if (!params.saferead_u8(gunner.shoot_type)) { return false; }

	if (isServer())
	{
		CBitStream reserialized;
		reserialized.write_u8(gunner.shoot_type);

		this.SendCommand(this.getCommandID("style sync client"), reserialized);
	}

	return true;
}

const string grapple_sync_cmd = "grapple sync";

void SyncGrapple(CBlob@ this)
{
	GunnerInfo@ gunner;
	if (!this.get("gunnerInfo", @gunner)) { return; }

	if (isClient()) return;

	CBitStream bt;
	bt.write_bool(gunner.grappling);

	if (gunner.grappling)
	{
		bt.write_u16(gunner.grapple_id);
		bt.write_u8(u8(gunner.grapple_ratio * 250));
		bt.write_Vec2f(gunner.grapple_pos);
		bt.write_Vec2f(gunner.grapple_vel);
	}

	this.SendCommand(this.getCommandID(grapple_sync_cmd), bt);
}

//TODO: saferead
void HandleGrapple(CBlob@ this, CBitStream@ bt, bool apply)
{
	GunnerInfo@ gunner;
	if (!this.get("gunnerInfo", @gunner)) { return; }

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
		gunner.grappling = grappling;
		if (gunner.grappling)
		{
			gunner.grapple_id = grapple_id;
			gunner.grapple_ratio = grapple_ratio;
			gunner.grapple_pos = grapple_pos;
			gunner.grapple_vel = grapple_vel;
		}
	}
}

bool hasBullets(CBlob@ this)
{
	if (this is null) return false;

	return this.hasBlob("mat_bullets", 1);
}

void SetShootType(CBlob@ this, const u8 type)
{
	GunnerInfo@ gunner;
	if (!this.get("gunnerInfo", @gunner))
	{
		return;
	}
	gunner.shoot_type = type;
}

u8 getShootType(CBlob@ this)
{
	GunnerInfo@ gunner;
	if (!this.get("gunnerInfo", @gunner))
	{
		return 0;
	}
	return gunner.shoot_type;
}
