// ballicade logic
#include "Hitters.as"

#include "FireCommon.as"

void onInit(CBlob@ this)
{
	this.getShape().SetRotationsAllowed(false);
	this.server_setTeamNum(-1); //allow anyone to break them

	this.set_s16(burn_duration , 300);
	//transfer fire to underlying tiles
	this.Tag(spread_fire_tag);

	// this.getCurrentScript().runFlags |= Script::tick_not_attached;
	this.getCurrentScript().tickFrequency = 0;

	this.Tag("builder always hit");
	//block knight sword
	this.Tag("blocks sword");
	this.Tag("blocks water");
	this.Tag("place norotate");
	this.Tag("builder fast hittable");

	if (this.getName() == "makeshift_barricade")
	{

		if (getNet().isServer())
		{
			dictionary harvest;
			harvest.set('mat_wood', 2);
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
	else if (customData ==  Hitters::burn)
		return 1.0f;
	return damage;
}

void onSetStatic(CBlob@ this, const bool isStatic)
{
	if (!isStatic) return;

	this.getSprite().PlaySound("/build_wood.ogg");
}

bool canBePickedUp(CBlob@ this, CBlob@ byBlob)
{
	return false;
}