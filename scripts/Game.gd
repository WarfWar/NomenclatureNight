extends Node3D
# Android graybox with six story phases, two player characters and autosave.
const MISSIONS = ["Партия под дождём","Новый отсчёт","Тюрьма №18","Технический сектор","Испытание","Возвращение"]
const WORLDS = ["outer","outer","inner","inner","dream","outer"]
const HEROES = ["qing","custom","qing","custom","qing","custom"]
const STEPS = [
    ["Шахматы","Обратный отсчёт","Первый переход"],
    ["Создать путешественника","Странная запись","Перемещение"],
    ["Общий зал","Ли Шутон","Шахматная задача","Контрольная точка"],
    ["Патруль","Журнал наблюдения","Судьба улики","Выход"],
    ["Проверка памяти","Учебный бой","Конец испытания"],
    ["Возвращение Цин Чэня","Тайник путешественника","Конец эпизода"]]
var stage: int = 0
var step: int = 0
var suspicion: int = 0
var hits: int = 0
var time_left: float = 480.0
var hero_label: String = "Путешественник"
var character_class: String = "Техник"
var clues: Array[String] = []
var zone: Node3D
var hero: CharacterBody3D
var cam: Camera3D
var marker: Node3D
var canvas: CanvasLayer
var title: Label
var objective_label: Label
var clock: Label
var modal: PanelContainer
var callback: Callable
var modal_visible: bool = false
var yaw: float = 0
var pitch: float = -0.24
func _ready() -> void:
    for k in {"up":KEY_W,"down":KEY_S,"left":KEY_A,"right":KEY_D,"use":KEY_E,"hit":KEY_F}:
        if not InputMap.has_action(k):
            InputMap.add_action(k)
        var event := InputEventKey.new()
        event.physical_keycode = {"up":KEY_W,"down":KEY_S,"left":KEY_A,"right":KEY_D,"use":KEY_E,"hit":KEY_F}[k]
        InputMap.action_add_event(k,event)
    _make_ui()
    _make_zone()
    _show("НОМЕНКЛАТУРА НОЧИ","ДВА МИРА\n\nТестовая версия 0.3 — шесть сюжетных этапов и два персонажа.",["НАЧАТЬ"],func(_i: int): pass)
func _material(col: Color) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = col
    return m
func _block(parent: Node3D, p: Vector3, size: Vector3, col: Color, solid: bool = true) -> Node3D:
    var n: Node3D = StaticBody3D.new() if solid else Node3D.new()
    parent.add_child(n)
    n.position=p
    var mesh:=MeshInstance3D.new()
    var b:=BoxMesh.new()
    b.size=size
    mesh.mesh=b
    mesh.material_override=_material(col)
    n.add_child(mesh)
    if solid:
        var cs:=CollisionShape3D.new()
        var box:=BoxShape3D.new()
        box.size=size
        cs.shape=box
        n.add_child(cs)
    return n
func _make_zone() -> void:
    if is_instance_valid(zone):
        zone.queue_free()
    zone=Node3D.new()
    add_child(zone)
    var env:=WorldEnvironment.new()
    env.environment=Environment.new()
    env.environment.background_mode=Environment.BG_COLOR
    env.environment.background_color=Color("#15283a")
    env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
    env.environment.ambient_light_color=Color("#b8ced8")
    zone.add_child(env)
    var light:=DirectionalLight3D.new()
    light.rotation_degrees=Vector3(-55,22,0)
    light.light_energy=1.5
    zone.add_child(light)
    _block(zone,Vector3(0,-0.7,0),Vector3(65,1.2,48),Color("#3e5364"))
    if WORLDS[stage]=="outer":
        for i in range(6):
            var x:=float(i*10-25)
            _block(zone,Vector3(x,4,-16),Vector3(8,8+float(i%3)*2,8),Color("#435667"))
        _block(zone,Vector3(-6,2,-4),Vector3(8,0.25,5),Color("#687280"),false)
    elif WORLDS[stage]=="inner":
        for i in range(7):
            _block(zone,Vector3(float(i*8-24),3,-18),Vector3(6,6,3),Color("#415b70"))
        _block(zone,Vector3(0,0.1,-8),Vector3(25,0.3,12),Color("#657f8b"),false)
    else:
        for i in range(10):
            _block(zone,Vector3(float(i*5-22),2,-12),Vector3(1,4,1),Color("#735d9a"))
    hero=CharacterBody3D.new()
    zone.add_child(hero)
    hero.position=Vector3(0,0.3,6)
    var c:=CollisionShape3D.new()
    var shape:=CapsuleShape3D.new()
    shape.radius=0.38
    shape.height=1.8
    c.shape=shape
    c.position.y=0.9
    hero.add_child(c)
    var body:=MeshInstance3D.new()
    var capsule:=CapsuleMesh.new()
    capsule.radius=0.35
    capsule.height=1.7
    body.mesh=capsule
    body.position.y=0.9
    body.material_override=_material(Color("#8acdd6") if HEROES[stage]=="qing" else Color("#e5b678"))
    hero.add_child(body)
    marker=Node3D.new()
    zone.add_child(marker)
    marker.position=Vector3(-6,0,-3)
    _block(marker,Vector3(0,0.1,0),Vector3(1,0.25,1),Color("#28cad4"),false)
    var label:=Label3D.new()
    label.text=STEPS[stage][step]
    label.font_size=36
    label.pixel_size=0.008
    label.position=marker.position+Vector3(0,2,0)
    label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
    zone.add_child(label)
    cam=Camera3D.new()
    cam.current=true
    cam.fov=68
    zone.add_child(cam)
    _hud()
