// Medic logic

#include "MedicCommon.as"
#include "ActivationThrowCommon.as"
#include "KnockedCommon.as"
#include "Hitters.as"
#include "RunnerCommon.as"
#include "Requirements.as"
#include "GameplayEventsCommon.as";
#include "SplashWater.as";// but only getBombForce()
#include "RedBarrierCommon.as"
#include "StandardControlsCommon.as";

void onInit(CBlob@ this)
{
	MedicInfo medic;
	this.set("medicInfo", @medic);

	this.set_u8("spray type", 255);
	this.set_f32("gib health", -1.5f);
	this.Tag("player");
	this.Tag("flesh");

	ControlsSwitch@ controls_switch = @onSwitch;
	this.set("onSwitch handle", @controls_switch);

	ControlsCycle@ controls_cycle = @onCycle;
	this.set("onCycle handle", @controls_cycle);

	//centered on arrows
	//this.set_Vec2f("inventory offset", Vec2f(0.0f, 122.0f));
	//centered on items
	this.set_Vec2f("inventory offset", Vec2f(0.0f, 0.0f));

	//no spinning
	this.getShape().SetRotationsAllowed(false);
	this.getShape().getConsts().net_threshold_multiplier = 0.5f;

	const string texName = "Entities/Characters/Medic/MedicIcons.png";
	AddIconToken("$WaterJar$", texName, Vec2f(16, 32), 1);
	AddIconToken("$AcidJar$", texName, Vec2f(16, 32), 2);

	this.addCommandID("activate/throw spray");
	this.addCommandID("usespray client");
	this.addCommandID("healally");
	this.addCommandID("healally client");
	this.addCommandID(grapple_sync_cmd);

	//add a command ID for each jar type
	for (uint i = 0; i < sprayTypeNames.length; i++)
	{
		this.addCommandID("pick " + sprayTypeNames[i]);
	}

	this.getCurrentScript().runFlags |= Script::tick_not_attached;
	this.getCurrentScript().removeIfTag = "dead";
}

void onSetPlayer(CBlob@ this, CPlayer@ player)
{
	if (player !is null)
	{
		player.SetScoreboardVars("LWBScoreboardIcons.png", 1, Vec2f(16, 16));
	}
}

