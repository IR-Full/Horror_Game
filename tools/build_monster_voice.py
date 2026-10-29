"""Bake Russian neural speech locally; only WAV sources and portable OGG ship.

Developer dependency: piper-tts. Download ru_RU-dmitri-medium.onnx and its JSON
from rhasspy/piper-voices into tools/voice-models (ignored). Dataset: CC0;
model repository: MIT. Piper's GPL runtime is a build tool, never game code.
"""
from pathlib import Path
import hashlib
import json
import wave
import shutil
import tempfile

from piper import PiperVoice, SynthesisConfig
from piper.phonemize_espeak import ESPEAK_DATA_DIR

ROOT = Path(__file__).resolve().parents[1]
MODEL = ROOT / 'tools/voice-models/ru_RU-dmitri-medium.onnx'
SOURCE = ROOT / 'assets/audio/sources'
MODEL_PAGE = 'https://huggingface.co/rhasspy/piper-voices/blob/main/ru/ru_RU/dmitri/medium/MODEL_CARD'
LINES = [
    'Вы где? Я слышу, как вы дышите.',
    'Я вас найду. Каждого.',
    'Выходите. Я всего лишь хочу поиграть.',
    'Тише. Не нужно кричать.',
    'Дверь вам не поможет.',
    'Я знаю, что ты здесь.',
    'Не беги. Ты только устанешь.',
    'Кто там шепчется? Поговори со мной.',
    'Погаси фонарь. Посмотри на меня.',
    'Я помню твои шаги.',
    'Здесь никто вас не услышит.',
    'Ты оставил друга одного?',
    'Ещё один звук. И я приду.',
    'Открой. Я уже рядом.',
    'Мы ещё не закончили играть.',
    'Я подожду. У меня много времени.',
    'Не трогайте рубильник. Мне нравится темнота.',
    'Слышишь? Это я иду за тобой.',
]


def main(espeak_data_dir):
    voice = PiperVoice.load(str(MODEL), espeak_data_dir=str(espeak_data_dir))
    manifest_path = SOURCE.parent / 'sources.json'
    manifest = json.loads(manifest_path.read_text(encoding='utf-8'))
    manifest = [entry for entry in manifest if not entry['file'].startswith('monster_neural_')]
    for i, text in enumerate(LINES):
        path = SOURCE / f'monster_neural_{i:02d}.wav'
        # Preserve the male voice's formants: no sub-octave doubling or robotic flutter.
        config = SynthesisConfig(length_scale=[1.10, 1.04, 1.16][i % 3],
                                 noise_scale=.68, noise_w_scale=.82, normalize_audio=True)
        with wave.open(str(path), 'wb') as output:
            voice.synthesize_wav(text, output, syn_config=config)
        manifest.append({'file': path.name, 'author': 'Project text; Piper Dmitri neural voice',
                         'source': MODEL_PAGE, 'text': text,
                         'license': 'Neural speech output; voice dataset CC0; model repository MIT',
                         'model_sha256': hashlib.sha256(MODEL.read_bytes()).hexdigest(),
                         'sha256': hashlib.sha256(path.read_bytes()).hexdigest()})
        print(f'VOICE_BAKE {i+1}/{len(LINES)} {path.name}', flush=True)
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')


if __name__ == '__main__':
    # espeak's Windows C file API cannot open Cyrillic install paths. Stage only
    # its dictionary in an ASCII temporary path; ONNX and outputs keep real paths.
    with tempfile.TemporaryDirectory(prefix='lastsignal-voice-') as temporary:
        data_dir = Path(temporary) / 'espeak-ng-data'
        shutil.copytree(ESPEAK_DATA_DIR, data_dir)
        main(data_dir)
