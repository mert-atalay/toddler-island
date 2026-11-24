extends RefCounted
## The ground of the valley: one height function for everything (the terrain, the water, the plants,
## the animals and the explorer all agree on it). North is -Z.
##
## The places keep the spots they had on the island, so all their code still fits: the farm (west),
## the cottage (south, the start), the pond in the middle, the windmill hill (north), the orchard
## (north-east), the wood with the tall oak (east), the rocket meadow and the lighthouse by the lake
## (south-east), and the zoo field (north-west). Round them now lies a green valley ringed by soft
## mountains instead of the sea: a waterfall pours out of the northern mountains, the river winds
## down past the windmill hill into the pond, flows on out of the pond and widens into a lake.
## The water level is 0 everywhere; the valley floor is about 0.6.

const SIZE := 512.0
const STEP := 1.0
const SEA := 0.0             # the water level
const FLOOR := 0.6
const WATER := 0.0

## The paths: one loop round the pond that passes every place, and short paths off it.
const PATHS := [
	[Vector2(64.0, 8.0), Vector2(63.3, 13.8), Vector2(61.4, 19.3), Vector2(58.3, 24.2), Vector2(54.2, 28.3), Vector2(49.3, 31.4), Vector2(43.8, 33.3), Vector2(38.0, 34.0), Vector2(32.2, 33.3), Vector2(26.7, 31.4), Vector2(21.8, 28.3), Vector2(17.7, 24.2), Vector2(14.6, 19.3), Vector2(12.7, 13.8), Vector2(12.0, 8.0), Vector2(12.7, 2.2), Vector2(14.6, -3.3), Vector2(17.7, -8.2), Vector2(21.8, -12.3), Vector2(26.7, -15.4), Vector2(32.2, -17.3), Vector2(38.0, -18.0), Vector2(43.8, -17.3), Vector2(49.3, -15.4), Vector2(54.2, -12.3), Vector2(58.3, -8.2), Vector2(61.4, -3.3), Vector2(63.3, 2.2), Vector2(64.0, 8.0)],
	[Vector2(0, 22), Vector2(0.5, 18), Vector2(-0.5, 8), Vector2(0, 2), Vector2(-1, -3)],     # up to the farm gate
	[Vector2(12.0, 8.0), Vector2(6.0, 11.0), Vector2(0.3, 14.0)],                           # loop to the farm path
	[Vector2(-0.5, 9), Vector2(-9, 11), Vector2(-20, 13), Vector2(-31, 12), Vector2(-42, 10)],  # west, towards the mountains
	[Vector2(38.0, 34.0), Vector2(37.5, 40.0), Vector2(37.0, 44.5)],                       # to the cottage
	[Vector2(38.0, -18.0), Vector2(32.0, -28.0), Vector2(28.0, -38.0), Vector2(26.5, -44.0)],  # up the windmill hill
	[Vector2(64.0, 8.0), Vector2(71.0, 6.0), Vector2(76.0, 4.0)],                           # into the wood, to the tall oak
	[Vector2(56.4, 26.4), Vector2(63.0, 34.0), Vector2(70.0, 42.0), Vector2(76.0, 49.0)],  # down to the lighthouse by the lake
	[Vector2(56.4, -10.4), Vector2(61.0, -16.0)],                                           # into the orchard
	[Vector2(40.5, 33.9), Vector2(40.5, 19.0)],                                             # to the jetty
	[Vector2(32.0, -28.0), Vector2(18.0, -28.5), Vector2(4.0, -28.0), Vector2(-6.0, -28.5)],  # to the zoo field
	[Vector2(37.5, 40.0), Vector2(46.0, 44.5), Vector2(52.0, 50.5)],                        # to the rocket meadow
	[Vector2(61.0, -16.0), Vector2(60.0, -30.0), Vector2(66.0, -44.0)],                     # orchard to the foot of the lookout
	[Vector2(66.0, -44.0), Vector2(79.0, -64.0), Vector2(84.0, -72.0)],                     # up the ramp onto the lookout
	[Vector2(-6.0, -28.5), Vector2(-22.0, -34.0), Vector2(-36.0, -42.0), Vector2(-46.0, -46.0), Vector2(-52.0, -48.0)],  # into the fairy hollow
	[Vector2(-31.0, 12.0), Vector2(-33.0, 21.0), Vector2(-32.0, 29.0)],                     # west path to the safari plain
	[Vector2(76.0, 4.0), Vector2(83.0, 1.0), Vector2(88.0, -4.0)],                           # through the wood to the treehouse camp
]

