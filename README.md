# Basys 3 Test

Digilent Basys 3 kartını **bilgisayara program kurmadan** test etmek için hazır bir test dosyası.
Kart, dosyayı doğrudan bir USB bellekten yükler.

## 📥 [selftest.bit dosyasını indir](https://github.com/cinardoruk/basys3-selftest/raw/main/selftest.bit)

## Nasıl yapılır

Gerekenler: FAT32 biçimli bir USB bellek, micro-USB kablo (telefon şarj adaptörü veya
bilgisayarın USB portu yeterli), varsa bir VGA monitör.

1. USB belleğin **ana dizinine** sadece `selftest.bit` dosyasını kopyalayın
   (bellekte başka `.bit` dosyası olmasın).
2. Kart kapalıyken **JP1** jumperını **USB** konumuna alın
   (kart üzerinde `JP1` yazan, yanında `QSPI / JTAG / USB` yazan 3'lü jumper).
3. **JP2** (güç) jumperı **USB** konumunda olsun.
4. USB belleği kartın büyük **USB-A** girişine takın.
5. Micro-USB kabloyu takın ve **POWER** anahtarını açın.
   Birkaç saniye içinde **DONE** ledi yanar ve test kendiliğinden başlar.

## Videoda görünmesi gerekenler

| Ne yapılıyor | Ne görünmeli |
|---|---|
| Hiçbir anahtar açık değil | 16 LED sırayla tek tek yanar, sonra dolar, geri döner, hepsi yanıp söner. 7 segment ekranda her hanenin her segmenti (nokta dahil) tek tek yanar, ardından `8.8.8.8.` tamamen yanar. |
| 16 anahtarı tek tek açın | Her anahtar tam üstündeki LED'i yakar; ekranda anahtarların değeri onaltılık (hex) görünür. |
| 5 butona tek tek basın | Ekranda `C` / `U` / `L` / `r` / `d` harfi görünür. |
| VGA monitör bağlıysa | Üstte renkli çubuklar, altta kırmızı / yeşil / mavi / gri renk geçişleri. |

Test bitince JP1'i tekrar **QSPI** konumuna alabilirsiniz. Karttaki fabrika demosu
**silinmez**, kart eskisi gibi açılır.

## DONE ledi yanmazsa

1. Başka bir USB bellek deneyin (küçük / eski bellekler daha sorunsuz olur).
2. Yine olmazsa: kartı kapatın, JP1'i **QSPI** konumuna alın, USB belleği çıkarın ve
   kartı tekrar açın. Kart, fabrikadan gelen kendi demosunu çalıştırır:
   - Her anahtar üstündeki LED'i yakar.
   - 7 segment ekran 0'dan 9'a sayar; U / L / R / D butonları birer haneyi söndürür,
     C butonu tüm ekranı söndürür.
   - VGA monitörde hareketli desenler görünür.

   Bunu da videoya çekmeniz yeterli.

---

## English

Self-running hardware test for the Digilent Basys 3 (Artix-7 XC7A35T). Load
`selftest.bit` from a FAT32 USB stick (JP1 = USB) or over JTAG. It does not touch
the QSPI flash.

- **LEDs:** chase / fill / blink when all switches are off; mirror the switches otherwise
- **7-seg:** walks every segment of every digit, then `8.8.8.8.`; shows the switches as hex; shows C/U/L/r/d for the buttons
- **VGA 640×480@60:** colour bars and 16-step R/G/B/grey ramps (exercises all 12 DAC bits)
- **UART 9600 8N1:** prints `BASYS3 SELFTEST SW=xxxx BTN=CULRD` about once a second

Built with the open-source [openXC7](https://github.com/openXC7) toolchain
(yosys + nextpnr-xilinx). Run `./build.sh` (needs Docker). `fix_header.py` rewrites the
`.bit` header in Vivado's style (part `7a35tcpg236`), matching Digilent's own Vivado-built
demos; the configuration data is untouched.

**If the stick won't load it:** to tell a board/stick problem from a bitstream problem, try
Digilent's Vivado-built General I/O demo from the same stick. It's in the
[Basys-3-GPIO release zip](https://github.com/Digilent/Basys-3-GPIO/releases/download/v2018.2-3/Basys-3-GPIO-2018.2-3.zip)
at `vivado_proj/Basys-3-GPIO.runs/impl_1/GPIO_demo.bit`. (It isn't copied here because
that repo has no license.)

Status: logic verified in simulation (`tb.v`, Icarus Verilog) and pinout checked against
Digilent's `Basys-3-Master.xdc`; not yet run on real hardware.
