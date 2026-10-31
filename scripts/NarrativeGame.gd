extends Control
## Nomenclature Night 0.4 — text-first narrative adventure.
const SOURCE := "res://data/story.json"
const C_BG := Color("#0c121d")
const C_CARD := Color("#152232")
const C_EDGE := Color("#294052")
const C_TEXT := Color("#f0eee6")
const C_MUTED := Color("#9eafba")
const C_ACCENT := Color("#68d9c9")
const C_GOLD := Color("#d5b77a")
var nodes: Dictionary = {}
var current: String = "prologue"
var stats: Dictionary = {"insight":1,"resolve":1,"trust":0,"heat":0}
var clues: Array[String] = []
var flags: Dictionary = {}
var visited: Array[String] = []
var history: Array[Dictionary] = []
var hero_name: String = "Путешественник"
var minutes: int = 118
var root: VBoxContainer
var header_title: Label
var header_status: Label
var header_clock: Label
var chapter_label: Label
var place_label: Label
var scene_title: Label
var narrative: Label
var choice_list: VBoxContainer
var scroll_story: ScrollContainer
var overlay: ColorRect
var progress: ProgressBar
var ending_banner: Label
func _ready() -> void:
    var f := FileAccess.open(SOURCE, FileAccess.READ)
    if f == null:
        push_error("Missing story.json")
        return
    var parsed: Variant = JSON.parse_string(f.get_as_text())
    if typeof(parsed) != TYPE_DICTIONARY:
        push_error("Invalid story JSON")
        return
    nodes = parsed.get("nodes",{})
    current = str(parsed.get("entry","prologue"))
    _build_interface()
    _render_scene()
    _welcome()
func _rect_color(parent: Node, c: Color) -> ColorRect:
    var rect := ColorRect.new()
    rect.color = c
    parent.add_child(rect)
    return rect
func _style(bg: Color, border: Color, radius: int = 17) -> StyleBoxFlat:
    var sb := StyleBoxFlat.new()
    sb.bg_color = bg
    sb.border_color = border
    sb.set_border_width_all(1)
    sb.set_corner_radius_all(radius)
    sb.content_margin_left = 16
    sb.content_margin_right = 16
    sb.content_margin_top = 14
    sb.content_margin_bottom = 14
    return sb
func _label(parent: Node, text: String, size: int, color: Color, bold: bool=false) -> Label:
    var label := Label.new()
    label.text = text
    label.add_theme_font_size_override("font_size",size)
    label.add_theme_color_override("font_color",color)
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    if bold:
        label.add_theme_color_override("font_shadow_color",Color(0,0,0,0.35))
        label.add_theme_constant_override("shadow_offset_x",1)
        label.add_theme_constant_override("shadow_offset_y",1)
    parent.add_child(label)
    return label
func _space(parent: Node, height: float) -> void:
    var s := Control.new()
    s.custom_minimum_size.y = height
    parent.add_child(s)
func _button(parent: Node, text: String, cb: Callable, emphasis: bool=false, height: int=76) -> Button:
    var btn := Button.new()
    btn.text = text
    btn.custom_minimum_size.y = height
    btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
    btn.add_theme_font_size_override("font_size",24)
    btn.add_theme_color_override("font_color",C_TEXT)
    btn.add_theme_color_override("font_hover_color",C_TEXT)
    btn.add_theme_color_override("font_pressed_color",C_BG)
    btn.add_theme_stylebox_override("normal",_style(Color("#24505a") if emphasis else C_CARD,C_ACCENT if emphasis else C_EDGE))
    btn.add_theme_stylebox_override("hover",_style(Color("#2c5661"),C_ACCENT))
    btn.add_theme_stylebox_override("pressed",_style(C_ACCENT,C_ACCENT))
    btn.pressed.connect(cb)
    parent.add_child(btn)
    return btn
