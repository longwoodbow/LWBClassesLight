#define SERVER_ONLY

#include "CratePickupCommon.as"

void onInit(CBlob@ this)
{
	this.getCurrentScript().removeIfTag = "dead";
}

void onCollision(CBlob@ this, CBlob@ blob, bool solid)
{
	if (blob is null || blob.getShape().vellen > 1.0f)
	{
		return;
	}

	string blobName = blob.getName();

	if (blobName == "mat_firelances")
	{
		u32 lances_count = this.getBlobCount("mat_firelances");
		u32 blob_quantity = blob.getQuantity();
		if (lances_count + blob_quantity <= 10)
		{
			this.server_PutInInventory(blob);
		}
		else if (lances_count < 10) //merge into current lance stacks
		{
			this.getSprite().PlaySound("/PutInInventory.ogg");

			u32 pickup_amount = Maths::Min(blob_quantity, 10 - lances_count);
			if (blob_quantity - pickup_amount > 0)
				blob.server_SetQuantity(blob_quantity - pickup_amount);
			else
				blob.server_Die();

			CInventory@ inv = this.getInventory();
			for (int i = 0; i < inv.getItemsCount() && pickup_amount > 0; i++)
			{
				CBlob@ lances = inv.getItem(i);
				if (lances !is null && lances.getName() == blobName)
				{
					u32 lance_amount = lances.getQuantity();
					u32 lance_maximum = lances.getMaxQuantity();
					if (lance_amount + pickup_amount < lance_maximum)
					{
						lances.server_SetQuantity(lance_amount + pickup_amount);
					}
					else
					{
						pickup_amount -= lance_maximum - lance_amount;
						lances.server_SetQuantity(lance_maximum);
					}
				}
			}
		}
	}
	if (blobName == "mat_flamethrowers")
	{
		if (this.server_PutInInventory(blob))
		{
			return;
		}
	}

	CBlob@ carryblob = this.getCarriedBlob(); // For crate detection
	if (carryblob !is null && carryblob.getName() == "crate")
	{
		if (crateTake(carryblob, blob))
		{
			return;
		}
	}
}
