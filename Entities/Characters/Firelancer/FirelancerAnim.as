// Firelancer animations

#include "FirelancerCommon.as"
#include "FireParticle.as"
#include "RunnerAnimCommon.as";
#include "RunnerCommon.as";
#include "KnockedCommon.as";
#include "PixelOffsets.as"
#include "RunnerTextures.as"
#include "Accolades.as"


const f32 config_offset = -6.0f;

void onInit(CSprite@ this)
{
	LoadSprites(this);
}

void onPlayerInfoChanged(CSprite@ this)
{
	LoadSprites(this);
}

void LoadSprites(CSprite@ this)
{
	ensureCorrectRunnerTexture(this, "firelancer", "Firelancer");

	string texname = getRunnerTextureName(this);

	this.RemoveSpriteLayer("frontarm");
	CSpriteLayer@ frontarm = this.addTexturedSpriteLayer("frontarm", texname , 32, 16);

	if (frontarm !is null)
	{
		Animation@ firelance = frontarm.addAnimation("firelance", 0, false);
		firelance.AddFrame(24);
		firelance.AddFrame(25);
		Animation@ flamethrower = frontarm.addAnimation("flamethrower", 0, false);
		flamethrower.AddFrame(32);
		flamethrower.AddFrame(33);
		frontarm.SetOffset(Vec2f(-1.0f, 5.0f + config_offset));
		frontarm.SetAnimation("firelance");
		frontarm.SetVisible(false);
	}

	this.RemoveSpriteLayer("backarm");
	CSpriteLayer@ backarm = this.addTexturedSpriteLayer("backarm", texname , 32, 16);

	if (backarm !is null)
	{
		Animation@ anim = backarm.addAnimation("default", 0, false);
		anim.AddFrame(17);
		backarm.SetOffset(Vec2f(-1.0f, 5.0f + config_offset));
		backarm.SetAnimation("default");
		backarm.SetVisible(false);
	}

	//quiver
	this.RemoveSpriteLayer("quiver");
	CSpriteLayer@ quiver = this.addTexturedSpriteLayer("quiver", texname , 32, 8);

	if (quiver !is null)
	{
		Animation@ anim = quiver.addAnimation("default", 0, false);
		anim.AddFrame(32);
		quiver.SetOffset(Vec2f(-10.0f, 2.0f + config_offset));
		quiver.SetRelativeZ(-0.1f);
	}
}

void setArmValues(CSpriteLayer@ arm, bool visible, f32 angle, f32 relativeZ, string anim, Vec2f around, Vec2f offset)
{
	if (arm !is null)
	{
		arm.SetVisible(visible);

		if (visible)
		{
			if (!arm.isAnimation(anim))
			{
				arm.SetAnimation(anim);
			}

			arm.SetOffset(offset);
			arm.ResetTransform();
			arm.SetRelativeZ(relativeZ);
			arm.RotateBy(angle, around);
		}
	}
}

// stuff for shiny - global cause is used by a couple functions in a tick

