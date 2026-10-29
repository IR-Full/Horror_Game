# Авторы ассетов

## Модели

В каталоге 42 модели, 35 536 треугольников уникальной геометрии. 41 модель создана скриптами Blender проекта. Число треугольников кадра зависит от повторений объектов.

Активная модель: **3D Horror Game Monster**, **City Building Game Art / HorrorGameMaker.com**, [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/). [Исходная страница](https://opengameart.org/content/3d-horror-game-monster), [исходник и SHA-256](../art-source/third_party/horror_game_maker/NOTICE.md). В Blender изменены пропорции, поза и веса для 15 игровых костей и 11 анимаций; исходные цвет и нормали уменьшены до 2048/1024 px. Активная модель — 3584 треугольника.

Сохранённая прежняя модель **Smily horror monster** by **Bento (@gostbento)**:

- [Оригинальная модель на Sketchfab](https://sketchfab.com/3d-models/smily-horror-monster-3d3fc31eddaa409a8f2df564823154e1)
- [Автор](https://sketchfab.com/gostbento)
- [CC Attribution 4.0 International](https://creativecommons.org/licenses/by/4.0/)
- [Публичное зеркало GLB](https://models.codelove.in/library/ghosts/smiley-horror-monster.glb)

Лицензия сверена с API исходной страницы; метаданные сохранены вместе с исходником. Изменения: поза, пропорции и масштаб, объединение весов исходного скелета, привязка к 15 костям проекта и 11 собственным игровым анимациям. Исходные UV и текстуры сохранены. Анимационные пакеты зеркала не использовались.

Исходник и SHA-256: [NOTICE](../art-source/third_party/bento_smily/NOTICE.md). Прежняя процедурная сущность и библиотека сохранены в `art-source/legacy/`; восстановление описано в NOTICE.

## Текстуры и оформление

Восемь процедурных наборов 512×512: штукатурка, краска, бетон, плитка, металл, мышцы, дерево и ткань; цвет, нормали и шероховатость. Создаются в `tools/build_art.py`.

`textures/decals/bootprint.png` — сгенерированная через встроенный imagegen прозрачная текстура следа. [Промпт и происхождение](../docs/GENERATED_ASSETS.md). Это синтетическое изображение, не фотография.

Шейдеры крови, следов, мышц, контактных теней и атмосферы созданы в проекте. Надписи используют системные шрифты с общим fallback; сторонние файлы шрифтов не распространяются.

## Звук

88 OGG-клипов. Сохранены 31 исходная запись **CC0 1.0** с OpenGameArt и BigSoundBank и 18 активных локально синтезированных русских реплик (прежние три SAPI WAV сохранены в архиве исходников). Новая боль — **Lasse Bührmann / EmoPreben**, новые контакты обуви — **Joseph SARDIN**. Реплики подготовлены локально через Piper Dmitri medium: датасет CC0 по [карточке модели](https://huggingface.co/rhasspy/piper-voices/blob/main/ru/ru_RU/dmitri/medium/MODEL_CARD), репозиторий модели MIT. Тексты и обработка созданы в проекте; синтез не выдаётся за актёрскую запись. В игру входят только готовые записи, движок синтеза и файлы голоса не распространяются. Авторы: **HaelDB, rubberduck, Darsycho, Brian MacIntosh (BMacZero), TinyWorlds, EZduzziteh, Tabasco, SpringySpringo, YCbCr, qubodup**.

[Полные источники и обработка](../docs/AUDIO_SOURCES.md), [пофайловые лицензии и SHA-256](audio/sources.json). Неизменённые оригиналы сохранены в `audio/sources/`, исключены из импорта и готовой сборки. В синтезе остаются музыка, радио, SOS и сердцебиение. Микрофоны игроков используются только для голосового чата: звук не записывается на диск и не становится игровым ассетом.

Для запуска Blender, Audacity, Python и загрузка дополнительных ассетов не нужны.
