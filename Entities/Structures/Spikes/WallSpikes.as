#include "Hitters.as"

enum spike_state
{
	normal = 0,
	hidden,
	stabbing
};

const string state_prop = "popup state";
const string timer_prop = "popout timer";
const u8 delay_stab = 10;
const u8 delay_retract = 30;

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
	this.set_u8(timer_prop, 0);
	this.set_TileType("background tile", CMap::tile_castle_back);
	this.getSprite().SetRelativeZ(-50); //background
}

void onSetStatic(CBlob@ this, const bool isStatic)
{
	if (!isStatic) return;

	this.getSprite().PlaySound("/build_wall2.ogg");
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

	//get prop
	spike_state state = spike_state(this.get_u8(state_prop));

	u8 timer = this.get_u8(timer_prop);

	// spike'em

	const u32 tickFrequency = 3;
	this.getCurrentScript().tickFrequency = tickFrequency;

	if (state == hidden)
	{
		this.getSprite().SetAnimation("hidden");
		CBlob@[] blobsInRadius;
		const int team = this.getTeamNum();
		if (map.getBlobsInRadius(pos, this.getRadius() * 1.0f, @blobsInRadius))
		{
			for (uint i = 0; i < blobsInRadius.length; i++)
			{
				CBlob @b = blobsInRadius[i];
				if (team != b.getTeamNum() && canStab(b))
				{
					state = stabbing;
					timer = delay_stab;

					break;
				}
			}
		}
	}
	else if (state == stabbing)
	{
		if (timer >= tickFrequency)
		{
			timer -= tickFrequency;
		}
		else
		{
			state = normal;
			timer = delay_retract;

			this.getSprite().SetAnimation("default");
			this.getSprite().PlaySound("/SpikesOut.ogg");

			CBlob@[] blobsInRadius;
			const int team = this.getTeamNum();
			if (map.getBlobsInRadius(pos, this.getRadius() * 2.0f, @blobsInRadius))
			{
				for (uint i = 0; i < blobsInRadius.length; i++)
				{
					CBlob @b = blobsInRadius[i];
					if (canStab(b)) //even hurts team when stabbing
					{
						// hurt?
						if (this.isOverlapping(b))
						{
							this.server_Hit(b, pos, b.getVelocity() * -1, 0.5f, Hitters::spikes, true);
						}
					}
				}
			}
		}
	}
	else //state is normal
	{
		if (timer >= tickFrequency)
		{
			timer -= tickFrequency;
		}
		else
		{
			state = hidden;
			timer = 0;
		}
	}
	this.set_u8(state_prop, state);
	this.set_u8(timer_prop, timer);

	onHealthChange(this, this.getHealth());
}

bool canStab(CBlob@ b)
{
	return !b.hasTag("dead") && b.hasTag("flesh");
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
				sprite.animation.frame += 1;
			}

			this.Tag("bloody");
		}
	}
}

void onHealthChange(CBlob@ this, f32 oldHealth)
{
	f32 hp = this.getHealth();
	f32 full_hp = this.getInitialHealth();
	int frame = 0;//(hp > full_hp * 0.9f) ? 0 : ((hp > full_hp * 0.4f) ? 1 : 2);

	if (this.hasTag("bloody") && !g_kidssafe)
	{
		frame += 1;
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
			break;

		case Hitters::arrow:
			dmg = 0.0f;
			break;

		case Hitters::cata_stones:
			dmg *= 3.0f;
			break;
	}
	return dmg;
}