func _build_interface() -> void:
    var back := _rect_color(self,C_BG)
    back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var gradient := ColorRect.new()
    gradient.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    gradient.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var shader := Shader.new()
    shader.code = "shader_type canvas_item; void fragment(){ vec2 uv=UV; vec3 top=vec3(0.055,0.112,0.164); vec3 low=vec3(0.035,0.049,0.083); COLOR=vec4(mix(top,low,uv.y),1.0); }"
    var mat := ShaderMaterial.new()
    mat.shader = shader
    gradient.material = mat
    add_child(gradient)
    var margin := MarginContainer.new()
    margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    margin.add_theme_constant_override("margin_left",22)
    margin.add_theme_constant_override("margin_right",22)
    margin.add_theme_constant_override("margin_top",26)
    margin.add_theme_constant_override("margin_bottom",20)
    add_child(margin)
    root = VBoxContainer.new()
    root.add_theme_constant_override("separation",12)
    margin.add_child(root)
    var mast := HBoxContainer.new()
    mast.add_theme_constant_override("separation",14)
    root.add_child(mast)
    var title_stack := VBoxContainer.new()
    title_stack.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    mast.add_child(title_stack)
    header_title = _label(title_stack,"НОМЕНКЛАТУРА НОЧИ",21,C_ACCENT,true)
    header_status = _label(title_stack,"ДВА МИРА  /  ТЕКСТОВЫЙ КВЕСТ",16,C_MUTED)
    header_clock = _label(mast,"",21,C_GOLD,true)
    header_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    var line:=ProgressBar.new()
    line.custom_minimum_size.y=5
    line.show_percentage=false
    line.min_value=0
    line.max_value=1
    line.value=0
    line.add_theme_stylebox_override("background",_style(Color("#263545"),Color("#263545"),2))
    line.add_theme_stylebox_override("fill",_style(C_ACCENT,C_ACCENT,2))
    progress=line
    root.add_child(line)
    var scroll:=ScrollContainer.new()
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
    scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_AUTO
    root.add_child(scroll)
    scroll_story = scroll
    var body := VBoxContainer.new()
    body.add_theme_constant_override("separation",18)
    body.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    scroll.add_child(body)
    chapter_label = _label(body,"",18,C_ACCENT,true)
    place_label = _label(body,"",16,C_MUTED)
    _space(body,2)
    scene_title = _label(body,"",38,C_TEXT,true)
    _space(body,9)
    narrative = _label(body,"",27,C_TEXT)
    narrative.add_theme_constant_override("line_spacing",13)
    narrative.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    _space(body,18)
    ending_banner = _label(body,"",19,C_GOLD,true)
    var label := _label(root,"ВАШЕ РЕШЕНИЕ",17,C_ACCENT,true)
    label.add_theme_constant_override("outline_size",0)
    var option_scroll := ScrollContainer.new()
    option_scroll.custom_minimum_size.y=145
    option_scroll.size_flags_vertical=Control.SIZE_SHRINK_END
    option_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
    root.add_child(option_scroll)
    var list := VBoxContainer.new()
    list.add_theme_constant_override("separation",10)
    list.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    option_scroll.add_child(list)
    choice_list=list
    var bottom := HBoxContainer.new()
    bottom.add_theme_constant_override("separation",6)
    root.add_child(bottom)
    _nav(bottom,"ИСТОРИЯ",func():_show_history())
    _nav(bottom,"УЛИКИ",func():_show_journal())
    _nav(bottom,"ГЕРОЙ",func():_show_character())
    _nav(bottom,"МЕНЮ",func():_show_menu())
func _nav(parent: Node, caption: String, cb: Callable) -> void:
    var btn := Button.new()
    btn.text = caption
    btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    btn.custom_minimum_size.y=58
    btn.add_theme_font_size_override("font_size",17)
    btn.add_theme_stylebox_override("normal",_style(Color("#1d3040"),Color("#273c4b"),10))
    btn.add_theme_stylebox_override("hover",_style(Color("#31525e"),C_ACCENT,10))
    parent.add_child(btn)
    btn.pressed.connect(cb)
func _allowed(choice: Dictionary) -> bool:
    var req: Dictionary = choice.get("requires",{})
    if stats.get("insight",0) < int(req.get("insight_min",0)):
        return false
    if stats.get("trust",0) < int(req.get("trust_min",0)):
        return false
    if stats.get("resolve",0) < int(req.get("resolve_min",0)):
        return false
    if req.has("clue") and not clues.has(str(req["clue"])):
        return false
    if req.has("flag") and not flags.has(str(req["flag"])):
        return false
    return true
func _enter(id: String) -> void:
    if not nodes.has(id):
        push_error("Missing story node: "+id)
        return
    if id == "prologue" and visited.size()>0 and current != id:
        _reset()
    current=id
    var data: Dictionary=nodes[id]
    if not visited.has(id):
        visited.append(id)
        var enter: Dictionary=data.get("enter",{})
        if enter.has("clock"):
            minutes=int(enter["clock"])
        if enter.has("clue"):
            _clue(str(enter["clue"]))
    history.append({"id":id,"title":data.get("title",""),"hero":data.get("hero","")})
    if history.size()>110:
        history.pop_front()
    _render_scene()
    _autosave()
