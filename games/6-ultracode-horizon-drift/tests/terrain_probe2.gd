extends SceneTree
func _init() -> void:
	for rt in [FastNoiseLite.RETURN_DISTANCE, FastNoiseLite.RETURN_DISTANCE2, FastNoiseLite.RETURN_DISTANCE2_SUB]:
		var nc := FastNoiseLite.new()
		nc.noise_type = FastNoiseLite.TYPE_CELLULAR
		nc.cellular_return_type = rt
		nc.frequency = 0.01
		nc.cellular_jitter = 0.9
		var vals: Array = []
		for i in 100000:
			var x := float(i) * 0.37
			vals.append(nc.get_noise_3d(x, 12.3 + x * 0.31, 7.7 - x * 0.13))
		vals.sort()
		var n := vals.size()
		print("rt ", rt, ": min %.3f p1 %.3f p10 %.3f p50 %.3f p90 %.3f p99 %.3f max %.3f" % [vals[0], vals[n/100], vals[n/10], vals[n/2], vals[n*9/10], vals[n*99/100], vals[n-1]])
	quit()
