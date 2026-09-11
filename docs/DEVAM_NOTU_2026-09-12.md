# TinyFisher — Devam Notu

**Tarih:** 2026-09-12  
**Branch:** `eski`  
**Amaç:** Yeni sohbette bu dosyadan doğrudan devam etmek.

## KALDIĞIMIZ YER — EN GÜNCEL DURUM

Eski düşük çözünürlüklü canyon görseli bırakıldı. Miraç yeni, şeffaf arka planlı canyon görselini onayladı ve bu görsel artık **final canyon tabanı** olarak kullanılacak.

Onaylanan yeni canyon özellikleri:
- Şeffaf arka plan / RGBA
- Kayalık + mercan + yosun detayları görselin kendi içinde mevcut
- Eski 965×722 V15 canyon aktif tasarımdan çıkarılacak
- Eklenen `shallow_rock_01` test kayaları şimdilik kapatıldı; yeni canyon tek başına temiz değerlendirilecek

## YENİ CANYON DOSYASI — REPOYA PARÇA PARÇA YÜKLEME

GitHub bağlantısı büyük binary görseli doğrudan rahat yükleyemediği için final canyon bir **WebP + Base64 chunk** sistemiyle repo içine aktarılıyor.

Aktif hazırlanan dosya:
- Yerel çalışma dosyası: `canyon_q95.webp`
- Boyut: **1226×1283**
- Renk modu: **RGBA**
- Şeffaflık: **VAR**
- Binary boyutu: **481946 byte**
- Base64 uzunluğu: **642596 karakter**
- SHA-256: `b00865a0d42d6488159f9ecf4cbde30df86873d96036f6630d548ec68f429679`

Chunk planı:
- Her parça: yaklaşık `16000` Base64 karakteri
- Toplam parça: **41 adet** (`part00` → `part40`)
- Repo klasörü:
  `assets/environment/terrain/runtime_data_final/`

### Şu ana kadar GitHub'a yüklenen final canyon parçaları

Aşağıdakiler mevcut:
- `canyon_final_q95_part00.txt`
- `canyon_final_q95_part01.txt`
- `canyon_final_q95_part02.txt`
- `canyon_final_q95_part03.txt`
- `canyon_final_q95_part04.txt`
- `canyon_final_q95_part05.txt`
- `canyon_final_q95_part06.txt`
- `canyon_final_q95_part07.txt`
- `canyon_final_q95_part08.txt`

**Yani 9 / 41 parça tamamlandı.**

Son branch ucu:
- `1ecb9dca6dcfad19a8988df7bd5c32b46498d87b`
- Commit mesajı: `Add final canyon data part 08`

### KALAN PARÇALAR

Yeni sohbette ilk büyük iş:

`part09` → `part40`

arasındaki **32 parçayı** aynı klasöre eklemek.

## LOADER DURUMU — ÖNEMLİ

`scenes/canyon_texture_loader.gd` şu an geçici olarak doğrudan şu dosyayı bekliyor:

`res://assets/environment/terrain/canyon_final_hq_transparent.png`

Bu **henüz final çalışma yöntemi değil**. PNG repo içinde mevcut olmadığı için bu haliyle loader final canyon'u açamaz.

### Yeni sohbette yapılacak loader işi

Tüm `part00..part40` yüklenince `canyon_texture_loader.gd` şu sisteme geçirilecek:

1. `runtime_data_final/canyon_final_q95_part00.txt` → `part40.txt` sırayla okunacak.
2. Base64 string tek parça halinde birleştirilecek.
3. Beklenen Base64 uzunluğu `642596` olarak doğrulanacak.
4. Decode edilen raw byte boyutu `481946` olarak doğrulanacak.
5. SHA-256 şu değerle doğrulanacak:
   `b00865a0d42d6488159f9ecf4cbde30df86873d96036f6630d548ec68f429679`
6. Godot buffer'dan WebP decode edecek.
7. Decode edilen texture **1226×1283 RGBA** olmalı.
8. Görselin alpha alanı korunacak.
9. Runtime'da ikinci kez resize/upscale yapılmayacak; mümkün olduğunca kaynak kalite korunacak.

Beklenen Output benzeri:

`FINAL CANYON VERIFIED: 41 parts / 481946 bytes / SHA256=OK / 1226x1283 RGBA`

