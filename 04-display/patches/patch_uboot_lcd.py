# 让U-Boot不开屏: boot_info.sync来自U-Boot传的boot_disp(开屏才置1)
# U-Boot当前用LVDS配置开屏->内核smooth接管错误状态->MIPI屏黑
# 改成lcd_used=0后: U-Boot不开屏->sync=0->内核完整执行fl7707开屏流程
P = "/home/karry/T113-Tina5.0-V1.2/device/config/chips/t113/configs/evb1_auto_nand/uboot-board.dts"
import shutil
shutil.copy(P, P + ".bak-1008-lcdsync")
t = open(P).read()
anc = '&lcd0 {\n\tlcd_used            = <1>;\n\n\tlcd_driver_name     = "default_lcd";'
assert anc in t, "anchor missing"
t = t.replace(anc, '&lcd0 {\n\tlcd_used            = <0>;\n\n\tlcd_driver_name     = "default_lcd";', 1)
open(P, "w").write(t)
print("uboot lcd_used 1->0 done")
