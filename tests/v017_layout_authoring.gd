extends SceneTree
func _initialize() -> void:
	var data:=ArenaLevelCatalog.definition("ruins");var roads: Array=[]
	for points in data.routes:roads.append(ArenaLevelCatalog.curve(points))
	var detour:=ArenaLevelCatalog.curve(data.bridge_gate.detour);detour.set_point_in(2,roads[1].get_point_in(2))
	var sampled: Array=[]
	for road in roads+[detour]:
		var points: Array=[]
		for point in road.get_baked_points():points.append([point.x,point.y])
		sampled.append(points)
	var output:=FileAccess.open("res://test-results/v017-layout-curves.json",FileAccess.WRITE)
	output.store_string(JSON.stringify(sampled));output.close()
	for index in range(data.sites.size()):
		var site: Vector2=data.sites[index];var nearest:=INF;var neighbour:=INF
		for curve in roads:nearest=minf(nearest,site.distance_to(curve.sample_baked(curve.get_closest_offset(site),true)))
		for other in range(data.sites.size()):
			if other!=index:neighbour=minf(neighbour,site.distance_to(data.sites[other]))
		print(index," ",site," road=",snappedf(nearest,0.1)," neighbour=",snappedf(neighbour,0.1))
	for lane in range(roads.size()):
		var road: Curve2D=roads[lane];var begin:=-1
		for offset in range(0,int(road.get_baked_length())+1,5):
			var point:=road.sample_baked(offset,true);var near:=INF
			for site in data.sites:near=minf(near,point.distance_to(site))
			if near>=220 and begin<0:begin=offset
			if near<220 and begin>=0:
				if offset-begin>120:print("GAP ",lane," ",offset-begin," at ",road.sample_baked((begin+offset)*0.5,true))
				begin=-1
	quit()
