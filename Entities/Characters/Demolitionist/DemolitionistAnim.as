// Demolitionist animations

#include "BuilderCommon.as";
#include "DemolitionistCommon.as"
#include "FireCommon.as"
#include "Requirements.as"
#include "RunnerAnimCommon.as"
#include "RunnerCommon.as"
#include "KnockedCommon.as"
#include "PixelOffsets.as"
#include "RunnerTextures.as"
#include "Accolades.as"


//

void onInit(CSprite@ this)
{
	LoadSprites(this);

	this.getCurrentScript().runFlags |= Script::tick_not_infire;

	this.getBlob().set_string("prev_attack_anim", "strike");
}

void onPlayerInfoChanged(CSprite@ this)
{
	LoadSprites(this);
}

void LoadSprites(CSprite@ this)
{
	ensureCorrectRunnerTexture(this, "demolitionist", "Demolitionist");

	//bomb
	this.RemoveSpriteLayer("bomb");
	CSpriteLayer@ bomb = this.addTexturedSpriteLayer("bomb", getRunnerTextureName(this) , 16, 16);

	if (bomb !is null)
	{
		Animation@ anim = bomb.addAnimation("default", 0, false);
		anim.AddFrame(41);
		bomb.SetOffset(Vec2f(-12.0f, -2.0f));
		bomb.SetRelativeZ(-0.1f);
	}

	//grapple
	this.RemoveSpriteLayer("hook");
	CSpriteLayer@ hook = this.addTexturedSpriteLayer("hook", getRunnerTextureName(this) , 16, 8);

	if (hook !is null)
	{
		Animation@ anim = hook.addAnimation("default", 0, false);
		anim.AddFrame(72);
		hook.SetRelativeZ(2.0f);
		hook.SetVisible(false);
	}

	this.RemoveSpriteLayer("rope");
	CSpriteLayer@ rope = this.addTexturedSpriteLayer("rope", getRunnerTextureName(this) , 32, 8);

	if (rope !is null)
	{
		Animation@ anim = rope.addAnimation("default", 0, false);
		anim.AddFrame(35);
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
		this.SetAnimation("dead");

		doQuiverUpdate(this, false, true);
		doRopeUpdate(this, null, null);

		Vec2f vel = blob.getVelocity();

		if (vel.y < -1.0f)
		{
			this.SetFrameIndex(0);
		}
		else if (vel.y > 1.0f)
		{
			this.SetFrameIndex(2);
		}
		else
		{
			this.SetFrameIndex(1);
		}
		return;
	}

	DemolitionistInfo@ demolitionist;
	if (!blob.get("demolitionistInfo", @demolitionist))
	{
		return;
	}

	doRopeUpdate(this, blob, demolitionist);

	// animations

	bool knocked = isKnocked(blob);
	const bool action2 = blob.isKeyPressed(key_action2);
	const bool action1 = blob.isKeyPressed(key_action1);

	// set attack animation back to default
	if (blob.isKeyJustReleased(key_action2))
	{
		blob.set_string("prev_attack_anim", "strike");

	}

	if (!blob.hasTag(burning_tag)) //give way to burning anim
	{
		const bool left = blob.isKeyPressed(key_left);
		const bool right = blob.isKeyPressed(key_right);
		const bool up = blob.isKeyPressed(key_up);
		const bool down = blob.isKeyPressed(key_down);
		const bool inair = (!blob.isOnGround() && !blob.isOnLadder());
		Vec2f pos = blob.getPosition();

		RunnerMoveVars@ moveVars;
		if (!blob.get("moveVars", @moveVars))
		{
			return;
		}

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
		else if ((action1 && isPickaxeTime(blob)) || ((this.isAnimation("strike") || this.isAnimation("chop")) && !this.isAnimationEnded()))
		{
			string attack_anim = blob.get_string("prev_attack_anim");
			HitData@ hitdata;
			if (blob.get("hitdata", @hitdata))
			{
				bool hitting_wood = false;
				bool hitting_stone = false;
				bool hitting_structure = false; // hitting player-built blocks

				if (hitdata.tilepos != Vec2f_zero)
				{
					CMap@ map = getMap();
					Tile t = map.getTile(hitdata.tilepos);
					// 207 is damaged wood tile back
					if (map.isTileWood(t.type) || map.isTileGrass(t.type) || t.type == CMap::tile_wood_back || t.type == 207)
					{
						hitting_wood = true;
					}
					else if(t.type != CMap::tile_empty)
					{
						hitting_stone = true;
					}

					if (map.isTileWood(t.type) || // wood tile
						(t.type >= CMap::tile_wood_back && t.type <= 207) || // wood backwall
						map.isTileCastle(t.type) || // castle block
						(t.type >= CMap::tile_castle_back && t.type <= 79) || // castle backwall
					 	t.type == CMap::tile_castle_back_moss) // castle mossbackwall
					{
						hitting_structure = true;
					}
				}
				else if(hitdata.blobID != 0)
				{
					CBlob@ attacked = getBlobByNetworkID(hitdata.blobID);
					if (attacked !is null)
					{
						string attacked_name = attacked.getName();
						if ((attacked.hasTag("wooden") || attacked_name.toLower().find("tree") != -1 || attacked.hasTag("scenary"))
							&& attacked_name != "mine" && attacked_name != "drill")
						{
							hitting_wood = true;
						}
						else
						{
							hitting_stone = true;
						}

						if (attacked_name == "bridge" ||
							attacked_name == "wooden_platform" ||
							attacked.hasTag("door") ||
							attacked_name == "ladder" ||
							attacked_name == "spikes" ||
							attacked.hasTag("builder fast hittable")
							)
						{
							hitting_structure = true;
						}

					}
				}

				if (hitting_wood || hitting_stone)
				{
					attack_anim = hitting_wood ? "chop" : "strike";

					Animation @anim = this.getAnimation(attack_anim);

					int framecount = anim.getFramesCount();

					if (hitting_structure && anim.getFrame(0) == anim.getFrame(framecount - 1)) 
					{
						anim.RemoveFrame(anim.getFrame(framecount - 1)); // remove last anim (which is same as first)
					}
					else if (!hitting_structure && anim.getFrame(0) != anim.getFrame(framecount - 1))
					{
						anim.AddFrame(anim.getFrame(0)); // add it back
					}
				}

				this.SetAnimation(attack_anim);
				blob.set_string("prev_attack_anim", attack_anim);
			}
			else
			{
				this.SetAnimation(attack_anim);
			}

		}
		else if ((action1 && isBuildTime(blob)) || (this.isAnimation("build") && !this.isAnimationEnded()))
		{
			this.SetAnimation("build");
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
			// get the angle of aiming with mouse
			Vec2f aimpos = blob.getAimPos();
			Vec2f vec = aimpos - pos;
			f32 angle = vec.Angle();
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
	}

	doQuiverUpdate(this, blob.getBlobCount("mat_bombboxes") > 0, true);

	//set the attack head

	if (knocked)
	{
		blob.Tag("dead head");
	}
	else if ((action1 && isPickaxeTime(blob)) || blob.isInFlames())
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

void doRopeUpdate(CSprite@ this, CBlob@ blob, DemolitionistInfo@ demolitionist)
{
	CSpriteLayer@ rope = this.getSpriteLayer("rope");
	CSpriteLayer@ hook = this.getSpriteLayer("hook");

	bool visible = demolitionist !is null && demolitionist.grappling;

	rope.SetVisible(visible);
	hook.SetVisible(visible);
	if (!visible)
	{
		return;
	}

	Vec2f adjusted_pos = Vec2f(demolitionist.grapple_pos.x, Maths::Max(0.0, demolitionist.grapple_pos.y));
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
	if (demolitionist.grapple_id == 0xffff) //still in air
	{
		demolitionist.cache_angle = -demolitionist.grapple_vel.Angle();
	}
	hook.RotateBy(demolitionist.cache_angle , Vec2f());

	hook.TranslateBy(off);
	hook.SetIgnoreParentFacing(true);
	hook.SetFacingLeft(false);

	//GUI::DrawLine(blob.getPosition(), demolitionist.grapple_pos, SColor(255,255,255,255));
}

void doQuiverUpdate(CSprite@ this, bool has_bombs, bool basket)
{
	CSpriteLayer@ basketLayer = this.getSpriteLayer("bomb");
	CBlob@ blob = this.getBlob();

	if (basketLayer !is null)
	{
		if (not this.isVisible()) {
			basketLayer.SetVisible(false);
			return;
		}
		basketLayer.SetVisible(true);

		if (basket)
		{
			//face the same way (force)
			basketLayer.SetIgnoreParentFacing(true);
			basketLayer.SetFacingLeft(this.isFacingLeft());

			int layer = 0;
			Vec2f head_offset = getHeadOffset(blob, -1, layer);

			bool down = (this.isAnimation("dead"));
			bool easy = false;
			Vec2f off;
			if (layer != 0)
			{
				easy = true;
				off.Set(this.getFrameWidth() / 2, -this.getFrameHeight() / 2);
				off += this.getOffset();
				off += Vec2f(-head_offset.x, head_offset.y);


				f32 y = (down ? 3.0f : 7.0f);
				f32 x = (down ? 5.0f : 4.0f);
				off += Vec2f(x, y - 4.0f);
			}

			if (easy)
			{
				basketLayer.SetOffset(off);
			}

			if (has_bombs)
			{
				basketLayer.SetVisible(true);
			}
			else
			{
				basketLayer.SetVisible(false);
			}
		}
		else
		{
			basketLayer.SetVisible(false);
		}
	}
}

void DrawCursorAt(Vec2f position, string& in filename)
{
	position = getMap().getAlignedWorldPos(position);
	if (position == Vec2f_zero) return;
	position = getDriver().getScreenPosFromWorldPos(position - Vec2f(1, 1));
	GUI::DrawIcon(filename, position, getCamera().targetDistance * getDriver().getResolutionScaleFactor());
}

// render cursors

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

	if (blob.isKeyPressed(key_action1) || this.isAnimation("strike") || this.isAnimation("chop"))
	{
		HitData@ hitdata;
		blob.get("hitdata", @hitdata);
		CBlob@ hitBlob = hitdata.blobID > 0 ? getBlobByNetworkID(hitdata.blobID) : null;

		if (hitBlob !is null) // blob hit
		{
			if (!hitBlob.hasTag("flesh"))
			{
				hitBlob.RenderForHUD(RenderStyle::outline);

				// hacky fix for shitty z-buffer issue
				// the sprite layers go out of order while hitting with this fix,
				// but its better than the entire blob glowing brighter than the sun
				if (v_postprocess)
				{
					hitBlob.RenderForHUD(RenderStyle::normal);
				}
			}
		}
		else// map hit
		{
			DrawCursorAt(hitdata.tilepos, cursorTexture);
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
	f32 hp = Maths::Min(Maths::Abs(blob.getHealth()), 2.0f) + 1.0;
	const u8 team = blob.getTeamNum();
	CParticle@ Body     = makeGibParticle("Entities/Characters/Demolitionist/DemolitionistGibs.png", pos, vel + getRandomVelocity(90, hp , 80), 0, 0, Vec2f(16, 16), 2.0f, 20, "/BodyGibFall", team);
	CParticle@ Arm1     = makeGibParticle("Entities/Characters/Demolitionist/DemolitionistGibs.png", pos, vel + getRandomVelocity(90, hp - 0.2 , 80), 1, 0, Vec2f(16, 16), 2.0f, 20, "/BodyGibFall", team);
	CParticle@ Arm2     = makeGibParticle("Entities/Characters/Demolitionist/DemolitionistGibs.png", pos, vel + getRandomVelocity(90, hp - 0.2 , 80), 1, 0, Vec2f(16, 16), 2.0f, 20, "/BodyGibFall", team);
	CParticle@ Shield   = makeGibParticle("Entities/Characters/Demolitionist/DemolitionistGibs.png", pos, vel + getRandomVelocity(90, hp , 80), 2, 0, Vec2f(16, 16), 2.0f, 0, "Sounds/material_drop.ogg", team);
	CParticle@ Sword    = makeGibParticle("Entities/Characters/Demolitionist/DemolitionistGibs.png", pos, vel + getRandomVelocity(90, hp + 1 , 80), 3, 0, Vec2f(16, 16), 2.0f, 0, "Sounds/material_drop.ogg", team);
}
