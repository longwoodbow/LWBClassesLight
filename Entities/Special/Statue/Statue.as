// statue logic

#include "MakeDustParticle.as";
#include "Hitters.as";
#include "DTSConfig.as";

void onInit(CBlob@ this)
{
	// for sound
	this.Tag("heavy weight");

	//cannot fall out of map
	this.SetMapEdgeFlags(u8(CBlob::map_collide_up) |
	                     u8(CBlob::map_collide_down) |
	                     u8(CBlob::map_collide_sides));

	// defaultnobuild
	this.set_Vec2f("nobuild extend", Vec2f(0.0f, 8.0f));

	this.SetMinimapVars("GUI/Minimap/MinimapIcons.png", 9, Vec2f(8, 8));
	this.server_SetHealth(DTSConfig::statueHealth);
}

//sprite

void onInit(CSprite@ this)
{
	this.SetZ(10.0f);
}

bool doesCollideWithBlob(CBlob@ this, CBlob@ blob)
{
	return (blob.hasTag("projectile") && blob.getTeamNum() != this.getTeamNum());
}

/* kill projectiles for never stick on statue
void onCollision(CBlob@ this, CBlob@ blob, bool solid)
{
	if(blob.hasTag("projectile") && doesCollideWithBlob(this, blob))
		this.server_Hit(blob, this.getPosition(), Vec2f_zero, 1.0f, Hitters::crush);
}*/

// from GenericDestruction.as

void onHealthChange(CBlob@ this, f32 health_old)
{
	CSprite@ sprite = this.getSprite();
	if (sprite is null) return;

	Animation@ animation = sprite.getAnimation("destruction");
	if (animation is null) return;

	float initialHealth = DTSConfig::statueHealth;
	sprite.animation.frame = u8((initialHealth - this.getHealth()) / (initialHealth / sprite.animation.getFramesCount()));
}

// from HealthBar.as

void onRender(CSprite@ this)
{
	if (g_videorecording)
		return;

	CBlob@ blob = this.getBlob();
	Vec2f center = blob.getPosition();
	Vec2f mouseWorld = getControls().getMouseWorldPos();
	const f32 renderRadius = (blob.getRadius()) * 0.95f;
	bool mouseOnBlob = (mouseWorld - center).getLength() < renderRadius;
	if (mouseOnBlob)
	{
		//VV right here VV
		Vec2f pos2d = blob.getScreenPos() + Vec2f(0, 20);
		Vec2f dim = Vec2f(24, 8);
		const f32 y = blob.getHeight() * 2.4f;
		const f32 initialHealth = DTSConfig::statueHealth;
		if (initialHealth > 0.0f)
		{
			const f32 perc = blob.getHealth() / initialHealth;
			if (perc >= 0.0f)
			{
				GUI::DrawRectangle(Vec2f(pos2d.x - dim.x - 2, pos2d.y + y - 2), Vec2f(pos2d.x + dim.x + 2, pos2d.y + y + dim.y + 2));
				GUI::DrawRectangle(Vec2f(pos2d.x - dim.x + 2, pos2d.y + y + 2), Vec2f(pos2d.x - dim.x + perc * 2.0f * dim.x - 2, pos2d.y + y + dim.y - 2), SColor(0xffac1512));
			}
		}
	}
}