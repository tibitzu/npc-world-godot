class_name Job
extends RefCounted
## A resident's day job. While they're on duty (and nobody is playing them, and it isn't
## bedtime) the job decides where they go and what they do, a step at a time; off duty they
## stroll and chat as usual. Each kind of job is a script in this folder (see make()).
##
## A job's step() runs every physics frame while on duty. It walks the resident somewhere with
## go(), checks arrived(), and waits with wait()/waiting(); all times are game seconds.

var r: Resident
var working := false               # on duty right now
var _wait_left := 0.0
var _goal := Vector3.INF           # where go() last sent them
var _tries := 0                    # how often they've been sent there without getting there


static func make(res: Resident) -> Job:
	match res.def.job:
		"shop": return ShopJob.new(res)
		"woodcutter": return WoodcutterJob.new(res)
		"post": return PostJob.new(res)
		"lamplighter": return LamplighterJob.new(res)
		"patrol": return PatrolJob.new(res)
	return null


func _init(res: Resident) -> void:
	r = res


## Are they due at work at this local hour? (A shift may run past midnight.)
func on_duty(h: float) -> bool:
	var a := r.def.work_from
	var b := r.def.work_to
	return (h >= a and h < b) if a < b else (h >= a or h < b)


## Called every physics frame while the job may run; true while it's in charge of them.
func tick(delta: float) -> bool:
	if not on_duty(Game.local_hours(r.position.x)):
		if working:
			finish()
		return false
	if not working:
		working = true
		_goal = Vector3.INF
		r.work_speed = r.def.work_speed
		start()
	return step(delta)


## Off duty, bedtime, or someone took them over: put things away, forget the plan.
func finish() -> void:
	working = false
	_wait_left = 0.0
	_goal = Vector3.INF
	r.work_speed = 0.0
	r.pose = ""
	r.set_held("")
	stop()


# ---- for the jobs to override ----

## What they're doing, for the roster.
func label() -> String:
	return "Working"


func start() -> void:
	pass


func stop() -> void:
	pass


func step(_delta: float) -> bool:
	return false


# ---- helpers ----

## Walk to p (snapped onto the walkable mesh). Calling it again for the same spot while they're
## on the way does nothing; if they keep giving up short of it, it returns false.
func go(p: Vector3) -> bool:
	var q := snap(p)
	if _goal != Vector3.INF and _goal.distance_to(q) < 0.05:
		if r.has_goal():
			return true
		if arrived(q):
			return true
		_tries += 1
		if _tries > 3:
			return false
	else:
		_goal = q
		_tries = 0
	r.walk_to(q)
	return true


## Close enough to p (horizontally, and on the same floor)?
func arrived(p: Vector3, within := 0.35) -> bool:
	return Hex.distance(r.position, p) < within and absf(r.position.y - p.y) < 0.6


## The nearest point of the walkable mesh to p.
func snap(p: Vector3) -> Vector3:
	var map := r.get_world_3d().navigation_map
	if NavigationServer3D.map_get_iteration_id(map) == 0:
		return p                           # the map isn't ready yet
	var q := NavigationServer3D.map_get_closest_point(map, p)
	return q if q != Vector3.ZERO or p.length() < 0.5 else p


func wait(secs: float) -> void:
	_wait_left = secs


## Counts a wait down; true while it's still going.
func waiting(delta: float) -> bool:
	if _wait_left <= 0.0:
		return false
	_wait_left -= delta
	return true


func say(lines: Array, chance := 1.0) -> void:
	if not lines.is_empty() and randf() < chance and Game.world_time > r.next_speak:
		r.say(lines[randi() % lines.size()])


## A building by its node name (e.g. "Store").
func building(node_name: String) -> Building:
	for b in r.get_tree().get_nodes_in_group("buildings"):
		if (b as Node).name == node_name:
			return b
	return null
