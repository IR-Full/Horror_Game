"""Build the shipped sound bank from CC0 recordings and locally generated Russian speech.

Requires numpy and soundfile for development only. No network calls. Sources and
their provenance are kept under assets/audio/sources (excluded from Godot import).
"""
from pathlib import Path
import sys, json, hashlib
ROOT = Path(__file__).resolve().parents[1]
import numpy as np
import soundfile as sf

SOURCE = ROOT/'assets'/'audio'/'sources'
OUTPUT = ROOT/'assets'/'audio'/'clips'
OUTPUT.mkdir(parents=True, exist_ok=True)
RATE = 32000
voice_only = '--voices-only' in sys.argv
bank, metadata = {}, []
if voice_only:
    previous_bank = json.loads((OUTPUT.parent/'bank.json').read_text(encoding='utf-8'))
    bank = {kind: paths for kind, paths in previous_bank['sounds'].items() if kind != 'monster_voice'}
    metadata = [entry for entry in previous_bank['clips'] if not entry['file'].startswith('monster_voice_')]

def read(name, trim=True):
    x, rate = sf.read(SOURCE/name, always_2d=True)
    x = x.mean(axis=1)
    if rate != RATE:
        x = np.interp(np.arange(int(len(x)*RATE/rate))*rate/RATE, np.arange(len(x)), x)
    if trim:
        active = np.flatnonzero(np.abs(x) > max(.008, np.max(np.abs(x))*.025))
        if len(active): x = x[max(0,active[0]-800):min(len(x),active[-1]+3200)]
    return x

def pitch(x, factor):
    return np.interp(np.arange(0,len(x)-1,factor),np.arange(len(x)),x)

def layer(a,b,amount=.3):
    result = np.zeros(max(len(a),len(b)))
    result[:len(a)] += a
    result[:len(b)] += b*amount
    return result