void ManageGrapple(CBlob@ this, MedicInfo@ medic)
{
	CSprite@ sprite = this.getSprite();
	Vec2f pos = this.getPosition();

	const bool right_click = this.isKeyJustPressed(key_action2);
	if (right_click)
	{
		if (canSend(this) || isServer()) //otherwise grapple
		{
			medic.grappling = true;
			medic.grapple_id = 0xffff;
			medic.grapple_pos = pos;

			medic.grapple_ratio = 1.0f; //allow fully extended

			Vec2f direction = this.getAimPos() - pos;

			//aim in direction of cursor
			f32 distance = direction.Normalize();
			if (distance > 1.0f)
			{
				medic.grapple_vel = direction * medic_grapple_throw_speed;
			}
			else
			{
				medic.grapple_vel = Vec2f_zero;
			}

			SyncGrapple(this);
		}
	}

	if (medic.grappling)
	{
		//update grapple
		//TODO move to its own script?

		if (!this.isKeyPressed(key_action2))
		{
			if (canSend(this) || isServer())
			{
				medic.grappling = false;
				SyncGrapple(this);
			}
		}
		else
		{
			const f32 medic_grapple_range = medic_grapple_length * medic.grapple_ratio;
			const f32 medic_grapple_force_limit = this.getMass() * medic_grapple_accel_limit;

			CMap@ map = this.getMap();

			//reel in
			//TODO: sound
			if (medic.grapple_ratio > 0.2f)
				medic.grapple_ratio -= 1.0f / getTicksASecond();

			//get the force and offset vectors
			Vec2f force;
			Vec2f offset;
			f32 dist;
			{
				force = medic.grapple_pos - this.getPosition();
				dist = force.Normalize();
				f32 offdist = dist - medic_grapple_range;
				if (offdist > 0)
				{
					offset = force * Maths::Min(8.0f, offdist * medic_grapple_stiffness);
					force *= Maths::Min(medic_grapple_force_limit, Maths::Max(0.0f, offdist + medic_grapple_slack) * medic_grapple_force);
				}
				else
				{
					force.Set(0, 0);
				}
			}

			//left map? too long? close grapple
			if (medic.grapple_pos.x < 0 ||
			        medic.grapple_pos.x > (map.tilemapwidth)*map.tilesize ||
			        dist > medic_grapple_length * 3.0f)
			{
				if (canSend(this) || isServer())
				{
					medic.grappling = false;
					SyncGrapple(this);
				}
			}
			else if (medic.grapple_id == 0xffff) //not stuck
			{
				const f32 drag = map.isInWater(medic.grapple_pos) ? 0.7f : 0.90f;
				const Vec2f gravity(0, 1);

				medic.grapple_vel = (medic.grapple_vel * drag) + gravity - (force * (2 / this.getMass()));

				Vec2f next = medic.grapple_pos + medic.grapple_vel;
				next -= offset;

				Vec2f dir = next - medic.grapple_pos;
				f32 delta = dir.Normalize();
				bool found = false;
				const f32 step = map.tilesize * 0.5f;
				while (delta > 0 && !found) //fake raycast
				{
					if (delta > step)
					{
						medic.grapple_pos += dir * step;
					}
					else
					{
						medic.grapple_pos = next;
					}
					delta -= step;
					found = checkGrappleStep(this, medic, map, dist);
				}

			}
			else //stuck -> pull towards pos
			{

				//wallrun/jump reset to make getting over things easier
				//at the top of grapple
				if (this.isOnWall()) //on wall
				{
					//close to the grapple point
					//not too far above
					//and moving downwards
					Vec2f dif = pos - medic.grapple_pos;
					if (this.getVelocity().y > 0 &&
					        dif.y > -10.0f &&
					        dif.Length() < 24.0f)
					{
						//need move vars
						RunnerMoveVars@ moveVars;
						if (this.get("moveVars", @moveVars))
						{
							moveVars.walljumped_side = Walljump::NONE;
						}
					}
				}

				CBlob@ b = null;
				if (medic.grapple_id != 0)
				{
					@b = getBlobByNetworkID(medic.grapple_id);
					if (b is null)
					{
						medic.grapple_id = 0;
					}
				}

				if (b !is null)
				{
					medic.grapple_pos = b.getPosition();
					if (b.isKeyJustPressed(key_action1) ||
					        b.isKeyJustPressed(key_action2) ||
					        this.isKeyPressed(key_use))
					{
						if (canSend(this) || isServer())
						{
							medic.grappling = false;
							SyncGrapple(this);
						}
					}
				}
				else if (shouldReleaseGrapple(this, medic, map))
				{
					if (canSend(this) || isServer())
					{
						medic.grappling = false;
						SyncGrapple(this);
					}
				}

				this.AddForce(force);
				Vec2f target = (this.getPosition() + offset);
				if (!map.rayCastSolid(this.getPosition(), target) &&
					(this.getVelocity().Length() > 2 || !this.isOnMap()))
				{
					this.setPosition(target);
				}

				if (b !is null)
					b.AddForce(-force * (b.getMass() / this.getMass()));

			}
		}

	}
}

