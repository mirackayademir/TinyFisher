# TinyFisher — Environment Asset Status

Bu dosya, katmanlı çevre görsellerinin onay ve entegrasyon durumunu takip eder.

## Durumlar

- `APPROVED`: Görsel yönü kullanıcı tarafından onaylandı.
- `TEMP`: Geçici olarak kabul edildi; final turunda yeniden üretilecek.
- `PROMPT_READY`: Görsel üretim promptu hazır, henüz üretim onayı yok.
- `INTEGRATED`: Asset repo içinde ve Godot katmanına bağlı.

## Assetler

### 1. SkyBase
- Durum: `APPROVED`
- Hedef yol: `res://assets/environment/sky_base.*`
- Katman: `EnvironmentLayers/SkyParallax/SkyBaseLayer`
- Not: Mor/lacivertten turuncuya geçen dramatik pixel-art gün batımı. Güneş ve fiziksel ufuk öğeleri ayrı tutulacak.
- Entegrasyon: Binary görsel repo aktarımı bekliyor.

### 2. Sun
- Durum: `TEMP`
- Hedef yol: `res://assets/environment/sun_temp.*`
- Katman: `EnvironmentLayers/SkyParallax/SunLayer`
- Not: Mevcut üretilen güneş geçici kullanılabilir; final sürümde güneş diskinin içine bulut/gökyüzü dokusu girmeyecek. Final asset yalnızca saf pixel-art güneş + kontrollü halo olacak.
- Entegrasyon: Binary görsel repo aktarımı bekliyor.

### 3. HorizonLand
- Durum: `PROMPT_READY`
- Hedef yol: `res://assets/environment/horizon_land_01.*` ve varyantları
- Katman: `EnvironmentLayers/SkyParallax/HorizonLandLayer`
- Entegrasyon: Görsel üretim onayı bekliyor.

## Teknik not

Görseller tek birleşik arka plan olarak kullanılmayacak. Her asset ayrı katmanda, bağımsız parallax/animasyon/konum kontrolüyle çalışacak.
