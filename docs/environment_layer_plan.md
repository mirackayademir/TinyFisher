# TinyFisher — Katmanlı Deniz / Dünya Görsel Planı

Bu belge, TinyFisher'ın yeni deniz ve atmosfer görselleri için teknik çalışma planıdır.
Amaç tek parça bir konsept resmi oyuna yapıştırmak değil; Godot içinde ayrı ayrı kontrol edilebilen, animasyonlanabilen ve gerektiğinde RNG ile yerleştirilebilen gerçek oyun assetleri üretmektir.

## Ana kural

- Görseller tek parça sahne olarak üretilmeyecek.
- Her görsel önce kullanım amacı, katmanı, boyutu, şeffaflık ihtiyacı ve animasyon yöntemi belirlenerek hazırlanacak.
- Oyuncunun açık üretim onayı gelmeden görsel üretimi yapılmayacak.
- Yeni görseller hazır olana kadar mevcut shader tabanlı Sky/Water sistemi kaldırılmayacak; böylece geliştirme sırasında oyun bozulmayacak.

---

## Katman sırası

### A. Gökyüzü / ufuk

1. `SkyBase`
   - Gün batımı gökyüzü.
   - Güneş bu assetin içinde OLMAYACAK.
   - Uzak ada ve deniz bu assetin içinde OLMAYACAK.
   - Yatayda parallax / tekrar kullanımına uygun olacak.
   - Önerilen üretim: 2048x512 veya 2560x512 pixel-art panorama.
   - Arka plan opak.

2. `Sun`
   - Ayrı şeffaf PNG.
   - Pixel-art güneş diski + çok hafif kontrollü halo.
   - Godot içinde bağımsız konumlandırılır ve çok yavaş parallax uygulanabilir.
   - Önerilen asset alanı: 256x256.

3. `HorizonLand`
   - Uzak kayalık ada / deniz feneri / silüet çeşitleri.
   - Şeffaf PNG.
   - 2–4 varyant hazırlanır; tüm dünya boyunca aynı ada tekrar etmez.
   - Çok düşük parallax hızında hareket eder.

### B. Deniz yüzeyi

4. `OceanSurfaceBase`
   - Su yüzeyinin ana renk / dalga dokusu.
   - Ufuk çizgisi ve büyük dalgalar.
   - Yatay tekrar kullanımına uygun olacak.
   - Bu katman su altı gövdesini içermeyecek.

5. `WaveBack`
   - Küçük ve orta dalga tepeleri.
   - Şeffaf sprite strip / sprite sheet.
   - Daha yavaş kayan arka dalga katmanı.

6. `WaveFront`
   - Oyuncuya yakın dalga tepeleri.
   - Şeffaf sprite strip / sprite sheet.
   - Biraz daha hızlı hareket.

7. `SurfaceFoam`
   - Köpük / beyaz kırılma çizgileri.
   - Ayrı şeffaf asset.
   - Hafif alpha pulse ve yatay drift ile canlandırılır.

Not: Mevcut Line2D dalga sistemi yeni katmanlar doğrulanana kadar yedek olarak kalır.

### C. Su altı temel atmosferi

8. `UnderwaterBase`
   - Dev bir bitmap yerine renk geçişi + mevcut depth sistemi kullanılacak.
   - Sığda turkuaz, derinde lacivert / siyaha yaklaşan ton.
   - Bu değişim kodla yapılır; gereksiz dev görsel üretilmez.

9. `SunRays`
   - Yüzeyden aşağı inen ışık huzmeleri.
   - Ayrı şeffaf texture.
   - Yavaş alpha / x drift.
   - Yaklaşık 0–35 m arasında görünür, aşağı indikçe kaybolur.

10. `WaterParticlesBack`
    - Çok küçük parçacıklar / plankton / toz.
    - Kodla oluşturulabilir veya küçük texture atlas kullanılabilir.
    - Düşük yoğunluk.

11. `WaterParticlesFront`
    - Kamera önündeki daha iri birkaç parçacık.
    - Çok seyrek.
    - Derinlik arttıkça renk ve hız değişebilir.

### D. Su altı dekorları

Dekorlar tek bir büyük arka plan olmayacak. Her obje ayrı şeffaf asset olacak ve uygun derinlik bölgesinde kontrollü RNG ile yerleştirilecek.

12. `BackgroundDecor`
    - Uzak kaya duvarları
    - Uzak mercan / yosun silüetleri
    - Uzak balık sürüsü silüetleri
    - Çok düşük kontrast

13. `MidDecor`
    - Kayalık çıkıntı
    - Mercan kümeleri
    - Yosun
    - Küçük harabe parçaları
    - Zincir / çapalar

