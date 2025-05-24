#include "Hitters.as";
#include "ShieldCommon.as";
#include "MakeDustParticle.as";
#include "ParticleSparks.as";
#include "KnockedCommon.as";
#include "RedBarrierCommon.as"

const f32 fragFastSpeed = 6.5f;

const f32 FRAG_PUSH_FORCE = 1.0f;
//arrow is 6.0f
const f32 SPECIAL_HIT_SCALE = 1.0f; //special hit on food items to shoot to team-mates


//Frag logic

//blob functions
void onInit(CBlob@ this)
{
	CShape@ shape = this.getShape();
	shape.SetGravityScale(0.05f);
	ShapeConsts@ consts = shape.getConsts();
	consts.mapCollisions = false;	 // weh ave our own map collision
	consts.bullet = true;
	consts.net_threshold_multiplier = 4.0f;
	this.Tag("projectile");

	//dont collide with top of the map
	this.SetMapEdgeFlags(CBlob::map_collide_left | CBlob::map_collide_right);

	// 20 seconds of floating around
	this.server_SetTimeToDie(20);

	// like fire arrow, quarter radius
	this.SetLight(true);
	this.SetLightColor(SColor(255, 250, 215, 178));
	this.SetLightRadius(5.0f);
}

void onTick(CBlob@ this)
{
	CShape@ shape = this.getShape();

	f32 angle;
	if (!this.hasTag("collided")) //we haven't hit anything yet!
	{
		if (this.getTickSinceCreated() > 15)
		{
			this.server_Hit(this, this.getPosition(), Vec2f(), 1.0f, Hitters::crush);
		}
		//prevent leaving the map
		{
			Vec2f pos = this.getPosition();
			if (
				pos.x < 0.1f ||
				pos.x > (getMap().tilemapwidth * getMap().tilesize) - 0.1f
			) {
				this.server_Die();
				return;
			}
		}
		angle = (this.getVelocity()).Angle();
		Pierce(this);   //map
		this.setAngleDegrees(-angle);
	}
}

