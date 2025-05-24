//#include "/Entities/Common/Attacks/Hitters.as"; // Explosion.as has it too
#include "/Entities/Common/Attacks/LimitedAttacks.as";
#include "Explosion.as";  // <---- onHit()

const int pierce_amount = 4; // from 8... i was tried in 4

void onInit(CBlob @ this)
{
	this.Tag("medium weight");

	// small explosion stat
	this.set_f32("explosive_radius", 24.0f);
	this.set_f32("explosive_damage", 1.0f);
	this.set_u8("custom_hitter", Hitters::cata_boulder);
	this.set_f32("map_damage_radius", 24.0f);
	this.set_f32("map_damage_ratio", 0.4f);
	this.set_bool("map_damage_raycast", true);
	this.set_string("custom_explosion_sound", "ArrowHitGroundFast.ogg");

	LimitedAttack_setup(this);

	this.set_u8("blocks_pierced", 0);
	u32[] tileOffsets;
	this.set("tileOffsets", tileOffsets);

	CShape@ shape = this.getShape();
	ShapeConsts@ consts = shape.getConsts();
	consts.mapCollisions = false;
	consts.collidable = false;
	//consts.bullet = true;

	// damage
	this.getCurrentScript().runFlags |= Script::tick_not_attached;
	this.getCurrentScript().tickFrequency = 3;
}

void onTick(CBlob@ this)
{
	//rock and roll mode
	Vec2f vel = this.getVelocity();
	f32 angle = vel.Angle();
	Slam(this, angle, vel, this.getShape().vellen * 1.5f);
}

void Slam(CBlob @this, f32 angle, Vec2f vel, f32 vellen)
{
	if (vellen < 0.1f)
		return;

	CMap@ map = this.getMap();
	Vec2f pos = this.getPosition();
	HitInfo@[] hitInfos;
	u8 team = this.getTeamNum();

	if (map.getHitInfosFromArc(pos, -angle, 30, vellen, this, true, @hitInfos))
	{
		for (uint i = 0; i < hitInfos.length; i++)
		{
			HitInfo@ hi = hitInfos[i];
			f32 dmg = 5.0f;// from 2.0f

			if (hi.blob is null) // map
			{
				if (BoulderHitMap(this, hi.hitpos, hi.tileOffset, vel, dmg, Hitters::cata_boulder))
					return;
			}
			else if (team != u8(hi.blob.getTeamNum()))
			{
				this.server_Hit(hi.blob, pos, vel, dmg, Hitters::cata_boulder, true);
				this.setVelocity(vel * 0.9f); //damp

				// die when hit something large
				if (hi.blob.getRadius() > 32.0f)
				{
					this.server_Hit(this, pos, vel, 10, Hitters::cata_boulder, true);
				}
			}
		}
	}

	// chew through backwalls

	Tile tile = map.getTile(pos);
	if (map.isTileBackgroundNonEmpty(tile))
	{
		if (map.getSectorAtPosition(pos, "no build") !is null)
		{
			return;
		}
		map.server_DestroyTile(pos + Vec2f(7.0f, 7.0f), 10.0f, this);
		map.server_DestroyTile(pos - Vec2f(7.0f, 7.0f), 10.0f, this);
	}
}

bool BoulderHitMap(CBlob@ this, Vec2f worldPoint, int tileOffset, Vec2f velocity, f32 damage, u8 customData)
{
	//check if we've already hit this tile
	u32[]@ offsets;
	this.get("tileOffsets", @offsets);

	if (offsets.find(tileOffset) >= 0) { return false; }

	//this.getSprite().PlaySound("ArrowHitGroundFast.ogg");
	f32 angle = velocity.Angle();
	CMap@ map = getMap();
	TileType t = map.getTile(tileOffset).type;
	u8 blocks_pierced = this.get_u8("blocks_pierced");
	bool stuck = false;

	if (map.isTileCastle(t) || map.isTileWood(t))
	{
		Vec2f tpos = this.getMap().getTileWorldPosition(tileOffset);
		if (map.getSectorAtPosition(tpos, "no build") !is null)
		{
			return false;
		}

		//make a shower of gibs here

		map.server_DestroyTile(tpos, 100.0f, this);
		Vec2f vel = this.getVelocity();
		this.setVelocity(vel * 0.8f); //damp
		this.push("tileOffsets", tileOffset);

		if (blocks_pierced < pierce_amount)
		{
			blocks_pierced++;
			this.set_u8("blocks_pierced", blocks_pierced);
		}
		else
		{
			stuck = true;
		}
	}
	else
	{
		stuck = true;
	}

	if (velocity.LengthSquared() < 5)
		stuck = true;

	if (stuck)
	{
		this.server_Hit(this, worldPoint, velocity, 10, Hitters::crush, true);
	}
	else
	{
		// small explosion on hit map
		Explode(this, this.get_f32("explosive_radius"), this.get_f32("explosive_damage"));
	}

	return stuck;
}


void onCollision(CBlob@ this, CBlob@ blob, bool solid, Vec2f normal, Vec2f point1)
{
	if (blob !is null)
	{
		Vec2f hitvel = this.getOldVelocity();
		Vec2f hitvec = point1 - this.getPosition();
		f32 coef = hitvec * hitvel;

		if (coef < 0.706f) // check we were flying at it
		{
			return;
		}

		f32 vellen = hitvel.Length();

		//fast enough
		if (vellen < 1.0f)
		{
			return;
		}

		if ((!blob.hasTag("invincible") && this.getTeamNum() != blob.getTeamNum()) || blob.hasTag("blocks sword"))
		{
			u8 blocks_pierced = this.get_u8("blocks_pierced");

			if (blocks_pierced < pierce_amount && blob.getMass() < 1000.0f)
			{
				blocks_pierced++;
				this.set_u8("blocks_pierced", blocks_pierced);
				Explode(this, this.get_f32("explosive_radius"), this.get_f32("explosive_damage"));
			}
			else
			{
				this.server_Hit(this, this.getPosition(), hitvel, 10, Hitters::crush, true);
			}
		}
	}
}

f32 onHit(CBlob@ this, Vec2f worldPoint, Vec2f velocity, f32 damage, CBlob@ hitterBlob, u8 customData)
{
	if (customData == Hitters::sword || customData == Hitters::arrow)
	{
		return damage *= 0.5f;
	}

	return damage;
}

void onDie(CBlob@ this)
{
	// big explosion, power up	
	this.set_f32("explosive_radius", 32.0f);
	this.set_f32("explosive_damage", 10.0f);
	this.set_f32("map_damage_radius", 32.0f);
	this.set_f32("map_damage_ratio", 0.6f);
	this.set_string("custom_explosion_sound", "Entities/Items/Explosives/KegExplosion.ogg");

	Explode(this, this.get_f32("explosive_radius"), this.get_f32("explosive_damage"));
}
