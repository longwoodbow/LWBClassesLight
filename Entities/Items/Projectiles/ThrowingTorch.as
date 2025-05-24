
#include "Hitters.as";
#include "ShieldCommon.as";
#include "FireParticle.as";
#include "FireplaceCommon.as";
#include "ActivationThrowCommon.as"

const f32 fireFastSpeed = 6.5f;

//arrow is 6.0f
const f32 FIRE_PUSH_FORCE = 9.0f;
const f32 SPECIAL_HIT_SCALE = 1.0f; //special hit on food items to shoot to team-mates


//Fire logic

//blob functions
void onInit(CBlob@ this)
{
	CShape@ shape = this.getShape();
	ShapeConsts@ consts = shape.getConsts();
	consts.mapCollisions = false;	 // we have our own map collision
	consts.bullet = false;
	consts.net_threshold_multiplier = 4.0f;
	this.Tag("projectile");

	//dont collide with top of the map
	this.SetMapEdgeFlags(CBlob::map_collide_left | CBlob::map_collide_right);

	// 20 seconds of floating around
	this.server_SetTimeToDie(20);

	// like fire arrow
	this.SetLight(true);
	this.SetLightColor(SColor(255, 250, 215, 178));
	this.SetLightRadius(20.0f);
	this.Tag("fire source");
	this.Tag("activated"); // make it lit already and throwable
}

void onTick(CBlob@ this)
{
	CShape@ shape = this.getShape();

	f32 angle;
	if (!this.hasTag("collided")) //we haven't hit anything yet!
	{
		Vec2f pos = this.getPosition();
		//prevent leaving the map
		if (
			pos.x < 0.1f ||
			pos.x > (getMap().tilemapwidth * getMap().tilesize) - 0.1f
		) {
			this.server_Die();
			return;
		}
		

		Pierce(this);

		if (this.isInWater())
		{
			this.server_Die();
		}

		const s32 gametime = getGameTime();

		if (gametime % 6 == 0)
		{
			makeFireParticle(pos, 4);
		}
	}
}

void onCollision(CBlob@ this, CBlob@ blob, bool solid, Vec2f normal, Vec2f point1)
{
	if (blob !is null && doesCollideWithBlob(this, blob) && !this.hasTag("collided"))
	{
		if (
			!solid && !blob.hasTag("flesh") &&
			!specialFireHit(blob) &&
			(blob.getName() != "mounted_bow" || this.getTeamNum() != blob.getTeamNum())
		) {
			return;
		}

		Vec2f initVelocity = this.getOldVelocity();
		f32 vellen = initVelocity.Length();
		if (vellen < 0.1f)
		{
			return;
		}

		f32 dmg = 0.0f;
		if (blob.getTeamNum() != this.getTeamNum() || blob.getName() == "bridge")
		{
			dmg = getFireDamage(this, vellen);
		}

		// this isnt synced cause we want instant collision for arrow even if it was wrong
		dmg = FireHitBlob(this, point1, initVelocity, dmg, blob, Hitters::fire);

		this.Tag("collided");
		
		if (dmg > 0.0f)
		{
			//perform the hit and tag so that another doesn't happen
			this.server_Hit(blob, point1, initVelocity, 0.0f, Hitters::fire);
		}
	}
}

bool doesCollideWithBlob(CBlob@ this, CBlob@ blob)
{
	//don't collide with other projectiles
	if (blob.hasTag("projectile"))
	{
		return false;
	}

	//anything to always hit
	if (specialFireHit(blob))
	{
		return true;
	}

	//definitely collide with non-team blobs

	bool check =	this.getTeamNum() != blob.getTeamNum() || // collide with enemy blobs
					blob.getName() == "bridge" ||
					(blob.getName() == "keg" && !blob.isAttached() && this.hasTag("fire source")); // fire arrows collide with team kegs that arent held

	//maybe collide with team structures
	if (!check)
	{
		CShape@ shape = blob.getShape();
		check = (shape.isStatic() && !shape.getConsts().platform);
	}

	if (check)
	{
		if (
			this.hasTag("collided") ||
			blob.hasTag("dead") ||
			//or they ignore us
			blob.hasTag("ignore_arrow")
		) {
			return false;
		}
		else
		{
			return true;
		}
	}

	return false;
}

bool specialFireHit(CBlob@ blob)
{
	string bname = blob.getName();
	return (bname == "fishy" && blob.hasTag("dead") || bname == "food"
		|| bname == "steak" || bname == "grain"/* || bname == "heart"*/); //no egg because logic
}

void Pierce(CBlob @this, CBlob@ blob = null)
{
	Vec2f end;
	CMap@ map = getMap();
	Vec2f position = blob is null ? this.getPosition() : blob.getPosition();

	if (map.rayCastSolidNoBlobs(this.getShape().getVars().oldpos, position, end))
	{
		FireHitMap(this, end, this.getOldVelocity(), 0.5f, Hitters::fire, blob);
	}
}

f32 FireHitBlob(CBlob@ this, Vec2f worldPoint, Vec2f velocity, f32 damage, CBlob@ hitBlob, u8 customData)
{
	if (hitBlob !is null)
	{
		Pierce(this, hitBlob);
		if (this.hasTag("collided")) return 0.0f;

		// check if invincible + special -> add force here
		if (specialFireHit(hitBlob))
		{
			const f32 scale = SPECIAL_HIT_SCALE;
			f32 force = (FIRE_PUSH_FORCE * 0.125f) * Maths::Sqrt(hitBlob.getMass() + 1) * scale;
			//if (this.hasTag("bow arrow"))
			//{
				force *= 1.3f;
			//}

			hitBlob.AddForce(velocity * force);

			//die
			this.server_Hit(this, this.getPosition(), Vec2f(), 1.0f, Hitters::crush);
		}

		if (hitBlob.getName() == "keg" && !hitBlob.hasTag("exploding") && isServer())
		{
			server_Activate(hitBlob);
		}

		// check if shielded
		const bool hitShield = (hitBlob.hasTag("shielded") && blockAttack(hitBlob, velocity, 0.0f));
		const bool hitKeg = (hitBlob.getName() == "keg");

		if (hitShield)
		{
			// don't set anything on fire if we hit a shield
			this.Tag("no_fire");
			// don't want to give fire for shielded knight, old style
			damage = 0.0f;
		}
		else
		{
			this.set_Vec2f("override fire pos", hitBlob.getPosition());
		}

		this.server_Die();
	}

	return damage;
}

