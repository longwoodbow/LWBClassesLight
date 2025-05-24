
#include "Hitters.as";
#include "ShieldCommon.as";
#include "KnockedCommon.as";
#include "DoorCommon.as";

const f32 chakramMediumSpeed = 6.5f;
const f32 chakramFastSpeed = 10.0f;

const f32 CHAKRAM_PUSH_FORCE = 6.0f;
//arrow is 6.0f
const f32 SPECIAL_HIT_SCALE = 1.0f; //special hit on food items to shoot to team-mates

const u32 STUCK_CHAKRAM_DECAY_SECS = 30;

//Chakram logic

//blob functions
void onInit(CBlob@ this)
{
	CShape@ shape = this.getShape();
	shape.SetRotationsAllowed(false);
	ShapeConsts@ consts = shape.getConsts();
	consts.mapCollisions = false;	 // we have our own map collision
	consts.bullet = false;
	consts.net_threshold_multiplier = 4.0f;
	this.Tag("projectile");

	//dont collide with top of the map
	this.SetMapEdgeFlags(CBlob::map_collide_left | CBlob::map_collide_right);

	// 20 seconds of floating around
	this.server_SetTimeToDie(20);
}

void onTick(CBlob@ this)
{
	CShape@ shape = this.getShape();

	bool processSticking = true;
	if (!this.hasTag("collided")) //we haven't hit anything yet!
	{
		// if (this.hasTag("shotgunned"))
		//{
			//if (this.getTickSinceCreated() > 20)
			//{
				//this.server_Hit(this, this.getPosition(), Vec2f(), 1.0f, Hitters::crush);
			//}
		//}
		//prevent leaving the map
		{
			Vec2f pos = this.getPosition();
			if (
				pos.x < 0.1f ||
				pos.x > (getMap().tilemapwidth * getMap().tilesize) - 0.1f
			) {
				this.server_Die();
				return;
			}
		}

		Pierce(this);

		if (shape.vellen > 0.0001f)
		{
			if (shape.vellen > 13.5f)
			{
				shape.SetGravityScale(0.1f);
			}
			else
			{
				shape.SetGravityScale(Maths::Min(1.0f, 1.0f / (shape.vellen * 0.1f)));
			}

			processSticking = false;
		}
	}

	// sticking
	if (processSticking)
	{
		if (isServer())
		{
			if (this.exists("hitBlob")) 
			{
				// structure blob: door, platform, team bridge, trap block etc.

				CBlob@ gottenBlob = getBlobByNetworkID(this.get_u32("hitBlob"));

				if (gottenBlob is null) // structure blob is gone
				{
					this.server_Die();
				}
				else 
				{
					string n = gottenBlob.getName();
					bool isOpened = (isOpen(gottenBlob) && (n.find("door") != -1 || n == "bridge" || n == "trap_block"));
				
					if (gottenBlob.hasTag("fallen") || isOpened) // structure blob is collapsing or is an opening door/bridge/trap
					{
						this.server_Die();
					}
				}
			}
			else if (this.exists("hitWorldPoint"))
			{
				// maptile: stone, wood, dirt, obstructor etc.
				
				CMap@ map = getMap();
				
				Vec2f hitpos = this.get_Vec2f("hitWorldPoint");
				Tile hitTile = map.getTile(hitpos);
				
				if (!map.isTileSolid(hitTile))
					this.server_Die();	
			}
		}
		
		shape.getConsts().collidable = false;	//no collision
		
		this.getSprite().animation.time = 0;
		this.setVelocity(Vec2f(0, 0));
		this.setPosition(this.get_Vec2f("lock"));
		shape.SetStatic(true);
		shape.getVars().isladder = true;
	}

}

