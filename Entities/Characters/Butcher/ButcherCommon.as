//Butcher Include
//...need?

shared class ButcherInfo
{
	//bool has_meat;
	u8 tileDestructionLimiter;
	u32 knife_timer;
	u32 throw_timer;

	ButcherInfo()
	{
		//has_meat = false;
		tileDestructionLimiter = 0;
		knife_timer = 0;
		throw_timer = 0;
	}
};