func _make_ui() -> void:
    canvas=CanvasLayer.new()
    add_child(canvas)
    var root:=Control.new()
    root.set_anchors_preset(Control.PRESET_FULL_RECT)
    root.mouse_filter=Control.MOUSE_FILTER_IGNORE
    canvas.add_child(root)
    title=Label.new()
    title.position=Vector2(18,10)
    title.add_theme_font_size_override("font_size",24)
    root.add_child(title)
    objective_label=Label.new()
    objective_label.position=Vector2(18,48)
    objective_label.add_theme_font_size_override("font_size",19)
    root.add_child(objective_label)
    clock=Label.new()
    clock.position=Vector2(18,112)
    root.add_child(clock)
    var menu:=Button.new()
    menu.text="МЕНЮ"
    menu.position=Vector2(18,150)
    menu.custom_minimum_size=Vector2(105,48)
    root.add_child(menu)
    menu.pressed.connect(_menu)
    var journal:=Button.new()
    journal.text="ЖУРНАЛ"
    journal.position=Vector2(137,150)
    journal.custom_minimum_size=Vector2(105,48)
    root.add_child(journal)
    journal.pressed.connect(_journal)
    if OS.has_feature("mobile"):
        _touch(root,"▲","up",120,-230)
        _touch(root,"▼","down",120,-162)
        _touch(root,"◀","left",44,-162)
        _touch(root,"▶","right",196,-162)
        _touch(root,"ДЕЙСТВИЕ","use",-185,-230,true)
        _touch(root,"УДАР","hit",-185,-162,true)
func _touch(root: Control, name: String, action: String, x: int, y: int, right: bool = false) -> void:
    var b:=Button.new()
    b.text=name
    b.anchor_left=1.0 if right else 0.0
    b.anchor_right=b.anchor_left
    b.anchor_top=1.0
    b.anchor_bottom=1.0
    b.offset_left=float(x)
    b.offset_right=float(x + (155 if right else 65))
    b.offset_top=float(y)
    b.offset_bottom=float(y+58)
    root.add_child(b)
    b.button_down.connect(func(): Input.action_press(action))
    b.button_up.connect(func(): Input.action_release(action))
func _hud() -> void:
    if not is_instance_valid(title):
        return
    title.text="НОМЕНКЛАТУРА НОЧИ / "+("Цин Чэнь" if HEROES[stage]=="qing" else hero_label)
    objective_label.text="Глава %d/6: %s\nЦель: %s\nПодозрение: %d%%" % [stage+1,MISSIONS[stage],STEPS[stage][step],suspicion]
func _physics_process(d: float) -> void:
    if not is_instance_valid(hero):
        return
    var input:=Vector2.ZERO
    if not modal_visible:
        input=Input.get_vector("left","right","up","down")
    var direction:=Basis(Vector3.UP,yaw)*Vector3(input.x,0,input.y)
    hero.velocity.x=direction.x*5.5
    hero.velocity.z=direction.z*5.5
    hero.velocity.y=-0.2 if hero.is_on_floor() else hero.velocity.y-17.0*d
    hero.move_and_slide()
    cam.position=hero.position+Basis(Vector3.UP,yaw)*Vector3(0,3.1+pitch*2,6.5)
    cam.look_at(hero.position+Vector3(0,1.3,0))
    if not modal_visible and Input.is_action_just_pressed("use"):
        _interact()
    if not modal_visible and Input.is_action_just_pressed("hit"):
        _strike()
func _unhandled_input(e: InputEvent) -> void:
    if modal_visible:
        return
    if e is InputEventScreenDrag and e.position.x>get_viewport().get_visible_rect().size.x*0.4:
        yaw-=e.relative.x*0.004
        pitch=clampf(pitch+e.relative.y*0.002,-0.7,0.4)
    if e is InputEventMouseMotion and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED:
        yaw-=e.relative.x*0.004
        pitch=clampf(pitch+e.relative.y*0.002,-0.7,0.4)
    if e is InputEventMouseButton and e.pressed:
        Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
func _process(d: float) -> void:
    if not modal_visible:
        time_left=maxf(0.0,time_left-d)
    var t:=int(time_left)
    clock.text="ОТСЧЁТ: %02d:%02d:%02d" % [int(t/3600),int(t/60)%60,t%60]
