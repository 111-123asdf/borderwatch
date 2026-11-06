extends SceneTree
# Authored layout geometry checks. Samples actual Curve2D used by live enemies.
var checks:=0
var failures:=0
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error("LAYOUT FAIL: "+message)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	for stage in ArenaLevelCatalog.IDS:
		var data:=ArenaLevelCatalog.definition(stage);var roads: Array=[]
		for points in data.routes:roads.append(ArenaLevelCatalog.curve(points))
		check(data.sites.size()==(8 if stage=="forest" else 10),stage+" site count")
		for i in range(data.sites.size()):
			var p: Vector2=data.sites[i];var closest:=INF;var coverage:=0.0;var neighbour:=INF
			for road in roads:
				closest=minf(closest,p.distance_to(road.sample_baked(road.get_closest_offset(p),true)))
				for offset in range(0,int(road.get_baked_length()),5):
					if p.distance_to(road.sample_baked(offset,true))<220:coverage+=5
			for j in range(data.sites.size()):
				if i!=j:neighbour=minf(neighbour,p.distance_to(data.sites[j]))
			check(closest>=75 and closest<=145,stage+" site %d road clearance/rally access"%i)
			check(neighbour>=160,stage+" site %d building separation"%i)
			check(coverage>=250,stage+" site %d useful firing coverage"%i)
			check(p.y-120>=86,stage+" site %d roof below HUD"%i)
			for obstacle in data.blocked:check(not obstacle.grow(25).has_point(p),stage+" build footprint outside terrain")
		for lane in range(roads.size()):
			var road: Curve2D=roads[lane];var uncovered:=0;var gap:=0;var longest:=0;var samples:=0
			for offset in range(35,int(road.get_baked_length())-40,5):
				var p: Vector2=road.sample_baked(offset,true)
				if not Rect2(0,88,1600,812).has_point(p):continue
				samples+=1
				for obstacle in data.blocked:check(not obstacle.grow(12).has_point(p),stage+" main road clear")
				var covered:=false
				for site in data.sites:
					if site.distance_to(p)<220:covered=true;break
				if not covered:uncovered+=1;gap+=5;longest=maxi(longest,gap)
				else:gap=0
			print("COVERAGE ",stage," lane",lane," ",snappedf(100.0*(samples-uncovered)/samples,0.1),"% max gap ",longest)
			check(longest<=180,stage+" no long indefensible road segment")
		if stage=="creek":
			check(roads[0].get_baked_length()>roads[1].get_baked_length()*1.15,"distinct lane lengths")
			check(data.routes[0][0].x<0 and data.routes[1][0].y>900,"distinct west and south entrances")
			check(absf(data.bridges[0].x-data.bridges[1].x)>100,"bridges deliberately offset")
		for n in range(1,9):
			var wave:=ArenaLevelCatalog.wave(stage,n)
			check(not wave.units.is_empty(),"authored wave "+str(n))
			for group in wave.units:check(group[0] in ArenaDefinitions.ENEMIES and group[1]>0,"valid authored group")
	print("V06 LAYOUT CHECKS: %d, FAILURES: %d"%[checks,failures]);quit(0 if failures==0 else 1)
