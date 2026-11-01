extends Control

const INK := Color("#0A111B")
const PANEL := Color("#132433")
const PANEL2 := Color("#1A3040")
const BORDER := Color("#345061")
const MUTED := Color("#9BB0BC")
const IVORY := Color("#F2F0E5")
const TEAL := Color("#75E0CB")
const AMBER := Color("#EAC584")
const RED := Color("#F28E91")
var sim: ShiftGame = ShiftGame.new()
var tab: String="map"
var root: MarginContainer
var scroll: ScrollContainer

func _ready() -> void:
    if not sim.load_game():
        sim.reset()
    _render()

func _style(c: Color, b: Color = BORDER, corner: int=16) -> StyleBoxFlat:
    var s: StyleBoxFlat=StyleBoxFlat.new()
    s.bg_color=c
    s.border_color=b
    s.set_border_width_all(1)
    s.set_corner_radius_all(corner)
    s.content_margin_left=15
    s.content_margin_right=15
    s.content_margin_top=12
    s.content_margin_bottom=12
    return s

func _text(parent: Node, content: String, px: int=21, color: Color=IVORY) -> Label:
    var t: Label=Label.new()
    t.text=content
    t.add_theme_font_size_override("font_size",px)
    t.add_theme_color_override("font_color",color)
    t.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    parent.add_child(t)
    return t

func _btn(parent: Node, caption: String, callback: Callable, active: bool=false, height: int=62, disabled: bool=false) -> Button:
    var b: Button=Button.new()
    b.text=caption
    b.custom_minimum_size.y=height
    b.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    b.add_theme_font_size_override("font_size",19)
    b.add_theme_color_override("font_color",IVORY)
    b.add_theme_color_override("font_hover_color",IVORY)
    b.add_theme_color_override("font_disabled_color",Color("#728290"))
    b.add_theme_stylebox_override("normal",_style(Color("#20535C") if active else PANEL2,TEAL if active else BORDER,12))
    b.add_theme_stylebox_override("hover",_style(Color("#28636B"),TEAL,12))
    b.add_theme_stylebox_override("pressed",_style(Color("#386977"),TEAL,12))
    b.add_theme_stylebox_override("disabled",_style(Color("#182633"),Color("#253744"),12))
    b.pressed.connect(callback)
    b.disabled=disabled
    parent.add_child(b)
    return b

func _panel(parent: Node, c: Color=PANEL, edge: Color=BORDER) -> VBoxContainer:
    var container: PanelContainer=PanelContainer.new()
    container.add_theme_stylebox_override("panel",_style(c,edge,18))
    container.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    parent.add_child(container)
    var content: VBoxContainer=VBoxContainer.new()
    content.add_theme_constant_override("separation",8)
    container.add_child(content)
    return content

func _row(parent: Node, space: int=8) -> HBoxContainer:
    var r: HBoxContainer=HBoxContainer.new()
    r.add_theme_constant_override("separation",space)
    parent.add_child(r)
    return r

func _spacer(parent: Node, height: int=10) -> void:
    var s: Control=Control.new()
    s.custom_minimum_size.y=height
    parent.add_child(s)

func _clear_root() -> void:
    if is_instance_valid(root):
        root.queue_free()
    for n in get_children():
        if n!=root and n.name=="SceneBackground":
            n.queue_free()

func _render() -> void:
    _clear_root()
    var bg: ColorRect=ColorRect.new()
    bg.name="SceneBackground"
    bg.color=INK
    bg.mouse_filter=Control.MOUSE_FILTER_IGNORE
    bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(bg)
    root=MarginContainer.new()
    root.name="ShiftContent"
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.add_theme_constant_override("margin_left",20)
    root.add_theme_constant_override("margin_right",20)
    root.add_theme_constant_override("margin_top",20)
    root.add_theme_constant_override("margin_bottom",16)
    add_child(root)
    var shell: VBoxContainer=VBoxContainer.new()
    shell.add_theme_constant_override("separation",11)
    root.add_child(shell)
    _top(shell)
    _world_bar(shell)
    _resources(shell)
    _tabs(shell)
    scroll=ScrollContainer.new()
    scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
    scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
    shell.add_child(scroll)
    var content: VBoxContainer=VBoxContainer.new()
    content.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    content.add_theme_constant_override("separation",14)
    scroll.add_child(content)
    match tab:
        "map": _map_tab(content)
        "base": _base_tab(content)
        "team": _team_tab(content)
        "journal": _journal_tab(content)
    _footer(shell)

