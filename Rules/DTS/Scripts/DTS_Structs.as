// management structs

#include "Rules/CommonScripts/BaseTeamInfo.as";
#include "Rules/CommonScripts/PlayerInfo.as";

shared class DTSUIData
{
    DTSUIData(){}
  
    int[] teams;
    int[] statueTeams;
    int[] statueIds;
    float[] statueHealth;

    void addTeam(int team)
    {
        for(int i = 0; i < teams.size(); i++)
        {
            if(teams[i] == team)
            {
                return;
            }

        }

        teams.push_back(team);

    }

    CBitStream serialize()
    {
		CBitStream bt;
		bt.write_u16(0x5afe); //check bits

        for(int i = 0; i < teams.size(); i++)
        {
            bt.write_u8(teams[i]);
            string stuff = teams[i] == 0 ? "Blue Team : " : teams[i] == 1 ? "Red Team : " : "Unknown : ";
            bool firstStatue = false;
            for(int j = 0; j < statueTeams.size(); j++)
            {
                if(statueTeams[j] == teams[i])
                {
                    stuff += (firstStatue ? " / " : "") + statueHealth[j];
                    firstStatue = true;
                }

            }
            bt.write_string(stuff);
        }
        return bt;

    }
    
};

shared class DTSPlayerInfo : PlayerInfo
{
	u32 can_spawn_time;
	bool thrownBomb;

	DTSPlayerInfo() { Setup("", 0, ""); }
	DTSPlayerInfo(string _name, u8 _team, string _default_config) { Setup(_name, _team, _default_config); }

	void Setup(string _name, u8 _team, string _default_config)
	{
		PlayerInfo::Setup(_name, _team, _default_config);
		can_spawn_time = 0;
		thrownBomb = false;
	}
};

//teams

shared class DTSTeamInfo : BaseTeamInfo
{
	PlayerInfo@[] spawns;

	DTSTeamInfo() { super(); }

	DTSTeamInfo(u8 _index, string _name)
	{
		super(_index, _name);
	}

	void Reset()
	{
		BaseTeamInfo::Reset();
		//spawns.clear();
	}
};

//how each team is serialised
// almost as same as CTF
shared class DTS_HUD
{
	//is this our team?
	u8 team_num;
	//u8 spawn_time;
    string statueHealth;

	DTS_HUD() { }
	DTS_HUD(CBitStream@ bt) { Unserialise(bt); }

	/*void Serialise(CBitStream@ bt)
	{
		bt.write_u8(team_num);
		//bt.write_u8(spawn_time);
	}*/

	void Unserialise(CBitStream@ bt)
	{
		team_num = bt.read_u8();
		statueHealth = bt.read_string();
	}

};
