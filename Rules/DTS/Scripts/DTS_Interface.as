#include "DTS_Structs.as";
#include "TeamColour.as";

/*
void onTick( CRules@ this )
{
    //see the logic script for this
}
*/

void onInit(CRules@ this)
{
    onRestart(this);
}

void onRestart( CRules@ this )
{
    DTSUIData ui;

    CBlob@[] statue;
    if(getBlobsByName("statue", statue))
    {
        for(int i = 0; i < statue.size(); i++)
        {
            CBlob@ blob = statue[i];

            ui.statueIds.push_back(blob.getNetworkID());
            ui.statueTeams.push_back(blob.getTeamNum());
            ui.statueHealth.push_back(blob.getHealth());
            ui.addTeam(blob.getTeamNum());
        }

    }

    this.set("uidata", @ui);

    CBitStream bt = ui.serialize();

	this.set_CBitStream("dts_serialised_team_hud", bt);
	this.Sync("dts_serialised_team_hud", true);

	//set for all clients to ensure safe sync
	this.set_s16("stalemate_breaker", 0);

}

//only for after the fact if you spawn a flag
void onBlobCreated( CRules@ this, CBlob@ blob )
{
    if(!getNet().isServer())
        return;

    if(blob.getName() == "statue")
    {
        DTSUIData@ ui;
        this.get("uidata", @ui);

        if(ui is null) return;

        ui.statueIds.push_back(blob.getNetworkID());
        ui.statueTeams.push_back(blob.getTeamNum());
        ui.statueHealth.push_back(blob.getInitialHealth());
        ui.addTeam(blob.getTeamNum());

        CBitStream bt = ui.serialize();

		this.set_CBitStream("dts_serialised_team_hud", bt);
		this.Sync("dts_serialised_team_hud", true);

    }

}
/* scale will be 0 why
f32 onBlobTakeDamage( CRules@ this, CBlob@ victim , CBlob@ attacker, f32 DamageScale)// statue hit
{
    if(!getNet().isServer())
        return DamageScale;

    if(victim.getName() == "statue")
    {
        DTSUIData@ ui;
        this.get("uidata", @ui);

        if(ui is null) return DamageScale;

        int id = victim.getNetworkID();

        for(int i = 0; i < ui.statueIds.size(); i++)
        {
            if(ui.statueIds[i] == id)
            {
                ui.statueHealth[i] = Maths::Max(victim.getHealth(), 0.0f);
            }
        }

        CBitStream bt = ui.serialize();

		this.set_CBitStream("dts_serialised_team_hud", bt);
		this.Sync("dts_serialised_team_hud", true);
    }

    return DamageScale;
}*/

void onBlobDie( CRules@ this, CBlob@ blob )
{
    if(!getNet().isServer())
        return;

    if(blob.getName() == "statue")
    {
        DTSUIData@ ui;
        this.get("uidata", @ui);

        if(ui is null) return;

        int id = blob.getNetworkID();

        for(int i = 0; i < ui.statueIds.size(); i++)
        {
            if(ui.statueIds[i] == id)
            {
                ui.statueHealth[i] = 0.0f;

            }

        }

        CBitStream bt = ui.serialize();

		this.set_CBitStream("dts_serialised_team_hud", bt);
		this.Sync("dts_serialised_team_hud", true);

    }

}

void onRender(CRules@ this)
{
	if (g_videorecording)
		return;

	CPlayer@ p = getLocalPlayer();

	if (p is null || !p.isMyPlayer()) { return; }

	GUI::SetFont("hud");
	
	CBitStream serialised_team_hud;
	this.get_CBitStream("dts_serialised_team_hud", serialised_team_hud);

	if (serialised_team_hud.getBytesUsed() > 8)
	{
		serialised_team_hud.Reset();
		u16 check;

		if (serialised_team_hud.saferead_u16(check) && check == 0x5afe)
		{
			while (!serialised_team_hud.isBufferEnd())
			{
				DTS_HUD hud(serialised_team_hud);
				int team = hud.team_num;

				GUI::DrawText(hud.statueHealth, Vec2f(0, 10 * team), getTeamColor(team));
			}
		}

		serialised_team_hud.Reset();
	}
	
	string propname = "dts spawn time " + p.getUsername();
	if (p.getBlob() is null && this.exists(propname))
	{
		u8 spawn = this.get_u8(propname);

		if (spawn != 255)
		{
			if (spawn == 254)
			{
				GUI::DrawText(getTranslatedString("In Queue to Respawn...") , Vec2f(getScreenWidth() / 2 - 70, getScreenHeight() / 3 + Maths::Sin(getGameTime() / 3.0f) * 5.0f), SColor(255, 255, 255, 55));
			}
			else
			{
				GUI::DrawText(getTranslatedString("Respawning in: {SEC}").replace("{SEC}", "" + spawn), Vec2f(getScreenWidth() / 2 - 70, getScreenHeight() / 3 + Maths::Sin(getGameTime() / 3.0f) * 5.0f), SColor(255, 255, 255, 55));
			}
		}
	}
}

void onNewPlayerJoin( CRules@ this, CPlayer@ player )
{
	this.SyncToPlayer("dts_serialised_team_hud", player);
}