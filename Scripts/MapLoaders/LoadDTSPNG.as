// TDM PNG loader base class - extend this to add your own PNG loading functionality!

#include "BasePNGLoader.as";
#include "MinimapHook.as";

// TDM custom map colors
namespace dts_colors
{
	enum color
	{
		tradingpost_1 = 0xFF8888FF,
		tradingpost_2 = 0xFFFF8888,
		tradingpost_3 = 0xFF505050,
		statue_1 = 0xFF0011FF,
		statue_2 = 0xFFFF1100,
		healspot_1 = 0xFF0011F0,
		healspot_2 = 0xFFF01100,
		healspot_3 = 0xFF222222
	};
}

//the loader

class DTSPNGLoader : PNGLoader
{
	DTSPNGLoader()
	{
		super();
	}

	//override this to extend functionality per-pixel.
	void handlePixel(const SColor &in pixel, int offset) override
	{
		PNGLoader::handlePixel(pixel, offset);

		switch (pixel.color)
		{
		case dts_colors::tradingpost_1: autotile(offset); spawnBlob(map, "tradingpost", offset, 0); break;
		case dts_colors::tradingpost_2: autotile(offset); spawnBlob(map, "tradingpost", offset, 1); break;
		case dts_colors::tradingpost_3: autotile(offset); spawnBlob(map, "tradingpost", offset, 255); break;
		case dts_colors::statue_1: autotile(offset); spawnBlob(map, "statue", offset, 0); break;
		case dts_colors::statue_2: autotile(offset); spawnBlob(map, "statue", offset, 1).SetFacingLeft(true); break;
		case dts_colors::healspot_1: autotile(offset); spawnBlob(map, "healspot", offset, 0); break;
		case dts_colors::healspot_2: autotile(offset); spawnBlob(map, "healspot", offset, 1); break;
		case dts_colors::healspot_3: autotile(offset); spawnBlob(map, "healspot", offset, 255); break;
		};
	}
};

// --------------------------------------------------

bool LoadMap(CMap@ map, const string& in fileName)
{
	print("LOADING DTS PNG MAP " + fileName);

	DTSPNGLoader loader();

	MiniMap::Initialise();

	return loader.loadMap(map , fileName);
}
