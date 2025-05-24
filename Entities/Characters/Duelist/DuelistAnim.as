// Duelist animations

#include "DuelistCommon.as"
#include "FireParticle.as"
#include "RunnerAnimCommon.as";
#include "RunnerCommon.as";
#include "KnockedCommon.as";
#include "PixelOffsets.as"
#include "RunnerTextures.as"
#include "Accolades.as"

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
	ensureCorrectRunnerTexture(this, "duelist", "Duelist");

	string texname = getRunnerTextureName(this);

	// add blade
	this.RemoveSpriteLayer("chop");
	CSpriteLayer@ chop = this.addTexturedSpriteLayer("chop", this.getTextureName(), 32, 32);

	if (chop !is null)
	{
		Animation@ anim = chop.addAnimation("default", 0, true);
		anim.AddFrame(8);
		anim.AddFrame(9);
		anim.AddFrame(10);
		chop.SetVisible(false);
		chop.SetRelativeZ(1000.0f);
	}

	//grapple
	this.RemoveSpriteLayer("hook");
	CSpriteLayer@ hook = this.addTexturedSpriteLayer("hook", texname , 16, 8);

	if (hook !is null)
	{
		Animation@ anim = hook.addAnimation("default", 0, false);
		anim.AddFrame(178);
		hook.SetRelativeZ(2.0f);
		hook.SetVisible(false);
	}

	this.RemoveSpriteLayer("rope");
	CSpriteLayer@ rope = this.addTexturedSpriteLayer("rope", texname , 32, 8);

	if (rope !is null)
	{
		Animation@ anim = rope.addAnimation("default", 0, false);
		anim.AddFrame(81);
		rope.SetRelativeZ(-1.5f);
		rope.SetVisible(false);
	}
}