void onTick(CSprite@ this)
{
	// store some vars for ease and speed
	CBlob@ blob = this.getBlob();

	if (blob.hasTag("dead"))
	{
		if (this.animation.name != "dead")
		{
			this.SetAnimation("dead");
			this.RemoveSpriteLayer("frontarm");
			this.RemoveSpriteLayer("backarm");
		}

		doQuiverUpdate(this, false);

		Vec2f vel = blob.getVelocity();

		if (vel.y < -1.0f)
		{
			this.SetFrameIndex(0);
		}
		else if (vel.y > 1.0f)
		{
			this.SetFrameIndex(1);
		}
		else
		{
			this.SetFrameIndex(2);
		}

		return;
	}

	FirelancerInfo@ firelancer;
	if (!blob.get("firelancerInfo", @firelancer))
	{
		return;
	}


	// animations
	const bool firing = IsFiring(blob) && firelancer.charge_state != FirelancerParams::stick;
	const bool left = blob.isKeyPressed(key_left);
	const bool right = blob.isKeyPressed(key_right);
	const bool up = blob.isKeyPressed(key_up);
	const bool down = blob.isKeyPressed(key_down);
	const bool inair = (!blob.isOnGround() && !blob.isOnLadder());
	bool crouch = false;

	bool knocked = isKnocked(blob);
	bool ignited = (firelancer.charge_state == FirelancerParams::ignited || firelancer.charge_state == FirelancerParams::firing) && !blob.isAttached() && !knocked;
	Vec2f pos = blob.getPosition() + Vec2f(0, -2);
	Vec2f aimpos = blob.getAimPos();
	pos.x += this.isFacingLeft() ? 2 : -2;

	// get the angle of aiming with mouse
	Vec2f vec = aimpos - pos;
	f32 angle = vec.Angle();

	if (knocked)
	{
		if (inair)
		{
			this.SetAnimation("knocked_air");
		}
		else
		{
			this.SetAnimation("knocked");
		}
	}
	else if (blob.hasTag("seated"))
	{
		this.SetAnimation("default");
	}
	else if(firelancer.charge_state == FirelancerParams::stick)
	{
		string animName = this.animation.name;
		if((animName == "stick_mid" || animName == "stick_up" || animName == "stick_down") && !this.isAnimationEnded())
			this.SetAnimation(animName);
		else
		{
			const int direction = this.getBlob().getAimDirection(vec);
			if (direction == -1)
			{
				this.SetAnimation("stick_up");
			}
			else if (direction == 0)
			{
				this.SetAnimation("stick_mid");
			}
			else
			{
				this.SetAnimation("stick_down");
			}
		}
	}
	else if (firing || ignited)
	{
		if (inair)
		{
			this.SetAnimation("shoot_jump");
		}
		else if ((left || right) ||
		         (blob.isOnLadder() && (up || down)))
		{
			this.SetAnimation("shoot_run");
		}
		else
		{
			this.SetAnimation("shoot");
		}
	}
	else if (inair)
	{
		RunnerMoveVars@ moveVars;
		if (!blob.get("moveVars", @moveVars))
		{
			return;
		}
		Vec2f vel = blob.getVelocity();
		f32 vy = vel.y;
		if (vy < -0.0f && moveVars.walljumped)
		{
			this.SetAnimation("run");
		}
		else
		{
			this.SetAnimation("fall");
			this.animation.timer = 0;
			bool inwater = blob.isInWater();

			if (vy < -1.5 * (inwater ? 0.7 : 1))
			{
				this.animation.frame = 0;
			}
			else if (vy > 1.5 * (inwater ? 0.7 : 1))
			{
				this.animation.frame = 2;
			}
			else
			{
				this.animation.frame = 1;
			}
		}
	}
	else if ((left || right) ||
	         (blob.isOnLadder() && (up || down)))
	{
		this.SetAnimation("run");
	}
	else
	{
		if (down && this.isAnimationEnded())
			crouch = true;

		int direction;

		if ((angle > 330 && angle < 361) || (angle > -1 && angle < 30) ||
		        (angle > 150 && angle < 210))
		{
			direction = 0;
		}
		else if (aimpos.y < pos.y)
		{
			direction = -1;
		}
		else
		{
			direction = 1;
		}

		defaultIdleAnim(this, blob, direction);
	}

	SColor lightColor = SColor(255, 255, Maths::Min(255, Maths::Max(8 * firelancer.charge_time - FirelancerParams::ignite_period, 0)), 0);
	blob.SetLightColor(lightColor);

	//arm anims
	Vec2f armOffset = Vec2f(-1.0f, 4.0f + config_offset);
	const u8 lanceType = getLanceType(blob);
	f32 armangle = -angle;

	if (firing || ignited)
	{

		if (this.isFacingLeft())
		{
			armangle = 180.0f - angle;
		}

		while (armangle > 180.0f)
		{
			armangle -= 360.0f;
		}

		while (armangle < -180.0f)
		{
			armangle += 360.0f;
		}

		DrawLance(this, blob, firelancer, armangle, lanceType, armOffset, lightColor);
	}
	else
	{
		setArmValues(this.getSpriteLayer("frontarm"), false, 0.0f, 0.1f, "fired", Vec2f(0, 0), armOffset);
		setArmValues(this.getSpriteLayer("backarm"), false, 0.0f, -0.1f, "default", Vec2f(0, 0), armOffset);
		setArmValues(this.getSpriteLayer("held lance"), false, 0.0f, 0.5f, "default", Vec2f(0, 0), armOffset);
	}

	DrawLanceEffects(this, blob, firelancer, ignited);

	//set the head anim
	if (knocked || crouch)
	{
		blob.Tag("dead head");
	}
	else if (blob.isKeyPressed(key_action1))
	{
		blob.Tag("attack head");
		blob.Untag("dead head");
	}
	else
	{
		blob.Untag("attack head");
		blob.Untag("dead head");
	}


}

