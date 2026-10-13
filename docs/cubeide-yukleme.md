# STM32CubeIDE'de derleme ve CubeProgrammer ile yükleme

Bu depo Assembly kaynak kodunu ve açıklama dosyalarını içerir. STM32CubeIDE'nin oluşturduğu startup/vector table ve linker script dosyaları, kullanıcının özgün proje klasörü paylaşılmadığı için depoda yoktur. En kolay yol, bu dosyayı mevcut STM32F103C8Tx projesine eklemektir.

## STM32CubeIDE

1. Mevcut STM32F103C8Tx projesini açın. Yeni proje oluşturuyorsanız bu MCU'yu seçin ve proje içinde uygun startup dosyası ile linker script bulunduğunu doğrulayın.
2. `src/line_follower.s` dosyasını proje kaynak klasörüne kopyalayın veya **File → Import → File System** ile içeri alın.
3. Dosyanın Assembly olarak derlendiğini kontrol edin. GNU ARM araç zinciri Cortex-M3 ve Thumb modunda olmalı: `-mcpu=cortex-m3 -mthumb`.
4. Bu kaynak `main` giriş noktası sağlar. Projenin startup dosyası `main` fonksiyonunu çağırmalı; linker script STM32F103C8'in Flash ve RAM bölgelerini tanımlamalı.
5. **Project → Build Project** ya da `Ctrl+B` kullanın. Hatalar varsa Console'daki ilk assembler/linker hatasını inceleyin.
6. Derleme başarılıysa proje `Debug` klasöründeki `<proje-adı>.elf` dosyasını kullanın.

### Saat kaynağını kontrol edin

Kod 8 MHz HSE kristali bekler ve PLL ile 72 MHz'e çıkar. HSE hazır olmazsa `hse_wait` içinde kalır. Kartınızdaki kristal farklıysa `RCC_CFGR` ayarını değiştirin; zamanlama döngülerini de yeniden hesaplayın.

## STM32CubeProgrammer ve ST-Link

1. ST-Link'i kartın `SWDIO (PA13)`, `SWCLK (PA14)` ve `GND` noktalarına bağlayın. Mümkünse `NRST` hattını da bağlayın.
2. Blue Pill üzerinde normal Flash'tan başlatmak için `BOOT0`'ı düşük konuma alın.
3. STM32CubeProgrammer'ı açıp bağlantı arayüzü olarak **ST-LINK**, protokol olarak **SWD** seçin ve **Connect**'e basın.
4. **Open file** ile CubeIDE'nin oluşturduğu `Debug/<proje-adı>.elf` dosyasını seçin.
5. **Download**'a basıp programlama tamamlanınca kartı resetleyin.

## İlk çalıştırma kontrolü

- Önce robotu bir stand üzerinde veya tekerlekleri yerden kesilmiş şekilde deneyin.
- Açılışta beş hızlı LED yanıp sönmesini gözlemleyin.
- Sabit LED sırasında sensör dizisini hem siyah çizgi hem açık zemin üzerinde hareket ettirin.
- Üç yavaş blink'ten sonra robotu piste bırakmak için 1,25 saniye bekleyin.
- Motor yönü veya sensör polaritesi tersse önce kablo eşleşmesini ve kaynak sabitlerini kontrol edin.

> Bu rehber kaynak dosyanın yapısını açıklar; gerçek motor, sensör, güç kaynağı ve ST-Link bağlantısı bu çalışma sırasında test edilmedi.

