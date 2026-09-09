# TinyFisher — Environment Asset Checkpoint

**Tarih:** 2026-09-09  
**Branch:** `eski`  
**Amaç:** Yeni sohbette bu dosyayı okuyarak deniz/dünya görsel çalışmasına tam olarak kaldığımız yerden devam etmek.

---

## 1. Bu checkpoint neden var?

Bugün mevcut tek-parça ve çirkin görünen deniz/gökyüzü sistemini değiştirmek için **katmanlı oyun asset sistemi** tasarladık. Ana kuralımız: tek büyük arka plan resmi üretip oyuna yapıştırmak yok. Gökyüzü, güneş, ufuk, deniz yüzeyi, dalgalar, köpük, ışık huzmeleri ve her derinlik bandındaki dekorlar ayrı asset olacak.

Kullanıcının görsel çalışma kuralı:

- Kullanıcı bir görsel fikri söylediğinde hemen görsel üretme.
- Önce projeye uygun prompt/tasvir/teknik kullanım planını metin halinde hazırla.
- Kullanıcı açıkça `üretebilirsin`, `şimdi görsel üretebilirsin` veya benzer onay vermeden image generation çağırma.
- Oyun assetlerini mümkün olduğunca ayrı katmanlar halinde tasarla.
- Obje/dekor assetlerinin arka planı gerçekten şeffaf olsun.
- Görselleri üretirken Godot'ta hangi layer, derinlik, animasyon ve RNG mantığıyla kullanılacağını önceden düşün.

---

## 2. Repo tarafında bugün hazırlanan altyapı

Daha önce `scenes/environment_layers.gd` eklendi ve `EnvironmentLayers` sistemi autoload olarak aktif edildi.

Hazır layer yapısı:

```text
World
└─ EnvironmentLayers
   ├─ SkyParallax
   │  ├─ SkyBaseLayer
   │  ├─ SunLayer
   │  └─ HorizonLandLayer
   ├─ SurfaceLayers
   │  ├─ OceanSurfaceLayer
   │  ├─ WaveBackLayer
   │  ├─ WaveFrontLayer
   │  └─ SurfaceFoamLayer
   ├─ UnderwaterLayers
   │  ├─ SunRaysLayer
   │  ├─ BackgroundDecorLayer
   │  ├─ MidDecorLayer
   │  ├─ LandmarkDecorLayer
   │  ├─ ForegroundDecorLayer
   │  └─ ParticleLayer
   └─ RuntimeDecor
```

Mevcut Z sırası:

- SkyBase `-30`
- Sun `-29`
- Horizon `-28`
- OceanSurface `-20`
- WaveBack `-19`
- SunRays `-18`
- BackgroundDecor `-17`
- MidDecor `-12`
- LandmarkDecor `-10`
- WaveFront `-3`
- SurfaceFoam `-2`
- ForegroundDecor `8`
- Particles `9`

Mevcut eski `Sky/Water` shader sistemi **yeni assetler oyunda doğrulanana kadar silinmeyecek**. Geçiş güvenli yapılacak.

---

## 3. Derinlik bölgeleri

Kod tarafında hedef bölgeler:

- `0–20 m` → `shallow`
- `20–50 m` → `open_blue`
- `50–80 m` → `deep`
- `80–100 m` → `abyss`

Yaklaşık dünya yerleşimi için referans:

- Su yüzeyi: yaklaşık `Y = 360`
- Test modunda 100 m fiziksel erişim yaklaşık `3450 px`
- Yaklaşık `1 m ≈ 34.5 px`

Önemli yerleşim kuralı: **20–80 m arasında düz tabanlı kaya PNG'lerini ekranın ortasına deniz tabanı varmış gibi koyma.** Orta derinlikte kayalar çoğunlukla kamera kenarından/altından giren uzak uçurum veya çıkıntılar gibi kullanılacak. Gerçek taban ve büyük landmark hissi esas olarak 80–100 m Abyss bölgesinde artacak.

RNG:

- Sabit seed: `9042026`
- Liman çevresi RNG dışında tutulacak.
- Güvenli yatay spawn yaklaşık `X = 1400–10700`.
- Büyük landmarklar aynı ekranda üst üste yığılmayacak.
- Aynı asset arka arkaya kullanılmayacak; flip ve sınırlı scale varyasyonu uygulanabilir.

---

## 4. Bugün üretilen assetler — toplam 36

Tüm oyun-hazır PNG'ler şu paketin içinde saklandı:

`art_sources/environment/tinyfisher_environment_assets_2026-09-09.zip`