void FireHitMap(CBlob@ this, Vec2f worldPoint, Vec2f velocity, f32 damage, u8 customData, CBlob@ hitBlob = null)
{
	getMap().server_setFireWorldspace(worldPoint, true);

	this.Tag("collided");
	//kill any grain plants we shot the base of
	//ignite fireplace when fire arrow hits the base
	CBlob@[] blobsInRadius;
	if (getMap().getBlobsInRadius(worldPoint, this.getRadius() * 1.3f, @blobsInRadius))
	{
		for (uint i = 0; i < blobsInRadius.length; i++)
		{
			CBlob @b = blobsInRadius[i];
			if (b.getName() == "grain_plant")
			{
				this.server_Hit(b, worldPoint, Vec2f(0, 0), velocity.Length() / 7.0f, Hitters::fire);
				break;
			}
			if (b.getName() == "fireplace" && !b.getSprite().isAnimation("fire"))
			{
				Ignite(b);
				break;
			}
		}
	}
	this.server_Die();
}

void FireUp(CBlob@ this)
{
	CMap@ map = getMap();
	if (map is null) return;

	Vec2f pos = this.getPosition();
	Vec2f head = Vec2f(map.tilesize * 0.8f, 0.0f);
	f32 angle = this.getAngleDegrees();
	head.RotateBy(angle);
	Vec2f burnpos = pos + head;

	if (this.exists("override fire pos"))
	{
		MakeFireCross(this, this.get_Vec2f("override fire pos"));
	}
	else if (isFlammableAt(burnpos))
	{
		MakeFireCross(this, burnpos);
	}
	else if (isFlammableAt(pos))
	{
		MakeFireCross(this, pos);
	}
}

void MakeFireCross(CBlob@ this, Vec2f burnpos)
{
	/*
	fire starting pattern
	X -> fire | O -> not fire
	[O] [X] [O]
	[X] [X] [X]
	[O] [X] [O]
	*/

	CMap@ map = getMap();

	const float ts = map.tilesize;

	//align to grid
	burnpos = Vec2f(
		(Maths::Floor(burnpos.x / ts) + 0.5f) * ts,
		(Maths::Floor(burnpos.y / ts) + 0.5f) * ts
	);

	Vec2f[] positions = {
		burnpos, // center
		burnpos - Vec2f(ts, 0.0f), // left
		burnpos + Vec2f(ts, 0.0f), // right
		burnpos - Vec2f(0.0f, ts), // up
		burnpos + Vec2f(0.0f, ts) // down
	};

	for (int i = 0; i < positions.length; i++)
	{
		Vec2f pos = positions[i];
		//set map on fire
		map.server_setFireWorldspace(pos, true);

		//set blob on fire
		CBlob@ b = map.getBlobAtPosition(pos);
		//skip self or nothing there
		if (b is null || b is this) continue;

		//only hit static blobs
		CShape@ s = b.getShape();
		if (s !is null && s.isStatic())
		{
			this.server_Hit(b, this.getPosition(), this.getVelocity(), 0.5f, Hitters::fire);
		}
	}
}

bool isFlammableAt(Vec2f worldPos)
{
	CMap@ map = getMap();
	//check for flammable tile
	Tile tile = map.getTile(worldPos);
	if ((tile.flags & Tile::FLAMMABLE) != 0)
	{
		return true;
	}
	//check for flammable blob
	CBlob@ b = map.getBlobAtPosition(worldPos);
	if (b !is null && b.isFlammable())
	{
		return true;
	}
	//nothing flammable here!
	return false;
}

void onDie(CBlob@ this)
{
	if (isServer() && !this.hasTag("no_fire"))
	{
		FireUp(this);
	}
}

void onThisAddToInventory(CBlob@ this, CBlob@ inventoryBlob)
{
	if (!getNet().isServer())
	{
		return;
	}
	this.server_Die();
}

f32 onHit(CBlob@ this, Vec2f worldPoint, Vec2f velocity, f32 damage, CBlob@ hitterBlob, u8 customData)
{
	if (customData == Hitters::sword || customData == Hitters::stab)
	{
		return 0.0f; //no cut arrows
	}

	return damage;
}

void onHitBlob(CBlob@ this, Vec2f worldPoint, Vec2f velocity, f32 damage, CBlob@ hitBlob, u8 customData)
{
	// unbomb, stick to blob
	if (this !is hitBlob && customData == Hitters::fire)
	{
		// affect players velocity
		const f32 scale = specialFireHit(hitBlob) ? SPECIAL_HIT_SCALE : 1.0f;

		Vec2f vel = velocity;
		const f32 speed = vel.Normalize();
		f32 force = (FIRE_PUSH_FORCE * 0.125f) * Maths::Sqrt(hitBlob.getMass() + 1) * scale * 1.3f;// like bow arrow

		hitBlob.AddForce(velocity * force);
	}
}

f32 getFireDamage(CBlob@ this, f32 vellen = -1.0f)
{
	return 0.25f;
}