14. `LandmarkDecor`
    - Batık gemi
    - Büyük iskelet
    - Harabe kapısı
    - Dev çapa
    - Mağara ağzı
    - Leviathan / boss bölgeleri için özel çevresel landmarklar

15. `ForegroundDecor`
    - Ekranın kenarlarından giren koyu kaya / yosun parçaları
    - Oyuncu ve balıkların önüne nadiren geçebilir.
    - Düşük yoğunluk; oynanışı kapatmayacak.

---

## Derinlik bölgeleri

### 0–20 m — Sığ Su
- Parlak turkuaz.
- Güçlü güneş ışınları.
- Küçük kayalar, yosun, küçük balık silüetleri.
- Dekor yoğunluğu orta.

### 20–50 m — Açık Mavi Bölge
- Daha doygun mavi.
- Işık huzmeleri zayıflamaya başlar.
- Kaya oluşumları, mercanlar, küçük batık parçaları.
- Daha büyük balık silüetleri.

### 50–80 m — Derin Deniz
- Soğuk koyu mavi / lacivert.
- Güneş ışınları çok az.
- Batıklar, zincirler, büyük kayalar, seyrek biyolüminesans.
- Görüş alanı daha dar hissedilir.

### 80–100 m — Abyss
- Çok koyu lacivert / siyah.
- Doğal yüzey ışığı yok denecek kadar az.
- Büyük iskelet, harabe, mağara, dev gölge / tentacle benzeri uzak detaylar.
- Dekor sayısı az fakat objeler büyük ve anlamlı.
- Leviathan gibi bosslar için uygun çevre.

---

## RNG yerleşim kuralları

Tamamen rastgele dağıtım kullanılmayacak. Kontrollü kompozisyon kullanılacak.

- Dünya her çalıştırmada anlamsız şekilde değişmemeli; sabit seed kullanılacak.
- Her derinlik bandının ayrı dekor havuzu olacak.
- Büyük landmarklar arasında minimum yatay mesafe bulunacak.
- Aynı asset yan yana tekrar etmeyecek.
- Balıkların yüzme / yem / kanca alanları büyük foreground dekorlarla kapatılmayacak.
- Liman çevresi elle tasarlanacak; RNG limana yaklaşmayacak.
- Büyük dekorların yatay flip, hafif scale varyasyonu ve sınırlı renk varyasyonu olabilir.

---

## Godot node hedefi

Yeni sistem aşağıdaki boş katmanları oluşturacak. Assetler üretildikçe doğrudan ilgili node'a takılacak.

```text
World
├─ Sky (mevcut, geçici yedek)
├─ Water (mevcut, geçici yedek)
├─ EnvironmentLayers
│  ├─ SkyParallax
│  │  ├─ SkyBaseLayer
│  │  ├─ SunLayer
│  │  └─ HorizonLandLayer
│  ├─ SurfaceLayers
│  │  ├─ OceanSurfaceLayer
│  │  ├─ WaveBackLayer
│  │  ├─ WaveFrontLayer
│  │  └─ SurfaceFoamLayer
│  ├─ UnderwaterLayers
│  │  ├─ SunRaysLayer
│  │  ├─ BackgroundDecorLayer
│  │  ├─ MidDecorLayer
│  │  ├─ LandmarkDecorLayer
│  │  ├─ ForegroundDecorLayer
│  │  └─ ParticleLayer
│  └─ RuntimeDecor
```

Katmanlar ilk kurulumda boş olacaktır; mevcut görünümü değiştirmeyecektir.

---

## Görsel üretim sırası

Görsel üretim onayı geldiğinde sıra:

1. SkyBase
2. Sun
3. HorizonLand varyantları
4. OceanSurfaceBase
5. WaveBack / WaveFront / SurfaceFoam animasyon assetleri
6. SunRays
7. Sığ su dekor seti
8. Orta su dekor seti
9. Derin su dekor seti
10. Abyss dekor + landmark seti

Her başlık için üretimden önce ayrı prompt / teknik asset tanımı hazırlanacak ve oyuncu onayından sonra üretilecek.

---

## İlk konseptten korunacak sanat yönü

Beğenilen prototipin şu özellikleri korunacak:

- Gün batımında mor / turuncu gökyüzü.
- Koyu mavi, kontrastlı pixel-art deniz.
- Sığda turkuaz ışık.
- Derine doğru dramatik lacivert kararma.
- Kayalık uçurum hissi.
- Batık gemi / harabe gibi hikâye anlatan çevre detayları.
- Derinde doğrudan gösterilmeyen, silüet halinde tehdit hissi veren büyük yaratık izleri.

Ancak bu öğelerin hiçbiri tek bir birleşik background resmi olarak kullanılmayacak.
