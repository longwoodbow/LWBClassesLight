#include "VehicleCommon.as"
#include "KnockedCommon.as";
#include "Hitters.as";

// Cart anim

void onInit(CSprite@ this)
{
	AddIconToken("$empty_charge_bar$", "../Mods/VehicleGUI/Entities/Vehicles/Common/ChargeBar.png", Vec2f(24, 8), 0);
	AddIconToken("$last_charge_slider$", "../Mods/VehicleGUI/Entities/Vehicles/Common/ChargeBar.png", Vec2f(32, 10), 1);
	AddIconToken("$red_last_charge_slider$", "../Mods/VehicleGUI/Entities/Vehicles/Common/ChargeBar.png", Vec2f(32, 10), 2);
	ReloadSprites(this);
}

void ReloadSprites(CSprite@ sprite)
{
	string filename = sprite.getFilename();

	sprite.SetZ(-25.0f);
	sprite.ReloadSprite(filename);

	// (re)init arm and cage sprites
	sprite.RemoveSpriteLayer("rollcage");
	CSpriteLayer@ rollcage = sprite.addSpriteLayer("rollcage", filename, 48, 32);

	if (rollcage !is null)
	{
		Animation@ anim = rollcage.addAnimation("default", 0, false);
		anim.AddFrame(3);
		rollcage.SetOffset(Vec2f(0, -4.0f));
		rollcage.SetRelativeZ(-0.01f);
	}
}

// Cart logic

const u8 ram_charge = 45;
const u8 ram_delay = 20;

class RamInfo : VehicleInfo
{
	bool canFire(CBlob@ this, AttachmentPoint@ ap)
	{
		if (ap.isKeyPressed(key_action2))
		{
			//cancel
			charge = 0;
			cooldown_time = Maths::Max(cooldown_time, 15);
			return false;
		}

		if (cooldown_time > 0)
		{
			this.Untag("ram attacked");// more check for local host
			return false;
		}

		const bool isActionPressed = ap.isKeyPressed(key_action1);
		if (charge > 0 || isActionPressed)
		{

			if (charge < ram_charge && isActionPressed)
			{
				charge++;

				u8 t = Maths::Round(60.0f * 0.66f);
				if ((charge < t && charge % 10 == 0) || (charge >= t && charge % 5 == 0))
					this.getSprite().PlaySound("/LoadingTick");
				return false;
			}

			if (charge < 10)
				return false;

			return true;
		}

		return false;
	}

	void onFire(CBlob@ this, CBlob@ bullet, const u16 &in fired_charge)
	{
		// don't use this
	}
}

void onInit(CBlob@ this)
{
	Vehicle_Setup(this,
	              30.0f, // move speed
	              0.31f,  // turn speed
	              Vec2f(0.0f, 0.0f), // jump out velocity
	              false,  // inventory access
	              RamInfo()
	             );
	VehicleInfo@ v;
	if (!this.get("VehicleInfo", @v)) return;

	Vehicle_SetupGroundSound(this, v, "WoodenWheelsRolling",  // movement sound
	                         1.0f, // movement sound volume modifier   0.0f = no manipulation
	                         1.0f // movement sound pitch modifier     0.0f = no manipulation
	                        );
	Vehicle_addWheel(this, v, "WoodenWheels.png", 16, 16, 0, Vec2f(-10.0f, 10.0f));
	Vehicle_addWheel(this, v, "WoodenWheels.png", 16, 16, 0, Vec2f(8.0f, 10.0f));

	this.getShape().SetOffset(Vec2f(0, 6));

	// ram seat
	CAttachment@ a = this.getAttachments();
	if (a !is null)
	{
		AttachmentPoint@ ap = a.getAttachmentPointByName("RAM");
		if (ap !is null)
		{
			ap.offsetZ = -10.0f;
			ap.customData = 0;
			ap.offset = Vec2f(-16.0f, -1.0f);
			ap.controller = true;
			ap.radius = 12.0f;
			ap.SetKeysToTake(key_left | key_right | key_up | key_down | key_action1 | key_action2 | key_action3 | key_inventory);
			// wow, seat system works on set keys to take only
		}
	}
	
	//add ram sprite

	CSprite@ sprite = this.getSprite();
	sprite.RemoveSpriteLayer("ram");
	CSpriteLayer@ ram = sprite.addSpriteLayer("ram", "CartRam.png", 32, 16);

	if (ram !is null)
	{
		Animation@ anim = ram.addAnimation("default", 0, false);
		anim.AddFrame(0);
		ram.ResetTransform();
		ram.SetRelativeZ(-20.5f);// cata arm is -10.5f
		//rotation handled by update
	}

	this.addCommandID("ram_attack");
	this.addCommandID("ram client");
}

