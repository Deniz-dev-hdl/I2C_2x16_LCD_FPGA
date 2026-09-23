# FPGA I2C LCD Projects

Bu çalışma, PCF8574 I2C dönüştürücüye sahip 16x2 HD44780 LCD ekranı FPGA üzerinden kontrol etmek için hazırlanmış iki SystemVerilog projesinden oluşmaktadır.

Projeler 27 MHz sistem saati, 400 kHz I2C frekansı ve `0x27` LCD adresi için yapılandırılmıştır. Bu değerler modül parametrelerinden değiştirilebilir.

## Proje 1: LCD Hello World

Bu projede LCD açılış sırasında başlatılır, 8-bit başlangıç durumundan 4-bit çalışma moduna geçirilir ve ekrana `Hello World` yazılır.

### Çalışma sırası

1. LCD güç açılış gecikmesi uygulanır.
2. `0x30` değeri üç kez gönderilir.
3. `0x20` gönderilerek 4-bit moda geçilir.
4. LCD iki satırlı çalışma için yapılandırılır.
5. Ekran temizlenir.
6. Ekran ve karakter gösterimi açılır.
7. `Hello World` yazılır.
8. İşlem tamamlandığında `o_lcd_done` aktif olur.

### Dosyalar

```text
FPGA_TOP.sv
I2C_LCD_CONTROLLER.sv
I2C_LCD_DRIVER.sv
DELAY_20US_R.sv
I2C_MASTER.vhd
```

### Modül yapısı

```text
FPGA_TOP
└── I2C_LCD_CONTROLLER
    ├── I2C_LCD_DRIVER
    │   └── I2C_MASTER
    └── DELAY_20US_R
```

## Proje 2: UART LCD Terminal

Bu projede bilgisayardan UART üzerinden alınan karakterler FPGA tarafından I2C LCD ekrana yazılır. Gelen karakterler önce FIFO bellekte saklanır ve LCD hazır olduğunda sırayla işlenir.

### Özellikler

* 115200 baud UART alıcısı
* 8 data biti, parite yok, 1 stop biti
* 32 karakterlik FIFO
* Otomatik satır geçişi
* Carriage return desteği
* Line feed desteği
* Backspace desteği
* Ekran temizleme komutu
* I2C ACK hata çıkışı
* FIFO taşma çıkışı

### Kontrol karakterleri

| Karakter        |    Hex | İşlem                                  |
| --------------- | -----: | -------------------------------------- |
| Carriage return | `0x0D` | Mevcut satırın başına gider            |
| Line feed       | `0x0A` | Diğer satıra geçer                     |
| Backspace       | `0x08` | Cursor konumunu bir karakter geri alır |
| Form feed       | `0x0C` | Ekranı temizler                        |

### Dosyalar

```text
FPGA_TOP.sv
LCD_UART_TERMINAL.sv
UART_RX.sv
BYTE_FIFO.sv
I2C_LCD_DRIVER.sv
DELAY_20US_R.sv
I2C_MASTER.vhd
```

### Modül yapısı

```text
FPGA_TOP
└── LCD_UART_TERMINAL
    ├── UART_RX
    ├── BYTE_FIFO
    ├── I2C_LCD_DRIVER
    │   └── I2C_MASTER
    └── DELAY_20US_R
```

## Donanım bağlantıları

| FPGA sinyali      | Bağlantı                     |
| ----------------- | ---------------------------- |
| `i_clk`           | 27 MHz sistem saati          |
| `i_rst_n`         | Aktif-düşük reset            |
| `i_uart_rx`       | USB-UART TX çıkışı           |
| `io_sda`          | PCF8574 SDA                  |
| `io_scl`          | PCF8574 SCL                  |
| `o_ack_error`     | İsteğe bağlı hata LED'i      |
| `o_uart_overflow` | İsteğe bağlı FIFO hata LED'i |

USB-UART ve FPGA toprak bağlantıları ortak olmalıdır.

SDA ve SCL hatları open-drain olarak kullanılmalıdır. LCD kartındaki pull-up dirençleri 5 V seviyesine bağlıysa, FPGA pinlerinin gerilim sınırları kontrol edilmeli veya uygun bir I2C seviye dönüştürücü kullanılmalıdır.

## Parametreler

```systemverilog
parameter integer P_CLOCK_FREQ = 27_000_000;
parameter integer P_I2C_FREQ = 400_000;
parameter integer P_UART_BAUD_RATE = 115_200;
parameter logic [6:0] P_I2C_LCD_ADDRESS = 7'h27;
```

Farklı bir FPGA kartı veya LCD backpack kullanıldığında bu değerler değiştirilmelidir.

## UART terminal ayarları

```text
Baud rate: 115200
Data bits: 8
Parity: None
Stop bits: 1
Flow control: None
```

Python, PuTTY, Tera Term, minicom veya başka bir seri terminal programı kullanılabilir.

## Kullanım

1. Gerekli HDL dosyalarını FPGA projesine ekleyin.
2. `FPGA_TOP` modülünü top-level olarak seçin.
3. Clock, reset, UART, SDA ve SCL pinlerini tanımlayın.
4. Clock constraint değerini gerçek kart frekansına göre ayarlayın.
5. Projeyi sentezleyip FPGA üzerine yükleyin.
6. UART terminalini açın.
7. LCD hazır olduktan sonra metin gönderin.

## I2C veri düzeni

PCF8574 çıkış byte düzeni:

| Bit | LCD işlevi      |
| --: | --------------- |
| 7–4 | D7–D4           |
|   3 | Backlight       |
|   2 | Enable          |
|   1 | Read/Write      |
|   0 | Register Select |

Her nibble önce `Enable=1`, ardından aynı veriyle `Enable=0` olarak gönderilir. LCD veriyi Enable sinyalinin düşen kenarında kabul eder.

## Notlar

* Varsayılan I2C adresi `0x27` değeridir.
* Bazı PCF8574 kartlarında adres veya pin bağlantısı farklı olabilir.
* `ack_error` aktif olursa LCD adresi, bağlantılar, besleme ve pull-up dirençleri kontrol edilmelidir.
* UART FIFO taşarsa veri gönderme hızı azaltılmalı veya FIFO kapasitesi artırılmalıdır.
* HD44780 karakter tablosu standart UTF-8 karakterlerini doğrudan desteklemez.
* `i2c_master.vhd` modülü Digi-Key tarafından yayımlanan I2C master tasarımını temel almaktadır.
