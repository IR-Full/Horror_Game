"""Original deterministic seamless wind/rain bed; Python stdlib, no downloads."""
import math, random, struct, wave
from pathlib import Path
rate=22050
count=rate*12
rng=random.Random(731)
low=0.0
samples=[]
for i in range(count):
    t=i/rate
    noise=rng.uniform(-1,1)
    low=low*.975+noise*.025
    gust=.55+.25*math.sin(math.tau*t/12)+.15*math.sin(math.tau*t/4)
    samples.append(low*gust*1.8+noise*.024)
# Equal-power crossfade of a complete periodic copy avoids an audible seam.
overlap=rate
for i in range(overlap):
    a=i/(overlap-1)
    samples[i]=samples[-overlap+i]*(1-a)+samples[i]*a
samples=samples[:-overlap]
path=Path(__file__).resolve().parents[1]/'assets/audio/clips/forest_wind.wav'
with wave.open(str(path),'wb') as stream:
    stream.setnchannels(1);stream.setsampwidth(2);stream.setframerate(rate)
    stream.writeframes(b''.join(struct.pack('<h',max(-32767,min(32767,round(x*32767)))) for x in samples))
print('FOREST_AUDIO_PASS',path.stat().st_size)