void onTick(CBlob@ this)
{
	VehicleInfo@ v;
	if (!this.get("VehicleInfo", @v)) return;

	const f32 time_til_fire = Maths::Max(0, Maths::Min(v.fire_time - getGameTime(), ram_delay));
	if (this.hasAttached() || this.get_bool("hadattached") || this.getTickSinceCreated() < 30 || time_til_fire > 0)
	{
		Vehicle_StandardControls(this, v); //just make sure it's updated

		if (v.cooldown_time > 0)
		{
			v.cooldown_time--;
		}

		// similar with GUNNER
		AttachmentPoint@[] aps;
		if (this.getAttachmentPoints(@aps))
		{
			for (uint i = 0; i < aps.length; i++)
			{
				AttachmentPoint@ ap = aps[i];
				CBlob@ blob = ap.getOccupied();

				if (blob !is null && ap.socket)
				{
					if (ap.name == "RAM" && !isKnocked(blob))
					{
						const bool canFireLocally = blob.isMyPlayer() && v.canFire() && getGameTime() > v.network_fire_time && !this.hasTag("ram attacked");// use tag for ignore multi command;
						if (v.canFire(this, ap) && canFireLocally)
						{
							v.network_fire_time = getGameTime() + ram_delay;
							CBitStream params;
							params.write_netid(blob.getNetworkID());
							params.write_u8(v.charge);
							this.SendCommand(this.getCommandID("ram_attack"), params);
							this.Tag("ram attacked");
						}
					}
				}
			}
		}
	
		if (isClient()) //only matters visually on client
		{
			// ram texture update

			CSpriteLayer@ ram = this.getSprite().getSpriteLayer("ram");

			if (ram !is null)
			{
				Vec2f offset = Vec2f(0, 0);

				if (v.charge > 0)
				{
					offset = Vec2f((float(v.charge) / float(ram_charge) * 16), 0);
				}
				else if (v.cooldown_time > 0)
				{
					offset = Vec2f(-(float(v.cooldown_time) / float(ram_delay) * 16), 0);
				}

				ram.SetOffset(offset);
			}
		}
	}
	this.set_bool("hadattached", this.hasAttached());
}