## HARİTA / ÖLÇEK DURUMU

Mevcut dünya hâlâ yaklaşık **5500 px genişlik** düzeninde.

Daha önce 3600 px'e düşürme fikri konuşuldu ancak **henüz uygulanmadı**.

Yeni canyon entegrasyonu tamamlanmadan harita genişliğini tekrar değiştirme.

Doğru sıra:
1. Final canyon'u tamamen reconstruct et.
2. Editor Preview'da tek başına göster.
3. F5 runtime'da aynı görünümü göster.
4. Görüntünün kalite ve oranına bak.
5. Gerekirse **o zaman** dünya genişliği/derinlik ölçeği ayarla.

## 9/36 SHALLOW ROCK DURUMU

`shallow_rock_01` ile iki ayrı küçük kaya canyon üzerine eklenmişti.

Sorun:
- Eski canyon ile küçük kaya asset'i arasında çok büyük pixel/detay farkı vardı.
- Görsel yapıştırılmış gibi duruyordu.
- Konum düzeltmeleri bile kalite uyumsuzluğunu çözemedi.

Karar:
- Yeni canyon kendi kayalık detaylarını içerdiği için **9/36 küçük kaya testi şimdilik kapalı**.
- `project.godot` autoload içinden `ShallowRock01Runtime` çıkarıldı.
- Final canyon onaylanmadan 9/36 veya 10/36 asset yerleşimine devam etme.

## EDITOR PREVIEW

Kullanılacak kontrol sahnesi:

`res://scenes/world_editor_preview.tscn`

İlgili dosyalar:
- `scenes/editor_environment_preview.gd`
- `scenes/canyon_texture_loader.gd`
- `scenes/underwater_terrain_runtime.gd`

Editor Preview ve runtime **aynı texture loader ve aynı konum/ölçek hesabını** kullanmalı.

## ŞU AN KULLANICI NE YAPMALI?

**Şimdilik `git pull` çekip test isteme.**

Çünkü final canyon entegrasyonu henüz tamamlanmadı. Önce kalan veri parçaları + loader tamamlanmalı.

## YENİ SOHBETTE İLK YAPILACAKLAR

Sıra kesin olarak:

1. GitHub `eski` branch'i kontrol et; uç commit `1ecb9dca` veya bu notu kaydeden daha yeni commit olmalı.
2. `runtime_data_final` içinde `part00..part08` mevcut olduğunu doğrula.
3. `part09..part40` parçalarını GitHub'a ekle.
4. `canyon_texture_loader.gd` dosyasını final chunk reconstruction sistemine çevir.
5. `editor_environment_preview.gd` ve `underwater_terrain_runtime.gd` ile yeni canyon'un aynı matematikte kullanıldığını doğrula.
6. Küçük kaya 9/36 kapalı kalacak.
7. Sonra Miraç'a `git pull` yaptır ve `world_editor_preview.tscn` ekran görüntüsü iste.
8. Canyon haritaya kaliteli ve düzgün oturunca 36 environment asset sırasına geri dön.

## ÇALIŞMA KURALLARI

- Branch: **`eski`**
- Büyük değişiklik olmadıkça yeni branch açma.
- Yeni branch gerekiyorsa önce Miraç'a sor.
- Mümkün olan işleri doğrudan GitHub'a işle; kullanıcıya gereksiz görev verme.
- Godot tarafında tahmini yerleşim yerine texture/kod matematiğini kullan.
- Görsel kalitesini bozacak gereksiz upscale/downscale zinciri kurma.
- Her tamamlanan işten sonra kısa rapor ver.
- Kullanıcı açıkça istemedikçe Work moduna geçme.

---

# Yeni sohbet için tek cümlelik başlangıç

**`eski` branch'te yeni şeffaf final canyon için Q95 RGBA WebP Base64 parçaları yükleniyor; toplam 41 parçanın `part00..part08` kısmı GitHub'da, son uç `1ecb9dca`, sıradaki iş `part09..part40` yüklemek ve `canyon_texture_loader.gd`yi 642596 Base64 / 481946 byte / SHA256=b00865a0... doğrulamalı reconstruction sistemine geçirip Editor Preview + runtime'da final canyon'u test etmek; 9/36 küçük kaya şimdilik kapalı.**
