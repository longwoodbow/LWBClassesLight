// Chopper logic

#include "Hitters.as";
#include "BuilderCommon.as";
#include "ChopperCommon.as";
#include "ActivationThrowCommon.as"
#include "RunnerCommon.as";
#include "Requirements.as"
#include "BuilderHittable.as";
#include "PlacementCommon.as";
#include "ParticleSparks.as";
#include "MaterialCommon.as";
#include "KnockedCommon.as"

const f32 hit_damage = 0.5f;

f32 pickaxe_distance = 10.0f;
u8 delay_between_hit = 12;
u8 delay_between_hit_structure = 10;

//attacks limited to the one time per-actor before reset.

void chopper_actorlimit_setup(CBlob@ this)
{
	u16[] networkIDs;
	this.set("LimitedActors", networkIDs);
}

bool chopper_has_hit_actor(CBlob@ this, CBlob@ actor)
{
	u16[]@ networkIDs;
	this.get("LimitedActors", @networkIDs);
	return networkIDs.find(actor.getNetworkID()) >= 0;
}

u32 chopper_hit_actor_count(CBlob@ this)
{
	u16[]@ networkIDs;
	this.get("LimitedActors", @networkIDs);
	return networkIDs.length;
}

void chopper_add_actor_limit(CBlob@ this, CBlob@ actor)
{
	this.push("LimitedActors", actor.getNetworkID());
}

void chopper_clear_actor_limits(CBlob@ this)
{
	this.clear("LimitedActors");
}

void onInit(CBlob@ this)
{
	ChopperInfo chopper;

	chopper.axeTimer = 0;
	chopper.tileDestructionLimiter = 0;
	if(!this.exists("tool_type")) this.set_u8("tool_type", ToolType::axe);
	chopper.state = ChopperStates::normal;

	this.set("chopperInfo", @chopper);

	ChopperState@[] states;
	states.push_back(NormalState());
	states.push_back(AxeDrawnState());
	states.push_back(SlashState(ChopperStates::chop));
	states.push_back(SlashState(ChopperStates::chop_power));
	states.push_back(ResheathState(ChopperStates::resheathing, ChopperVars::resheath_time));

	this.set("chopperStates", @states);
	this.set_s32("currentChopperState", 0);

	this.set_f32("gib health", -1.5f);
	chopper_actorlimit_setup(this);

	this.Tag("player");
	this.Tag("flesh");

	HitData hitdata;
	this.set("hitdata", hitdata);

	PickaxeInfo PI;
	this.set("pi", PI);

	PickaxeInfo SPI; // server
	this.set("spi", SPI);

	this.addCommandID("pickaxe");

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
		player.SetScoreboardVars("LWBScoreboardIcons.png", 6, Vec2f(16, 16));
	}
}

void RunStateMachine(CBlob@ this, ChopperInfo@ chopper, RunnerMoveVars@ moveVars)
{
	ChopperState@[]@ states;
	if (!this.get("chopperStates", @states))
	{
		return;
	}

	s32 currentStateIndex = this.get_s32("currentChopperState");

	if (getNet().isClient())
	{
		if (this.exists("serverChopperState"))
		{
			s32 serverStateIndex = this.get_s32("serverChopperState");
			this.set_s32("serverChopperState", -1);
			if (serverStateIndex != -1 && serverStateIndex != currentStateIndex)
			{
				ChopperState@ serverState = states[serverStateIndex];
				u8 net_state = states[serverStateIndex].getStateValue();
				if (this.isMyPlayer())
				{
					if (net_state >= ChopperStates::chop && net_state <= ChopperStates::chop_power)
					{
						if (chopper.state != ChopperStates::axe_drawn && chopper.state != ChopperStates::resheathing)
						{
							if ((getGameTime() - serverState.stateEnteredTime) > 20)
							{
								chopper.state = net_state;
								serverState.stateEnteredTime = getGameTime();
								serverState.StateEntered(this, chopper, serverState.getStateValue());
								this.set_s32("currentChopperState", serverStateIndex);
								currentStateIndex = serverStateIndex;
							}

						}

					}
				}
				else
				{
					chopper.state = net_state;
					serverState.stateEnteredTime = getGameTime();
					serverState.StateEntered(this, chopper, serverState.getStateValue());
					this.set_s32("currentChopperState", serverStateIndex);
					currentStateIndex = serverStateIndex;
				}

			}
		}
	}



	u8 state = chopper.state;
	ChopperState@ currentState = states[currentStateIndex];

	bool tickNext = false;
	tickNext = currentState.TickState(this, chopper, moveVars);

	if (state != chopper.state)
	{
		for (s32 i = 0; i < states.size(); i++)
		{
			if (states[i].getStateValue() == chopper.state)
			{
				s32 nextStateIndex = i;
				ChopperState@ nextState = states[nextStateIndex];
				currentState.StateExited(this, chopper, nextState.getStateValue());

				nextState.stateEnteredTime = getGameTime();
				nextState.StateEntered(this, chopper, currentState.getStateValue());
				this.set_s32("currentChopperState", nextStateIndex);
				if (getNet().isServer() && chopper.state >= ChopperStates::axe_drawn && chopper.state <= ChopperStates::chop_power)
				{
					this.set_s32("serverChopperState", nextStateIndex);
					this.Sync("serverChopperState", true);
				}

				if (tickNext)
				{
					RunStateMachine(this, chopper, moveVars);

				}
				break;
			}
		}
	}
}

