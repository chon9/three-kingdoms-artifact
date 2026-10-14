extends SceneTree
## Run with a real rendering driver. Captures only this game's viewport.
const MainScene = preload("res://scenes/main.tscn")

func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	root.size = Vector2i(1440, 900)
	var app = MainScene.instantiate()
	root.add_child(app)
	app.bot_timer.stop()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var screenshot = root.get_texture().get_image()
	var result = screenshot.save_png("res://.tools/preview.png")
	print("Preview PNG: ", error_string(result))
	if "--decks" in OS.get_cmdline_user_args():
		app._open_decks()
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.tools/decks_preview.png")
	if "--patches" in OS.get_cmdline_user_args():
		app._inspect("axe")
		app._open_card_preview()
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.tools/patched_axe_preview.png")
	app.queue_free()
	await process_frame
	quit(0 if result == OK else 1)
