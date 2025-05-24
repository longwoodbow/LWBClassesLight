#include "VehicleCommon.as"
#include "KnockedCommon.as";
#include "GenericButtonCommon.as";
#include "Requirements.as"
#include "CheckSpam.as"
#include "GenericButtonCommon.as"

// Cart anim

void onInit(CSprite@ this)
{
	ReloadSprites(this);
}

void ReloadSprites(CSprite@ sprite)
{
	string filename = sprite.getFilename();

	sprite.SetZ(-25.0f);
	sprite.ReloadSprite(filename);
}

// Cart logic

void onInit(CBlob@ this)
{
	Vehicle_Setup(this,
	              25.0f, // move speed
	              0.5f,  // turn speed
	              Vec2f(0.0f, 0.0f), // jump out velocity
	              false  // inventory access
	             );
	VehicleInfo@ v;
	if (!this.get("VehicleInfo", @v)) return;

	Vehicle_SetupGroundSound(this, v, "WoodenWheelsRolling",  // movement sound
	                         1.0f, // movement sound volume modifier   0.0f = no manipulation
	                         1.0f // movement sound pitch modifier     0.0f = no manipulation
	                        );
	Vehicle_addWheel(this, v, "WoodenWheels.png", 16, 16, 0, Vec2f(-10.0f, 75.0f));
	Vehicle_addWheel(this, v, "WoodenWheels.png", 16, 16, 0, Vec2f(8.0f, 75.0f));

	//looks buggy, sad
	//this.getShape().SetCenterOfMassOffset(Vec2f(0, 75));
	this.getShape().SetOffset(Vec2f(0, 24));// ...WHY!?

	this.getShape().SetRotationsAllowed(false);
}

void onTick(CBlob@ this)
{
	VehicleInfo@ v;
	if (!this.get("VehicleInfo", @v)) return;

	Vehicle_StandardControls(this, v); //just make sure it's updated
}

bool doesCollideWithBlob(CBlob@ this, CBlob@ blob)
{
	return Vehicle_doesCollideWithBlob_ground(this, blob);
}
/*
void onCollision(CBlob@ this, CBlob@ blob, bool solid)
{
	if (blob !is null)
	{
		TryToAttachVehicle(this, blob);
	}
}
*/