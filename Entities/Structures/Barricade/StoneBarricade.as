// ballicade logic
#include "Hitters.as"

void onInit(CBlob@ this)
{
	this.getShape().SetRotationsAllowed(false);
	this.server_setTeamNum(-1); //allow anyone to break them

	// this.getCurrentScript().runFlags |= Script::tick_not_attached;
	this.getCurrentScript().tickFrequency = 0;

	this.Tag("builder always hit");
	//block knight sword
	this.Tag("blocks sword");
	this.Tag("blocks water");
	this.Tag("place norotate");
	this.Tag("builder fast hittable");

	if (this.getName() == "stone_barricade")
	{

		if (getNet().isServer())
		{
			dictionary harvest;
			harvest.set('mat_stone', 2);
			this.set('harvest', harvest);
		}
	}
}

f32 onHit(CBlob@ this, Vec2f worldPoint, Vec2f velocity, f32 damage, CBlob@ hitterBlob, u8 customData)
{
	if (customData == Hitters::builder)
	{
		return damage * 2.0f;
	}
	return damage;
}

void onSetStatic(CBlob@ this, const bool isStatic)
{
	if (!isStatic) return;

	this.getSprite().PlaySound("/build_door.ogg");
}

bool canBePickedUp(CBlob@ this, CBlob@ byBlob)
{
	return false;
}