void onCollision(CBlob@ this, CBlob@ blob, bool solid, Vec2f normal, Vec2f point1)
{
	if (blob !is null && doesCollideWithBlob(this, blob) && !this.hasTag("collided"))
	{
		if (
			!solid && !blob.hasTag("flesh") &&
			!specialFragHit(blob) &&
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
			dmg = getFragDamage(this, vellen);
		}

		// this isnt synced cause we want instant collision for arrow even if it was wrong
		dmg = FragHitBlob(this, point1, initVelocity, dmg, blob, Hitters::arrow);

		this.Tag("collided");
		
		if (dmg > 0.0f)
		{
			//perform the hit and tag so that another doesn't happen
			this.server_Hit(blob, point1, initVelocity, dmg, Hitters::arrow);
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
	if (specialFragHit(blob))
	{
		return true;
	}

	//definitely collide with non-team blobs
	bool check = this.getTeamNum() != blob.getTeamNum() || blob.getName() == "bridge";
	//maybe collide with team structures
	if (!check)
	{
		CShape@ shape = blob.getShape();
		check = (shape.isStatic() && !shape.getConsts().platform);
	}

	if (check)
	{
		if (
			//we've collided
			this.hasTag("collided") ||
			//or they're dead
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

bool specialFragHit(CBlob@ blob)
{
	string bname = blob.getName();
	return (bname == "fishy" && blob.hasTag("dead") || bname == "food"
		|| bname == "steak" || bname == "grain"/* || bname == "heart"*/); //no egg because logic
}

bool checkGrappleBarrier(Vec2f pos)
{
	CRules@ rules = getRules();
	if (!shouldBarrier(@rules)) { return false; }

	Vec2f tl, br;
	getBarrierRect(@rules, tl, br);

	return (pos.x > tl.x && pos.x < br.x);
}

void Pierce(CBlob @this, CBlob@ blob = null)
{
	Vec2f end;
	CMap@ map = getMap();
	Vec2f position = blob is null ? this.getPosition() : blob.getPosition();

	if (checkGrappleBarrier(position))  //red barrier
	{
		this.server_Die();
	}

	if (map.rayCastSolidNoBlobs(this.getShape().getVars().oldpos, position, end))
	{
		FragHitMap(this, end, this.getOldVelocity(), 0.5f, Hitters::arrow, blob);
	}
}

f32 FragHitBlob(CBlob@ this, Vec2f worldPoint, Vec2f velocity, f32 damage, CBlob@ hitBlob, u8 customData)
{
	if (hitBlob !is null)
	{
		Pierce(this, hitBlob);
		if (this.hasTag("collided")) return 0.0f;

		// check if invincible + special -> add force here
		if (specialFragHit(hitBlob))
		{
			const f32 scale = SPECIAL_HIT_SCALE;
			f32 force = (FRAG_PUSH_FORCE * 0.125f) * Maths::Sqrt(hitBlob.getMass() + 1) * scale;
			//if (this.hasTag("bow arrow"))
			//{
				force *= 1.3f;
			//}

			hitBlob.AddForce(velocity * force);

			//die
			this.server_Hit(this, this.getPosition(), Vec2f(), 1.0f, Hitters::crush);
		}

		// check if shielded
		const bool hitShield = (hitBlob.hasTag("shielded") && blockAttack(hitBlob, velocity, 0.0f));

		// play sound
		if (!hitShield)
		{
			if (hitBlob.hasTag("flesh"))
			{
				this.getSprite().PlaySound("ArrowHitFlesh.ogg");
			}
			else if (hitBlob.hasTag("stone"))
			{
				sparks (worldPoint, -velocity.Angle(), Maths::Max(velocity.Length()*0.05f, damage));
				this.getSprite().PlaySound("BulletRicochet.ogg");
			}
			else
			{
				this.getSprite().PlaySound("BulletImpact.ogg");	
			}
		}

		this.server_Die();
	}

	return damage;
}

void FragHitMap(CBlob@ this, Vec2f worldPoint, Vec2f velocity, f32 damage, u8 customData, CBlob@ hitBlob = null)
{
	MakeDustParticle(worldPoint, "/DustSmall.png");
	CMap@ map = getMap();
	f32 vellen = velocity.Length();
	TileType tile = map.getTile(worldPoint).type;
	if (map.isTileCastle(tile) || map.isTileStone(tile) || map.isTileBedrock(tile))
	{
		sparks (worldPoint, -velocity.Angle(), Maths::Max(vellen*0.05f, damage));
		this.getSprite().PlaySound("BulletRicochet.ogg");
		if(!map.isTileBedrock(tile))
		{
			map.server_DestroyTile(worldPoint, 0.1f, this);
			map.server_DestroyTile(worldPoint, 0.1f, this);
		}
	}
	else
	{
		this.getSprite().PlaySound("BulletImpact.ogg");
		if (map.isTileWood(tile))
			map.server_DestroyTile(worldPoint, 0.1f, this);
	}
	this.Tag("collided");
	//kill any grain plants we shot the base of
	CBlob@[] blobsInRadius;
	if (map.getBlobsInRadius(worldPoint, this.getRadius() * 1.3f, @blobsInRadius))
	{
		for (uint i = 0; i < blobsInRadius.length; i++)
		{
			CBlob @b = blobsInRadius[i];
			if (b.getName() == "grain_plant")
			{
				this.server_Hit(b, worldPoint, Vec2f(0, 0), velocity.Length() / 7.0f, Hitters::arrow);
				break;
			}
		}
	}
	this.server_Die();
}


//random object used for gib spawning
Random _gib_r(0xa7c3a);
void onDie(CBlob@ this)
{
	if (getNet().isClient())
	{
		Vec2f pos = this.getPosition();
		if (pos.x >= 1 && pos.y >= 1)
		{
			Vec2f vel = this.getVelocity();
			makeGibParticle(
				"GenericGibs.png", pos, vel,
				6, _gib_r.NextRanged(4) + 4,
				Vec2f(8, 8), 2.0f, 20, "/thud",
				this.getTeamNum()
			);
		}
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
	if (customData == Hitters::sword)
	{
		return 0.0f; //no cut arrows
	}

	return damage;
}

void onHitBlob(CBlob@ this, Vec2f worldPoint, Vec2f velocity, f32 damage, CBlob@ hitBlob, u8 customData)
{
	// unbomb, stick to blob
	if (this !is hitBlob && customData == Hitters::arrow)
	{
		// affect players velocity
		const f32 scale = specialFragHit(hitBlob) ? SPECIAL_HIT_SCALE : 1.0f;

		Vec2f vel = velocity;
		const f32 speed = vel.Normalize();
		if (speed > 17.59f)
		{
			f32 force = (FRAG_PUSH_FORCE * 0.125f) * Maths::Sqrt(hitBlob.getMass() + 1) * scale * 1.3f;// like bow arrow

			hitBlob.AddForce(velocity * force);
			if (
				this.getTickSinceCreated() <= 7 &&// arrow and some projectiles are 4, bullet is 15(20 ticks stun while)
				speed > 17.59 * 0.845f &&
				hitBlob.hasTag("player")
			) {
				setKnocked(hitBlob, 20, true);
				Sound::Play("/Stun", hitBlob.getPosition(), 1.0f, this.getSexNum() == 0 ? 1.0f : 1.5f);
			}
		}
	}
}

f32 getFragDamage(CBlob@ this, f32 vellen = -1.0f)
{
	return 1.0f;
}