void onCollision(CBlob@ this, CBlob@ blob, bool solid, Vec2f normal, Vec2f point1)
{
	if (blob !is null && doesCollideWithBlob(this, blob) && !this.hasTag("collided"))
	{
		if (
			!solid && !blob.hasTag("flesh") &&
			!specialChakramHit(blob) &&
			(blob.getName() != "mounted_bow" || this.getTeamNum() != blob.getTeamNum())
		) {
			return;
		}

		Vec2f initVelocity = this.getOldVelocity();
		f32 vellen = initVelocity.Length();
		if (vellen < 0.1f)
		{
			return;
		}

		f32 dmg = 0.0f;
		if (blob.getTeamNum() != this.getTeamNum() || blob.getName() == "bridge")
		{
			dmg = getChakramDamage(this, vellen);
		}

		// this isnt synced cause we want instant collision for arrow even if it was wrong
		dmg = ChakramHitBlob(this, point1, initVelocity, dmg, blob, Hitters::arrow);

		if (dmg > 0.0f)
		{
			//perform the hit and tag so that another doesn't happen
			this.server_Hit(blob, point1, initVelocity, dmg, Hitters::arrow);
			this.Tag("collided");
		}
	}
}

bool doesCollideWithBlob(CBlob@ this, CBlob@ blob)
{
	//don't collide with other projectiles
	if (blob.hasTag("projectile"))
	{
		return false;
	}

	//anything to always hit
	if (specialChakramHit(blob))
	{
		return true;
	}

	//definitely collide with non-team blobs
	bool check = this.getTeamNum() != blob.getTeamNum() || blob.getName() == "bridge";
	//maybe collide with team structures
	if (!check)
	{
		CShape@ shape = blob.getShape();
		check = (shape.isStatic() && !shape.getConsts().platform);
	}

	if (check)
	{
		if (
			//we've collided
			this.getShape().isStatic() ||
			this.hasTag("collided") ||
			//or they're dead
			blob.hasTag("dead") ||
			//or they ignore us
			blob.hasTag("ignore_arrow")
		) {
			return false;
		}
		else
		{
			return true;
		}
	}

	return false;
}

bool specialChakramHit(CBlob@ blob)
{
	string bname = blob.getName();
	return (bname == "fishy" && blob.hasTag("dead") || bname == "food"
		|| bname == "steak" || bname == "grain"/* || bname == "heart"*/); //no egg because logic
}

void Pierce(CBlob @this, CBlob@ blob = null)
{
	Vec2f end;
	CMap@ map = getMap();
	Vec2f position = blob is null ? this.getPosition() : blob.getPosition();

	if (map.rayCastSolidNoBlobs(this.getShape().getVars().oldpos, position, end))
	{
		ChakramHitMap(this, end, this.getOldVelocity(), 0.5f, Hitters::arrow, blob);
	}
}

void AddChakramLayer(CBlob@ this, CBlob@ hitBlob, CSprite@ sprite, Vec2f worldPoint, Vec2f velocity)
{
	uint index = hitBlob.get_u32("stuck_chakram_index");
	CSpriteLayer@ chakram = sprite.addSpriteLayer("chakram" + index, "Entities/Items/Projectiles/Chakram.png", 16, 8, this.getTeamNum(), this.getSkinNum());

	if (chakram !is null)
	{
		Animation@ anim = chakram.addAnimation("default", 13, true);

		if (this.getSprite().animation !is null)
		{
			anim.AddFrame(XORRandom(4));  //always use broken frame... make it?
		}
		else
		{
			warn("exception: chakram has no anim");
			anim.AddFrame(0);
		}

		chakram.SetAnimation(anim);
		Vec2f normal = worldPoint - hitBlob.getPosition();
		f32 len = normal.Length();
		if (len > 0.0f)
			normal /= len;
		Vec2f soffset = normal * (len + 0);

		// wow, this is shit
		// movement existing makes setfacing matter?
		if (hitBlob.getMovement() is null)
		{
			// soffset.x *= -1;
			chakram.RotateBy(180.0f, Vec2f(0, 0));
			chakram.SetFacingLeft(true);
		}
		else
		{
			soffset.x *= -1;
			chakram.SetFacingLeft(false);
		}

		chakram.SetIgnoreParentFacing(true); //dont flip when parent flips


		chakram.SetOffset(soffset);
		chakram.SetRelativeZ(-0.01f);

		f32 angle = velocity.Angle();
		chakram.RotateBy(-angle - hitBlob.getAngleDegrees(), Vec2f(0, 0));

		//track time until chakram is destroyed

		//initialize arrays
		if (!hitBlob.exists("stuck_chakram_names"))
		{
			string[] names;
			hitBlob.set("stuck_chakram_names", names);

			uint[] times;
			hitBlob.set("stuck_chakram_times", times);
		}

		//save details of chakram so it can decay
		hitBlob.push("stuck_chakram_names", chakram.name);
		hitBlob.push("stuck_chakram_times", getGameTime() + getTicksASecond() * STUCK_CHAKRAM_DECAY_SECS);

		//attach decay script
		if (!hitBlob.hasScript("DecayStuckChakrams.as"))
		{
			hitBlob.AddScript("DecayStuckChakrams.as");
		}

		//increment chakram index
		hitBlob.add_u32("stuck_chakram_index", 1);
	}
}

