//musketman HUD

#include "ActorHUDStartPos.as";
#include "MusketmanCommon.as";

const string iconsFilename = "Entities/Characters/Musketman/MusketmanIcons.png";
const int slotsSize = 6;

void onInit(CSprite@ this)
{
	this.getCurrentScript().runFlags |= Script::tick_myplayer;
	this.getCurrentScript().removeIfTag = "dead";
	this.getBlob().set_u8("gui_HUD_slots_width", slotsSize);
}

void ManageCursors(CBlob@ this)
{
	// set cursor
	if (getHUD().hasButtons())
	{
		getHUD().SetDefaultCursor();
	}
	else
	{
		// set cursor
		getHUD().SetCursorImage("Entities/Characters/Archer/ArcherCursor.png", Vec2f(32, 32));
		getHUD().SetCursorOffset(Vec2f(-16, -16) * cl_mouse_scale);
		// frame set in logic
	}
}

void onRender(CSprite@ this)
{
	CBlob@ blob = this.getBlob();
	ManageCursors(blob);

	if (g_videorecording)
		return;

	CPlayer@ player = blob.getPlayer();

	// draw inventory
	Vec2f tl = getActorHUDStartPosition(blob, slotsSize);
	DrawInventoryOnHUD(blob, tl);
	// draw coins
	const int coins = player !is null ? player.getCoins() : 0;
	DrawCoinsOnHUD(blob, coins, tl, slotsSize - 2);

	u8 type = getBuildMode(blob);
	if (type > 0) type++;

	// class weapon icon
	GUI::DrawIcon(iconsFilename, type, Vec2f(16, 32), tl + Vec2f(8 + (slotsSize - 1) * 40, -16), 1.0f);
}
