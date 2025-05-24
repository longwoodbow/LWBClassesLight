// BuilderCommon.as

shared class DemolitionistInfo
{
	u8 action_type;

	bool grappling;
	u16 grapple_id;
	f32 grapple_ratio;
	f32 cache_angle;
	Vec2f grapple_pos;
	Vec2f grapple_vel;

	DemolitionistInfo()
	{
		action_type = ActionType::nothing;
		grappling = false;
	}
};

const f32 demolitionist_grapple_length = 72.0f;
const f32 demolitionist_grapple_slack = 16.0f;
const f32 demolitionist_grapple_throw_speed = 20.0f;

const f32 demolitionist_grapple_force = 2.0f;
const f32 demolitionist_grapple_accel_limit = 1.5f;
const f32 demolitionist_grapple_stiffness = 0.1f;

namespace ActionType
{
	enum type
	{
		nothing = 0,
		pickaxe,
		bomb,
		wood,
		stone,
		count
	};
}

u8 getActionType(CBlob@ this)
{
	DemolitionistInfo@ demolitionist;
	if (!this.get("demolitionistInfo", @demolitionist))
	{
		return 0;
	}
	return demolitionist.action_type;
}

bool isPickaxeTime(CBlob@ this)
{
	DemolitionistInfo@ demolitionist;
	if (!this.get("demolitionistInfo", @demolitionist))
	{
		return false;
	}
	return demolitionist.action_type == ActionType::pickaxe;
}

bool isBuildTime(CBlob@ this)
{
	DemolitionistInfo@ demolitionist;
	if (!this.get("demolitionistInfo", @demolitionist))
	{
		return false;
	}
	return demolitionist.action_type >= ActionType::bomb && demolitionist.action_type < ActionType::count;
}

const string grapple_sync_cmd = "grapple sync";

void SyncGrapple(CBlob@ this)
{
	DemolitionistInfo@ demolitionist;
	if (!this.get("demolitionistInfo", @demolitionist)) { return; }

	if (isClient()) return;

	CBitStream bt;
	bt.write_bool(demolitionist.grappling);

	if (demolitionist.grappling)
	{
		bt.write_u16(demolitionist.grapple_id);
		bt.write_u8(u8(demolitionist.grapple_ratio * 250));
		bt.write_Vec2f(demolitionist.grapple_pos);
		bt.write_Vec2f(demolitionist.grapple_vel);
	}

	this.SendCommand(this.getCommandID(grapple_sync_cmd), bt);
}

//TODO: saferead
void HandleGrapple(CBlob@ this, CBitStream@ bt, bool apply)
{
	DemolitionistInfo@ demolitionist;
	if (!this.get("demolitionistInfo", @demolitionist)) { return; }

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
		demolitionist.grappling = grappling;
		if (demolitionist.grappling)
		{
			demolitionist.grapple_id = grapple_id;
			demolitionist.grapple_ratio = grapple_ratio;
			demolitionist.grapple_pos = grapple_pos;
			demolitionist.grapple_vel = grapple_vel;
		}
	}
}
