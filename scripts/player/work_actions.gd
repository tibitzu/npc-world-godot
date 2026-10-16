class_name WorkActions
extends RefCounted
## What the resident you're playing can do with F where they stand (besides lying down in a bed):
## the same work the residents do on their own (see scripts/brains).
##
##   at the woodpile, carrying logs    stack them
##   by a loose log                    pick it up (three fit in a pack)
##   by a letterbox, carrying post     post a parcel
##   by Bolt Post's pillar box         collect the post (two parcels)
##   at the general store's till       mind the shop (or stop)
##   by a street lamp                  light it, or put it out
##   by a standing tree                fell it (it takes a few seconds)
##   at the alarm bell                 ring it (everyone indoors, the guards out)
##   at the well                       have a drink
##   in front of an oven               have a meal
##
## find() returns {label, run} for the first that applies, or an empty dictionary.

const STACKED := ["That'll keep the fire going.", "Another one for the pile.", "Stacked and squared."]


static func find(r: Resident) -> Dictionary:
	var tree := r.get_tree()
	var here := r.position
	# the woodpile
	if r.pack.logs > 0:
		for p in tree.get_nodes_in_group("wood_piles"):
			var pile := p as WoodPile
			if _near_pile(pile, here) and not pile.is_full():
				return {"label": "Stack your logs", "run": func() -> void:
					var n := mini(r.pack.logs, pile.capacity - pile.count)
					r.pack_take("logs", n)
					pile.count += n
					r.say(STACKED[randi() % STACKED.size()])}
	var forest := tree.get_first_node_in_group("forest") as Forest
	# a loose log
	if forest and r.pack_room("logs") > 0 and here.y < 0.5:
		var l := forest.log_near(here, 1.1)
		if l:
			return {"label": "Pick up the log", "run": func() -> void:
				if is_instance_valid(l) and l in forest.logs:
					forest.take_log(l)
					r.pack_add("logs")}
	# a letterbox, with post to deliver
	if r.pack.parcels > 0:
		var box := _nearest_letterbox(r, 1.4)
		if not box.is_empty():
			return {"label": "Post a parcel at %s" % box.house, "run": func() -> void:
				r.pack_take("parcels")}
	# the pillar box outside Bolt Post
	if r.pack_room("parcels") > 0:
		for b in tree.get_nodes_in_group("buildings"):
			if (b as Node).name != "PostOffice":
				continue
			var pillar := (b as Node).find_child("PillarBox", true, false) as Node3D
			if pillar and _close(here, pillar.global_position, 1.4):
				return {"label": "Collect the post", "run": func() -> void:
					r.pack_add("parcels", r.pack_room("parcels"))}
	# the general store's till
	if _close(here, ShopJob.till_spot(), 0.9):
		if ShopJob.player_keeper == r:
			return {"label": "Stop minding the shop", "run": func() -> void:
				ShopJob.player_keeper = null}
		return {"label": "Mind the shop", "run": func() -> void:
			ShopJob.player_keeper = r
			r.say("Shop's open!")}
	# a street lamp
	var lamps := tree.get_first_node_in_group("lamp_posts") as LampPosts
	if lamps:
		for i in lamps.lamps.size():
			var lp: Vector3 = lamps.lamps[i].pos
			if _close(here, lp, 1.4):
				var lit: bool = lamps.lamps[i].lit
				return {"label": "Put out the lamp" if lit else "Light the lamp", "run": func() -> void:
					r.start_action("light", "pole", 1.0 if lit else 1.6, lp, func() -> void:
						lamps.set_lit(i, not lit))}
	# the alarm bell
	var bell := AlarmBell.find(tree)
	if bell and _close(here, bell.position, 1.6):
		return {"label": "Ring the alarm bell", "run": func() -> void:
			bell.ring(r)}
	# the well
	var well := tree.get_first_node_in_group("well") as Well
	if well and _close(here, well.position, Well.RING_R + 1.0) and r.needs.thirst < 97.0:
		return {"label": "Have a drink", "run": func() -> void:
			r.start_action("", "", 2.5, well.position, func() -> void:
				r.needs.thirst = 100.0
				r.cheer(4.0))}
	# an oven
	if r.needs.hunger < 97.0:
		for b in tree.get_nodes_in_group("buildings"):
			for o in Resident.ovens_in(b):
				if _close(here, Resident.oven_front(o), 1.0):
					return {"label": "Have a meal", "run": func() -> void:
						r.start_action("", "", 4.0, o.global_position, func() -> void:
							r.needs.hunger = 100.0
							r.cheer(6.0))}
	# a tree
	if forest:
		var near := forest.standing_near(here, 1.6)
		if not near.is_empty():
			var t: int = near[0]
			return {"label": "Fell the tree", "run": func() -> void:
				r.start_action("chop", "axe", 3.0, forest.trees[t].pos, func() -> void:
					if forest.is_standing(t):
						forest.fell(t, r.position)
						r.say("Timber!"))}
	return {}


static func _close(a: Vector3, b: Vector3, within: float) -> bool:
	return Hex.distance(a, b) < within and absf(a.y - b.y) < 0.8


# beside the pile: within reach of its length (it runs along its own Z)
static func _near_pile(pile: WoodPile, p: Vector3) -> bool:
	var l := pile.global_transform.affine_inverse() * p
	return absf(l.z) < 1.6 and absf(l.x) < 1.3 and absf(l.y) < 0.8


static func _nearest_letterbox(r: Resident, within: float) -> Dictionary:
	var best := {}
	var bd := within
	for b in r.get_tree().get_nodes_in_group("buildings"):
		var bld := b as Building
		if bld.name == "PostOffice":
			continue
		for n in bld.find_children("Letterbox*", "Node3D", true, false):
			var d := Hex.distance(r.position, (n as Node3D).global_position)
			if d < bd:
				bd = d
				best = {"node": n, "house": bld.def.display_name if bld.def else String(bld.name)}
	return best
