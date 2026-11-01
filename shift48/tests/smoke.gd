extends SceneTree

func check(ok: bool, description: String) -> void:
    if not ok:
        push_error("FAIL: "+description)
        quit(1)

func _initialize() -> void:
    var game: ShiftGame=ShiftGame.new()
    game.reset()
    check(game.mode=="outer","outer world on new game")
    check(ShiftGame.DISTRICTS.size()==6,"six districts")
    check(ShiftGame.OPERATIONS.size()==12,"twelve operations")
    check(game.credits>0 and game.hired.has("lea"),"initial starter resources")
    game.start_shift()
    check(game.mode=="inner" and game.hours_left==48,"start shift")
    game.rng.seed=1
    game.operate("factory_scrap")
    check(game.operations_done==1 and game.hours_left==42,"an operation spends time")
    game.return_home()
    check(game.mode=="outer" and game.cycle==2,"return and cycle progression")
    game.credits=5000
    game.alloy=20
    game.data=20
    game.upgrade("lab")
    check(int(game.buildings["lab"])==1,"lab upgrade")
    game.research("scanner")
    check(game.researched.has("scanner"),"research tech")
    game.recruit("nord")
    check(game.hired.has("nord"),"agent recruitment")
    game.select_agent("nord")
    check(game.active_agent=="nord","agent selection")
    game.save_game()
    var loaded: ShiftGame=ShiftGame.new()
    check(loaded.load_game(),"save file readable")
    check(loaded.active_agent=="nord" and loaded.researched.has("scanner"),"state restored")
    print("PASS: Shift48 mechanics smoke test")
    quit(0)
