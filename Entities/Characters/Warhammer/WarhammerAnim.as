// Warhammer animations

#include "WarhammerCommon.as";
#include "RunnerAnimCommon.as";
#include "RunnerCommon.as";
#include "KnockedCommon.as";
#include "PixelOffsets.as"
#include "RunnerTextures.as"
#include "Accolades.as"
#include "CrouchCommon.as";

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
	ensureCorrectRunnerTexture(this, "warhammer", "Warhammer");

	string texname = getRunnerTextureName(this);

	// add blade
	this.RemoveSpriteLayer("chop");
	CSpriteLayer@ chop = this.addTexturedSpriteLayer("chop", this.getTextureName(), 32, 32);

	if (chop !is null)
	{
		Animation@ anim = chop.addAnimation("default", 0, true);
		anim.AddFrame(35);
		anim.AddFrame(43);
		anim.AddFrame(63);
		chop.SetVisible(false);
		chop.SetRelativeZ(1000.0f);
	}

	//spinning flail
	this.RemoveSpriteLayer("flail");
	CSpriteLayer@ flail = this.addTexturedSpriteLayer("flail", texname , 32, 8);

	if (flail !is null)
	{
		Animation@ anim = flail.addAnimation("default", 4, true);
		anim.AddFrame(33);
		anim.AddFrame(34);
		anim.AddFrame(35);
		anim.AddFrame(36);
		flail.SetRelativeZ(1.0f);
		flail.SetVisible(false);
	}

	//thrown flail
	this.RemoveSpriteLayer("ball");
	CSpriteLayer@ ball = this.addTexturedSpriteLayer("ball", texname , 8, 8);

	if (ball !is null)
	{
		Animation@ anim = ball.addAnimation("default", 0, false);
		anim.AddFrame(152);
		ball.SetRelativeZ(2.0f);
		ball.SetVisible(false);
	}

	this.RemoveSpriteLayer("chain");
	CSpriteLayer@ chain = this.addTexturedSpriteLayer("chain", texname , 32, 8);

	if (chain !is null)
	{
		Animation@ anim = chain.addAnimation("default", 0, false);
		anim.AddFrame(37);
		chain.SetRelativeZ(-1.5f);
		chain.SetVisible(false);
	}
}

