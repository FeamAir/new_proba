"""Синтез всех звуков игры (стиль «стекло и кристаллы»). Запуск: python3 tools/make_sounds.py
Результат: assets/sounds/*.wav и music.ogg (через ffmpeg). Сторонних ассетов нет."""
import numpy as np, wave, os, subprocess

SR = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "sounds")
rng = np.random.default_rng(7)

def t(d): return np.arange(int(SR * d)) / SR

def env(n, a=0.003, d=None, curve=4.0):
    x = np.arange(n) / SR
    e = np.minimum(1.0, x / max(a, 1e-4))
    dur = n / SR
    e *= np.exp(-curve * x / dur) if d is None else np.exp(-x / d)
    e[-int(SR*0.005):] *= np.linspace(1, 0, int(SR*0.005))
    return e

def bell(f, d, decay=None, harm=(1, 0.35, 0.12)):
    x = t(d)
    s = sum(a * np.sin(2*np.pi*f*(i+1 if i < 1 else (2 if i == 1 else 3))*x) for i, a in enumerate(harm))
    return s * env(len(x), d=decay or d/3)

def glide(f0, f1, d):
    x = t(d)
    f = np.geomspace(f0, f1, len(x))
    ph = 2*np.pi*np.cumsum(f)/SR
    return np.sin(ph)

def noise(d): return rng.uniform(-1, 1, int(SR*d))

def mix(*parts):
    n = max(len(p) for p in parts)
    out = np.zeros(n)
    for p in parts: out[:len(p)] += p
    return out

def place(base, part, at):
    i = int(at*SR)
    need = i + len(part)
    if need > len(base): base = np.concatenate([base, np.zeros(need-len(base))])
    base[i:need] += part
    return base

def echo(s, delay=0.11, fb=0.3, n=3):
    out = s.copy()
    for k in range(1, n+1):
        out = place(out, s*(fb**k), delay*k)
    return out

def save(name, s, vol=0.8):
    s = s / (np.max(np.abs(s)) + 1e-9) * vol
    data = (s * 32767).astype(np.int16)
    with wave.open(os.path.join(OUT, name + ".wav"), "w") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR); w.writeframes(data.tobytes())

def lowpass(s, k=8):
    return np.convolve(s, np.ones(k)/k, mode="same")

os.makedirs(OUT, exist_ok=True)
save("move", bell(1200, 0.035, decay=0.008, harm=(1, 0.2, 0)), 0.35)
save("rotate", glide(700, 1100, 0.07)*env(int(SR*0.07)) + 0.1*noise(0.07)*env(int(SR*0.07)), 0.45)
save("land", mix(np.sin(2*np.pi*180*t(0.09))*env(int(SR*0.09)), lowpass(noise(0.03), 20)*env(int(SR*0.03))), 0.55)
save("drop", mix(glide(300, 90, 0.15)*env(int(SR*0.15)), lowpass(noise(0.06), 12)*env(int(SR*0.06))), 0.8)
for n in range(1, 5):
    notes = [523.25, 659.25, 783.99, 1046.5, 1318.5][:n+1]
    s = np.zeros(1)
    for i, f in enumerate(notes):
        s = place(s, bell(f, 0.45, decay=0.12), i*0.06)
    save(f"line{n}", echo(s, 0.09, 0.25, 2), 0.75)
for k in range(1, 6):  # комбо: лестница по полутону
    f = 659.25 * 2**((k*2)/12)
    s = mix(bell(f, 0.3, decay=0.08), bell(f*1.5, 0.3, decay=0.07)*0.6)
    save(f"combo{k}", echo(s, 0.07, 0.3, 2), 0.7)
s = glide(400, 1600, 0.5)*env(int(SR*0.5), d=0.25)
for i in range(10):
    s = place(s, bell(rng.uniform(2000, 4000), 0.06, decay=0.015)*0.4, 0.2 + i*0.045)
save("crystal", echo(mix(bell(1567.98, 0.4, decay=0.1), bell(2093, 0.4, decay=0.08)*0.5), 0.08, 0.35, 3), 0.7)
save("levelup", echo(s, 0.1, 0.3, 2), 0.75)
s = np.zeros(1)
for i, f in enumerate([392, 329.63, 261.63, 196]):
    s = place(s, bell(f, 0.5, decay=0.18, harm=(1, 0.25, 0.05)), i*0.18)
s = place(s, np.sin(2*np.pi*80*t(0.6))*env(int(SR*0.6), d=0.25)*0.6, 0.7)
save("gameover", s, 0.7)
save("click", bell(880, 0.05, decay=0.012, harm=(1, 0.1, 0)), 0.45)
save("pause", mix(bell(660, 0.12, decay=0.04), np.zeros(1)), 0.4)

# Музыка: спокойный эмбиент, пентатоника ля-минор, 90 уд/мин, 32 такта, бесшовная петля
bpm = 90; eighth = 60/bpm/2; bars = 16
length = bars * 8 * eighth
music = np.zeros(int(SR*length) + SR*2)
penta = [220, 261.63, 293.66, 329.63, 392, 440, 523.25, 587.33, 659.25]
chords = [[110, 164.81], [87.31, 130.81], [98, 146.83], [82.41, 123.47]]  # Am F G Em
for b in range(bars):
    root = chords[b % 4]
    x = t(8*eighth + 0.5)
    pad = sum(np.sin(2*np.pi*f*x) + 0.3*np.sin(2*np.pi*f*2.005*x) for f in root)
    pad *= np.minimum(1, x/0.6) * np.minimum(1, np.maximum(0, (8*eighth + 0.5 - x))/0.6) * 0.18
    music = place(music, pad, b*8*eighth)
    idx = rng.integers(0, len(penta))
    for e in range(8):
        if rng.random() < 0.72:
            idx = int(np.clip(idx + rng.integers(-2, 3), 0, len(penta)-1))
            music = place(music, bell(penta[idx]*2 if rng.random() < 0.3 else penta[idx], 0.9, decay=0.25)*0.22, b*8*eighth + e*eighth)
music = echo(music, eighth*1.5, 0.3, 3)
n = int(SR*length)
tail = music[n:]
music = music[:n]
music[:len(tail)] += tail  # хвост эха переносим в начало: петля без щелчка
save("music", music, 0.6)
wav = os.path.join(OUT, "music.wav")
subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-c:a", "libvorbis", "-q:a", "4", os.path.join(OUT, "music.ogg")], check=True)
os.remove(wav)
print("ok", sorted(os.listdir(OUT)))
