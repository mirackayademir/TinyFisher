# Tiny Fisher — dikey olta döngüsü

## Kaynak

Kanonik depo: https://github.com/mirackayademir/TinyFisher

7 Eylül 2026 kontrolünde GitHub API, deponun boş olduğunu bildirdi; mevcut bir commit veya dal içeriği yoktu. Bu çalışma, önceki konuşmaya eklenen `tiny-fisherv-2.rar` arşivindeki gerçek Godot projesinden devam eder. Yerel çalışma klasörünün `origin` adresi yukarıdaki depodur. GitHub'a gönderim yapılmadı.

## Açılış ve kontroller

Godot 4.7.2 ile `project.godot` dosyasını açıp F6 yerine F5 ile projeyi çalıştırın.

- A / D: tekneyi yatay hareket ettirir.
- Sağ tık veya S: oltayı bırakır; kurşun otomatik olarak dikey batar.
- Sol fare tuşunu basılı tutmak veya W: oltayı sarar.
- Balık temas ettiğinde mevcut mücadele çubuğu açılır. Fareyle yeşil alanı turuncu balık işaretinin üzerine getirin ve sol tuşu basılı tutun. A / D ile alanı hareket ettirmek de mümkündür.
- Mücadele çubuğu dolduğunda sararak balığı tekneye alın. Balık ancak tekneye ulaştığında envantere eklenir.
- Olta aşağıdayken tekne sabittir. Boş oltayı da tamamen topladığınızda hareket tekrar açılır.
- Envanter kapasitesi 8 balıktır. Dolu envanterle yeni atış yapılamaz.
- Soldaki limana yaklaşın, E ile yanaşın; Balıkları Sat / Denize Açıl düğmelerini kullanın.

## Gerçek proje yapısı

- `scenes/world.tscn` / `world.gd`: deniz, soldaki liman, satış, Boat, FishingSpot, HUD.
- `scenes/boat.tscn` / `boat.gd`: CharacterBody2D tekne, Hook, HookLine, Camera2D. Tekne hareket scripti korunmuştur.
- `scenes/hook.gd`: dikey bırakma/sarma, tek balık kilidi, mücadele sonrası teslim ve kamera takibi.
- `scenes/fish.tscn` / `fish.gd`: mevcut dört balık türü, yüzme, kancaya bağlanma.
- `scenes/fishing_spot.gd`: dört balığın korunması ve yeniden doğma.
- `scenes/hud.gd`: mevcut mücadele ve 8 balıklık envanter.

Kanca ve balık görsel/çarpışma koordinatları kök düğümleriyle hizalandı. Balıkların sahnedeki başlangıç konumu korundu. Balık yeniden doğarken devriye merkezi artık doğru konumdan kaydedilir. İp koordinatları teknenin yerel uzayında tutulur. Limandan çıkış sinyali bağlandı; olta aşağıdayken yanaşma engellendi. Arayüz dekorları olta tıklamalarını yutmaz. Yeni görsel varlık üretilmedi.

## Doğrulama

Godot 4.7.2 headless açılışı tamamlandı; aşağıdaki testte 20 kontrol geçti:

```text
godot --headless --path . --fixed-fps 60 --script res://tests/fishing_loop_test.gd
```

Kontroller: liman giriş/çıkışı, yatay hareket, sağ tık atışı, dikey düşüş, tekne kilidi, boş sarma, derinlik sınırı/kamera, gerçek Area2D teması, mücadele kilidi/kazanma, tek seferlik envanter teslimi, kapasite, satış, limanda atış engeli ve yeniden doğma merkezi.

Ortam kaynaklı kök sertifika deposu uyarısı çıktı; testler 0 hata ile tamamlandı. Görsel oynanış ve fare hissi elle doğrulanmadı.

## Sonraki elle kontrol

1. A/D ile açılın; sağ tıkla bırakın. İpin dik kaldığını ve kancanın kameradan çıkmadığını kontrol edin.
2. Boş oltayı sol tuşla toplayın; teknenin yeniden hareket ettiğini kontrol edin.
3. Balık takılınca fareyle mücadeleyi kazanın, yukarı çekin; envanter yalnızca bir artsın.
4. 8 balıkta yeni atışın engellendiğini kontrol edin; soldaki limanda E → satış → denize açıl akışını deneyin.
5. Farklı balık türlerinde mücadele hızını ve fare hassasiyetini değerlendirin.
