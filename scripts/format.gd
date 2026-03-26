class_name Format
extends RefCounted
## Utility class for formatting large numbers with K/M/B/T suffixes.

const SUFFIXES := ["", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc"]

## Formats a number with appropriate suffix.
## e.g. 1500 -> "1.50K", 2300000 -> "2.30M"
static func number(value: float) -> String:
	if value < 1000.0:
		return str(int(value))
	var tier := 0
	var scaled := value
	while scaled >= 1000.0 and tier < SUFFIXES.size() - 1:
		scaled /= 1000.0
		tier += 1
	if scaled >= 100.0:
		return "%d%s" % [int(scaled), SUFFIXES[tier]]
	elif scaled >= 10.0:
		return "%.1f%s" % [scaled, SUFFIXES[tier]]
	else:
		return "%.2f%s" % [scaled, SUFFIXES[tier]]

## Formats a number as a follower count with the word "followers".
static func followers(value: float) -> String:
	return number(value) + " followers"

## Formats a time duration in seconds to a readable string.
static func time(seconds: float) -> String:
	if seconds < 60.0:
		return "%.1fs" % seconds
	elif seconds < 3600.0:
		var m := int(seconds) / 60
		var s := int(seconds) % 60
		return "%dm %ds" % [m, s]
	else:
		var h := int(seconds) / 3600
		var m := (int(seconds) % 3600) / 60
		return "%dh %dm" % [h, m]
