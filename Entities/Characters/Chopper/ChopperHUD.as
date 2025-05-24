//chopper HUD

#include "/Entities/Common/GUI/ActorHUDStartPos.as";
#include "ChopperCommon.as";

const string iconsFilename = "Entities/Characters/Chopper/ChopperIcons.png";
const int slotsSize = 6;

void onInit(CSprite@ this)
{
	this.getCurrentScript().runFlags |= Script::tick_myplayer;
	this.getCurrentScript().removeIfTag = "dead";
	this.getBlob().set_u8("gui_HUD_slots_width", slotsSize);
}

void ManageCursors(CBlob@ this, bool isMattock)
{
	// set cursor
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
		else if (isMattock)
		{
			getHUD().SetCursorImage("Entities/Characters/Builder/BuilderCursor.png");
		}
		else
		{
			getHUD().SetCursorImage("Entities/Characters/Chopper/ChopperCursor.png", Vec2f(32, 32));
			getHUD().SetCursorOffset(Vec2f(-11, -11) * cl_mouse_scale);
		}

	}
}

void onRender(CSprite@ this)
{
	CBlob@ blob = this.getBlob();

	if (g_videorecording)
		return;

	CPlayer@ player = blob.getPlayer();

	// draw inventory

	Vec2f tl = getActorHUDStartPosition(blob, slotsSize);
	DrawInventoryOnHUD(blob, tl);

	// draw coins

	const int coins = player !is null ? player.getCoins() : 0;
	DrawCoinsOnHUD(blob, coins, tl, slotsSize - 2);

	// draw class icon

	ChopperInfo@ chopper;
	if (!blob.get("chopperInfo", @chopper))
	{
		return;
	}
	ManageCursors(blob, blob.get_u8("tool_type") == ToolType::mattock);
	GUI::DrawIcon(iconsFilename, blob.get_u8("tool_type"), Vec2f(16, 32), tl + Vec2f(8 + (slotsSize - 1) * 40, -13), 1.0f);
}
