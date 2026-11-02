extends Control
## Shift 48 v0.2 — compact mobile UI, one scroll per screen, stable scroll position.

const BG := Color("#0B121D")
const SURFACE := Color("#172634")
const SURFACE_2 := Color("#203542")
const OUTLINE := Color("#314956")
const INK := Color("#F0F3EF")
const MUTED := Color("#9BAEB9")
const AQUA := Color("#74DBCB")
const GOLD := Color("#E3BE80")
const DANGER := Color("#EE9194")

var sim: ShiftGame = ShiftGame.new()
var page: String = "home"
var shell: MarginContainer
var page_scroll: ScrollContainer
var scroll_positions: Dictionary = {}
var return_page: String = "home"
var reset_overlay: ColorRect
# Finger-drag state, independent of Godot's built-in ScrollContainer behavior.
var touch_index: int = -1
var touch_origin: Vector2 = Vector2.ZERO
var touch_previous: Vector2 = Vector2.ZERO
var gesture_was_scroll: bool = false
var pointer_in_scroll: bool = false
var touch_scroll_events: int = 0

func _ready() -> void:
    var backdrop := ColorRect.new()
    backdrop.color=BG
    backdrop.mouse_filter=Control.MOUSE_FILTER_IGNORE
    backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(backdrop)
    if not sim.load_game():
        sim.reset()
    _draw_screen(false)

func _style(fill: Color, edge: Color = OUTLINE, radius: int = 14) -> StyleBoxFlat:
    var s := StyleBoxFlat.new()
    s.bg_color = fill
    s.border_color = edge
    s.set_border_width_all(1)
    s.set_corner_radius_all(radius)
    s.content_margin_left = 15
    s.content_margin_right = 15
    s.content_margin_top = 13
    s.content_margin_bottom = 13
    return s

func _text(parent: Node, value: String, font: int = 22, tone: Color = INK) -> Label:
    var t := Label.new()
    t.text = value
    t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    t.add_theme_font_size_override("font_size",font)
    t.add_theme_color_override("font_color",tone)
    parent.add_child(t)
    return t

func _row(parent: Node, gap: int = 9) -> HBoxContainer:
    var r := HBoxContainer.new()
    r.add_theme_constant_override("separation",gap)
    parent.add_child(r)
    return r

func _column(parent: Node, gap: int = 10) -> VBoxContainer:
    var c := VBoxContainer.new()
    c.add_theme_constant_override("separation",gap)
    parent.add_child(c)
    return c

func _panel(parent: Node, alternate: bool = false, accent: bool = false) -> VBoxContainer:
    var p := PanelContainer.new()
    p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    p.add_theme_stylebox_override("panel",_style(SURFACE_2 if alternate else SURFACE,AQUA if accent else OUTLINE,16))
    parent.add_child(p)
    return _column(p,8)

func _button(parent: Node, value: String, action: Callable, primary: bool=false, inactive: bool=false, h: int=64) -> Button:
    var b := Button.new()
    b.text=value
    b.custom_minimum_size.y=h
    b.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    b.add_theme_font_size_override("font_size",19)
    b.add_theme_color_override("font_color",INK)
    b.add_theme_color_override("font_hover_color",INK)
    b.add_theme_stylebox_override("normal",_style(Color("#28525C") if primary else SURFACE_2,AQUA if primary else OUTLINE,12))
    b.add_theme_stylebox_override("hover",_style(Color("#356570"),AQUA,12))
    b.add_theme_stylebox_override("pressed",_style(Color("#38757C"),AQUA,12))
    b.add_theme_stylebox_override("disabled",_style(Color("#15212C"),Color("#273744"),12))
    b.add_theme_color_override("font_disabled_color",MUTED)
    b.disabled=inactive
    b.mouse_filter=Control.MOUSE_FILTER_PASS
    b.focus_mode=Control.FOCUS_NONE
    b.pressed.connect(_button_guard.bind(action))
    parent.add_child(b)
    return b

func _button_guard(action: Callable) -> void:
    # Do not activate a card if the finger was dragging the list.
    if gesture_was_scroll:
        return
    if action.is_valid():
        action.call()

