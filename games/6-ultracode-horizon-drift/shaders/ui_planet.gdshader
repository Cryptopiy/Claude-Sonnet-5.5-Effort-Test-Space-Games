shader_type canvas_item;
// Stylised planet limb with atmosphere for the main menu (module M6).
uniform vec2 center = vec2(1.15, 1.42);     // in height-normalised screen units (x 0..aspect, y 0..1)
uniform float radius = 0.98;
uniform float aspect = 1.7778;
uniform vec3 sun_dir = vec3(-0.72, 0.38, 0.58);
uniform float time_s = 0.0;
uniform vec3 atmo_color : source_color = vec3(0.32, 0.62, 1.0);

float hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

float vnoise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash13(i), hash13(i + vec3(1.0, 0.0, 0.0)), f.x), mix(hash13(i + vec3(0.0, 1.0, 0.0)), hash13(i + vec3(1.0, 1.0, 0.0)), f.x), f.y),
		mix(mix(hash13(i + vec3(0.0, 0.0, 1.0)), hash13(i + vec3(1.0, 0.0, 1.0)), f.x), mix(hash13(i + vec3(0.0, 1.0, 1.0)), hash13(i + vec3(1.0, 1.0, 1.0)), f.x), f.y), f.z);
}

float fbm(vec3 p) {
	float a = 0.5;
	float s = 0.0;
	for (int i = 0; i < 5; i++) {
		s += a * vnoise(p);
		p = p * 2.1 + vec3(5.2, 1.3, 8.1);
		a *= 0.5;
	}
	return s;
}

void fragment() {
	vec2 p = vec2(UV.x * aspect, UV.y) - center;
	float d = length(p);
	vec3 sd = normalize(sun_dir);
	vec3 col = vec3(0.0);
	float alpha = 0.0;
	if (d < radius) {
		float z = sqrt(max(radius * radius - d * d, 0.0));
		vec3 n = normalize(vec3(p.x, -p.y, z));
		float spin = time_s * 0.012;
		float cs = cos(spin);
		float sn = sin(spin);
		vec3 sp = vec3(cs * n.x + sn * n.z, n.y, -sn * n.x + cs * n.z);
		float land_n = fbm(sp * 2.6 + 4.0);
		float detail = fbm(sp * 9.0);
		float land = smoothstep(0.50, 0.55, land_n + (detail - 0.5) * 0.12);
		float lat = abs(sp.y);
		vec3 ocean = mix(vec3(0.02, 0.10, 0.28), vec3(0.04, 0.26, 0.48), smoothstep(0.35, 0.55, land_n));
		vec3 grass = mix(vec3(0.12, 0.34, 0.12), vec3(0.42, 0.40, 0.20), smoothstep(0.55, 0.78, land_n + (detail - 0.5) * 0.3));
		vec3 surf = mix(ocean, grass, land);
		surf = mix(surf, vec3(0.88, 0.94, 1.0), smoothstep(0.80, 0.92, lat + (detail - 0.5) * 0.15));
		float cl = fbm(vec3(sp.x * 3.4 + time_s * 0.02, sp.y * 3.4, sp.z * 3.4) + 20.0);
		float clouds = smoothstep(0.50, 0.72, cl);
		surf = mix(surf, vec3(1.0), clouds * 0.85);
		float lit = dot(n, sd);
		vec3 shaded = surf * (0.04 + 1.05 * max(lit, 0.0));
		float city = step(0.78, hash13(floor(sp * 140.0))) * land * (1.0 - clouds) * smoothstep(0.10, -0.25, lit);
		vec3 lights = vec3(1.0, 0.75, 0.38) * city * 0.9;
		col = shaded + lights;
		float rim = pow(1.0 - n.z, 2.6);
		float scatter = smoothstep(-0.25, 0.5, lit);
		col += atmo_color * rim * (0.15 + 1.6 * scatter);
		col += vec3(1.0, 0.45, 0.2) * pow(1.0 - n.z, 4.0) * smoothstep(0.25, 0.0, abs(lit)) * 0.6;
		vec3 h = normalize(sd + vec3(0.0, 0.0, 1.0));
		float spec = pow(max(dot(n, h), 0.0), 90.0) * (1.0 - land) * (1.0 - clouds);
		col += vec3(1.0, 0.95, 0.85) * spec * 0.6;
		alpha = smoothstep(radius, radius - 0.004, d);
	} else {
		float out_d = d - radius;
		vec2 dir2 = p / max(d, 0.0001);
		float lit_out = clamp(dot(vec3(dir2.x, -dir2.y, 0.0), sd) * 0.5 + 0.55, 0.0, 1.0);
		float glow = exp(-out_d / 0.022) * lit_out + exp(-out_d / 0.09) * 0.25 * lit_out;
		col = atmo_color * glow * 1.15;
		alpha = clamp(glow, 0.0, 1.0);
	}
	COLOR = vec4(col, alpha);
}
