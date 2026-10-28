extends SceneTree
## Oyunun tüm seslerini prosedürel olarak üretir ve assets/audio/*.res olarak kaydeder.
## Dışarıdan ses dosyası gerekmez; sonuçlar tohuma bağlı olduğu için her seferinde aynıdır.
## Çalıştırma: godot --headless --path . -s res://tools/gen_sfx.gd

const RATE := 22050
const OUT := "res://assets/audio/"

var rng := RandomNumberGenerator.new()


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	for i in 4:
		_save("footstep_%d" % i, _footstep(i))
	_save("swing", _swing())
	_save("chop", _chop())
	_save("hit_flesh", _hit_flesh())
	_save("pickup", _pickup())
	_save("eat", _eat())
	_save("drink", _drink())
	_save("craft", _craft())
	_save("ignite", _ignite())
	_save("splash", _splash())
	_save("tree_fall", _tree_fall())
	_save("bite", _bite())
	_save("deer_alarm", _deer_alarm())
	_save("wolf_growl", _wolf_growl())
	_save("wolf_howl", _wolf_howl())
	_save("ui_click", _ui_click())
	_save("bear_roar", _bear_roar())
	_save("snake_hiss", _snake_hiss())
	_save("bird_takeoff", _bird_takeoff())
	_save("wolf_snarl", _wolf_snarl())
	_save("bear_growl", _bear_growl())
	_save("croc_hiss", _croc_hiss())
	_save("dog_bark", _dog_bark(false))
	_save("puppy_yip", _dog_bark(true))
	_save("dog_whine", _dog_whine())
	_save("bow_release", _bow_release())
	_save("arrow_hit", _arrow_hit())
	_save("trade", _trade())
	_save("drum_loop", _loopify(_drums(8.4), 0.4), true)
	_save("fire_loop", _loopify(_fire(4.3), 0.3), true)
	_save("wind_loop", _loopify(_wind(8.5), 0.5), true)
	_save("birds_loop", _loopify(_birds(12.4), 0.4), true)
	_save("crickets_loop", _loopify(_crickets(6.3), 0.3), true)
	_save("cave_loop", _loopify(_cave(9.4), 0.4), true)
	print("Sesler üretildi: ", OUT)
	quit()


# --- Sesler ---

func _footstep(variant: int) -> PackedFloat32Array:
	rng.seed = 100 + variant
	var n := int(RATE * 0.18)
	var s := _noise(n)
	s = _lowpass(s, 1600.0 + variant * 150.0)
	s = _highpass(s, 180.0)
	var second := rng.randi_range(int(RATE * 0.03), int(RATE * 0.06))
	for i in n:
		var t := float(i) / RATE
		var e := _env(t, 0.004, 28.0)
		if i > second:
			e += _env(float(i - second) / RATE, 0.003, 40.0) * 0.5
		s[i] *= e
	return s


func _swing() -> PackedFloat32Array:
	rng.seed = 2
	var n := int(RATE * 0.3)
	var src := _noise(n)
	var out := PackedFloat32Array()
	out.resize(n)
	var y := 0.0
	for i in n:
		var t := float(i) / n
		var fc := 400.0 + sin(t * PI) * 2600.0
		var a := exp(-TAU * fc / RATE)
		y = (1.0 - a) * src[i] + a * y
		out[i] = y * pow(sin(t * PI), 2.0)
	return _highpass(out, 300.0)


func _chop() -> PackedFloat32Array:
	rng.seed = 3
	var n := int(RATE * 0.35)
	var click := _lowpass(_noise(n), 3500.0)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		var body := sin(TAU * 170.0 * t) * 0.7 + sin(TAU * 255.0 * t) * 0.45 + sin(TAU * 1150.0 * t) * 0.2 * exp(-t * 80.0)
		out[i] = body * exp(-t * 22.0) + click[i] * exp(-t * 120.0) * 1.2
	return out


func _hit_flesh() -> PackedFloat32Array:
	rng.seed = 4
	var n := int(RATE * 0.25)
	var thud := _lowpass(_noise(n), 700.0)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		out[i] = sin(TAU * 85.0 * t) * exp(-t * 18.0) * 0.8 + thud[i] * exp(-t * 30.0) * 1.5
	return out


func _pickup() -> PackedFloat32Array:
	var n := int(RATE * 0.16)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		var f := 660.0 if t < 0.06 else 990.0
		var local := t if t < 0.06 else t - 0.06
		out[i] = sin(TAU * f * t) * _env(local, 0.005, 30.0) * 0.6
	return out


