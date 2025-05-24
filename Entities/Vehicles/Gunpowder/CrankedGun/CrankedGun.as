#include "VehicleCommon.as"
#include "GenericButtonCommon.as"

// Cranked Gun logic

//naming here is kinda counter intuitive, but 0 == up, 90 == sideways
const f32 high_angle = -60.0f;
const f32 low_angle = 45.0f;

class CrankedGunInfo : VehicleInfo
{
	void onFire(CBlob@ this, CBlob@ bullet, const u16 &in fired_charge)
	{
		if (bullet !is null)
		{
			const f32 sign = this.isFacingLeft() ? -1 : 1;
			f32 angle = wep_angle * sign;
			angle += (XORRandom(512) - 256) / 256.0f;// from 64, 4 -> 1 degree

			const f32 arrow_speed = 50.0f;
			Vec2f vel = Vec2f(arrow_speed * sign, 0.0f).RotateBy(angle);
			bullet.setVelocity(vel);

			// set much higher drag than archer arrow
			//bullet.getShape().setDrag(bullet.getShape().getDrag() * 2.0f);

			//bullet.server_SetTimeToDie(-1);   // override lock
			//bullet.server_SetTimeToDie(0.69f);
			//bullet.Tag("bow arrow");
		}
	}
}

void onInit(CBlob@ this)
{
	// from PopWheelsOff.as
	this.addCommandID("pop_wheels");
	if (this.hasTag("immobile"))
	{
		PopWheels(this, false);
	}

	Vehicle_Setup(this,
	              50.0f, // move speed
	              0.31f,  // turn speed
	              Vec2f(0.0f, 0.0f), // jump out velocity
	              false,  // inventory access
	              CrankedGunInfo()
	             );
	VehicleInfo@ v;
	if (!this.get("VehicleInfo", @v)) return;

	Vehicle_AddAmmo(this, v,
	                    10, // fire delay (ticks) from 25
	                    1, // fire bullets amount
	                    1, // fire cost
	                    "mat_bullets", // bullet ammo config name
	                    "Bullets", // name for ammo selection
	                    "bullet", // bullet config name
	                    "M16Fire", // fire sound
	                    "EmptyFire", // empty fire sound
	                    Vec2f(-3, 0) //fire position offset
	                   );

	Vehicle_SetupGroundSound(this, v, "WoodenWheelsRolling",  // movement sound
	                         1.0f, // movement sound volume modifier   0.0f = no manipulation
	                         1.0f // movement sound pitch modifier     0.0f = no manipulation
	                        );
	Vehicle_addWheel(this, v, "IronWheel.png", 16, 16, 0, Vec2f(0.0f, 9.0f));


	// init arm + cage sprites
	CSprite@ sprite = this.getSprite();
	sprite.SetZ(-10.0f);
	CSpriteLayer@ arm = sprite.addSpriteLayer("arm", sprite.getConsts().filename, 16, 32);
	if (arm !is null)
	{
		Animation@ anim = arm.addAnimation("default", 0, false);
		int[] frames = { 2 };
		anim.AddFrames(frames);
		//arm.SetOffset(Vec2f(-6, 0));
		arm.RotateBy(90.0f, Vec2f_zero);
		arm.SetRelativeZ(0.08f);
	}

	//UpdateFrame(this);

	v.wep_angle = 0.0f;

	this.getShape().SetRotationsAllowed(false);

	string[] autograb_blobs = {"mat_bullets"};
	this.set("autograb blobs", autograb_blobs);

	this.set_bool("facing", false);

	// auto-load on creation
	if (isServer())
	{
		CBlob@ ammo = server_CreateBlob("mat_bullets");
		if (ammo !is null && !this.server_PutInInventory(ammo))
		{
			ammo.server_Die();
		}
	}
}

f32 getAimAngle(CBlob@ this, VehicleInfo@ v)
{
	f32 angle = v.wep_angle;
	const bool facing_left = this.isFacingLeft();
	AttachmentPoint@ gunner = this.getAttachments().getAttachmentPointByName("GUNNER");
	if (gunner !is null && gunner.getOccupied() !is null)
	{
		gunner.offsetZ = 5.0f;
		Vec2f aim_vec = gunner.getPosition() - gunner.getAimPos();

		if (this.isAttached())
		{
			if (facing_left) { aim_vec.x = -aim_vec.x; }
			angle = (-(aim_vec).getAngle() + 180.0f);
		}
		else
		{
			if ((!facing_left && aim_vec.x < 0) ||
			        (facing_left && aim_vec.x > 0))
			{
				if (aim_vec.x > 0) { aim_vec.x = -aim_vec.x; }

				angle = (-(aim_vec).getAngle() + 180.0f);
				angle = Maths::Max(high_angle , Maths::Min(angle , low_angle));
			}
			else
			{
				this.SetFacingLeft(!facing_left);
			}
		}
	}

	return angle;
}

