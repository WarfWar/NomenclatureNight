class_name ShiftGame
extends RefCounted

const DISTRICTS = [
    {"id":"port","name":"Неоновый порт","subtitle":"Рынки и грузовые линии","danger":2,"color":"#2a6472"},
    {"id":"factory","name":"Заводской пояс","subtitle":"Сталь, сборочные линии","danger":3,"color":"#9b784b"},
    {"id":"archive","name":"Архивный квартал","subtitle":"Серверы и закрытые данные","danger":4,"color":"#5367a8"},
    {"id":"station","name":"Станция 17","subtitle":"Пути и контрольные посты","danger":3,"color":"#637489"},
    {"id":"crown","name":"Верхний город","subtitle":"Корпорации и прототипы","danger":5,"color":"#956387"},
    {"id":"undercity","name":"Подземные доки","subtitle":"Тоннели и тайные склады","danger":4,"color":"#51796b"}
]
const OPERATIONS = [
    {"id":"port_wire","district":"port","name":"Прослушка грузовой сети","type":"tech","hours":5,"chance":78,"heat":6,"loot":{"intel":2,"credits":70}},
    {"id":"port_trade","district":"port","name":"Обмен у контрабандистов","type":"social","hours":7,"chance":69,"heat":9,"loot":{"modules":1,"credits":120}},
    {"id":"factory_scrap","district":"factory","name":"Разобрать промышленный узел","type":"tech","hours":6,"chance":80,"heat":8,"loot":{"alloy":3}},
    {"id":"factory_drone","district":"factory","name":"Перехват грузового дрона","type":"stealth","hours":9,"chance":66,"heat":14,"loot":{"modules":2,"alloy":1}},
    {"id":"archive_query","district":"archive","name":"Считать научный архив","type":"tech","hours":8,"chance":72,"heat":11,"loot":{"data":3}},
    {"id":"archive_cipher","district":"archive","name":"Похитить ключ шифрования","type":"stealth","hours":7,"chance":66,"heat":13,"loot":{"intel":3,"data":1}},
    {"id":"station_cache","district":"station","name":"Забрать контейнер на станции","type":"stealth","hours":5,"chance":76,"heat":8,"loot":{"alloy":2,"credits":75}},
    {"id":"station_patrol","district":"station","name":"Изучить патрули охраны","type":"stealth","hours":5,"chance":83,"heat":0,"loot":{"intel":2},"cool":9},
    {"id":"crown_broker","district":"crown","name":"Договориться с посредником","type":"social","hours":7,"chance":71,"heat":11,"loot":{"credits":270,"data":1}},
    {"id":"crown_proto","district":"crown","name":"Выкрасть экспериментальный модуль","type":"stealth","hours":12,"chance":50,"heat":23,"loot":{"modules":3,"data":2}},
    {"id":"under_stash","district":"undercity","name":"Найти тайник в тоннелях","type":"stealth","hours":6,"chance":75,"heat":8,"loot":{"alloy":2,"data":1}},
    {"id":"under_lab","district":"undercity","name":"Проникнуть в старую лабораторию","type":"tech","hours":10,"chance":57,"heat":16,"loot":{"data":3,"modules":1}}
]
const AGENTS = [
    {"id":"lea","name":"Лея Восс","role":"Разведчик","desc":"Тихие проникновения и обход патрулей","speciality":"stealth","skills":{"stealth":4,"tech":1,"social":2},"fee":0},
    {"id":"nord","name":"Норд Кейн","role":"Инженер","desc":"Взлом, архивы и оборудование","speciality":"tech","skills":{"stealth":1,"tech":4,"social":1},"fee":630},
    {"id":"rey","name":"Рей Марш","role":"Посредник","desc":"Сделки, контакты и торговля","speciality":"social","skills":{"stealth":2,"tech":1,"social":4},"fee":690}
]
const BUILDINGS = [
    {"id":"lab","name":"Исследовательский модуль","desc":"Открывает научные проекты","credits":450,"alloy":2,"max":1},
    {"id":"safehouse","name":"Защищённое убежище","desc":"Снижает подозрение при возвращении","credits":400,"alloy":3,"max":3},
    {"id":"storage","name":"Контейнерный склад","desc":"Увеличивает объём переносимого груза","credits":370,"alloy":2,"max":3}
]
const RESEARCH = [
    {"id":"scanner","name":"Сканер траекторий","desc":"+9% к успеху операций","credits":280,"data":3,"lab":1},
    {"id":"filter","name":"Тихий протокол","desc":"Подозрение от операций снижается на 4","credits":240,"data":2,"lab":1},
    {"id":"cargo","name":"Усиленные контейнеры","desc":"+1 единица добычи основного ресурса","credits":350,"data":4,"lab":1}
]
const FILE_PATH = "user://shift48_v01.json"

