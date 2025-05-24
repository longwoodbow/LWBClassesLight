// spawn resources
// added data for new classes
const u32 materials_wait = 20; //seconds between free mats
const u32 materials_wait_warmup = 40; //seconds between free mats

const int warmup_wood_amount = 250;
const int warmup_stone_amount = 80;

const int matchtime_wood_amount = 100;
const int matchtime_stone_amount = 30;

//property
const string SPAWN_ITEMS_TIMER_BUILDER       = "CTF SpawnItems Builder and More:";//Rockthrower, Warcrafter, Demolitonist and Chopper
const string SPAWN_ITEMS_TIMER_ARCHER        = "CTF SpawnItems Archer and Crossbowman:";
const string SPAWN_ITEMS_TIMER_MEDIC         = "CTF SpawnItems Medic:";
const string SPAWN_ITEMS_TIMER_SPEARMAN      = "CTF SpawnItems Spearman:";
const string SPAWN_ITEMS_TIMER_MUSKETMAN     = "CTF SpawnItems Musketman and Gunner:";
const string SPAWN_ITEMS_TIMER_WEAPONTHROWER = "CTF SpawnItems Weaponthrower:";
const string SPAWN_ITEMS_TIMER_FIRELANCER    = "CTF SpawnItems Firelancer:";

string base_name() { return "tent"; }

//resupply timers
string getCTFTimerPropertyName(CPlayer@ p, string classname)
{
	if (classname == "archer")
	{
		return SPAWN_ITEMS_TIMER_ARCHER + p.getUsername();
	}
	else if (classname == "medic")
	{
		return SPAWN_ITEMS_TIMER_MEDIC + p.getUsername();
	}
	else if (classname == "spearman")
	{
		return SPAWN_ITEMS_TIMER_SPEARMAN + p.getUsername();
	}
	else if (classname == "musketman")
	{
		return SPAWN_ITEMS_TIMER_MUSKETMAN + p.getUsername();
	}
	else if (classname == "weaponthrower")
	{
		return SPAWN_ITEMS_TIMER_WEAPONTHROWER + p.getUsername();
	}
	else if (classname == "firelancer")
	{
		return SPAWN_ITEMS_TIMER_FIRELANCER + p.getUsername();
	}
	else// builder, rockthrower, warcrafter, demolitionist and chopper, or others? i don't wish
	{
		return SPAWN_ITEMS_TIMER_BUILDER + p.getUsername();
	} 
}

s32 getCTFTimer(CRules@ this, CPlayer@ p, string classname)
{
	string property = getCTFTimerPropertyName(p, classname);
	if (this.exists(property))
		return this.get_s32(property);
	else
		return 0;
}

void SetCTFTimer(CRules@ this, CPlayer@ p, s32 time, string classname)
{
	string property = getCTFTimerPropertyName(p, classname);
	this.set_s32(property, time);
	this.SyncToPlayer(property, p);
}