void onCommand(CBlob@ this, u8 cmd, CBitStream @params)
{
	/// RAM
	if (cmd == this.getCommandID("ram_attack") && isServer())
	{
		CBlob@ caller = getBlobByNetworkID(params.read_netid());
		const u8 charge = params.read_u8();
		VehicleInfo@ v;
		if (!this.get("VehicleInfo", @v))
		{
			return;
		}
		if (!v.canFire() || caller is null) return;

		// hit like melee attack
		// base damage check
		f32 damage = Maths::Floor(float(charge) * 5.0f / ram_charge);// 1.0f ~ 5.0f

		f32 radius = this.getRadius();
		CMap@ map = this.getMap();
		Vec2f pos = this.getPosition();

		// repeat hit check for penetrating
		for (u8 j = 0; j < damage; j++)
		{
			// this gathers HitInfo objects which contain blob or tile hit information
			HitInfo@[] hitInfos;
			if (map.getHitInfosFromArc(this.getPosition() + Vec2f((this.isFacingLeft() ? radius : -radius), 0.0f), this.getAngleDegrees() + (this.isFacingLeft() ? 180.0f : 0.0f), 24.0f, radius + 50.0f, this, @hitInfos))
			{
				// HitInfo objects are sorted, first come closest hits
				for (int i =  0; i < hitInfos.size(); i++)
				{
					HitInfo@ hi = hitInfos[i];
					CBlob@ b = hi.blob;

					if (b !is null)
					{
						if (b.hasTag("ignore sword") || !canHit(this, b)) continue;

						f32 temp_damage = 1.0f;
					
						Vec2f hitvec = hi.hitpos - pos;
						if (b.getName() == "log")
						{
							temp_damage /= 3;
							CBlob@ wood = server_CreateBlobNoInit("mat_wood");
							if (wood !is null)
							{
								int quantity = Maths::Ceil(float(temp_damage) * 20.0f);
								int max_quantity = b.getHealth() / 0.024f; // initial log health / max mats
								
								quantity = Maths::Max(
									Maths::Min(quantity, max_quantity),
									0
								);

								wood.Tag('custom quantity');
								wood.Init();
								wood.setPosition(hitInfos[i].hitpos);
								wood.server_SetQuantity(quantity);
							}
						}

						Vec2f velocity = b.getPosition() - pos;
						velocity.Normalize();
						velocity *= 12; // knockback force is same regardless of distance

						this.server_Hit(b, hitInfos[i].hitpos, velocity, temp_damage, Hitters::ram, true);
					}
					else  // hitmap
					{
						bool ground = map.isTileGround(hi.tile);
						bool dirt_stone = map.isTileStone(hi.tile);
						bool dirt_thick_stone = map.isTileThickStone(hi.tile);
						bool gold = map.isTileGold(hi.tile);
						bool wood = map.isTileWood(hi.tile);
						bool stone = map.isTileCastle(hi.tile);
						if (stone || ground || wood || dirt_stone || gold)
						{
							//dont dig through no build zones
							Vec2f tpos = map.getTileWorldPosition(hi.tileOffset) + Vec2f(4, 4);
							bool canhit = map.getSectorAtPosition(tpos, "no build") is null;

							if (canhit)
							{
								// damage check
								//u8 map_damage;

								map.server_DestroyTile(hi.hitpos, 0.1f, this);
								if (gold)
								{
									// Note: 0.1f damage doesn't harvest anything I guess
									// This puts it in inventory - include MaterialCommon
									//Material::fromTile(this, hi.tile, 1.f);
									CBlob@ ore = server_CreateBlobNoInit("mat_gold");
									if (ore !is null)
									{
										ore.Tag('custom quantity');
										ore.Init();
										ore.setPosition(hi.hitpos);
										ore.server_SetQuantity(4);
									}
								}
								else if (dirt_stone)
								{
									int quantity = 4;
									if(dirt_thick_stone)
									{
										quantity = 6;
									}
									CBlob@ ore = server_CreateBlobNoInit("mat_stone");
									if (ore !is null)
									{
										ore.Tag('custom quantity');
										ore.Init();
										ore.setPosition(hi.hitpos);
										ore.server_SetQuantity(quantity);
									}
								}
							}
						}
					}
				}
			}
		}

		// finally set the delay
		v.SetFireDelay(ram_delay); // from Fire() of VehicleCommon.as

		v.charge = 0; // from Catapult.as "fire" command
		v.last_charge = charge; // from onFire of CatapultInfo
		v.cooldown_time = ram_delay; // same, but no complexity formula
		this.Untag("ram attacked");

		CBitStream bt;
		bt.write_u16(caller.getNetworkID());
		bt.write_u16(v.charge);
		this.SendCommand(this.getCommandID("ram client"), bt);
	}
	else if (cmd == this.getCommandID("ram client") && isClient())
	{
		u16 id;
		if (!params.saferead_u16(id)) return;

		u16 charge;
		if (!params.saferead_u16(charge)) return;

		CBlob@ caller = getBlobByNetworkID(id);
		if (caller is null) return;

		v.charge = 0; // from Catapult.as "fire" command
		v.last_charge = charge; // from onFire of CatapultInfo
		v.cooldown_time = ram_delay; // same, but no complexity formula
		this.getSprite().PlaySound("CatapultFire");
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

bool canHit(CBlob@ this, CBlob@ b)
{

	if (b.hasTag("invincible") || b.hasTag("temp blob"))
		return false;

	if (b.hasTag("dead player"))
		return true;

	return b.getTeamNum() != this.getTeamNum();

}

// from VehicleGUI.as
void onRender(CSprite@ this)
{
	if (this is null) return; //can happen with bad reload

	// draw only for local player
	CBlob@ localBlob = getLocalPlayerBlob();
	CBlob@ blob = this.getBlob();

	if (localBlob is null)
	{
		return;
	}

	VehicleInfo@ v;
	if (!blob.get("VehicleInfo", @v))
	{
		return;
	}

	AttachmentPoint@ gunner = blob.getAttachments().getAttachmentPointByName("RAM");
	if (gunner !is null	&& gunner.getOccupied() is localBlob)
	{
		if (60 > 0)
		{
			drawChargeBar(blob, v);
			drawCooldownBar(blob, v);
			drawLastFireCharge(blob, v);
		}
	}
}

void drawChargeBar(CBlob@ blob, VehicleInfo@ v)
{
	Vec2f pos2d = blob.getScreenPos() - Vec2f(0, 60);
	Vec2f dim = Vec2f(20, 8);
	const f32 y = blob.getHeight() * 2.4f;
	const f32 charge_percent = v.charge / float(ram_charge);

	Vec2f ul = Vec2f(pos2d.x - dim.x, pos2d.y + y);
	Vec2f lr = Vec2f(pos2d.x - dim.x + charge_percent * 2.0f * dim.x, pos2d.y + y + dim.y);

	if (blob.isFacingLeft())
	{
		ul -= Vec2f(8, 0);
		lr -= Vec2f(8, 0);
	}

	GUI::DrawIconByName("$empty_charge_bar$", ul);

	if (blob.isFacingLeft())
	{
		const f32 max_dist = ul.x - lr.x;
		ul.x += max_dist + dim.x * 2.0f;
		lr.x += max_dist + dim.x * 2.0f;
	}

	GUI::DrawRectangle(ul + Vec2f(4, 4), lr + Vec2f(4, 4), SColor(0xff0C280D));
	GUI::DrawRectangle(ul + Vec2f(6, 6), lr + Vec2f(2, 4), SColor(0xff316511));
	GUI::DrawRectangle(ul + Vec2f(6, 6), lr + Vec2f(2, 2), SColor(0xff9BC92A));
}

void drawCooldownBar(CBlob@ blob, VehicleInfo@ v)
{
	if (v.cooldown_time > 0)
	{
		Vec2f pos2d = blob.getScreenPos() - Vec2f(0, 60);
		Vec2f dim = Vec2f(20, 8);
		const f32 y = blob.getHeight() * 2.4f;

		const f32 modified_last_charge_percent = Maths::Min(1.0f, float(v.last_charge) / float(ram_charge));
		const f32 modified_cooldown_time_percent = modified_last_charge_percent * (v.cooldown_time / float(ram_delay));

		Vec2f ul = Vec2f(pos2d.x - dim.x, pos2d.y + y);
		Vec2f lr = Vec2f(pos2d.x - dim.x + (modified_cooldown_time_percent) * 2.0f * dim.x, pos2d.y + y + dim.y);

		if (blob.isFacingLeft())
		{
			ul -= Vec2f(8, 0);
			lr -= Vec2f(8, 0);

			f32 max_dist = ul.x - lr.x;
			ul.x += max_dist + dim.x * 2.0f;
			lr.x += max_dist + dim.x * 2.0f;
		}

		GUI::DrawRectangle(ul + Vec2f(4, 4), lr + Vec2f(4, 4), SColor(0xff3B1406));
		GUI::DrawRectangle(ul + Vec2f(6, 6), lr + Vec2f(2, 4), SColor(0xff941B1B));
		GUI::DrawRectangle(ul + Vec2f(6, 6), lr + Vec2f(2, 2), SColor(0xffB73333));
	}
}

void drawLastFireCharge(CBlob@ blob, VehicleInfo@ v)
{
	Vec2f pos2d = blob.getScreenPos() - Vec2f(0, 60);
	Vec2f dim = Vec2f(24, 8);
	const f32 y = blob.getHeight() * 2.4f;

	const f32 last_charge_percent = v.last_charge / float(ram_charge);
	const f32 charge_percent = v.charge / float(ram_charge);

	Vec2f ul = Vec2f(pos2d.x - dim.x, pos2d.y + y);
	Vec2f lr = Vec2f(pos2d.x - dim.x + last_charge_percent * 2.0f * dim.x, pos2d.y + y + dim.y);

	if (blob.isFacingLeft())
	{
		ul -= Vec2f(8, 0);
		lr -= Vec2f(8, 0);
	}

	if (blob.isFacingLeft())
	{
		f32 max_dist = ul.x - lr.x;
		ul.x += max_dist + dim.x * 2.0f;
		lr.x += max_dist + dim.x * 2.0f;
	}

	GUI::DrawIconByName("$last_charge_slider$", blob.isFacingLeft() ? (ul - Vec2f(0, 2)) : Vec2f(lr.x, ul.y - 2));

	const f32 range = (3 / float(ram_charge));

	if (charge_percent > last_charge_percent - range && charge_percent < last_charge_percent + range)
		GUI::DrawIconByName("$red_last_charge_slider$", blob.isFacingLeft() ? (ul - Vec2f(0, 4)) : Vec2f(lr.x, ul.y - 4));
}