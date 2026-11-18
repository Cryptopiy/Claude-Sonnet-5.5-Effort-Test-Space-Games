class_name PoiLoot
extends RefCounted
## Deterministic loot + lore tables for interactable points of interest (M7a).

const LORE := [
	"The glyphs rearrange themselves: 'Those who drift will always find a shore.'",
	"A hum rises through the stone. Somewhere, very far away, something answers.",
	"The monolith maps the sky: a ring of stars, and one dark point at its heart.",
	"Carved symbols tell of a gate that swallows light and returns it elsewhere.",
	"The surface warms under your glove. A voice without sound: 'Do not fear the dark.'",
	"Spiral glyphs, thousands of years old: 'We left. The doors remain open.'",
	"The obelisk pulses in time with your heartbeat, then falls quiet.",
	"A message in a language you somehow understand: 'Collect the void, and cross it.'",
]

const WRECK_LOG := [
	"Flight recorder: 'Hull breach after pulse-drive overload. Setting down. If anyone finds this - the crystals are real.'",
	"Black box: 'Engines gone, fuel gone. The planet is beautiful, at least.'",
	"Captain's log: 'We mapped nine worlds before the drive failed. Take what is useful.'",
	"Logbook: 'Atmospheric entry too steep. Lost the port wing. Ferrite will fix almost anything.'",
]

const TERMINAL_LOG := [
	"Automated survey post online. Long-range survey data uploaded to your visor.",
	"Station AI: 'Welcome back, Explorer. Surveyed sites have been marked.'",
	"Outpost terminal: 'No crew on site. Supplies released. Navigation data shared.'",
	"Remote relay linked. Nearby sites added to your map.",
]

static func lore_for(sd: int) -> String:
	return LORE[SeedUtil.rand_int(sd, 3, 0, LORE.size() - 1)]

static func pick(arr: Array, sd: int, salt: int) -> String:
	return str(arr[SeedUtil.rand_int(sd, salt, 0, arr.size() - 1)])

## loot table: returns Dictionary resource_id -> amount for a point of interest kind
static func roll(kind: String, sd: int, biome: String) -> Dictionary:
	var w := FloraTables.resource_weights(biome)
	var out: Dictionary = {}
	match kind:
		"container":
			var ids := ["ferrite", "zyrite", "sodium"]
			var main_i := SeedUtil.rand_int(sd, 21, 0, 2)
			out[ids[main_i]] = SeedUtil.rand_int(sd, 22, 5, 12)
			if SeedUtil.rand01(sd, 23) < 0.5:
				out[ids[(main_i + 1) % 3]] = SeedUtil.rand_int(sd, 24, 3, 7)
			if SeedUtil.rand01(sd, 25) < 0.12:
				out["voidstone"] = 1
		"wreck":
			out["ferrite"] = SeedUtil.rand_int(sd, 31, 10, 22)
			out["zyrite"] = SeedUtil.rand_int(sd, 32, 5, 12)
			if SeedUtil.rand01(sd, 33) < 0.5:
				out["voidstone"] = 1
		"beacon":
			out["voidstone"] = SeedUtil.rand_int(sd, 41, 1, 2)
			out["zyrite"] = SeedUtil.rand_int(sd, 42, 4, 9)
		"outpost":
			out["sodium"] = SeedUtil.rand_int(sd, 51, 8, 16)
			out["ferrite"] = SeedUtil.rand_int(sd, 52, 4, 9)
		"tower":
			out["zyrite"] = SeedUtil.rand_int(sd, 61, 3, 7)
		"ruin":
			out["voidstone"] = SeedUtil.rand_int(sd, 71, 1, 2)
			out["sodium"] = SeedUtil.rand_int(sd, 72, 4, 8)
	return out

static func describe(loot: Dictionary) -> String:
	var parts: PackedStringArray = []
	for k in loot:
		var info := ResourceDB.info(k)
		parts.append("+%d %s" % [int(loot[k]), String(info.get("name", k.capitalize()))])
	return ", ".join(parts)