func _input(event: InputEvent) -> void:
    # Godot's native touch-to-scroll may behave differently from a desktop
    # wheel. Route Android touchscreen drags directly into the current list.
    if event is InputEventScreenTouch:
        var finger: InputEventScreenTouch=event
        if finger.pressed:
            gesture_was_scroll=false
            touch_index=-1
            pointer_in_scroll=false
            if is_instance_valid(page_scroll) and page_scroll.get_global_rect().has_point(finger.position):
                touch_index=finger.index
                touch_origin=finger.position
                touch_previous=finger.position
                pointer_in_scroll=true
        elif finger.index==touch_index:
            if gesture_was_scroll:
                get_viewport().set_input_as_handled()
            touch_index=-1
            pointer_in_scroll=false
    elif event is InputEventScreenDrag:
        var drag: InputEventScreenDrag=event
        if pointer_in_scroll and drag.index==touch_index and is_instance_valid(page_scroll):
            var displacement: float=drag.position.y-touch_previous.y
            if absf(drag.position.y-touch_origin.y)>9.0 or gesture_was_scroll:
                gesture_was_scroll=true
                var bar: VScrollBar=page_scroll.get_v_scroll_bar()
                var limit: int=maxi(0,int(ceilf(bar.max_value-bar.page)))
                page_scroll.scroll_vertical=clampi(page_scroll.scroll_vertical-int(round(displacement)),0,limit)
                touch_scroll_events+=1
                get_viewport().set_input_as_handled()
            touch_previous=drag.position

func _scroll_step(direction: int) -> void:
    if not is_instance_valid(page_scroll):
        return
    var bar: VScrollBar=page_scroll.get_v_scroll_bar()
    var limit: int=maxi(0,int(ceilf(bar.max_value-bar.page)))
    page_scroll.scroll_vertical=clampi(page_scroll.scroll_vertical+direction*int(page_scroll.size.y*0.60),0,limit)
    scroll_positions[page]=page_scroll.scroll_vertical

func _remember_scroll() -> void:
    if is_instance_valid(page_scroll):
        scroll_positions[page]=page_scroll.scroll_vertical

func _restore_scroll(expected_page: String, y: int) -> void:
    if is_instance_valid(page_scroll) and expected_page==page:
        page_scroll.scroll_vertical=y

func _navigate(destination: String) -> void:
    if destination==page:
        return
    _remember_scroll()
    page=destination
    _draw_screen(false)

func _detail(destination: String) -> void:
    return_page=page
    _navigate(destination)

func _back() -> void:
    if page in ["market","buildings","research","storage"]:
        _navigate("hq")
    else:
        _navigate("home")

func _clear_old() -> void:
    # Remove immediately so queued controls never intercept touches or swipes.
    if is_instance_valid(shell):
        remove_child(shell)
        shell.queue_free()

func _draw_screen(preserve_scroll: bool=true) -> void:
    if preserve_scroll:
        _remember_scroll()
    _clear_old()
    shell=MarginContainer.new()
    shell.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    shell.add_theme_constant_override("margin_left",18)
    shell.add_theme_constant_override("margin_right",18)
    shell.add_theme_constant_override("margin_top",18)
    shell.add_theme_constant_override("margin_bottom",12)
    add_child(shell)
    var body:=_column(shell,10)
    _top(body)
    _compact_status(body)
    page_scroll=ScrollContainer.new()
    page_scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
    page_scroll.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    page_scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_AUTO
    page_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
    page_scroll.scroll_deadzone=4
    page_scroll.follow_focus=false
    page_scroll.mouse_filter=Control.MOUSE_FILTER_PASS
    body.add_child(page_scroll)
    var content:=_column(page_scroll,12)
    content.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    match page:
        "home": _home(content)
        "districts": _districts(content)
        "operations": _operations(content)
        "hq": _hq(content)
        "storage": _storage(content)
        "market": _market(content)
        "buildings": _buildings(content)
        "research": _research(content)
        "team": _team(content)
        "journal": _journal(content)
        _: _home(content)
    _bottom(body)
    call_deferred("_restore_scroll",page,int(scroll_positions.get(page,0)))

func _top(parent: VBoxContainer) -> void:
    var line:=_row(parent,12)
    var left:=_column(line,1)
    left.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    _text(left,"СДВИГ  /  48",27,INK)
    _text(left,"ОРГАНИЗАЦИЯ МЕЖДУ МИРАМИ",13,AQUA)
    var right:=_column(line,1)
    var t:=_text(right,"ЦИКЛ %02d" % sim.cycle,18,GOLD)
    t.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
    t=_text(right,"ДЕНЬ %d" % sim.day,14,MUTED)
    t.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT

