// bomb box logic

#include "Hitters.as";
#include "ActivationThrowCommon.as"

//config

s32 bomb_fuse = 120;

//setup

#include "FireCommon.as"

void onInit(CBlob@ this)
{
	this.getShape().SetRotationsAllowed(false);
	this.getSprite().getConsts().accurateLighting = true;
	this.getShape().getConsts().waterPasses = true;
	this.Tag("place norotate");
	this.set_s16(burn_duration , 300);
	//transfer fire to underlying tiles
	this.Tag(spread_fire_tag);
	// same as mine
	this.set_f32("explosive_radius", 48.0f);
	this.set_f32("explosive_damage", 8.0f);
	this.set_f32("map_damage_radius", 36.0f);
	this.set_f32("map_damage_ratio", 0.5f);
	this.set_bool("map_damage_raycast", true);
	this.set_string("custom_explosion_sound", "KegExplosion.ogg");
	this.set_bool("explosive_teamkill", true);

	this.Tag("activatable");

	Activate@ activation_handle = @onActivate;
	this.set("activate handle", @activation_handle);

	Activate@ deactivation_handle = @onDeactivate;
	this.set("deactivate handle", @deactivation_handle);

	this.addCommandID("activate client");
	this.addCommandID("deactivate client");

	this.Tag("builder always hit");
}

//based satchel

void onTick(CBlob@ this)
{
	if((this.hasTag("placed") && !this.hasTag("initial ignited")) || //add placed tag by onDetach in DemolitionistLogic.as
		(this.isInFlames() && !this.hasTag("exploding")) //ignite it if it is in flames, like keg
		 && isServer())
	{
		server_Activate(this);
		this.Tag("initial ignited");
	}

	// from KegVoodoo.as
	if(this.hasTag("exploding"))
	{
		if (!this.hasTag("activated") && isServer()) //admin frozen?
		{
			server_Deactivate(this);
		}
		else
		{
			s32 timer = this.get_s32("explosion_timer") - getGameTime();

			if (timer <= 0)
			{
				if (getNet().isServer())
				{
					Boom(this);
				}
			}
			else
			{
				SColor lightColor = SColor(255, 255, Maths::Min(255, uint(timer * 0.7)), 0);
				this.SetLightColor(lightColor);

				if (XORRandom(2) == 0)
				{
					sparks(this.getPosition(), this.getAngleDegrees(), 1.5f + (XORRandom(10) / 5.0f), lightColor);
				}

				if (timer < 90)
				{
					f32 speed = 1.0f + (90.0f - f32(timer)) / 90.0f;
					this.getSprite().SetEmitSoundSpeed(speed);
					this.getSprite().SetEmitSoundVolume(speed);
				}
			}
		}
	}
}

f32 onHit(CBlob@ this, Vec2f worldPoint, Vec2f velocity, f32 damage, CBlob@ hitterBlob, u8 customData)
{
	switch (customData)
	{
		case Hitters::water:
			if (hitterBlob.getName() == "bucket" && this.hasTag("exploding") && isServer())
			{
				server_Deactivate(this);
			}
			break;
		case Hitters::fire:
		case Hitters::burn:
			if (!this.hasTag("exploding") && isServer())
			{
				server_Activate(this);
				damage = 0.0f;
			}
			break;
		case Hitters::bomb:
		case Hitters::explosion:
		case Hitters::keg:
		case Hitters::mine:
		case Hitters::mine_special:
		case Hitters::bomb_arrow:
			this.Tag("exploding");
			Boom(this);
			break;
	}

	return damage;
}

//sprite

void onTick(CSprite@ this)
{
	CBlob@ blob = this.getBlob();

	if (blob.hasTag("exploding"))
	{
		s32 timer = blob.get_s32("explosion_timer") - getGameTime();

		if (timer < 0)
		{
			return;
		}

		if (timer > 60)
		{
			this.animation.frame = 0;
		}
		else
		{
			this.animation.frame = 1;
		}
	}
}

