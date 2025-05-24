// BuilderCommon.as

namespace Action
{
	enum type
	{
		nothing = 0,
		throw,
		ladder,
		count
	};
}

shared class RockthrowerInfo
{
	u8 action;
	u16 boulderTimer;
	u8 throwTimer;

	RockthrowerInfo()
	{
		action = Action::nothing;
		boulderTimer = 0;
		throwTimer = 0;
	}
};

void SetActionType(CBlob@ this, const u8 type)
{
	RockthrowerInfo@ rockthrower;
	if (!this.get("rockthorwerInfo", @rockthrower))
	{
		return;
	}
	rockthrower.action = type;
}

u8 getActionType(CBlob@ this)
{
	RockthrowerInfo@ rockthrower;
	if (!this.get("rockthrowerInfo", @rockthrower))
	{
		return 0;
	}
	return rockthrower.action;
}

// for animation
bool isShootTime(CBlob@ this)
{
	RockthrowerInfo@ rockthrower;
	if (!this.get("rockthrowerInfo", @rockthrower))
	{
		return false;
	}
	return rockthrower.action == Action::throw;
}

bool isBuildTime(CBlob@ this)
{
	RockthrowerInfo@ rockthrower;
	if (!this.get("rockthrowerInfo", @rockthrower))
	{
		return false;
	}
	return rockthrower.action == Action::ladder;
}

bool hasStones(CBlob@ this)
{
	return this.getBlobCount("mat_stone") > 0;
}

bool hasBoulderStones(CBlob@ this)
{
	return this.getBlobCount("mat_stone") >= 35;
}
