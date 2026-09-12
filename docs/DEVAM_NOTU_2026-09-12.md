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

## GITHUB'DAKİ AKTARIM DURUMU

Final görsel büyük binary olduğu için WebP Base64 verisi `assets/environment/terrain/runtime_data_final/` içine parça parça aktarılmaya başlanmıştı.

2026-09-12 kontrolünde `eski` branch'te mevcut geçici veri dosyaları:

### Canonical `part` dosyaları
- `canyon_final_q95_part00.txt` → `part08.txt`: 9 × 16000 karakter
- `canyon_final_q95_part09.txt`: 15975 karakter
- `canyon_final_q95_part10.txt`: 3985 karakter

### Geçici `tail` dosyaları
- `canyon_final_q95_tail00.txt`: 27999 karakter
- `canyon_final_q95_tail01.txt` → `tail07.txt`: 7 × 19999 karakter

Repo dosya boyutlarına göre taşınmış toplam Base64 veri:

**331952 / 642596 karakter = yaklaşık %51.66**

Eksik veri:

**310644 Base64 karakteri**

Son canyon veri commit'i:
- `3335064cc8994d506305067bcfa57e09dc7bb7cb`
- `Add final canyon data tail 07`

## BYTE-SEVİYESİ KURTARMA DENETİMİ

Mevcut parçalar ve commit diffləri ayrıca incelendi. Sonuç:

- Canonical kaynak RIFF header'ı doğru ve toplam WebP boyutunu **481946 byte** olarak bildiriyor.
- `VP8X` chunk mevcut.
- VP8X canvas ölçüsü doğrudan **1226×1283** olarak doğrulandı.
- VP8X alpha flag = `0x10`; yani kaynak şeffaflık kullanan extended WebP.
- `ALPH` chunk boyutu **109494 byte**.
- RIFF + VP8X + ALPH bölümü byte **109532**'de tamamen bitiyor.
- GitHub'a aktarılmış Base64 akışının decode edilebilir kısmı yaklaşık **248964 raw byte**'a karşılık geliyor.
- Böylece alpha katmanı tamamen mevcut olsa da akış, alpha'dan sonra gelen ana renk görüntüsü verisinin içinde kesiliyor.
- Eksik raw veri yaklaşık **232982 byte**.

**Sonuç:** Eksik bölüm yalnızca metadata / dosya sonu değildir; ana sıkıştırılmış görüntü bilgisinin büyük kısmıdır. Bu nedenle truncated WebP decoder kullanarak onaylanan görseli birebir geri kazanmak mümkün değildir. SHA-256 da eksik byte'ları tersine üretmek için kullanılamaz.

Git geçmişi, diğer branch'ler ve File Library ayrıca tarandı:
- `main` ve test branch'lerinde final payload yok.
- `tail08+` veya gizli devam commit'i yok.
- Onaylanan final canyon kaynak dosyası Git geçmişinde hiçbir zaman tam olarak commitlenmemiş.
- 2026-09-10 → 2026-09-12 File Library aramasında canyon/kara parçası/terrain kaynak görseli bulunmadı.
- Eski `runtime_data/canyon_20_100_*` verileri farklı bir WebP'ye ait; yeni HQ payload ile aynı değildir.

Bu nedenle mevcut eksik verinin üzerine uydurma byte yazmak veya bozuk 41 parça üretmek **yasak**. Kaynak birebir doğrulanmadan final data seti tamamlanmış kabul edilmeyecek.

## DETERMINISTIC BUILDER / VERIFIER EKLENDİ

Yeni araç:

`tools/canyon_final_builder.py`

Commit:
- `b1c65d28fa6097e9b57096553e19c36f53e88734`
- `Add deterministic final canyon chunk builder`

Araç final kaynağı kabul etmeden önce şunların **tamamını** doğrular:
- Raw boyut = `481946`
- SHA-256 = `b00865a0d42d6488159f9ecf4cbde30df86873d96036f6630d548ec68f429679`
- RIFF / WEBP container
- RIFF header toplam boyutu
- VP8X canvas = `1226×1283`
- VP8X alpha flag aktif
- Base64 toplam uzunluk = `642596`

