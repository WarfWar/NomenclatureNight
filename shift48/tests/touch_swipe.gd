extends SceneTree
## Synthetic Android-like finger gesture test (not a real hardware swipe).
func assert_ok(ok: bool, description: String) -> bool:
    if not ok:
        push_error("SWIPE TEST FAILED: "+description)
        quit(1)
        return false
    return true
func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var packed: PackedScene=load("res://scenes/Main.tscn")
    if not assert_ok(packed!=null,"main scene exists"):
        return
    var app: Control=packed.instantiate()
    root.add_child(app)
    await process_frame
    app._navigate("districts")
    await process_frame
    await process_frame
    var scroll: ScrollContainer=app.page_scroll
    if not assert_ok(is_instance_valid(scroll),"scroll viewport exists"):
        return
    var scrollbar: VScrollBar=scroll.get_v_scroll_bar()
    if not assert_ok(scrollbar.max_value-scrollbar.page>90,"districts content overflows"):
        return
    var rect: Rect2=scroll.get_global_rect()
    var center: Vector2=rect.position+Vector2(rect.size.x*0.50,rect.size.y*0.80)
    var initial_page: String=app.page
    var touch:=InputEventScreenTouch.new()
    touch.pressed=true
    touch.index=0
    touch.position=center
    Input.parse_input_event(touch)
    await process_frame
    print("SWIPE DEBUG rect=",rect," center=",center," index=",app.touch_index," inside=",app.pointer_in_scroll," scroll=",scroll.scroll_vertical)
    var point: Vector2=center
    for i in range(9):
        var drag:=InputEventScreenDrag.new()
        drag.index=0
        drag.relative=Vector2(0,-26)
        point+=drag.relative
        drag.position=point
        Input.parse_input_event(drag)
        await process_frame
    print("SWIPE DEBUG counter=",app.touch_scroll_events," index=",app.touch_index," scroll=",scroll.scroll_vertical)
    var release:=InputEventScreenTouch.new()
    release.index=0
    release.pressed=false
    release.position=point
    Input.parse_input_event(release)
    await process_frame
    if not assert_ok(app.touch_scroll_events>0,"real touch drag events were handled"):
        return
    if not assert_ok(app.page_scroll.scroll_vertical>80,"touch gesture scrolled the content"):
        return
    if not assert_ok(app.page==initial_page,"drag didn't activate a navigation card"):
        return
    var first_position: int=app.page_scroll.scroll_vertical
    app._draw_screen(true)
    await process_frame
    await process_frame
    if not assert_ok(app.page_scroll.scroll_vertical>=first_position-12,"scroll persists on re-render"):
        return
    app._scroll_step(-1)
    await process_frame
    if not assert_ok(app.page_scroll.scroll_vertical<first_position,"arrow scroll can move up"):
        return
    print("PASS: finger gesture, no accidental navigation, persistent scroll and fallback buttons")
    quit(0)
