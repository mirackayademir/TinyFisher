# TinyFisher — Checkpoint 2026-09-08

## Aktif branch

`eski`

Büyük bir değişiklik gerekmedikçe yeni branch açılmayacak. Yeni branch gerekirse önce Miraç'a sorulacak.

## Projenin mevcut yönü

TinyFisher artık **Cat Goes Fishing tarzı yatay tekne + dikey olta** yapısında ilerliyor.

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

Yaklaşık SVG taklitleri, geçici sade çizimler veya görsele benzeyen yeniden çizimler final asset olarak kullanılmayacak. Onaylanan görsel neyse mümkün olduğunca **aynı görsel dosyası** oyuna aktarılacak.

Onaylanan iki ana görsel:

1. Turkuaz / krem renkli pixel-art balıkçı teknesi
2. Turkuaz çatılı pixel-art liman / iskele

Bu iki görsel GitHub üzerinden projeye aktarılmaya başlandı ve `git pull` sonrasında proje tarafında dosyalar görünür hale geldi.

### Görsel entegrasyonda sıradaki iş

- Onaylanan tekne görselini mevcut geçici `boat_approved.svg` yerine gerçek oyun görseli olarak bağlamak.
- Onaylanan liman görselini mevcut geçici `harbor_pixel.svg` yerine bağlamak.
- Tekne / liman ölçek ve konumlarını sahnede düzgün oturtmak.
- Mevcut oynanış sistemlerini bozmamak.
- Tekne üzerindeki olta ile gerçek atış animasyonunu eşleştirmek.
- Daha sonra UI / geliştirme ekranlarını da aynı pixel-art görsel diline geçirmek.

## Önemli çalışma kuralı

KISS uygulanacak. Gereksiz araştırma, gereksiz dosya üretimi ve işi uzatan ara adımlar yapılmayacak.

Bir görev tamamlandığında kısa rapor verilecek:

- Ne yapıldı
- GitHub'a işlendi mi
- Bir sonraki net adım ne

Kullanıcı müdahalesi gerçekten gerekmedikçe iş kullanıcıya geri görev olarak verilmeyecek.

## Yarın devam noktası

**İlk iş:** Tekne ve limanın onaylanan birebir pixel-art görsellerini sahnede aktif hale getirip eski geçici SVG görselleri devreden çıkarmak.

Ardından olta atma animasyonu ve pixel-art UI düzenlemesine devam edilecek.
