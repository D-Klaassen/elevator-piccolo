class_name Upgrades
## The upgrades you can buy in the staff room between shifts and what every level does.
## Level 0 is what you start with. The prices are Pension Bellevue's; every hotel scales
## them (the rustic cabin halves them), see [Hotels].
## An upgrade with [code]from_hotel[/code] is only for sale from that hotel on.

const MUSIC := "music"
const CAB := "cab"
const DOORS := "doors"
const CALLS := "calls"
const SPANISH := "spanish"

## In the order the staff room lists them. [code]effects[/code] describes each level you
## can buy, so it has one entry per price.
const CATALOGUE: Array[Dictionary] = [
	{
		"id": CALLS,
		"name": "Call panel",
		"prices": [80.0, 200.0],
		"effects": [
			"Lamps show which floors have someone waiting",
			"The lamps blink when a guest runs out of patience",
		],
	},
	{
		"id": MUSIC,
		"name": "Music",
		"prices": [80.0, 200.0, 450.0],
		"effects": [
			"A music box: guests put up with a 25% longer ride",
			"Better speakers: a 50% longer ride",
			"A proper playlist: a 75% longer ride",
		],
	},
	{
		"id": CAB,
		"name": "Bigger cab",
		"prices": [150.0, 400.0],
		"effects": ["Room for 4 guests", "Room for 5 guests"],
	},
	{
		"id": DOORS,
		"name": "Faster doors",
		"prices": [100.0, 250.0],
		"effects": ["Doors open and close in 0.55 s", "Doors open and close in 0.35 s"],
	},
	{
		"id": SPANISH,
		"name": "Spanish lessons",
		"prices": [60.0, 100.0, 150.0, 220.0, 300.0],
		"from_hotel": 1,
		"effects": [
			"Lesson 1: small words",
			"Lesson 2: common verbs",
			"Lesson 3: floors and numbers",
			"Lesson 4: hotel places",
			"Lesson 5: fluent, with full subtitles",
		],
	},
]

## By level: how much longer guests put up with a ride.
const RIDE_PATIENCE: Array[float] = [1.0, 1.25, 1.5, 1.75]
## By level: how many guests fit in the cab.
const CAPACITY: Array[int] = [3, 4, 5]
## By level: seconds the doors take to open or close.
const DOOR_TIME: Array[float] = [0.8, 0.55, 0.35]


static func find(id: String) -> Dictionary:
	for upgrade in CATALOGUE:
		if upgrade.id == id:
			return upgrade
	push_error("No upgrade called %s" % id)
	return {}


## True when [param id] is for sale at the hotel at [param hotel] on the ladder.
static func is_sold_at(id: String, hotel: int) -> bool:
	return hotel >= find(id).get("from_hotel", 0)


## How many levels [param id] has on top of level 0.
static func max_level(id: String) -> int:
	return find(id).prices.size()