bool getInAir(CBlob@ this)
{
	bool inair = (!this.isOnGround() && !this.isOnLadder());
	return inair;

}

class NormalState : ChopperState
{
	u8 getStateValue() { return ChopperStates::normal; }
	void StateEntered(CBlob@ this, ChopperInfo@ chopper, u8 previous_state)
	{
		chopper.axeTimer = 0;
		chopper.decreasing = false;
		this.set_u8("swordSheathPlayed", 0);
	}

	bool TickState(CBlob@ this, ChopperInfo@ chopper, RunnerMoveVars@ moveVars)
	{
		if (this.isKeyPressed(key_action2) && this.get_u8("tool_type") == ToolType::axe && !moveVars.wallsliding && !isStrikeAnim(this.getSprite()))
		{
			chopper.state = ChopperStates::axe_drawn;
			return true;
		}

		return false;
	}
}

s32 getAxeTimerDelta(ChopperInfo@ chopper)
{
	s32 delta = chopper.axeTimer;
	if (chopper.axeTimer > 0 && chopper.decreasing)
	{
		chopper.axeTimer--;
		if (chopper.axeTimer == 0) chopper.decreasing = false;
	}
	else if (chopper.axeTimer < 128)
	{
		chopper.axeTimer++;
	}
	return delta;
}

void AttackMovement(CBlob@ this, ChopperInfo@ chopper, RunnerMoveVars@ moveVars)
{
	Vec2f vel = this.getVelocity();

	moveVars.jumpFactor *= 0.6f;
	moveVars.walkFactor *= 0.8f;

	bool inair = getInAir(this);
	if (!inair)
	{
		this.AddForce(Vec2f(vel.x * -5.0, 0.0f));   //horizontal slowing force (prevents SANICS)
	}

	moveVars.canVault = false;
}

class AxeDrawnState : ChopperState
{
	u8 getStateValue() { return ChopperStates::axe_drawn; }
	void StateEntered(CBlob@ this, ChopperInfo@ chopper, u8 previous_state)
	{
		chopper.axeTimer = 0;
		chopper.decreasing = false;
		this.set_u8("swordSheathPlayed", 0);
	}

	bool TickState(CBlob@ this, ChopperInfo@ chopper, RunnerMoveVars@ moveVars)
	{
		if (moveVars.wallsliding || this.get_u8("tool_type") == ToolType::mattock)
		{
			chopper.state = ChopperStates::normal;
			return false;

		}

		Vec2f pos = this.getPosition();

		if (getNet().isClient())
		{
			const bool myplayer = this.isMyPlayer();
			if (chopper.axeTimer == ChopperVars::slash_charge && !chopper.decreasing)
			{
				Sound::Play("SwordSheath.ogg", pos, myplayer ? 1.3f : 0.7f);
				this.set_u8("swordSheathPlayed",  1);
			}
		}

		if (chopper.axeTimer >= ChopperVars::slash_charge_limit)
		{
			chopper.decreasing = true;
		}

		AttackMovement(this, chopper, moveVars);
		s32 delta = getAxeTimerDelta(chopper);

		if (!this.isKeyPressed(key_action2))
		{
			if (delta < ChopperVars::slash_charge)
			{
				chopper.state = ChopperStates::chop;
			}
			else// if(delta < ChopperVars::slash_charge_limit)
			{
				chopper.state = ChopperStates::chop_power;
			}
		}
		return false;
	}
}

