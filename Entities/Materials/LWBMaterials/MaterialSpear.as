#include "ArrowCommon.as"

void onInit(CBlob@ this)
{
  if (getNet().isServer())
  {
    this.set_u16('decay time', 45);
  }

  this.maxQuantity = 10;

  this.getCurrentScript().runFlags |= Script::remove_after_this;

  setArrowHoverRect(this);
}
