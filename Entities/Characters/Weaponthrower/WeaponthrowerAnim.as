// Weaponthrower animations

#include "WeaponthrowerCommon.as";
#include "RunnerAnimCommon.as";
#include "RunnerCommon.as";
#include "KnockedCommon.as";
#include "PixelOffsets.as"
#include "RunnerTextures.as"
#include "Accolades.as"
#include "ShieldCommon.as"
#include "CrouchCommon.as";

const string shiny_layer = "shiny bit";

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
	ensureCorrectRunnerTexture(this, "weaponthrower", "Weaponthrower");

	// add shiny
	this.RemoveSpriteLayer(shiny_layer);
	CSpriteLayer@ shiny = this.addSpriteLayer(shiny_layer, "AnimeShiny.png", 16, 16);

	if (shiny !is null)
	{
		Animation@ anim = shiny.addAnimation("default", 2, true);
		int[] frames = {0, 1, 2, 3};
		anim.AddFrames(frames);
		shiny.SetVisible(false);
		shiny.SetRelativeZ(1.0f);
	}
}

void onTick(CSprite@ this)
{
	// store some vars for ease and speed
	CBlob@ blob = this.getBlob();
	Vec2f pos = blob.getPosition();
	Vec2f aimpos;

	WeaponthrowerInfo@ weaponthrower;
	if (!blob.get("weaponthrowerInfo", @weaponthrower))
	{
		return;
	}

	bool knocked = isKnocked(blob);

	bool shieldState = isShieldState(weaponthrower.state);
	bool specialShieldState = isSpecialShieldState(weaponthrower.state);
	bool weaponState = isWeaponState(weaponthrower.state);

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
			this.RemoveSpriteLayer(shiny_layer);
			this.SetAnimation("dead");
		}
		Vec2f oldvel = blob.getOldVelocity();

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

		return;
	}

	// get the angle of aiming with mouse
	Vec2f vec;
	int direction = blob.getAimDirection(vec);

	// set facing
	bool facingLeft = this.isFacingLeft();
	// animations
	bool ended = this.isAnimationEnded() || this.isAnimation("shield_raised");

	const bool left = blob.isKeyPressed(key_left);
	const bool right = blob.isKeyPressed(key_right);
	const bool up = blob.isKeyPressed(key_up);
	const bool down = blob.isKeyPressed(key_down);

	bool shinydot = false;

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
		switch(weaponthrower.state)
		{
			case WeaponthrowerStates::shieldgliding:
				this.SetAnimation("shield_glide");
			break;

			case WeaponthrowerStates::shielddropping:
				this.SetAnimation("shield_drop");
			break;

			case WeaponthrowerStates::resheathing_throw:
				this.SetAnimation("resheath_throw");
			break;

			case WeaponthrowerStates::weapon_throw:
			case WeaponthrowerStates::weapon_throw_super:
			{
				if(weaponthrower.weapon_type == WeaponType::chakram)
					this.SetAnimation("chakram_power");
				else
					this.SetAnimation("boomerang_power");
		
				if (weaponthrower.weaponTimer <= 1)
					this.animation.SetFrameIndex(0);
			}
			break;
	
			case WeaponthrowerStates::weapon_drawn:
			{
				if (weaponthrower.weaponTimer < WeaponthrowerVars::throw_charge)
				{
					this.SetAnimation(crouching ? "draw_weapon_crouched" : "draw_weapon");
				}
				else if (weaponthrower.weaponTimer < WeaponthrowerVars::throw_charge_level2)
				{
					if(weaponthrower.weapon_type == WeaponType::chakram)
						this.SetAnimation(crouching ? "chakram_power_ready_crouched" : "chakram_power_ready");
					else
						this.SetAnimation(crouching ? "boomerang_power_ready_crouched" : "boomerang_power_ready");
					this.animation.frame = 0;
				}
				else if (weaponthrower.weaponTimer < WeaponthrowerVars::throw_charge_limit)
				{
					if(weaponthrower.weapon_type == WeaponType::chakram)
						this.SetAnimation(crouching ? "chakram_power_ready_crouched" : "chakram_power_ready");
					else
						this.SetAnimation(crouching ? "boomerang_power_ready_crouched" : "boomerang_power_ready");
					this.animation.frame = 1;
					shinydot = true;
				}
				else
				{
					this.SetAnimation(crouching ? "draw_weapon_crouched" : "draw_weapon");
				}
			}
			break;
	
			case WeaponthrowerStates::shielding:
			{
				if (!isShieldEnabled(blob))
					break;
	
				if (walking)
				{
					if (direction == 0)
					{
						this.SetAnimation("shield_run");
					}
					else if (direction == -1)
					{
						this.SetAnimation("shield_run_up");
					}
					else if (direction == 1)
					{
						this.SetAnimation("shield_run_down");
					}
				}
				else
				{
					this.SetAnimation(crouching ? "shield_crouched" : "shield_raised");
		
					if (direction == 1)
					{
						this.animation.frame = 2;
					}
					else if (direction == -1)
					{
						if (vec.y > -0.97)
						{
							this.animation.frame = 1;
						}
						else
						{
							this.animation.frame = 3;
						}
					}
					else
					{
						this.animation.frame = 0;
					}
				}
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

	//set the shiny dot on the weapon

	CSpriteLayer@ shiny = this.getSpriteLayer(shiny_layer);

	if (shiny !is null)
	{
		shiny.SetVisible(shinydot);
		if (shinydot)
		{
			shiny.RotateBy(10, Vec2f());
			shiny.SetOffset(Vec2f(12, -2));
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
	CParticle@ Body     = makeGibParticle("Entities/Characters/Weaponthrower/WeaponthrowerGibs.png", pos, vel + getRandomVelocity(90, hp , 80), 0, 0, Vec2f(16, 16), 2.0f, 20, "/BodyGibFall", team);
	CParticle@ Arm      = makeGibParticle("Entities/Characters/Weaponthrower/WeaponthrowerGibs.png", pos, vel + getRandomVelocity(90, hp - 0.2 , 80), 1, 0, Vec2f(16, 16), 2.0f, 20, "/BodyGibFall", team);
	CParticle@ Shield   = makeGibParticle("Entities/Characters/Weaponthrower/WeaponthrowerGibs.png", pos, vel + getRandomVelocity(90, hp , 80), 2, 0, Vec2f(16, 16), 2.0f, 0, "Sounds/material_drop.ogg", team);
	CParticle@ Sword    = makeGibParticle("Entities/Characters/Weaponthrower/WeaponthrowerGibs.png", pos, vel + getRandomVelocity(90, hp + 1 , 80), 3, 0, Vec2f(16, 16), 2.0f, 0, "Sounds/material_drop.ogg", team);
}