void onTick(CBlob@ this)
{
	if (this.hasAttached() || this.get_bool("facing") != this.isFacingLeft())
	{
		VehicleInfo@ v;
		if (!this.get("VehicleInfo", @v)) return;

		const f32 angle = getAimAngle(this, v);
		v.wep_angle = angle;

		CSprite@ sprite = this.getSprite();
		CSpriteLayer@ arm = sprite.getSpriteLayer("arm");
		if (arm !is null)
		{
			const f32 sign = sprite.isFacingLeft() ? -1 : 1;
			const f32 rotation = (angle + 90.0f) * sign;

			arm.ResetTransform();
			arm.RotateBy(rotation, Vec2f_zero);
			arm.SetRelativeZ(0.08f);
			//arm.animation.frame = v.getCurrentAmmo().loaded_ammo > 0 ? 1 : 0;
		}

		Vehicle_StandardControls(this, v);
	}
	this.set_bool("facing", this.isFacingLeft());
}

void onHealthChange(CBlob@ this, f32 oldHealth)
{
	//UpdateFrame(this);
}
/*
void UpdateFrame(CBlob@ this)
{
}
*/
void GetButtonsFor(CBlob@ this, CBlob@ caller)
{
	if (!canSeeButtons(this, caller)) return;

	if (!Vehicle_AddFlipButton(this, caller))
	{
		Vehicle_AddLoadAmmoButton(this, caller);
	}
	
	if (this.isAttached() || caller.isAttached()) return;

	if (this.getAttachments().getAttachmentPointByName("DRIVER").getOccupied() !is null) return;

	if (this.getTeamNum() == caller.getTeamNum() && this.getDistanceTo(caller) < this.getRadius() && !this.hasTag("immobile"))
	{
		caller.CreateGenericButton(2, Vec2f(0.0f, 8.0f), this, this.getCommandID("pop_wheels"), getTranslatedString("Immobilise"));
	}
}

bool doesCollideWithBlob(CBlob@ this, CBlob@ blob)
{
	return Vehicle_doesCollideWithBlob_ground(this, blob);
}

void onCollision(CBlob@ this, CBlob@ blob, bool solid)
{
	if (blob !is null)
	{
		TryToAttachVehicle(this, blob);
	}
}

// from PopWheelsOff.as
void onCommand(CBlob@ this, u8 cmd, CBitStream @params)
{
	if (cmd == this.getCommandID("pop_wheels"))
	{
		if (!this.hasTag("immobile"))
		{
			CBlob@ chauffeur = this.getAttachments().getAttachmentPointByName("DRIVER").getOccupied();
			if (chauffeur !is null) return;

			this.Tag("immobile");
			PopWheels(this, true);
		}
	}
}

void PopWheels(CBlob@ this, bool addparticles = true)
{
	this.getShape().setFriction(0.75f);   //grippy now

	if (!isClient()) //don't bother w/o graphics
		return;

	CSprite@ sprite = this.getSprite();

	Vec2f pos = this.getPosition();
	Vec2f vel = this.getVelocity();

	//remove wheels
	for (int i = 0; i < sprite.getSpriteLayerCount(); ++i)
	{
		CSpriteLayer@ wheel = sprite.getSpriteLayer(i);
		if (wheel !is null && wheel.name.substr(0, 2) == "!w")
		{
			if (addparticles)
			{
				//todo: wood falling sounds...
				makeGibParticle("IronWheel.png", pos + wheel.getOffset(), vel + getRandomVelocity(90, 5, 80), 0, 0, Vec2f(16, 16), 2.0f, 20, "/material_drop", 0);
			}

			sprite.RemoveSpriteLayer(wheel.name);
			i--;
		}
	}

	//add chocks
	CSpriteLayer@ chocks = sprite.addSpriteLayer("!chocks", "IronWheel.png", 16, 16);
	if (chocks !is null)
	{
		Animation@ anim = chocks.addAnimation("default", 0, false);
		anim.AddFrame(1);
		chocks.SetOffset(Vec2f(0, 9.0f));
	}
}
