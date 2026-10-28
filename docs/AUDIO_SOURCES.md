# Источники записей звука

Все 24 исходных файла опубликованы на OpenGameArt по CC0 1.0: https://creativecommons.org/publicdomain/zero/1.0/. Для HaelDB выбрана явно указанная на исходной странице альтернатива CC0. Скачаны 28 октября 2026; названия участников архивов и SHA-256 указаны в assets/audio/sources.json. Исходные байты сохранены в assets/audio/sources/ и исключены из импорта Godot через .gdignore.

- [Brian MacIntosh (BMacZero)](https://opengameart.org/content/mechanical-sounds)
- [Darsycho](https://opengameart.org/content/monster-snarls)
- [EZduzziteh](https://opengameart.org/content/alarm-1)
- [HaelDB](https://opengameart.org/content/male-gruntyelling-sounds)
- [SpringySpringo](https://opengameart.org/content/gun-reload-sounds)
- [Tabasco](https://opengameart.org/content/gunshot-sounds)
- [TinyWorlds](https://opengameart.org/content/different-steps-on-wood-stone-leaves-gravel-and-mud)
- [YCbCr](https://opengameart.org/content/generator-loop)
- [qubodup](https://opengameart.org/content/electronic-device-loop)
- [rubberduck](https://opengameart.org/content/80-cc0-creature-sfx)

51 игровой клип в assets/audio/clips/: боль и удары, рычание, крики, шаги по камню/металлу/гравию, двери, переключатели, тревога, дробовик и перезарядка, генератор и фон электроники. Крики сущности обработаны по высоте и местами сведены слоями; голос боли сохраняет естественный регистр. Это обработанные записи, а не голосовой синтез. SOS, радиосигналы, музыка и сердцебиение остаются авторским синтезом.

Обработка в tools/build_audio.py: моно 32 кГц, обрезка тишины, удаление DC и низкого гула, короткие плавные края, ограничение пиков примерно -1.5 dBFS, сглаживание швов петель. bank.json связывает события с вариантами; раздел clips в bank.json содержит происхождение готовых клипов. Загрузки в игре нет.

## Повторная сборка разработчиком

Игроку ничего устанавливать не нужно. Разработчику нужны Python, numpy и soundfile:

```sh
python -m pip install numpy soundfile
python tools/build_audio.py
```

Затем выполните импорт в Godot. Оригиналы не изменяются. Audacity можно использовать для прослушивания и ручной обработки WAV/OGG. Если хочется заменить звук, положите новый WAV/OGG в отдельную папку assets/audio/custom/, импортируйте и измените соответствующий путь bank.json. Сохраняйте лицензию и автора нового файла. Установка сторонних кодеков для воспроизведения готового OGG не требуется.