func _top(parent: VBoxContainer) -> void:
    var r: HBoxContainer=_row(parent,8)
    var brand: VBoxContainer=VBoxContainer.new()
    brand.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    r.add_child(brand)
    _text(brand,"С Д В И Г   /   4 8",30,IVORY)
    _text(brand,"СТРАТЕГИЯ ДВУХ РЕАЛЬНОСТЕЙ",14,TEAL)
    var right: VBoxContainer=VBoxContainer.new()
    r.add_child(right)
    var txt: Label=_text(right,"ЦИКЛ %02d" % sim.cycle,19,AMBER)
    txt.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
    txt=_text(right,"ДЕНЬ %02d" % sim.day,15,MUTED)
    txt.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT

func _world_bar(parent: VBoxContainer) -> void:
    var p: VBoxContainer=_panel(parent,Color("#162D3A"),Color("#35646A"))
    var r: HBoxContainer=_row(p)
    var v: VBoxContainer=VBoxContainer.new()
    v.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    r.add_child(v)
    var inner: bool=sim.mode=="inner"
    _text(v,"ВНУТРЕННИЙ МИР" if inner else "ВНЕШНИЙ МИР",20,TEAL)
    _text(v,("%d ЧАС. ДО ВОЗВРАЩЕНИЯ" % sim.hours_left) if inner else "ШТАБ / ПОДГОТОВКА",17,MUTED)
    var b: Button=_btn(r,"ВЕРНУТЬСЯ" if inner else "СДВИГ →",_return_home if inner else _start,true,62)
    b.custom_minimum_size.x=176

func _stat_cell(parent: Node, name: String, amount: int, col: Color) -> void:
    var p: VBoxContainer=_panel(parent,Color("#152634"),Color("#273D4C"))
    p.custom_minimum_size.y=82
    _text(p,name,14,MUTED)
    _text(p,str(amount),25,col)

func _resources(parent: VBoxContainer) -> void:
    var grid: GridContainer=GridContainer.new()
    grid.columns=3
    grid.add_theme_constant_override("h_separation",9)
    grid.add_theme_constant_override("v_separation",8)
    parent.add_child(grid)
    _stat_cell(grid,"КРЕДИТЫ",sim.credits,AMBER)
    _stat_cell(grid,"СПЛАВЫ",sim.alloy,IVORY)
    _stat_cell(grid,"ДАННЫЕ",sim.data,IVORY)
    _stat_cell(grid,"МОДУЛИ",sim.modules,IVORY)
    _stat_cell(grid,"РАЗВЕДКА",sim.intel,TEAL)
    _stat_cell(grid,"ПОДОЗРЕНИЕ",sim.heat,RED if sim.heat>60 else TEAL)

func _tabs(parent: VBoxContainer) -> void:
    var r: HBoxContainer=_row(parent,5)
    for item in [{"id":"map","title":"ГОРОД"},{"id":"base","title":"ШТАБ"},{"id":"team","title":"АГЕНТЫ"},{"id":"journal","title":"ЖУРНАЛ"}]:
        var b: Button=_btn(r,str(item["title"]),_set_tab.bind(str(item["id"])),tab==str(item["id"]),57)
        b.size_flags_horizontal=Control.SIZE_EXPAND_FILL
        b.add_theme_font_size_override("font_size",15)

func _footer(parent: VBoxContainer) -> void:
    var p: VBoxContainer=_panel(parent,Color("#102633"),Color("#28585D"))
    _text(p,"ПОСЛЕДНЕЕ СОБЫТИЕ",14,TEAL)
    _text(p,sim.last_event,17,IVORY)

func _header(parent: VBoxContainer, heading: String, subtitle: String) -> void:
    _text(parent,heading,29,IVORY)
    _text(parent,subtitle,18,MUTED)
    _spacer(parent,2)

