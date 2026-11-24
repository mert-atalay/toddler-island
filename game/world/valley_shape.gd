extends RefCounted
## The shape of the valley, designed rather than random: a wide green valley floor ringed by soft
## mountains, a river that tumbles out of the north-west mountains as a waterfall, winds across the
## valley and widens into a lake in the south-east, a round hill for the windmill, and flat spots
## where the places will stand. Every height and every "what is the ground here" answer comes from
## this one file, so the terrain, the water, the plants and the animals all agree.

const SIZE := 512.0           # metres across (the terrain is -256..256)
const FLOOR := 3.0            # the valley floor
const WATER := 2.1            # the water level of the river and the lake

## The river, from the foot of the waterfall to the lake.
const RIVER := [Vector2(-128, -150), Vector2(-112, -118), Vector2(-92, -96), Vector2(-60, -84), Vector2(-28, -70),
	Vector2(-4, -44), Vector2(6, -14), Vector2(2, 14), Vector2(18, 40), Vector2(44, 58), Vector2(62, 72)]
const LAKE := Vector2(80, 88)
const LAKE_R := 30.0
## Where the waterfall comes down the mountain (top, bottom).
const FALL_TOP := Vector2(-146, -184)
const FALL_FOOT := Vector2(-128, -150)

## The places: [name, centre, radius of the flat spot].
const PLACES := {
	"cottage": [Vector2(-30, 40), 16.0],
	"farm": [Vector2(-78, 6), 24.0],
	"orchard": [Vector2(52, -34), 18.0],
	"windmill": [Vector2(-70, -40), 10.0],
	"rocket": [Vector2(70, 18), 14.0],
	"playground": [Vector2(-8, 70), 12.0],
	"beach": [Vector2(64, 108), 12.0],
	"wood": [Vector2(110, -40), 10.0],
}
const HILL := Vector2(-70, -40)

## The paths, as lines through points.
const PATHS := [
	[Vector2(-30, 40), Vector2(-26, 22), Vector2(-14, 4), Vector2(6, -14)],                # cottage to the bridge
	[Vector2(6, -14), Vector2(26, -24), Vector2(52, -34)],                                    # bridge to the orchard
	[Vector2(-30, 40), Vector2(-52, 30), Vector2(-78, 6)],                                    # cottage to the farm
	[Vector2(-78, 6), Vector2(-80, -18), Vector2(-70, -40)],                                  # farm up the windmill hill
	[Vector2(-30, 40), Vector2(-16, 58), Vector2(-8, 70)],                                    # cottage to the playground
	[Vector2(-8, 70), Vector2(20, 82), Vector2(44, 100), Vector2(64, 108)],                    # playground to the lake beach
	[Vector2(52, -34), Vector2(66, -10), Vector2(70, 18)],                                    # orchard to the rocket meadow
	[Vector2(52, -34), Vector2(84, -40), Vector2(110, -40)],                                  # orchard into the wood
]
const BRIDGE := Vector2(6, -14)

static var _n1: FastNoiseLite
static var _n2: FastNoiseLite
static var _n3: FastNoiseLite


static func _noise() -> void:
	if _n1:
		return
	_n1 = FastNoiseLite.new()
	_n1.seed = 11
	_n1.frequency = 1.0 / 70.0
	_n2 = FastNoiseLite.new()
	_n2.seed = 23
	_n2.frequency = 1.0 / 160.0
	_n3 = FastNoiseLite.new()
	_n3.seed = 5
	_n3.frequency = 1.0 / 25.0