Doğrulama başarılıysa araç:
1. Kaynağı Base64'e çevirir.
2. Tam **41 canonical parçaya** böler.
3. `part00..part39` = 16000 karakter üretir.
4. `part40` = 2596 karakter üretir.
5. Her parçanın text SHA-256 değerini manifest'e yazar.
6. Staging dizininde parçaları tekrar birleştirip kaynağın byte-for-byte aynısı olduğunu doğrular.
7. Yalnızca bütün doğrulamalar geçerse eski partial `part*` ve geçici `tail*` dosyalarını değiştirir.
8. `canyon_final_q95_manifest.json` üretir.
9. Son kez 41 parçayı yeniden okuyup full raw SHA / ölçü / alpha doğrulaması yapar.

Komutlar:

```bash
python tools/canyon_final_builder.py build /path/to/canyon_q95.webp
python tools/canyon_final_builder.py verify
```

Builder yanlış/benzer bir canyon'u kabul etmez. Böylece görsel yanlışlıkla değiştirilemez.

## LOADER DURUMU

`scenes/canyon_texture_loader.gd` final reconstruction sistemine hazır.

Loader:
- `PART_COUNT = 41`
- `CHUNK_BASE64_LENGTH = 16000`
- `EXPECTED_BASE64_LENGTH = 642596`
- `EXPECTED_RAW_BYTES = 481946`
- `EXPECTED_WIDTH = 1226`
- `EXPECTED_HEIGHT = 1283`
- Beklenen SHA-256 = `b00865a0d42d6488159f9ecf4cbde30df86873d96036f6630d548ec68f429679`
- `part00` → `part40` isimlerini sırayla okur.
- Her chunk uzunluğunu doğrular.
- Full Base64 uzunluğunu doğrular.
- Raw byte boyutunu doğrular.
- SHA-256 doğrular.
- WebP decode eder.
- 1226×1283 ölçüyü doğrular.
- Alpha kanalını ve görünür alpha alanını doğrular.

Editor Preview ve runtime aynı loader'ı kullanıyor.

## EDITOR PREVIEW + RUNTIME

Kod tarafındaki bağlantı hazır:
- `scenes/canyon_texture_loader.gd`
- `scenes/editor_environment_preview.gd`
- `scenes/underwater_terrain_runtime.gd`

Editor Preview ve runtime aynı canyon loader'ını ve aynı aspect-lock / yaklaşık 5500 px dünya ölçeği matematiğini kullanıyor.

Kontrol sahnesi:
`res://scenes/world_editor_preview.tscn`

Harita genişliğini final canyon görsel testi bitmeden değiştirme.

## 9/36 SHALLOW ROCK DURUMU

Küçük `shallow_rock_01` test kayaları yeni canyon ile pixel/detay seviyesi uyuşmadığı için kapalı kalacak.

- `ShallowRock01Runtime` autoload dışı.
- Final canyon haritaya düzgün oturmadan 9/36 veya sonraki environment asset yerleşimine geçme.

## DEVAM SIRASI

1. Miraç'ın onayladığı **aynı final canyon kaynak görselini / exact `canyon_q95.webp` dosyasını** yeniden erişilebilir hale getir.
2. `tools/canyon_final_builder.py build ...` ile exact source doğrulamasını çalıştır.
3. Araç 41 canonical parçayı + manifest'i atomik şekilde yeniden oluştursun.
4. `tools/canyon_final_builder.py verify` ile ikinci doğrulama yap.
5. Loader ile Editor Preview aç.
6. F5 runtime'da aynı canyon konumu/ölçeğini doğrula.
7. Miraç görsel sonucu onayladıktan sonra 36 environment asset sırasına geri dön.

## KULLANICIYA GEREKEN TEK ŞEY

Kod veya Git işlemi isteme. Eksik görüntü verisi hiçbir bağlı kaynaktan kurtarılamadığı için yalnızca onaylanan final HQ canyon kaynak görselinin yeniden erişilebilir olması gerekir. Kaynak geldiği anda builder + Git entegrasyonunu doğrudan tamamla.

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
