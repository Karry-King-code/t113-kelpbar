# 照片实锤: 屏是竖条屏(约1:2)不是方屏! 老师参考dts的720x1424+lcd_dclk 63才是真配置
# 修正: lcd0段 720x720->720x1424(老师时序), fb0_height 720->1424
P = '/home/karry/T113-Tina5.0-V1.2/device/config/chips/t113/configs/evb1_auto_nand/linux-5.4/board.dts'
import shutil
shutil.copy(P, P + '.bak-1009-bar')
t = open(P).read()

# ① lcd0段: 我的720x720参数 -> 老师的720x1424参数
old_seg = '''	lcd_driver_name     = "fl7707n_mipi";
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
	lcd_vspw            = <4>;'''
new_seg = '''	lcd_driver_name     = "fl7707n_mipi";
	lcd_backlight       = <50>;
	lcd_if              = <4>;
	lcd_dsi_if          = <0>;
	lcd_dsi_lane        = <4>;
	pinctrl-0 = <&dsi4lane_pins_a>;
	pinctrl-1 = <&dsi4lane_pins_b>;

	lcd_x               = <720>;
	lcd_y               = <1424>;
	lcd_width           = <72>;
	lcd_height          = <171>;
	lcd_dclk_freq       = <63>;

	lcd_hbp             = <90>;
	lcd_ht              = <850>;
	lcd_hspw            = <30>;
	lcd_vbp             = <18>;
	lcd_vt              = <1457>;
	lcd_vspw            = <3>;'''
assert old_seg in t, 'lcd0 segment anchor missing'
t = t.replace(old_seg, new_seg, 1)

# ② fb0_height 720 -> 1424
old_fb = ('\tfb0_format               = <0>;\n'
          '\tfb0_width                = <720>;\n'
          '\tfb0_height               = <720>;')
new_fb = ('\tfb0_format               = <0>;\n'
          '\tfb0_width                = <720>;\n'
          '\tfb0_height               = <1424>;')
assert old_fb in t, 'fb0 anchor missing'
t = t.replace(old_fb, new_fb, 1)

open(P, 'w').write(t)
print('lcd0 -> 720x1424 (teacher timing), fb0 -> 720x1424 done')
