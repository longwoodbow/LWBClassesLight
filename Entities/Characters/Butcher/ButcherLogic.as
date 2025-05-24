// Butcher logic

#include "ButcherCommon.as"
#include "ActivationThrowCommon.as"
#include "KnockedCommon.as"
#include "Hitters.as"
#include "RunnerCommon.as"
#include "ShieldCommon.as";
#include "Help.as";
#include "MakeDustParticle.as";
#include "Requirements.as"
#include "FireParticle.as";
#include "MakeFood.as";
#include "SplashWater.as";// but only getBombForce()
#include "ProductionCommon.as";// for MakeFood.as

void onInit(CBlob@ this)
{
	ButcherInfo butcher;
	this.set("butcherInfo", @butcher);

	this.set_f32("gib health", -1.5f);
	this.Tag("player");
	this.Tag("flesh");

	//centered on arrows
	//this.set_Vec2f("inventory offset", Vec2f(0.0f, 122.0f));
	//centered on items
	this.set_Vec2f("inventory offset", Vec2f(0.0f, 0.0f));

	//no spinning
	this.getShape().SetRotationsAllowed(false);
	this.getShape().getConsts().net_threshold_multiplier = 0.5f;

	this.addCommandID("knife");
	this.addCommandID("throwmeat");
	this.addCommandID("throwmeat client");
	this.addCommandID("oil");
	this.addCommandID("oil client");

	this.getCurrentScript().runFlags |= Script::tick_not_attached;
	this.getCurrentScript().removeIfTag = "dead";
}

void onSetPlayer(CBlob@ this, CPlayer@ player)
{
	if (player !is null)
	{
		player.SetScoreboardVars("ScoreboardIcons.png", 1, Vec2f(16, 16));
	}
}

void onTick(CBlob@ this)
{
	ButcherInfo@ butcher;
	if (!this.get("butcherInfo", @butcher))
	{
		return;
	}

	if (isKnocked(this) || this.isInInventory())
	{
		this.getSprite().SetEmitSoundPaused(true);
		return;
	}

	if (butcher.knife_timer >= 18)
	{
		butcher.knife_timer = 0;
	}
	if (butcher.throw_timer >= 18)
	{
		butcher.throw_timer = 0;
	}

	bool knife = butcher.knife_timer > 0 || this.isKeyPressed(key_action1);
	bool throwing = butcher.throw_timer > 0 || this.isKeyPressed(key_action2);

	if (knife || throwing)
	{
		RunnerMoveVars@ moveVars;
		if (this.get("moveVars", @moveVars))
		{
			moveVars.walkFactor = 0.8f;
			moveVars.jumpFactor = 0.6f;
		}
		this.Tag("prevent crouch");
	}

	// like builder's pickaxe
	if(knife && butcher.throw_timer <= 0)
	{
		butcher.knife_timer++;

		if (butcher.knife_timer == 7)
		{
			Sound::Play("/SwordSlash", this.getPosition());
			if (this.isMyPlayer()) this.SendCommand(this.getCommandID("knife"));
		}
	}
	else if(throwing)
	{
		butcher.throw_timer++;

		if (butcher.throw_timer == 7 && this.isMyPlayer())
		{
			this.SendCommand(this.getCommandID("throwmeat"));
		}
	}
	if(this.isMyPlayer())
	{
		// description
		/*
		if (u_showtutorial && !this.hasTag("spoke description"))
		{
			this.maxChatBubbleLines = 255;
			this.Chat("Get more foods and poison spamming!\n\n[LMB] to use knife, can get steaks and poison meats from corpse\n[RMB] to throw poison meats\n[SPACE] to use oil to burn somethings, can cook steak and fishy");
			this.set_u8("emote", Emotes::off);
			this.set_u32("emotetime", getGameTime() + 300);
			this.Tag("spoke description");
		}
		*/

		// space

		if (this.isKeyJustPressed(key_action3))
		{
			if (hasItem(this, "mat_cookingoils"))
			{
				this.SendCommand(this.getCommandID("oil"));
			}
			else
			{
				client_SendThrowOrActivateCommand(this);
			}
		}
	}
}

