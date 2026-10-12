# 考核③触摸 dts 手术：twi0删挡道ctp@14 / twi1开总线挂ctp@5d(PE5=INT,PE4=RST,老师参考dts+原理图双证) / twi2回disabled还PE12给USB
import shutil

DTS = '/home/karry/T113-Tina5.0-V1.2/device/config/chips/t113/configs/evb1_auto_nand/linux-5.4/board.dts'
shutil.copy(DTS, DTS + '.bak-1008-touch')

lines = open(DTS).read().splitlines(keepends=True)

# 行号锚点三重校验（1-based -> index-1），防行号漂移
def check(lineno, expect):
    act = lines[lineno - 1]
    assert expect in act, 'L%d anchor fail: expect %r got %r' % (lineno, expect, act)

check(867, 'ctp@14');   check(885, '};');      # twi0 下的 ctp 块 867-885
check(888, '&twi1');    check(893, 'okay') if False else None
check(893, 'disabled'); check(894, '};')       # twi1 段 888-894
check(896, '&twi2');    check(904, 'okay'); check(905, 'ctp@14'); check(915, '};'); check(916, '};')

# 从后往前改，行号不漂移
# ③ twi2: 删 ctp@14 块 905-915, status 904 改 disabled
lines[915 - 1:915] = []          # 删后 twi2 段只剩属性+};
for i in range(904 - 1, 896 - 1, -1):
    if 'status' in lines[i]:
        lines[i] = '\tstatus = "disabled";\n'
        break
else:
    raise SystemExit('twi2 status line not found')

# ② twi1: status 893 改 okay, 在 894 }; 前插入 ctp@5d 节点
lines[893 - 1] = '\tstatus = "okay";\n'
ctp = '''\tctp@5d {
\t\tcompatible = "allwinner,goodix";
\t\tdevice_type = "ctp";
\t\treg = <0x5d>;
\t\tstatus = "okay";
\t\tctp_name = "gt9xxnew_ts";
\t\tctp_twi_id = <0x1>;
\t\tctp_twi_addr = <0x5d>;
\t\tctp_screen_max_x = <0x2D0>;
\t\tctp_screen_max_y = <0x2D0>;
\t\tctp_revert_x_flag = <0x0>;
\t\tctp_revert_y_flag = <0x0>;
\t\tctp_exchange_x_y_flag = <0x0>;
\t\tctp_int_port = <&pio PE 5 GPIO_ACTIVE_HIGH>;
\t\tctp_wakeup = <&pio PE 4 GPIO_ACTIVE_HIGH>;
\t};
'''
lines[894 - 1:894 - 1] = [ctp]   # 插在 twi1 的 }; 之前

# ① twi0: 删 ctp@14 块 867-885（原行号不受后面影响，但本块在前面改动之前行号未变）
del lines[867 - 1:885]

open(DTS, 'w').write(''.join(lines))
print('surgery done')