void onTick(CSprite@ this)
{
	// store some vars for ease and speed
	CBlob@ blob = this.getBlob();

	if (blob.hasTag("dead"))
	{
		if (this.animation.name != "dead")
		{
			this.SetAnimation("dead");
		}

		doRopeUpdate(this, null, null);

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

		CSpriteLayer@ chop = this.getSpriteLayer("chop");

		if (chop !is null)
		{
			chop.SetVisible(false);
		}

		return;
	}

	DuelistInfo@ duel;
	if (!blob.get("duelistInfo", @duel))
	{
		return;
	}

	doRopeUpdate(this, blob, duel);

	// animations
	bool wantsChopLayer = false;
	s32 chopframe = 0;
	f32 chopAngle = 0.0f;

	const bool left = blob.isKeyPressed(key_left);
	const bool right = blob.isKeyPressed(key_right);
	const bool up = blob.isKeyPressed(key_up);
	const bool down = blob.isKeyPressed(key_down);
	const bool inair = (!blob.isOnGround() && !blob.isOnLadder());
	bool crouch = false;

	bool knocked = isKnocked(blob);
	const bool action1 = blob.isKeyPressed(key_action1);
	Vec2f pos = blob.getPosition();
	Vec2f aimpos = blob.getAimPos();
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
	else if (duel.state == DuelistStates::resheathing_slash)
	{
		this.SetAnimation("resheath_slash");
	}
	else if(duel.state == DuelistStates::resheathing_cut)
	{
		this.SetAnimation("draw_rapier");
	}
	else if (duel.state == DuelistStates::rapier_drawn)
	{
		if (duel.rapierTimer < DuelistVars::slash_charge)
		{
			this.SetAnimation("draw_rapier");
		}
		else if (duel.rapierTimer < DuelistVars::slash_charge_limit)
		{
			this.SetAnimation("strike_power_ready");
		}
		else
		{
			this.SetAnimation("draw_rapier");
		}
	}
	else if (isRapierAnim(this) && !this.isAnimationEnded())// now playing rapier? keep going
	{
		this.SetAnimation(this.animation.name);

		if(duel.state == DuelistStates::rapier_power)
		{
			u8 mintime = 6;
			u8 maxtime = 8;
			if (duel.rapierTimer >= mintime && duel.rapierTimer <= maxtime)
			{
				wantsChopLayer = true;
				chopframe = duel.rapierTimer - mintime;
				chopAngle = -vec.Angle();
			}
		}
	}
	else if (duel.state == DuelistStates::rapier_cut || duel.state == DuelistStates::rapier_power)
	{
		const int direction = this.getBlob().getAimDirection(vec);
		if (direction == -1)
		{
			this.SetAnimation("strike_up");
		}
		else if (direction == 0)
		{
			this.SetAnimation("strike_mid");
		}
		else
		{
			this.SetAnimation("strike_down");
		}
		if(duel.state == DuelistStates::rapier_power)
		{
			u8 mintime = 6;
			u8 maxtime = 8;
			if (duel.rapierTimer >= mintime && duel.rapierTimer <= maxtime)
			{
				wantsChopLayer = true;
				chopframe = duel.rapierTimer - mintime;
				chopAngle = -vec.Angle();
			}
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

	CSpriteLayer@ chop = this.getSpriteLayer("chop");

	if (chop !is null)
	{
		chop.SetVisible(wantsChopLayer);
		if (wantsChopLayer)
		{
			f32 choplength = 5.0f;

			chop.animation.frame = chopframe;
			Vec2f offset = Vec2f(choplength, 0.0f);
			offset.RotateBy(chopAngle, Vec2f_zero);
			if (!this.isFacingLeft())
				offset.x *= -1.0f;
			offset.y += this.getOffset().y * 0.5f;

			chop.SetOffset(offset);
			chop.ResetTransform();
			if (this.isFacingLeft())
				chop.RotateBy(180.0f + chopAngle, Vec2f());
			else
				chop.RotateBy(chopAngle, Vec2f());
		}
	}

	//set the head anim
	if (knocked|| crouch)
	{
		blob.Tag("dead head");
	}
	else if (action1)
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

void doRopeUpdate(CSprite@ this, CBlob@ blob, DuelistInfo@ duel)
{
	CSpriteLayer@ rope = this.getSpriteLayer("rope");
	CSpriteLayer@ hook = this.getSpriteLayer("hook");

	bool visible = duel !is null && duel.grappling;

	rope.SetVisible(visible);
	hook.SetVisible(visible);
	if (!visible)
	{
		return;
	}

	Vec2f adjusted_pos = Vec2f(duel.grapple_pos.x, Maths::Max(0.0, duel.grapple_pos.y));
	Vec2f off = adjusted_pos - blob.getPosition();

	f32 ropelen = Maths::Max(0.1f, off.Length() / 32.0f);
	if (ropelen > 200.0f)
	{
		rope.SetVisible(false);
		hook.SetVisible(false);
		return;
	}

	rope.ResetTransform();
	rope.ScaleBy(Vec2f(ropelen, 1.0f));

	rope.TranslateBy(Vec2f(ropelen * 16.0f, 0.0f));

	rope.RotateBy(-off.Angle() , Vec2f());

	hook.ResetTransform();
	if (duel.grapple_id == 0xffff) //still in air
	{
		duel.cache_angle = -duel.grapple_vel.Angle();
	}
	hook.RotateBy(duel.cache_angle , Vec2f());

	hook.TranslateBy(off);
	hook.SetIgnoreParentFacing(true);
	hook.SetFacingLeft(false);

	//GUI::DrawLine(blob.getPosition(), duel.grapple_pos, SColor(255,255,255,255));
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
	CParticle@ Body     = makeGibParticle("DuelistGibs.png", pos, vel + getRandomVelocity(90, hp , 80), 0, 0, Vec2f(16, 16), 2.0f, 20, "/BodyGibFall", team);
	CParticle@ Arm      = makeGibParticle("DuelistGibs.png", pos, vel + getRandomVelocity(90, hp - 0.2 , 80), 1, 0, Vec2f(16, 16), 2.0f, 20, "/BodyGibFall", team);
	CParticle@ Shield   = makeGibParticle("DuelistGibs.png", pos, vel + getRandomVelocity(90, hp , 80), 2, 0, Vec2f(16, 16), 2.0f, 0, "Sounds/material_drop.ogg", team);
	CParticle@ Rapier    = makeGibParticle("DuelistGibs.png", pos, vel + getRandomVelocity(90, hp + 1 , 80), 3, 0, Vec2f(16, 16), 2.0f, 0, "Sounds/material_drop.ogg", team);
}

// render cursors

// as same as duel
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

	if (blob.isKeyPressed(key_action1))
	{
		CMap@ map = blob.getMap();
		Vec2f position = blob.getPosition();
		Vec2f cursor_position = blob.getAimPos();
		Vec2f surface_position;
		map.rayCastSolid(position, cursor_position, surface_position);
		Vec2f vector = surface_position - position;
		f32 distance = vector.getLength();
		Tile tile = map.getTile(surface_position);

		if ((map.isTileSolid(tile) || map.isTileGrass(tile.type)) && map.getSectorAtPosition(surface_position, "no build") is null && distance < 17.0f)
		{
			DrawCursorAt(surface_position, cursorTexture);
		}
	}
}