func _objective(parent: VBoxContainer) -> void:
    var box: VBoxContainer=_panel(parent,Color("#1D3241"),Color("#577C79"))
    _text(box,"ТЕКУЩАЯ ЦЕЛЬ",14,TEAL)
    _text(box,sim.objective(),20,IVORY)

func _map_tab(parent: VBoxContainer) -> void:
    if sim.mode=="outer":
        _header(parent,"ПОДГОТОВКА К ПЕРЕХОДУ","Между мирами проходит 48 часов. Ты решаешь, что вынести обратно.")
        _objective(parent)
        var intro: VBoxContainer=_panel(parent)
        _text(intro,"ШТАБ В ТЕНИ ГОРОДА",19,AMBER)
        _text(intro,"Ты основал небольшую организацию. Во Внутреннем мире можно добыть сплавы, модули и научные данные. Во Внешнем — продать технологии, нанять специалистов и построить лабораторию.",20,IVORY)
        _btn(intro,"НАЧАТЬ ПЕРЕХОД · 48 ЧАСОВ",_start,true,78)
        _text(intro,"СОВЕТ: начни с Заводского пояса — для лаборатории нужен сплав.",17,MUTED)
        var preview: VBoxContainer=_panel(parent)
        _text(preview,"КАРТА ДОСТУПНЫХ РАЙОНОВ",18,TEAL)
        _text(preview,"6 районов • 12 типов операций • риск зависит от агента",17,MUTED)
        for d in ShiftGame.DISTRICTS:
            _text(preview,"◆  %s  /  опасность %d" % [d["name"],int(d["danger"])],19,IVORY)
        return
    _header(parent,"КАРТА ВНУТРЕННЕГО МИРА","Выбери район, затем операцию. Доступное время ограничено.")
    _objective(parent)
    var a: Dictionary=sim.get_agent(sim.active_agent)
    var indicator: VBoxContainer=_panel(parent,Color("#193A44"),Color("#378E8B"))
    _text(indicator,"АКТИВНЫЙ АГЕНТ  /  %s" % a["name"],20,TEAL)
    _text(indicator,"%s  •  усталость %d/6  •  груз %d/%d" % [a["role"],int(sim.fatigue.get(sim.active_agent,0)),sim.alloy+sim.data+sim.modules,sim.cargo_limit()],16,MUTED)
    var grid: GridContainer=GridContainer.new()
    grid.columns=2
    grid.add_theme_constant_override("h_separation",9)
    grid.add_theme_constant_override("v_separation",9)
    parent.add_child(grid)
    for d in ShiftGame.DISTRICTS:
        var focus: bool=sim.selected==str(d["id"])
        var label: String="%s\nРИСК  %d / 5" % [d["name"],int(d["danger"])]
        var b: Button=_btn(grid,label,_choose_district.bind(str(d["id"])),focus,102)
        b.size_flags_horizontal=Control.SIZE_EXPAND_FILL
        b.add_theme_font_size_override("font_size",19)
    var district: Dictionary=sim.get_district(sim.selected)
    var detail: VBoxContainer=_panel(parent,Color("#1B303D"),TEAL)
    _text(detail,str(district["name"]).to_upper(),24,IVORY)
    _text(detail,str(district["subtitle"]),17,MUTED)
    for op in sim.get_ops(sim.selected):
        var chance: int=sim.chance(op)
        var can_do: bool=sim.hours_left>=int(op["hours"])
        var line: VBoxContainer=_panel(detail,Color("#142330"),Color("#355360"))
        _text(line,str(op["name"]),21,IVORY)
        _text(line,"ШАНС %d%%    •    %d ЧАСОВ    •    +%d ПОДОЗРЕНИЕ" % [chance,int(op["hours"]),int(op["heat"])],16,TEAL if chance>=65 else AMBER)
        _text(line,"ДОБЫЧА:  "+_loot_label(op["loot"]),16,MUTED)
        _btn(line,"НАЧАТЬ ОПЕРАЦИЮ",_do_operation.bind(str(op["id"])),false,63,not can_do)

func _loot_label(loot: Dictionary) -> String:
    var parts: Array[String]=[]
    for key in ["credits","alloy","data","modules","intel"]:
        if int(loot.get(key,0))>0:
            parts.append("%s %d" % [sim.resource_name(key),int(loot[key])])
    return ", ".join(parts)

