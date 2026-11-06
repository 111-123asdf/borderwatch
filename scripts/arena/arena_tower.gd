class_name ArenaTower
extends Node2D
const MAX_LEVEL:=3
var game: Node2D
var kind: String="archer"
var site_id:=0
var level:=1
var data: Dictionary={}
var destroyed:=false
var attack_clock:=0.0
var fire_clock:=0.0
var rally_point:=Vector2.ZERO
var target_mode: String="first"
var troops: Array=[]
var body: Sprite2D
static var art_cache: Dictionary={}
func _ready() -> void:
	data=ArenaDefinitions.tower(kind);body=Sprite2D.new();body.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR;add_child(body);refresh_art()
	var obstacle:=StaticBody2D.new();obstacle.collision_layer=1;obstacle.collision_mask=2
	var collision:=CollisionShape2D.new();var circle:=CircleShape2D.new();circle.radius=25;collision.shape=circle;obstacle.add_child(collision);add_child(obstacle)
	var anchor: Vector2=game.nearest_road(position).point
	rally_point=anchor
	if kind=="barracks":
		for index in range(3):
			var soldier:=ArenaSoldier.new();soldier.game=game;soldier.tower=self;soldier.slot=index;soldier.position=anchor+Vector2((index-1)*20,8+index%2*15)
			game.actors.add_child(soldier);game.soldiers.append(soldier);troops.append(soldier)
func refresh_art() -> void:
	var key: String=kind+str(level)
	if not art_cache.has(key):
		var path: String="res://assets/v06/towers.png"
		if ResourceLoader.exists(path):
			var atlas:=AtlasTexture.new();var sheet: Texture2D=load(path);atlas.atlas=sheet
			var column: int=ArenaDefinitions.TOWER_IDS.find(kind)
			atlas.region=Rect2(column*sheet.get_width()/4.0,(level-1)*sheet.get_height()/3.0,sheet.get_width()/4.0,sheet.get_height()/3.0)
			art_cache[key]=atlas
	if art_cache.has(key):
		body.texture=art_cache[key]
		var width: float=(111.0+level*7) if kind in ["archer","mage"] else (120.0+level*11)
		body.scale=Vector2.ONE*width/body.texture.get_width();body.position.y=-body.texture.get_height()*body.scale.y*ArenaArtAnchors.offset_for("tower_"+kind+"_"+str(level))
func upgrade_price() -> int:return int(data.cost)*(level+1)/2+35
func attack_range() -> float:return float(data.reach)+(level-1)*16
func upgrade() -> bool:
	if level>=3 or destroyed or game.gold<upgrade_price():return false
	game.gold-=upgrade_price();level+=1;refresh_art()
	for soldier in troops:
		if is_instance_valid(soldier):soldier.refresh_stats()
	game.effect(position,65,Color("f4d28b"),"upgrade",0.55);game.audio.play("tower");game.hud.refresh_context();return true
func sell() -> bool:
	if destroyed:return false
	destroyed=true;game.gold+=int(float(data.cost)*0.6+float(level-1)*data.cost*0.25)
	for soldier in troops:
		if is_instance_valid(soldier):game.blocking.release(soldier);game.soldiers.erase(soldier);soldier.queue_free()
	game.towers.erase(self);game.rebuild_navigation();queue_free();game.hud.close_context();return true
func set_rally(point: Vector2) -> bool:
	if kind!="barracks" or destroyed:return false
	var closest: Dictionary=game.nearest_road(point)
	if position.distance_to(closest.point)>145:return false
	rally_point=closest.point;game.effect(rally_point,25,Color("e9c37e"),"flag",0.5);return true
func _physics_process(delta: float) -> void:
	if not game.running or game.game_over or destroyed:return
	attack_clock=maxf(0,attack_clock-delta);fire_clock=maxf(0,fire_clock-delta)
	if kind=="barracks":return
	if attack_clock<=0:
		var enemy: Node2D=game.tower_target(self)
		if enemy!=null:
			attack_clock=float(data.interval)/(1+0.14*(level-1))
			var power: float=float(data.damage)*(1+0.6*(level-1))*game.support_scale(position)
			if kind=="cannon":
				game.delayed_attack(enemy.position,64+(level-1)*12,power,0,"tower",0.45,{"origin":position+Vector2(0,-45),"cannon":true})
			else:
				game.fire_projectile(position+Vector2(0,-65),enemy.center(),power,int(data.type),"tower",{"target":enemy,"appearance":"magic" if kind=="mage" else "arrow","pierce":1 if kind=="archer" and level==3 else 0})
			fire_clock=0.13;game.audio.play("tower",-16)
	body.rotation=sin(fire_clock*30)*0.025
	queue_redraw()
func _draw() -> void:
	draw_set_transform(Vector2.ZERO,0,Vector2(1,0.38));draw_circle(Vector2.ZERO,35,Color(0.1,0.13,0.07,0.26));draw_set_transform(Vector2.ZERO)
	if game.selected_site==site_id:
		draw_arc(Vector2.ZERO,attack_range(),0,TAU,72,Color(data.colour,0.3),2,true)
