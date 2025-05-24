// now max quantity is 250 in TTH.
void onInit(CBlob@ this)
{
  if (isServer())
  {
	this.set_u8("decay step", 10);
  }

  if (getRules().gamemode_name == "Sandbox")
  {
  	this.Tag("AdminAlertIgnore");
  }
  
  if (getRules().gamemode_name == "TTH") this.maxQuantity = 250;
  else this.maxQuantity = 50;

  this.getCurrentScript().runFlags |= Script::remove_after_this;
}
