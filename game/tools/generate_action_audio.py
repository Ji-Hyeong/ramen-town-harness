"""Reproduce original short UI cues, without network or third-party recordings.

PCM synthesis is deterministic; generation only writes the explicitly named
project audio assets. Melody, envelopes and seeded noise are authored here.
"""

from pathlib import Path
import math
import random
import struct
import wave

RATE = 22050
CUES = {
    "tap": [(880, .045)],
    "ingredient": [(523, .065), (784, .08)],
    "broth": [(196, .11), (247, .12)],
    "noodle": [(330, .08), (440, .09), (660, .09)],
    "plate": [(660, .10), (880, .12)],
    "complete": [(523, .09), (659, .09), (784, .16)],
    "discover": [(523, .08), (659, .08), (784, .08), (1047, .24)],
    "refuse": [(247, .08), (196, .11)],
}


def generate(destination: Path) -> None:
    """Keep low amplitudes, smooth edges and bounded durations to avoid clicks."""
    destination.mkdir(parents=True, exist_ok=True)
    for name, notes in CUES.items():
        samples = []
        noise = random.Random(47)
        for frequency, duration in notes:
            count = round(RATE * duration)
            for index in range(count):
                t = index / RATE
                envelope = min(1, t / .008) * min(1, (duration - t) / .025)
                tone = math.sin(2 * math.pi * frequency * t)
                tone += .20 * math.sin(4 * math.pi * frequency * t)
                if name == "broth":
                    tone = .6 * tone + .25 * noise.uniform(-1, 1)
                samples.append(round(32767 * .16 * envelope * tone))
        with wave.open(str(destination / f"{name}.wav"), "wb") as stream:
            stream.setparams((1, 2, RATE, 0, "NONE", "not compressed"))
            stream.writeframes(struct.pack(f"<{len(samples)}h", *samples))


if __name__ == "__main__":
    generate(Path(__file__).resolve().parents[1] / "assets" / "audio")