var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var mode: String = "outer"
var cycle: int = 1
var day: int = 1
var hours_left: int = 48
var credits: int = 920
var alloy: int = 0
var data: int = 0
var modules: int = 0
var intel: int = 0
var heat: int = 7
var operations_done: int = 0
var successful: int = 0
var sold_units: int = 0
var active_agent: String = "lea"
var hired: Array[String] = ["lea"]
var fatigue: Dictionary = {"lea":0,"nord":0,"rey":0}
var buildings: Dictionary = {"lab":0,"safehouse":0,"storage":0}
var researched: Array[String] = []
var logbook: Array[String] = []
var last_event: String = "Получен сигнал. До первого перемещения осталось совсем немного."
var selected: String = "port"

func _init() -> void:
    rng.randomize()

func _log(text: String) -> void:
    last_event = text
    logbook.push_front("Цикл %d • %s" % [cycle,text])
    if logbook.size() > 40:
        logbook.resize(40)

func reset() -> void:
    mode="outer"
    cycle=1
    day=1
    hours_left=48
    credits=920
    alloy=0
    data=0
    modules=0
    intel=0
    heat=7
    operations_done=0
    successful=0
    sold_units=0
    active_agent="lea"
    hired=["lea"]
    fatigue={"lea":0,"nord":0,"rey":0}
    buildings={"lab":0,"safehouse":0,"storage":0}
    researched=[]
    logbook=[]
    selected="port"
    _log("Штаб активирован. Первая цель: добыть ресурсы и открыть лабораторию.")
    save_game()

func start_shift() -> void:
    if mode=="inner":
        return
    mode="inner"
    hours_left=48
    _log("Переход выполнен. Во Внутреннем мире доступно 48 часов.")
    save_game()

func return_home() -> void:
    if mode=="outer":
        return
    mode="outer"
    cycle+=1
    day+=2
    var recovery: int=11+int(buildings.get("safehouse",0))*9
    heat=maxi(0,heat-recovery)
    for a in hired:
        fatigue[a]=maxi(0,int(fatigue.get(a,0))-3)
    _log("Возвращение домой. Подозрение снижено, команда восстановила силы.")
    save_game()

func can_carry_more() -> bool:
    return alloy+data+modules < cargo_limit()

func cargo_limit() -> int:
    return 10+int(buildings.get("storage",0))*6

func get_agent(id: String) -> Dictionary:
    for a in AGENTS:
        if a["id"]==id:
            return a
    return AGENTS[0]

func get_district(id: String) -> Dictionary:
    for d in DISTRICTS:
        if d["id"]==id:
            return d
    return DISTRICTS[0]

func get_ops(id: String) -> Array:
    var out: Array=[]
    for o in OPERATIONS:
        if o["district"]==id:
            out.append(o)
    return out

func chance(op: Dictionary) -> int:
    var agent: Dictionary=get_agent(active_agent)
    var skill: int=int(agent["skills"].get(op["type"],1))
    var tired: int=int(fatigue.get(active_agent,0))
    var n: int=int(op["chance"])+(skill-2)*7-int(round(float(heat)*0.2))-tired*3
    if researched.has("scanner"):
        n+=9
    return clampi(n,25,95)

