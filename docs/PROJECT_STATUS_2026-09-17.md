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

## 5. Canyon Curated Set — Sıradaki Tasarım Yönü

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

Örnek:

- 45–65 m: küçük enkaz + çapa
- 85–105 m: zincir + eski fener
- 120–145 m: iskelet / gizemli kalıntı
- 155–175 m: karanlık mağara / Leviathan foreshadow alanı

Amaç:

- `%70` doğal canyon
- `%20` gizemli kalıntı
- `%10` özel hikâye / boss / nadir obje hissi

## 6. Büyük Batık Gemi Kararı

- Büyük batık geminin canyon ortasına yerleştirilmesi şu an önerilmiyor.
- Canyon dar ve dikey kompozisyonlu olduğu için büyük gemi ana görseli bozabilir.
- Büyük shipwreck ileride:
  - açık deniz biyomunda,
  - ayrı bir yan bölgede,
  - veya uzak arka plan POI olarak
  değerlendirilebilir.

## 7. Sıradaki Net İş

Yeni sohbette buradan devam edilecek:

1. `Canyon Curated Set v1` listesini kesinleştir.
2. İlk 3 uyumlu asseti üret:
   - çapa,
   - zincir,
   - küçük kırık enkaz.
3. Bunları farklı derinliklerde canyon içine test amaçlı yerleştir.
4. Screenshot ile stil ve yoğunluk kontrolü yap.
5. Yakışırsa kalan curated assetlere geç.

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
- Yeni Canyon Curated Set: ⏳ sıradaki ana iş
