// based WoodStructureHit.as
// changed bomb arrow multiply from 8.0 to balancing

#include "Hitters.as";
#include "GameplayEventsCommon.as";

u8 alertTimer = 0;
void onTick(CBlob@ this)
{
	if (alertTimer > 0) alertTimer--;
}


f32 onHit(CBlob@ this, Vec2f worldPoint, Vec2f velocity, f32 damage, CBlob@ hitterBlob, u8 customData)
{
	f32 dmg = damage;

	switch (customData)
	{
		case Hitters::builder:
			dmg *= 2.0f;
			break;

		case Hitters::drill:
			dmg *= 0.8f;
			break;

		case Hitters::sword:
		case Hitters::arrow:
		case Hitters::stab:
			dmg *= 0.5f;
			break;

		case Hitters::bomb:
			dmg *= 1.40f;
			break;

		case Hitters::burn:
			dmg = 1.0f;
			break;

		case Hitters::explosion:
			dmg *= 2.5f;
			break;

		case Hitters::bomb_arrow:
			dmg *= 2.5f;
			break;

		case Hitters::cata_stones:
		case Hitters::crush:
		case Hitters::cata_boulder:
			dmg *= 1.5f;
			break;

		case Hitters::flying: // boat ram
			dmg *= 1.0f;
			break;
	}

	if (dmg > 0 && hitterBlob !is null && hitterBlob !is this)
	{
		CPlayer@ damageowner = hitterBlob.getDamageOwnerPlayer();
		if (damageowner !is null)
		{
			if (damageowner.getTeamNum() != this.getTeamNum() && isServer())
			{
				GE_HitStatue(damageowner.getNetworkID(), dmg); // gameplay event for coins
			}
		}
	}

	if (alertTimer == 0)
	{
		CPlayer@ p = getLocalPlayer();
		if (p !is null && p.getTeamNum() == this.getTeamNum())
		{
			Sound::Play("/depleting.ogg");
		}
		alertTimer = 150;
	}
	
	return dmg;
}

//make message? TODO
void onDie(CBlob@ this)
{
	CPlayer@ p = this.getPlayerOfRecentDamage();
	if (p !is null)
	{
		CBlob@ b = p.getBlob();
		if (b !is null && b.getTeamNum() != this.getTeamNum() && isServer())
		{
			CPlayer@ p = this.getPlayerOfRecentDamage();
			if (p !is null)
			{
				GE_KillStatue(p.getNetworkID());
			}
		}
	}
	Sound::Play("/flag_score.ogg");
}