func operate(id: String) -> void:
    if mode!="inner":
        return
    var op: Dictionary={}
    for o in OPERATIONS:
        if o["id"]==id:
            op=o
            break
    if op.is_empty():
        return
    if hours_left<int(op["hours"]):
        _log("Не хватает времени для этой операции.")
        return
    if not can_carry_more() and int(op["loot"].get("credits",0))==0 and int(op["loot"].get("intel",0))==0:
        _log("Грузовой отсек заполнен. Возвращайся или выбирай разведку.")
        return
    var likelihood: int=chance(op)
    hours_left-=int(op["hours"])
    operations_done+=1
    fatigue[active_agent]=mini(6,int(fatigue.get(active_agent,0))+1)
    var success: bool=rng.randi_range(1,100)<=likelihood
    if success:
        successful+=1
        var items: Dictionary=op["loot"]
        var parts: Array[String]=[]
        for key in ["alloy","data","modules","intel","credits"]:
            var quantity: int=int(items.get(key,0))
            if quantity<=0:
                continue
            if researched.has("cargo") and key!="credits" and key!="intel":
                quantity+=1
            if key=="alloy" or key=="data" or key=="modules":
                quantity=mini(quantity,maxi(0,cargo_limit()-alloy-data-modules))
            if quantity<=0:
                continue
            set(key,int(get(key))+quantity)
            parts.append("%s +%d" % [resource_name(key),quantity])
        heat=clampi(heat+maxi(0,int(op["heat"])-(4 if researched.has("filter") else 0))-int(op.get("cool",0)),0,100)
        _log("Успех: %s. %s" % [op["name"],", ".join(parts)])
    else:
        heat=clampi(heat+int(op["heat"])+8,0,100)
        _log("Провал: %s. Служба безопасности заметила следы группы." % op["name"])
    if heat>=95:
        heat=65
        hours_left=0
        _log("Тревога! Экстренный выход из зоны. Часть времени потеряна.")
    if hours_left<=0:
        return_home()
    else:
        save_game()

func resource_name(key: String) -> String:
    match key:
        "credits": return "Кредиты"
        "alloy": return "Сплав"
        "data": return "Данные"
        "modules": return "Модули"
        "intel": return "Разведка"
    return key

func sell(key: String) -> void:
    if mode!="outer":
        return
    var prices: Dictionary={"alloy":90,"data":125,"modules":240,"intel":55}
    if not prices.has(key):
        return
    var available: int=int(get(key))
    if available<=0:
        _log("Нет товара для продажи.")
        return
    set(key,available-1)
    credits+=int(prices[key])
    sold_units+=1
    _log("Продано: %s. Получено %d кредитов." % [resource_name(key),int(prices[key])])
    save_game()

func upgrade(id: String) -> void:
    if mode!="outer":
        return
    for building in BUILDINGS:
        if building["id"]==id:
            var lvl: int=int(buildings.get(id,0))
            if lvl>=int(building["max"]):
                return
            var price: int=int(building["credits"])+lvl*200
            var metal: int=int(building["alloy"])+lvl
            if credits<price or alloy<metal:
                _log("Не хватает ресурсов для улучшения.")
                return
            credits-=price
            alloy-=metal
            buildings[id]=lvl+1
            _log("%s: построено улучшение уровня %d." % [building["name"],lvl+1])
            save_game()
            return

func research(id: String) -> void:
    if mode!="outer" or researched.has(id):
        return
    for p in RESEARCH:
        if p["id"]==id:
            if int(buildings.get("lab",0))<int(p["lab"]):
                _log("Для исследований требуется лаборатория.")
                return
            if credits<int(p["credits"]) or data<int(p["data"]):
                _log("Недостаточно ресурсов для исследования.")
                return
            credits-=int(p["credits"])
            data-=int(p["data"])
            researched.append(id)
            _log("Изучено: %s." % p["name"])
            save_game()
            return