void onTick(CBlob@ this)
{
	MedicInfo@ medic;
	if (!this.get("medicInfo", @medic))
	{
		return;
	}

	if (isKnocked(this) || this.isInInventory())
	{
		medic.grappling = false;
		return;
	}

	if (medic.healTimer > 0)
		medic.healTimer--;
	if (medic.sprayTimer > 0)
		medic.sprayTimer--;

	ManageGrapple(this, medic);

	if (this.isMyPlayer())
	{
		if (this.isKeyPressed(key_action1) && medic.healTimer == 0 && this.getBlobCount("mat_medkits") > 0)
		{
			CMap@ map = this.getMap();
			Vec2f vec;
			this.getAimDirection(vec);
			HitInfo@[] hitInfos;
			if (map.getHitInfosFromArc(this.getPosition(), -(vec.Angle()), 90.0f, this.getRadius() + 10.0f, this, @hitInfos))
			{
				//HitInfo objects are sorted, first come closest hits
				CBlob@ mostDamaged;
				f32 mostDamage = 0.0f;
				for (uint i = 0; i < hitInfos.length; i++)
				{
					HitInfo@ hi = hitInfos[i];
					CBlob@ b = hi.blob;

					if (b !is null && this.getTeamNum() == b.getTeamNum() && b.hasTag("player") && !b.hasTag("dead") && b.getHealth() < b.getInitialHealth())// find injured ally player
					{
						if (b.getHealth() < mostDamage || mostDamage == 0.0f)
							@mostDamaged = @b;
							mostDamage = b.getHealth();
					}
				}
				if (mostDamaged !is null)// heal most damaged ally player
				{
					CBitStream params;
					params.write_netid(mostDamaged.getNetworkID());
					this.SendCommand(this.getCommandID("healally"), params);
					medic.healTimer = healPrep;
				}
			}
		}
		// space

		if (this.isKeyJustPressed(key_action3))
		{
			u8 sprayType = this.get_u8("spray type");
			if (sprayType == 255)
			{
				SetFirstAvailableJar(this);
				sprayType = this.get_u8("spray type");
			}
			if (sprayType < sprayTypeNames.length && medic.sprayTimer == 0)
			{
				if (hasItem(this, sprayTypeNames[sprayType]))
				{
					CBitStream params;
					params.write_u8(sprayType);
					this.SendCommand(this.getCommandID("activate/throw spray"), params);

					medic.sprayTimer = sprayPrep;
					SetFirstAvailableJar(this);
					return;
				}
			}
			client_SendThrowOrActivateCommand(this);
			SetFirstAvailableJar(this);
		}
	}
}

bool checkGrappleBarrier(Vec2f pos)
{
	CRules@ rules = getRules();
	if (!shouldBarrier(@rules)) { return false; }

	Vec2f tl, br;
	getBarrierRect(@rules, tl, br);

	return (pos.x > tl.x && pos.x < br.x);
}

bool checkGrappleStep(CBlob@ this, MedicInfo@ medic, CMap@ map, const f32 dist)
{
	if (checkGrappleBarrier(medic.grapple_pos)) // red barrier
	{
		if (canSend(this) || isServer())
		{
			medic.grappling = false;
			SyncGrapple(this);
		}
	}
	else if (grappleHitMap(medic, map, dist))
	{
		medic.grapple_id = 0;

		medic.grapple_ratio = Maths::Max(0.2, Maths::Min(medic.grapple_ratio, dist / medic_grapple_length));

		medic.grapple_pos.y = Maths::Max(0.0, medic.grapple_pos.y);

		if (canSend(this) || isServer()) SyncGrapple(this);

		return true;
	}
	else
	{
		CBlob@ b = map.getBlobAtPosition(medic.grapple_pos);
		if (b !is null)
		{
			if (b is this)
			{
				//can't grapple self if not reeled in
				if (medic.grapple_ratio > 0.5f)
					return false;

				if (canSend(this) || isServer())
				{
					medic.grappling = false;
					SyncGrapple(this);
				}

				return true;
			}
			else if (b.isCollidable() && b.getShape().isStatic() && !b.hasTag("ignore_arrow"))
			{
				//TODO: Maybe figure out a way to grapple moving blobs
				//		without massive desync + forces :)

				medic.grapple_ratio = Maths::Max(0.2, Maths::Min(medic.grapple_ratio, b.getDistanceTo(this) / medic_grapple_length));

				medic.grapple_id = b.getNetworkID();
				if (canSend(this) || isServer())
				{
					SyncGrapple(this);
				}

				return true;
			}
		}
	}

	return false;
}

