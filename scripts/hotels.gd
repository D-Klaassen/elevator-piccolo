class_name Hotels
## The hotel ladder, from the rustic cabin up. You start in the first and move up one at a
## time, never back. A hotel opens up once the last [constant Career.AVERAGE_OVER] shifts
## average [constant UNLOCK_STARS] stars or more and you pay its application fee.
## Moving takes your music box along; the cab's hardware starts over.
##
## Per hotel: [code]floors[/code]; [code]guests[/code] per shift, [code]lunch_guests[/code]
## of them in the lunch rush; [code]pay[/code] multiplies fares and tips;
## [code]prices[/code] multiplies the upgrade catalogue; [code]ride_patience[/code]
## multiplies how long guests put up with a ride, as a taller shaft means longer rides;
## [code]fee[/code] is the application fee to move in; [code]spanish[/code] is the share of
## guests who speak Spanish; [code]places[/code] names what is on each floor, or is empty.

const UNLOCK_STARS := 4.0

const LADDER: Array[Dictionary] = [
	{
		"id": "cabin",
		"name": "Rustic cabin",
		"floors": 3,
		"guests": 15,
		"lunch_guests": 5,
		"pay": 1.0,
		"prices": 0.5,
		"ride_patience": 1.0,
		"fee": 0.0,
		"spanish": 0.0,
		"places": [],
	},
	{
		"id": "bellevue",
		"name": "Pension Bellevue",
		"floors": 7,
		"guests": 25,
		"lunch_guests": 8,
		"pay": 1.5,
		"prices": 1.0,
		"ride_patience": 1.5,
		"fee": 150.0,
		"spanish": 0.6,
		"places": ["Lobby", "Rooms", "Rooms", "Restaurant", "Pool", "Spa", "Rooftop bar"],
	},
]

## The upgrades that stay behind when you move: they belong to the old hotel's cab.
const HARDWARE: Array[String] = [Upgrades.CALLS, Upgrades.CAB, Upgrades.DOORS]


static func at(index: int) -> Dictionary:
	return LADDER[clampi(index, 0, LADDER.size() - 1)]


static func is_last(index: int) -> bool:
	return index >= LADDER.size() - 1
