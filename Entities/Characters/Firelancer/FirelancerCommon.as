//Firelancer Include

namespace FirelancerParams
{
	enum Aim
	{
		not_aiming = 0,
		igniting,
		ignited,
		firing,
		stick,
		no_lances
	}
	
	const ::s32 ready_time = 11;

	const ::s32 ignite_period = 60;
	const ::s32 shoot_period = 30;
}

namespace LanceType
{
	enum type
	{
		normal = 0,
		fire,
		count
	};
}

shared class FirelancerInfo
{
	s8 charge_time;
	u8 charge_state;
	bool has_lance;
	u8 lance_type;
	
	u8 stick_timer;
	u8 tileDestructionLimiter;

	FirelancerInfo()
	{
		charge_time = 0;
		charge_state = 0;
		has_lance = false;
		lance_type = LanceType::normal;
		stick_timer = 0;
	}
};

void ClientSendLanceState(CBlob@ this)
{
	if (!isClient()) { return; }
	if (isServer()) { return; } // no need to sync on localhost

	FirelancerInfo@ firelancer;
	if (!this.get("firelancerInfo", @firelancer)) { return; }

	CBitStream params;
	params.write_u8(firelancer.lance_type);

	this.SendCommand(this.getCommandID("lance sync"), params);
}

bool ReceiveLanceState(CBlob@ this, CBitStream@ params)
{
	// valid both on client and server

	if (isServer() && isClient()) { return false; }

	FirelancerInfo@ firelancer;
	if (!this.get("firelancerInfo", @firelancer)) { return false; }

	firelancer.lance_type = 0;
	if (!params.saferead_u8(firelancer.lance_type)) { return false; }

	if (isServer())
	{
		CBitStream reserialized;
		reserialized.write_u8(firelancer.lance_type);

		this.SendCommand(this.getCommandID("lance sync client"), reserialized);
	}

	return true;
}


const string[] lanceTypeNames = { "mat_firelances",
                                  "mat_flamethrowers"
                                };

const string[] lanceNames = { "Firelances",
                              "Flamethrower"
                            };

const string[] lanceIcons = { "$Firelance$",
                              "$Flamethrower$"
                            };

const string[] lanceShootBlob = { "firelancefrag",
                       		      "thrownflame"
                       		    };

const u8[] lanceShootVolley = { 3,
                       		    5
                       		  };

const u8[] lanceShootDeviation = { 4,
                       		       3
                       		     };

const f32[] lanceShootVelocity = { 35.18f,//arrow x1.5
                       		       15.0f//x0.75
                       		     };

bool hasLances(CBlob@ this)
{
	FirelancerInfo@ firelancer;
	if (!this.get("firelancerInfo", @firelancer))
	{
		return false;
	}
	if (firelancer.lance_type >= 0 && firelancer.lance_type < lanceTypeNames.length)
	{
		return this.getBlobCount(lanceTypeNames[firelancer.lance_type]) > 0;
	}
	return false;
}

bool hasLances(CBlob@ this, u8 lanceType)
{
	if (this is null) return false;
	
	return lanceType < lanceTypeNames.length && this.hasBlob(lanceTypeNames[lanceType], 1);
}

bool hasAnyLances(CBlob@ this)
{
	for (uint i = 0; i < LanceType::count; i++)
	{
		if (hasLances(this, i))
		{
			return true;
		}
	}
	return false;
}

void SetLanceType(CBlob@ this, const u8 type)
{
	FirelancerInfo@ firelancer;
	if (!this.get("firelancerInfo", @firelancer))
	{
		return;
	}
	firelancer.lance_type = type;
}

u8 getLanceType(CBlob@ this)
{
	FirelancerInfo@ firelancer;
	if (!this.get("firelancerInfo", @firelancer))
	{
		return 0;
	}
	return firelancer.lance_type;
}