func _render_scene() -> void:
    var n: Dictionary=nodes.get(current,{})
    var hero: String=str(n.get("hero",""))
    var speaker: String="ЦИН ЧЭНЬ" if hero=="qing" else (hero_name.to_upper() if hero=="player" else "ДВА ПУТЕШЕСТВЕННИКА")
    chapter_label.text=str(n.get("chapter",""))+"   /   "+speaker
    place_label.text="◆  "+str(n.get("world",""))
    scene_title.text=str(n.get("title",""))
    narrative.text=str(n.get("text","")).replace("{name}",hero_name)
    ending_banner.text="ИТОГ: "+str(n.get("enter",{}).get("ending","")) if n.get("enter",{}).has("ending") else ""
    header_status.text=("%s • %s" % [speaker,str(n.get("world",""))])
    header_clock.text=("%02d:%02d" % [int(minutes/60),minutes%60])
    progress.value=minf(float(visited.size())/24.0,1.0)
    for child in choice_list.get_children():
        child.queue_free()
    var idx:=1
    for raw in n.get("choices",[]):
        var choice: Dictionary=raw
        if not _allowed(choice):
            continue
        var number: String="%02d" % idx
        var b:=_button(choice_list,number+"  "+str(choice.get("label","")),func():_choose(choice),idx==1,80)
        b.tooltip_text="Время: %d мин." % int(choice.get("cost",0))
        idx+=1
    scroll_story.scroll_vertical=0
func _choose(choice: Dictionary) -> void:
    for key in choice.get("effects",{}):
        stats[key]=clampi(int(stats.get(key,0))+int(choice["effects"][key]),0,12)
    if choice.has("clue"):
        _clue(str(choice["clue"]))
    if choice.has("flag"):
        flags[str(choice["flag"])]=true
    minutes=maxi(0,minutes-int(choice.get("cost",0)))
    var next: String=str(choice.get("next",""))
    if next=="prologue" and current.begins_with("ending_"):
        _reset()
    _enter(next)
func _clue(s: String) -> void:
    if not clues.has(s):
        clues.append(s)
func _reset() -> void:
    stats={"insight":1,"resolve":1,"trust":0,"heat":0}
    clues.clear()
    flags.clear()
    visited.clear()
    history.clear()
    minutes=118
func _autosave() -> void:
    _save(0)
func _save(slot: int) -> void:
    var f:=FileAccess.open("user://nomenclature_%d.json" % slot,FileAccess.WRITE)
    if f==null:
        return
    f.store_string(JSON.stringify({"version":4,"node":current,"stats":stats,"clues":clues,"flags":flags,"visited":visited,"history":history,"name":hero_name,"minutes":minutes}))
    f.close()
func _load(slot: int) -> bool:
    var path: String="user://nomenclature_%d.json" % slot
    if not FileAccess.file_exists(path):
        return false
    var parsed: Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
    if typeof(parsed)!=TYPE_DICTIONARY:
        return false
    if not nodes.has(str(parsed.get("node",""))):
        return false
    current=str(parsed["node"])
    stats=parsed.get("stats",stats)
    flags=parsed.get("flags",{})
    clues.clear()
    for item in parsed.get("clues",[]):
        clues.append(str(item))
    visited.clear()
    for item in parsed.get("visited",[]):
        visited.append(str(item))
    history.clear()
    for item in parsed.get("history",[]):
        if typeof(item)==TYPE_DICTIONARY:
            history.append(item)
    hero_name=str(parsed.get("name","Путешественник"))
    minutes=int(parsed.get("minutes",118))
    _render_scene()
    return true
func _clear_overlay() -> void:
    if is_instance_valid(overlay):
        overlay.queue_free()
        overlay=null
func _panel(title_text: String) -> VBoxContainer:
    _clear_overlay()
    overlay=ColorRect.new()
    overlay.color=Color(0.012,0.022,0.035,0.96)
    overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(overlay)
    var margin:=MarginContainer.new()
    margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    margin.add_theme_constant_override("margin_left",28)
    margin.add_theme_constant_override("margin_right",28)
    margin.add_theme_constant_override("margin_top",56)
    margin.add_theme_constant_override("margin_bottom",38)
    overlay.add_child(margin)
    var wrap:=VBoxContainer.new()
    wrap.add_theme_constant_override("separation",16)
    margin.add_child(wrap)
    _label(wrap,title_text,36,C_TEXT,true)
    _space(wrap,5)
    return wrap
func _close_control(wrap: VBoxContainer) -> void:
    _space(wrap,10)
    _button(wrap,"ЗАКРЫТЬ",_clear_overlay,false,66)
