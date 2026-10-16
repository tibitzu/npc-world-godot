class_name ShopJob
extends Job
## Tilda minds the general store (as in the HTML game): she comes down to the till behind the
## counter and stands facing the door. Every so often she potters along the shelves behind her,
## looks them over, and goes back. Anyone who comes up to the counter gets a welcome.
##
## While she's at the till the shop is open, and other residents now and then drop in (see
## Resident._autonomy): customer_spot() is where they stand. A player can mind the shop too
## (F at the till): while they stay there it's open, and customers come up and ask for things.

const TILL := Vector2(-0.6, -1.55)                 # store-local x, z: behind the counter
const CUSTOMER := Vector2(-0.6, -0.05)             # in front of it
const SHELVES: Array[Vector2] = [Vector2(-2.7, -1.75), Vector2(-1.6, -1.75), Vector2(0.35, -1.75)]
const WELCOME := ["Welcome in, {n}! What can I get you?", "{n}! Come to spend or to sell?",
	"{Tod}, {n}. Have a look round.", "Ah, {n}. Potions are fresh."]
const WELCOME_AGAIN := 90.0                        # game seconds before the same customer is welcomed again

const SHOPPING := ["Got any rope?", "Just looking, thanks.", "How much for the fizzy one?",
	"Anything new in?", "A bag of nails, if you've got them.", "I'll take a candle. Two, actually."]

## The resident minding the shop now, if anyone is (the shop is open while she's at the till).
static var keeper: ShopJob = null
## A resident a player is minding the shop with (F at the till), if any.
static var player_keeper: Resident = null

var _store: Building
var _state := "to_till"
var _potter_at := 0.0
var _shelf := Vector3.ZERO
var _welcomed := {}                                # resident -> Game.world_time they may be welcomed again


static func is_open() -> bool:
	return (keeper != null and keeper._state == "till") or player_minding()


## Is a player minding the shop (playing a resident standing at the till)?
static func player_minding() -> bool:
	if player_keeper == null or not is_instance_valid(player_keeper) or not player_keeper.controlled:
		player_keeper = null
		return false
	if Hex.distance(player_keeper.position, till_spot()) > 1.3:
		player_keeper = null
		return false
	return true


## Is Tilda at her till to trade with (and nobody playing her)?
static func trading() -> bool:
	return keeper != null and keeper._state == "till" and not keeper.r.controlled and not keeper.r.dead \
		and keeper.arrived(till_spot(), 0.8)


## Is someone standing at the counter, on the customer's side?
static func at_counter(r: Resident) -> bool:
	var c := customer_spot()
	return Hex.distance(r.position, c) < 1.1 and absf(r.position.y - c.y) < 0.6


static func _the_store() -> Building:
	var tree := Engine.get_main_loop() as SceneTree
	for b in tree.get_nodes_in_group("buildings"):
		if (b as Node).name == "Store":
			return b
	return null


static func _store_point(p: Vector2) -> Vector3:
	var st := _the_store()
	return st.global_transform * Vector3(p.x, 0.0, p.y) if st else Vector3.ZERO


static func customer_spot() -> Vector3:
	return _store_point(CUSTOMER)


static func till_spot() -> Vector3:
	return _store_point(TILL)


func label() -> String:
	return "Minding the shop"


func start() -> void:
	_store = building("Store")
	_state = "to_till"
	Items.restock()                                # the shelves filled up for the day


func stop() -> void:
	if keeper == self:
		keeper = null


func _at_local(p: Vector2) -> Vector3:
	return _store.global_transform * Vector3(p.x, 0.0, p.y)


func step(delta: float) -> bool:
	if _store == null:
		return false
	keeper = self
	var till := _at_local(TILL)
	match _state:
		"to_till":
			if arrived(till, 0.3):
				_state = "till"
				_potter_at = Game.world_time + randf_range(12.0, 25.0)
			elif not go(till):
				_state = "till"                   # can't get there: mind the shop from here
		"till":
			if not arrived(till, 0.8):
				_state = "to_till"
				return true
			r.face_toward(_at_local(Vector2(TILL.x, 3.0)))   # the door
			_welcome_customers()
			if Game.world_time > _potter_at:
				if randf() < 0.6:
					var s: Vector2 = SHELVES[randi() % SHELVES.size()]
					_shelf = _at_local(s)
					_state = "to_shelf"
				else:
					say(r.def.lines)
					_potter_at = Game.world_time + randf_range(12.0, 25.0)
		"to_shelf":
			if arrived(_shelf, 0.3) or not go(_shelf):
				_state = "browse"
				wait(randf_range(2.0, 4.0))
		"browse":
			r.face_toward(_shelf + _store.global_transform.basis.z * -1.0)
			if not waiting(delta):
				_state = "to_till"
	return true


func _welcome_customers() -> void:
	var spot := _at_local(CUSTOMER)
	for o in r.get_tree().get_nodes_in_group("residents"):
		var c := o as Resident
		if c == r or Hex.distance(c.position, spot) > 1.2 or absf(c.position.y - spot.y) > 0.6:
			continue
		if _welcomed.get(c, 0.0) > Game.world_time or Game.world_time < r.next_speak:
			continue
		_welcomed[c] = Game.world_time + WELCOME_AGAIN
		r.say(Conversations.fill(WELCOME[randi() % WELCOME.size()], c))
		if not c.controlled:
			c.stop_to_talk(r, 4.0)
			c.say_later(Resident._pick(c.def.reply_lines), 1.6)
			c.shop_a_little()
		return
