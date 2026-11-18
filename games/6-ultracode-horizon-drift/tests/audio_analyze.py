"""Offline analysis of the WAV files written by tests/audio_dump.gd (a sound card is not needed).

  python tests/audio_analyze.py <wav_dir> <out_dir> [name1 name2 ...]

Writes <out_dir>/sheet_N.png (waveform envelope + log-frequency spectrogram per sound) and prints a table:
duration, peak dBFS, RMS dBFS, DC offset, spectral centroid, energy per band (%), and for loops the seam click ratio.
"""
import os
import sys
import wave

import numpy as np
from PIL import Image, ImageDraw

BANDS = [(0, 150), (150, 600), (600, 2500), (2500, 6000), (6000, 24000)]


def load(path):
    with wave.open(path, "rb") as w:
        n, ch, sr, sw = w.getnframes(), w.getnchannels(), w.getframerate(), w.getsampwidth()
        raw = w.readframes(n)
    a = np.frombuffer(raw, dtype="<i2").astype(np.float32) / 32768.0
    if ch == 2:
        a = a.reshape(-1, 2)
    else:
        a = a.reshape(-1, 1)
    return a, sr


def spectrogram(x, sr, cols, rows, fmin=40.0, fmax=11000.0):
    win = 1024 if sr >= 16000 else 512
    if len(x) < win * 2:
        x = np.pad(x, (0, win * 2 - len(x)))
    hop = max((len(x) - win) // max(cols - 1, 1), 1)
    w = np.hanning(win).astype(np.float32)
    frames = []
    for i in range(cols):
        s = min(i * hop, len(x) - win)
        seg = x[s:s + win] * w
        frames.append(np.abs(np.fft.rfft(seg)))
    S = np.array(frames).T  # bins x cols
    freqs = np.fft.rfftfreq(win, 1.0 / sr)
    fmax = min(fmax, sr / 2.0 - 1)
    ys = np.geomspace(fmin, fmax, rows)
    out = np.zeros((rows, cols), dtype=np.float32)
    for r, f in enumerate(ys):
        k = np.searchsorted(freqs, f)
        k = min(max(k, 1), len(freqs) - 1)
        out[r] = S[k]
    db = 20 * np.log10(out / win * 4 + 1e-7)
    return db[::-1]  # high frequencies on top


def colormap(v):
    # v in 0..1 -> RGB (black -> blue -> magenta -> orange -> white)
    stops = [(0.0, (0, 0, 0)), (0.25, (30, 20, 110)), (0.5, (170, 30, 120)), (0.75, (250, 140, 30)), (1.0, (255, 255, 220))]
    v = np.clip(v, 0, 1)
    out = np.zeros(v.shape + (3,), dtype=np.float32)
    for (a, ca), (b, cb) in zip(stops[:-1], stops[1:]):
        m = (v >= a) & (v <= b)
        t = np.where(m, (v - a) / (b - a), 0)[..., None]
        out = np.where(m[..., None], np.array(ca) * (1 - t) + np.array(cb) * t, out)
    return out.astype(np.uint8)


def panel(name, a, sr, W=360, H=150):
    mono = a.mean(axis=1)
    img = Image.new("RGB", (W, H), (12, 12, 16))
    d = ImageDraw.Draw(img)
    # envelope
    ENV_H = 40
    seg = np.array_split(np.abs(mono), W)
    env = np.array([s.max() if len(s) else 0 for s in seg])
    for x in range(W):
        h = int(env[x] * (ENV_H / 2 - 1))
        d.line([(x, ENV_H // 2 - h), (x, ENV_H // 2 + h)], fill=(90, 200, 120) if env[x] < 0.98 else (255, 60, 60))
    # spectrogram
    SH = H - ENV_H - 14
    db = spectrogram(mono, sr, W, SH)
    v = (db + 80.0) / 70.0
    rgb = colormap(v)
    img.paste(Image.fromarray(rgb, "RGB"), (0, ENV_H))
    dur = len(mono) / sr
    d.text((3, H - 12), f"{name}  {dur:.2f}s  {sr}Hz", fill=(220, 220, 230))
    return img


def stats(name, a, sr):
    mono = a.mean(axis=1)
    peak = np.abs(a).max()
    rms = np.sqrt((mono ** 2).mean())
    dc = mono.mean()
    spec = np.abs(np.fft.rfft(mono * np.hanning(len(mono)))) ** 2
    freqs = np.fft.rfftfreq(len(mono), 1.0 / sr)
    tot = spec.sum() + 1e-12
    cen = (spec * freqs).sum() / tot
    bands = [spec[(freqs >= lo) & (freqs < hi)].sum() / tot * 100 for lo, hi in BANDS]
    # seam: jump between last and first sample relative to typical sample-to-sample diff
    seam = abs(mono[0] - mono[-1])
    typ = np.abs(np.diff(mono)).mean() + 1e-9
    return peak, rms, dc, cen, bands, seam / typ


def main():
    wav_dir, out_dir = sys.argv[1], sys.argv[2]
    names = sys.argv[3:]
    os.makedirs(out_dir, exist_ok=True)
    files = sorted(f for f in os.listdir(wav_dir) if f.endswith(".wav"))
    if names:
        files = [f for f in files if f[:-4] in names]
    panels = []
    print(f"{'name':20s} {'dur':>6s} {'peak':>6s} {'rms':>6s} {'dc':>7s} {'centroid':>8s}  bands%(<150,<600,<2.5k,<6k,>6k)  seam")
    for f in files:
        a, sr = load(os.path.join(wav_dir, f))
        name = f[:-4]
        peak, rms, dc, cen, bands, seam = stats(name, a, sr)
        flag = ""
        if peak >= 0.999:
            flag += " CLIP"
        if abs(dc) > 0.02:
            flag += " DC"
        if seam > 6 and name.split("_")[0] in ("eng", "amb", "alarm", "jetpack", "mining", "warp", "blackhole") and name not in ("warp_jump", "warp_charge", "warp_arrive", "blackhole_enter"):
            flag += " SEAM?"
        print(f"{name:20s} {len(a)/sr:6.2f} {20*np.log10(peak+1e-9):6.1f} {20*np.log10(rms+1e-9):6.1f} {dc:7.4f} {cen:8.0f}  " + " ".join(f"{b:5.1f}" for b in bands) + f"  {seam:5.1f}{flag}")
        panels.append(panel(name, a, sr))
    per = 24
    cols = 3
    for si in range(0, len(panels), per):
        chunk = panels[si:si + per]
        rows = (len(chunk) + cols - 1) // cols
        W, H = chunk[0].size
        sheet = Image.new("RGB", (W * cols, H * rows), (0, 0, 0))
        for i, p in enumerate(chunk):
            sheet.paste(p, ((i % cols) * W, (i // cols) * H))
        sheet.save(os.path.join(out_dir, f"sheet_{si // per}.png"))
    print("sheets:", (len(panels) + per - 1) // per)


if __name__ == "__main__":
    main()