void sparks(Vec2f at, f32 angle, f32 speed, SColor color)
{
	Vec2f vel = getRandomVelocity(angle + 90.0f, speed, 45.0f);
	at.y -= 3.0f;
	ParticlePixel(at, vel, color, true, 119);
}


void onDie(CBlob@ this)
{
	this.getSprite().SetEmitSoundPaused(true);
	if (getNet().isServer() && !this.hasTag("exploding") && this.hasTag("placed"))
	{
		CBlob@ mat = server_CreateBlob("mat_bombboxes", 0, this.getPosition());
		CBlob@ attached;
		if (mat !is null && this.get("attached", @attached))
		{
			this.server_DetachFrom(attached);
			!attached.server_Pickup(mat);
		}
	}
}

// run the tick so we explode in inventory
void onThisAddToInventory(CBlob@ this, CBlob@ inventoryBlob)
{
	this.doTickScripts = true;
}

void onActivate(CBitStream@ params)
{
	if (!isServer()) return;

	u16 this_id;
	if (!params.saferead_u16(this_id)) return;

	CBlob@ this = getBlobByNetworkID(this_id);
	if (this is null) return;

	this.Tag("activated");
	this.set_s32("explosion_timer", getGameTime() + bomb_fuse);
	this.Tag("exploding");

	this.Sync("activated", true);
	this.Sync("explosion_timer", true);
	this.Sync("exploding", true);

	// not sure if necessary for server
	this.SetLight(true);
	this.SetLightRadius(this.get_f32("explosive_radius") * 0.5f);

	this.SendCommand(this.getCommandID("activate client"));
}

void onDeactivate(CBitStream@ params)
{
	if (!isServer()) return;

	u16 this_id;
	if (!params.saferead_u16(this_id)) return;

	CBlob@ this = getBlobByNetworkID(this_id);
	if (this is null) return;

	this.Untag("activated");
	this.set_s32("explosion_timer", 0);
	this.Untag("exploding");

	this.Sync("activated", true);
	this.Sync("explosion_timer", true);
	this.Sync("exploding", true);

	// not sure if necessary for server
	this.SetLight(false);

	this.SendCommand(this.getCommandID("deactivate client"));
}

void onCommand(CBlob@ this, u8 cmd, CBitStream @params)
{
	if (cmd == this.getCommandID("activate client") && isClient())
	{
		this.SetLight(true);
		this.SetLightRadius(this.get_f32("explosive_radius") * 0.5f);
		this.getSprite().SetEmitSound("/Sparkle.ogg");
		this.getSprite().SetEmitSoundSpeed(1.0f);
		this.getSprite().SetEmitSoundVolume(1.0f);
		this.getSprite().SetEmitSoundPaused(false);
		this.getSprite().SetAnimation("flaming");
	}
	else if (cmd == this.getCommandID("deactivate client") && isClient())
	{
		this.SetLight(false);
		this.getSprite().SetEmitSoundPaused(true);
		this.getSprite().SetAnimation("default");
	}
}

void Boom(CBlob@ this)
{
	this.server_SetHealth(-1.0f);
	this.server_Die();
}

// turn off the fire to pickup
bool canBePickedUp(CBlob@ this, CBlob@ byBlob)
{
	return !this.hasTag("activated");
}

void onAttach(CBlob@ this, CBlob@ attached, AttachmentPoint @attachedPoint)
{
	if(getNet().isServer() && this.isAttached() && !this.hasTag("exploding") && this.hasTag("placed"))//pickuped after extinguished
	{
		this.set("attached", @attached);
		//this.set("attachedPoint", @attachedPoint);
		Boom(this);//but no explotion
	}
}

void onSetStatic(CBlob@ this, const bool isStatic)
{
	if (!isStatic) return;

	this.getSprite().PlaySound("/build_ladder.ogg");
}