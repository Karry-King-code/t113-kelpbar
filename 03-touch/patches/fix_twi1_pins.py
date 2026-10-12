# 触摸I2C物理线在PE0/PE1(原理图PE0=TP_SCL,PE1=TP_SDA)，dts twi1_pins_a/b却定义在PE14/PE15
# 必须把twi1的pinctrl引脚组改到PE0/PE1，否则TWI1波形从PE14/PE15出去，到不了触摸芯片
# 锚定块内替换，不碰gmac0/csi0等其他PE14/PE15出现处
P = '/home/karry/T113-Tina5.0-V1.2/device/config/chips/t113/configs/evb1_auto_nand/linux-5.4/board.dts'
import shutil
shutil.copy(P, P + '.bak-1008-twi1pins')
lines = open(P).read().splitlines(keepends=True)

def fix_block(tag):
    start = None
    for i, l in enumerate(lines):
        if tag in l:
            start = i
            break
    assert start is not None, tag + ' not found'
    for j in range(start, min(start + 8, len(lines))):
        if 'pins' in lines[j] and 'PE14' in lines[j]:
            lines[j] = lines[j].replace('"PE14", "PE15"', '"PE0", "PE1"')
            return lines[j].strip()
    raise SystemExit(tag + ': pins line not found in block')

r1 = fix_block('twi1_pins_a: twi1@0')
r2 = fix_block('twi1_pins_b: twi1@1')
open(P, 'w').write(''.join(lines))
print('twi1_pins_a ->', r1)
print('twi1_pins_b ->', r2)