func _eat() -> PackedFloat32Array:
	rng.seed = 6
	var n := int(RATE * 0.5)
	var out := PackedFloat32Array()
	out.resize(n)
	var src := _highpass(_noise(n), 1200.0)
	for k in 4:
		var start := int(RATE * (0.02 + k * 0.11 + rng.randf() * 0.03))
		var amp := rng.randf_range(0.6, 1.0)
		for i in range(start, mini(n, start + int(RATE * 0.05))):
			out[i] += src[i] * _env(float(i - start) / RATE, 0.002, 60.0) * amp
	return out


func _drink() -> PackedFloat32Array:
	var n := int(RATE * 0.6)
	var out := PackedFloat32Array()
	out.resize(n)
	for k in 3:
		var start := int(RATE * (0.02 + k * 0.18))
		var phase := 0.0
		for i in range(start, mini(n, start + int(RATE * 0.14))):
			var t := float(i - start) / RATE
			var f := lerpf(320.0, 140.0, t / 0.14)
			phase += TAU * f / RATE
			out[i] += sin(phase) * sin(PI * t / 0.14) * 0.7
	return _lowpass(out, 1200.0)


func _craft() -> PackedFloat32Array:
	rng.seed = 8
	var n := int(RATE * 0.45)
	var out := PackedFloat32Array()
	out.resize(n)
	var click := _lowpass(_noise(n), 3000.0)
	for k in 3:
		var start := int(RATE * k * 0.13)
		var f: float = [410.0, 520.0, 380.0][k]
		for i in range(start, n):
			var t := float(i - start) / RATE
			out[i] += (sin(TAU * f * t) * 0.6 + click[i] * 0.8 * exp(-t * 90.0)) * exp(-t * 35.0)
	return out


func _ignite() -> PackedFloat32Array:
	rng.seed = 9
	var n := int(RATE * 0.8)
	var src := _noise(n)
	var out := PackedFloat32Array()
	out.resize(n)
	var y := 0.0
	for i in n:
		var t := float(i) / n
		var fc := lerpf(200.0, 1800.0, t)
		var a := exp(-TAU * fc / RATE)
		y = (1.0 - a) * src[i] + a * y
		out[i] = y * sin(t * PI) * (0.6 + 0.4 * t)
	return out


func _splash() -> PackedFloat32Array:
	rng.seed = 10
	var n := int(RATE * 0.7)
	var s := _lowpass(_noise(n), 2200.0)
	for i in n:
		var t := float(i) / RATE
		s[i] *= _env(t, 0.01, 7.0)
		s[i] += sin(TAU * (500.0 + 300.0 * sin(t * 40.0)) * t) * 0.1 * exp(-t * 5.0)
	return s


func _tree_fall() -> PackedFloat32Array:
	rng.seed = 11
	var n := int(RATE * 2.8)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	var crash_at := int(RATE * 1.55)
	var crash := _lowpass(_noise(n), 1400.0)
	for i in n:
		var t := float(i) / RATE
		if i < crash_at:
			var f := 75.0 + sin(t * 9.0) * 12.0 + rng.randf_range(-6.0, 6.0)
			phase += TAU * f / RATE
			var saw := fposmod(phase / TAU, 1.0) * 2.0 - 1.0
			out[i] = saw * smoothstep(0.0, 1.4, t) * 0.35
		else:
			var tc := float(i - crash_at) / RATE
			out[i] = crash[i] * exp(-tc * 3.5) * 1.4 + sin(TAU * 48.0 * tc) * exp(-tc * 6.0)
	return _lowpass(out, 2500.0)


func _bite() -> PackedFloat32Array:
	rng.seed = 12
	var n := int(RATE * 0.22)
	var snap := _highpass(_noise(n), 900.0)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		out[i] = snap[i] * exp(-t * 90.0) * 1.3 + sin(TAU * 110.0 * t) * exp(-t * 25.0) * 0.6
	return out


func _deer_alarm() -> PackedFloat32Array:
	rng.seed = 13
	var n := int(RATE * 0.35)
	var src := _noise(n)
	var band := _highpass(_lowpass(src, 1300.0), 600.0)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		out[i] = (band[i] * 2.2 + sin(TAU * 640.0 * t) * 0.4) * _env(t, 0.008, 14.0)
	return out


