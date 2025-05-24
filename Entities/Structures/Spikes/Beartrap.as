#include "Hitters.as"

enum spike_state
{
	normal = 0,
	stabbing
};

const string state_prop = "popup state";

void onInit(CBlob@ this)
{
	CShape@ shape = this.getShape();
	ShapeConsts@ consts = shape.getConsts();
	consts.mapCollisions = false;	 // we have our own map collision

	this.Tag("place norotate");
	this.Tag("builder always hit");
	this.Tag("builder urgent hit");
	this.Tag("builder fast hittable");

	this.getCurrentScript().runFlags |= Script::tick_not_attached;
	//dont set radius flags here so we orient to the ground first

	this.set_u8(state_prop, normal);
}

void onSetStatic(CBlob@ this, const bool isStatic)
{
	if (!isStatic) return;

	this.getSprite().PlaySound("/build_wall2.ogg");
}

//specific tile checking logic for the spikes
void tileCheck(CBlob@ this, CMap@ map, Vec2f pos)
{
	TileType t = map.getTile(pos).type;

	if (!map.isTileSolid(t))
	{
		this.server_Hit(this, pos, Vec2f(0, -1), 3.0f, Hitters::fall, true);
	}
}

void onTick(CBlob@ this)
{
	CMap@ map = getMap();
	Vec2f pos = this.getPosition();
	const f32 tilesize = map.tilesize;

	if (!(getNet().isServer() && this.getShape().isStatic())) return;

	if (map.isTileSolid(map.getTile(pos)) || map.rayCastSolid(pos - this.getVelocity(), pos))
	{
		this.server_Hit(this, pos, Vec2f(0, -1), 3.0f, Hitters::fall, true);
		return;
	}

	tileCheck(this, map, pos + Vec2f(0.0f, tilesize));// die if not on block
}

void setTrapped(CBlob@ this)
{
	if (this.get_u8(state_prop) == stabbing) return;// no double effect
	this.getSprite().SetAnimation("trapped");
	this.set_u8(state_prop, stabbing);
	this.server_SetTimeToDie(0.6f);
	this.getSprite().PlaySound("/metal_stone.ogg");
}

bool canStab(CBlob@ b)
{
	return !b.hasTag("dead") && b.hasTag("flesh");
}

bool doesCollideWithBlob(CBlob@ this, CBlob@ blob)
{
	return this.get_u8(state_prop) == normal && blob.hasTag("projectile") && blob.getTeamNum() != this.getTeamNum();
}

//physics logic
void onCollision(CBlob@ this, CBlob@ blob, bool solid, Vec2f normal, Vec2f point)
{
	if (!getNet().isServer() || this.isAttached())
	{
		return;
	}

	//shouldn't be in here! collided with map??
	if (blob is null)
	{
		return;
	}

	u8 state = this.get_u8(state_prop);
	if (state == stabbing)
	{
		return;
	}

	if (canStab(blob) && blob.getTeamNum() != this.getTeamNum() && !this.hasTag("trapped"))
	{
		this.server_Hit(blob, point, Vec2f_zero, 1.0f, Hitters::spikes, true);
		this.Tag("trapped");
	}
}

bool canBePickedUp(CBlob@ this, CBlob@ byBlob)
{
	return false;
}
void onHitBlob(CBlob@ this, Vec2f worldPoint, Vec2f velocity, f32 damage, CBlob@ hitBlob, u8 customData)
{
	if (hitBlob !is null && hitBlob !is this && damage > 0.0f)
	{
		setTrapped(this);
	}
}

f32 onHit(CBlob@ this, Vec2f worldPoint, Vec2f velocity, f32 damage, CBlob@ hitterBlob, u8 customData)
{
	f32 dmg = damage;
	switch (customData)
	{
		case Hitters::bomb:
			dmg *= 0.5f;
			break;

		case Hitters::keg:
			dmg *= 2.0f;

		case Hitters::cata_stones:
			dmg *= 3.0f;
			break;

		// it is deactivated by player's attack
		case Hitters::builder:
		case Hitters::sword:
		case Hitters::arrow:
		case Hitters::stab:
		case Hitters::drill:
			dmg = 0.0f;
			setTrapped(this);
			break;

	}
	return dmg;
}