Paket içindeki klasör yolları doğrudan repo köküne göre hazırlanmıştır (`assets/environment/...`).

### Sky / Horizon — 3

1. `assets/environment/sky/sky_base_01.png` — **OK** — ana mor/turuncu gün batımı gökyüzü.
2. `assets/environment/sky/sun_01_TEMP.png` — **TEMP_REVIEW** — güneşin içine gökyüzü/bulut dokusu sızdı; final turunda yeniden üretilecek.
3. `assets/environment/sky/horizon_land_01.png` — **OK** — uzak kayalık ufuk/ada silüeti.

### Sea Surface / Light — 5

4. `assets/environment/surface/ocean_surface_base_01.png` — **OK** — ana deniz yüzeyi.
5. `assets/environment/surface/wave_back_01.png` — **OK** — yavaş arka dalga katmanı.
6. `assets/environment/surface/wave_front_01.png` — **OK** — daha belirgin ön dalga katmanı.
7. `assets/environment/surface/surface_foam_01.png` — **OK** — ayrı köpük katmanı.
8. `assets/environment/underwater/sun_rays_01.png` — **OK** — 0–35 m civarı su altı ışık huzmeleri.

### Shallow 0–20 m — 5

9. `shallow_rock_01.png` — **OK**
10. `shallow_kelp_01.png` — **OK**, hafif sway animasyonu planlandı.
11. `shallow_coral_01.png` — **OK**
12. `shallow_fish_school_01_TEMP.png` — **TEMP_REVIEW**, kullanıcı “eh işte / idare eder” dedi; arka planda düşük kontrast kullanılabilir veya finalde yenilenir.
13. `shallow_rock_02.png` — **OK**, ilk kayadan daha yatay varyant.

### Open Blue 20–50 m — 5

14. `open_blue_rock_01.png` — **OK**, dik kaya sütunu.
15. `open_blue_coral_01.png` — **OK**, daha soğuk mor/indigo mercan.
16. `open_blue_wreck_01.png` — **OK**, küçük kırık tekne/tahta kalıntısı.
17. `open_blue_large_fish_silhouette_01.png` — **OK**, uzak atmosfer balığı; yakalanabilir balık değil.
18. `open_blue_rock_02.png` — **OK**, doğal kaya kemeri/geçit.

### Deep Sea 50–80 m — 7

19. `deep_sea_rock_01.png` — **OK**, karanlık dik kaya.
20. `deep_sea_chain_01_TEMP.png` — **TEMP_REVIEW**, kullanıcı zincirin kadrajdan kesilmiş ve dev göründüğünü söyledi. Finalde daha küçük 2–3 zincir parçasına bölmek daha doğru.
21. `deep_sea_wreck_01.png` — **OK**, büyük eski batık gövde parçası.
22. `deep_sea_bioluminescent_01.png` — **OK**, cyan biyolüminesan bitki/mantar benzeri dekor; alpha pulse planlandı.
23. `deep_sea_creature_silhouette_01_TEMP.png` — **TEMP_REVIEW**, uzaktaki büyük yaratık silüeti kullanıcıya göre idare eder.
24. `deep_sea_rock_02.png` — **OK**, yatay/çökmüş koyu kaya.
25. `deep_sea_landmark_ruin_gate_01.png` — **OK**, 50–80 m için çok seyrek antik taş kapı landmarkı.

### Abyss 80–100 m — 6

26. `abyss_rock_01_TEMP.png` — **TEMP_REVIEW**, kullanıcı idare eder dedi.
27. `abyss_cave_01.png` — **OK**, büyük karanlık mağara ağzı landmarkı.
28. `abyss_skeleton_01.png` — **OK**, dev bilinmeyen deniz yaratığı iskeleti.
29. `abyss_ruin_01_TEMP.png` — **TEMP_REVIEW**, çökmüş yabancı harabe.
30. `abyss_anchor_01.png` — **OK**, dev eski çapa landmarkı.
31. `abyss_tentacle_silhouette_01_TEMP.png` — **TEMP_REVIEW**, arka planda çok seyrek tentacle gölgesi.

### Leviathan özel çevresi 92–100 m — 5

