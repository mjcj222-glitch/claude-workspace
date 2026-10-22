extends SceneTree
const Store=preload("res://scripts/board_checkpoint.gd")
var checks=0
var failures=0
func check(ok,label):
 checks+=1
 if not ok:failures+=1;printerr("FAIL ",label)
 else:print("PASS ",label)
func tap(v,at):v.press(at,-1);v.release(at,-1)
func _initialize():call_deferred("run")
func run():
 var v=load("res://main.tscn").instantiate();root.add_child(v);v.set_process(false)
 preload("res://tests/enter_adventure.gd").enter(v)
 var s=v.session;var old=Store.capture(v)
 s.current_node="safe";s.history=["entry","rest","safe"];s.visited={"entry":true,"rest":true,"safe":true};s.paid_nodes={"entry":true,"safe":true};s.battles_entered=2
 s.phase="reward";s.relics=["pigment"];s.rewards_taken=1;s.reward_round=2;s.reward_options=["lens","ash"]
 s.combat.enemy_hp=0;s.combat._victory_counted=true
 var legacy=Store.capture(v)
 check(Store.valid(legacy),"version1 legacy unclaimed offer remains valid unchanged")
 var store=Store.new("/tmp/chroma-petal-state-"+str(OS.get_process_id()))
 check(store.save(legacy),"legacy-shaped fixture writes")
 var bytes=FileAccess.get_file_as_bytes(store.directory+"/current.json")
 var loaded=store.load_run();Store.restore(v,loaded.data)
 check(v.session.reward_options==["lens","ash"] and FileAccess.get_file_as_bytes(store.directory+"/current.json")==bytes,"load preserves legacy offers and bytes; no reroll")
 s=v.session;s.reward_options=s.Relics.available(s.relics)
 check(s.reward_options==["lens","ash","petal"],"new reward has bounded third alternative")
 tap(v,v.UI.reward_rect(2,3).get_center())
 check(s.relics==["pigment","petal"] and s.phase=="map","actual reward gesture acquires petal")
 var serial=s.offer_serial;v.release(v.UI.reward_rect(2,3).get_center(),-1)
 check(s.relics.size()==2 and s.offer_serial==serial,"stale reward release cannot duplicate")
 var data=Store.capture(v);check(store.save(data),"petal transaction checkpoint valid")
 var rng=v.rng.state;Store.restore(v,store.load_run().data)
 check(Store.capture(v)==data and v.rng.state==rng,"petal resume preserves exact state and RNG")
 var bad=data.duplicate(true);bad.session.relics.append("unrecognised")
 check(not Store.valid(bad),"unknown catalogue remains rejected")
 # Shop old-stock semantics remain exactly the same; new reward ownership
 # can fill its remaining slot once without a fourth relic or duplicate sale.
 s=v.session;s.phase="shop";s.gold=20;s.shop_closed=false
 check(s.shop_remaining_relic()=="lens","petal build still has explicit shop stock")
 check(s.buy_shop("relic") and s.relics==["pigment","petal","lens"] and s.gold==12,"third relic costs eight once")
 check(not s.buy_shop("relic") and s.gold==12 and s.Relics.available(s.relics).is_empty(),"three-slot cap and sold guard")
 s.relics=["pigment","lens"];s.shop_relic_sold=false
 check(s.shop_remaining_relic()=="ash","legacy shop stock stays ash")
 s.relics=["pigment"]
 check(s.shop_remaining_relic()=="","legacy empty shop stays empty")
 var ui=v.UI
 check(ui.intent_lines({"intent":"slam","incoming_damage":10},true)[1].contains("하트3"),"new option telegraphed")
 check(ui.intent_lines({"intent":"plain","incoming_damage":6},true)[1]=="","plain attack never promises guard")
 check(ui.RELIC_COPY.petal.lines[0].contains("2 → 1"),"cost visible before acquisition")
 check(v.UI.RelicArt._texture("petal")!=null,"original icon loads")
 await preload("res://tests/audio_teardown.gd").release(v,self)
 print("PETAL_STATE checks=",checks," failures=",failures);quit(1 if failures else 0)
