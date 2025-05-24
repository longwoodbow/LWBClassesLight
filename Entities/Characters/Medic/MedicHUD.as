//knight HUD
#include "/Entities/Common/GUI/ActorHUDStartPos.as";

const string iconsFilename = "Entities/Characters/Medic/MedicIcons.png";
const int slotsSize = 6;

void onInit(CSprite@ this)
{
	this.getCurrentScript().runFlags |= Script::tick_myplayer;
	this.getCurrentScript().removeIfTag = "dead";
	this.getBlob().set_u8("gui_HUD_slots_width", slotsSize);
}

void ManageCursors(CBlob@ this)
{
	if (getHUD().hasButtons())
	{
		getHUD().SetDefaultCursor();
	}
	else
	{
		if (this.isAttached() && this.isAttachedToPoint("GUNNER"))
		{
			getHUD().SetCursorImage("Entities/Characters/Archer/ArcherCursor.png", Vec2f(32, 32));
			getHUD().SetCursorOffset(Vec2f(-16, -16) * cl_mouse_scale);
		}
		else
		{
			getHUD().SetCursorImage("Entities/Characters/Medic/MedicCursor.png");
		}
	}
}

void onDie(CBlob@ this)//clear icon
{
	CBlob@[] list;
	if(getBlobsByTag("player", @list))
	{
		for(uint i = 0; i < list.length(); i++)
		{
			list[i].getSprite().RemoveSpriteLayer("need_medic");
		}
	}
	if(getBlobsByTag("dead", @list))
	{
		for(uint i = 0; i < list.length(); i++)
		{
			list[i].getSprite().RemoveSpriteLayer("need_medic");
		}
	}
}

void onRender(CSprite@ this)
{
	CBlob@ blob = this.getBlob();
	ManageCursors(blob);

	if (g_videorecording)
		return;

	if (!blob.hasTag("dead"))
	{
		CBlob@[] list;
		if(getBlobsByTag("player", @list))
		{
			for(uint i = 0; i < list.length(); i++)
			{
				CSprite@ sprite = list[i].getSprite();
				CSpriteLayer@ icon = sprite.getSpriteLayer("need_medic");
				if(!list[i].isMyPlayer() && !list[i].hasTag("dead") && list[i].getTeamNum() == blob.getTeamNum() && list[i].getHealth() < list[i].getInitialHealth())
				{
					if (icon is null)
					{
						CSpriteLayer@ addIcon = sprite.addSpriteLayer("need_medic", "NeedsMedicIcon.png", 9, 9);
						if (addIcon !is null)
						{
							Animation@ anim = addIcon.addAnimation("default", 0, false);
							anim.AddFrame(0);
							addIcon.SetRelativeZ(1000.0f);
							addIcon.SetVisible(true);
							addIcon.SetLighting(true);
						}
					}
					else
						icon.SetVisible(true);
				}
				else
				{
					if (icon !is null)
					{
						icon.SetVisible(false);
					}
				}
			}
		}
		
		list.clear();
		if(getBlobsByTag("dead", @list))
		{
			for(uint i = 0; i < list.length(); i++)
			{
				if (list[i].hasTag("dead")) list[i].getSprite().RemoveSpriteLayer("need_medic");
			}
		}
	}

	CPlayer@ player = blob.getPlayer();

	// draw inventory

	Vec2f tl = getActorHUDStartPosition(blob, slotsSize);
	DrawInventoryOnHUD(blob, tl);

	u8 type = blob.get_u8("spray type");
	u8 frame = 0;
	if (type < 255)
	{
		frame = 1 + type;
	}

	// draw coins

	const int coins = player !is null ? player.getCoins() : 0;
	DrawCoinsOnHUD(blob, coins, tl, slotsSize - 2);

	// draw class icon

	GUI::DrawIcon(iconsFilename, frame, Vec2f(16, 32), tl + Vec2f(8 + (slotsSize - 1) * 40, -16), 1.0f);
}
