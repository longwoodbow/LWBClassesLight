#include "Hitters.as"

enum facing_direction
{
	none = 0,
	up,
	down,
	left,
	right
};

const string facing_prop = "facing";

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

	this.set_u8(facing_prop, up);
}

void onSetStatic(CBlob@ this, const bool isStatic)
{
	if (!isStatic) return;

	this.getSprite().PlaySound("/build_door.ogg");
}

//temporary struct used to pass some variables by reference
//since &inout isn't supported for native types
class spikeCheckParameters
{
	facing_direction facing;
	bool onSurface;
};

//specific tile checking logic for the spikes
void tileCheck(CBlob@ this, CMap@ map, Vec2f pos, f32 angle, facing_direction set_facing, spikeCheckParameters@ params)
{
	if (params.onSurface) return; //do nothing if we've already found stone

	TileType t = map.getTile(pos).type;

	if (map.isTileSolid(t))
	{
		params.onSurface = true;
		params.facing = set_facing;
		this.setAngleDegrees(angle);
	}
}

void onTick(CBlob@ this)
{
	CMap@ map = getMap();
	Vec2f pos = this.getPosition();
	const f32 tilesize = map.tilesize;

	if (getNet().isServer() &&
	        (map.isTileSolid(map.getTile(pos)) || map.rayCastSolid(pos - this.getVelocity(), pos)))
	{
		this.server_Hit(this, pos, Vec2f(0, -1), 3.0f, Hitters::fall, true);
		return;
	}

	//check support/placement status
	facing_direction facing;
	bool onSurface;

	//wrapped functionality
	{
		spikeCheckParameters temp;
		//box
		temp.facing = none;
		temp.onSurface = false;

		tileCheck(this, map, pos + Vec2f(0.0f, tilesize), 0.0f, up, temp);
		tileCheck(this, map, pos + Vec2f(-tilesize, 0.0f), 90.0f, right, temp);
		tileCheck(this, map, pos + Vec2f(tilesize, 0.0f), -90.0f, left, temp);
		tileCheck(this, map, pos + Vec2f(0.0f, -tilesize), 180.0f, down, temp);

		//unbox
		facing = temp.facing;
		onSurface = temp.onSurface;
	}

	if (this.getShape().isStatic() && !onSurface && getNet().isServer())// normal spikes will be falling on here
	{
		this.server_Hit(this, pos, Vec2f(0, -1), 3.0f, Hitters::fall, true);
		return;
	}

	if (getNet().isClient() && !this.hasTag("_frontlayer"))
	{
		CSprite@ sprite = this.getSprite();
		sprite.SetZ(500.0f);

		if (sprite !is null)
		{
			CSpriteLayer@ panel = sprite.addSpriteLayer("panel", sprite.getFilename() , 8, 16, this.getTeamNum(), this.getSkinNum());

			if (panel !is null)
			{
				panel.SetOffset(Vec2f(0, 3));
				panel.SetRelativeZ(500.0f);

				Animation@ animcharge = panel.addAnimation("default", 0, false);
				animcharge.AddFrame(6);
				animcharge.AddFrame(7);

				this.Tag("_frontlayer");
			}
		}
	}

	this.set_u8(facing_prop, facing);

	// set optimisation flags - not done in oninit so we actually orient to the stone first

	this.getCurrentScript().runProximityRadius = 124.0f;
	this.getCurrentScript().runFlags |= Script::tick_blob_in_proximity;

	onHealthChange(this, this.getHealth());
	
	this.getCurrentScript().tickFrequency = 25;// normal spike will be changed on stone block
}

bool canStab(CBlob@ b)
{
	return !b.hasTag("dead") && b.hasTag("flesh");
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

	// only hit living things
	if (!blob.hasTag("flesh"))
	{
		return;
	}

	f32 damage = 0.0f;

	f32 angle = this.getAngleDegrees();
	Vec2f vel = blob.getOldVelocity(); //if we use current vel it might have been cancelled vs terrain

	bool b_falling = Maths::Abs(vel.y) > 0.5f;

	if (angle > -135.0f && angle < -45.0f)
	{
		f32 verDist = Maths::Abs(this.getPosition().y - blob.getPosition().y);

		if (normal.x > 0.5f && verDist < 6.1f && vel.x > 1.0f)
		{
			damage = 0.5f;
		}
		else if (b_falling && vel.x >= 0)
		{
			damage = 0.25f;
		}
	}
	else if (angle > 45.0f && angle < 135.0f)
	{
		f32 verDist = Maths::Abs(this.getPosition().y - blob.getPosition().y);

		if (normal.x < -0.5f && verDist < 6.1f && vel.x < -1.0f)
		{
			damage = 0.5f;
		}
		else if (b_falling && vel.x <= 0)
		{
			damage = 0.25f;
		}
	}
	else if (angle <= -135.0f || angle >= 135.0f)
	{
		f32 horizDist = Maths::Abs(this.getPosition().x - blob.getPosition().x);

		if (normal.y < -0.5f && horizDist < 6.1f && vel.y < -0.5f)
		{
			damage = 0.5f;
		}
	}
	else
	{
		f32 horizDist = Maths::Abs(this.getPosition().x - blob.getPosition().x);

		if (normal.y > 0.5f && horizDist < 6.1f && vel.y > 0.5f)
		{
			damage = 0.5f;
		}
		else if (this.getVelocity().y > 0.5f && horizDist < 6.1f)  // falling down
		{
			damage = this.getVelocity().y * 1.0f;
		}
	}

	if (damage > 0)
	{
		this.server_Hit(blob, point, vel * -1, damage, Hitters::spikes, true);
	}
}

void onHitBlob(CBlob@ this, Vec2f worldPoint, Vec2f velocity, f32 damage, CBlob@ hitBlob, u8 customData)
{
	if (hitBlob !is null && hitBlob !is this && damage > 0.0f)
	{
		CSprite@ sprite = this.getSprite();
		sprite.PlaySound("/SpikesCut.ogg");

		if (!this.hasTag("bloody"))
		{
			if (!g_kidssafe)
			{
				sprite.animation.frame += 3;
			}
			this.Tag("bloody");
		}
	}
}

void onHealthChange(CBlob@ this, f32 oldHealth)
{
	f32 hp = this.getHealth();
	f32 full_hp = this.getInitialHealth();
	int frame = (hp > full_hp * 0.9f) ? 0 : ((hp > full_hp * 0.4f) ? 1 : 2);

	if (this.hasTag("bloody") && !g_kidssafe)
	{
		frame += 3;
	}
	this.getSprite().animation.frame = frame;
}

bool canBePickedUp(CBlob@ this, CBlob@ byBlob)
{
	return false;
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

		case Hitters::arrow:
			dmg = 0.0f;
			break;

		case Hitters::cata_stones:
			dmg *= 3.0f;
			break;
	}
	return dmg;
}