const CENTRE := Vector2(30, 8)
const LOOP := Vector2(38, 8)
const POND := Vector2(38, 8)
const HILL := Vector2(26, -50)
const COTTAGE := Vector2(37, 50)
const ORCHARD := Vector2(63, -21)
const OAK := Vector2(78, 2)
const LIGHTHOUSE := Vector2(80, 52)
const START := Vector2(37, 43)
const VISITOR := Vector2(-6, -35)
const ROCKET := Vector2(55, 54)
## The lookout: a rocky outcrop with a flat top, reached by a ramp up its side.
const LOOKOUT := Vector2(86, -75)
const LOOKOUT_R := 8.0
const LOOKOUT_H := 9.0
const RAMP := [Vector2(66.0, -44.0), Vector2(80.0, -65.5)]
## The fairy hollow: a glade ringed by steep grassy banks, with one way in (from the east).
const HOLLOW := Vector2(-62, -50)
const HOLLOW_R := 12.0

## The safari plain in the west: open dry grass, acacia trees and a waterhole.
const SAFARI := Vector2(-32, 42)
const SAFARI_R := 20.0
const WATERHOLE := Vector2(-21, 49)
const WATERHOLE_R := 5.5
## The treehouse camp: a clearing deep in the eastern wood.
const CAMP := Vector2(95, -10)
const CAMP_R := 12.0

## The lake in the south-east, by the lighthouse.
const LAKE := Vector2(103, 70)
const LAKE_R := 25.0
## The waterfall down the northern mountains (top, foot).
const FALL_TOP := Vector2(52, -140)
const FALL_FOOT := Vector2(47, -104)
## The river: from the waterfall's foot down to the pond, then out of the pond to the lake.
const RIVER := [Vector2(47, -104), Vector2(51, -86), Vector2(47, -68), Vector2(50, -50), Vector2(47, -34), Vector2(44.5, -20),
	Vector2(41, -8), Vector2(38, 0)]
const OUTFLOW := [Vector2(46, 12), Vector2(56, 19), Vector2(67, 24), Vector2(79, 33), Vector2(90, 46), Vector2(98, 58)]
## The whole water course as one line (bridges are built where paths cross it).
const STREAM := [Vector2(47, -104), Vector2(51, -86), Vector2(47, -68), Vector2(50, -50), Vector2(47, -34), Vector2(44.5, -20),
	Vector2(41, -8), Vector2(38, 0), Vector2(38, 8), Vector2(46, 12), Vector2(56, 19), Vector2(67, 24), Vector2(79, 33), Vector2(90, 46), Vector2(98, 58)]

## The flat spots the places stand on: [centre, radius, height above the floor].
const FLATS := [[Vector2(-2, -10), 22.0, 0.0], [COTTAGE, 13.0, 0.0], [ORCHARD, 11.0, 0.0], [VISITOR, 10.0, 0.0], [ROCKET, 10.0, 0.0],
	[LIGHTHOUSE, 6.0, 0.6], [SAFARI, 19.0, 0.0], [CAMP, 9.0, 0.0]]

static var heights := PackedFloat32Array()
static var _seg_cells := {}
static var _n1: FastNoiseLite
static var _n2: FastNoiseLite
static var _n3: FastNoiseLite


static func _noise() -> void:
	if _n1:
		return
	_n1 = FastNoiseLite.new()
	_n1.seed = 7
	_n1.frequency = 0.035
	_n2 = FastNoiseLite.new()
	_n2.seed = 11
	_n2.frequency = 0.008
	_n3 = FastNoiseLite.new()
	_n3.seed = 23
	_n3.frequency = 0.04