void sparks(Vec2f at, f32 angle, f32 speed, SColor color)
{
	Vec2f vel = getRandomVelocity(angle + 90.0f, speed, 25.0f);
	at.y -= 2.5f;
	ParticlePixel(at, vel, color, true, 119);
}


void DrawLance(CSprite@ this, CBlob@ blob, FirelancerInfo@ firelancer, f32 armangle, const u8 lanceType, Vec2f armOffset, SColor lightColor)
{
	f32 sign = (this.isFacingLeft() ? 1.0f : -1.0f);
	CSpriteLayer@ frontarm = this.getSpriteLayer("frontarm");

	string animname = lanceType == LanceType::fire ? "flamethrower" : "firelance";

	f32 temp = Maths::Min(firelancer.charge_time, FirelancerParams::ready_time);
	f32 ready_tween = temp / FirelancerParams::ready_time;
	armangle = armangle * ready_tween;
	armOffset = Vec2f(-1.0f, 4.0f + config_offset + 2.0f * (1.0f - ready_tween));
	setArmValues(frontarm, true, armangle, 0.1f, animname, Vec2f(-4.0f * sign, 0.0f), armOffset);
	frontarm.animation.frame = (firelancer.charge_state == FirelancerParams::ignited || firelancer.charge_state == FirelancerParams::firing) ? 1 : 0;

	frontarm.SetRelativeZ(1.5f);
	setArmValues(this.getSpriteLayer("backarm"), true, armangle, -0.1f, "default", Vec2f(-4.0f * sign, 0.0f), armOffset);

	// fire lance particles
	
	if (firelancer.charge_state == FirelancerParams::firing)
	{
		if (XORRandom(2) == 0)
			{
			Vec2f offset = Vec2f(10.0f, 0.0f);

			if (this.isFacingLeft())
			{
				offset.x = -offset.x;
			}

			offset.RotateBy(armangle);

			sparks(frontarm.getWorldTranslation() + offset, armangle, 3.5f + (XORRandom(10) / 5.0f), lightColor);
		}
	}
}

void DrawLanceEffects(CSprite@ this, CBlob@ blob, FirelancerInfo@ firelancer, bool ignited)
{
	// set fire light

	if (!blob.isAttached() && ignited && hasLances(blob))
	{
		blob.SetLight(true);
		blob.SetLightRadius(blob.getRadius() * 2.0f);
	}
	else
	{
		blob.SetLight(false);
	}

	//quiver
	bool has_lances = hasAnyLances(blob);
	doQuiverUpdate(this, has_lances);
}

bool IsFiring(CBlob@ blob)
{
	return blob.isKeyPressed(key_action1);
}

