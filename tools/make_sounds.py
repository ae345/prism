"""Prism のシステムサウンド（WAV）を合成する。外部ライブラリは使わない。

音の方針：短く、やわらかく、高めの澄んだ音。ベルのような倍音に、ごく短い残響。
デザイン案（キャンバス）の効果音も、同じレシピを Web Audio で鳴らしている。

使い方: python tools/make_sounds.py
出力先: system_files/usr/share/sounds/myos/stereo/
"""

from __future__ import annotations

import math
import os
import random
import struct
import wave
from pathlib import Path

RATE = 48_000
OUT = Path(
    os.environ.get("MYOS_SOUND_OUT")
    or Path(__file__).resolve().parent.parent / "system_files/usr/share/sounds/myos/stereo"
)

# ベル風の倍音（周波数の倍率, 音量）
BELL = [(1.0, 1.0), (2.0, 0.32), (3.01, 0.12), (4.2, 0.05)]
SOFT = [(1.0, 1.0), (2.0, 0.12)]


class Track:
    def __init__(self, seconds: float):
        self.samples = [0.0] * int(seconds * RATE)

    def tone(
        self,
        start: float,
        freq: float,
        length: float,
        volume: float = 0.5,
        attack: float = 0.004,
        partials: list[tuple[float, float]] = BELL,
        glide_to: float | None = None,
    ) -> None:
        """指数的に減衰する音を1つ足す。glide_to を指定すると音程が滑らかに変わる。"""
        begin = int(start * RATE)
        count = int(length * RATE)
        phases = [0.0] * len(partials)
        for i in range(count):
            n = begin + i
            if n >= len(self.samples):
                break
            t = i / RATE
            current = freq if glide_to is None else freq + (glide_to - freq) * min(1.0, t / (length * 0.45))
            envelope = min(1.0, t / attack) * math.exp(-5.0 * t / length)
            value = 0.0
            for k, (ratio, gain) in enumerate(partials):
                phases[k] += 2 * math.pi * current * ratio / RATE
                # 高い倍音ほど早く消えるようにする
                value += gain * math.sin(phases[k]) * math.exp(-ratio * 1.5 * t / length)
            self.samples[n] += volume * envelope * value

    def noise(self, start: float, length: float, volume: float = 0.3, brightness: float = 0.5) -> None:
        """シャッター音などに使う、短いノイズ。brightness が高いほど明るい音になる。"""
        begin = int(start * RATE)
        low = 0.0
        for i in range(int(length * RATE)):
            n = begin + i
            if n >= len(self.samples):
                break
            t = i / RATE
            raw = random.uniform(-1, 1)
            low += (raw - low) * brightness
            envelope = min(1.0, t / 0.001) * math.exp(-9.0 * t / length)
            self.samples[n] += volume * envelope * (raw - low)

    def reverb(self, mix: float = 0.22) -> None:
        """短い部屋の響き（数本の反射を足すだけの簡易版）。"""
        taps = [(0.023, 0.6), (0.037, 0.45), (0.053, 0.32), (0.079, 0.2), (0.113, 0.12)]
        dry = self.samples[:]
        for delay, gain in taps:
            offset = int(delay * RATE)
            for n in range(offset, len(dry)):
                self.samples[n] += dry[n - offset] * gain * mix

    def save(self, path: Path, peak: float = 0.55) -> None:
        loudest = max(abs(s) for s in self.samples) or 1.0
        scale = peak / loudest
        # 最後の 10ms はフェードアウトして、プツッという音を防ぐ
        fade = int(0.01 * RATE)
        frames = bytearray()
        for n, sample in enumerate(self.samples):
            if n > len(self.samples) - fade:
                sample *= (len(self.samples) - n) / fade
            value = int(max(-1.0, min(1.0, sample * scale)) * 32767)
            frames += struct.pack("<hh", value, value)
        with wave.open(str(path), "wb") as file:
            file.setnchannels(2)
            file.setsampwidth(2)
            file.setframerate(RATE)
            file.writeframes(bytes(frames))