void onCommand(CBlob@ this, u8 cmd, CBitStream @params)
{
	if (cmd == this.getCommandID("knife") && isServer())
	{
		if (!getNet().isServer())
		{
			return;
		}

		ButcherInfo@ info;
		if (!this.get("butcherInfo", @info))
		{
			return;
		}

		Vec2f blobPos = this.getPosition();
		Vec2f vel = this.getVelocity();
		Vec2f vec;
		this.getAimDirection(vec);
		Vec2f thinghy(1, 0);
		f32 aimangle = -(vec.Angle());
		if (aimangle < 0.0f)
		{
			aimangle += 360.0f;
		}
		thinghy.RotateBy(aimangle);
		Vec2f pos = blobPos - thinghy * 6.0f + vel + Vec2f(0, -2);
		vel.Normalize();

		f32 radius = this.getRadius();
		CMap@ map = this.getMap();
		bool dontHitMore = false;
		bool dontHitMoreMap = false;
		bool dontHitMoreLogs = false;

		//get the actual aim angle
		f32 exact_aimangle = (this.getAimPos() - blobPos).Angle();

		// this gathers HitInfo objects which contain blob or tile hit information
		HitInfo@[] hitInfos;
		if (map.getHitInfosFromArc(pos, aimangle, 90.0f, radius + 10.0f, this, @hitInfos))
		{
			//HitInfo objects are sorted, first come closest hits
			// start from furthest ones to avoid doing too many redundant raycasts
			for (int i = hitInfos.size() - 1; i >= 0; i--)
			{
				HitInfo@ hi = hitInfos[i];
				CBlob@ b = hi.blob;

				if (b !is null)
				{
					if (b.hasTag("ignore sword") 
					    || !canHit(this, b)) 
					{
						continue;
					}

					Vec2f hitvec = hi.hitpos - pos;

					// we do a raycast to given blob and hit everything hittable between knight and that blob
					// raycast is stopped if it runs into a "large" blob (typically a door)
					// raycast length is slightly higher than hitvec to make sure it reaches the blob it's directed at
					HitInfo@[] rayInfos;
					map.getHitInfosFromRay(pos, -(hitvec).getAngleDegrees(), hitvec.Length() + 2.0f, this, rayInfos);

					for (int j = 0; j < rayInfos.size(); j++)
					{
						CBlob@ rayb = rayInfos[j].blob;
						
						if (rayb is null) break; // means we ran into a tile, don't need blobs after it if there are any
						if (rayb.hasTag("ignore sword") || !canHit(this, rayb)) continue;

						bool large = (rayb.hasTag("blocks sword") || (rayb.hasTag("barricade") && rayb.getTeamNum() != this.getTeamNum())// added here
									 && !rayb.isAttached() && rayb.isCollidable()); // usually doors, but can also be boats/some mechanisms

						f32 temp_damage = 1.0f;
						
						if (rayb.getName() == "log")
						{
							if (!dontHitMoreLogs)
							{
								temp_damage /= 3;
								dontHitMoreLogs = true; // set this here to prevent from hitting more logs on the same tick
								CBlob@ wood = server_CreateBlobNoInit("mat_wood");
								if (wood !is null)
								{
									int quantity = Maths::Ceil(float(temp_damage) * 20.0f);
									int max_quantity = rayb.getHealth() / 0.024f; // initial log health / max mats
									
									quantity = Maths::Max(
										Maths::Min(quantity, max_quantity),
										0
									);

									wood.Tag('custom quantity');
									wood.Init();
									wood.setPosition(rayInfos[j].hitpos);
									wood.server_SetQuantity(quantity);
								}
							}
							else 
							{
								// print("passed a log on " + getGameTime());
								continue; // don't hit the log
							}
						}

						
						Vec2f velocity = rayb.getPosition() - pos;
						velocity.Normalize();
						velocity *= 12; // knockback force is same regardless of distance

						if (rayb.getTeamNum() != this.getTeamNum() || rayb.hasTag("dead player"))
						{
							this.server_Hit(rayb, rayInfos[j].hitpos, velocity, temp_damage, Hitters::kitchenknife, true);
						}
						
						if (large)
						{
							break; // don't raycast past the door after we do damage to it
						}
					}
				}
				else  // hitmap
					if (!dontHitMoreMap)
					{
						bool ground = map.isTileGround(hi.tile);
						bool dirt_stone = map.isTileStone(hi.tile);
						bool dirt_thick_stone = map.isTileThickStone(hi.tile);
						bool gold = map.isTileGold(hi.tile);
						bool wood = map.isTileWood(hi.tile);
						if (ground || wood || dirt_stone || gold)
						{
							Vec2f tpos = map.getTileWorldPosition(hi.tileOffset) + Vec2f(4, 4);
							Vec2f offset = (tpos - blobPos);
							f32 tileangle = offset.Angle();
							f32 dif = Maths::Abs(exact_aimangle - tileangle);
							if (dif > 180)
								dif -= 360;
							if (dif < -180)
								dif += 360;

							dif = Maths::Abs(dif);
							//print("dif: "+dif);

							if (dif < 20.0f)
							{
								//detect corner

								int check_x = -(offset.x > 0 ? -1 : 1);
								int check_y = -(offset.y > 0 ? -1 : 1);
								if (map.isTileSolid(hi.hitpos - Vec2f(map.tilesize * check_x, 0)) &&
								        map.isTileSolid(hi.hitpos - Vec2f(0, map.tilesize * check_y)))
									continue;

								bool canhit = true; //default true if not jab
								info.tileDestructionLimiter++;
								canhit = ((info.tileDestructionLimiter % ((wood || dirt_stone) ? 3 : 2)) == 0);

								//dont dig through no build zones
								canhit = canhit && map.getSectorAtPosition(tpos, "no build") is null;

								dontHitMoreMap = true;
								if (canhit)
								{
									map.server_DestroyTile(hi.hitpos, 0.1f, this);
									info.tileDestructionLimiter = 0;
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
	}
	else if (cmd == this.getCommandID("throwmeat") && isServer())
	{
		if (!this.hasBlob("mat_poisonmeats", 1))// failed
		{
			CBitStream params;
			params.write_bool(false);
			this.SendCommand(this.getCommandID("throwmeat client"), params);
			return;
		}

		Vec2f offset(this.isFacingLeft() ? 2 : -2, -2);

		Vec2f meatPos = this.getPosition() + offset;
		Vec2f aimpos = this.getAimPos();
		Vec2f meatVel = (aimpos - meatPos);
		meatVel.Normalize();
		meatVel *= 10.0f;

		CBlob@ meat = server_CreateBlobNoInit("poisonmeat");
		if (meat !is null)
		{
			meat.SetDamageOwnerPlayer(this.getPlayer());
			meat.Init();
		
			meat.IgnoreCollisionWhileOverlapped(this);
			meat.server_setTeamNum(this.getTeamNum());
			meat.setPosition(meatPos);
			meat.setVelocity(meatVel);
			this.TakeBlob("mat_poisonmeats", 1);
		}

		CBitStream params;
		params.write_bool(true);
		this.SendCommand(this.getCommandID("throwmeat client"), params);
	}
	else if (cmd == this.getCommandID("throwmeat client") && isClient())
	{
		bool success;
		if (!params.saferead_bool(success)) return;

		if (success)
		{
			Sound::Play("/ArgLong", this.getPosition());
		}
		else if (this.isMyPlayer())
		{
			Sound::Play("/NoAmmo");
		}
	}
	else if (cmd == this.getCommandID("oil") && isServer())
	{
		// like knight bomb
		Vec2f pos = this.getVelocity();
		Vec2f vector = this.getAimPos() - this.getPosition();
		Vec2f vel = this.getVelocity();

		CBlob @carried = this.getCarriedBlob();
		bool hasOil = false;

		if (carried !is null)
		{
			if (carried.getName() != "mat_cookingoils")
			{
				ActivateBlob(this, carried, pos, vector, vel);
				return;
			}
			else
			{
				hasOil = true;
			}
		}
		
		if (!hasOil && !hasItem(this, "mat_cookingoils"))// oil is not on hand and inventory
		{
			return;
		}

		vector.y /= -1;
		Vec2f sprayPos = Vec2f_lengthdir(Maths::Min(30.0f, (vector.getLength())), vector.Angle()) + this.getPosition();

		const uint splash_halfwidth = 2;
		const uint splash_halfheight = 2;
		CMap@ map = this.getMap();
		bool cooked = false;
		if (map !is null)
		{
			for (int x_step = -splash_halfwidth; x_step < splash_halfwidth; ++x_step)
			{
				for (int y_step = -splash_halfheight; y_step < splash_halfheight; ++y_step)
				{
					Vec2f wpos = sprayPos + Vec2f(x_step * map.tilesize, y_step * map.tilesize);

					//extinguish the fire or destroy tile at this pos
					map.server_setFireWorldspace(wpos, true);
				}
			}

			const f32 radius = Maths::Max(splash_halfwidth * map.tilesize + map.tilesize, splash_halfheight * map.tilesize + map.tilesize);

			Vec2f offset = Vec2f(splash_halfwidth * map.tilesize + map.tilesize, splash_halfheight * map.tilesize + map.tilesize);
			Vec2f tl = sprayPos - offset * 0.5f;
			Vec2f br = sprayPos + offset * 0.5f;
			CBlob@[] blobs;
			map.getBlobsInBox(tl, br, @blobs);
			for (uint i = 0; i < blobs.length; i++)
			{
				CBlob@ blob = blobs[i];

				bool hitHard = blob.getTeamNum() != this.getTeamNum();

				Vec2f hit_blob_pos = blob.getPosition();
				f32 scale;
				Vec2f bombforce = getBombForce(this, radius, hit_blob_pos, sprayPos, blob.getMass(), scale);
				string blobName = blob.getName();
				if(!blob.isInWater())
				{
					if(blobName == "steak" || blobName == "fishy")
					{
						cookFood(blob);
						if(blobName == "steak") server_MakeFood(blob.getPosition(), "Cooked Steak", 0);
						cooked = true;
					}
					else if (hitHard)
					{
						this.server_Hit(blob, sprayPos, bombforce, 0.25f, Hitters::fire, true);
					}
				}
			}
		}

		CBitStream sparams;
		sparams.write_Vec2f(sprayPos);
		sparams.write_bool(cooked);
		this.SendCommand(this.getCommandID("oil client"), sparams);

		TakeItem(this, "mat_cookingoils");
	}
	else if (cmd == this.getCommandID("oil client") && isClient())
	{
		Vec2f sprayPos;
		if (!params.saferead_Vec2f(sprayPos)) return;
		const uint splash_halfwidth = 2;
		const uint splash_halfheight = 2;
		CMap@ map = this.getMap();
		if (map !is null)
		{
			for (int x_step = -splash_halfwidth; x_step < splash_halfwidth; ++x_step)
			{
				for (int y_step = -splash_halfheight; y_step < splash_halfheight; ++y_step)
				{
					Vec2f wpos = sprayPos + Vec2f(x_step * map.tilesize, y_step * map.tilesize);

					//make a splash!
					makeFireParticle(wpos, 0);
				}
			}
		}

		bool cooked = false;
		if (params.saferead_bool(cooked) && cooked) Sound::Play("Cooked.ogg", this.getPosition(), 3.0f);
		Sound::Play("splat.ogg", this.getPosition(), 3.0f);
		CSprite@ sprite = this.getSprite();
		sprite.SetAnimation("oil");
	}
}

void onHitBlob(CBlob@ this, Vec2f worldPoint, Vec2f velocity, f32 damage, CBlob@ hitBlob, u8 customData)
{
	if (customData == Hitters::sword)
	{
		if (damage > 0.0f && hitBlob.hasTag("flesh") && hitBlob.hasTag("dead") && !hitBlob.hasTag("butched") && hitBlob.getHealth() - hitBlob.get_f32("gib health") <= 0.0f)
		{
			hitBlob.Tag("butched");//safety, no double butcher
			Vec2f blobPos = hitBlob.getPosition();

			if (getNet().isServer())
			{
				CBlob@ meat = server_CreateBlobNoInit("mat_poisonmeats");
				if (meat !is null)
				{
					meat.Tag('custom quantity');
			 		meat.Init();
			 		meat.setPosition(blobPos);
			 		meat.server_SetQuantity(3);
			 	}
				CBlob@ steak = server_CreateBlob("steak");
				if (steak !is null)
				{
			 		steak.setPosition(blobPos);
			 	}
			}
		}

		/*if (blockAttack(hitBlob, velocity, 0.0f))
		{
			this.getSprite().PlaySound("/Stun", 1.0f, this.getSexNum() == 0 ? 1.0f : 1.5f);
			setKnocked(this, 20, true);
		}*/
	}
	if (customData == Hitters::fire && hitBlob.getName() == "keg" && !hitBlob.hasTag("exploding") && !(this.getTeamNum() == hitBlob.getTeamNum()))
	{
		hitBlob.SendCommand(hitBlob.getCommandID("activate"));
	}
}

// as same as knight
// Blame Fuzzle.
bool canHit(CBlob@ this, CBlob@ b)
{
	if (b.hasTag("invincible") || b.hasTag("temp blob"))
		return false;
	
	// don't hit picked up items (except players and specially tagged items)
	return b.hasTag("player") || b.hasTag("slash_while_in_hand") || !isBlobBeingCarried(b);
}

bool isBlobBeingCarried(CBlob@ b)
{	
	CAttachment@ att = b.getAttachments();
	if (att is null)
	{
		return false;
	}

	// Look for a "PICKUP" attachment point where socket=false and occupied=true
	return att.getAttachmentPoint("PICKUP", false, true) !is null;
}

//ball management

bool hasItem(CBlob@ this, const string &in name)
{
	CBitStream reqs, missing;
	AddRequirement(reqs, "blob", name, "Oil Bottles", 1);
	CInventory@ inv = this.getInventory();

	if (inv !is null)
	{
		return hasRequirements(inv, reqs, missing);
	}
	else
	{
		warn("our inventory was null! ButcherLogic.as");
	}

	return false;
}

void TakeItem(CBlob@ this, const string &in name)
{
	CBlob@ carried = this.getCarriedBlob();
	if (carried !is null)
	{
		if (carried.getName() == name)
		{
			carried.server_Die();
			return;
		}
	}

	CBitStream reqs, missing;
	AddRequirement(reqs, "blob", name, "Smoke Balls", 1);
	CInventory@ inv = this.getInventory();

	if (inv !is null)
	{
		if (hasRequirements(inv, reqs, missing))
		{
			server_TakeRequirements(inv, reqs);
		}
		else
		{
			warn("took a ball even though we dont have one! ButcherLogic.as");
		}
	}
	else
	{
		warn("our inventory was null! ButcherLogic.as");
	}
}