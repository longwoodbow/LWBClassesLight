// OneClassAvailable.as
// add scripts for genuine shops.

#include "StandardRespawnCommand.as";
#include "GenericButtonCommon.as";
#include "ClassesConfig.as"

const string req_class = "required class";

void onInit(CBlob@ this)
{
	this.Tag("change class drop inventory");
	if (!this.exists("class offset"))
		this.set_Vec2f("class offset", Vec2f_zero);

	if (!this.exists("class button radius"))
	{
		CShape@ shape = this.getShape();
		f32 ts = getMap().tilesize;
		if (shape !is null)
		{
			this.set_u8("class button radius", Maths::Max(this.getRadius(), Maths::Max(shape.getWidth(), shape.getHeight()) + ts));
		}
		else
		{
			this.set_u8("class button radius", ts * 2);
		}
	}
	this.addCommandID("change class");
}

void GetButtonsFor(CBlob@ this, CBlob@ caller)
{
	if (!canSeeButtons(this, caller) || (!this.exists(req_class) && !this.hasTag("multi classes"))) return;

	string cfg = this.get_string(req_class);
	if (canChangeClass(this, caller) && this.hasTag("multi classes"))
	{
		PlayerClass[]@ classes;
		if (!this.get("playerclasses", @classes) || classes.length() <= 0)
		{
			return;
		}

		CButton@ button = caller.CreateGenericButton(
		"$change_class$",                           // icon token
		this.get_Vec2f("class offset"),             // button offset
		this,                                       // button attachment
		buildSpawnMenu,                      // command id
		getTranslatedString("Swap Class"));                               // description
	}
	else if (canChangeClass(this, caller) && caller.getName() != cfg)// default, if this is other mod shop...
	{
		CBitStream params;
		params.write_u8(0);

		CButton@ button = caller.CreateGenericButton(
		"$change_class$",                           // icon token
		this.get_Vec2f("class offset"),             // button offset
		this,                                       // button attachment
		this.getCommandID("change class"),           // command id
		getTranslatedString("Swap Class"),           // description
		params);                                    // bit stream

		button.enableRadius = this.get_u8("class button radius");
	}
}

void onCommand(CBlob@ this, u8 cmd, CBitStream @params)
{
	onRespawnCommand(this, cmd, params);
}