static func sstep(a: float, b: float, x: float) -> float:
	var t := clampf((x - a) / (b - a), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


static func _line_dist(p: Vector2, line: Array) -> float:
	var best := 1e9
	for i in line.size() - 1:
		var a: Vector2 = line[i]
		var b: Vector2 = line[i + 1]
		var ab := b - a
		var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
		best = minf(best, p.distance_to(a + ab * t))
	return best


static func river_distance(p: Vector2) -> float:
	return _line_dist(p, RIVER)


static func path_distance(p: Vector2) -> float:
	var best := 1e9
	for line in PATHS:
		best = minf(best, _line_dist(p, line))
	return best


## How far into the mountains (0 on the valley floor, 1 high up).
static func mountain(p: Vector2) -> float:
	_noise()
	var r := Vector2(p.x, p.y * 1.08).length() + 18.0 * _n2.get_noise_2d(p.x, p.y)
	return sstep(150.0, 235.0, r)


## The ground height at (x, z).
static func height(x: float, z: float) -> float:
	_noise()
	var p := Vector2(x, z)
	var h := FLOOR + 1.2 * _n1.get_noise_2d(x, z) + 0.35 * _n3.get_noise_2d(x, z)
	# soft rolling meadows
	h += maxf(0.0, _n2.get_noise_2d(x * 1.3, z * 1.3)) * 7.0 * sstep(40.0, 90.0, p.length())
	# the windmill hill
	h += sstep(46.0, 4.0, p.distance_to(HILL)) * 13.0
	# the mountains all round
	var m := mountain(p)
	h += m * m * (46.0 + 22.0 * _n1.get_noise_2d(x * 0.6, z * 0.6)) + m * 6.0 * absf(_n3.get_noise_2d(x * 0.4, z * 0.4))
	# flat spots for the places
	for k in PLACES:
		var c: Vector2 = PLACES[k][0]
		var r: float = PLACES[k][1]
		var top := FLOOR + 0.4 if k != "windmill" else FLOOR + 13.0
		h = lerpf(h, top, sstep(r + 10.0, r * 0.7, p.distance_to(c)))
	# paths are gently levelled
	var pd := path_distance(p)
	h = lerpf(h, h * 0.8 + FLOOR * 0.2, sstep(4.0, 0.5, pd) * 0.5)
	# the river valley: the floor drops to the banks, then the channel
	var rd := river_distance(p)
	var lake := p.distance_to(LAKE)
	h = lerpf(h, FLOOR + 0.3, sstep(26.0, 7.0, minf(rd, lake - LAKE_R + 7.0)))
	var bed := WATER - 1.3 - 0.6 * sstep(5.0, 0.0, rd)
	h = lerpf(h, bed, sstep(6.2, 3.2, rd))
	# the lake
	h = lerpf(h, WATER - 3.2, sstep(LAKE_R, LAKE_R - 9.0, lake))
	# the waterfall's notch in the mountain
	var fall_line := [FALL_TOP, FALL_FOOT]
	var fd := _line_dist(p, fall_line)
	var along := clampf((p - FALL_TOP).dot(FALL_FOOT - FALL_TOP) / (FALL_FOOT - FALL_TOP).length_squared(), 0.0, 1.0)
	h = lerpf(h, lerpf(36.0, WATER - 1.0, along), sstep(9.0, 3.0, fd) * 0.85)
	return h


## What the ground is here: 0 grass, 1 rock, 2 path, 3 pebbly bank.
static func ground(x: float, z: float) -> int:
	var p := Vector2(x, z)
	var rd := minf(river_distance(p), p.distance_to(LAKE) - LAKE_R + 3.0)
	if rd < 7.2:
		return 3
	if path_distance(p) < 1.7 + 0.5 * _n3.get_noise_2d(x * 2.0, z * 2.0):
		return 2
	return 0


## Is this a good open spot for plants (not path, not water, not a place)?
static func is_open(p: Vector2, margin := 0.0) -> bool:
	if river_distance(p) < 8.0 + margin or p.distance_to(LAKE) < LAKE_R + 4.0 + margin:
		return false
	if path_distance(p) < 2.5 + margin:
		return false
	for k in PLACES:
		if p.distance_to(PLACES[k][0]) < float(PLACES[k][1]) + margin:
			return false
	return true
