class_name Upgrades
## The upgrades you can buy in the staff room between shifts, at the rustic cabin's prices
## (half of Pension Bellevue's), and what every level does. Level 0 is what you start with.
## Spanish lessons come with the Spanish guests.

const MUSIC := "music"
const CAB := "cab"
const DOORS := "doors"
const CALLS := "calls"

## In the order the staff room lists them. [code]effects[/code] describes each level you
## can buy, so it has one entry per price.
const CATALOGUE: Array[Dictionary] = [
	{
		"id": CALLS,
		"name": "Call panel",
		"prices": [40.0, 100.0],
		"effects": [
			"Lamps show which floors have someone waiting",
			"The lamps blink when a guest runs out of patience",
		],
	},
	{
		"id": MUSIC,
		"name": "Music",
		"prices": [40.0, 100.0, 225.0],
		"effects": [
			"A music box: guests put up with a 25% longer ride",
			"Better speakers: a 50% longer ride",
			"A proper playlist: a 75% longer ride",
		],
	},
	{
		"id": CAB,
		"name": "Bigger cab",
		"prices": [75.0, 200.0],
		"effects": ["Room for 4 guests", "Room for 5 guests"],
	},
	{
		"id": DOORS,
		"name": "Faster doors",
		"prices": [50.0, 125.0],
		"effects": ["Doors open and close in 0.55 s", "Doors open and close in 0.35 s"],
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


## How many levels [param id] has on top of level 0.
static func max_level(id: String) -> int:
	return find(id).prices.size()