def make() -> dict[str, Track]:
    sounds: dict[str, Track] = {}

    t = Track(0.08)
    t.tone(0, 2000, 0.03, 0.4, attack=0.001, partials=SOFT)
    t.noise(0, 0.006, 0.15, brightness=0.9)
    sounds["myos-tap"] = sounds["button-pressed"] = t

    t = Track(0.12)
    t.tone(0, 1400, 0.035, 0.4, attack=0.001, partials=SOFT)
    t.tone(0.04, 2100, 0.05, 0.4, attack=0.001, partials=SOFT)
    sounds["button-toggle-on"] = t

    t = Track(0.12)
    t.tone(0, 2100, 0.035, 0.4, attack=0.001, partials=SOFT)
    t.tone(0.04, 1400, 0.05, 0.4, attack=0.001, partials=SOFT)
    sounds["button-toggle-off"] = t

    t = Track(0.35)
    t.tone(0, 520, 0.28, 0.5, attack=0.012, glide_to=880)
    t.reverb()
    sounds["myos-open"] = t

    t = Track(0.35)
    t.tone(0, 880, 0.26, 0.45, attack=0.01, glide_to=520)
    t.reverb()
    sounds["myos-close"] = t

    t = Track(1.2)
    for i, freq in enumerate((783.99, 1046.5, 1318.51)):
        t.tone(i * 0.07, freq, 0.9, 0.42)
    t.reverb(0.3)
    sounds["message-new-instant"] = sounds["message"] = sounds["window-attention"] = t

    t = Track(0.8)
    t.tone(0, 1046.5, 0.5, 0.45)
    t.tone(0.09, 1567.98, 0.6, 0.45)
    t.reverb()
    sounds["complete"] = t

    t = Track(0.5)
    t.tone(0, 880, 0.35, 0.4)
    t.tone(0, 1318.51, 0.35, 0.3)
    t.reverb()
    sounds["bell"] = sounds["dialog-information"] = t

    t = Track(0.7)
    t.tone(0, 659.25, 0.3, 0.45)
    t.tone(0.14, 523.25, 0.45, 0.45)
    t.reverb()
    sounds["dialog-warning"] = sounds["dialog-error"] = t

    t = Track(0.06)
    t.tone(0, 1800, 0.035, 0.45, attack=0.001, partials=SOFT)
    sounds["audio-volume-change"] = t

    t = Track(0.2)
    t.noise(0, 0.03, 0.5, brightness=0.6)
    t.noise(0.07, 0.05, 0.35, brightness=0.4)
    sounds["screen-capture"] = sounds["camera-shutter"] = t

    t = Track(2.2)
    for i, freq in enumerate((523.25, 659.25, 783.99, 987.77, 1174.66)):
        t.tone(i * 0.06, freq, 1.9, 0.22, attack=0.35, partials=SOFT)
        t.tone(i * 0.06, freq * 1.003, 1.9, 0.12, attack=0.4, partials=SOFT)
    t.reverb(0.35)
    sounds["desktop-login"] = t

    t = Track(0.3)
    t.tone(0, 880, 0.12, 0.4)
    t.tone(0.08, 1318.51, 0.18, 0.4)
    sounds["device-added"] = t

    t = Track(0.3)
    t.tone(0, 1318.51, 0.12, 0.4)
    t.tone(0.08, 880, 0.18, 0.4)
    sounds["device-removed"] = t

    t = Track(0.9)
    for i, freq in enumerate((1318.51, 1661.22, 1975.53, 2637.02)):
        t.tone(i * 0.045, freq, 0.5, 0.32)
    t.tone(0.18, 3951.07, 0.6, 0.08, attack=0.05, partials=SOFT)
    t.reverb(0.35)
    sounds["myos-assistant"] = t

    return sounds


def main() -> None:
    random.seed(7)  # 毎回同じ音になるように
    OUT.mkdir(parents=True, exist_ok=True)
    sounds = make()
    for name, track in sounds.items():
        track.save(OUT / f"{name}.wav")
    (OUT.parent / "index.theme").write_text(
        "[Sound Theme]\nName=Prism\nComment=Prism system sounds\nInherits=freedesktop\n"
        "Directories=stereo\n\n[stereo]\nOutputProfile=stereo\n",
        encoding="utf-8",
    )
    print(f"wrote {len(sounds)} sounds to {OUT}")


if __name__ == "__main__":
    main()