func _wolf_growl() -> PackedFloat32Array:
	rng.seed = 14
	var n := int(RATE * 1.3)
	var src := _lowpass(_noise(n), 300.0)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		var rough := 0.55 + 0.45 * sin(TAU * (28.0 + sin(t * 3.0) * 5.0) * t)
		var env := smoothstep(0.0, 0.15, t) * (1.0 - smoothstep(1.0, 1.3, t))
		out[i] = (src[i] * 3.0 + sin(TAU * 82.0 * t) * 0.3) * rough * env
	return out


func _wolf_howl() -> PackedFloat32Array:
	rng.seed = 15
	var dur := 3.4
	var n := int(RATE * dur)
	var out := PackedFloat32Array()
	out.resize(n)
	var breath := _lowpass(_noise(n), 900.0)
	var phase := 0.0
	for i in n:
		var t := float(i) / RATE
		var f: float
		if t < 0.45:
			f = lerpf(300.0, 520.0, smoothstep(0.0, 0.45, t))
		elif t < 2.5:
			f = lerpf(520.0, 565.0, (t - 0.45) / 2.05)
		else:
			f = lerpf(565.0, 370.0, smoothstep(2.5, dur, t))
		f += sin(TAU * 5.0 * t) * 6.0 * smoothstep(0.5, 1.2, t)
		phase += TAU * f / RATE
		var tone := sin(phase) + sin(phase * 2.0) * 0.28 + sin(phase * 3.0) * 0.1
		var env := smoothstep(0.0, 0.35, t) * (1.0 - smoothstep(dur - 0.7, dur, t))
		out[i] = (tone * 0.75 + breath[i] * 0.6) * env
	return out


func _bear_roar() -> PackedFloat32Array:
	rng.seed = 30
	var n := int(RATE * 1.8)
	var src := _lowpass(_noise(n), 450.0)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / RATE
		var f := lerpf(140.0, 85.0, t / 1.8)
		phase += TAU * f / RATE
		var rough := 0.6 + 0.4 * sin(TAU * 22.0 * t)
		var env := smoothstep(0.0, 0.2, t) * (1.0 - smoothstep(1.2, 1.8, t))
		out[i] = (src[i] * 3.2 + sin(phase) * 0.5 + sin(phase * 2.0) * 0.25) * rough * env
	return out


func _snake_hiss() -> PackedFloat32Array:
	rng.seed = 31
	var n := int(RATE * 1.1)
	var s := _highpass(_noise(n), 2800.0)
	for i in n:
		var t := float(i) / RATE
		# Nefes alır gibi dalgalanan uzun tıslama.
		var swell := 0.7 + 0.3 * sin(TAU * 7.0 * t)
		s[i] *= smoothstep(0.0, 0.05, t) * (1.0 - smoothstep(0.8, 1.1, t)) * swell
	return s


## Kurt saldırırken: kısa, sert hırıltı ve havlama.
func _wolf_snarl() -> PackedFloat32Array:
	rng.seed = 33
	var n := int(RATE * 0.7)
	var src := _lowpass(_noise(n), 900.0)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / RATE
		var f := lerpf(260.0, 170.0, t / 0.7)
		phase += TAU * f / RATE
		var rough := 0.5 + 0.5 * sin(TAU * 38.0 * t)
		var env := _env(t, 0.02, 4.0)
		out[i] = (src[i] * 2.4 + sin(phase) * 0.45 + sin(phase * 2.0) * 0.2) * rough * env
	return out


## Ayı yaklaşırken: derin, uzun homurtu.
func _bear_growl() -> PackedFloat32Array:
	rng.seed = 34
	var n := int(RATE * 1.6)
	var src := _lowpass(_noise(n), 260.0)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		var rough := 0.55 + 0.45 * sin(TAU * (18.0 + sin(t * 2.0) * 4.0) * t)
		var env := smoothstep(0.0, 0.25, t) * (1.0 - smoothstep(1.2, 1.6, t))
		out[i] = (src[i] * 3.5 + sin(TAU * 62.0 * t) * 0.35) * rough * env
	return out


## Timsah: boğuk, derin tıslama.
func _croc_hiss() -> PackedFloat32Array:
	rng.seed = 35
	var n := int(RATE * 1.2)
	var hiss := _lowpass(_highpass(_noise(n), 500.0), 2500.0)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		out[i] = (hiss[i] * 1.6 + sin(TAU * 48.0 * t) * 0.3) * smoothstep(0.0, 0.1, t) * (1.0 - smoothstep(0.8, 1.2, t))
	return out