32. `leviathan_scars_01_TEMP.png` — **TEMP_REVIEW**, dev çizik/ısırık izli kaya.
33. `leviathan_debris_01_TEMP.png` — **TEMP_REVIEW**, parçalanmış ağır olta/kanca/makara kalıntısı.
34. `leviathan_glow_marker_01.png` — **OK/LOW_DENSITY**, kırmızı çatlaklı çevre işareti; Leviathan'ın kendi kırmızı ışığıyla yarışmayacak kadar seyrek kullanılmalı.
35. `leviathan_arena_rock_left_01_TEMP.png` — **TEMP_REVIEW**, boss alanı sol kaya duvarı.
36. `leviathan_arena_rock_right_01.png` — **OK**, boss alanı sağ kaya duvarı.

---

## 5. Asset pack teknik notu

Paket içindeki PNG'ler **Godot entegrasyonu için game-ready boyutlara normalize edildi** ve repo boyutunu kontrol etmek için 256 renkli indexed PNG olarak optimize edildi. Pixel-art kenarlar için nearest-neighbor ölçekleme kullanıldı, transparan objelerde alfa korunmuştur.

Bu paket **36 assetin bugünkü onaylı çalışma kopyasıdır**. Final polish sırasında `TEMP_REVIEW` isimli dosyalar değiştirilirse eski dosyanın üzerine körlemesine yazmak yerine önce yeni varyant test edilmelidir.

Paket SHA-256:

`ae736b31112062e4e4cd6b929fd9feb6c84ada9fcf7a1a7de79e54a8ad922cfa`

---

## 6. Yarın yapılacak ilk iş — GÖRSEL ÜRETME DEĞİL, ENTEGRASYON

Yeni sohbet açıldığında bu dosyayı oku ve buradan devam et.

Önerilen sıra:

1. Asset pack'i repo köküne çıkar (`tools/extract_environment_asset_pack.ps1`).
2. Godot importlarının oluştuğunu doğrula.
3. Önce sadece **SkyBase + HorizonLand + geçici Sun** yerleştir ve ekran görüntüsüyle kontrol et.
4. Ardından `OceanSurfaceBase + WaveBack + WaveFront + SurfaceFoam` bağla.
5. Dalga katmanlarına farklı yatay drift hızları ve hafif bob uygula.
6. `SunRays` sadece 0–35 m bandında görünsün; derine indikçe alpha düşsün.
7. Sonra dekor spawn sistemi: shallow → open_blue → deep → abyss.
8. Mid-depth kayaları havada duran taban gibi kullanma; kenar/uçurum kompozisyonu uygula.
9. Landmarklar çok seyrek ve aynı ekranda maksimum 1 büyük obje olacak şekilde yerleşsin.
10. 92–100 m Leviathan çevre assetleri normal RNG'ye girmesin; Leviathan bölgesine özel sabit/yarı-sabit koordinatlar kullan.
11. Tüm yeni dünya görünümü doğrulandıktan sonra eski Sky/Water shader sistemini aşamalı kapat.
12. En son `TEMP_REVIEW` assetleri görsel polish turuna al.

**Yeni asset üretmeye, entegrasyon testini görmeden tekrar başlama.** Önce elimizdeki 36 assetin oyunda gerçekten nasıl durduğunu görelim.

---

## 7. Leviathan gameplay tarafında kaldığımız durum

Görsel dünya çalışmasına geçmeden hemen önce Leviathan tarafında:

- Yemi görünce hızlı biçimde yeme geliyor.
- Hızlandığında kuyruk animasyonu da hızlanıyor.
- Kanca artık kırmızı fener noktasına değil, diş/ağız bölgesine oturuyor.
- İlk boss fight prototipi var: `LEVIATHAN • DİRENÇ 100%` barı açılıyor, sarıldıkça 0'a iniyor ve test yakalama gerçekleşiyor.
- Gerçek boss fazları, özel saldırılar ve gelişmiş mücadele henüz daha sonra yapılacak.
- Leviathan'ı şimdilik bıraktık; mevcut ana görev dünya/deniz görsel entegrasyonu.

---

## 8. Çalışma kuralları

- Branch: `eski`.
- Büyük değişiklik olmadıkça yeni branch açma; açmadan önce kullanıcıya sor.
- Git konusunda kullanıcıyı gereksiz yere uğraştırma; mümkün olan işi doğrudan repo üzerinde yap.
- Bir değişiklik bittiğinde kısa rapor ver.
- Görsel üretim için her zaman önce prompt/tasvir hazırla, açık kullanıcı onayı gelmeden üretme.
- Kullanıcı açıkça onaylamadığı yeni mekanik/görsel fikri projeye ekleme; öneri olarak belirt.

**Kaldığımız nokta:** 36 environment asset üretildi ve kaynak paketi GitHub'a kaydedildi. Sıradaki iş assetleri Godot'a çıkarıp katman katman entegre etmek.