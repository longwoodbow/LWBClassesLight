//Assassin Include
const f32 assassin_grapple_length = 72.0f;
const f32 assassin_grapple_slack = 16.0f;
const f32 assassin_grapple_throw_speed = 20.0f;

const f32 assassin_grapple_force = 2.0f;
const f32 assassin_grapple_accel_limit = 1.5f;
const f32 assassin_grapple_stiffness = 0.1f;

shared class AssassinInfo
{
	u32 stab_timer;

	u8 tileDestructionLimiter;
	//bool dontHitMore;

	bool grappling;
	u16 grapple_id;
	f32 grapple_ratio;
	f32 cache_angle;
	Vec2f grapple_pos;
	Vec2f grapple_vel;

	bool use_left;
	AssassinInfo()
	{
		//stab_delay = 0;
		tileDestructionLimiter = 0;
		grappling = false;
		use_left = false;
	}
};

const string grapple_sync_cmd = "grapple sync";

void SyncGrapple(CBlob@ this)
{
	AssassinInfo@ assassin;
	if (!this.get("assassinInfo", @assassin)) { return; }

	if (isClient()) return;

	CBitStream bt;
	bt.write_bool(assassin.grappling);

	if (assassin.grappling)
	{
		bt.write_u16(assassin.grapple_id);
		bt.write_u8(u8(assassin.grapple_ratio * 250));
		bt.write_Vec2f(assassin.grapple_pos);
		bt.write_Vec2f(assassin.grapple_vel);
	}

	this.SendCommand(this.getCommandID(grapple_sync_cmd), bt);
}

//TODO: saferead
void HandleGrapple(CBlob@ this, CBitStream@ bt, bool apply)
{
	AssassinInfo@ assassin;
	if (!this.get("assassinInfo", @assassin)) { return; }

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
		assassin.grappling = grappling;
		if (assassin.grappling)
		{
			assassin.grapple_id = grapple_id;
			assassin.grapple_ratio = grapple_ratio;
			assassin.grapple_pos = grapple_pos;
			assassin.grapple_vel = grapple_vel;
		}
	}
}

bool isKnifeAnim(CSprite@ this)
{
	return this.isAnimation("stab_up") ||
	this.isAnimation("stab_up_left") ||
	this.isAnimation("stab_mid") ||
	this.isAnimation("stab_mid_left") ||
	this.isAnimation("stab_down") ||
	this.isAnimation("stab_down_left");
}