# Ткань хирурга 0.11

Сохранена в `assets/textures/hospital_cloth_generated.png`. Создана встроенным imagegen 29 октября 2026, без CLI/API-ключа. Исходный PNG скопирован в проект без растровой правки; это синтетическое изображение. Blender уменьшает копию в памяти до 1024×1024 и упаковывает в GLB, исходный файл не меняет. Материал применяется к халату, фартуку, маске и медицинским подушкам. Процедурные normal/color остаются запасными. Игроку imagegen не нужен.

Полный исходный промпт:

> Create one square seamless albedo texture for a realistic fictional survival horror game surgeon coat. Flat orthographic evenly lit close-up of aged off-white unbleached surgical cotton fabric, subtle woven cotton fibres, irregular grime, sweat yellowing, frayed creases, scattered dark dried maroon blood smears, thin gravity drips and a few wiped finger streaks. Blood is realistically absorbed into the cloth with feathered capillary edges, NOT shiny paint, not decorative patterns, NOT round polka dots, NOT camouflage. Keep 65 percent of fabric relatively light, concentrate a broad asymmetrical smear in lower center and scattered small stains around it. High quality physically plausible material reference. No garment silhouette, no body, no human, no gore or organs, no objects, no text, no border, no lighting gradients or cast shadows, no perspective. The whole image is only fabric surface suitable to wrap a 3D hospital monster coat. Make the edges tile seamlessly.

---

# Сгенерированные изображения

Текстура: `assets/textures/decals/bootprint.png`, RGBA 1024×1536. Создана **встроенным imagegen**, без CLI/API-ключа. Сохранена без последующей растровой обработки. Это сгенерированный реалистичный отпечаток, не фотография. Используется как статичный след на карте и как динамический отпечаток; цвет и зеркальная правая нога задаются игровым шейдером.

Исходный промпт:

> Create a production game texture asset: one single realistic LEFT combat/work BOOT FOOTPRINT STAMP, straight orthographic top down, toe at top heel at bottom, vertically centered, entire sole visible with ample transparent margin. This is the dirty ink impression LEFT BEHIND by a boot, NOT an actual boot or shoe. Photographically credible irregular worn sole contact: broad rounded forefoot, narrow arch gap, separate block heel; angular chevron lug tread blocks, thin parallel grooves and little rubber cracks, uneven contact pressure, tiny scratched missing spots and slight smearing along the toe edge. Color only dark charcoal brown grime, translucent scuffed edges. Empty grooves and surrounding background must be genuinely transparent alpha. No floor, no background color, no lighting, no drop shadow, no perspective, no text, no logos, no second footprint. Texture will be tinted as muddy or bloody sole prints in a 3D horror game.
