#!/usr/bin/env python3
"""Generates the board's three alarm tones.

The sounds are committed as assets, but they are *generated* rather than
sourced so that "why does it sound like that?" has an answer in the repo. All three
are 44.1 kHz 16-bit mono WAV — the one format every Android and iOS decoder
plays without a codec negotiation, on a tablet that may be offline forever.

    python3 tool/make_alarm_sounds.py

**waiting** is the kitchen siren from ECOSYSTEM §22.1: 880 Hz and 1320 Hz
alternating, a perfect fifth apart. A fifth is used rather than a single tone
because a steady tone disappears into an extractor fan, while an alternating
pair keeps re-attacking the ear. Odd harmonics are mixed in for the same
reason a real alarm is not a sine: a pure tone at kitchen volume is felt as
quieter than a reedy one at the same amplitude.

**counter** is the *À encaisser* register (ECOSYSTEM §22.1, v1.25). It is
three short rising blips — C6/E6/G6, a major triad — repeated three times.
**The rhythm carries it, not the pitch**: in a kitchen the ear separates a
fast triplet from a slow two-tone alternation far more reliably than it
separates two frequencies, and a cook hears this one from the pass without
looking up. Loud, because somebody is standing at the counter with cash in
their hand, but shorter than the siren so it does not outstay the message.

**notice** sounds once, so it is deliberately the opposite: two soft tones
falling rather than alternating, at a third of the level. A scheduled ticket
reaching its fire time is information, and information that shouts trains a
kitchen to ignore the register that is a summons.
"""

import math
import struct
import wave

RATE = 44100


def tone(freq, ms, level, harmonics=(1.0, 0.35, 0.12)):
    """One tone with 6 ms raised-cosine edges.

    The fades are not cosmetic: a waveform that starts at full amplitude puts a
    step into the DAC, and that step is an audible click in front of every
    single beep — on a sound the kitchen hears a hundred times a shift.
    """
    n = int(RATE * ms / 1000)
    edge = max(1, int(RATE * 0.006))
    out = []
    for i in range(n):
        t = i / RATE
        sample = sum(
            weight * math.sin(2 * math.pi * freq * (k + 1) * t)
            for k, weight in enumerate(harmonics)
        ) / sum(harmonics)
        if i < edge:
            sample *= 0.5 - 0.5 * math.cos(math.pi * i / edge)
        elif i > n - edge:
            sample *= 0.5 - 0.5 * math.cos(math.pi * (n - i) / edge)
        out.append(sample * level)
    return out


def silence(ms):
    return [0.0] * int(RATE * ms / 1000)


def write(path, samples):
    with wave.open(path, "wb") as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(RATE)
        handle.writeframes(
            b"".join(
                struct.pack("<h", max(-32767, min(32767, int(s * 32767))))
                for s in samples
            )
        )


def main():
    waiting = []
    for _ in range(4):
        waiting += tone(880, 190, 0.92)
        waiting += silence(35)
        waiting += tone(1320, 190, 0.92)
        waiting += silence(35)
    write("assets/audio/kds_waiting.wav", waiting)

    counter = []
    for _ in range(3):
        counter += tone(1046, 85, 0.88)
        counter += silence(45)
        counter += tone(1318, 85, 0.88)
        counter += silence(45)
        counter += tone(1568, 150, 0.88)
        counter += silence(230)
    write("assets/audio/kds_counter.wav", counter)

    notice = tone(1320, 130, 0.32) + silence(50) + tone(880, 260, 0.32)
    write("assets/audio/kds_notice.wav", notice)


if __name__ == "__main__":
    main()