func _base_tab(parent: VBoxContainer) -> void:
    _header(parent,"ТВОЙ ПОДПОЛЬНЫЙ ШТАБ","Экономика, исследования и развитие организации.")
    _objective(parent)
    if sim.mode!="outer":
        var wait: VBoxContainer=_panel(parent)
        _text(wait,"РАЗВИТИЕ НЕДОСТУПНО",20,AMBER)
        _text(wait,"Строительство и продажа ресурсов возможны после возвращения во Внешний мир.",18,MUTED)
        return
    var market: VBoxContainer=_panel(parent,Color("#192F3B"),Color("#43646D"))
    _text(market,"ЧЁРНЫЙ РЫНОК",22,AMBER)
    _text(market,"Продажа добытых материалов пополняет бюджет. Реши, что оставить для исследований.",17,MUTED)
    var prices: Dictionary={"alloy":90,"data":125,"modules":240,"intel":55}
    for key in ["alloy","data","modules","intel"]:
        var line: HBoxContainer=_row(market,7)
        var value: Label=_text(line,"%s  •  %d шт.  •  %d кр." % [sim.resource_name(key),int(sim.get(key)),int(prices[key])],17,IVORY)
        value.size_flags_horizontal=Control.SIZE_EXPAND_FILL
        var action: Button=_btn(line,"ПРОДАТЬ",_sell.bind(key),false,54,int(sim.get(key))==0)
        action.custom_minimum_size.x=130
    var buildings: VBoxContainer=_panel(parent)
    _text(buildings,"РАЗВИТИЕ БАЗЫ",22,TEAL)
    for building in ShiftGame.BUILDINGS:
        var id: String=str(building["id"])
        var level: int=int(sim.buildings.get(id,0))
        var max_lvl: int=int(building["max"])
        var price: int=int(building["credits"])+level*200
        var metal: int=int(building["alloy"])+level
        var box: VBoxContainer=_panel(buildings,Color("#172A38"),BORDER)
        _text(box,"%s   [%d/%d]" % [building["name"],level,max_lvl],20,IVORY)
        _text(box,str(building["desc"]),16,MUTED)
        _btn(box,"ПОСТРОИТЬ  •  %d кр. + %d сплава" % [price,metal],_upgrade.bind(id),false,56,level>=max_lvl or sim.credits<price or sim.alloy<metal)
    var research: VBoxContainer=_panel(parent)
    _text(research,"ПРОЕКТЫ ЛАБОРАТОРИИ",22,TEAL)
    if int(sim.buildings.get("lab",0))==0:
        _text(research,"Построй исследовательский модуль для доступа к разработкам.",17,AMBER)
    for p in ShiftGame.RESEARCH:
        var id: String=str(p["id"])
        var ready: bool=sim.researched.has(id)
        var box: VBoxContainer=_panel(research,Color("#172A38"),BORDER)
        _text(box,str(p["name"])+( "   ✓" if ready else ""),20,IVORY)
        _text(box,str(p["desc"]),16,MUTED)
        _btn(box,"ИЗУЧЕНО" if ready else "ИЗУЧИТЬ  •  %d кр. + %d данных" % [int(p["credits"]),int(p["data"])],_research.bind(id),false,56,ready or int(sim.buildings.get("lab",0))==0 or sim.credits<int(p["credits"]) or sim.data<int(p["data"]))