void doQuiverUpdate(CSprite@ this, bool has_lances)
{
	CSpriteLayer@ quiverLayer = this.getSpriteLayer("quiver");
	CBlob@ blob = this.getBlob();

	if (quiverLayer !is null)
	{
		if (not this.isVisible()) {
			quiverLayer.SetVisible(false);
			return;
		}
		quiverLayer.SetVisible(true);
		f32 quiverangle = 45.0f;

		//face the same way (force)
		quiverLayer.SetIgnoreParentFacing(true);
		quiverLayer.SetFacingLeft(this.isFacingLeft());

		int layer = 0;
		Vec2f head_offset = getHeadOffset(blob, -1, layer);

		bool down = (this.isAnimation("crouch") || this.isAnimation("dead"));
		bool easy = false;

		if (down)
		{
			quiverangle += 135.0f;
		}
		if (this.isFacingLeft())
		{
			quiverangle *= -1.0f;
		}

		Vec2f off;
		if (layer != 0)
		{
			easy = true;
			off.Set(this.getFrameWidth() / 2, -this.getFrameHeight() / 2);
			off += this.getOffset();
			off += Vec2f(-head_offset.x, head_offset.y);


			f32 y = (down ? 6.0f : 9.0f);
			f32 x = 3.0f;
			off += Vec2f(x, y + config_offset);
		}

		if (easy)
		{
			quiverLayer.SetOffset(off);
		}

		quiverLayer.ResetTransform();
		quiverLayer.RotateBy(quiverangle, Vec2f(0.0f, 0.0f));

		if (has_lances)
		{
			quiverLayer.SetVisible(true);
		}
		else
		{
			quiverLayer.SetVisible(false);
		}
	}
}

void onGib(CSprite@ this)
{
	if (g_kidssafe)
	{
		return;
	}

	CBlob@ blob = this.getBlob();
	Vec2f pos = blob.getPosition();
	Vec2f vel = blob.getVelocity();
	vel.y -= 3.0f;
	f32 hp = Maths::Min(Maths::Abs(blob.getHealth()), 2.0f) + 1.0f;
	const u8 team = blob.getTeamNum();
	CParticle@ Body     = makeGibParticle("Entities/Characters/Firelancer/FirelancerGibs.png", pos, vel + getRandomVelocity(90, hp , 80), 0, 0, Vec2f(16, 16), 2.0f, 20, "/BodyGibFall", team);
	CParticle@ Arm      = makeGibParticle("Entities/Characters/Firelancer/FirelancerGibs.png", pos, vel + getRandomVelocity(90, hp - 0.2 , 80), 1, 0, Vec2f(16, 16), 2.0f, 20, "/BodyGibFall", team);
	CParticle@ Shield   = makeGibParticle("Entities/Characters/Firelancer/FirelancerGibs.png", pos, vel + getRandomVelocity(90, hp , 80), 2, 0, Vec2f(16, 16), 2.0f, 0, "Sounds/material_drop.ogg", team);
	CParticle@ Sword    = makeGibParticle("Entities/Characters/Firelancer/FirelancerGibs.png", pos, vel + getRandomVelocity(90, hp + 1 , 80), 3, 0, Vec2f(16, 16), 2.0f, 0, "Sounds/material_drop.ogg", team);
}

// render cursors

void DrawCursorAt(Vec2f position, string& in filename)
{
	position = getMap().getAlignedWorldPos(position);
	if (position == Vec2f_zero) return;
	position = getDriver().getScreenPosFromWorldPos(position - Vec2f(1, 1));
	GUI::DrawIcon(filename, position, getCamera().targetDistance * getDriver().getResolutionScaleFactor());
}

const string cursorTexture = "Entities/Characters/Sprites/TileCursor.png";

void onRender(CSprite@ this)
{
	CBlob@ blob = this.getBlob();
	if (!blob.isMyPlayer())
	{
		return;
	}
	if (getHUD().hasButtons())
	{
		return;
	}

	// draw tile cursor

	if (blob.isKeyPressed(key_action2))
	{
		CMap@ map = blob.getMap();
		Vec2f position = blob.getPosition();
		Vec2f cursor_position = blob.getAimPos();
		Vec2f surface_position;
		map.rayCastSolid(position, cursor_position, surface_position);
		Vec2f vector = surface_position - position;
		f32 distance = vector.getLength();
		Tile tile = map.getTile(surface_position);

		if ((map.isTileSolid(tile) || map.isTileGrass(tile.type)) && map.getSectorAtPosition(surface_position, "no build") is null && distance < 18.0f)
		{
			DrawCursorAt(surface_position, cursorTexture);
		}
	}
}
