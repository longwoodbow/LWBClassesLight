// new bombing system and health bar(without changing cfg file)

#include "VehicleCommon.as"
#include "Hitters.as"
#include "KnockedCommon.as"

// Boat logic

void onInit(CBlob@ this)
{
	Vehicle_Setup(this,
	              47.0f, // move speed
	              0.19f,  // turn speed
	              Vec2f(0.0f, -5.0f), // jump out velocity
	              true  // inventory access
	             );
	VehicleInfo@ v;
	if (!this.get("VehicleInfo", @v)) return;
	Vehicle_SetupAirship(this, v, -350.0f);

	this.SetLight(true);
	this.SetLightRadius(48.0f);
	this.SetLightColor(SColor(255, 255, 240, 171));

	this.set_f32("map dmg modifier", 35.0f);

	//this.getShape().SetOffset(Vec2f(0,0));
	//  this.getShape().getConsts().bullet = true;
//	this.getShape().getConsts().transports = true;

	CSprite@ sprite = this.getSprite();

	// add balloon

	CSpriteLayer@ balloon = sprite.addSpriteLayer("balloon", "Balloon.png", 48, 64);
	if (balloon !is null)
	{
		balloon.addAnimation("default", 0, false);
		int[] frames = { 0, 2, 3 };
		balloon.animation.AddFrames(frames);
		balloon.SetRelativeZ(1.0f);
		balloon.SetOffset(Vec2f(0.0f, -26.0f));
	}

	CSpriteLayer@ background = sprite.addSpriteLayer("background", "Balloon.png", 32, 16);
	if (background !is null)
	{
		background.addAnimation("default", 0, false);
		int[] frames = { 3 };
		background.animation.AddFrames(frames);
		background.SetRelativeZ(-5.0f);
		background.SetOffset(Vec2f(0.0f, -5.0f));
	}

	CSpriteLayer@ burner = sprite.addSpriteLayer("burner", "Balloon.png", 8, 16);
	if (burner !is null)
	{
		{
			Animation@ a = burner.addAnimation("default", 3, true);
			int[] frames = { 41, 42, 43 };
			a.AddFrames(frames);
		}
		{
			Animation@ a = burner.addAnimation("up", 3, true);
			int[] frames = { 38, 39, 40 };
			a.AddFrames(frames);
		}
		{
			Animation@ a = burner.addAnimation("down", 3, true);
			int[] frames = { 44, 45, 44, 46 };
			a.AddFrames(frames);
		}
		burner.SetRelativeZ(1.5f);
		burner.SetOffset(Vec2f(0.0f, -26.0f));
	}

	this.addCommandID("dropBomb");
	this.set_s32("bombTimer", 0);
}

void onTick(CBlob@ this)
{
	if (this.hasAttached())
	{
		if (this.getHealth() > 1.0f)
		{
			VehicleInfo@ v;
			if (!this.get("VehicleInfo", @v)) return;

			Vehicle_StandardControls(this, v);

			//TODO: move to atmosphere damage script
			f32 y = this.getPosition().y;
			if (y < 100)
			{
				if (getGameTime() % 15 == 0)
					this.server_Hit(this, this.getPosition(), Vec2f(0, 0), y < 50 ? (y < 0 ? 2.0f : 1.0f) : 0.25f, 0, true);
			}
		}
		else
		{
			this.server_DetachAll();
			this.setAngleDegrees(this.getAngleDegrees() + (this.isFacingLeft() ? 1 : -1));
			if (this.isOnGround() || this.isInWater())
			{
				this.server_SetHealth(-1.0f);
				this.server_Die();
			}
			else
			{
				//TODO: effects
				if (getGameTime() % 30 == 0)
					this.server_Hit(this, this.getPosition(), Vec2f(0, 0), 0.05f, 0, true);
			}
		}

		// bombing
		if (this.getTickSinceCreated() >= 30 && (this.get_s32("bombTimer") + 90) <= getGameTime())
		{
			AttachmentPoint@[] aps;
			if (this.getAttachmentPoints(@aps))
			{
				for (uint i = 0; i < aps.length; i++)
				{
					AttachmentPoint@ ap = aps[i];
					CBlob@ blob = ap.getOccupied();

					if (blob !is null && blob.isMyPlayer() && ap.socket && ap.name == "FLYER" && ap.isKeyPressed(key_action3) && !isKnocked(blob))
					{
						// bomb check
						CInventory@ inv = this.getInventory();
						for (int i = 0; i < inv.getItemsCount(); i++)
						{
							CBlob@ invBlob = inv.getItem(i);
							if (invBlob.getName() == "bombball")// found bomb
							{		
								CBitStream params;
								params.write_netid(blob.getPlayer().getNetworkID());
								this.SendCommand(this.getCommandID("dropBomb"), params);
								this.set_s32("bombTimer", getGameTime());
								return;
							}
						}
					}
				}
			}
		}
	}
}