func _team_tab(parent: VBoxContainer) -> void:
    _header(parent,"ТВОИ АГЕНТЫ","Специализация агента влияет на шанс успеха. Команда восстанавливается между переходами.")
    for a in ShiftGame.AGENTS:
        var id: String=str(a["id"])
        var owned: bool=sim.hired.has(id)
        var focus: bool=sim.active_agent==id
        var box: VBoxContainer=_panel(parent,Color("#19343E") if focus else PANEL,TEAL if focus else BORDER)
        var heading: String=str(a["name"]).to_upper()+"  /  "+str(a["role"])
        _text(box,heading,22,TEAL if focus else IVORY)
        _text(box,str(a["desc"]),17,MUTED)
        var skills: Dictionary=a["skills"]
        _text(box,"СКРЫТНОСТЬ %d   ТЕХНИКА %d   ПЕРЕГОВОРЫ %d" % [int(skills["stealth"]),int(skills["tech"]),int(skills["social"])],16,AMBER)
        _text(box,"Усталость: %d из 6" % int(sim.fatigue.get(id,0)),16,MUTED)
        if owned:
            _btn(box,"АКТИВНЫЙ АГЕНТ" if focus else "НАЗНАЧИТЬ НА ОПЕРАЦИИ",_select_agent.bind(id),focus,64,focus)
        else:
            _btn(box,"НАНЯТЬ  •  %d кредитов" % int(a["fee"]),_recruit.bind(id),false,64,sim.mode!="outer" or sim.credits<int(a["fee"]))
    var note: VBoxContainer=_panel(parent)
    _text(note,"СТРАТЕГИЯ",17,TEAL)
    _text(note,"Лея сильнее в скрытности, Норд — в технике, Рей — в переговорах. Выбирай агента перед миссией, а не после.",18,MUTED)

func _journal_tab(parent: VBoxContainer) -> void:
    _header(parent,"ЖУРНАЛ ОРГАНИЗАЦИИ","Все последствия твоих решений сохраняются.")
    _objective(parent)
    var summary: VBoxContainer=_panel(parent)
    _text(summary,"ОТЧЁТ ШТАБА",21,TEAL)
    _text(summary,"Операций: %d   •   Успешно: %d" % [sim.operations_done,sim.successful],19,IVORY)
    _text(summary,"Агентов: %d / 3   •   Исследований: %d / 3" % [sim.hired.size(),sim.researched.size()],19,IVORY)
    _text(summary,"Продано предметов: %d   •   Переходов: %d" % [sim.sold_units,sim.cycle-1],19,IVORY)
    _btn(summary,"СОХРАНИТЬ ИГРУ",_manual_save,true,57)
    _btn(summary,"НАЧАТЬ ЗАНОВО",_show_reset_confirm,false,57)
    var logs: VBoxContainer=_panel(parent)
    _text(logs,"ХРОНИКА",21,TEAL)
    for line in sim.logbook:
        _text(logs,"•  "+line,18,MUTED)

func _set_tab(name: String) -> void:
    tab=name
    _render()
func _choose_district(id: String) -> void:
    sim.selected=id
    sim.save_game()
    _render()
func _start() -> void:
    sim.start_shift()
    tab="map"
    _render()
func _return_home() -> void:
    sim.return_home()
    tab="base"
    _render()
func _do_operation(id: String) -> void:
    sim.operate(id)
    _render()
func _upgrade(id: String) -> void:
    sim.upgrade(id)
    _render()
func _sell(id: String) -> void:
    sim.sell(id)
    _render()
func _recruit(id: String) -> void:
    sim.recruit(id)
    _render()
func _select_agent(id: String) -> void:
    sim.select_agent(id)
    _render()
func _research(id: String) -> void:
    sim.research(id)
    _render()
func _manual_save() -> void:
    sim.save_game()
    sim._log("Состояние штаба сохранено.")
    sim.save_game()
    _render()

func _show_reset_confirm() -> void:
    var layer: ColorRect=ColorRect.new()
    layer.name="ResetOverlay"
    layer.color=Color(0.03,0.05,0.08,0.96)
    layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(layer)
    var margin: MarginContainer=MarginContainer.new()
    margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    margin.add_theme_constant_override("margin_left",32)
    margin.add_theme_constant_override("margin_right",32)
    margin.add_theme_constant_override("margin_top",170)
    layer.add_child(margin)
    var v: VBoxContainer=VBoxContainer.new()
    v.add_theme_constant_override("separation",18)
    margin.add_child(v)
    _text(v,"НОВЫЙ СДВИГ",34,TEAL)
    _text(v,"Весь текущий прогресс будет сброшен. Ты уверен?",25,IVORY)
    _btn(v,"ОТМЕНА",_cancel_reset.bind(layer),false,76)
    _btn(v,"СБРОСИТЬ ПРОГРЕСС",_confirm_reset.bind(layer),true,76)

func _cancel_reset(layer: ColorRect) -> void:
    layer.queue_free()
func _confirm_reset(layer: ColorRect) -> void:
    layer.queue_free()
    sim.reset()
    tab="map"
    _render()