Vec2f getSlashDirection(CBlob@ this)
{
	Vec2f vel = this.getVelocity();
	Vec2f aiming_direction = vel;
	aiming_direction.y *= 2;
	aiming_direction.Normalize();

	return aiming_direction;
}

class SlashState : ChopperState
{
	u8 state;
	SlashState(u8 s) { state = s; }
	u8 getStateValue() { return state; }
	void StateEntered(CBlob@ this, ChopperInfo@ chopper, u8 previous_state)
	{
		chopper_clear_actor_limits(this);
		chopper.axeTimer = 0;
		chopper.slash_direction = getSlashDirection(this);
		chopper.decreasing = false;
	}

	bool TickState(CBlob@ this, ChopperInfo@ chopper, RunnerMoveVars@ moveVars)
	{
		if (moveVars.wallsliding)
		{
			chopper.state = ChopperStates::normal;
			return false;

		}

		if (getNet().isClient())
		{
			const bool myplayer = this.isMyPlayer();
			Vec2f pos = this.getPosition();
			if (chopper.state == ChopperStates::chop_power && this.get_u8("swordSheathPlayed") == 0)
			{
				Sound::Play("SwordSheath.ogg", pos, myplayer ? 1.3f : 0.7f);
				this.set_u8("swordSheathPlayed",  1);
			}
		}

		this.Tag("prevent crouch");

		AttackMovement(this, chopper, moveVars);
		s32 delta = getAxeTimerDelta(chopper);

		if (delta == 2)
		{
			if (chopper.state == ChopperStates::chop_power) Sound::Play("/ArgLong", this.getPosition());
			Sound::Play("/SwordSlash", this.getPosition());
		}
		else if (delta > DELTA_BEGIN_ATTACK && delta < 10)
		{
			Vec2f vec;
			this.getAimDirection(vec);
			DoAttack(this, chopper.state == ChopperStates::chop_power ? 2.0f : 1.0f, -(vec.Angle()), 120.0f, Hitters::sword, delta, chopper);
		}
		else if (delta >= (chopper.state == ChopperStates::chop ? 9 : ChopperVars::slash_time))
		{
			chopper.state = ChopperStates::resheathing;
		}

		Vec2f vel = this.getVelocity();
		if (chopper.state == ChopperStates::chop_power &&
				delta < ChopperVars::slash_move_time)
		{

			if (Maths::Abs(vel.x) < ChopperVars::slash_move_max_speed &&
					vel.y > -ChopperVars::slash_move_max_speed)
			{
				Vec2f slash_vel =  chopper.slash_direction * this.getMass() * 0.5f;
				this.AddForce(slash_vel);
			}
		}

		return false;

	}
}

class ResheathState : ChopperState
{
	u8 state;
	s32 time;
	ResheathState(u8 s, s32 t) { state = s; time = t; }
	u8 getStateValue() { return state; }
	void StateEntered(CBlob@ this, ChopperInfo@ chopper, u8 previous_state)
	{
		chopper.axeTimer = 0;
		this.set_u8("swordSheathPlayed", 0);
	}

	bool TickState(CBlob@ this, ChopperInfo@ chopper, RunnerMoveVars@ moveVars)
	{
		if (moveVars.wallsliding || this.get_u8("tool_type") == ToolType::mattock)
		{
			chopper.state = ChopperStates::normal;
			return false;

		}
		else if (this.isKeyPressed(key_action2))
		{
			chopper.state = ChopperStates::axe_drawn;
			return true;
		}

		AttackMovement(this, chopper, moveVars);
		s32 delta = getAxeTimerDelta(chopper);

		if (delta > time)
		{
			chopper.state = ChopperStates::normal;
		}

		return false;
	}
}

void AxeCursorUpdate(CBlob@ this, ChopperInfo@ chopper)
{
		if (this.get_u8("tool_type") == ToolType::mattock)
		{
			getHUD().SetCursorFrame(0);
		}
		else if (chopper.axeTimer >= ChopperVars::slash_charge)
		{
			getHUD().SetCursorFrame(1);
		}
		else if (chopper.state == ChopperStates::normal || chopper.state == ChopperStates::resheathing) // disappear after slash is done
		// the yellow circle dissapears after mouse button release, more intuitive for improving slash timing
		// else if (chopper.axeTimer == 0) (disappear right after mouse release)
		{
			getHUD().SetCursorFrame(0);
		}
		else if (chopper.axeTimer < ChopperVars::slash_charge && chopper.state == ChopperStates::axe_drawn)
		{
			int frame = 2 + int((float(chopper.axeTimer) / ChopperVars::slash_charge) * 8) * 2;
			if (chopper.axeTimer <= ChopperVars::resheath_time) //prevent from appearing when jabbing/jab spamming
			{
				getHUD().SetCursorFrame(0);
			}
			else
			{
				getHUD().SetCursorFrame(frame);
			}
		}
}