func _welcome() -> void:
    var wrap:=_panel("НОМЕНКЛАТУРА НОЧИ")
    _label(wrap,"ДВА МИРА  •  ИНТЕРАКТИВНЫЙ РОМАН",19,C_ACCENT,true)
    _space(wrap,22)
    _label(wrap,"Две судьбы. Один отсчёт. Решения, за которые придётся отвечать.",29,C_TEXT)
    _space(wrap,30)
    _button(wrap,"НАЧАТЬ ИСТОРИЮ",_new_game,true,84)
    if FileAccess.file_exists("user://nomenclature_0.json"):
        _button(wrap,"ПРОДОЛЖИТЬ",_continue_game,false,78)
    _space(wrap,30)
    _label(wrap,"Пробный эпизод: тюрьма №18, Цин Чэнь и собственный путешественник. Четыре концовки.",20,C_MUTED)
func _show_history() -> void:
    var wrap:=_panel("ИСТОРИЯ")
    _label(wrap,"Пройденные сцены",19,C_MUTED)
    var scroll:=ScrollContainer.new()
    scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
    wrap.add_child(scroll)
    var col:=VBoxContainer.new()
    col.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    scroll.add_child(col)
    for i in range(history.size()-1,-1,-1):
        var e: Dictionary=history[i]
        _label(col,"%02d  %s" % [i+1,str(e.get("title",""))],22,C_TEXT)
    _close_control(wrap)
func _show_journal() -> void:
    var wrap:=_panel("ЖУРНАЛ УЛИК")
    _label(wrap,"Найдено: %d" % clues.size(),21,C_ACCENT)
    var scroll:=ScrollContainer.new()
    scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
    wrap.add_child(scroll)
    var col:=VBoxContainer.new()
    col.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    col.add_theme_constant_override("separation",12)
    scroll.add_child(col)
    if clues.is_empty():
        _label(col,"Пока пусто. Улики появляются после внимательных решений.",23,C_MUTED)
    for i in range(clues.size()):
        _label(col,"%02d    %s" % [i+1,clues[i]],23,C_TEXT)
    _close_control(wrap)
func _show_character() -> void:
    var wrap:=_panel("ВАШ ПЕРСОНАЖ")
    _label(wrap,"Имя второго путешественника",21,C_MUTED)
    var edit:=LineEdit.new()
    edit.text=hero_name
    edit.max_length=26
    edit.custom_minimum_size.y=64
    edit.add_theme_font_size_override("font_size",27)
    wrap.add_child(edit)
    _button(wrap,"СОХРАНИТЬ ИМЯ",_save_name.bind(edit),true,74)
    _space(wrap,12)
    var names={"insight":"НАБЛЮДАТЕЛЬНОСТЬ","resolve":"РЕШИМОСТЬ","trust":"ДОВЕРИЕ","heat":"ПОДОЗРЕНИЕ"}
    for key in ["insight","resolve","trust","heat"]:
        _label(wrap,"%s  /  %d" % [names[key],stats.get(key,0)],22,C_ACCENT if key!="heat" else C_GOLD)
    _space(wrap,12)
    _label(wrap,"Характеристики меняются от решений. Некоторые варианты открываются только при достаточной наблюдательности или доверии.",20,C_MUTED)
    _close_control(wrap)
func _show_menu() -> void:
    var wrap:=_panel("СОХРАНЕНИЯ")
    _label(wrap,"Автосохранение работает после каждого выбора. Три ручных слота доступны ниже.",19,C_MUTED)
    for slot in range(1,4):
        var box:=HBoxContainer.new()
        wrap.add_child(box)
        var value:=slot
        var a:=_button(box,"СОХР. %d" % slot,_save_and_close.bind(value),false,72)
        a.size_flags_horizontal=Control.SIZE_EXPAND_FILL
        var b:=_button(box,"ЗАГР. %d" % slot,_load_and_close.bind(value),false,72)
        b.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    _space(wrap,16)
    _button(wrap,"НОВАЯ ИСТОРИЯ",_new_game,false,72)
    _close_control(wrap)

func _new_game() -> void:
    _reset()
    _enter("prologue")
    _clear_overlay()
func _continue_game() -> void:
    _load(0)
    _clear_overlay()
func _save_name(edit: LineEdit) -> void:
    var trimmed: String=edit.text.strip_edges()
    if not trimmed.is_empty():
        hero_name=trimmed
        _render_scene()
        _autosave()
    _clear_overlay()
func _save_and_close(slot: int) -> void:
    _save(slot)
    _clear_overlay()
func _load_and_close(slot: int) -> void:
    if _load(slot):
        _clear_overlay()
