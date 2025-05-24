// based of Heal.as
#include "DTSConfig.as";

void onInit(CBlob@ this)
{
	this.getCurrentScript().tickFrequency = DTSConfig::healCooldown;
	this.set_TileType("background tile", CMap::tile_castle_back);
}

void onTick(CBlob@ this)
{
	CBlob@[] blobsInRadius;
	if (getMap().getBlobsInRadius(this.getPosition(), this.getRadius(), @blobsInRadius))
	{
		const u8 teamNum = this.getTeamNum();
		for (uint i = 0; i < blobsInRadius.length; i++)
		{
			CBlob @b = blobsInRadius[i];
			if ((b.getTeamNum() == teamNum || this.getTeamNum() == 255) && b.getHealth() < b.getInitialHealth() && b.hasTag("flesh") && !b.hasTag("dead"))// team -1 spot heals all players
			{
				f32 oldHealth = b.getHealth();
				b.server_Heal(1.0f);
				b.add_f32("heal amount", b.getHealth() - oldHealth);
				b.getSprite().PlaySound("/Heart.ogg");
			}
		}
	}
}