void onTick(CBlob@ this)
{
	bool knocked = isKnocked(this);
	CHUD@ hud = getHUD();

	//chopper logic stuff
	//get the vars to turn various other scripts on/off
	RunnerMoveVars@ moveVars;
	if (!this.get("moveVars", @moveVars))
	{
		return;
	}

	ChopperInfo@ chopper;
	if (!this.get("chopperInfo", @chopper))
	{
		return;
	}

	if (this.isInInventory())
	{
		//prevent players from insta-slashing when exiting crates
		chopper.state = 0;
		chopper.axeTimer = 0;
		hud.SetCursorFrame(0);
		this.set_s32("currentChopperState", 0);
		return;
	}

	Vec2f pos = this.getPosition();
	Vec2f vel = this.getVelocity();
	Vec2f aimpos = this.getAimPos();
	const bool inair = (!this.isOnGround() && !this.isOnLadder());

	Vec2f vec;

	const int direction = this.getAimDirection(vec);
	const f32 side = (this.isFacingLeft() ? 1.0f : -1.0f);
	bool pressed_a1 = this.isKeyPressed(key_action1);
	bool pressed_a2 = this.isKeyPressed(key_action2);

	const bool ismyplayer = this.isMyPlayer();

	if (getNet().isClient() && !this.isInInventory() && ismyplayer)  //Chopper charge cursor
	{
		AxeCursorUpdate(this, chopper);
	}

	if (knocked)
	{
		chopper.state = ChopperStates::normal; //cancel any attacks or shielding
		chopper.axeTimer = 0;
		this.set_s32("currentChopperState", 0);

		pressed_a1 = false;
		pressed_a2 = false;
	}
	else
	{
		RunStateMachine(this, chopper, moveVars);

	}

	//from builder logic
	if (ismyplayer && hud.hasMenus())
	{
		return;
	}

	// activate/throw
	if (ismyplayer)
	{
		Pickaxe(this);
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
	if (pressed_a2 && chopper.state == ChopperStates::normal && this.get_u8("tool_type") == ToolType::mattock)
	{
		moveVars.walkFactor = 0.5f;
		moveVars.jumpFactor = 0.5f;
		this.Tag("prevent crouch");
	}

	if (ismyplayer && pressed_a1 && !this.isKeyPressed(key_inventory)) //Don't let the builder place blocks if he/she is selecting which one to place
	{
		BlockCursor @bc;
		this.get("blockCursor", @bc);

		HitData@ hitdata;
		this.get("hitdata", @hitdata);
		hitdata.blobID = 0;
		hitdata.tilepos = bc.buildable ? bc.tileAimPos : Vec2f(-8, -8);
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

	if (chopper.state == ChopperStates::normal)
	{
		chopper_clear_actor_limits(this);
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

void Pickaxe(CBlob@ this)
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
	if (this.isKeyPressed(key_action2) && PI.pickaxe_timer == 0 && this.get_u8("tool_type") == ToolType::mattock)
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

bool isJab(f32 damage)
{
	return damage < 1.5f;
}

void DoAttack(CBlob@ this, f32 damage, f32 aimangle, f32 arcdegrees, u8 type, int deltaInt, ChopperInfo@ info)
{
	if (!getNet().isServer())
	{
		return;
	}

	if (aimangle < 0.0f)
	{
		aimangle += 360.0f;
	}

	Vec2f blobPos = this.getPosition();
	Vec2f vel = this.getVelocity();
	Vec2f thinghy(1, 0);
	thinghy.RotateBy(aimangle);
	Vec2f pos = blobPos - thinghy * 6.0f + vel + Vec2f(0, -2);
	vel.Normalize();

	f32 attack_distance = Maths::Min(DEFAULT_ATTACK_DISTANCE + Maths::Max(0.0f, 1.75f * this.getShape().vellen * (vel * thinghy)), MAX_ATTACK_DISTANCE);

	f32 radius = this.getRadius();
	CMap@ map = this.getMap();
	bool dontHitMore = false;
	bool dontHitMoreMap = false;
	const bool jab = isJab(damage);
	bool dontHitMoreLogs = false;

	//get the actual aim angle
	f32 exact_aimangle = (this.getAimPos() - blobPos).Angle();

	// this gathers HitInfo objects which contain blob or tile hit information
	HitInfo@[] hitInfos;
	if (map.getHitInfosFromArc(pos, aimangle, arcdegrees, radius + attack_distance, this, @hitInfos))
	{
		// HitInfo objects are sorted, first come closest hits
		// start from furthest ones to avoid doing too many redundant raycasts
		for (int i = hitInfos.size() - 1; i >= 0; i--)
		{
			HitInfo@ hi = hitInfos[i];
			CBlob@ b = hi.blob;

			if (b !is null)
			{
				if (b.hasTag("ignore sword") 
				    || !axe_canHit(this, b)
				    || chopper_has_hit_actor(this, b)) 
				{
					continue;
				}

				Vec2f hitvec = hi.hitpos - pos;

				// we do a raycast to given blob and hit everything hittable between chopper and that blob
				// raycast is stopped if it runs into a "large" blob (typically a door)
				// raycast length is slightly higher than hitvec to make sure it reaches the blob it's directed at
				HitInfo@[] rayInfos;
				map.getHitInfosFromRay(pos, -(hitvec).getAngleDegrees(), hitvec.Length() + 2.0f, this, rayInfos);

				for (int j = 0; j < rayInfos.size(); j++)
				{
					CBlob@ rayb = rayInfos[j].blob;
					
					if (rayb is null) break; // means we ran into a tile, don't need blobs after it if there are any
					if (rayb.hasTag("ignore sword") || !axe_canHit(this, rayb)) continue;

					bool large = (rayb.hasTag("blocks sword") || (rayb.hasTag("barricade") && rayb.getTeamNum() != this.getTeamNum())// added here
								 && !rayb.isAttached() && rayb.isCollidable()); // usually doors, but can also be boats/some mechanisms
								 
					if (chopper_has_hit_actor(this, rayb)) 
					{
						// check if we hit any of these on previous ticks of slash
						if (large) break;
						if (rayb.getName() == "log")
						{
							dontHitMoreLogs = true;
						}
						continue;
					}

					f32 temp_damage = damage;
					
					if (rayb.getName() == "log")
					{
						if (!dontHitMoreLogs)
						{
							temp_damage /= 2;
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
					
					chopper_add_actor_limit(this, rayb);

					
					Vec2f velocity = rayb.getPosition() - pos;
					velocity.Normalize();
					velocity *= 12; // knockback force is same regardless of distance

					if (rayb.getTeamNum() != this.getTeamNum() || rayb.hasTag("dead player"))
					{
						this.server_Hit(rayb, rayInfos[j].hitpos, velocity, temp_damage, type, true);
					}
					
					if (large)
					{
						break; // don't raycast past the door after we do damage to it
					}
				}
			}
			else  // hitmap
				if (!dontHitMoreMap && (deltaInt == DELTA_BEGIN_ATTACK + 1))
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
							if (jab && !wood) //fake damage, one hit for wood
							{
								info.tileDestructionLimiter++;
								canhit = ((info.tileDestructionLimiter % (dirt_stone ? 3 : 2)) == 0);
							}
							else //reset fake dmg for next time
							{
								info.tileDestructionLimiter = 0;
							}

							//dont dig through no build zones
							canhit = canhit && map.getSectorAtPosition(tpos, "no build") is null;

							dontHitMoreMap = true;
							if (canhit)
							{
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
								else if (!jab && wood)
								{
									map.server_DestroyTile(hi.hitpos, 0.1f, this);
								}
							}
						}
					}
				}
		}
	}

	// destroy grass

	if (((aimangle >= 0.0f && aimangle <= 180.0f) || damage > 1.0f) &&    // aiming down or slash
	        (deltaInt == DELTA_BEGIN_ATTACK + 1)) // hit only once
	{
		f32 tilesize = map.tilesize;
		int steps = Maths::Ceil(2 * radius / tilesize);
		int sign = this.isFacingLeft() ? -1 : 1;

		for (int y = 0; y < steps; y++)
			for (int x = 0; x < steps; x++)
			{
				Vec2f tilepos = blobPos + Vec2f(x * tilesize * sign, y * tilesize);
				TileType tile = map.getTile(tilepos).type;

				if (map.isTileGrass(tile))
				{
					map.server_DestroyTile(tilepos, damage, this);

					if (damage <= 1.0f)
					{
						return;
					}
				}
			}
	}
}

// Blame Fuzzle.
bool axe_canHit(CBlob@ this, CBlob@ b)
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