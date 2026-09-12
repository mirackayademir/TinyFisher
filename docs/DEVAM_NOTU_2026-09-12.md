# TinyFisher — Devam Notu

**Tarih:** 2026-09-12  
**Branch:** `eski`  
**Amaç:** Yeni sohbette doğrudan gerçek Git durumundan devam etmek.

## KALDIĞIMIZ YER — GERÇEK EN GÜNCEL DURUM

Eski düşük çözünürlüklü canyon bırakıldı. Miraç'ın onayladığı yeni, şeffaf arka planlı HQ canyon final taban olarak kullanılacak.

Onaylanan canyon kaynak özellikleri:
- Kaynak çalışma adı: `canyon_q95.webp`
- Boyut: **1226×1283**
- Renk modu: **RGBA**
- Şeffaflık: **var**
- Binary boyutu: **481946 byte**
- Base64 uzunluğu: **642596 karakter**
- SHA-256: `b00865a0d42d6488159f9ecf4cbde30df86873d96036f6630d548ec68f429679`
- Beklenen final çıktı: `assets/environment/terrain/canyon_final_hq_transparent.png`

## GITHUB'DAKİ AKTARIM DURUMU

Final görsel büyük binary olduğu için WebP Base64 verisi `assets/environment/terrain/runtime_data_final/` içine parça parça aktarılmaya başlanmıştı.

2026-09-12 kontrolünde `eski` branch'te mevcut geçici veri dosyaları:

### Canonical `part` dosyaları
- `canyon_final_q95_part00.txt` → `part08.txt`: 9 × 16000 byte
- `canyon_final_q95_part09.txt`: 15975 byte
- `canyon_final_q95_part10.txt`: 3985 byte

### Geçici `tail` dosyaları
- `canyon_final_q95_tail00.txt`: 27999 byte
- `canyon_final_q95_tail01.txt` → `tail07.txt`: 7 × 19999 byte

Repo dosya boyutlarına göre şu ana kadar taşınmış toplam Base64 veri:

**331952 / 642596 karakter = yaklaşık %51.66**

Eksik veri:

**310644 karakter**

Son veri commit'i:
- `3335064cc8994d506305067bcfa57e09dc7bb7cb`
- `Add final canyon data tail 07`

Bu nedenle final WebP şu an reconstruct edilemez. Eksik kaynak veri Git geçmişinde de bulunamadı; `canyon_final_hq_transparent.png` hiçbir eski committe mevcut değil.

## LOADER DURUMU — ÖNCEKİ NOTTAN DAHA İLERİ

`scenes/canyon_texture_loader.gd` artık final reconstruction mantığına hazırlanmış durumda.

Loader:
- `PART_COUNT = 41`
- `EXPECTED_BASE64_LENGTH = 642596`
- `EXPECTED_RAW_BYTES = 481946`
- Beklenen SHA-256 = `b00865a0d42d6488159f9ecf4cbde30df86873d96036f6630d548ec68f429679`
- Kaynak format = WebP
- `part00` → `part40` isimlerini sırayla okumayı bekliyor
- uzunluk / byte / SHA doğrulaması yapıyor
- doğrulanmış buffer'ı WebP olarak decode ediyor

**Önemli:** Geçici `tail00..tail07` dosyaları loader tarafından okunmuyor. Bunlar yalnızca yarım kalmış veri aktarımının taşıma parçaları. Kaynak tamamlanınca veri tek stream olarak doğrulanmalı ve canonical `part00..part40` biçimine yeniden bölünmeli.

## EDITOR PREVIEW + RUNTIME

Kod tarafındaki bağlantı hazır:
- `scenes/canyon_texture_loader.gd`
- `scenes/editor_environment_preview.gd`
- `scenes/underwater_terrain_runtime.gd`

Editor Preview ve runtime aynı canyon loader'ını ve aynı aspect-lock / yaklaşık 5500 px dünya ölçeği matematiğini kullanıyor.

Dolayısıyla şu aşamada canyon kodunu yeniden tasarlamak gerekmiyor. Asıl blokaj eksik görsel verisi.

Kontrol sahnesi:
`res://scenes/world_editor_preview.tscn`

## 9/36 SHALLOW ROCK DURUMU

Küçük `shallow_rock_01` test kayaları yeni canyon ile pixel/detay seviyesi uyuşmadığı için kapalı kalacak.

- `ShallowRock01Runtime` autoload dışı.
- Final canyon haritaya düzgün oturmadan 9/36 veya sonraki environment asset yerleşimine geçme.

## DEVAM SIRASI

1. Miraç'ın onayladığı **aynı final canyon kaynak görselini** yeniden erişilebilir hale getir.
2. Kaynaktan WebP Q95 RGBA payload'ı yeniden üret veya eldeki veriyle birebir aynı SHA'yı doğrula.
3. Base64'ü temiz şekilde `part00..part40` olarak yeniden oluştur.
4. Toplam Base64 = **642596**, raw = **481946**, SHA-256 = **b00865a0...** doğrulansın.
5. Geçici `tailXX` taşıma dosyalarını ancak doğrulama tamamlandıktan sonra temizle.
6. `world_editor_preview.tscn` ile Editor Preview kontrolü yap.
7. F5 runtime'da aynı canyon konumu/ölçeğini doğrula.
8. Miraç ekran görüntüsüyle görsel sonucu onayladıktan sonra 36 environment asset yerleşimine devam et.

## KULLANICIYA GEREKEN TEK ŞEY

Kod veya Git işlemi isteme. Eksik payload GitHub'da veya File Library'de bulunamadığı için yalnızca onaylanan son HQ canyon görselinin yeniden sohbete yüklenmesi / erişilebilir hale gelmesi gerekiyor. Görsel geldiğinde tüm reconstruction + Git entegrasyonunu doğrudan tamamla.

## ÇALIŞMA KURALLARI

- Branch: **`eski`**
- Büyük değişiklik olmadıkça yeni branch açma.
- Yeni branch gerekiyorsa önce Miraç'a sor.
- Mümkün olan işleri doğrudan GitHub'a işle.
- Kullanıcıya gereksiz kod/Git işi yükleme.
- Godot tarafında tahmini yerleşim yerine texture/kod matematiğini kullan.
- Görsel kalitesini bozacak gereksiz upscale/downscale zinciri kurma.
- Her tamamlanan işten sonra kısa rapor ver.
- Kullanıcı açıkça istemedikçe Work moduna geçme.