static func sstep(a: float, b: float, x: float) -> float:
	var t := clampf((x - a) / (b - a), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


static func _line_dist(p: Vector2, line: Array) -> float:
	var best := 1e9
	for i in line.size() - 1:
		var a: Vector2 = line[i]
		var ab: Vector2 = line[i + 1] - a
		var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
		best = minf(best, p.distance_to(a + ab * t))
	return best


static func _bucket() -> void:
	if not _seg_cells.is_empty():
		return
	for line in PATHS:
		for i in line.size() - 1:
			var a: Vector2 = line[i]
			var b: Vector2 = line[i + 1]
			var lo := Vector2i(floori((minf(a.x, b.x) - 4.0) / 10.0), floori((minf(a.y, b.y) - 4.0) / 10.0))
			var hi := Vector2i(floori((maxf(a.x, b.x) + 4.0) / 10.0), floori((maxf(a.y, b.y) + 4.0) / 10.0))
			for cy in range(lo.y, hi.y + 1):
				for cx in range(lo.x, hi.x + 1):
					(_seg_cells.get_or_add(Vector2i(cx, cy), []) as Array).append([a, b])


## Distance to the nearest path (up to about 4 m; further away it answers 99).
static func path_distance(x: float, z: float) -> float:
	_bucket()
	var segs: Array = _seg_cells.get(Vector2i(floori(x / 10.0), floori(z / 10.0)), [])
	var p := Vector2(x, z)
	var best := 99.0
	for sg in segs:
		var a: Vector2 = sg[0]
		var ab: Vector2 = sg[1] - a
		var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
		best = minf(best, p.distance_to(a + ab * t))
	return best


## Distance to the river (the pond and the lake are not counted).
static func river_distance(p: Vector2) -> float:
	if p.x < 20.0 or p.x > 110.0 or p.y < -115.0 or p.y > 75.0:
		return 99.0
	return minf(_line_dist(p, RIVER), _line_dist(p, OUTFLOW))


static func stream_distance(x: float, z: float) -> float:
	return river_distance(Vector2(x, z))


## How far into the mountains (0 on the valley floor, 1 high up).
static func mountain(p: Vector2) -> float:
	_noise()
	var q := p - CENTRE
	var r := Vector2(q.x, q.y * 1.08).length() + 16.0 * _n2.get_noise_2d(p.x, p.y)
	return sstep(122.0, 215.0, r)


## Kept for code from the island: there is no sea now, so the "shore" is far away in the mountains.
static func shore_radius(_x: float, _z: float) -> float:
	return 400.0


## The ground height at (x, z). carve = false leaves out the river bed (the bank height there).
static func height(x: float, z: float, carve := true) -> float:
	_noise()
	var p := Vector2(x, z)
	var h := FLOOR + 0.45 * _n1.get_noise_2d(x, z)
	# soft rolling meadows away from the middle
	h += maxf(0.0, _n2.get_noise_2d(x * 1.6, z * 1.6)) * 5.0 * sstep(60.0, 105.0, p.distance_to(CENTRE))
	# the windmill hill in the north
	h += sstep(36.0, 4.0, p.distance_to(HILL)) * (10.0 + 2.5 * _n2.get_noise_2d(x * 3.0, z * 3.0))
	# rising ground in the wood to the east
	h += sstep(64.0, 95.0, x) * sstep(40.0, 10.0, absf(z - 0.0)) * 2.2
	# the mountains all round
	var m := mountain(p)
	h += m * m * (48.0 + 20.0 * _n1.get_noise_2d(x * 0.15, z * 0.15)) + m * 5.0 * absf(_n3.get_noise_2d(x * 0.5, z * 0.5))
	# flat ground for the farmyard and the places
	var farm := 1.0 - sstep(0.85, 1.35, maxf(absf(x + 6.0) / 22.0, absf(z + 2.0) / 26.0))
	for f in FLATS:
		var c: Vector2 = f[0]
		var r: float = f[1]
		farm = maxf(farm, sstep(r + 7.0, r * 0.65, p.distance_to(c)))
	h = lerpf(h, FLOOR + 0.08 * _n1.get_noise_2d(x, z), farm * 0.9)
	# paths are flattened a little
	h = lerpf(h, h * 0.9 + 0.06, sstep(2.0, 0.0, path_distance(x, z)) * 0.5)
	# the lookout: a steep-sided outcrop, flat on top, with a ramp climbing its side
	var lk := p.distance_to(LOOKOUT)
	if lk < 40.0:
		var top := FLOOR + LOOKOUT_H
		h = maxf(h, lerpf(h, top, sstep(LOOKOUT_R + 5.0, LOOKOUT_R, lk)))
		var ra: Vector2 = RAMP[0]
		var rb: Vector2 = RAMP[1]
		var along := clampf((p - ra).dot(rb - ra) / (rb - ra).length_squared(), 0.0, 1.0)
		var rd2 := p.distance_to(ra + (rb - ra) * along)
		var ramp_h := lerpf(FLOOR + 0.1, top, along)
		h = lerpf(h, ramp_h, sstep(3.2, 1.6, rd2))
	# the fairy hollow: a ring of steep banks round a sheltered glade, open to the east
	var hd := p.distance_to(HOLLOW)
	if hd < 30.0:
		var ang := absf(angle_difference(atan2(p.y - HOLLOW.y, p.x - HOLLOW.x), atan2(-48.0 - HOLLOW.y, -46.0 - HOLLOW.x)))
		var gap := sstep(0.18, 0.32, ang)
		var ring := sstep(HOLLOW_R, HOLLOW_R + 3.0, hd) * sstep(HOLLOW_R + 10.0, HOLLOW_R + 5.0, hd)
		h += ring * gap * (5.5 + 1.2 * _n1.get_noise_2d(x * 2.0, z * 2.0))
		h = lerpf(h, FLOOR + 0.05, sstep(HOLLOW_R + 0.5, HOLLOW_R - 2.0, hd))
	# the river valley: the floor eases down to the banks, then the channel
	var rd := river_distance(p)
	if rd < 30.0:
		h = lerpf(h, FLOOR, sstep(16.0, 5.0, rd))
		if carve:
			var bed := WATER - 1.1 - 0.5 * sstep(3.5, 0.0, rd)
			h = lerpf(h, bed, sstep(4.6, 2.2, rd))
	# the pond in the middle
	h -= 2.3 * sstep(12.5, 6.0, p.distance_to(POND))
	# the safari waterhole: a shallow round pool with a soft muddy rim
	h -= 1.05 * sstep(WATERHOLE_R + 2.5, WATERHOLE_R - 2.0, p.distance_to(WATERHOLE))
	# the lake, with a gentle beach round it
	var ld := p.distance_to(LAKE)
	if ld < LAKE_R + 30.0:
		h = lerpf(h, FLOOR - 0.1, sstep(LAKE_R + 16.0, LAKE_R + 4.0, ld))
		h = lerpf(h, WATER - 2.8, sstep(LAKE_R + 2.0, LAKE_R - 9.0, ld))
	# the waterfall's cleft in the mountain
	var fd := _line_dist(p, [FALL_TOP, FALL_FOOT])
	if fd < 12.0:
		var along := clampf((p - FALL_TOP).dot(FALL_FOOT - FALL_TOP) / (FALL_FOOT - FALL_TOP).length_squared(), 0.0, 1.0)
		h = lerpf(h, lerpf(30.0, WATER - 0.8, pow(along, 0.7)), sstep(10.0, 3.0, fd) * 0.85)
	return h


## Sand: the lake's beach and the pond's rim.
static func is_sand(x: float, z: float) -> float:
	var p := Vector2(x, z)
	# a muddy rim round the safari waterhole
	var sd := p.distance_to(SAFARI)
	if sd < SAFARI_R + 6.0:
		_noise()
		return sstep(WATERHOLE_R + 3.0, WATERHOLE_R + 1.0, p.distance_to(WATERHOLE))
	var ld := p.distance_to(LAKE)
	var lake := sstep(LAKE_R + 11.0, LAKE_R + 6.0, ld) * sstep(LAKE_R - 6.0, LAKE_R - 1.0, ld)
	var pond := sstep(10.0, 8.5, p.distance_to(POND)) * 0.7
	return maxf(lake, pond)


## What the ground is here, for painting: 0 grass, 1 rock, 2 path, 3 pebbly bank or sand.
static func ground(x: float, z: float) -> int:
	if is_sand(x, z) > 0.55 or river_distance(Vector2(x, z)) < 5.4:
		return 3
	if path_distance(x, z) < 1.35:
		return 2
	return 0


## A grass colour for a spot (the grass field and the old island code use it).
static func ground_color(x: float, z: float, h: float) -> Color:
	_noise()
	var n := _n2.get_noise_2d(x * 4.0, z * 4.0) * 0.5 + 0.5
	var c := Color(0.27, 0.48, 0.18).lerp(Color(0.5, 0.64, 0.27), n)
	return c.lerp(Color(0.62, 0.66, 0.3), maxf(0.0, n - 0.7) * 2.0)


## Inside the farmyard fence.
static func in_yard(p: Vector2) -> bool:
	return p.x > -24.0 and p.x < 12.0 and p.y > -21.0 and p.y < 1.0


## The farm and the ground just round it (kept tidy: no tall wild grass or bushes).
static func in_farm(p: Vector2) -> bool:
	return p.x > -32.0 and p.x < 16.0 and p.y > -26.0 and p.y < 12.0


## Is this a good open spot for wild plants (not path, water, a place or near the farm)?
static func is_open(p: Vector2, margin := 0.0) -> bool:
	if river_distance(p) < 6.5 + margin or p.distance_to(LAKE) < LAKE_R + 4.0 + margin or p.distance_to(POND) < 13.0 + margin:
		return false
	if path_distance(p.x, p.y) < 2.5 + margin:
		return false
	if p.distance_to(LOOKOUT) < LOOKOUT_R + 6.0 or p.distance_to(HOLLOW) < HOLLOW_R + 0.5:
		return false
	if p.distance_to(WATERHOLE) < WATERHOLE_R + 2.5:
		return false
	return true


# --- kept so old island code still compiles (the valley does not use these) -------------------

static func height_fast(x: float, z: float) -> float:
	return height(x, z)


static func build_mesh() -> ArrayMesh:
	return ArrayMesh.new()


static func paint_image() -> Image:
	return Image.create_empty(4, 4, false, Image.FORMAT_RG8)