bool grappleHitMap(MedicInfo@ medic, CMap@ map, const f32 dist = 16.0f)
{
	return  map.isTileSolid(medic.grapple_pos + Vec2f(0, -3)) ||			//fake quad
	        map.isTileSolid(medic.grapple_pos + Vec2f(3, 0)) ||
	        map.isTileSolid(medic.grapple_pos + Vec2f(-3, 0)) ||
	        map.isTileSolid(medic.grapple_pos + Vec2f(0, 3)) ||
	        (dist > 10.0f && map.getSectorAtPosition(medic.grapple_pos, "tree") !is null);   //tree stick
}

bool shouldReleaseGrapple(CBlob@ this, MedicInfo@ medic, CMap@ map)
{
	return !grappleHitMap(medic, map) || this.isKeyPressed(key_use);
}

bool canSend(CBlob@ this)
{
	return (this.isMyPlayer() || this.getPlayer() is null || this.getPlayer().isBot());
}

// clientside
void onCycle(CBitStream@ params)
{
	u16 this_id;
	if (!params.saferead_u16(this_id)) return;

	CBlob@ this = getBlobByNetworkID(this_id);
	if (this is null) return;

	if (sprayTypeNames.length == 0) return;

	// cycle bombs
	u8 type = this.get_u8("spray type");
	int count = 0;
	while (count < sprayTypeNames.length)
	{
		type++;
		count++;
		if (type >= sprayTypeNames.length)
			type = 0;
		if (hasJars(this, type))
		{
			CycleToSprayType(this, type);
			CBitStream sparams;
			sparams.write_u8(type);
			this.SendCommand(this.getCommandID("switch"), sparams);
			break;
		}
	}
}

void onSwitch(CBitStream@ params)
{
	u16 this_id;
	if (!params.saferead_u16(this_id)) return;

	CBlob@ this = getBlobByNetworkID(this_id);
	if (this is null) return;

	if (sprayTypeNames.length == 0) return;

	u8 type;
	if (!params.saferead_u8(type)) return;

	if (hasJars(this, type))
	{
		CycleToSprayType(this, type);
		CBitStream sparams;
		sparams.write_u8(type);
		this.SendCommand(this.getCommandID("switch"), sparams);
	}
}

