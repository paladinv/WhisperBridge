#!/usr/bin/env python3
"""Create deterministic non-speech inputs within the workspace. No speech QA implied."""
import hashlib
import json
import random
import struct
import wave
from pathlib import Path

root = Path(__file__).resolve().parents[1]
out = root / '.build-artifacts/fixtures'
out.mkdir(parents=True, exist_ok=True)
rng = random.Random(42)
for name, noise in [('F07-silence.wav', False), ('F08-noise.wav', True)]:
    with wave.open(str(out / name), 'wb') as f:
        f.setparams((1, 2, 16000, 0, 'NONE', 'not compressed'))
        f.writeframes(b''.join(struct.pack('<h', rng.randint(-2000, 2000) if noise else 0) for _ in range(160000)))
(out / 'F11-not-audio.mp3').write_bytes(b'This is deliberately not audio.\n')
(out / 'F12-malformed.wav').write_bytes(b'RIFF\xff\xff\xff\xffWAVEfmt ')
manifest = {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in out.iterdir() if p.suffix in ('.wav', '.mp3')}
(out / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
print(f'Created {len(manifest)} negative fixtures in {out}')
