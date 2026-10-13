@ =============================================================================
@ STM32F103C8T6 - QTR-8A Çizgi Takip Robotu
@ Safety: QTR-8A outputs range from 0 V to VCC. Keep PA0-PA7 input voltage at or below 3.3 V.
@ Kontrol: Basit Bang-Bang (PID YOK)
@ Hız    : Yazılımsal PWM (yön pinleri toggle)
@ Not    : L298N ENA/ENB pinleri jumperlı ya da lojik-1 olmalı; yoksa ilgili motor çalışmaz.
@ =============================================================================
@ KALIBRASYON:
@   1. Güç ver → 5 hızlı blink (kod çalışıyor onayı)
@   2. LED sabit yanar → ~5.6 sn boyunca sensörleri siyah/beyaz üzerinde gezdir
@   3. LED 3 kez yavaş blink → kalibrasyon bitti, robotu piste koy
@   4. 1.25 sn sessizlik → elleri çek
@   5. Robot hareket eder
@ =============================================================================

.syntax unified
.thumb
.section .text
.global main

@ =============================================================================
@ ADRES TANIMLARI
@ =============================================================================
.equ RCC_CR,      0x40021000
.equ RCC_CFGR,    0x40021004
.equ RCC_APB2ENR, 0x40021018
.equ RCC_APB1ENR, 0x4002101C
.equ FLASH_ACR,   0x40022000

.equ GPIOA_CRL,   0x40010800
.equ GPIOB_CRH,   0x40010C04
.equ GPIOB_ODR,   0x40010C0C
.equ GPIOC_CRH,   0x40011004
.equ GPIOC_ODR,   0x4001100C

.equ ADC1_SR,     0x40012400
.equ ADC1_CR2,    0x40012408
.equ ADC1_SMPR2,  0x40012410
.equ ADC1_SQR3,   0x40012434
.equ ADC1_DR,     0x4001244C

@ --- Motor Yön Pin Desenleri (GPIOB_ODR bit15:12) ---
@ L298N: IN1=PB12, IN2=PB13, IN3=PB14, IN4=PB15
@ Saha belirtisi: "sola dönmesi gerekirken sağa dönüyor, sadece sol teker çalışıyor"
@ Bu yüzden robot üzerindeki eşleşme PB14=SOL motor, PB12=SAĞ motor olarak ayarlandı.
@ Eğer motorlar kartta ters takılıysa sadece MOTOR_LEFT_FWD / MOTOR_RIGHT_FWD değerlerini değiştir.
.equ MOTOR_MASK,       0x0000F000
.equ MOTOR_RIGHT_FWD,  0x1000
.equ MOTOR_LEFT_FWD,   0x4000
.equ MOTORS_FWD,       0x5000
@ Dur: 0x0000

@ --- Çizgi polaritesi ---
@ 0: siyah çizgi ham ADC'de beyaz zeminden büyük (QTR-8A için yaygın durum)
@ 1: siyah çizgi ham ADC'de beyaz zeminden küçükse bunu 1 yap
.equ LINE_DARK_LOW, 0

@ --- Yazılımsal PWM Zamanlaması (72 MHz, 2 cycle/iter) ---
@ 1ms = 36,000 iterasyon
@ "Düz/yavaş": 2.0ms ileri + 5.0ms dur = ~%29 duty
@ "Dönüş"    : 0.5ms iki motor ileri + kısa dış motor düzeltme darbesi

@ --- Çizgi Kabul Eşiği ---
@ Normalize değer 0..1000. Gölgeyi çizgi sanmamak için sadece çok koyu siyah kabul edilir.
@ Gölge hâlâ çizgi gibi algılanırsa 750'ye çıkar; çizgiyi kaçırırsa 600'e indir.
.equ LINE_MIN_VALUE, 700

