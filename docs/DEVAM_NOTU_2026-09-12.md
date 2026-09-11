# TinyFisher — Devam Notu
**Tarih:** 2026-09-12  
**Branch:** `eski`  
**Amaç:** Yeni sohbette bu dosyadan doğrudan devam etmek.

## Şu an kaldığımız yer

Godot için ayrı bir **2B Editor Preview** sistemi kuruldu.  
Kullanılacak sahne:

`res://scenes/world_editor_preview.tscn`

Bu sahne gerçek `world.tscn`yi gösteriyor ve runtime'da oluşturulan sualtı terrain/kanyon öğelerini editörde de görebilmemizi sağlıyor.

### Önceki büyük hata
Runtime terrain sistemi aynı `deep_sea_rock_01` görselini dev boyutta 6 kere tekrar ediyordu. Editor Preview sayesinde bu ilk kez bütün haritada net görüldü.

Bu tekrar eden kaya sistemi kaldırıldı.

---

## Kanyon texture sorununun kök nedeni

Önce `underwater_canyon_20_100_hq.webp` kullanılmaya çalışıldı.

Sonradan görüldü ki:
- Git geçmişindeki “accepted HQ WebP” dosyası ilk eklendiği committen beri bozuk.
- Dosya ~14 KB idi.
- RIFF/base64 chunk yamalarıyla düzeltmeye çalışmak doğru çözüm değildi.
- 2048×682 lossless chunk seti de Godot WebP decoder'ında geçerli görüntü üretmedi.

Bu yol bırakıldı.

### Şu an kullanılan sağlam kaynak

Eski **V15 verified canyon data** sistemine geri dönüldü.

Kaynak:
`assets/environment/terrain/runtime_data/canyon_20_100_part*.txt`

Toplam 18 parça.

Doğrulamalar:
- Base64 uzunluğu: `74540`
- Decode byte boyutu: `55904`
- SHA-256:
  `44d51db26db819b7ca6c950bf4cc67b1074a41da859272337ef1a2b2763395f4`
- Texture boyutu: `965x722`

Son testte Godot Output'ta şu satır başarıyla çıktı:

`VERIFIED CANYON OK: 18 parca / 55904 byte / SHA256=OK / 965x722`

Bu nedenle **texture verisi artık sağlam**.

---

## Son kalan hata ve yapılan düzeltme

Texture doğrulandıktan sonra Editor Preview şu hatayı verdi:

`Invalid call. Nonexistent 'float' constructor.`

Kaynak:
`editor_environment_preview.gd` içinde:

```gdscript
float(hook.get("max_depth"))
float(hook.get("max_depth_meters"))
```

Aynı kullanım runtime dosyasında da vardı.

İki dosyada da `float(...)` constructor yaklaşımı kaldırıldı ve değerler `Variant` üzerinden güvenli şekilde sayıya çevrildi.

### Son commitler

- `b2e627ba2495bbdf353ae9a87f72ece418f63d17`
  - Editor Preview `float()` hatası düzeltildi.
- `7f9494ff471a755b78f5e7ed0130d8e0bb99a422`
  - Runtime terrain tarafındaki aynı `float()` hatası düzeltildi.

### Önemli
Kullanıcı **bu iki committen sonra henüz yeni ekran görüntüsü/test sonucu göndermedi**.

Yeni sohbette ilk yapılacak şey:

```powershell
git pull
```

Godot'u tamamen kapatıp tekrar aç.

Sonra:
`scenes/world_editor_preview.tscn`

sahnesini aç.

Beklenen:
- `Nonexistent 'float' constructor` hatası artık çıkmamalı.
- Output'ta:
  `VERIFIED CANYON OK: 18 parca / 55904 byte / SHA256=OK / 965x722`
  görünmeli.
- Kanyon 2B editörde görünmeli.

---

## Kanyon görünür hale gelince yapılacak iş

İlk hedef **kanyonun sadece konum/ölçek/kompozisyonunu düzeltmek**.

Kullanıcının beklentisi:
- Tekrar eden 6 kaya kesinlikle geri gelmeyecek.
- Terrain doğal bir **tek parça / geniş kara-kanyon yapısı** gibi görünmeli.
- Tahmini koordinat kullanılmamalı.
- `Water` genişliği ve gerçek hook depth px/metre hesabıyla matematiksel oturtulmalı.
- Editor Preview ile runtime aynı yerleşimi göstermeli.

Kanyon onaylanmadan yosun/mercan gibi dekorlara geçme.

---

## Yosunların durumu

Daha önce `shallow_kelp_01.png` büyük kaya yüzeylerine alpha-mask ile bağlanmıştı.

Yapılanlar:
- Havada duran yosun fixlendi.
- Yosun kökü gerçek kaya alpha yüzeyine kilitlendi.
- Tepeye “mum gibi” tek yosun koyma sistemi kaldırıldı.
- Her kayada 4–5 yosun cluster denendi.
- Çakışma kontrolü ve koyu mavi-yeşil renk yapıldı.
- Kaya PNG'sinin kendi bitkilerinin üstüne ek yosun gelmesini engellemek için `kelp_rock_contact_guard.gd` eklendi.

Ancak bu yosun sistemi **eski tekrar eden kaya/spire sistemine göre yapılmıştı**.

Dolayısıyla:
- Yeni sağlam canyon görünümü onaylandıktan sonra
- yosunlar bu yeni gerçek kanyon yüzeyine yeniden adapte edilmeli.

Şimdilik yosunları kanyona zorla yerleştirme.

---

## Editor Preview dosyaları

Başlıca dosyalar:

- `scenes/world_editor_preview.tscn`
- `scenes/editor_environment_preview.gd`
- `scenes/canyon_texture_loader.gd`
- `scenes/underwater_terrain_runtime.gd`

Preview sahnesi sadece editör kontrolü içindir.  
Normal oyun `world.tscn` üzerinden devam eder.

---

## Çalışma kuralı

- Branch: **`eski`**
- Büyük değişiklik olmadıkça yeni branch açma.
- Yeni branch gerekiyorsa önce Miraç'a sor.
- Dosya değişikliklerini mümkün olduğunca doğrudan GitHub'a işle.
- Kullanıcıdan gereksiz manuel iş isteme.
- Godot kod değişikliklerinde gerekirse tam final dosyayı kullan.
- Görsel yerleşimlerinde tahmini koordinat kullanma; koddan/texture'dan matematiksel hesapla.
- Her tamamlanan işten sonra kısa durum raporu ver.
- Kullanıcı açıkça istemedikçe Work moduna geçme.

---

# Yeni sohbet için tek cümlelik başlangıç

**`eski` branch'te son commitler `b2e627b` ve `7f9494f`; verified V15 canyon texture 55904 byte + SHA256 OK olarak decode oluyor, float constructor hatası iki tarafta da fixlendi; ilk iş `git pull` sonrası `world_editor_preview.tscn` içinde kanyonun artık hatasız görünüp görünmediğini kontrol etmek, sonra sadece kanyonun matematiksel konum/ölçeğini düzeltmek.**