f32 ChakramHitBlob(CBlob@ this, Vec2f worldPoint, Vec2f velocity, f32 damage, CBlob@ hitBlob, u8 customData)
{
	if (hitBlob !is null)
	{
		Pierce(this, hitBlob);
		if (this.hasTag("collided")) return 0.0f;

		// check if invincible + special -> add force here
		if (specialChakramHit(hitBlob))
		{
			const f32 scale = SPECIAL_HIT_SCALE;
			f32 force = (CHAKRAM_PUSH_FORCE * 0.125f) * Maths::Sqrt(hitBlob.getMass() + 1) * scale;
			//if (this.hasTag("bow arrow"))
			//{
				force *= 1.3f;
			//}

			hitBlob.AddForce(velocity * force);

			//die
			this.server_Hit(this, this.getPosition(), Vec2f(), 1.0f, Hitters::crush);
		}

		// check if shielded
		const bool hitShield = (hitBlob.hasTag("shielded") && blockAttack(hitBlob, velocity, 0.0f));

		// play sound
		if (!hitShield)
		{
			if (hitBlob.hasTag("flesh"))
			{
				if (velocity.Length() > chakramFastSpeed)
				{
					this.getSprite().PlaySound("ArrowHitFleshFast.ogg");
				}
				else
				{
					this.getSprite().PlaySound("ArrowHitFlesh.ogg");
				}
			}
			else
			{
				if (velocity.Length() > chakramFastSpeed)
				{
					this.getSprite().PlaySound("ArrowHitGroundFast.ogg");
				}
				else
				{
					this.getSprite().PlaySound("ArrowHitGround.ogg");
				}
			}
		}

		//stick into "map" blobs
		if (hitBlob.getShape().isStatic())
		{
			ChakramHitMap(this, worldPoint, velocity, damage, Hitters::arrow, hitBlob);
		}
		//die otherwise
		else
		{
			//add chakram layer
			CSprite@ sprite = hitBlob.getSprite();
			if (sprite !is null && !hitShield && !v_fastrender)
			{
				AddChakramLayer(this, hitBlob, sprite, worldPoint, velocity);
			}
			this.server_Die();
		}
	}

	return damage;
}

void ChakramHitMap(CBlob@ this, Vec2f worldPoint, Vec2f velocity, f32 damage, u8 customData, CBlob@ hitBlob = null)
{
	if (velocity.Length() > chakramFastSpeed)
	{
		this.getSprite().PlaySound("ArrowHitGroundFast.ogg");
	}
	else
	{
		this.getSprite().PlaySound("ArrowHitGround.ogg");
	}

	CMap@ map = getMap();
	if(map.isTileWood(map.getTile(worldPoint).type) && getChakramDamage(this) >= 1.0f)
	{
		map.server_DestroyTile(worldPoint, 0.1f, this);
	}
	if(map.isTileCastle(map.getTile(worldPoint).type) && getChakramDamage(this) >= 1.5f)
	{
		map.server_DestroyTile(worldPoint, 0.1f, this);
	}

	f32 radius = this.getRadius();

	Vec2f norm = velocity;
	norm.Normalize();
	norm *= (1.5f * radius);
	Vec2f lock = worldPoint - norm;
	this.set_Vec2f("lock", lock);

	// saving information on what was hit to determine when the arrow should collapse
	if (isServer())
	{
		if (hitBlob is null) // map (stone, wood, dirt)
		{
			this.set_Vec2f("hitWorldPoint", worldPoint);
		}
		else // hitBlob (door, platform, etc.)
		{
			this.set_u32("hitBlob", hitBlob.getNetworkID());
		}
	}

	this.Sync("lock", true);

	this.setVelocity(Vec2f(0, 0));
	this.setPosition(lock);
	//this.getShape().server_SetActive( false );

	this.Tag("collided");

	//kill any grain plants we shot the base of
	CBlob@[] blobsInRadius;
	if (map.getBlobsInRadius(worldPoint, this.getRadius() * 1.3f, @blobsInRadius))
	{
		for (uint i = 0; i < blobsInRadius.length; i++)
		{
			CBlob @b = blobsInRadius[i];
			if (b.getName() == "grain_plant")
			{
				this.server_Hit(b, worldPoint, Vec2f(0, 0), velocity.Length() / 7.0f, Hitters::arrow);
				break;
			}
		}
	}
}

