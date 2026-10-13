# STM32F103C8T6 Assembly Line Follower

STM32F103C8T6 (Blue Pill) üzerinde GNU Assembly ile çalışan, QTR-8A analog sensör dizisi ve L298N motor sürücüsü kullanan çizgi izleyen robot projesi.

> **Güvenlik:** QTR-8A çıkışları 0 V ile sensör besleme gerilimi arasında analog sinyaldir. Sensör 5 V ile beslenirse çıkış 5 V'a kadar çıkabilir. STM32'nin ADC pinlerine 3.3 V'tan yüksek gerilim vermeyin. Sensörü 3.3 V'ta çalıştırın veya uygun gerilim bölücü/seviye dönüştürücü kullanın. Pololu, QTR-8A için 3.3–5.0 V besleme aralığı ve 0–VCC analog çıkış belirtir; STM32F103 çalışma/besleme aralığı 2.0–3.6 V'tur. Kaynaklar: [Pololu QTR-8A](https://www.pololu.com/product/960), [ST STM32F103C8](https://www.st.com/en/microcontrollers-microprocessors/stm32f103c8.html).

## Donanım

| Parça | Kullanımı |
|---|---|
| STM32F103C8T6 (Blue Pill) | Kontrolcü; kod 72 MHz HSE + PLL ayarı yapar |
| QTR-8A | Sekiz analog yansıtma sensörü; çıkışlar PA0–PA7 / ADC1 CH0–CH7 |
| L298N | İki DC motoru sürer; girişler PB12–PB15 |
| 2 DC motor | Sol ve sağ tekerlekler |
| ST-Link | SWD üzerinden programlama ve hata ayıklama |
| Uygun motor beslemesi, kablo ve şasi | Motorları ve sensör dizisini taşır |

Bağlantıların tam tablosu için [donanım ve bağlantılar](docs/donanim.md) sayfasına bakın.

## Çalıştırma sırası

1. Robotu açınca kart üzerindeki LED beş kez hızlı yanıp söner.
2. LED sabit yanarken sensör dizisini yaklaşık 5 saniye boyunca hem açık renkli zemin hem de siyah çizgi üzerinde gezdirin.
3. LED üç kez yavaş yanıp sönünce kalibrasyon tamamlanır.
4. Robotu piste koymak için yaklaşık 1,25 saniye bekleyin; sonra motorlar devreye girer.

Kalibrasyonda sensörleri hem siyahı hem açık zemini görecek şekilde hareket ettirin. Tekerlekleri ilk denemede yerden kaldırın; yön ve motor eşleşmesini güvenli biçimde kontrol edin.

## Algoritma

- Her döngüde sekiz ADC kanalı okunur ve kalibrasyon min/max değerleriyle 0–1000 aralığına ölçeklenir.
- Sensör değerleri soldan sağa `-3500` ile `+3500` arasında ağırlıklandırılır.
- Hata değerine basit yumuşatma uygulanır; `TURN_THRESHOLD` üstünde sağa, altında sola yönelir, aradaysa düz gider.
- Bu bir **Bang-Bang kontrolüdür; PID değildir**. Hız, zamanlayıcı PWM yerine Assembly içindeki kısa yazılımsal açık/kapalı darbeleriyle ayarlanır.
- Çizgi kaybolursa son bilinen yön hatası kullanılır.

Kodun bölümlerini ve ayarlarını [Assembly kod açıklaması](docs/kod-aciklamasi.md) içinde adım adım anlattım.

## STM32CubeIDE ile derleme ve ST-Link ile yükleme

1. STM32CubeIDE'de `STM32F103C8Tx` için bir proje açın. Projede cihazın startup dosyası ve linker script'i bulunmalı.
2. [`src/line_follower.s`](src/line_follower.s) dosyasını projenin kaynaklarına ekleyin (ör. `Core/Src`).
3. Assembly derleyici ayarlarının Cortex-M3 ve Thumb kullandığını doğrulayın: `-mcpu=cortex-m3 -mthumb`.
4. **Project → Build Project** veya `Ctrl+B` ile derleyin. Başarılı derleme sonunda `Debug/<proje-adı>.elf` oluşur.
5. ST-Link'i SWDIO, SWCLK ve GND hatlarıyla Blue Pill'e bağlayın; normal Flash açılışı için `BOOT0` düşük olmalı.
6. STM32CubeProgrammer'da **ST-LINK / SWD** seçip bağlanın, `Debug/<proje-adı>.elf` dosyasını açın ve **Download**'a basın.

Ekran adımları, bağlantı ve sorun giderme notları için [CubeIDE ve yükleme rehberi](docs/cubeide-yukleme.md) sayfasına bakın.

### Saat kaynağı gereksinimi

Kaynak kod, harici 8 MHz HSE kristalinden PLL ×9 ile 72 MHz ayarlar. HSE hazır olmazsa `hse_wait` döngüsünde bekler. Farklı kristal veya kart kullanıyorsanız saat ayarını ve zamanlama sabitlerini gözden geçirin.

## Dosya yapısı

```text
src/line_follower.s       Assembly kaynak kodu
docs/donanim.md           Malzemeler ve pin bağlantıları
docs/kod-aciklamasi.md    Algoritma ve ayarların açıklaması
docs/cubeide-yukleme.md   CubeIDE derleme ve CubeProgrammer adımları
```

Bu depoda Assembly kaynak dosyası ve rehberler bulunur; STM32CubeIDE'nin ürettiği startup/linker dosyaları projeye eklenmemiştir. Gerçek robot ve motor bağlantısı olmadan bu kopyayı donanım üzerinde doğrulayamıyorum; ilk çalıştırmayı tekerlekler boştayken ve bağlantıları kontrol ederek yapın.

## English

An STM32F103C8T6 (Blue Pill) line-following robot example written in GNU Assembly. It reads eight analog QTR-8A outputs through ADC1, drives two DC motors through an L298N, calibrates sensor min/max values at startup, and uses smoothed Bang-Bang steering (no PID). See the Turkish guides in [`docs/`](docs/) for wiring, code walkthrough, and STM32CubeIDE/ST-Link instructions.

**Voltage note:** QTR-8A analog outputs range from 0 V to VCC. Keep every STM32 ADC input at or below 3.3 V; use 3.3 V sensor power or suitable level conversion.

