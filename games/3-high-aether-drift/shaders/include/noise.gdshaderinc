// Integer-hash gradient noise. scripts/core/terrain_params.gd mirrors this EXACTLY (same hash, same constants),
// so the CPU (collision, prop placement) and the GPU (terrain mesh) agree on the ground height.

uint hash_i(ivec3 p, uint seed) {
	uint h = ((uint(p.x) * 73856093u) ^ (uint(p.y) * 19349663u) ^ (uint(p.z) * 83492791u) ^ (seed * 2654435761u));
	h ^= h >> 16u;
	h *= 0x7feb352du;
	h ^= h >> 15u;
	h *= 0x846ca68bu;
	h ^= h >> 16u;
	return h;
}

float grad_dot(uint h, vec3 d) {
	return (((h >> 5u) & 1u) != 0u ? d.x : -d.x) + (((h >> 6u) & 1u) != 0u ? d.y : -d.y) + (((h >> 7u) & 1u) != 0u ? d.z : -d.z);
}

float gnoise(vec3 p, uint seed) {
	vec3 i = floor(p);
	vec3 f = p - i;
	vec3 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
	ivec3 ip = ivec3(i);
	float n000 = grad_dot(hash_i(ip, seed), f);
	float n100 = grad_dot(hash_i(ip + ivec3(1, 0, 0), seed), f - vec3(1.0, 0.0, 0.0));
	float n010 = grad_dot(hash_i(ip + ivec3(0, 1, 0), seed), f - vec3(0.0, 1.0, 0.0));
	float n110 = grad_dot(hash_i(ip + ivec3(1, 1, 0), seed), f - vec3(1.0, 1.0, 0.0));
	float n001 = grad_dot(hash_i(ip + ivec3(0, 0, 1), seed), f - vec3(0.0, 0.0, 1.0));
	float n101 = grad_dot(hash_i(ip + ivec3(1, 0, 1), seed), f - vec3(1.0, 0.0, 1.0));
	float n011 = grad_dot(hash_i(ip + ivec3(0, 1, 1), seed), f - vec3(0.0, 1.0, 1.0));
	float n111 = grad_dot(hash_i(ip + ivec3(1, 1, 1), seed), f - vec3(1.0, 1.0, 1.0));
	return mix(mix(mix(n000, n100, u.x), mix(n010, n110, u.x), u.y),
			mix(mix(n001, n101, u.x), mix(n011, n111, u.x), u.y), u.z) * 0.8;
}

vec3 rot3(vec3 p) {
	return vec3(0.8 * p.y + 0.6 * p.z, -0.8 * p.x + 0.36 * p.y - 0.48 * p.z, -0.6 * p.x - 0.48 * p.y + 0.64 * p.z);
}

float fbm(vec3 p, uint seed, int oct) {
	float s = 0.0;
	float a = 0.5;
	float norm = 0.0;
	for (int i = 0; i < oct; i++) {
		s += a * gnoise(p, seed + uint(i));
		norm += a;
		a *= 0.5;
		p = rot3(p) * 2.02 + vec3(11.3, 5.7, 3.1);
	}
	return s / norm;
}

// Random crater field on the sphere; returns approx [-1 .. 0.35] (bowl depth / rim height), in crater units
float crater_field(vec3 d, float dens, uint seed) {
	vec3 q = d * dens;
	vec3 ic = floor(q);
	float res = 0.0;
	for (int z = -1; z <= 1; z++) {
		for (int y = -1; y <= 1; y++) {
			for (int x = -1; x <= 1; x++) {
				vec3 c = ic + vec3(float(x), float(y), float(z));
				uint h = hash_i(ivec3(c), seed);
				if ((h & 255u) > 120u) {
					continue;
				}
				uint h2 = hash_i(ivec3(c), seed + 1u);
				vec3 ctr = c + vec3(0.2 + 0.6 * float((h >> 8u) & 255u) / 255.0,
						0.2 + 0.6 * float((h >> 16u) & 255u) / 255.0,
						0.2 + 0.6 * float((h >> 24u) & 255u) / 255.0);
				float rad = 0.18 + 0.32 * float(h2 & 255u) / 255.0;
				float dd = length(q - ctr) / rad;
				float k = rad / 0.35;
				if (dd < 1.0) {
					res -= (1.0 - dd * dd) * k;
				} else if (dd < 1.5) {
					res += 0.32 * k * smoothstep(1.0, 1.12, dd) * (1.0 - smoothstep(1.12, 1.5, dd));
				}
			}
		}
	}
	return res;
}