//random object used for gib spawning
Random _gib_r(0xa7c3a);
void onDie(CBlob@ this)
{
	if (getNet().isClient())
	{
		Vec2f pos = this.getPosition();
		if (pos.x >= 1 && pos.y >= 1)
		{
			Vec2f vel = this.getVelocity();
			makeGibParticle(
				"GenericGibs.png", pos, vel,
				2, _gib_r.NextRanged(4) + 4,
				Vec2f(8, 8), 2.0f, 20, "/thud",
				this.getTeamNum()
			);
		}
	}
}

void onThisAddToInventory(CBlob@ this, CBlob@ inventoryBlob)
{
	if (!getNet().isServer())
	{
		return;
	}

	// merge arrow into mat_arrows

	for (int i = 0; i < inventoryBlob.getInventory().getItemsCount(); i++)
	{
		CBlob @blob = inventoryBlob.getInventory().getItem(i);

		if (blob !is this && blob.getName() == "mat_chakrams")
		{
			blob.server_SetQuantity(blob.getQuantity() + 1);
			this.server_Die();
			return;
		}
	}

	// mat_arrows not found
	// make arrow into mat_arrows
	CBlob @mat = server_CreateBlob("mat_chakrams");

	if (mat !is null)
	{
		inventoryBlob.server_PutInInventory(mat);
		mat.server_SetQuantity(1);
		this.server_Die();
	}
}

f32 onHit(CBlob@ this, Vec2f worldPoint, Vec2f velocity, f32 damage, CBlob@ hitterBlob, u8 customData)
{
	if (customData == Hitters::sword)
	{
		return 0.0f; //no cut arrows
	}

	return damage;
}

void onHitBlob(CBlob@ this, Vec2f worldPoint, Vec2f velocity, f32 damage, CBlob@ hitBlob, u8 customData)
{
	// unbomb, stick to blob
	if (this !is hitBlob && customData == Hitters::arrow)
	{
		// affect players velocity
		const f32 scale = specialChakramHit(hitBlob) ? SPECIAL_HIT_SCALE : 1.0f;

		Vec2f vel = velocity;
		const f32 speed = vel.Normalize();
		if (speed > 6.0f)//12.0f, shoot vel / 0.5f
		{
			f32 force = (CHAKRAM_PUSH_FORCE * 0.125f) * Maths::Sqrt(hitBlob.getMass() + 1) * scale * 1.3f;// like bow arrow

			hitBlob.AddForce(velocity * force);

			// stun if shot real close
			if (
				this.getTickSinceCreated() <= 4 &&
				speed > 12.0f * 0.845f &&
				hitBlob.hasTag("player")
			) {
				setKnocked(hitBlob, 20, true);
				Sound::Play("/Stun", hitBlob.getPosition(), 1.0f, this.getSexNum() == 0 ? 1.0f : 1.5f);
			}
		}
	}
}

f32 getChakramDamage(CBlob@ this, f32 vellen = -1.0f)
{
	if (vellen < 0) //grab it - otherwise use cached
	{
		CShape@ shape = this.getShape();
		if (shape is null)
			vellen = this.getOldVelocity().Length();
		else
			vellen = this.getShape().getVars().oldvel.Length();
	}

	if (vellen >= chakramFastSpeed)
	{
		return 1.5f;
	}
	else if (vellen >= chakramMediumSpeed)
	{
		return 1.0f;
	}

	return 0.5f;
}