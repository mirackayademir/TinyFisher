# TinyFisher — Proje Son Durum Raporu

Tarih: 2026-09-17
Branch: `eski`

## 1. HQ Canyon — TAMAMLANDI / KİLİTLENDİ

- Ana canyon kaynağı artık tek parça HQ asset:
  - `res://assets/environment/terrain/canyon_hq.png`
- Kaynak çözünürlük: `1226x1283`
- Eski Base64/chunk sistemi ana yol olmaktan çıkarıldı; yalnızca acil fallback mantığı kaldı.
- Canyon oranı bozulmadan, tek tip ölçek ile yerleştiriliyor.
- Canyon gameplay derinlik bandı:
  - Başlangıç: `20 m`
  - Taban: `180 m`
- Canyon artık görsel ve gameplay açısından kilitli kabul edilecek. Ciddi hata olmadığı sürece ölçek/derinlik değiştirilmemeli.

## 2. Kanca / Dünya Derinliği — TAMAMLANDI

- Önce denenmiş `250 m` dünya / Abyss planı iptal edildi.
- Maksimum oynanabilir derinlik canyon tabanına çekildi:
  - `180 m`
- Kanca F5 testinde canyonun en altına kadar iniyor ve daha aşağı inmiyor.
- Derinlik upgrade planı yeni 180 m tavana göre:
  - 60 m
  - 100 m
  - 130 m
  - 150 m
  - 165 m
  - 180 m
- Canyon altında yalnızca çok kısa görsel taban payı var; oynanabilir ekstra 180–250 m alan yok.

## 3. Son Görsel Durum

- HQ canyon düzgün geliyor.
- 20–180 m aralığı doğru.
- Kanca 180 m tabanda duruyor.
- Canyonun altındaki eski büyük siyah/Abyss boşluğu kaldırıldı.
- Görselde canyon zaten yoğun şekilde:
  - kaya,
  - yosun,
  - mercan,
  - doğal deniz tabanı detayları
  içeriyor.

## 4. 36 Environment Asset Kararı

Eski `36 assets` paketini canyon üzerine olduğu gibi yerleştirme fikri artık önerilmiyor.

Sebep:

- Canyon zaten yüksek detaylı bir "hero environment".
- İçinde doğal dekor yeterince güçlü.
- Eski paket içindeki büyük batık gemi, sandık, rastgele dekorlar canyon üzerine zorla yerleştirilirse görüntü kalabalık ve yapay olabilir.
- HQ canyon ile eski assetlerin stil/kalite farkı tekrar çirkin görüntü oluşturabilir.

### Yeni karar

`36 assets` tamamen çöpe atılmayacak; açık deniz, liman, başka biyom veya gelecekteki map bölgelerinde kullanılabilir.

Canyon için ayrı, küçük ve özel bir **Canyon Curated Set** hazırlanacak.

## 5. Canyon Curated Set — V1 TESTİ AKTİF

İlk etapta yaklaşık `8–12` adet, canyon stiline özel asset hedefleniyor.

Önerilen adaylar:

1. Yarı gömülü çapa
2. Eski zincir
3. Küçük kırık gemi/tahta kalıntısı
4. Eski su altı feneri / lamba
5. Küçük mağara ağzı
6. Büyük balık / yaratık iskeleti
7. Parlayan derin deniz bitkisi
8. Yoğun mercan kümesi
9. Sivri kaya çıkıntısı / taş sütun
10. Kayaya sıkışmış küçük enkaz detayı

### Yerleştirme yaklaşımı

Assetler her yere serpiştirilmeyecek. Bunun yerine az sayıda **POI (Point of Interest)** oluşturulacak.

Hedef dağılım:

- `%70` doğal canyon
- `%20` gizemli kalıntı
- `%10` özel hikâye / boss / nadir obje hissi

### 2026-09-17 — V1 test uygulaması

Yeni runtime:

- `res://scenes/canyon_curated_set.gd`
- `project.godot` autoload: `CanyonCuratedSet`

İlk üç test asseti mevcut HQ kaynaklardan seçildi:

- `res://assets/environment/abyss/abyss_anchor_01.png`
- `res://assets/environment/deep_sea/deep_sea_chain_01_TEMP.png`
- `res://assets/environment/deep_sea/deep_sea_wreck_01.png`

Test POI yerleşimi:

- `55 m`: yarı gömülü çapa
- `58 m`: küçük enkaz
- `96 m`: eski zincir

Üçüne de aynı görsel uyum materyali uygulanıyor:

- hafif saturation düşürme,
- canyon tonuna yakın mavi/gri tint,
- hafif brightness düşürme,
- linear + mipmap filtreleme.

Amaç eski assetleri canyon üzerine yığmak değil; yalnızca ilk 3 parçanın stil uyumunu F5 screenshot ile değerlendirmek.

## 6. Büyük Batık Gemi Kararı

- Büyük batık geminin canyon ortasına yerleştirilmesi şu an önerilmiyor.
- Canyon dar ve dikey kompozisyonlu olduğu için büyük gemi ana görseli bozabilir.
- Büyük shipwreck ileride:
  - açık deniz biyomunda,
  - ayrı bir yan bölgede,
  - veya uzak arka plan POI olarak
  değerlendirilebilir.

## 7. Sıradaki Net İş

1. Kullanıcı `git pull` yapacak.
2. Godot F5 ile canyonu açacak.
3. 55–58 m POI ile 96 m zincirin screenshot'ı alınacak.
4. Stil/boyut/pozisyon kontrolü yapılacak.
5. Uyum iyiyse kalan curated assetlere geçilecek.
6. Uyum kötüyse sistem korunup yalnız asset görselleri özel HQ versiyonlarla değiştirilecek.

## 8. Git / Workflow Notları

- Ana çalışma branch'i: `eski`
- Büyük değişiklik olmadıkça yeni branch açılmayacak.
- Yeni branch açmadan önce kullanıcıya sorulacak.
- KISS yaklaşımı korunacak.
- Her tamamlanan görevden sonra kısa durum raporu verilecek.

## Son Özet

- HQ Canyon: ✅
- 20–180 m canyon: ✅
- Kanca max 180 m: ✅
- 250 m Abyss planı: ❌ iptal
- Canyon oranı: ✅
- Eski 36 assets canyon üzerine topluca yerleştirme: ❌ önerilmiyor
- Canyon Curated Set runtime: ✅
- İlk test POI (çapa + küçük enkaz): ✅ 55–58 m
- İkinci test POI (zincir): ✅ 96 m
- Görsel onay: ⏳ F5 screenshot bekleniyor