func _interact() -> void:
    if hero.position.distance_to(marker.position)>3.7:
        return
    if stage==1 and step==0:
        _show("ВТОРОЙ ПУТЕШЕСТВЕННИК","Выбери предысторию.",["ТЕХНИК","АНАЛИТИК","БЕГУН"],func(i: int):
            character_class=["Техник","Аналитик","Бегун"][i]
            _advance())
    elif stage==3 and step==2:
        _show("СЛУЖЕБНЫЙ ЖУРНАЛ","Как поступить с доказательством?",["СКОПИРОВАТЬ","УДАЛИТЬ","ДОГОВОРИТЬСЯ"],func(i: int):
            clues.append(["Копия журнала","Журнал удалён","Техник — союзник"][i])
            suspicion=clampi(suspicion+[25,-10,-5][i],0,100)
            _advance())
    elif stage==4 and step==1:
        _strike()
    else:
        if stage==0 and step==0:
            clues.append("Шахматная партия")
        if stage==3 and step==1:
            clues.append("Изменённые временные метки")
        _show("СЮЖЕТ",STEPS[stage][step],["ПРОДОЛЖИТЬ"],func(_i: int): _advance())
func _strike() -> void:
    if stage!=4 or step!=1 or hero.position.distance_to(marker.position)>3.7:
        return
    hits+=1
    if hits>=3:
        _show("ИСПЫТАНИЕ","Три попадания! Испытание завершено.",["ДАЛЬШЕ"],func(_i: int): _advance())
    else:
        _show("ИСПЫТАНИЕ","Попадание %d/3" % hits,["ПРОДОЛЖИТЬ"],func(_i: int): pass)
func _advance() -> void:
    step+=1
    if step>=STEPS[stage].size():
        stage+=1
        step=0
        if stage>=6:
            stage=5
            step=STEPS[stage].size()-1
            _show("КОНЕЦ ЭПИЗОДА","Вы прошли шесть сюжетных глав.",["СОХРАНИТЬ"],func(_i: int): _save())
            return
        time_left=172800
    _make_zone()
    _save()
func _show(heading: String, body: String, options: Array, cb: Callable) -> void:
    if is_instance_valid(modal):
        modal.queue_free()
    modal_visible=true
    callback=cb
    modal=PanelContainer.new()
    modal.set_anchors_preset(Control.PRESET_CENTER)
    var viewport:=get_viewport().get_visible_rect().size
    var w:=minf(355.0,viewport.x*0.43)
    var h:=minf(220.0,viewport.y*0.42)
    modal.offset_left=-w
    modal.offset_right=w
    modal.offset_top=-h
    modal.offset_bottom=h
    canvas.add_child(modal)
    var col:=VBoxContainer.new()
    modal.add_child(col)
    var l:=Label.new()
    l.text=heading+"\n\n"+body
    l.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    l.size_flags_vertical=Control.SIZE_EXPAND_FILL
    l.add_theme_font_size_override("font_size",22)
    col.add_child(l)
    for i in range(options.size()):
        var b:=Button.new()
        b.text=str(options[i])
        b.custom_minimum_size.y=44
        col.add_child(b)
        b.pressed.connect(_pick.bind(i))
    Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
func _pick(i: int) -> void:
    var selected:=callback
    if is_instance_valid(modal):
        modal.queue_free()
    modal_visible=false
    if selected.is_valid():
        selected.call(i)
func _menu() -> void:
    if modal_visible:
        return
    _show("МЕНЮ","Локальное сохранение первого слота.",["ПРОДОЛЖИТЬ","СОХРАНИТЬ","ЗАГРУЗИТЬ","НАЧАТЬ ЗАНОВО"],func(i: int):
        if i == 1:
            _save()
        elif i == 2:
            _load()
        elif i == 3:
            stage=0
            step=0
            suspicion=0
            clues.clear()
            _make_zone()
    )
func _journal() -> void:
    if modal_visible:
        return
    var content: String="Предыстория: "+character_class+"\n"
    for item in clues:
        content+="\n• "+item
    _show("ЖУРНАЛ",content,["ЗАКРЫТЬ"],func(_i: int): pass)
func _save() -> void:
    var f:=FileAccess.open("user://night.json",FileAccess.WRITE)
    if f!=null:
        f.store_string(JSON.stringify({"stage":stage,"step":step,"suspicion":suspicion,"clues":clues,"time":time_left,"class":character_class}))
        f.close()
func _load() -> void:
    if not FileAccess.file_exists("user://night.json"):
        return
    var d: Variant=JSON.parse_string(FileAccess.get_file_as_string("user://night.json"))
    if typeof(d)!=TYPE_DICTIONARY:
        return
    stage=clampi(int(d.get("stage",0)),0,5)
    step=clampi(int(d.get("step",0)),0,STEPS[stage].size()-1)
    suspicion=clampi(int(d.get("suspicion",0)),0,100)
    clues.clear()
    for item in d.get("clues",[]):
        clues.append(str(item))
    time_left=float(d.get("time",480.0))
    character_class=str(d.get("class","Техник"))
    _make_zone()