void onCommand(CBlob@ this, u8 cmd, CBitStream @params)
{
	if (cmd == this.getCommandID("switch") && isServer())
	{
		CPlayer@ callerp = getNet().getActiveCommandPlayer();
		if (callerp is null) return;

		CBlob@ caller = callerp.getBlob();
		if (caller is null) return;

		if (caller !is this) return;
		// cycle bombs
		u8 type;
		if (!params.saferead_u8(type)) return;

		CycleToSprayType(this, type);
	}
	if (cmd == this.getCommandID("healally") && isServer())
	{
		MedicInfo@ medic;
		if (!this.get("medicInfo", @medic))
		{
			return;
		}
		
		u16 allyID;
		if(params !is null && params.saferead_netid(allyID) && (getNet().isClient() || this.getBlobCount("mat_medkits") > 0))// for lag...
		{
			CBlob@ ally = getBlobByNetworkID(allyID);
			if (ally is null) return;
			if (ally.getHealth() >= ally.getInitialHealth()) return;

			f32 oldHealth = ally.getHealth();
			this.TakeBlob("mat_medkits", 1);
			ally.server_Heal(1.0f);
			server_setPoisonOff(ally);
			if(ally.getNetworkID() != this.getNetworkID())// not heal myself
			{
				CPlayer@ p = this.getPlayer();
				if (p !is null)
				{
					GE_MedicHeal(p.getNetworkID(), (ally.getHealth() - oldHealth) * 2);
				}
			}
			CBitStream sparams;
			sparams.write_netid(allyID);
			this.SendCommand(this.getCommandID("healally client"), sparams);
		}
	}
	else if (cmd == this.getCommandID("healally client") && isClient())
	{
		u16 allyID;
		if(params !is null && params.saferead_netid(allyID) && (getNet().isClient() || this.getBlobCount("mat_medkits") > 0))// for lag...
		{
			CBlob@ ally = getBlobByNetworkID(allyID);
			if (ally is null) return;
			this.getSprite().SetAnimation("action");
			Sound::Play("/Heart.ogg", ally.getPosition());
		}
	}
	else if (cmd == this.getCommandID("activate/throw spray") && isServer())
	{
		Vec2f pos = this.getPosition();
		Vec2f vector = this.getAimPos() - this.getPosition();
		Vec2f aimPos = Vec2f_lengthdir(Maths::Min(40.0f, (vector.getLength())), vector.Angle()) + this.getPosition();

		u8 sprayType; 
		if (!params.saferead_u8(sprayType)) return;
		u8 holdingSprayType;

		CBlob @carried = this.getCarriedBlob();

		if (carried !is null)
		{
			bool holding_jar = false;
			// are we actually holding a jar or something else?
			for (uint i = 0; i < sprayTypeNames.length; i++)
			{
				if(carried.getName() == sprayTypeNames[i])
				{
					holding_jar = true;
					holdingSprayType = i;
				}
			}

			if (!holding_jar)
			{
				pos = this.getVelocity();
				Vec2f vel = this.getVelocity();
				ActivateBlob(this, carried, pos, vector, vel);
				return;
			}
		}

		if (sprayType >= sprayTypeNames.length)
			return;

		string sprayTypeName = sprayTypeNames[sprayType];
		if (!hasItem(this, sprayTypeName))
		{
			if (hasItem(this, sprayTypeNames[holdingSprayType]))
			{
				sprayType = holdingSprayType;
				sprayTypeName = sprayTypeNames[sprayType];
			}
			else return;
		}

		Spray(this, sprayType, aimPos);
		TakeItem(this, sprayTypeName);

		CBitStream sparams;
		sparams.write_u8(sprayType);
		sparams.write_Vec2f(aimPos);
		this.SendCommand(this.getCommandID("usespray client"), sparams);

		SetFirstAvailableJar(this);
	}
	else if (cmd == this.getCommandID("usespray client") && isClient())
	{
		u8 type;
		Vec2f sprayPos;
		if(params !is null && params.saferead_u8(type) && params.saferead_Vec2f(sprayPos))
		{
			Spray_client(this, type, sprayPos);
			CSprite@ sprite = this.getSprite();
			sprite.SetAnimation("action");
		}

		SetFirstAvailableJar(this);
	}
	else if (cmd == this.getCommandID(grapple_sync_cmd) && isClient())
	{
		HandleGrapple(this, params, !canSend(this));
	}
	else if (cmd == this.getCommandID("activate/throw"))
	{
		SetFirstAvailableJar(this);
	}
	else if (isServer())
	{
		for (uint i = 0; i < sprayTypeNames.length; i++)
		{
			if (cmd == this.getCommandID("pick " + sprayTypeNames[i]))
			{
				this.set_u8("spray type", i);
				break;
			}
		}
	}
}

void CycleToSprayType(CBlob@ this, u8 sprayType)
{
	this.set_u8("spray type", sprayType);
	if (this.isMyPlayer())
	{
		Sound::Play("/CycleInventory.ogg");
	}
}