@ Kalibrasyonda bir sensörün min/max farkı bundan küçükse o sensör güvenilmez sayılır.
@ Böylece yalnızca gölge görmüş bir sensörün gölgeyi "siyah çizgi" diye öğrenmesi engellenir.
.equ CAL_MIN_RANGE, 120

@ --- Hata Eşiği ---
@ Ağırlıklı konum hatası [-3500, +3500] aralığında
@ Bu eşiğin altında → düz git, üstünde → dön
.equ TURN_THRESHOLD, 600

@ =============================================================================
@ MAIN
@ =============================================================================
.type main, %function
.thumb_func
main:
    @ Kalibrasyon dizilerini sıfırla/başlat (white=4095, black=0)
    ldr  r0, =white
    ldr  r1, =black
    ldr  r2, =4095
    mov  r3, #0
    mov  r4, #0
init_cal_loop:
    str  r2, [r0, r4, LSL #2]   @ white[r4] = 4095
    str  r3, [r1, r4, LSL #2]   @ black[r4] = 0
    add  r4, r4, #1
    cmp  r4, #8
    blt  init_cal_loop

    @ last_error değişkenini sıfırla
    ldr  r0, =last_error
    mov  r1, #0
    str  r1, [r0]


@ ============================================================
@ 0. SİSTEM SAATİ: 72 MHz (HSE + PLL x9)
@ STM32F103 varsayılan 8MHz HSI ile çalışır.
@ HSE kristal yoksa hse_wait'te takılır; o durumda bu bloğu
@ kaldır ve tüm timing sabitlerini 9'a böl.
@ ============================================================
    ldr  r0, =FLASH_ACR
    mov  r1, #0x12          @ PRFTBE=1, LATENCY=2 (72MHz için zorunlu)
    str  r1, [r0]

    ldr  r0, =RCC_CR
    ldr  r1, [r0]
    ldr  r2, =0x00010000    @ HSEON
    orr  r1, r1, r2
    str  r1, [r0]
hse_wait:
    ldr  r1, [r0]
    ldr  r2, =0x00020000    @ HSERDY
    tst  r1, r2
    beq  hse_wait

    ldr  r0, =RCC_CFGR
    ldr  r1, =0x001D8400    @ PLLMUL=x9, PLLSRC=HSE, APB1=/2, ADC=/6
    str  r1, [r0]

    ldr  r0, =RCC_CR
    ldr  r1, [r0]
    ldr  r2, =0x01000000    @ PLLON
    orr  r1, r1, r2
    str  r1, [r0]
pll_wait:
    ldr  r1, [r0]
    ldr  r2, =0x02000000    @ PLLRDY
    tst  r1, r2
    beq  pll_wait

    ldr  r0, =RCC_CFGR
    ldr  r1, [r0]
    orr  r1, r1, #0x02      @ SW=10 (PLL)
    str  r1, [r0]
sw_wait:
    ldr  r1, [r0]
    and  r2, r1, #0x0C
    cmp  r2, #0x08
    bne  sw_wait            @ Sistem saati PLL olana kadar bekle

@ ============================================================
@ 1. SAAT (CLOCK) ETKİNLEŞTİRME
@ ============================================================
    ldr  r0, =RCC_APB2ENR
    ldr  r1, [r0]
    ldr  r2, =0x021D        @ ADC1+GPIOC+GPIOB+GPIOA+AFIO
    orr  r1, r1, r2
    str  r1, [r0]

@ ============================================================
@ 2. GPIO YAPILANDIRMASI
@ ============================================================
    @ PA0-PA7: Analog Giriş
    ldr  r0, =GPIOA_CRL
    mov  r1, #0
    str  r1, [r0]

    @ PB12-PB15: Çıkış Push-Pull 50MHz (motor yön pinleri)
    ldr  r0, =GPIOB_CRH
    ldr  r1, [r0]
    ldr  r2, =0xFFFF0000
    bic  r1, r1, r2
    ldr  r2, =0x33330000
    orr  r1, r1, r2
    str  r1, [r0]

    @ Motorları DURDUR (tüm yön pinleri = 0)
    ldr  r0, =GPIOB_ODR
    ldr  r1, [r0]
    ldr  r2, =MOTOR_MASK
    bic  r1, r1, r2
    str  r1, [r0]

    @ PC13: Çıkış Push-Pull 50MHz (onboard LED, active-low)
    ldr  r0, =GPIOC_CRH
    ldr  r1, [r0]
    ldr  r2, =0x00F00000
    bic  r1, r1, r2
    ldr  r2, =0x00300000
    orr  r1, r1, r2
    str  r1, [r0]

@ ============================================================
@ 3. BAŞLANGIÇ İMZASI: 5 HIZLI BLİNK
@ Eğer bu blink olmazsa → kod çalışmıyor demektir.
@ ============================================================
    mov  r12, #5
sig_loop:
    ldr  r0, =GPIOC_ODR
    ldr  r1, [r0]
    bic  r1, r1, #0x2000    @ LED YAK
    str  r1, [r0]
    ldr  r2, =3600000       @ 100ms
sig_on_dly:
    subs r2, r2, #1
    bne  sig_on_dly
    ldr  r0, =GPIOC_ODR
    ldr  r1, [r0]
    orr  r1, r1, #0x2000    @ LED SÖNDÜR
    str  r1, [r0]
    ldr  r2, =3600000       @ 100ms
sig_off_dly:
    subs r2, r2, #1
    bne  sig_off_dly
    subs r12, r12, #1
    bne  sig_loop

@ ============================================================
@ 4. ADC BAŞLATMA VE KALİBRASYON
@ ============================================================
    ldr  r0, =ADC1_CR2
    ldr  r1, =0x001E0001    @ EXTTRIG=1, EXTSEL=111 (SWSTART), ADON=1
    str  r1, [r0]

    @ QTR-8A ve kablo/parazit toleransı için CH0-CH7 örnekleme süresini uzat.
    @ Varsayılan 1.5 cycle, analog sensörlerde kararsız/yanlış okumaya çok açıktır.
    ldr  r0, =ADC1_SMPR2
    ldr  r1, =0x00FFFFFF     @ SMP0..SMP7 = 111 (239.5 ADC cycle)
    str  r1, [r0]

    mov  r2, #200           @ Stabilizasyon gecikmesi
adc_stab:
    subs r2, r2, #1
    bne  adc_stab

    @ RSTCAL: Kalibrasyon register'larını sıfırla
    ldr  r1, =ADC1_CR2
    ldr  r2, [r1]
    orr  r2, r2, #8
    str  r2, [r1]
rstcal_wait:
    ldr  r2, [r1]
    tst  r2, #8
    bne  rstcal_wait

    @ CAL: Kalibrasyonu başlat
    ldr  r2, [r1]
    orr  r2, r2, #4
    str  r2, [r1]
cal_wait:
    ldr  r2, [r1]
    tst  r2, #4
    bne  cal_wait

@ ============================================================
@ 5. SENSÖR KALİBRASYONU (MIN/MAX)
@ LED sabit yanarken sensörleri çizgi ve zemin üzerinde gezdir.
@ white[] = kalibrasyon minimumu, black[] = kalibrasyon maksimumu olarak kullanılır.
@ ============================================================
    @ LED YAK
    ldr  r0, =GPIOC_ODR
    ldr  r1, [r0]
    bic  r1, r1, #0x2000
    str  r1, [r0]

    @ ~5 sn boyunca min/max topla. Bu, sensörler arası farkı ve ortam ışığını telafi eder.
    ldr  r10, =2048
cal_minmax_loop:
    mov  r4, #0
cal_minmax_inner:
    mov  r1, r4
    bl   read_adc_idx       @ r0 = ham değer

    @ minimumu güncelle
    ldr  r2, =white
    ldr  r3, [r2, r4, LSL #2]
    cmp  r0, r3
    it   lt
    strlt r0, [r2, r4, LSL #2]

    @ maksimumu güncelle
    ldr  r2, =black
    ldr  r3, [r2, r4, LSL #2]
    cmp  r0, r3
    it   gt
    strgt r0, [r2, r4, LSL #2]

    add  r4, r4, #1
    cmp  r4, #8
    blt  cal_minmax_inner

    ldr  r2, =90000         @ kullanıcı sensörü pist üzerinde gezdirebilsin
cal_sweep_delay:
    subs r2, r2, #1
    bne  cal_sweep_delay

    subs r10, r10, #1
    bne  cal_minmax_loop

    @ LED SÖNDÜR
    ldr  r0, =GPIOC_ODR
    ldr  r1, [r0]
    orr  r1, r1, #0x2000
    str  r1, [r0]

@ ============================================================
@ 6. KALİBRASYON BİTİŞ SİNYALİ
@ Motorlar DURGUN, 3 yavaş blink (500ms), sonra 1.25 sn bekleme.
@ Blink sürerken robot HAREKET ETMEZ.
@ ============================================================
    @ Motorlar STOP (güvence)
    ldr  r0, =GPIOB_ODR
    ldr  r1, [r0]
    ldr  r2, =MOTOR_MASK
    bic  r1, r1, r2
    str  r1, [r0]

    mov  r10, #3

cal_done_blink:
    ldr  r0, =GPIOC_ODR
    ldr  r1, [r0]
    bic  r1, r1, #0x2000    @ LED YAK
    str  r1, [r0]
    ldr  r2, =18000000      @ 500ms
blink_on:
    subs r2, r2, #1
    bne  blink_on
    ldr  r0, =GPIOC_ODR
    ldr  r1, [r0]
    orr  r1, r1, #0x2000    @ LED SÖNDÜR
    str  r1, [r0]
    ldr  r2, =18000000      @ 500ms
blink_off:
    subs r2, r2, #1
    bne  blink_off
    subs r10, r10, #1
    bne  cal_done_blink

    @ 1.25 sn dur — robotu piste yerleştir
    ldr  r2, =45000000
start_pause:
    subs r2, r2, #1
    bne  start_pause

@ ============================================================
@ 7. ANA DÖNGÜ — BASIT BANG-BANG KONTROLÜ
@ ============================================================
@ Algoritma:
@   - 8 sensör okunur, kalibre edilmiş [0,1000] aralığına normalize edilir
@   - Ağırlıklı konum: [-3500, +3500]
@   - Hata > +THRESHOLD → sağa yumuşak yay dönüşü
@   - Hata < -THRESHOLD → sola yumuşak yay dönüşü
@   - Aksi → yazılımsal PWM ile düz git (2.0ms ileri + 5.0ms dur)
@
@ Kayıtçı haritası:
@   r8 = ağırlıklı toplam
@   r9 = sensör toplam
@   r4 = sensör indeksi (geçici)
@ ============================================================

    @ Yön pinlerini ileri ayarla (PID loop başlamadan hemen önce)
    ldr  r0, =GPIOB_ODR
    ldr  r1, [r0]
    ldr  r2, =MOTOR_MASK
    bic  r1, r1, r2
    orr  r1, r1, #MOTORS_FWD
    str  r1, [r0]

main_loop:
    mov  r8, #0
    mov  r9, #0
    mov  r4, #0

read_sensors:
    mov  r1, r4
    bl   read_norm_val      @ r0 = normalize edilmiş değer [0, 1000]

    ldr  r6, =weights
    ldr  r6, [r6, r4, LSL #2]
    mla  r8, r0, r6, r8     @ weighted_sum += value * weight
    add  r9, r9, r0         @ total += value

    add  r4, r4, #1
    cmp  r4, #8
    blt  read_sensors

    @ Çizgi kayboldu mu? Gölge filtresi sonrası geçerli değer yoksa son yöne dön.
    cmp  r9, #100
    bge  calculate_error

    @ Çizgi kaybolduysa: Son bilinen hataya (last_error) göre dönmeye devam et
    ldr  r2, =last_error
    ldr  r0, [r2]
    b    decide_action

calculate_error:
    @ Konum hatası = ağırlıklı toplam / toplam
    mov  r0, r8
    mov  r1, r9
    bl   safe_div           @ r0 = yeni hata [-3500, +3500]

    @ Smoothing Filtresi (Alçak Geçiren Filtre):
    @ smoothed_error = (last_error * 3 + new_error) / 4
    ldr  r2, =last_error
    ldr  r3, [r2]
    mov  r4, #3
    mul  r3, r3, r4         @ last_error * 3
    add  r3, r3, r0         @ + new_error
    asr  r0, r3, #2         @ / 4 (smoothed value)
    str  r0, [r2]           @ last_error = smoothed_error

decide_action:
    @ Eşiğe göre karar
    ldr  r1, =TURN_THRESHOLD
    cmp  r0, r1
    bgt  do_right_turn      @ Hata pozitif → çizgi sağda → sağa dön

    neg  r1, r1
    cmp  r0, r1
    blt  do_left_turn       @ Hata negatif → çizgi solda → sola dön

    @ --------------------------------------------------------
    @ DÜZ GİT: 2.0ms ileri, 5.0ms dur (yazılımsal PWM ~%29)
    @ Motor gücü daha yumuşak verilir; sağ-sol salınım azalır.
    @ --------------------------------------------------------
do_straight:
    ldr  r0, =GPIOB_ODR
    ldr  r1, [r0]
    ldr  r2, =MOTOR_MASK
    bic  r1, r1, r2
    orr  r1, r1, #MOTORS_FWD @ Her iki motor ileri
    str  r1, [r0]
    ldr  r2, =72000         @ 2.0ms açık
fwd_on:
    subs r2, r2, #1
    bne  fwd_on

    ldr  r0, =GPIOB_ODR
    ldr  r1, [r0]
    ldr  r2, =MOTOR_MASK
    bic  r1, r1, r2         @ Dur
    str  r1, [r0]
    ldr  r2, =180000        @ 5.0ms kapalı
fwd_off:
    subs r2, r2, #1
    bne  fwd_off

    b    main_loop

    @ --------------------------------------------------------
    @ SOLA DÖN: Çok kısa iki motor ileri, sonra sağ motor düzeltme darbesi.
    @ Önceki güçlü takibi korur, başlangıç darbesi sert kırmayı biraz yumuşatır.
    @ --------------------------------------------------------
do_left_turn:
    ldr  r0, =GPIOB_ODR
    ldr  r1, [r0]
    ldr  r2, =MOTOR_MASK
    bic  r1, r1, r2
    orr  r1, r1, #MOTORS_FWD @ İki motor ileri
    str  r1, [r0]
    ldr  r2, =18000         @ 0.5ms iki motor açık
turn_l_both_on:
    subs r2, r2, #1
    bne  turn_l_both_on

    ldr  r0, =GPIOB_ODR
    ldr  r1, [r0]
    ldr  r2, =MOTOR_MASK
    bic  r1, r1, r2
    orr  r1, r1, #MOTOR_RIGHT_FWD @ Sadece sağ motor destek
    str  r1, [r0]
    ldr  r2, =54000         @ 1.5ms dış motor düzeltme
turn_l_outer_on:
    subs r2, r2, #1
    bne  turn_l_outer_on

    ldr  r0, =GPIOB_ODR
    ldr  r1, [r0]
    ldr  r2, =MOTOR_MASK
    bic  r1, r1, r2         @ Dur
    str  r1, [r0]
    ldr  r2, =180000        @ 5.0ms kapalı
turn_l_off:
    subs r2, r2, #1
    bne  turn_l_off

    b    main_loop

    @ --------------------------------------------------------
    @ SAĞA DÖN: Çok kısa iki motor ileri, sonra sol motor düzeltme darbesi.
    @ Önceki güçlü takibi korur, başlangıç darbesi sert kırmayı biraz yumuşatır.
    @ --------------------------------------------------------
do_right_turn:
    ldr  r0, =GPIOB_ODR
    ldr  r1, [r0]
    ldr  r2, =MOTOR_MASK
    bic  r1, r1, r2
    orr  r1, r1, #MOTORS_FWD @ İki motor ileri
    str  r1, [r0]
    ldr  r2, =18000         @ 0.5ms iki motor açık
turn_r_both_on:
    subs r2, r2, #1
    bne  turn_r_both_on

    ldr  r0, =GPIOB_ODR
    ldr  r1, [r0]
    ldr  r2, =MOTOR_MASK
    bic  r1, r1, r2
    orr  r1, r1, #MOTOR_LEFT_FWD @ Sadece sol motor destek
    str  r1, [r0]
    ldr  r2, =72000         @ 2.0ms sol motor düzeltme; zayıf teker için biraz güçlü ama yumuşak
turn_r_outer_on:
    subs r2, r2, #1
    bne  turn_r_outer_on

    ldr  r0, =GPIOB_ODR
    ldr  r1, [r0]
    ldr  r2, =MOTOR_MASK
    bic  r1, r1, r2         @ Dur
    str  r1, [r0]
    ldr  r2, =180000        @ 5.0ms kapalı
turn_r_off:
    subs r2, r2, #1
    bne  turn_r_off

    b    main_loop

@ =============================================================================
@ ALT PROGRAMLAR
@ =============================================================================

@ --- read_adc_idx: Sensör indeksine göre ADC oku ---
@ Giriş : r1 = sensör indeksi (0-7)
@ Çıkış : r0 = ham ADC değeri (0-4095)
.type read_adc_idx, %function
.thumb_func
read_adc_idx:
    push {r2, r3, lr}
    ldr  r2, =adc_channels
    ldrb r1, [r2, r1]       @ Fiziksel kanal numarasına çevir

    @ Kanalı seç
    ldr  r2, =ADC1_SQR3
    str  r1, [r2]

    @ EOC bayrağını temizle
    ldr  r2, =ADC1_SR
    mov  r3, #0
    str  r3, [r2]

    @ SWSTART ile dönüşümü tetikle
    ldr  r2, =ADC1_CR2
    ldr  r3, [r2]
    ldr  r0, =0x00500001    @ SWSTART|EXTTRIG|ADON
    orr  r3, r3, r0
    str  r3, [r2]

    @ EOC bekle (timeout korumalı)
    ldr  r2, =ADC1_SR
    ldr  r0, =10000         @ 10000 iterasyon timeout
wait_eoc:
    subs r0, r0, #1
    beq  eoc_timeout
    ldr  r3, [r2]
    tst  r3, #2
    beq  wait_eoc

    @ Sonucu oku
    ldr  r2, =ADC1_DR
    ldr  r0, [r2]
    pop  {r2, r3, pc}

eoc_timeout:
    mov  r0, #0             @ Motor gürültüsünden ADC kilitlenirse hang olmasın, 0 dön
    pop  {r2, r3, pc}

@ --- read_norm_val: Kalibre edilmiş normalize değer oku ---
@ Giriş : r1 = sensör indeksi (0-7)
@ Çıkış : r0 = normalize değer [0, 1000]
.type read_norm_val, %function
.thumb_func
read_norm_val:
    push {r1, r2, r3, r11, lr}

    mov  r11, r1
    bl   read_adc_idx       @ r0 = ham değer

    @ white[] = min_raw, black[] = max_raw
    ldr  r2, =white
    ldr  r3, [r2, r11, LSL #2] @ r3 = min_raw

    ldr  r2, =black
    ldr  r2, [r2, r11, LSL #2] @ r2 = max_raw

    @ Kalibrasyon aralığı çok darsa sensör güvenilmez sayılır.
    sub  r1, r2, r3
    ldr  r12, =CAL_MIN_RANGE
    cmp  r1, r12
    blt  rn_zero

.if LINE_DARK_LOW
    @ Siyah çizgi düşük ADC veriyorsa: value = (max_raw - raw) * 1000 / range
    cmp  r0, r3
    ble  rn_max
    cmp  r0, r2
    bge  rn_zero
    sub  r0, r2, r0
.else
    @ Siyah çizgi yüksek ADC veriyorsa: value = (raw - min_raw) * 1000 / range
    cmp  r0, r3
    ble  rn_zero
    cmp  r0, r2
    bge  rn_max
    sub  r0, r0, r3
.endif

    mov  r2, #1000
    mul  r0, r0, r2
    bl   safe_div

    @ Gürültü/Gölge Filtresi: Sadece zifiri siyaha yakın değerleri çizgi kabul et.
    ldr  r2, =LINE_MIN_VALUE
    cmp  r0, r2
    it   lt
    movlt r0, #0
    b    rn_end

rn_zero:
    mov  r0, #0
    b    rn_end

rn_max:
    mov  r0, #1000

rn_end:
    pop  {r1, r2, r3, r11, pc}

@ --- safe_div: İşaretli bölme ---
@ Giriş : r0 = bölünen, r1 = bölen
@ Çıkış : r0 = sonuç (bölen 0 ise 0 döner)
@ Not   : STM32F103/Cortex-M3'te SDIV yoktur; yazılımsal bölme kullanılır.
.type safe_div, %function
.thumb_func
safe_div:
    cmp  r1, #0
    beq  div_zero
    push {r4, lr}

    mov  r4, #0             @ sonuç işareti: 0=pozitif, 1=negatif
    cmp  r0, #0
    bge  div_num_abs_done
    rsb  r0, r0, #0
    eor  r4, r4, #1
div_num_abs_done:
    cmp  r1, #0
    bge  div_den_abs_done
    rsb  r1, r1, #0
    eor  r4, r4, #1
div_den_abs_done:
    mov  r2, #0             @ remainder
    mov  r3, #0             @ quotient
    mov  r12, #32

div_loop:
    lsls r0, r0, #1         @ dividend'in sıradaki bitini carry'ye al
    adcs r2, r2, r2         @ remainder = remainder * 2 + carry
    lsls r3, r3, #1         @ quotient <<= 1
    cmp  r2, r1
    blo  div_next
    sub  r2, r2, r1
    adds r3, r3, #1
div_next:
    subs r12, r12, #1
    bne  div_loop

    mov  r0, r3
    cmp  r4, #0
    beq  div_done
    rsb  r0, r0, #0
div_done:
    pop  {r4, pc}

div_zero:
    mov  r0, #0
    bx   lr

@ =============================================================================
@ VERİ BÖLÜMÜ (READ-ONLY - FLASH)
@ =============================================================================
.section .rodata
.align 2

@ ADC kanal haritası: sensör indeksi → fiziksel ADC kanalı
@ Seçenek A: PA0-PA7 (ADC CH0-CH7) — varsayılan
adc_channels:
    .byte 0, 1, 2, 3, 4, 5, 6, 7

.align 2
@ Konum ağırlıkları (sol=-3500, sağ=+3500)
weights:
    .word -3500, -2500, -1500, -500, 500, 1500, 2500, 3500

@ =============================================================================
@ RAM DEĞİŞKENLERİ (SENSÖR KALİBRASYON TAMPONLARI)
@ =============================================================================
.section .bss
.align 2
white:
    .space 32   @ 8 * 4 byte (white calibration minimums)
black:
    .space 32   @ 8 * 4 byte (black calibration maximums)
last_error:
    .space 4    @ 1 * 4 byte (last smoothed position error)




