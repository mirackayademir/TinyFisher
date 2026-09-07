# TinyFisher — Checkpoint 2026-09-08

## Aktif branch

`eski`

Büyük bir değişiklik gerekmedikçe yeni branch açılmayacak. Yeni branch gerekirse önce Miraç'a sorulacak.

## Projenin mevcut yönü

TinyFisher, **Cat Goes Fishing tarzı yatay tekne + dikey olta** yapısında ilerliyor.

Ana döngü:

- Tekne A / D ile yatay hareket eder.
- Sağ tık veya S ile olta dikey olarak denize bırakılır.
- Sol tık basılı veya W ile olta sarılır.
- Balık kancaya geldiğinde mücadele sistemi devreye girer.
- Balık tekneye kadar çekildiğinde envantere alınır.
- Limanda balık satılır ve geliştirmeler satın alınır.

## Çalışan sistemler

- Tekne hareketi
- Dikey olta bırakma ve sarma
- Kamera / derinlik takibi
- Balık spawn ve yeniden doğma
- Balığın kancaya bağlanması
- Balık mücadele sistemi
- Envanter ve kapasite
- Limana yanaşma
- Balık satışı / para
- Liman geliştirme menüsü

### Liman geliştirmeleri

- Motor Gücü — tekne hızı
- Makara Hızı — olta sarma hızı
- Tekne Ambarı — envanter kapasitesi
- Mücadele Desteği — balık mücadelesini kolaylaştırma

Her geliştirme 5 seviyelidir.

## Görsel yön — KANONİK KARAR

Bundan sonra oyun görselleri **birebir pixel-art tarzında** kullanılacak.

Onaylanan turkuaz/krem pixel-art tekne ve turkuaz çatılı pixel-art liman projeye bağlandı. Geçici SVG taklitleri final görsel olarak kullanılmayacak.

## 2026-09-08 görsel/fizik güncellemesi

- Gökyüzü gün batımı paletine geçirildi; pixel-art renk bantları, güneş ve ufuk bulutları eklendi.
- Deniz için animasyonlu shader eklendi: dalgalar, yüzey köpükleri, gün batımı yansıması ve su altı ışık kırılmaları hareket ediyor.
- Balıkların su altında görünmesi için mavi/derinlik tonu ve hafif ışık parlaması eklendi.
- Balık hareketi yenilendi: dikey yüzüş, daha küçük gövde salınımı, dönüş animasyonu ve shader ile kuyruk esnemesi var.
- Tekne su üstünde hafif dalga hareketi yapıyor.
- Tekne hareket ederken arkasından pixel köpük parçacıkları çıkıyor.
- Teknenin limanın içine gereğinden fazla girmesi engellendi; sol hareket sınırı yanaşma/yükseltme alanını açık bırakıyor.
- Liman görseli biraz büyütülüp konumu ayarlandı.
- Balık tekneye alındığında ortada **YAKALADIN!** popup'ı açılıyor; yakalanan balık görseli parlayıp kısa animasyon oynatıyor.

Yeni dosyalar:

- `shaders/sunset_sky.gdshader`
- `shaders/ocean.gdshader`
- `shaders/fish_underwater.gdshader`
- `assets/foam_particle.svg`

Ana değişen dosyalar:

- `scenes/world.tscn`
- `scenes/boat.tscn`
- `scenes/boat.gd`
- `scenes/fish.tscn`
- `scenes/fish.gd`
- `scenes/hud.gd`

## Önemli çalışma kuralı

KISS uygulanacak. Gereksiz araştırma, gereksiz dosya üretimi ve işi uzatan ara adımlar yapılmayacak.

Bir görev tamamlandığında kısa rapor verilecek:

- Ne yapıldı
- GitHub'a işlendi mi
- Bir sonraki net adım ne

Kullanıcı müdahalesi gerçekten gerekmedikçe iş kullanıcıya geri görev olarak verilmeyecek.

## Sonraki kontrol noktası

Oyunu çalıştırıp özellikle şu dört şeyi kontrol et:

1. Tekne limanın içine geçiyor mu, yoksa yanaşma bölgesinde duruyor mu?
2. Deniz dalgası / köpük / gün batımı görünümü sahnede düzgün mü?
3. Balık kuyruk hareketi doğal mı?
4. Balığı tekneye çekince `YAKALADIN!` efekti düzgün açılıyor mu?

Bir hata görülürse doğrudan o hatadan devam edilecek.
