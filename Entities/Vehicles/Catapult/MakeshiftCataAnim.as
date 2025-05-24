void onInit(CSprite@ this)
{
	ReloadSprites(this);
}

void ReloadSprites(CSprite@ sprite)
{
	string filename = sprite.getFilename();

	sprite.SetZ(-25.0f);
	sprite.ReloadSprite(filename);

	sprite.RemoveSpriteLayer("arm");
	CSpriteLayer@ arm = sprite.addSpriteLayer("arm", filename, 16, 32);

	if (arm !is null)
	{
		Animation@ anim = arm.addAnimation("default", 0, false);
		anim.AddFrame(2);
		anim.AddFrame(3);
		arm.ResetTransform();
		arm.SetOffset(Vec2f(-0.0f, -16.0f));
		arm.SetRelativeZ(-10.5f);
		//rotation handled by update
	}
}