void onTick(CSprite@ this)
{
	// store some vars for ease and speed
	CBlob@ blob = this.getBlob();
	Vec2f pos = blob.getPosition();
	Vec2f aimpos;

	WarhammerInfo@ warhammer;
	if (!blob.get("warhammerInfo", @warhammer))
	{
		return;
	}

	bool knocked = isKnocked(blob);

	bool flailState = isFlailState(warhammer.state);
	bool hammerState = isHammerState(warhammer.state);

	bool pressed_a1 = blob.isKeyPressed(key_action1);
	bool pressed_a2 = blob.isKeyPressed(key_action2);

	bool walking = (blob.isKeyPressed(key_left) || blob.isKeyPressed(key_right));
	bool crouching = isCrouching(blob);

	aimpos = blob.getAimPos();
	bool inair = (!blob.isOnGround() && !blob.isOnLadder());

	Vec2f vel = blob.getVelocity();

	if (blob.hasTag("dead"))
	{
		if (this.animation.name != "dead")
		{
			this.SetAnimation("dead");
			this.RemoveSpriteLayer("flail");
			this.RemoveSpriteLayer("ball");
			this.RemoveSpriteLayer("chain");
		}
		Vec2f oldvel = blob.getOldVelocity();

		doFlailUpdate(this, null, null);
		//TODO: trigger frame one the first time we server_Die()()
		if (vel.y < -1.0f)
		{
			this.SetFrameIndex(1);
		}
		else if (vel.y > 1.0f)
		{
			this.SetFrameIndex(3);
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

	doFlailUpdate(this, blob, warhammer);

	// get the angle of aiming with mouse
	Vec2f vec;
	int direction = blob.getAimDirection(vec);

	// set facing
	bool facingLeft = this.isFacingLeft();
	// animations
	bool ended = this.isAnimationEnded() || this.isAnimation("flail") || this.isAnimation("flail_crouched");
	bool wantsChopLayer = false;
	bool wantsFlailLayer = false;
	s32 chopframe = 0;
	f32 chopAngle = 0.0f;

	const bool left = blob.isKeyPressed(key_left);
	const bool right = blob.isKeyPressed(key_right);
	const bool up = blob.isKeyPressed(key_up);
	const bool down = blob.isKeyPressed(key_down);

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
		this.SetAnimation("crouch");
	}
	else
	{
		switch(warhammer.state)
		{

			case WarhammerStates::flailthrow:
				this.SetAnimation("flail_throw");
			break;

			case WarhammerStates::resheathing_slash:
				this.SetAnimation("resheath_slash");
			break;
			
			case WarhammerStates::resheathing_cut:
				this.SetAnimation(crouching ? "draw_hammer_crouched" : "draw_hammer");
			break;

			case WarhammerStates::hammer_cut_mid:
				this.SetAnimation("strike_mid");
			break;

			case WarhammerStates::hammer_cut_mid_down:
				this.SetAnimation("strike_mid_down");
			break;

			case WarhammerStates::hammer_cut_up:
				this.SetAnimation("strike_up");
			break;

			case WarhammerStates::hammer_cut_down:
				this.SetAnimation("strike_down");
			break;

			case WarhammerStates::hammer_power:
			{
				this.SetAnimation("strike_power");

				if (warhammer.hammerTimer <= 1)
					this.animation.SetFrameIndex(0);

				u8 mintime = 6;
				u8 maxtime = 8;
				if (warhammer.hammerTimer >= mintime && warhammer.hammerTimer <= maxtime)
				{
					wantsChopLayer = true;
					chopframe = warhammer.hammerTimer - mintime;
					chopAngle = -vec.Angle();
				}
			}
			break;

			case WarhammerStates::hammer_drawn:
			{
				if (warhammer.hammerTimer < WarhammerVars::slash_charge)
				{
					this.SetAnimation(crouching ? "draw_hammer_crouched" : "draw_hammer");
				}
				else if (warhammer.hammerTimer <= WarhammerVars::slash_charge_limit)
				{
					this.SetAnimation(crouching ? "strike_power_ready_crouched" : "strike_power_ready");
					this.animation.frame = 0;
				}
				else
				{
					this.SetAnimation(crouching ? "draw_hammer_crouched" : "draw_hammer");
				}
			}
			break;

			case WarhammerStates::flail:
			{
				/*if (walking)
				{
					if (direction == 0)
					{
						this.SetAnimation("flail_run");
					}
					else if (direction == -1)
					{
						this.SetAnimation("flail_run_up");
					}
					else if (direction == 1)
					{
						this.SetAnimation("flail_run_down");
					}
						}*/
				if (getInAir(blob) && !blob.isInWater())
				{
					this.SetAnimation("flail_glide");
				}
				else
				{
					this.SetAnimation(crouching ? "flail_crouched" : "flail");

					//change speed by charge
				}
				wantsFlailLayer = true;
			}
			break;

			default:
			{
				if (inair)
				{
					RunnerMoveVars@ moveVars;
					if (!blob.get("moveVars", @moveVars))
					{
						return;
					}
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
				else if (walking || 
					(blob.isOnLadder() && (blob.isKeyPressed(key_up) || blob.isKeyPressed(key_down))))
				{
					this.SetAnimation("run");
				}
				else
				{
					defaultIdleAnim(this, blob, direction);
				}
			}
		}
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

	CSpriteLayer@ flail = this.getSpriteLayer("flail");

	if (flail !is null)
	{
		flail.SetVisible(wantsFlailLayer);
		if (wantsFlailLayer)
		{
			bool readying = warhammer.hammerTimer < WarhammerVars::flail_ready;
			bool charging = warhammer.hammerTimer < WarhammerVars::flail_charge;
			bool limit = warhammer.hammerTimer <= WarhammerVars::flail_charge_limit;

			f32 pitch = readying ? 0.5f :
						charging ? 0.75f :
						1.0f;
			if (flail.animation.timer == 0)
			{
				this.PlaySound("/SwordSlash", 1.0f, pitch);
			}

			flail.animation.time = readying ? 4 :
										charging ? 3 :
										2;

			int layer = 0;
			Vec2f head_offset = getHeadOffset(blob, -1, layer);

			Vec2f off;
			off.Set(this.getFrameWidth() / 2, -this.getFrameHeight() / 2);
			off += this.getOffset();
			off += Vec2f(-head_offset.x, head_offset.y);

			if(this.isAnimation("flail_glide")) off += Vec2f(6, -3);
			else if(this.isAnimation("flail")) off += Vec2f(8, -4);
			else if(this.isAnimation("flail_crouched")) off += Vec2f(7, -4);
			flail.SetOffset(off);
		}
	}

	//set the head anim
	if (knocked)
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

void doFlailUpdate(CSprite@ this, CBlob@ blob, WarhammerInfo@ warhammer)
{
	CSpriteLayer@ chain = this.getSpriteLayer("chain");
	CSpriteLayer@ ball = this.getSpriteLayer("ball");

	bool visible = warhammer !is null && warhammer.flail;

	if (chain !is null) chain.SetVisible(visible);// no null chech on archer anim... really?
	if (ball !is null) ball.SetVisible(visible);
	if (!visible)
	{
		return;
	}

	Vec2f adjusted_pos = Vec2f(warhammer.flail_pos.x, Maths::Max(0.0, warhammer.flail_pos.y));
	Vec2f off = adjusted_pos - blob.getPosition();

	f32 chainlen = Maths::Max(0.1f, off.Length() / 32.0f);
	if (chainlen > 200.0f)
	{
		chain.SetVisible(false);
		ball.SetVisible(false);
		return;
	}

	chain.ResetTransform();
	chain.ScaleBy(Vec2f(chainlen, 1.0f));

	chain.TranslateBy(Vec2f(chainlen * 16.0f, 0.0f));

	chain.RotateBy(-off.Angle() , Vec2f());

	ball.ResetTransform();
	warhammer.cache_angle = -warhammer.flail_vel.Angle();
	ball.RotateBy(warhammer.cache_angle , Vec2f());

	ball.TranslateBy(off);
	ball.SetIgnoreParentFacing(true);
	ball.SetFacingLeft(false);

	//GUI::DrawLine(blob.getPosition(), warhammer.flail_pos, SColor(255,255,255,255));
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
	CParticle@ Body     = makeGibParticle("Entities/Characters/Warhammer/WarhammerGibs.png", pos, vel + getRandomVelocity(90, hp , 80), 0, 0, Vec2f(16, 16), 2.0f, 20, "/BodyGibFall", team);
	CParticle@ Arm      = makeGibParticle("Entities/Characters/Warhammer/WarhammerGibs.png", pos, vel + getRandomVelocity(90, hp - 0.2 , 80), 1, 0, Vec2f(16, 16), 2.0f, 20, "/BodyGibFall", team);
	CParticle@ Flail   = makeGibParticle("Entities/Characters/Warhammer/WarhammerGibs.png", pos, vel + getRandomVelocity(90, hp , 80), 2, 0, Vec2f(16, 16), 2.0f, 0, "Sounds/material_drop.ogg", team);
	CParticle@ Hammer    = makeGibParticle("Entities/Characters/Warhammer/WarhammerGibs.png", pos, vel + getRandomVelocity(90, hp + 1 , 80), 3, 0, Vec2f(16, 16), 2.0f, 0, "Sounds/material_drop.ogg", team);
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

		if ((map.isTileSolid(tile) || map.isTileGrass(tile.type)) && map.getSectorAtPosition(surface_position, "no build") is null && distance < 16.0f)
		{
			DrawCursorAt(surface_position, cursorTexture);
		}
	}
}