func _compact_status(parent: VBoxContainer) -> void:
    var strip:=_row(parent,3)
    var left:=_column(strip,1)
    left.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    _text(left,"ВНУТРЕННИЙ МИР" if sim.mode=="inner" else "ВНЕШНИЙ МИР",17,AQUA)
    _text(left,("%d Ч. ОСТАЛОСЬ" % sim.hours_left) if sim.mode=="inner" else "ПОДГОТОВКА К ПЕРЕХОДУ",14,MUTED)
    var right:=_column(strip,1)
    right.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    var money:=_text(right,"%d КР.   /   РИСК %d%%" % [sim.credits,sim.heat],17,GOLD if sim.heat<60 else DANGER)
    money.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
    var cargo:=_text(right,"ГРУЗ %d/%d" % [sim.alloy+sim.data+sim.modules,sim.cargo_limit()],14,MUTED)
    cargo.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT

func _bottom(parent: VBoxContainer) -> void:
    # Always-available fallback for devices where touch emulation misbehaves.
    var arrows:=_row(parent,7)
    var up:=_button(arrows,"▲  ВВЕРХ",_scroll_step.bind(-1),false,false,43)
    var down:=_button(arrows,"▼  ВНИЗ",_scroll_step.bind(1),false,false,43)
    up.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    down.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    up.add_theme_font_size_override("font_size",15)
    down.add_theme_font_size_override("font_size",15)
    var nav:=_row(parent,5)
    for entry in [
        {"id":"home","label":"ОБЗОР"},
        {"id":"districts","label":"РАЙОНЫ"},
        {"id":"operations","label":"МИССИИ"},
        {"id":"hq","label":"ШТАБ"},
        {"id":"team","label":"АГЕНТЫ"}
    ]:
        var id:String=str(entry["id"])
        var b:=_button(nav,str(entry["label"]),_navigate.bind(id),page==id,false,63)
        b.size_flags_horizontal=Control.SIZE_EXPAND_FILL
        b.add_theme_font_size_override("font_size",14)

func _heading(parent: VBoxContainer, name: String, description: String="") -> void:
    var header:=_row(parent,6)
    if page in ["storage","market","buildings","research","journal"]:
        var back:=_button(header,"‹",_back,false,false,52)
        back.custom_minimum_size.x=57
    var title:=_text(header,name,28,INK)
    title.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    if description!="":
        _text(parent,description,18,MUTED)

func _hint(parent: VBoxContainer, title: String, description: String) -> void:
    var p:=_panel(parent,true)
    _text(p,title,16,AQUA)
    _text(p,description,19,INK)

func _home(parent: VBoxContainer) -> void:
    _heading(parent,"ЦЕНТР УПРАВЛЕНИЯ","Следующий шаг и состояние организации.")
    _hint(parent,"ТЕКУЩАЯ ЦЕЛЬ",sim.objective())
    var shift:=_panel(parent,false,true)
    _text(shift,"ПЕРЕХОД МЕЖДУ МИРАМИ",19,AQUA)
    _text(shift,"48 часов на разведку и добычу." if sim.mode=="outer" else "Следи за временем, грузом и уровнем подозрения.",20,INK)
    _button(shift,"НАЧАТЬ СДВИГ" if sim.mode=="outer" else "ВЕРНУТЬСЯ В ШТАБ",_shift,true,false,74)
    if sim.mode=="inner":
        _button(shift,"ВЫБРАТЬ ОПЕРАЦИЮ",_navigate.bind("operations"),false,false,62)
    var stats:=_panel(parent)
    _text(stats,"СОСТОЯНИЕ ОРГАНИЗАЦИИ",18,AQUA)
    _text(stats,"Агенты: %d/3     Операции: %d" % [sim.hired.size(),sim.operations_done],19,INK)
    _text(stats,"Лаборатория: %s" % ("построена" if int(sim.buildings.get("lab",0))>0 else "не построена"),19,MUTED)
    _text(stats,"Успешных операций: %d" % sim.successful,19,MUTED)
    var note:=_panel(parent)
    _text(note,"ПОСЛЕДНЕЕ СОБЫТИЕ",16,AQUA)
    _text(note,sim.last_event,19,INK)
    _button(note,"ПОСМОТРЕТЬ ЖУРНАЛ",_detail.bind("journal"),false,false,57)
    var quick:=_panel(parent)
    _text(quick,"БЫСТРЫЙ ДОСТУП",17,AQUA)
    _button(quick,"СКЛАД И РЕСУРСЫ",_detail.bind("storage"),false,false,58)
    _button(quick,"ОТКРЫТЬ ШТАБ",_navigate.bind("hq"),false,false,58)

