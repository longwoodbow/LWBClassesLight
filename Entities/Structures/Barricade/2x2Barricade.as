// ballicade logic

#include "FireCommon.as"
#include "Hitters.as";

void onInit(CBlob@ this)
{
	this.getShape().SetRotationsAllowed(false);
	this.getShape().getConsts().waterPasses = true;

	this.set_s16(burn_duration , 300);
	//transfer fire to underlying tiles
	this.Tag(spread_fire_tag);

	// this.getCurrentScript().runFlags |= Script::tick_not_attached;
	this.getCurrentScript().tickFrequency = 0;

	//so, don't use blocks sword tag for ally knights
	//block knight sword
	//this.Tag("blocks sword");
	this.Tag("builder always hit");
	this.Tag("barricade");//block spear and bullets
	this.Tag("place norotate");
	this.Tag("builder fast hittable");
}

void onSetStatic(CBlob@ this, const bool isStatic)
{
	if (!isStatic) return;

	this.getSprite().SetZ(-40);
}

bool doesCollideWithBlob(CBlob@ this, CBlob@ blob)
{
	return this.getTeamNum() != blob.getTeamNum();
}

bool canBePickedUp(CBlob@ this, CBlob@ byBlob)
{
	return false;
}