void Spray(CBlob@ this, u8 types, Vec2f sprayPos)
{
	// from SprashWater.as, but not blob pos as water pos and add poison/acid
	const uint splash_halfwidth = 3;
	const uint splash_halfheight = 3;
	CMap@ map = this.getMap();
	if (map !is null)
	{
		for (int x_step = -splash_halfwidth - 1; x_step < splash_halfwidth + 1; ++x_step)
		{
			for (int y_step = -splash_halfheight - 1; y_step < splash_halfheight + 1; ++y_step)
			{
				Vec2f wpos = sprayPos + Vec2f(x_step * map.tilesize, y_step * map.tilesize);
				Vec2f outpos;

				//extinguish the fire or destroy tile at this pos
				if (types == SprayType::water)
					map.server_setFireWorldspace(wpos, false);
				else if (!map.isTileGold(map.getTile(wpos).type) && map.getSectorAtPosition(wpos, "no build") is null && types == SprayType::acid)
				{
					map.server_DestroyTile(wpos, 1.0f);
					if (!(map.isTileBackground(map.getTile(wpos)) || map.isTileGroundStuff(map.getTile(wpos).type)))
						map.server_DestroyTile(wpos, 1.0f);// do twice
				}
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
			switch (types)
			{
				case SprayType::water:

				if (this.isOverlapping(blob) && hitHard)// no stun myself , shouldStun is true
				{
					this.server_Hit(blob, sprayPos, bombforce, 0.0f, Hitters::water_stun_force, true);
				}
				else if (hitHard)
				{
					this.server_Hit(blob, sprayPos, bombforce, 0.0f, Hitters::water_stun, true);
				}
				else //still have to hit teamies so we can put them out!
				{
					this.server_Hit(blob, sprayPos, bombforce, 0.0f, Hitters::water, true);
				}
				break;

				case SprayType::acid:
				if (hitHard)
				{
					this.server_Hit(blob, sprayPos, Vec2f_zero,  blob.getMass() >= 150.0f ? 2.0f : 1.0f, Hitters::burn, true);
				}
				break;
			}
		}
	}
}

void Spray_client(CBlob@ this, u8 types, Vec2f sprayPos)
{
	// from SprashWater.as, but not blob pos as water pos and add poison/acid
	const uint splash_halfwidth = 3;
	const uint splash_halfheight = 3;
	CMap@ map = this.getMap();
	Sound::Play("SplashSlow.ogg", this.getPosition(), 3.0f);
	if (map !is null)
	{
		bool is_server = getNet().isServer();

		for (int x_step = -splash_halfwidth - 1; x_step < splash_halfwidth + 1; ++x_step)
		{
			for (int y_step = -splash_halfheight - 1; y_step < splash_halfheight + 1; ++y_step)
			{
				Vec2f wpos = sprayPos + Vec2f(x_step * map.tilesize, y_step * map.tilesize);
				Vec2f outpos;

				switch (types)
				{
					case SprayType::water:
					ParticleAnimated("Splash.png", wpos, Vec2f(0, 0), 0.0f, 1.0f, 3, 0.0f, true);
					break;
					case SprayType::acid:
					ParticleAnimated("AcidSplash.png", wpos, Vec2f(0, 0), 0.0f, 1.0f, 3, 0.0f, true);
					break;

				}
			}
		}
	}
}

//bomb management

bool hasItem(CBlob@ this, const string &in name)
{
	CBitStream reqs, missing;
	AddRequirement(reqs, "blob", name, "Jars", 1);
	CInventory@ inv = this.getInventory();

	if (inv !is null)
	{
		return hasRequirements(inv, reqs, missing);
	}
	else
	{
		warn("our inventory was null! MedicLogic.as");
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
	AddRequirement(reqs, "blob", name, "Jars", 1);
	CInventory@ inv = this.getInventory();

	if (inv !is null)
	{
		if (hasRequirements(inv, reqs, missing))
		{
			server_TakeRequirements(inv, reqs);
		}
		else
		{
			warn("took a bomb even though we dont have one! MedicLogic.as");
		}
	}
	else
	{
		warn("our inventory was null! KnightLogic.as");
	}
}

void SetFirstAvailableJar(CBlob@ this)
{
	u8 type = 255;
	u8 nowType = 255;
	if (this.exists("spray type"))
		nowType = this.get_u8("spray type");

	CInventory@ inv = this.getInventory();

	bool typeReal = (uint(nowType) < sprayTypeNames.length);
	if (typeReal && inv.getItem(sprayTypeNames[nowType]) !is null)
		return;

	for (int i = 0; i < inv.getItemsCount(); i++)
	{
		const string itemname = inv.getItem(i).getName();
		for (uint j = 0; j < sprayTypeNames.length; j++)
		{
			if (itemname == sprayTypeNames[j])
			{
				type = j;
				break;
			}
		}

		if (type != 255)
			break;
	}

	this.set_u8("spray type", type);
}

void Callback_PickSpray(CBitStream@ params)
{
	CPlayer@ player = getLocalPlayer();
	if (player is null) return;

	CBlob@ blob = player.getBlob();
	if (blob is null) return;

	u8 spray_id;
	if (!params.saferead_u8(spray_id)) return;

	string matname = sprayTypeNames[spray_id];
	blob.set_u8("spray type", spray_id);

	blob.SendCommand(blob.getCommandID("pick " + matname));
}

// jar pick menu
void onCreateInventoryMenu(CBlob@ this, CBlob@ forBlob, CGridMenu @gridmenu)
{
	if (sprayTypeNames.length == 0)
	{
		return;
	}

	this.ClearGridMenusExceptInventory();
	Vec2f pos(gridmenu.getUpperLeftPosition().x + 0.5f * (gridmenu.getLowerRightPosition().x - gridmenu.getUpperLeftPosition().x),
	          gridmenu.getUpperLeftPosition().y - 32 * 1 - 2 * 24);
	CGridMenu@ menu = CreateGridMenu(pos, this, Vec2f(sprayTypeNames.length, 2), "Spray");
	u8 jarSel = this.get_u8("spray type");

	if (menu !is null)
	{
		menu.deleteAfterClick = false;

		for (uint i = 0; i < sprayTypeNames.length; i++)
		{
			string matname = sprayTypeNames[i];
			CBitStream params;
			params.write_u8(i);
			CGridButton @button = menu.AddButton(sprayIcons[i], sprayNames[i], "MedicLogic.as", "Callback_PickSpray", params);

			if (button !is null)
			{
				bool enabled = hasJars(this, i);
				button.SetEnabled(enabled);
				button.selectOneOnClick = true;
				if (jarSel == i)
				{
					button.SetSelected(1);
				}
			}
		}
	}
}

void onAttach(CBlob@ this, CBlob@ attached, AttachmentPoint @ap)
{
	MedicInfo@ medic;
	if (!this.get("medicInfo", @medic))
	{
		return;
	}

	if (this.isAttached() && (canSend(this) || isServer()))
	{
		medic.grappling = false;
		SyncGrapple(this);
	}

	for (uint i = 0; i < sprayTypeNames.length; i++)
	{
		if (attached.getName() == sprayTypeNames[i])
		{
			this.set_u8("spray type", i);
			break;
		}
	}
}

void onAddToInventory(CBlob@ this, CBlob@ blob)
{
	const string itemname = blob.getName();

	if (this.getInventory().getItemsCount() == 0)
	{
		for (uint j = 0; j < sprayTypeNames.length; j++)
		{
			if (itemname == sprayTypeNames[j])
			{
				this.set_u8("spray type", j);
				return;
			}
		}
	}
}

void onRemoveFromInventory(CBlob@ this, CBlob@ blob)
{
	CheckSelectedJarRemovedFromInventory(this, blob);
}

void onDetach(CBlob@ this, CBlob@ detached, AttachmentPoint@ attachedPoint)
{
	CheckSelectedJarRemovedFromInventory(this, detached);
}

void CheckSelectedJarRemovedFromInventory(CBlob@ this, CBlob@ blob)
{
	string name = blob.getName();
	if (sprayTypeNames.find(name) > -1 && this.getBlobCount(name) == 0)
	{
		SetFirstAvailableJar(this);
	}
}