void onCommand(CBlob@ this, u8 cmd, CBitStream @params)
{
	if (getNet().isServer() && cmd == this.getCommandID("dropBomb"))
	{
		// double bomb check

		CInventory@ inv = this.getInventory();
		for (int i = 0; i < inv.getItemsCount(); i++)
		{
			CBlob @blob = inv.getItem(i);
			if (blob.getName() == "bombball")
			{
				if(this.server_PutOutInventory(blob))
				{
					blob.setPosition(this.getPosition() + Vec2f(0.0f, 8.0f));
					blob.setVelocity(Vec2f(0.0f, 5.0f));
					u16 netid;
					if (params.saferead_netid(netid)) blob.SetDamageOwnerPlayer(getPlayerByNetworkId(netid));
					return;
				}
			}
		}
	}
}

bool doesCollideWithBlob(CBlob@ this, CBlob@ blob)
{
	return Vehicle_doesCollideWithBlob_ground(this, blob);
}

// SPRITE

void onInit(CSprite@ this)
{
	this.SetZ(-50.0f);
	this.getCurrentScript().tickFrequency = 5;
}

void onTick(CSprite@ this)
{
	CBlob@ blob = this.getBlob();
	f32 ratio = 1.0f - (blob.getHealth() / blob.getInitialHealth());
	this.animation.setFrameFromRatio(ratio);

	CSpriteLayer@ balloon = this.getSpriteLayer("balloon");
	if (balloon !is null)
	{
		if (blob.getHealth() > 1.0f)
			balloon.animation.frame = Maths::Min((ratio) * 3, 1.0f);
		else
			balloon.animation.frame = 2;
	}

	CSpriteLayer@ burner = this.getSpriteLayer("burner");
	AttachmentPoint@ ap = blob.getAttachments().getAttachmentPoint("FLYER");
	if (burner !is null && ap !is null)
	{
		const bool up = ap.isKeyPressed(key_action1);
		const bool down = ap.isKeyPressed(key_action2) || ap.isKeyPressed(key_down);
		burner.SetOffset(Vec2f(0.0f, -14.0f));
		if (up)
		{
			blob.SetLightColor(SColor(255, 255, 240, 200));
			burner.SetAnimation("up");
		}
		else if (down)
		{
			blob.SetLightColor(SColor(255, 255, 200, 171));
			burner.SetAnimation("down");
		}
		else
		{
			blob.SetLightColor(SColor(255, 255, 240, 171));
			burner.SetAnimation("default");
		}
	}
}

// from HealthBar.as
void onRender(CSprite@ this)
{
	if (g_videorecording)
		return;

	CBlob@ blob = this.getBlob();
	
	if (blob.isInInventory())
		return;
	
	Vec2f center = blob.getPosition();
	Vec2f mouseWorld = getControls().getMouseWorldPos();
	const f32 renderRadius = (blob.getRadius()) * 0.95f;
	bool mouseOnBlob = (mouseWorld - center).getLength() < renderRadius;
	if (mouseOnBlob)
	{
		//VV right here VV
		const f32 zoom = getCamera().targetDistance * getDriver().getResolutionScaleFactor();
		Vec2f pos2d = blob.getScreenPos() + Vec2f(0, 30);
		Vec2f dim = Vec2f(24, 8);
		const f32 y = blob.getHeight() * zoom;
		const f32 initialHealth = blob.getInitialHealth();
		if (initialHealth > 0.0f)
		{
			const f32 perc = blob.getHealth() / initialHealth;
			if (perc >= 0.0f)
			{
				GUI::DrawRectangle(Vec2f(pos2d.x - dim.x - 2, pos2d.y + y - 2), Vec2f(pos2d.x + dim.x + 2, pos2d.y + y + dim.y + 2));
				GUI::DrawRectangle(Vec2f(pos2d.x - dim.x + 2, pos2d.y + y + 2), Vec2f(pos2d.x - dim.x + perc * 2.0f * dim.x - 2, pos2d.y + y + dim.y - 2), SColor(0xffac1512));
			}
		}
	}
}