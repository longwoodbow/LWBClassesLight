namespace ClassesConfig
{
	//set false to disable classes.
	//in TDM and DTS, builder, warcrafter, demolitionist and chopper aren't allowed even they're true.

	//support
	const bool builder = true;
	const bool rockthrower = true;
	const bool medic = true;
	const bool warcrafter = true;
	const bool butcher = true;
	const bool demolitionist = true;

	//melee
	const bool knight = true;
	const bool spearman = true;
	const bool assassin = true;
	const bool chopper = true;
	const bool warhammer = true;
	const bool duelist = true;

	//ranged
	const bool archer = true;
	const bool crossbowman = true;
	const bool musketman = true;
	const bool weaponthrower = true;
	const bool firelancer = true;
	const bool gunner = true;
}

shared string randomClass(bool allowBuilder)
{
	string[] classes;
	if(ClassesConfig::builder && allowBuilder)
	{
		classes.push_back("builder");
	}
	if(ClassesConfig::rockthrower)
	{
		classes.push_back("rockthrower");
	}
	if(ClassesConfig::medic)
	{
		classes.push_back("medic");
	}
	if(ClassesConfig::warcrafter && allowBuilder)
	{
		classes.push_back("warcrafter");
	}
	if(ClassesConfig::butcher)
	{
		classes.push_back("butcher");
	}
	if(ClassesConfig::demolitionist && allowBuilder)
	{
		classes.push_back("demolitionist");
	}
	if(ClassesConfig::knight)
	{
		classes.push_back("knight");
	}
	if(ClassesConfig::spearman)
	{
		classes.push_back("spearman");
	}
	if(ClassesConfig::assassin)
	{
		classes.push_back("assassin");
	}
	if(ClassesConfig::chopper && allowBuilder)
	{
		classes.push_back("chopper");
	}
	if(ClassesConfig::warhammer)
	{
		classes.push_back("warhammer");
	}
	if(ClassesConfig::duelist)
	{
		classes.push_back("duelist");
	}
	if(ClassesConfig::archer)
	{
		classes.push_back("archer");
	}
	if(ClassesConfig::crossbowman)
	{
		classes.push_back("crossbowman");
	}
	if(ClassesConfig::musketman)
	{
		classes.push_back("musketman");
	}
	if(ClassesConfig::weaponthrower)
	{
		classes.push_back("weaponthrower");
	}
	if(ClassesConfig::firelancer)
	{
		classes.push_back("firelancer");
	}
	if(ClassesConfig::gunner)
	{
		classes.push_back("gunner");
	}

	if(classes.length > 0)
		return classes[XORRandom(classes.length)];
	else
	{
		if(!ClassesConfig::builder)
			warn("No class is allowed: See ClassesConfig.as");
		return "builder";
	}
}