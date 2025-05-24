// Demolitionist logic

#include "Hitters.as";
#include "BuilderCommon.as";
#include "DemolitionistCommon.as";
#include "ActivationThrowCommon.as"
#include "RunnerCommon.as";
#include "Help.as";
#include "Requirements.as"
#include "BuilderHittable.as";
#include "PlacementCommon.as";
#include "ParticleSparks.as";
#include "MaterialCommon.as";
#include "KnockedCommon.as"
#include "RedBarrierCommon.as"

const f32 hit_damage = 0.5f;

f32 pickaxe_distance = 10.0f;
u8 delay_between_hit = 12;
u8 delay_between_hit_structure = 10;

void onInit(CBlob@ this)
{
	DemolitionistInfo demolitionist;
	this.set("demolitionistInfo", @demolitionist);

	this.set_f32("gib health", -1.5f);

	this.Tag("player");
	this.Tag("flesh");

	HitData hitdata;
	this.set("hitdata", hitdata);

	PickaxeInfo PI;
	this.set("pi", PI);

	PickaxeInfo SPI; // server
	this.set("spi", SPI);

	this.addCommandID("pickaxe");

	this.addCommandID(grapple_sync_cmd);

	CShape@ shape = this.getShape();
	shape.SetRotationsAllowed(false);
	shape.getConsts().net_threshold_multiplier = 0.5f;

	this.set_Vec2f("inventory offset", Vec2f(0.0f, 160.0f));

	this.getCurrentScript().runFlags |= Script::tick_not_attached;
	this.getCurrentScript().removeIfTag = "dead";
}

void onSetPlayer(CBlob@ this, CPlayer@ player)
{
	if (player !is null)
	{
		player.SetScoreboardVars("LWBScoreboardIcons.png", 14, Vec2f(16, 16));
	}
}

void onTick(CBlob@ this)
{
	DemolitionistInfo@ demolitionist;
	if (!this.get("demolitionistInfo", @demolitionist))
	{
		return;
	}

	if (isKnocked(this) || this.isInInventory())
	{
		demolitionist.grappling = false;
		if (this.isInInventory())
			return;
	}

	ManageGrapple(this, demolitionist);

	const bool ismyplayer = this.isMyPlayer();

	if (ismyplayer && getHUD().hasMenus())
	{
		return;
	}

	// activate/throw
	if (ismyplayer)
	{
		Pickaxe(this, demolitionist);
		if (this.isKeyJustPressed(key_action3))
		{
			CBlob@ carried = this.getCarriedBlob();
			if (carried is null || !carried.hasTag("temp blob"))
			{
				client_SendThrowOrActivateCommand(this);
			}
		}
	}

	QueuedHit@ queued_hit;
	if (this.get("queued pickaxe", @queued_hit))
	{
		if (queued_hit !is null && getGameTime() >= queued_hit.scheduled_tick)
		{
			HandlePickaxeCommand(this, queued_hit.params);
			this.set("queued pickaxe", null);
		}
	}

	// slow down walking
	if (this.isKeyPressed(key_action1) && isPickaxeTime(this))
	{
		RunnerMoveVars@ moveVars;
		if (this.get("moveVars", @moveVars))
		{
			moveVars.walkFactor = 0.5f;
			moveVars.jumpFactor = 0.5f;
		}
		this.Tag("prevent crouch");
	}

	if (ismyplayer && this.isKeyPressed(key_action1) && !this.isKeyPressed(key_inventory) && !isPickaxeTime(this)) //Don't let the builder place blocks if he/she is selecting which one to place
	{
		BlockCursor @bc;
		this.get("blockCursor", @bc);

		HitData@ hitdata;
		this.get("hitdata", @hitdata);
		hitdata.blobID = 0;
		hitdata.tilepos = bc.buildable ? bc.tileAimPos : Vec2f(-8, -8);

		if(this.getCarriedBlob() is null && demolitionist.action_type == ActionType::bomb && this.isKeyJustPressed(key_action1))// reload building blob
			this.SendCommand(this.getCommandID("setbomb"));
		else if(this.getCarriedBlob() is null && demolitionist.action_type == ActionType::wood && this.isKeyJustPressed(key_action1))// reload building blob
			this.SendCommand(this.getCommandID("setwood"));
		else if(this.getCarriedBlob() is null && demolitionist.action_type == ActionType::stone && this.isKeyJustPressed(key_action1))// reload building blob
			this.SendCommand(this.getCommandID("setstone"));
	}

	// get rid of the built item
	if (this.isKeyJustPressed(key_inventory) || this.isKeyJustPressed(key_pickup))
	{
		this.set_u8("buildblob", 255);
		this.set_TileType("buildtile", 0);

		CBlob@ blob = this.getCarriedBlob();
		if (blob !is null && blob.hasTag("temp blob"))
		{
			blob.Untag("temp blob");
			blob.server_Die();
		}
	}
}