## Köpek havlaması; yavruda daha ince ve kısa.
func _dog_bark(puppy: bool) -> PackedFloat32Array:
	rng.seed = 36 if puppy else 37
	var dur := 0.22 if puppy else 0.3
	var n := int(RATE * dur)
	var src := _lowpass(_noise(n), 1800.0 if puppy else 1100.0)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / RATE
		var f := lerpf(900.0 if puppy else 420.0, 600.0 if puppy else 260.0, t / dur)
		phase += TAU * f / RATE
		var env := _env(t, 0.01, 12.0 if puppy else 9.0)
		out[i] = (sin(phase) * 0.7 + sin(phase * 2.0) * 0.3 + src[i] * 1.2) * env
	return out


func _dog_whine() -> PackedFloat32Array:
	var n := int(RATE * 0.6)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / RATE
		phase += TAU * lerpf(900.0, 1300.0, sin(t / 0.6 * PI)) / RATE
		out[i] = sin(phase) * sin(t / 0.6 * PI) * 0.6
	return out


func _bow_release() -> PackedFloat32Array:
	rng.seed = 38
	var n := int(RATE * 0.35)
	var out := PackedFloat32Array()
	out.resize(n)
	var whoosh := _highpass(_noise(n), 1500.0)
	for i in n:
		var t := float(i) / RATE
		out[i] = sin(TAU * 130.0 * t) * exp(-t * 18.0) * 0.8 + whoosh[i] * exp(-t * 14.0) * 0.4
	return out


func _arrow_hit() -> PackedFloat32Array:
	rng.seed = 39
	var n := int(RATE * 0.2)
	var src := _lowpass(_noise(n), 2500.0)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		out[i] = (src[i] + sin(TAU * 320.0 * t) * 0.5) * exp(-t * 35.0)
	return out


## Takas tamamlandı: iki tahta tıkırtısı ve hafif çan.
func _trade() -> PackedFloat32Array:
	var n := int(RATE * 0.45)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		out[i] = sin(TAU * 880.0 * t) * exp(-t * 6.0) * 0.35 + sin(TAU * 1320.0 * t) * exp(-t * 8.0) * 0.2
	return out


## Köyden gelen uzak davul sesi.
func _drums(dur: float) -> PackedFloat32Array:
	rng.seed = 40
	var n := int(RATE * dur)
	var out := PackedFloat32Array()
	out.resize(n)
	var beat := 0.6
	var t := 0.0
	var k := 0
	while t < dur:
		var start := int(t * RATE)
		var f := 70.0 if k % 4 != 3 else 110.0
		var amp := 1.0 if k % 2 == 0 else 0.6
		for i in range(start, mini(n, start + int(RATE * 0.4))):
			var x := float(i - start) / RATE
			out[i] += sin(TAU * f * x * (1.0 - x * 0.5)) * exp(-x * 9.0) * amp
		t += beat * (0.5 if k % 4 == 1 else 1.0)
		k += 1
	return _lowpass(out, 400.0)


func _bird_takeoff() -> PackedFloat32Array:
	rng.seed = 32
	var n := int(RATE * 0.7)
	var src := _lowpass(_noise(n), 900.0)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		var flap := pow(maxf(sin(TAU * 13.0 * t), 0.0), 3.0)
		out[i] = src[i] * flap * (1.0 - t / 0.7)
	return out


func _ui_click() -> PackedFloat32Array:
	var n := int(RATE * 0.05)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		out[i] = sin(TAU * 1300.0 * t) * exp(-t * 120.0) * 0.5
	return out


func _fire(dur: float) -> PackedFloat32Array:
	rng.seed = 20
	var n := int(RATE * dur)
	var white := _noise(n)
	var out := PackedFloat32Array()
	out.resize(n)
	var brown := 0.0
	for i in n:
		brown = clampf(brown + white[i] * 0.02, -1.0, 1.0) * 0.998
		out[i] = brown * 0.6
	out = _lowpass(out, 500.0)
	var pops := _highpass(_noise(n), 2000.0)
	var t := 0.0
	while t < dur:
		t += -log(maxf(rng.randf(), 0.0001)) / 14.0
		var start := int(t * RATE)
		var len := int(RATE * rng.randf_range(0.003, 0.012))
		var amp := rng.randf_range(0.2, 1.0)
		for i in range(start, mini(n, start + len)):
			out[i] += pops[i] * amp * (1.0 - float(i - start) / len)
	return out


