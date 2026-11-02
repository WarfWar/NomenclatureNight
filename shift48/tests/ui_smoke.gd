extends SceneTree
## Headless test for mobile screen navigation and scroll persistence.
func fail_if(condition: bool, description: String) -> bool:
    if condition:
        push_error("UI TEST FAILED: "+description)
        quit(1)
        return true
    return false

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var scene: PackedScene=load("res://scenes/Main.tscn")
    if fail_if(scene==null,"main scene missing"):
        return
    var game: Control=scene.instantiate()
    root.add_child(game)
    await process_frame
    if fail_if(not is_instance_valid(game.page_scroll),"scroll container missing"):
        return
    for page_name in ["home","districts","operations","hq","storage","market","buildings","research","team","journal"]:
        game._navigate(page_name)
        await process_frame
        if fail_if(game.page!=page_name,"navigation: "+page_name):
            return
        if fail_if(not is_instance_valid(game.page_scroll),"scroll missing on "+page_name):
            return
        if fail_if(game.page_scroll.horizontal_scroll_mode!=ScrollContainer.SCROLL_MODE_DISABLED,"horizontal scroll enabled"):
            return

    game._navigate("districts")
    await process_frame
    await process_frame
    var scroll: ScrollContainer=game.page_scroll
    var bar: VScrollBar=scroll.get_v_scroll_bar()
    var limit: int=int(bar.max_value-bar.page)
    if fail_if(limit < 55,"district list not scrollable on phone viewport"):
        return
    scroll.scroll_vertical=mini(130,limit)
    await process_frame
    var expected: int=scroll.scroll_vertical
    game._draw_screen(true)
    await process_frame
    await process_frame
    if fail_if(game.page_scroll.scroll_vertical<expected-10,"scroll jumped to top after screen redraw"):
        return
    # New pages should start at their own position, not inherit another list's offset.
    game._navigate("hq")
    await process_frame
    if fail_if(game.page_scroll.scroll_vertical>5,"scroll leaked from districts to HQ"):
        return
    game._detail("market")
    await process_frame
    game._back()
    await process_frame
    if fail_if(game.page!="hq","back navigation from market"):
        return
    print("PASS: separated screens, independent scrolling and UI navigation")
    quit(0)
