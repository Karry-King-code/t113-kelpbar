P = "/home/karry/T113-Tina5.0-V1.2/kernel/linux-5.4/drivers/video/fbdev/sunxi/disp2/disp/lcd/panels.h"
import shutil
shutil.copy(P, P + ".bak-fl7707")
t = open(P).read()
anc = "extern struct __lcd_panel he0801a068_panel;"
assert anc in t, "anchor missing"
t = t.replace(anc, anc + "\nextern struct __lcd_panel fl7707n_mipi_panel;", 1)
open(P, "w").write(t)
print("panels.h declaration added")