func _wind(dur: float) -> PackedFloat32Array:
	rng.seed = 21
	var n := int(RATE * dur)
	var src := _noise(n)
	var out := PackedFloat32Array()
	out.resize(n)
	var y := 0.0
	for i in n:
		var t := float(i) / RATE
		var fc := 380.0 + sin(t * 0.7) * 160.0 + sin(t * 1.9 + 1.0) * 90.0
		var a := exp(-TAU * fc / RATE)
		y = (1.0 - a) * src[i] + a * y
		out[i] = y * (0.65 + 0.35 * sin(t * 0.45 + 0.5))
	return out


func _birds(dur: float) -> PackedFloat32Array:
	rng.seed = 22
	var n := int(RATE * dur)
	var out := PackedFloat32Array()
	out.resize(n)
	var t := 0.3
	while t < dur - 1.0:
		var base := rng.randf_range(2300.0, 3600.0)
		var up := rng.randf() < 0.5
		var reps := rng.randi_range(2, 4)
		var amp := rng.randf_range(0.3, 0.8)
		for r in reps:
			var start := int((t + r * 0.13) * RATE)
			var length := int(RATE * rng.randf_range(0.05, 0.1))
			var phase := 0.0
			for i in range(start, mini(n, start + length)):
				var k := float(i - start) / length
				var f := base + (900.0 if up else -700.0) * k
				phase += TAU * f / RATE
				out[i] += sin(phase) * sin(PI * k) * amp * (0.85 + 0.15 * sin(TAU * 30.0 * k))
		t += rng.randf_range(0.6, 1.8)
	return out


## Mağara: alçak uğultu ve arada su damlaları.
func _cave(dur: float) -> PackedFloat32Array:
	rng.seed = 24
	var n := int(RATE * dur)
	var out := _lowpass(_noise(n), 120.0)
	for i in n:
		out[i] *= 0.8
	var t := 0.4
	while t < dur - 0.5:
		var start := int(t * RATE)
		var f := rng.randf_range(900.0, 1700.0)
		for i in range(start, mini(n, start + int(RATE * 0.25))):
			var k := float(i - start) / RATE
			out[i] += sin(TAU * f * k * (1.0 + k * 2.0)) * exp(-k * 25.0) * 0.6
		t += rng.randf_range(0.8, 2.4)
	return out


func _crickets(dur: float) -> PackedFloat32Array:
	rng.seed = 23
	var n := int(RATE * dur)
	var out := PackedFloat32Array()
	out.resize(n)
	for c in 3:
		var f := rng.randf_range(4000.0, 4800.0)
		var amp := rng.randf_range(0.25, 0.5)
		var t := rng.randf() * 0.4
		while t < dur:
			for p in 3:
				var start := int((t + p * 0.035) * RATE)
				var length := int(RATE * 0.02)
				for i in range(start, mini(n, start + length)):
					var k := float(i - start) / length
					out[i] += sin(TAU * f * float(i) / RATE) * sin(PI * k) * amp
			t += rng.randf_range(0.42, 0.62)
	return out


# --- Yardımcılar ---

func _noise(n: int) -> PackedFloat32Array:
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		s[i] = rng.randf_range(-1.0, 1.0)
	return s


func _lowpass(s: PackedFloat32Array, fc: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(s.size())
	var a := exp(-TAU * fc / RATE)
	var y := 0.0
	for i in s.size():
		y = (1.0 - a) * s[i] + a * y
		out[i] = y
	return out


func _highpass(s: PackedFloat32Array, fc: float) -> PackedFloat32Array:
	var low := _lowpass(s, fc)
	var out := PackedFloat32Array()
	out.resize(s.size())
	for i in s.size():
		out[i] = s[i] - low[i]
	return out


## Hızlı yükselen, üstel sönen zarf.
func _env(t: float, attack: float, decay: float) -> float:
	if t < attack:
		return t / attack
	return exp(-(t - attack) * decay)


## Sonun son 'fade' saniyesini başa karıştırarak kesintisiz döngü yapar.
func _loopify(s: PackedFloat32Array, fade: float) -> PackedFloat32Array:
	var f := int(fade * RATE)
	var n := s.size() - f
	var out := s.slice(0, n)
	for i in f:
		var k := float(i) / f
		out[i] = s[i] * k + s[n + i] * (1.0 - k)
	return out


func _save(name: String, samples: PackedFloat32Array, loop := false) -> void:
	var peak := 0.0001
	for v in samples:
		peak = maxf(peak, absf(v))
	var gain := 0.9 / peak
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i] * gain, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = bytes
	if loop:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = samples.size()
	var err := ResourceSaver.save(wav, OUT + name + ".res")
	if err != OK:
		push_error("Kaydedilemedi: %s (%s)" % [name, error_string(err)])
