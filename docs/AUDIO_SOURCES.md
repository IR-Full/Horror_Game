# Аудио 0.7

Новый банк: **73 OGG, 24 события**. Добавлены [боль EmoPreben](https://opengameart.org/content/pain-sounds-by-emopreben) и [обувь по бетону Joseph SARDIN](https://bigsoundbank.com/footsteps-shoe-on-concrete-s0514.html), обе публикации CC0. Фрагменты шагов выделены из настоящей записи, сохранены естественные атака и шорох. Боль сохраняет высоту голоса исполнителя. Звуки Bodycam не копировались.

Три реплики сущности созданы локально голосом Microsoft Irina Desktop / Windows SAPI: «Вы где?», «Я вас найду и убью», «Выходите. Я же всего лишь хочу поиграть с вами». Для эффекта используются пониженная высота, тихий второй слой, насыщение, дыхательная шероховатость, дрожание и короткое эхо. Это синтезированные реплики; они отдельно помечены в sources.json и не приписаны авторам CC0. В готовой игре синтез и интернет не используются: на Windows/Linux/macOS воспроизводятся одни OGG.

Сохранены 34 источника: 31 запись CC0, включая прежний архив, и 3 исходных WAV синтеза. Все SHA-256 и происхождение — в assets/audio/sources.json. Исходники исключены из Godot-импорта и экспорта. bank.json описывает фактически используемые клипы и обработку.

Обработка и сборка — tools/build_audio.py. Для разработки нужны Python, numpy и soundfile; игрокам они не нужны. Для собственного окружения разработчика:

```sh
python -m pip install numpy soundfile
python tools/build_audio.py
```

Рёв и рычание громче предыдущей версии, дальность громких угроз до 80 м, голос слегка глушится за стенами. Отдельная громкость эффектов доступна в настройках. Нормализация файлов сохраняет запас по пику, общий микс регулируется аудиошинами.

## Прежние источники записей

Прежние 24 исходных файла опубликованы на OpenGameArt по CC0 1.0: https://creativecommons.org/publicdomain/zero/1.0/. Для HaelDB выбрана явно указанная на исходной странице альтернатива CC0. Скачаны 28 октября 2026; названия участников архивов и SHA-256 указаны в assets/audio/sources.json. Исходные байты сохранены в assets/audio/sources/ и исключены из импорта Godot через .gdignore.

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

Банк прежней версии содержал 51 игровой клип в assets/audio/clips/: боль и удары, рычание, крики, шаги по камню/металлу/гравию, двери, переключатели, тревога, дробовик и перезарядка, генератор и фон электроники. Крики сущности обработаны по высоте и местами сведены слоями; голос боли сохраняет естественный регистр. Это обработанные записи, а не голосовой синтез. SOS, радиосигналы, музыка и сердцебиение остаются авторским синтезом.

Обработка в tools/build_audio.py: моно 32 кГц, обрезка тишины, удаление DC и низкого гула, короткие плавные края, ограничение пиков примерно -1.5 dBFS, сглаживание швов петель. bank.json связывает события с вариантами; раздел clips в bank.json содержит происхождение готовых клипов. Загрузки в игре нет.

## Повторная сборка разработчиком

Игроку ничего устанавливать не нужно. Разработчику нужны Python, numpy и soundfile:

```sh
python -m pip install numpy soundfile
python tools/build_audio.py
```

Затем выполните импорт в Godot. Оригиналы не изменяются. Audacity можно использовать для прослушивания и ручной обработки WAV/OGG. Если хочется заменить звук, положите новый WAV/OGG в отдельную папку assets/audio/custom/, импортируйте и измените соответствующий путь bank.json. Сохраняйте лицензию и автора нового файла. Установка сторонних кодеков для воспроизведения готового OGG не требуется.
