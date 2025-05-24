
void onInit(CBlob@ this)
{
  if (getNet().isServer())
  {
    this.set_u16('decay time', 180);
  }

  this.maxQuantity = 2;

  this.getCurrentScript().runFlags |= Script::remove_after_this;
  
  this.set_f32("important-pickup", 30.0f);
}
