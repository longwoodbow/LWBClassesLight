void onInit(CBlob@ this)
{
  if (getNet().isServer())
  {
    // ballista bolts dont have this value
    //this.set_u16('decay time', 45);
  }

  this.maxQuantity = 3;

  this.getCurrentScript().runFlags |= Script::remove_after_this;
}
