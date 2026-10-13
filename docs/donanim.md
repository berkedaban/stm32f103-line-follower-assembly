# Malzemeler ve bağlantılar

Bu tablo, [`line_follower.s`](../src/line_follower.s) içindeki ADC kanal ve L298N pin tanımlarını temel alır.

## Kullanılan malzemeler

- STM32F103C8T6 Blue Pill
- QTR-8A analog çizgi sensörü
- L298N çift H-köprü motor sürücüsü
- İki DC motor ve tekerlekler
- ST-Link programlayıcı
- Robot şasisi, bağlantı kabloları ve motorlara uygun harici besleme

## QTR-8A → Blue Pill

| QTR-8A | STM32F103C8T6 | ADC kanalı |
|---|---|---:|
| OUT1 / S1 | PA0 | ADC1 CH0 |
| OUT2 / S2 | PA1 | ADC1 CH1 |
| OUT3 / S3 | PA2 | ADC1 CH2 |
| OUT4 / S4 | PA3 | ADC1 CH3 |
| OUT5 / S5 | PA4 | ADC1 CH4 |
| OUT6 / S6 | PA5 | ADC1 CH5 |
| OUT7 / S7 | PA6 | ADC1 CH6 |
| OUT8 / S8 | PA7 | ADC1 CH7 |
| GND | GND | Ortak referans |
| VCC | 3.3 V önerilir | — |

QTR-8A'nın sekiz çıkışı analog gerilimdir ve 0–VCC aralığındadır. Sensörü 5 V ile beslerseniz çıkışlar STM32 ADC girişleri için yüksek olabilir. Sensörü 3.3 V ile besleyin veya her çıkışa uygun gerilim bölücü/seviye dönüştürücü ekleyin. Sadece kod ayarı yüksek giriş gerilimini güvenli hâle getirmez. [Pololu QTR-8A ürün sayfası](https://www.pololu.com/product/960), [ST STM32F103C8 ürün sayfası](https://www.st.com/en/microcontrollers-microprocessors/stm32f103c8.html).

## L298N → Blue Pill ve motorlar

| STM32 pini | L298N girişi | Kaynaktaki işlev |
|---|---|---|
| PB12 | IN1 | Sağ motor ileri |
| PB13 | IN2 | Sağ motor geri yön pini; kod normal sürüşte kullanmaz |
| PB14 | IN3 | Sol motor ileri |
| PB15 | IN4 | Sol motor geri yön pini; kod normal sürüşte kullanmaz |

Sağ motoru L298N'nin OUT1/OUT2 çıkışına, sol motoru OUT3/OUT4 çıkışına bağlayın. Karttaki `ENA` ve `ENB` jumper'ları takılı olmalı (veya enable girişleri lojik 1'e çekilmeli); kaynak dosya bu enable pinlerini sürmüyor. Motor beslemesini motorlarınızın gerilim/akım değerine göre seçin. STM32, L298N, sensör ve motor beslemesinin GND noktaları ortak olmalı.

Kod `MOTOR_RIGHT_FWD=PB12` ve `MOTOR_LEFT_FWD=PB14` kabul eder. Motorlar ters yöne dönerse motor kablolarını veya bu sabitleri değiştirip yönü yeniden kontrol edin. İlk denemede tekerlekleri yerden kaldırın.

## ST-Link SWD → Blue Pill

| ST-Link | Blue Pill |
|---|---|
| SWDIO | PA13 |
| SWCLK | PA14 |
| GND | GND |
| NRST (varsa) | NRST |
| VTref / 3.3 V referans | Kartın 3.3 V seviyesi |

ST-Link'in 3.3 V hattını karta güç vermek için kullanıp kullanmama kararını programlayıcının ve kartının güç düzenine göre verin; GND ortaklığını sağlayın. Normal uygulama açılışı için `BOOT0` düşük olmalı.