func recruit(id: String) -> void:
    if mode!="outer" or hired.has(id):
        return
    var agent: Dictionary=get_agent(id)
    if credits<int(agent["fee"]):
        _log("Не хватает кредитов для найма.")
        return
    credits-=int(agent["fee"])
    hired.append(id)
    _log("Нанят агент: %s." % agent["name"])
    save_game()

func select_agent(id: String) -> void:
    if not hired.has(id):
        return
    active_agent=id
    _log("Выбран активный агент: %s." % get_agent(id)["name"])
    save_game()

func objective() -> String:
    if operations_done<3:
        return "Проведи 3 операции во Внутреннем мире (%d/3)." % operations_done
    if int(buildings.get("lab",0))==0:
        return "Собери 2 сплава и построй исследовательский модуль."
    if not researched.has("scanner"):
        return "Собери 3 пакета данных и исследуй сканер траекторий."
    if hired.size()<2:
        return "Найми второго агента, чтобы расширить возможности."
    return "Штаб развит. Изучай районы и расширяй организацию!"

func save_game() -> void:
    var payload: Dictionary={
        "mode":mode,"cycle":cycle,"day":day,"hours_left":hours_left,
        "credits":credits,"alloy":alloy,"data":data,"modules":modules,"intel":intel,
        "heat":heat,"operations_done":operations_done,"successful":successful,
        "sold_units":sold_units,"active_agent":active_agent,"hired":hired,
        "fatigue":fatigue,"buildings":buildings,"researched":researched,
        "selected":selected,"logbook":logbook,"last_event":last_event
    }
    var f: FileAccess=FileAccess.open(FILE_PATH,FileAccess.WRITE)
    if f!=null:
        f.store_string(JSON.stringify(payload))
        f.close()

func load_game() -> bool:
    if not FileAccess.file_exists(FILE_PATH):
        return false
    var parsed: Variant=JSON.parse_string(FileAccess.get_file_as_string(FILE_PATH))
    if typeof(parsed)!=TYPE_DICTIONARY:
        return false
    var d: Dictionary=parsed
    mode=str(d.get("mode","outer"))
    if mode!="outer" and mode!="inner":
        mode="outer"
    cycle=clampi(int(d.get("cycle",1)),1,999999)
    day=clampi(int(d.get("day",1)),1,999999)
    hours_left=clampi(int(d.get("hours_left",48)),0,48)
    credits=maxi(0,int(d.get("credits",920)))
    alloy=maxi(0,int(d.get("alloy",0)))
    data=maxi(0,int(d.get("data",0)))
    modules=maxi(0,int(d.get("modules",0)))
    intel=maxi(0,int(d.get("intel",0)))
    heat=clampi(int(d.get("heat",7)),0,100)
    operations_done=maxi(0,int(d.get("operations_done",0)))
    successful=maxi(0,int(d.get("successful",0)))
    sold_units=maxi(0,int(d.get("sold_units",0)))
    active_agent=str(d.get("active_agent","lea"))
    hired.clear()
    for a in d.get("hired",["lea"]):
        if ["lea","nord","rey"].has(str(a)):
            hired.append(str(a))
    if not hired.has("lea"):
        hired.append("lea")
    if not hired.has(active_agent):
        active_agent="lea"
    fatigue=d.get("fatigue",{"lea":0,"nord":0,"rey":0})
    buildings=d.get("buildings",{"lab":0,"safehouse":0,"storage":0})
    researched.clear()
    for a in d.get("researched",[]):
        if ["scanner","filter","cargo"].has(str(a)):
            researched.append(str(a))
    selected=str(d.get("selected","port"))
    logbook.clear()
    for x in d.get("logbook",[]):
        logbook.append(str(x))
    last_event=str(d.get("last_event","Продолжаем операцию."))
    return true
