"""Bake actual CC0 voice acting at original pitch; preserve every other game event."""
from pathlib import Path
from zipfile import ZipFile
import hashlib
import json
import re
import numpy as np
import soundfile as sf
ROOT=Path(__file__).resolve().parents[1]
BASE=ROOT/'assets/audio'; SOURCE=BASE/'sources'; RATE=32000
PAGE='https://opengameart.org/content/demon-voice'
URL='https://opengameart.org/sites/default/files/all_demon_lord_audio_files_0.zip'
LINES=[
 ('DL NOWHERE TO RUN.wav','Тебе некуда бежать.'),
 ('DL SEARCH EVERYWHERE.wav','Обыщите всё.'),
 ('DL TIME IS UP.wav','Твоё время вышло.'),
 ('DL WEAPONS ARE USELESS.wav','Твоё оружие бесполезно.'),
 ('DL NOT WELCOME.wav','Тебе здесь не рады.'),
 ('DL NOTHING TO FEAR.wav','Здесь нечего бояться.'),
 ('DL VISITOR.wav','У нас гость.'),
 ('DL SILENCE.wav','Тихо!'),
 ('DL WRONG PLACE WRONG TIME.wav','Ты оказался не в том месте и не в то время.'),
 ('DL STAY AND CONVERSE.wav','Останься и поговори со мной.'),
 ('DL STAY FOR DINNER.wav','Останься на ужин.'),
 ('DL DINNERTIME.wav','Пора ужинать.'),
 ('DL BE AFRAID.wav','Бойся. Очень бойся.'),
 ('DL WELCOME.wav','Добро пожаловать.'),
 ('DL MERCY.wav','Пощада — для слабых.'),
 ("DL WAIT HE'S MINE.wav",'Подождите. Он мой.'),
 ('DL DEMON SNIGGER 1.wav','[Хриплый смешок]'),
 ('DL DEMON LAUGHS.wav','[Зловещий смех]')]
bank=json.loads((BASE/'bank.json').read_text(encoding='utf-8'))
sources=json.loads((BASE/'sources.json').read_text(encoding='utf-8'))
archive=ROOT/'test-results/v12-downloads/tim_demon.zip'
def source_file(member):
    name='timrockk_'+re.sub(r'[^a-z0-9]+','_',Path(member).stem.lower())+'.wav'
    path=SOURCE/name
    if not path.exists():
        if not archive.exists():raise RuntimeError('Download '+URL+' to '+str(archive))
        with ZipFile(archive) as package:path.write_bytes(package.read(member))
    entry={'file':name,'author':'Tim Rockk','source':PAGE,'download_url':URL,'member':member,'license':'CC0-1.0','performance':'Human voice acting; source has author-applied effects','sha256':hashlib.sha256(path.read_bytes()).hexdigest()}
    sources[:]=[old for old in sources if old['file']!=name];sources.append(entry)
    return path
def clear_event(kind):
    old_names={Path(path).name for path in bank['sounds'].get(kind,[])}
    bank['sounds'][kind]=[]
    bank['clips']=[clip for clip in bank['clips'] if clip['file'] not in old_names]
def emit(kind,member):
    path=source_file(member);x,rate=sf.read(path,always_2d=True);x=x.mean(axis=1)
    if rate!=RATE:x=np.interp(np.arange(round(len(x)*RATE/rate))*rate/RATE,np.arange(len(x)),x)
    x-=x.mean()
    spectrum=np.fft.rfft(x);hz=np.fft.rfftfreq(len(x),1/RATE)
    spectrum*=hz/np.sqrt(hz*hz+45**2);x=np.fft.irfft(spectrum,n=len(x))
    active=np.flatnonzero(np.abs(x)>max(.004,np.max(np.abs(x))*.012))
    if len(active):x=x[max(0,active[0]-2400):min(len(x),active[-1]+6000)]
    x*=min(.84/max(np.max(np.abs(x)),1e-6),.14/max(np.sqrt(np.mean(x*x)),1e-6))
    fade=min(180,len(x)//8);x[:fade]*=np.linspace(0,1,fade);x[-fade:]*=np.linspace(1,0,fade)
    name=f'{kind}_{len(bank["sounds"][kind])+1:02}.ogg'
    target=BASE/'clips'/name;sf.write(target,x,RATE,format='OGG',subtype='VORBIS')
    bank['sounds'][kind].append('res://assets/audio/clips/'+name)
    bank['clips'].append({'file':name,'sources':[path.name],'processing':'Recorded Tim Rockk voice, original source pitch; mono 32kHz, mild 45Hz high-pass, RMS/peak matching; no TTS, pitch shift, double voice or ring modulation','seconds':round(len(x)/RATE,3),'peak_dbfs':round(float(20*np.log10(max(np.max(np.abs(x)),1e-9))),2),'sha256':hashlib.sha256(target.read_bytes()).hexdigest()})
for kind in ['monster_voice','roar','growl','monster_hurt','whisper']:clear_event(kind)
for member,_ in LINES:emit('monster_voice',member)
for member in ['DL DEMON SNARL 1.wav','DL DEMON SNARL 2.wav','DL DEMON SNARL 3.wav','DL DEMON MOOHAAA LAUGH.wav']:emit('roar',member)
for member in ['DL DEMON GROWL 1.wav','DL DEMON GROWL 2.wav','DL DEMON GROWL 3.wav','DL DEMON GROWL 4.wav']:emit('growl',member)
for member in ['DL DEMON FIGHT GRUNT 1.wav','DL DEMON FIGHT GRUNT 2.wav','DL DEMON DIES.wav']:emit('monster_hurt',member)
for member in ['DL NOTHING TO FEAR.wav','DL SILENCE.wav','DL VISITOR.wav']:emit('whisper',member)
bank['speech']={'actor':'Tim Rockk','language':'en','synthesized':False,'source':PAGE,'captions_ru':[line[1] for line in LINES]}
(BASE/'bank.json').write_text(json.dumps(bank,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
(BASE/'sources.json').write_text(json.dumps(sources,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print('ACTOR_VOICE_BUILD',len(bank['clips']),'clips;',len(bank['sounds']),'events;',len(LINES),'captions')
