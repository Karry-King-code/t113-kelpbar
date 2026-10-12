# 关掉U-Boot的CONFIG_BOOT_GUI: board_env_late_init->board_bootlogo_display->boot_gui_init->disp_devices_open 无条件开屏
# 这是U-Boot开屏的真正开关(lcd_used/logo有无都不管它),关掉后内核可完整初始化FL7707
import shutil

BASE = '/home/karry/T113-Tina5.0-V1.2/brandy/brandy-2.0/u-boot-2018/'
for rel in ['configs/sun8iw20p1_auto_defconfig', '.config']:
    p = BASE + rel
    shutil.copy(p, p + '.bak-1008-nogui')
    lines = open(p).read().splitlines(keepends=True)
    hit = 0
    for i, l in enumerate(lines):
        if l.strip() == 'CONFIG_BOOT_GUI=y':
            lines[i] = l.replace('CONFIG_BOOT_GUI=y', '# CONFIG_BOOT_GUI is not set')
            hit += 1
    assert hit >= 1, 'CONFIG_BOOT_GUI=y not found in ' + rel
    open(p, 'w').write(''.join(lines))
    print('%s: %d line(s) changed' % (rel, hit))