func _districts(parent: VBoxContainer) -> void:
    _heading(parent,"РАЙОНЫ","6 районов Внутреннего мира. Нажми на район, чтобы выбрать операции.")
    for district in ShiftGame.DISTRICTS:
        var district_id:String=str(district["id"])
        var p:=_panel(parent,district_id==sim.selected,district_id==sim.selected)
        var row:=_row(p)
        var title:=_text(row,str(district["name"]),21,INK)
        title.size_flags_horizontal=Control.SIZE_EXPAND_FILL
        _text(row,"РИСК %d/5" % int(district["danger"]),16,GOLD)
        _text(p,str(district["subtitle"]),17,MUTED)
        _button(p,"ВЫБРАТЬ РАЙОН  →",_district_select.bind(district_id),district_id==sim.selected,false,58)

func _operations(parent: VBoxContainer) -> void:
    _heading(parent,"ОПЕРАЦИИ","Один район — два доступных задания. Без лишних списков.")
    if sim.mode!="inner":
        _hint(parent,"ПЕРЕХОД НЕ ВЫПОЛНЕН","Чтобы отправить агента на операцию, сначала начни Сдвиг.")
        _button(parent,"НАЧАТЬ СДВИГ",_shift,true,false,72)
        return
    var district:Dictionary=sim.get_district(sim.selected)
    var current:=_panel(parent,true)
    _text(current,"РАЙОН: "+str(district["name"]),20,AQUA)
    _text(current,str(district["subtitle"]),17,MUTED)
    _button(current,"СМЕНИТЬ РАЙОН",_navigate.bind("districts"),false,false,57)
    var a:Dictionary=sim.get_agent(sim.active_agent)
    var agent:=_panel(parent)
    _text(agent,"АГЕНТ: "+str(a["name"]),18,INK)
    _text(agent,"%s  •  усталость %d/6" % [a["role"],int(sim.fatigue.get(sim.active_agent,0))],16,MUTED)
    _button(agent,"СМЕНИТЬ АГЕНТА",_navigate.bind("team"),false,false,56)
    for op in sim.get_ops(sim.selected):
        var p:=_panel(parent)
        _text(p,str(op["name"]),23,INK)
        var chance:int=sim.chance(op)
        _text(p,"Шанс %d%%    •    Время %d ч." % [chance,int(op["hours"])],18,AQUA if chance>=65 else GOLD)
        _text(p,"Подозрение +%d  •  Добыча: %s" % [int(op["heat"]),_loot(op["loot"])],17,MUTED)
        _button(p,"ВЫПОЛНИТЬ",_do_operation.bind(str(op["id"])),true,sim.hours_left<int(op["hours"]),70)
    _hint(parent,"СОВЕТ","Выбирай агента по специализации. Чем выше подозрение и усталость, тем меньше шанс успеха.")

func _loot(value: Dictionary) -> String:
    var out:Array[String]=[]
    for key in ["credits","alloy","data","modules","intel"]:
        if int(value.get(key,0))>0:
            out.append("%s +%d" % [sim.resource_name(key),int(value[key])])
    return ", ".join(out)

func _hq(parent: VBoxContainer) -> void:
    _heading(parent,"ШТАБ","Все хозяйственные системы вынесены в отдельные экраны.")
    var options: Array=[
        {"title":"СКЛАД","desc":"Ресурсы, вместимость и добыча","page":"storage"},
        {"title":"РЫНОК","desc":"Продажа сплавов, данных и модулей","page":"market"},
        {"title":"СТРОИТЕЛЬСТВО","desc":"Лаборатория, склад, убежище","page":"buildings"},
        {"title":"ИССЛЕДОВАНИЯ","desc":"Научные технологии и улучшения","page":"research"}
    ]
    for choice in options:
        var p:=_panel(parent)
        _text(p,str(choice["title"]),23,AQUA)
        _text(p,str(choice["desc"]),17,MUTED)
        _button(p,"ОТКРЫТЬ",_detail.bind(str(choice["page"])),false,false,57)
    _hint(parent,"ВАЖНО","Улучшения базы доступны во Внешнем мире. Внутри Сдвига можно заниматься разведкой и операциями.")

