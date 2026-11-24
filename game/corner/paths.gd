extends RefCounted
## Where feet can go: the island as half-metre squares. Fences, buildings, tree trunks and water are
## solid; the farm gate's squares open and close with the gate. Animals ask for a route instead of
## heading straight at a target, so they walk round fences instead of through them.

const Terrain := preload("res://corner/terrain.gd")
const CELL := 0.5
const ORIGIN := Vector2(-56.0, -76.0)
const SIZE := Vector2i(344, 344)

var grid := AStarGrid2D.new()
var _gate_cells: Array[Vector2i] = []


func build(corner: Node3D) -> void:
	grid.region = Rect2i(Vector2i.ZERO, SIZE)
	grid.cell_size = Vector2.ONE
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	grid.update()
	# water: the sea round the island (a cheap test on the shoreline) and the pond
	for j in SIZE.y:
		for i in SIZE.x:
			var p := to_world(Vector2i(i, j))
			var from_centre := p.distance_to(Terrain.CENTRE)
			if Terrain.height(p.x, p.y) < -0.1 or from_centre > 135.0 or p.distance_to(Terrain.POND) < 9.8:
				grid.set_point_solid(Vector2i(i, j), true)
	for f in corner.fence_lines:
		_solid_line(f[0], f[1])
	for b in corner.blocked:
		_solid_disc(b[0], float(b[1]) * 0.85)
	for t in corner.trunks:
		_solid_disc(t[0], float(t[1]) + 0.2)
	# the footbridges are open over the water
	for b in corner.get_meta("bridges", []):
		var at: Vector2 = b[0]
		var dir: Vector2 = b[1]
		var half: float = float(b[2]) + 1.0
		var t := -half
		while t <= half:
			for w in [-0.5, 0.0, 0.5]:
				var c := to_cell(at + dir * t + dir.orthogonal() * w)
				if grid.is_in_boundsv(c):
					grid.set_point_solid(c, false)
			t += 0.25


## The farm gate: solid while shut, open squares once she opens it.
func set_gate(a: Vector2, b: Vector2, open: bool) -> void:
	if _gate_cells.is_empty():
		var n := int(a.distance_to(b) / (CELL * 0.5)) + 1
		for k in n + 1:
			var c := to_cell(a.lerp(b, float(k) / n))
			if not _gate_cells.has(c):
				_gate_cells.append(c)
	for c in _gate_cells:
		if grid.is_in_boundsv(c):
			grid.set_point_solid(c, not open)


func to_cell(p: Vector2) -> Vector2i:
	return Vector2i(floori((p.x - ORIGIN.x) / CELL), floori((p.y - ORIGIN.y) / CELL))


func to_world(c: Vector2i) -> Vector2:
	return ORIGIN + (Vector2(c) + Vector2(0.5, 0.5)) * CELL


func is_open(p: Vector2) -> bool:
	var c := to_cell(p)
	return grid.is_in_boundsv(c) and not grid.is_point_solid(c)


## A list of points from `from` to `to` round obstacles (empty if there is no way at all).
func route(from: Vector2, to: Vector2) -> PackedVector2Array:
	var a := _nearest_open(to_cell(from))
	var b := _nearest_open(to_cell(to))
	var out := PackedVector2Array()
	if a == Vector2i(-1, -1) or b == Vector2i(-1, -1):
		return out
	var ids := grid.get_id_path(a, b, true)
	# keep only the corners of the route, so animals walk in smooth straight runs
	var last_dir := Vector2i.ZERO
	for k in ids.size():
		if k > 0 and k < ids.size() - 1:
			var d: Vector2i = ids[k + 1] - ids[k]
			if d == last_dir:
				continue
			last_dir = d
		out.append(to_world(ids[k]))
	if not out.is_empty() and is_open(to):
		out[out.size() - 1] = to
	return out


func _nearest_open(c: Vector2i) -> Vector2i:
	if grid.is_in_boundsv(c) and not grid.is_point_solid(c):
		return c
	for r in range(1, 9):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var n := c + Vector2i(dx, dy)
				if grid.is_in_boundsv(n) and not grid.is_point_solid(n):
					return n
	return Vector2i(-1, -1)


func _solid_line(a: Vector2, b: Vector2) -> void:
	var n := int(a.distance_to(b) / (CELL * 0.5)) + 1
	for k in n + 1:
		var c := to_cell(a.lerp(b, float(k) / n))
		if grid.is_in_boundsv(c):
			grid.set_point_solid(c, true)


func _solid_disc(centre: Vector2, r: float) -> void:
	var lo := to_cell(centre - Vector2(r, r))
	var hi := to_cell(centre + Vector2(r, r))
	for j in range(lo.y, hi.y + 1):
		for i in range(lo.x, hi.x + 1):
			var c := Vector2i(i, j)
			if grid.is_in_boundsv(c) and to_world(c).distance_to(centre) <= r:
				grid.set_point_solid(c, true)
