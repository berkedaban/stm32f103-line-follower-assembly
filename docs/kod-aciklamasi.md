# Assembly kod açıklaması

Kaynak: [`src/line_follower.s`](../src/line_follower.s)

## 1. Başlangıç ve saat ayarı

`main`, kalibrasyon için sekiz sensörün min dizisini 4095'e, max dizisini 0'a ve `last_error` değerini sıfıra hazırlar. Ardından Flash bekleme/ön getirme ayarını yapar, harici 8 MHz HSE'yi açar, PLL ×9 ile 72 MHz sistem saatini seçer. APB1 `/2`, ADC `/6` ayarları da `RCC_CFGR` değerinde yer alır. HSE hazır olmazsa kod `hse_wait` etiketinde bekler.

## 2. GPIO ve LED

- PA0–PA7 analog giriş olarak ayarlanır.
- PB12–PB15, L298N yön girişleri için çıkış yapılır.
- PC13, Blue Pill üzerindeki active-low LED olarak ayarlanır: biti sıfırlamak LED'i yakar.
- Başlangıçta beş hızlı LED yanıp sönmesi, kodun bu noktaya ulaştığını gösterir.

## 3. ADC ve sensör kalibrasyonu

ADC1 açılır; CH0–CH7 için uzun örnekleme süresi ayarlanır. `read_adc_idx`, sensör indeksini `adc_channels` tablosuyla fiziksel ADC kanalına dönüştürür, yazılımsal dönüşüm başlatır ve EOC bayrağını bekler. Bekleme için sınırlı timeout vardır.

LED sabit yanarken sensörlerin ham min/max değerleri toplanır. Bu sırada sensör dizisini açık zemin ve siyah çizgi üzerinden gezdirin. Kalibrasyondan sonra üç yavaş LED sinyali ve 1,25 saniyelik başlangıç beklemesi gelir.

## 4. Normalleştirme ve çizgi konumu

`read_norm_val`, her ham ADC değerini o sensörün ölçülen min/max aralığına göre 0–1000 değerine ölçekler. `CAL_MIN_RANGE` altındaki aralıklara sahip sensörler güvenilmez kabul edilir. `LINE_DARK_LOW` ham ADC polaritesini seçer; varsayılan `0`, siyah çizginin ADC değerinin beyaz zeminden yüksek olduğunu varsayar. `LINE_MIN_VALUE` altındaki değerler gürültü/gölge filtresi için sıfırlanır.

Ağırlıklar soldan sağa `-3500, -2500, …, +3500` değerleridir. Kod her sensörün normalleştirilmiş değerini ağırlığıyla çarpar, toplam sinyale böler ve çizginin sensör dizisi üzerindeki yaklaşık konum hatasını bulur. `safe_div`, Cortex-M3'te donanım `SDIV` komutuna güvenmeden işaretli bölme yapar.

## 5. Yön kararı ve motor darbeleri

`TURN_THRESHOLD` pozitifse sağa, negatif eşiğin altındaysa sola düzeltme yapılır; aradaki bölgede düz sürüş uygulanır. `last_error` ile yeni hata 3:1 oranında harmanlanarak ani yön değişiklikleri yumuşatılır. Sinyal kaybolduğunda son bilinen hata yönünde arama sürer.

Motorlar için kod zamanlama döngüleriyle açık/kapalı darbeler üretir. Düz gidişte yaklaşık 2 ms ileri ve 5 ms duraklama; dönüşlerde farklı süreli dış motor darbeleri kullanılır. Süreler 72 MHz varsayımına ve işlemci/assembler çevrimine bağlı yaklaşık değerlerdir. Bu, donanımsal timer PWM veya PID değildir.

## Ayarlanabilir sabitler

| Sabit | Etkisi |
|---|---|
| `LINE_DARK_LOW` | Siyah çizginin ham ADC polaritesi |
| `LINE_MIN_VALUE` | Gölge/gürültü filtresinin koyuluk eşiği |
| `CAL_MIN_RANGE` | Sensörün geçerli sayılması için gereken kalibrasyon farkı |
| `TURN_THRESHOLD` | Düz gitme ve dönüş arasındaki konum hata sınırı |
| `MOTOR_RIGHT_FWD`, `MOTOR_LEFT_FWD` | L298N giriş pinlerinin ileri yön eşleşmesi |
| `72000`, `180000`, `54000` gibi döngü sabitleri | Yaklaşık motor açık/kapalı darbe süreleri |

Önce sensör polaritesini ve motor yön eşleşmesini düşük hızda doğrulayın. Kalibrasyonda sensörlerin gerçekten hem siyah hem açık yüzey gördüğünden emin olun.