func _storage(parent: VBoxContainer) -> void:
    _heading(parent,"СКЛАД","Текущие запасы и грузовые ограничения.")
    for key in ["alloy","data","modules","intel"]:
        var p:=_panel(parent)
        var row:=_row(p)
        var value:=_text(row,sim.resource_name(key),22,INK)
        value.size_flags_horizontal=Control.SIZE_EXPAND_FILL
        _text(row,str(int(sim.get(key))),24,AQUA)
    _hint(parent,"ВМЕСТИМОСТЬ","%d / %d единиц груза" % [sim.alloy+sim.data+sim.modules,sim.cargo_limit()])
    _button(parent,"ПЕРЕЙТИ К РЫНКУ",_navigate.bind("market"),false,false,64)

func _market(parent: VBoxContainer) -> void:
    _heading(parent,"ЧЁРНЫЙ РЫНОК","Продавай по одному предмету, чтобы не терять материалы для исследований.")
    if sim.mode!="outer":
        _hint(parent,"ДОСТУП ОГРАНИЧЕН","Торговля доступна после возвращения во Внешний мир.")
        return
    var prices:Dictionary={"alloy":90,"data":125,"modules":240,"intel":55}
    for key in ["alloy","data","modules","intel"]:
        var p:=_panel(parent)
        var row:=_row(p)
        var title:=_text(row,sim.resource_name(key),21,INK)
        title.size_flags_horizontal=Control.SIZE_EXPAND_FILL
        _text(row,"%d шт." % int(sim.get(key)),20,AQUA)
        _text(p,"Цена продажи: %d кредитов / шт." % int(prices[key]),17,MUTED)
        _button(p,"ПРОДАТЬ 1 ШТ.",_sell.bind(key),false,int(sim.get(key))<=0,61)

func _buildings(parent: VBoxContainer) -> void:
    _heading(parent,"СТРОИТЕЛЬСТВО","Отдельные объекты базы с затратами и уровнями.")
    if sim.mode!="outer":
        _hint(parent,"НЕДОСТУПНО","Вернись во Внешний мир, чтобы строить.")
        return
    for building in ShiftGame.BUILDINGS:
        var id:String=str(building["id"])
        var lvl:int=int(sim.buildings.get(id,0))
        var price:int=int(building["credits"])+lvl*200
        var metal:int=int(building["alloy"])+lvl
        var p:=_panel(parent)
        _text(p,str(building["name"]),22,INK)
        _text(p,"Уровень %d из %d" % [lvl,int(building["max"])],18,AQUA)
        _text(p,str(building["desc"]),17,MUTED)
        _button(p,"УЛУЧШИТЬ • %d кр. / %d сплава" % [price,metal],_upgrade.bind(id),false,lvl>=int(building["max"]) or sim.credits<price or sim.alloy<metal,66)

func _research(parent: VBoxContainer) -> void:
    _heading(parent,"ИССЛЕДОВАНИЯ","Научные проекты становятся доступны после строительства лаборатории.")
    if sim.mode!="outer":
        _hint(parent,"НЕДОСТУПНО","Исследования проводятся во Внешнем мире.")
        return
    if int(sim.buildings.get("lab",0))==0:
        _hint(parent,"СНАЧАЛА ЛАБОРАТОРИЯ","Построй исследовательский модуль в меню строительства.")
        _button(parent,"К СТРОИТЕЛЬСТВУ",_navigate.bind("buildings"),false,false,65)
        return
    for project in ShiftGame.RESEARCH:
        var id:String=str(project["id"])
        var completed:bool=sim.researched.has(id)
        var p:=_panel(parent)
        _text(p,str(project["name"])+( "  ✓" if completed else ""),22,INK)
        _text(p,str(project["desc"]),17,MUTED)
        var price:int=int(project["credits"])
        var information:int=int(project["data"])
        _button(p,"ИЗУЧЕНО" if completed else "ИЗУЧИТЬ • %d кр. / %d данных" % [price,information],_research_action.bind(id),false,completed or sim.credits<price or sim.data<information,66)

