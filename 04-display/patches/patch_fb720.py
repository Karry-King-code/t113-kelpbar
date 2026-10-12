# 考核④显示最后一击: fb0尺寸1024x600(LVDS遗留) -> 720x720(FL7707实际)
# 板上实锤: fb0_width=1024 fb0_height=600 而 lcd0是720x720 -> 图层缓冲与输出尺寸不匹配 -> 黑屏
P = '/home/karry/T113-Tina5.0-V1.2/device/config/chips/t113/configs/evb1_auto_nand/linux-5.4/board.dts'
import shutil
shutil.copy(P, P + '.bak-1009-fb')
t = open(P).read()
anc = ('\tfb0_format               = <0>;\n'
       '\tfb0_width                = <1024>;\n'
       '\tfb0_height               = <600>;')
assert anc in t, 'fb0 anchor missing'
new = ('\tfb0_format               = <0>;\n'
       '\tfb0_width                = <720>;\n'
       '\tfb0_height               = <720>;')
t = t.replace(anc, new, 1)
open(P, 'w').write(t)
print('fb0 1024x600 -> 720x720 done')
