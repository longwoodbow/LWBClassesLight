// From bomb logic

#include "KnockedCommon.as"
#include "MakeDustParticle.as";

void onInit(CBlob@ this)
{
	this.set_s32("smoke_timer", getGameTime() + 120);
	this.getShape().getConsts().net_threshold_multiplier = 2.0f;
	//
	this.Tag("activated"); // make it lit already and throwable
}

void onTick(CBlob@ this)
{
	s32 timer = this.get_s32("smoke_timer") - getGameTime();
	if (timer <= 0)
	{
		if (getNet().isServer())
		{
			this.server_Die();
		}
	}
	else if (timer % 2 == 0)
	{
		MakeDustParticle(this.getPosition(), "SmallSmoke" + (XORRandom(2) + 1) + ".png");
	}
}

f32 onHit(CBlob@ this, Vec2f worldPoint, Vec2f velocity, f32 damage, CBlob@ hitterBlob, u8 customData)
{
	return 0.0f;
}

// run the tick so we explode in inventory
void onThisAddToInventory(CBlob@ this, CBlob@ inventoryBlob)
{
	this.doTickScripts = true;
}

void onDie(CBlob@ this)
{
	Vec2f pos = this.getPosition();
	MakeDustParticle(pos, "LargeSmoke.png");
	this.getSprite().PlaySound("FireFwoosh.ogg", 1.0f, 1.0f);

	if (!getNet().isServer()) return;

	CMap@ map = this.getMap();
	CBlob@[] blobs;
	if (map.getBlobsInRadius(pos, 24.0f, @blobs))
	{
		//HitInfo objects are sorted, first come closest hits
		for (uint i = 0; i < blobs.length; i++)
		{
			CBlob@ b = blobs[i];
			if (b.getTeamNum() != this.getTeamNum() && isKnockable(b))
			{
				setKnocked(b, 30);
			}
		}
	}
}

bool doesCollideWithBlob(CBlob@ this, CBlob@ blob)
{
	//special logic colliding with players
	if (blob.hasTag("player"))
	{
		return blob.getTeamNum() != this.getTeamNum();
	}

	string name = blob.getName();

	if (name == "fishy" || name == "food" || name == "steak" || name == "grain" || name == "heart" || name == "saw")
	{
		return false;
	}

	return true;
}



void onCollision(CBlob@ this, CBlob@ blob, bool solid)
{
	if (!solid)
	{
		return;
	}

	if (!this.isAttached())
	{
		this.server_Die();
	}
}