func _team(parent: VBoxContainer) -> void:
    _heading(parent,"АГЕНТЫ","Выбирай специалиста перед операцией. Усталость влияет на успех.")
    for agent in ShiftGame.AGENTS:
        var id:String=str(agent["id"])
        var owned:bool=sim.hired.has(id)
        var selected:bool=sim.active_agent==id
        var p:=_panel(parent,selected,selected)
        _text(p,str(agent["name"]),24,INK)
        _text(p,str(agent["role"])+"  •  "+str(agent["desc"]),17,MUTED)
        var skills:Dictionary=agent["skills"]
        _text(p,"СКР %d   ТЕХ %d   ПЕР %d" % [int(skills["stealth"]),int(skills["tech"]),int(skills["social"])],17,AQUA)
        _text(p,"Усталость %d/6" % int(sim.fatigue.get(id,0)),16,MUTED)
        if owned:
            _button(p,"АКТИВНЫЙ АГЕНТ" if selected else "НАЗНАЧИТЬ",_select_agent.bind(id),selected,selected,62)
        else:
            _button(p,"НАНЯТЬ • %d кр." % int(agent["fee"]),_recruit.bind(id),false,sim.mode!="outer" or sim.credits<int(agent["fee"]),62)

func _journal(parent: VBoxContainer) -> void:
    _heading(parent,"ЖУРНАЛ","История операций и состояния организации.")
    var p:=_panel(parent,true)
    _text(p,"Операций: %d  •  Успешно: %d" % [sim.operations_done,sim.successful],20,INK)
    _text(p,"Продаж: %d  •  Исследований: %d" % [sim.sold_units,sim.researched.size()],18,MUTED)
    _button(p,"СОХРАНИТЬ ИГРУ",_save_now,false,false,55)
    for line in sim.logbook:
        var item:=_panel(parent)
        _text(item,str(line),18,INK)
    var reset:=_panel(parent)
    _text(reset,"НАЧАТЬ СНАЧАЛА",18,DANGER)
    _button(reset,"СБРОС ПРОГРЕССА",_confirm_reset,false,false,55)

func _shift() -> void:
    if sim.mode=="outer":
        sim.start_shift()
        _navigate("districts")
    else:
        sim.return_home()
        _navigate("home")

func _district_select(id: String) -> void:
    sim.selected=id
    sim.save_game()
    _navigate("operations")

func _do_operation(id: String) -> void:
    sim.operate(id)
    if sim.mode=="outer":
        _navigate("home")
    else:
        _draw_screen(true)

func _sell(id: String) -> void:
    sim.sell(id)
    _draw_screen(true)

func _upgrade(id: String) -> void:
    sim.upgrade(id)
    _draw_screen(true)

func _research_action(id: String) -> void:
    sim.research(id)
    _draw_screen(true)

func _recruit(id: String) -> void:
    sim.recruit(id)
    _draw_screen(true)

func _select_agent(id: String) -> void:
    sim.select_agent(id)
    _navigate("operations" if sim.mode=="inner" else "team")

func _save_now() -> void:
    sim.save_game()
    _draw_screen(true)

func _confirm_reset() -> void:
    if is_instance_valid(reset_overlay):
        reset_overlay.queue_free()
    reset_overlay=ColorRect.new()
    reset_overlay.color=Color("#101D2B")
    reset_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(reset_overlay)
    var margin:=MarginContainer.new()
    margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    margin.add_theme_constant_override("margin_left",35)
    margin.add_theme_constant_override("margin_right",35)
    margin.add_theme_constant_override("margin_top",155)
    reset_overlay.add_child(margin)
    var content:=_column(margin,17)
    _text(content,"СБРОС ПРОГРЕССА",30,DANGER)
    _text(content,"Все ресурсы, агенты и открытия будут потеряны.",23,INK)
    _button(content,"ОТМЕНА",_cancel_reset,false,false,70)
    _button(content,"ПОДТВЕРДИТЬ",_reset_game,true,false,70)

func _cancel_reset() -> void:
    if is_instance_valid(reset_overlay):
        reset_overlay.queue_free()

func _reset_game() -> void:
    _cancel_reset()
    sim.reset()
    scroll_positions.clear()
    _navigate("home")
