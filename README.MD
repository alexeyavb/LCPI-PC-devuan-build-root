Hi! 
Normal linux for LCPI-PC-T113-F133

*For Allwinner ARM T133 board*

For RISCV Board use Tina Linux

No build root used !

It's a normal linux distribution without systemd (SystemV scripts used)

Worked:

    ttyS0 as sysconsole
    WiFi on rtl8189fs
    40pin LCD tcon (framebuffer, cedarve accel, v4lin codecs)
    cryptoaccel
    D1 HiFi Auidio Codec
Used:

    Linux kernel 6.6.71
    u-boot 2024.12
    devuan latest bassed on debian 12.7
Build time:

    1 hours on Xeon E5/64Gb Ram/SSD

READ INSTALL FOR BUILD STEPS
    Regards, Alexey.