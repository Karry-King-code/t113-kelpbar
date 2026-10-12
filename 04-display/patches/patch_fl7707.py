# 考核④显示: 注册fl7707n_mipi panel驱动五件套
# 1.Makefile加编译行 2.Kconfig加开关条目 3.panels.c挂数组 4.config-5.4开开关 5.board.dts换lcd0段(LVDS1024x600->FL7707 720x720 4lane)
import shutil

BASE = '/home/karry/T113-Tina5.0-V1.2/kernel/linux-5.4/drivers/video/fbdev/sunxi/disp2/disp/'
LCD = BASE + 'lcd/'
CFG = '/home/karry/T113-Tina5.0-V1.2/device/config/chips/t113/configs/evb1_auto_nand/linux-5.4/'

# ---- 1. Makefile ----
f = BASE + 'Makefile'
shutil.copy(f, f + '.bak-1008-fl7707')
t = open(f).read()
anchor = 'disp-$(CONFIG_LCD_SUPPORT_HE0801A068) += lcd/he0801a068.o'
assert anchor in t, 'Makefile anchor missing'
t = t.replace(anchor, anchor + '\ndisp-$(CONFIG_LCD_SUPPORT_FL7707N_MIPI) += lcd/fl7707n_mipi.o', 1)
open(f, 'w').write(t)
print('1/5 Makefile ok')

# ---- 2. Kconfig ----
f = LCD + 'Kconfig'
shutil.copy(f, f + '.bak-1008-fl7707')
t = open(f).read()
blk = ('config LCD_SUPPORT_HE0801A068\n'
       '\tbool "LCD support he0801a068 panel"\n'
       '\tdefault y\n'
       '\t---help---\n'
       '\t\tIf you want to support he0801a068 panel for display driver, select it.\n')
if blk not in t:
    i = t.index('config LCD_SUPPORT_HE0801A068')
    print('KCONFIG ACTUAL BLOCK:', repr(t[i:i + 260]))
    raise SystemExit('Kconfig anchor mismatch')
new = blk + ('\nconfig LCD_SUPPORT_FL7707N_MIPI\n'
             '\tbool "LCD support fl7707n_mipi panel"\n'
             '\tdefault n\n'
             '\t---help---\n'
             '\t\tIf you want to support fl7707n_mipi panel for display driver, select it.\n')
t = t.replace(blk, new, 1)
open(f, 'w').write(t)
print('2/5 Kconfig ok')

# ---- 3. panels.c ----
f = LCD + 'panels.c'
shutil.copy(f, f + '.bak-1008-fl7707')
t = open(f).read()
anc = '#ifdef CONFIG_LCD_SUPPORT_HE0801A068\n\t&he0801a068_panel,\n#endif\n'
assert anc in t, 'panels.c anchor missing'
t = t.replace(anc, anc + '#ifdef CONFIG_LCD_SUPPORT_FL7707N_MIPI\n\t&fl7707n_mipi_panel,\n#endif\n', 1)
open(f, 'w').write(t)
print('3/5 panels.c ok')

# ---- 4. config-5.4 ----
f = CFG + 'config-5.4'
shutil.copy(f, f + '.bak-1008-fl7707')
assert 'CONFIG_LCD_SUPPORT_FL7707N_MIPI' not in open(f).read()
open(f, 'a').write('\nCONFIG_LCD_SUPPORT_FL7707N_MIPI=y\n')
print('4/5 config-5.4 ok')

# ---- 5. board.dts 替换第一段 &lcd0 ----
f = CFG + 'board.dts'
shutil.copy(f, f + '.bak-1008-lcd')
t = open(f).read()
start = t.index('&lcd0 {')
end = t.index('\n};', start) + len('\n};')
old_seg = t[start:end]
assert 'default_lcd' in old_seg and '1024' in old_seg, 'first lcd0 segment mismatch: ' + old_seg[:120]
new_seg = '''&lcd0 {
	lcd_used            = <1>;

	lcd_driver_name     = "fl7707n_mipi";
	lcd_backlight       = <50>;
	lcd_if              = <4>;
	lcd_dsi_if          = <0>;
	lcd_dsi_lane        = <4>;
	pinctrl-0 = <&dsi4lane_pins_a>;
	pinctrl-1 = <&dsi4lane_pins_b>;

	lcd_x               = <720>;
	lcd_y               = <720>;
	lcd_width           = <72>;
	lcd_height          = <72>;
	lcd_dclk_freq       = <60>;

	lcd_hbp             = <166>;
	lcd_ht              = <1006>;
	lcd_hspw            = <60>;
	lcd_vbp             = <24>;
	lcd_vt              = <764>;
	lcd_vspw            = <4>;

	lcd_pwm_used        = <1>;
	lcd_pwm_ch          = <7>;
	lcd_pwm_freq        = <10000>;
	lcd_pwm_pol         = <0>;
	lcd_pwm_max_limit   = <255>;

	lcd_dsi_format      = <0>;
	lcd_dsi_te          = <0>;
	lcd_frm             = <0>;
	lcd_gamma_en        = <0>;
	lcd_cmap_en         = <0>;

	lcd_gpio_0 = <&pio PD 20 GPIO_ACTIVE_HIGH>;
};'''
t = t[:start] + new_seg + t[end:]
open(f, 'w').write(t)
print('5/5 board.dts ok, LVDS segment replaced')
