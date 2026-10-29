"""Bake CC0 human breathing loops without touching existing game audio."""
from pathlib import Path
import hashlib
import json
import numpy as np
import soundfile as sf
ROOT=Path(__file__).resolve().parents[1]
BASE=ROOT/'assets/audio'
bank=json.loads((BASE/'bank.json').read_text(encoding='utf-8'))
sources=json.loads((BASE/'sources.json').read_text(encoding='utf-8'))
for name,source,number,start,end in [('player_breath_calm','sardin_breath_calm.wav','2195',8,20),('player_breath_heavy','sardin_breath_heavy.wav','1103',3,15)]:
    raw=BASE/'sources'/source
    x,rate=sf.read(raw,always_2d=True);x=x.mean(axis=1)[int(start*rate):int(end*rate)]
    x=np.interp(np.arange(round(len(x)*32000/rate))*rate/32000,np.arange(len(x)),x)
    x-=x.mean();x*=min(.75/max(abs(x).max(),.0001),.16/max(np.sqrt(np.mean(x*x)),.0001))
    count=int(.15*32000);mix=np.linspace(0,1,count)
    seam=x[-count:]*(1-mix)+x[:count]*mix;x=np.concatenate([seam,x[count:-count]])
    path=BASE/'clips'/f'{name}_01.ogg';sf.write(path,x,32000,format='OGG',subtype='VORBIS')
    bank['sounds'][name]=['res://assets/audio/clips/'+path.name]
    if name not in bank['loops']:bank['loops'].append(name)
    bank['clips']=[entry for entry in bank['clips'] if entry['file']!=path.name]
    bank['clips'].append({'file':path.name,'sources':[source],'processing':'Recorded human breathing; mono 32kHz, gentle RMS match and 150ms loop seam','duration':len(x)/32000,'peak_dbfs':round(float(20*np.log10(max(abs(x).max(),1e-8))),2),'rms_dbfs':round(float(20*np.log10(max(np.sqrt(np.mean(x*x)),1e-8))),2),'sha256':hashlib.sha256(path.read_bytes()).hexdigest()})
    sources=[entry for entry in sources if entry['file']!=source]
    sources.append({'file':source,'author':'Joseph SARDIN','source':f'https://bigsoundbank.com/{"breathless-man" if number=="1103" else "man-breathing"}-s{number}.html','download_url':f'https://bigsoundbank.com/UPLOAD/bwf-en/{number}.wav','license':'CC0-1.0','sha256':hashlib.sha256(raw.read_bytes()).hexdigest()})
    print('CONDITION_AUDIO',path.name,len(x)/32000)
(BASE/'bank.json').write_text(json.dumps(bank,indent=2)+'\n',encoding='utf-8')
(BASE/'sources.json').write_text(json.dumps(sources,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
