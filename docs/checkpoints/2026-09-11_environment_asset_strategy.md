# TinyFisher — 36 Asset Devam Stratejisi

Tarih: 2026-09-11
Branch: `eski`

## Kaldığımız yer

36 assetlik çevre entegrasyonunda resmî sıra **7/36** seviyesinde.

Tamamlananlar:
1. `sky_base_01.png`
2. `sun_01_TEMP.png`
3. `horizon_land_01.png`
4. `ocean_surface_base_01.png`
5. `wave_back_01.png`
6. `wave_front_01.png`
7. `surface_foam_01.png`

Yarın başlanacak asset:
8. `sun_rays_01.png`

Not: Kanyon sorununu çözmek için bazı kaya PNG'leri ayrıca runtime'da kullanıldı. Bunlar 36 assetlik sırada tamamlanmış sayılmayacak.

---

## Son karar — kaya, mercan ve diğer dekorların kullanımı

### Büyük kayalar

- Açık suya rastgele serpiştirilmeyecek.
- Ana harita/kanyonun yerini tutmayacak.
- Sadece mevcut kanyonun sağ/sol kenarlarında, taban geçişlerinde veya gerçekten boş kalan alanlarda destekleyici dekor olarak kullanılacak.
- Büyük kaya yerleşiminde RNG kullanılmayacak; konumlar elle ve sabit belirlenecek.
- Havada kalmayacak, tabana oturacak, birbirine girmeyecek.

Şimdilik 36 asset sırasında şu kaya assetleri atlanabilir:
- 9 `shallow_rock_01.png`
- 10 `shallow_rock_02.png`
- 14 `open_blue_rock_01.png`
- 15 `open_blue_rock_02.png`
- 19 `deep_sea_rock_01.png`
- 20 `deep_sea_rock_02.png`

Bunlar tamamen iptal değildir; ileride haritada ihtiyaç olan boşluklarda filler/destek asseti olarak kullanılabilir.

### Mercanlar

- Kullanılacak.
- Açık suda havada durmayacak.
- Mevcut kanyonun/deniz tabanının üzerine yapışık şekilde yerleştirilecek.
- Alt noktası terrain yüzeyine bağlanacak.
- Fazla yoğun kullanılmayacak.

### Kelp / yosun

- Kaya veya taban üzerindeki uygun yüzeylere yerleştirilecek.
- Hafif salınım animasyonu verilecek.
- Özellikle sığ bölgede suyu canlı göstermesi hedefleniyor.

### Batık, iskelet, çapa, mağara, harabe

- Tekrar tekrar spawn edilmeyecek.
- Haritada elle seçilmiş tekil landmark noktalarına yerleştirilecek.
- Örnek yaklaşım:
  - yaklaşık 35 m: küçük batık
  - yaklaşık 65 m: büyük enkaz / harabe
  - yaklaşık 85 m: büyük iskelet
  - yaklaşık 95 m: mağara / Abyss landmarkı
- Büyük landmarklar arasında yeterli yatay mesafe bırakılacak.

### Balık sürüsü / büyük balık gölgeleri / yaratık silüetleri

- Zemine bağlı olmak zorunda değiller.
- Background layer'da açık suda kullanılabilirler.
- Düşük kontrast ve düşük yoğunlukla ortam derinliği sağlayacaklar.

### Leviathan arena assetleri

- Sadece Leviathan/boss bölgesinde kullanılacak.
- Normal harita dekoru olarak dağıtılmayacak.

---

## RNG kuralı

- Büyük objelerde RNG kullanılmayacak.
- Büyük kaya, batık, mağara, iskelet, çapa ve harabeler elle yerleştirilecek.
- RNG yalnızca küçük parçacık, küçük yosun, küçük mercan gibi filler detaylarda kullanılabilir.
- Aynı asset yan yana tekrar etmeyecek.
- Oynanış/kanca/balık alanları dekorlarla kapatılmayacak.

---

## Yarın için önerilen sıra

İlk etapta kayalara yeniden dönmek yerine suyu canlılaştıracağız:

1. `sun_rays_01.png` — 8/36
2. `shallow_kelp_01.png`
3. `shallow_coral_01.png`
4. `shallow_fish_school_01_TEMP.png`
5. `open_blue_coral_01.png`
6. `open_blue_wreck_01.png`
7. `open_blue_large_fish_silhouette_01.png`
8. Sonra derin deniz landmark/silüet assetleri
9. Daha sonra Abyss landmarkları
10. En son Leviathan bölgesi assetleri

Ana hedef: haritayı kaya PNG'leriyle yamalı bohçaya çevirmek yerine mevcut kanyonun üstüne mantıklı, zemine bağlı ve bölgesel dekor eklemek.

---

## Yeni sohbette hatırlatılacak kısa özet

Kullanıcı yeni sohbette "dünkü son konuşmayı hatırla" veya benzeri bir şey derse:

- 36 asset entegrasyonunda **7/36'da kaldık**.
- Yarın **8/36 `sun_rays_01.png`** ile başlanacak.
- Büyük kaya assetleri açık suya rastgele konmayacak; şimdilik sıra içinde atlanabilir ve sadece ihtiyaç olan taban/kanyon kenarlarında kullanılacak.
- Mercan ve kelp mevcut terrain/kanyon yüzeyine yapışık yerleştirilecek; havada kalmayacak.
- Batık, iskelet, çapa, mağara ve harabeler elle seçilmiş tekil landmark noktalarında kullanılacak.
- Büyük objelerde RNG yok; RNG sadece küçük filler detaylarda.
- Önerilen devam sırası: Sun Rays -> kelp -> mercan -> balık sürüsü -> batık -> silüetler -> landmarklar -> Abyss -> Leviathan arena.