void ManageGrapple(CBlob@ this, DemolitionistInfo@ demolitionist)
{
	CSprite@ sprite = this.getSprite();
	Vec2f pos = this.getPosition();

	const bool right_click = this.isKeyJustPressed(key_action2);

	if (right_click)
	{
		if (canSend(this) || isServer()) //otherwise grapple
		{
			demolitionist.grappling = true;
			demolitionist.grapple_id = 0xffff;
			demolitionist.grapple_pos = pos;

			demolitionist.grapple_ratio = 1.0f; //allow fully extended

			Vec2f direction = this.getAimPos() - pos;

			//aim in direction of cursor
			f32 distance = direction.Normalize();
			if (distance > 1.0f)
			{
				demolitionist.grapple_vel = direction * demolitionist_grapple_throw_speed;
			}
			else
			{
				demolitionist.grapple_vel = Vec2f_zero;
			}

			SyncGrapple(this);
		}
	}

	if (demolitionist.grappling)
	{
		//update grapple
		//TODO move to its own script?

		if (!this.isKeyPressed(key_action2))
		{
			if (canSend(this) || isServer())
			{
				demolitionist.grappling = false;
				SyncGrapple(this);
			}
		}
		else
		{
			const f32 demolitionist_grapple_range = demolitionist_grapple_length * demolitionist.grapple_ratio;
			const f32 demolitionist_grapple_force_limit = this.getMass() * demolitionist_grapple_accel_limit;

			CMap@ map = this.getMap();

			//reel in
			//TODO: sound
			if (demolitionist.grapple_ratio > 0.2f)
				demolitionist.grapple_ratio -= 1.0f / getTicksASecond();

			//get the force and offset vectors
			Vec2f force;
			Vec2f offset;
			f32 dist;
			{
				force = demolitionist.grapple_pos - this.getPosition();
				dist = force.Normalize();
				f32 offdist = dist - demolitionist_grapple_range;
				if (offdist > 0)
				{
					offset = force * Maths::Min(8.0f, offdist * demolitionist_grapple_stiffness);
					force *= Maths::Min(demolitionist_grapple_force_limit, Maths::Max(0.0f, offdist + demolitionist_grapple_slack) * demolitionist_grapple_force);
				}
				else
				{
					force.Set(0, 0);
				}
			}

			//left map? too long? close grapple
			if (demolitionist.grapple_pos.x < 0 ||
			        demolitionist.grapple_pos.x > (map.tilemapwidth)*map.tilesize ||
			        dist > demolitionist_grapple_length * 3.0f)
			{
				if (canSend(this) || isServer())
				{
					demolitionist.grappling = false;
					SyncGrapple(this);
				}
			}
			else if (demolitionist.grapple_id == 0xffff) //not stuck
			{
				const f32 drag = map.isInWater(demolitionist.grapple_pos) ? 0.7f : 0.90f;
				const Vec2f gravity(0, 1);

				demolitionist.grapple_vel = (demolitionist.grapple_vel * drag) + gravity - (force * (2 / this.getMass()));

				Vec2f next = demolitionist.grapple_pos + demolitionist.grapple_vel;
				next -= offset;

				Vec2f dir = next - demolitionist.grapple_pos;
				f32 delta = dir.Normalize();
				bool found = false;
				const f32 step = map.tilesize * 0.5f;
				while (delta > 0 && !found) //fake raycast
				{
					if (delta > step)
					{
						demolitionist.grapple_pos += dir * step;
					}
					else
					{
						demolitionist.grapple_pos = next;
					}
					delta -= step;
					found = checkGrappleStep(this, demolitionist, map, dist);
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
					Vec2f dif = pos - demolitionist.grapple_pos;
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
				if (demolitionist.grapple_id != 0)
				{
					@b = getBlobByNetworkID(demolitionist.grapple_id);
					if (b is null)
					{
						demolitionist.grapple_id = 0;
					}
				}

				if (b !is null)
				{
					demolitionist.grapple_pos = b.getPosition();
					if (b.isKeyJustPressed(key_action1) ||
					        b.isKeyJustPressed(key_action2) ||
					        this.isKeyPressed(key_use))
					{
						if (canSend(this) || isServer())
						{
							demolitionist.grappling = false;
							SyncGrapple(this);
						}
					}
				}
				else if (shouldReleaseGrapple(this, demolitionist, map))
				{
					if (canSend(this) || isServer())
					{
						demolitionist.grappling = false;
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

//helper class to reduce function definition cancer
//and allow passing primitives &inout
class SortHitsParams
{
	Vec2f aimPos;
	Vec2f tilepos;
	Vec2f pos;
	bool justCheck;
	bool extra;
	bool hasHit;
	HitInfo@ bestinfo;
	f32 bestDistance;
};

//helper class to reduce function definition cancer
//and allow passing primitives &inout
class PickaxeInfo
{
	u32 pickaxe_timer;
	u32 last_pickaxed;
	bool last_hit_structure;
};

void Pickaxe(CBlob@ this, DemolitionistInfo@ demolitionist)
{
	HitData@ hitdata;
	this.get("hitdata", @hitdata);

	PickaxeInfo@ PI;
	if (!this.get("pi", @PI)) return;

	// magic number :D
	if (getGameTime() - PI.last_pickaxed >= 12 && isClient())
	{
		this.get("hitdata", @hitdata);
		hitdata.blobID = 0;
		hitdata.tilepos = Vec2f_zero;
	}

	u8 delay = delay_between_hit;
	if (PI.last_hit_structure) delay = delay_between_hit_structure;

	if (PI.pickaxe_timer >= delay)
	{
		PI.pickaxe_timer = 0;
	}

	bool just_pressed = false;
	if (this.isKeyPressed(key_action1) && PI.pickaxe_timer == 0 && demolitionist.action_type == ActionType::pickaxe)
	{
		just_pressed = true;
		PI.pickaxe_timer++;
	}

	if (PI.pickaxe_timer == 0) return;

	if (PI.pickaxe_timer > 0 && !just_pressed)
	{
		PI.pickaxe_timer++;
	}

	bool justCheck = PI.pickaxe_timer == 5;
	if (!justCheck) return;

	// we can only hit blocks with pickaxe on 5th tick of hitting, every 10/12 ticks

	this.get("hitdata", @hitdata);

	if (hitdata is null) return;

	Vec2f blobPos = this.getPosition();
	Vec2f aimPos = this.getAimPos();
	Vec2f aimDir = aimPos - blobPos;

	// get tile surface for aiming at little static blobs
	Vec2f normal = aimDir;
	normal.Normalize();

	Vec2f attackVel = normal;

	hitdata.blobID = 0;
	hitdata.tilepos = Vec2f_zero;

	f32 arcdegrees = 90.0f;

	f32 aimangle = aimDir.Angle();
	Vec2f pos = blobPos - Vec2f(2, 0).RotateBy(-aimangle);
	f32 attack_distance = this.getRadius() + pickaxe_distance;
	f32 radius = this.getRadius();
	CMap@ map = this.getMap();
	bool dontHitMore = false;

	bool hasHit = false;

	const f32 tile_attack_distance = attack_distance * 1.5f;
	Vec2f tilepos = blobPos + normal * Maths::Min(aimDir.Length() - 1, tile_attack_distance);
	Vec2f surfacepos;
	map.rayCastSolid(blobPos, tilepos, surfacepos);

	Vec2f surfaceoff = (tilepos - surfacepos);
	f32 surfacedist = surfaceoff.Normalize();
	tilepos = (surfacepos + (surfaceoff * (map.tilesize * 0.5f)));

	// this gathers HitInfo objects which contain blob or tile hit information
	HitInfo@ bestinfo = null;
	f32 bestDistance = 100000.0f;

	HitInfo@[] hitInfos;

	//setup params for ferrying data in/out
	SortHitsParams@ hit_p = SortHitsParams();

	//copy in
	hit_p.aimPos = aimPos;
	hit_p.tilepos = tilepos;
	hit_p.pos = pos;
	hit_p.justCheck = justCheck;
	hit_p.extra = true;
	hit_p.hasHit = hasHit;
	@(hit_p.bestinfo) = bestinfo;
	hit_p.bestDistance = bestDistance;

	if (map.getHitInfosFromArc(pos, -aimangle, arcdegrees, attack_distance, this, @hitInfos))
	{
		SortHits(this, hitInfos, hit_damage, hit_p);
	}

	aimPos = hit_p.aimPos;
	tilepos = hit_p.tilepos;
	pos = hit_p.pos;
	justCheck = hit_p.justCheck;
	hasHit = hit_p.hasHit;
	@bestinfo = hit_p.bestinfo;
	bestDistance = hit_p.bestDistance;

	Tile tile = map.getTile(tilepos);
	bool noBuildZone = inNoBuildZone(map, tilepos, tile.type);
	bool isgrass = false;

	if ((tilepos - aimPos).Length() < bestDistance - 4.0f && map.getBlobAtPosition(tilepos) is null)
	{
		Tile tile = map.getTile(surfacepos);

		if (!noBuildZone && !map.isTileGroundBack(tile.type))
		{
			//normal, honest to god tile
			if (map.isTileBackgroundNonEmpty(tile) || map.isTileSolid(tile))
			{
				hasHit = true;
				hitdata.tilepos = tilepos;
			}
			else if (map.isTileGrass(tile.type))
			{
				//NOT hashit - check last for grass
				isgrass = true;
			}
		}
	}

	if (!hasHit)
	{
		//copy in
		hit_p.aimPos = aimPos;
		hit_p.tilepos = tilepos;
		hit_p.pos = pos;
		hit_p.justCheck = justCheck;
		hit_p.extra = false;
		hit_p.hasHit = hasHit;
		@(hit_p.bestinfo) = bestinfo;
		hit_p.bestDistance = bestDistance;

		//try to find another possible one
		if (bestinfo is null)
		{
			SortHits(this, hitInfos, hit_damage, hit_p);
		}

		//copy out
		aimPos = hit_p.aimPos;
		tilepos = hit_p.tilepos;
		pos = hit_p.pos;
		justCheck = hit_p.justCheck;
		hasHit = hit_p.hasHit;
		@bestinfo = hit_p.bestinfo;
		bestDistance = hit_p.bestDistance;

		//did we find one (or have one from before?)
		if (bestinfo !is null)
		{
			hitdata.blobID = bestinfo.blob.getNetworkID();
		}
	}

	if (isgrass && bestinfo is null)
	{
		hitdata.tilepos = tilepos;
	}

	bool hitting_structure = false; // hitting player-built blocks -> smaller delay

	if (hitdata.blobID == 0)
	{
		CBitStream params;
		params.write_u16(0);
		params.write_Vec2f(hitdata.tilepos);
		this.SendCommand(this.getCommandID("pickaxe"), params);

		TileType t = getMap().getTile(hitdata.tilepos).type;
		if (t != CMap::tile_empty && t != CMap::tile_ground_back)
		{
			uint16 type = map.getTile(hitdata.tilepos).type;
			if (!inNoBuildZone(map, hitdata.tilepos, type))
			{
				// for smaller delay
				if (map.isTileWood(type) || // wood tile
					(type >= CMap::tile_wood_back && type <= 207) || // wood backwall
					map.isTileCastle(type) || // castle block
					(type >= CMap::tile_castle_back && type <= 79) || // castle backwall
					 type == CMap::tile_castle_back_moss) // castle mossbackwall
				{
					hitting_structure = true;
				}
			}

			if (map.isTileBedrock(type))
			{
				this.getSprite().PlaySound("/metal_stone.ogg");
				sparks(tilepos, attackVel.Angle(), 1.0f);
			}
		}
	}
	else
	{
		CBlob@ b = getBlobByNetworkID(hitdata.blobID);
		if (b !is null)
		{
			CBitStream params;
			params.write_u16(hitdata.blobID);
			params.write_Vec2f(hitdata.tilepos);
			this.SendCommand(this.getCommandID("pickaxe"), params);

			// for smaller delay
			string attacked_name = b.getName();
			if (attacked_name == "bridge" ||
				attacked_name == "wooden_platform" ||
				b.hasTag("door") ||
				attacked_name == "ladder" ||
				attacked_name == "spikes" ||
				b.hasTag("builder fast hittable")
				)
			{
				hitting_structure = true;
			}
		}
	}

	PI.last_hit_structure = hitting_structure;
	PI.last_pickaxed = getGameTime();
}

void SortHits(CBlob@ this, HitInfo@[]@ hitInfos, f32 damage, SortHitsParams@ p)
{
	//HitInfo objects are sorted, first come closest hits
	for (uint i = 0; i < hitInfos.length; i++)
	{
		HitInfo@ hi = hitInfos[i];

		CBlob@ b = hi.blob;
		if (b !is null) // blob
		{
			if (!canHit(this, b, p.tilepos, p.extra))
			{
				continue;
			}

			if (!p.justCheck && isUrgent(this, b))
			{
				p.hasHit = true;			
			}
			else
			{
				bool never_ambig = neverHitAmbiguous(b);
				f32 len = never_ambig ? 1000.0f : (p.aimPos - b.getPosition()).Length();
				if (len < p.bestDistance)
				{
					if (!never_ambig)
						p.bestDistance = len;

					@(p.bestinfo) = hi;
				}
			}
		}
	}
}

bool ExtraQualifiers(CBlob@ this, CBlob@ b, Vec2f tpos)
{
	//urgent stuff gets a pass here
	if (isUrgent(this, b))
		return true;

	//check facing - can't hit stuff we're facing away from
	f32 dx = (this.getPosition().x - b.getPosition().x) * (this.isFacingLeft() ? 1 : -1);
	if (dx < 0)
		return false;

	//only hit static blobs if aiming directly at them
	CShape@ bshape = b.getShape();
	if (bshape.isStatic())
	{
		bool bigenough = bshape.getWidth() >= 8 &&
		                 bshape.getHeight() >= 8;

		if (bigenough)
		{
			if (!b.isPointInside(this.getAimPos()) && !b.isPointInside(tpos))
			{
				return false;
			}
		}
		else
		{
			Vec2f bpos = b.getPosition();
			//get centered on the tile it's positioned on (for offset blobs like spikes)
			Vec2f tileCenterPos = Vec2f(s32(bpos.x / 8), s32(bpos.y / 8)) * 8 + Vec2f(4, 4);
			f32 dist = Maths::Min((tileCenterPos - this.getAimPos()).LengthSquared(),
			                      (tileCenterPos - tpos).LengthSquared());
			if (dist > 25) //>5*5
				return false;
		}
	}

	return true;
}

bool neverHitAmbiguous(CBlob@ b)
{
	string name = b.getName();
	return name == "saw";
}

bool canHit(CBlob@ this, CBlob@ b, Vec2f tpos, bool extra = true)
{
	if (this is b) return false;

	if (extra && !ExtraQualifiers(this, b, tpos))
	{
		return false;
	}

	if (b.hasTag("invincible"))
	{
		return false;
	}

	if (b.getTeamNum() == this.getTeamNum())
	{
		//no hitting friendly carried stuff
		if (b.isAttached())
			return false;

		if (BuilderAlwaysHit(b) || b.hasTag("dead") || b.hasTag("vehicle"))
			return true;

		if (b.getName() == "saw" || b.getName() == "trampoline" || b.getName() == "crate")
			return true;

		return false;

	}
	else if (b.getName() == "statue")//enemy statues, it's not my team bacause of over. can I make statue can be hit by genuine builder?
	{
		return true;
	}
	//no hitting stuff in hands
	else if (b.isAttached() && !b.hasTag("player"))
	{
		return false;
	}

	//static/background stuff
	CShape@ b_shape = b.getShape();
	if (!b.isCollidable() || (b_shape !is null && b_shape.isStatic()))
	{
		//maybe we shouldn't hit this..
		//check if we should always hit
		if (BuilderAlwaysHit(b))
		{
			if (!b.isCollidable() && !isUrgent(this, b))
			{
				//TODO: use a better overlap check here
				//this causes issues with quarters and
				//any other case where you "stop overlapping"
				if (!this.isOverlapping(b))
					return false;
			}
			return true;
		}
		//otherwise no hit
		return false;
	}

	return true;
}

class QueuedHit
{
	CBitStream params;
	int scheduled_tick;
}

void HandlePickaxeCommand(CBlob@ this, CBitStream@ params)
{
	PickaxeInfo@ SPI;
	if (!this.get("spi", @SPI)) return;

	u16 blobID;
	Vec2f tilepos;

	if (!params.saferead_u16(blobID)) return;
	if (!params.saferead_Vec2f(tilepos)) return;

	Vec2f blobPos = this.getPosition();
	Vec2f aimPos = this.getAimPos();
	Vec2f attackVel = aimPos - blobPos;

	attackVel.Normalize();

	bool hitting_structure = false;

	if (blobID == 0)
	{
		CMap@ map = getMap();
		TileType t = map.getTile(tilepos).type;
		if (t != CMap::tile_empty && t != CMap::tile_ground_back)
		{
			// 5 blocks range check
			Vec2f tsp = map.getTileSpacePosition(tilepos);
			Vec2f wsp = map.getTileWorldPosition(tsp);
			wsp += Vec2f(4, 4); // get center of block
			f32 distance = Vec2f(blobPos - wsp).Length();
			if (distance > 40.0f) return;

			uint16 type = map.getTile(tilepos).type;
			if (!inNoBuildZone(map, tilepos, type))
			{
				map.server_DestroyTile(tilepos, 1.0f, this);
				Material::fromTile(this, type, 1.0f);
			}

			// for smaller delay
			if (map.isTileWood(type) || // wood tile
				(type >= CMap::tile_wood_back && type <= 207) || // wood backwall
				map.isTileCastle(type) || // castle block
				(type >= CMap::tile_castle_back && type <= 79) || // castle backwall
					type == CMap::tile_castle_back_moss) // castle mossbackwall
			{
				hitting_structure = true;
			}
		}
	}
	else
	{
		CBlob@ b = getBlobByNetworkID(blobID);
		if (b !is null)
		{
			// 4 blocks range check
			f32 distance = this.getDistanceTo(b);
			if (distance > 32.0f) return;

			bool isdead = b.hasTag("dead");

			f32 attack_power = hit_damage;

			if (isdead) //double damage to corpses
			{
				attack_power *= 2.0f;
			}

			const bool teamHurt = !b.hasTag("flesh") || isdead;

			if (isServer())
			{
				this.server_Hit(b, tilepos, attackVel, attack_power, Hitters::builder, teamHurt);
				Material::fromBlob(this, b, attack_power);
			}

			// for smaller delay
			string attacked_name = b.getName();
			if (attacked_name == "bridge" ||
				attacked_name == "wooden_platform" ||
				b.hasTag("door") ||
				attacked_name == "ladder" ||
				attacked_name == "spikes" ||
				b.hasTag("builder fast hittable")
				)
			{
				hitting_structure = true;
			}
		}
	}

	SPI.last_hit_structure = hitting_structure;
	SPI.last_pickaxed = getGameTime();
}

void onCommand(CBlob@ this, u8 cmd, CBitStream @params)
{
	if (cmd == this.getCommandID("pickaxe") && isServer())
	{
		PickaxeInfo@ SPI;
		if (!this.get("spi", @SPI)) return;

		u8 delay = delay_between_hit;
		if (SPI.last_hit_structure) delay = delay_between_hit_structure;

		QueuedHit@ queued_hit;
		if (this.get("queued pickaxe", @queued_hit))
		{
			if (queued_hit !is null)
			{
				// cancel queued hit.
				return;
			}
		}

		// allow for one queued hit in-flight; reject any incoming one in the
		// mean time (would only happen with massive lag in legit scenarios)
		if (getGameTime() - SPI.last_pickaxed < delay)
		{
			QueuedHit queued_hit;
			queued_hit.params = params;
			queued_hit.scheduled_tick = SPI.last_pickaxed + delay;
			this.set("queued pickaxe", @queued_hit);
			return;
		}

		HandlePickaxeCommand(this, @params);
	}
	else if (cmd == this.getCommandID(grapple_sync_cmd) && isClient())
	{
		HandleGrapple(this, params, !canSend(this));
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

bool checkGrappleStep(CBlob@ this, DemolitionistInfo@ demolitionist, CMap@ map, const f32 dist)
{
	if (checkGrappleBarrier(demolitionist.grapple_pos)) // red barrier
	{
		if (canSend(this) || isServer())
		{
			demolitionist.grappling = false;
			SyncGrapple(this);
		}
	}
	else if (grappleHitMap(demolitionist, map, dist))
	{
		demolitionist.grapple_id = 0;

		demolitionist.grapple_ratio = Maths::Max(0.2, Maths::Min(demolitionist.grapple_ratio, dist / demolitionist_grapple_length));

		demolitionist.grapple_pos.y = Maths::Max(0.0, demolitionist.grapple_pos.y);

		if (canSend(this) || isServer()) SyncGrapple(this);

		return true;
	}
	else
	{
		CBlob@ b = map.getBlobAtPosition(demolitionist.grapple_pos);
		if (b !is null)
		{
			if (b is this)
			{
				//can't grapple self if not reeled in
				if (demolitionist.grapple_ratio > 0.5f)
					return false;

				if (canSend(this) || isServer())
				{
					demolitionist.grappling = false;
					SyncGrapple(this);
				}

				return true;
			}
			else if (b.isCollidable() && b.getShape().isStatic() && !b.hasTag("ignore_arrow"))
			{
				//TODO: Maybe figure out a way to grapple moving blobs
				//		without massive desync + forces :)

				demolitionist.grapple_ratio = Maths::Max(0.2, Maths::Min(demolitionist.grapple_ratio, b.getDistanceTo(this) / demolitionist_grapple_length));

				demolitionist.grapple_id = b.getNetworkID();
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

bool grappleHitMap(DemolitionistInfo@ demolitionist, CMap@ map, const f32 dist = 16.0f)
{
	return  map.isTileSolid(demolitionist.grapple_pos + Vec2f(0, -3)) ||			//fake quad
	        map.isTileSolid(demolitionist.grapple_pos + Vec2f(3, 0)) ||
	        map.isTileSolid(demolitionist.grapple_pos + Vec2f(-3, 0)) ||
	        map.isTileSolid(demolitionist.grapple_pos + Vec2f(0, 3)) ||
	        (dist > 10.0f && map.getSectorAtPosition(demolitionist.grapple_pos, "tree") !is null);   //tree stick
}

bool shouldReleaseGrapple(CBlob@ this, DemolitionistInfo@ demolitionist, CMap@ map)
{
	return !grappleHitMap(demolitionist, map) || this.isKeyPressed(key_use);
}

bool canSend(CBlob@ this)
{
	return (this.isMyPlayer() || this.getPlayer() is null || this.getPlayer().isBot());
}


void onAttach(CBlob@ this, CBlob@ attached, AttachmentPoint @attachedPoint)
{
	DemolitionistInfo@ demolitionist;
	if (!this.get("demolitionistInfo", @demolitionist))
	{
		return;
	}

	if (this.isAttached() && (canSend(this) || isServer()))
	{
		demolitionist.grappling = false;
		SyncGrapple(this);
	}
}

void onDetach(CBlob@ this, CBlob@ detached, AttachmentPoint@ attachedPoint)
{
	// ignore collision for built blob
	BuildBlock[][]@ blocks;
	if (!this.get("blocks", @blocks))
	{
		return;
	}

	const u8 PAGE = this.get_u8("build page");
	for (u8 i = 0; i < blocks[PAGE].length; i++)
	{
		BuildBlock@ block = blocks[PAGE][i];
		if (block !is null && block.name == detached.getName())
		{
			this.IgnoreCollisionWhileOverlapped(null);
			detached.IgnoreCollisionWhileOverlapped(null);
		}
	}

	// BUILD BLOB
	// take requirements from blob that is built and play sound
	// put out another one of the same
	if (detached.hasTag("temp blob"))
	{
		detached.Untag("temp blob");
		
		if (!detached.hasTag("temp blob placed"))
		{
			detached.server_Die();
			return;
		}
		else if (detached.getName() == "bombbox")//give tag for initial ignite
		{
			detached.Tag("placed");
		}

		uint i = this.get_u8("buildblob");
		if (i >= 0 && i < blocks[PAGE].length)
		{
			BuildBlock@ b = blocks[PAGE][i];
			if (b.name == detached.getName())
			{
				this.set_u8("buildblob", 255);
				this.set_TileType("buildtile", 0);

				CInventory@ inv = this.getInventory();

				CBitStream missing;
				if (hasRequirements(inv, b.reqs, missing, not b.buildOnGround))
				{
					server_TakeRequirements(inv, b.reqs);
				}
				// take out another one if in inventory
				server_BuildBlob(this, blocks[PAGE], i);
			}
		}
	}
	else if (detached.getName() == "seed")
	{
		if (not detached.hasTag('temp blob placed')) return;

		CBlob@ anotherBlob = this.getInventory().getItem(detached.getName());
		if (anotherBlob !is null)
		{
			this.server_Pickup(anotherBlob);
		}
	}
}

void onAddToInventory(CBlob@ this, CBlob@ blob)
{
	// destroy built blob if somehow they got into inventory
	if (blob.hasTag("temp blob"))
	{
		blob.server_Die();
		blob.Untag("temp blob");
	}
}