def emit(kind, x, sources, label):
    if voice_only and kind != 'monster_voice': return
    x = x.astype(float)-np.mean(x)
    spectrum = np.fft.rfft(x)
    hz = np.fft.rfftfreq(len(x),1/RATE)
    spectrum *= hz/np.sqrt(hz*hz+55*55)
    x = np.fft.irfft(spectrum,n=len(x))
    fade=min(180,len(x)//8)
    x[:fade]*=np.linspace(0,1,fade)
    x[-fade:]*=np.linspace(1,0,fade)
    peak=max(float(np.max(np.abs(x))),.0001)
    x *= min(.84/peak,6.0)
    number=len(bank.get(kind,[]))+1
    filename=f'{kind}_{number:02}.ogg'
    sf.write(OUTPUT/filename,x,RATE,format='OGG',subtype='VORBIS')
    bank.setdefault(kind,[]).append('res://assets/audio/clips/'+filename)
    metadata.append({'file':filename,'sources':sources,'processing':label,'seconds':round(len(x)/RATE,3),'peak_dbfs':round(20*np.log10(max(np.max(np.abs(x)),1e-8)),2),'sha256':hashlib.sha256((OUTPUT/filename).read_bytes()).hexdigest()})

for file in sorted(SOURCE.glob('emopreben_pain_*.ogg')):
    x=read(file.name)
    emit('pain',x,[file.name],'New CC0 human pain performance; original pitch, trim and EQ')
    emit('hurt',x,[file.name],'Human injury grunt; original pitch')

snarls=read('darsycho_snarls.ogg',False)
frame=int(.02*RATE)
energy=np.array([np.sqrt(np.mean(snarls[i:i+frame]**2)) for i in range(0,len(snarls),frame)])
active=np.flatnonzero(energy>max(.018,energy.max()*.12))
segments=[]
if len(active):
    start=last=int(active[0])
    for current in active[1:]:
        if current-last>9:
            segments.append((max(0,start*frame-800),min(len(snarls),(last+1)*frame+3000)))
            start=int(current)
        last=int(current)
    segments.append((max(0,start*frame-800),min(len(snarls),(last+1)*frame+3000)))
for start,end in segments[:4]:
    x=snarls[start:end]
    if len(x)<RATE*.2:continue
    x=pitch(x,.9)
    emit('growl',x,['darsycho_snarls.ogg'],'Isolated snarl, pitch 0.90, EQ and level matching')
for file in ['rubber_roar_02.ogg','rubber_scream_01.ogg','rubber_scream_02.ogg']:
    x=read(file)
    x=layer(pitch(x,.78),pitch(x,.61),.18)
    emit('roar',x,[file],'Human creature vocal, layered pitched takes 0.78 and 0.61')
emit('breath',read('rubber_breath.ogg'),['rubber_breath.ogg'],'Trim and EQ')
emit('whisper',pitch(read('rubber_breath.ogg'),.92),['rubber_breath.ogg'],'Close breath, original recorded vocal texture')
emit('scrape',pitch(read('bmac_mechanical2.wav'),.82),['bmac_mechanical2.wav'],'Recorded mechanical scrape')
emit('pickup',read('bmac_squeakyclick1.wav'),['bmac_squeakyclick1.wav'],'Small recorded handling click')
emit('power',layer(read('bmac_mechanical1.wav'),read('bmac_mechanical2.wav'),.4),['bmac_mechanical1.wav','bmac_mechanical2.wav'],'Recorded switch-on clunk')
for file in ['bmac_clank1.wav','bmac_mechanical1.wav']:
    x=read(file)
    emit('smash',layer(pitch(x,.82),pitch(x,.6),.3),[file],'Metallic impact with low recording layer')
    emit('knock',pitch(x,.92),[file],'Metal impact variation')
for file in ['bmac_lightclunk1.wav','bmac_lightclunk2.wav','bmac_squeakyclick1.wav']:
    emit('switch',read(file),[file],'Recorded switch or clunk, EQ and normalize')
for file in ['bmac_mechanical1.wav','bmac_mechanical2.wav']:
    emit('door',read(file),[file],'Mechanical door clank, mono and level matching')
# Isolate actual shoe contacts from Joseph Sardin's concrete recording.
steps=read('sardin_concrete.wav',False)
window=160
energy=np.array([np.sqrt(np.mean(steps[i:i+window]**2)) for i in range(0,len(steps),window)])
peaks=[]
for index in np.argsort(energy)[::-1]:
    if energy[index] < energy.max()*.16:break
    if all(abs(index-p)>int(.28*RATE/window) for p in peaks):peaks.append(int(index))
selected=sorted(peaks)[:10]
for take,index in enumerate(selected):
    center=index*window
    x=steps[max(0,center-int(.035*RATE)):min(len(steps),center+int(.26*RATE))]
    emit('step',x,['sardin_concrete.wav'],'Isolated recorded shoe contact, natural transient and scuff')
    emit('step_metal',layer(x,read('bmac_lightclunk1.wav')*.15),['sardin_concrete.wav','bmac_lightclunk1.wav'],'Recorded shoe contact with quiet structural metal resonance')
    if take<4:
        emit('entity_step',pitch(x,.75),['sardin_concrete.wav'],'Heavy recorded contact')
        emit('step_gravel',layer(x,read('tiny_gravel.ogg')*.55),['sardin_concrete.wav','tiny_gravel.ogg'],'Natural shoe plus recorded gravel')
        emit('crawl_impact',layer(pitch(x,.78),read('bmac_lightclunk2.wav')*.2),['sardin_concrete.wav','bmac_lightclunk2.wav'],'Heavy recorded hand impact')
# Male neural speech with restrained processing; no ring modulation or octave doubling.
for file in sorted(SOURCE.glob('monster_neural_*.wav')):
    x=pitch(read(file.name),.94)
    x=np.tanh(x*1.15)
    delayed=np.zeros(len(x)+int(.075*RATE));delayed[:len(x)]+=x
    delayed[int(.075*RATE):]+=x*.035
    emit('monster_voice',delayed,[file.name],'Piper Dmitri male neural speech, gentle saturation, -1 semitone and quiet room reflection')
emit('alarm',read('ez_alarm.ogg'),['ez_alarm.ogg'],'Mono, level matching; runtime loops a separate stream')
if (SOURCE/'shotguncock.wav').exists(): emit('reload',read('shotguncock.wav'),['shotguncock.wav'],'Recorded shotgun mechanism')
for file in sorted(SOURCE.glob('tabasco_*'))[:3]: emit('shotgun',read(file.name),[file.name],'Actual firearm recording, trim and normalize')
for kind,file in [('motor','loop_generator_1.mp3'),('hum','qubodup-edev.flac')]:
    if not (SOURCE/file).exists():continue
    x=read(file,False)
    overlap=min(int(.25*RATE),len(x)//5)
    seam=x[-overlap:]*(1-np.linspace(0,1,overlap))+x[:overlap]*np.linspace(0,1,overlap)
    x=np.concatenate([seam,x[overlap:-overlap]])
    emit(kind,x,[file],'Loop seam crossfade 250 ms, EQ, mono')
(OUTPUT.parent/'bank.json').write_text(json.dumps({'sounds':bank,'loops':['motor','hum'],'clips':metadata},indent=2),encoding='utf-8')
print('AUDIO_BUILD',len(metadata),'clips;',len(bank),'events;',sum(p.stat().st_size for p in OUTPUT.glob('*.ogg')),'bytes')
