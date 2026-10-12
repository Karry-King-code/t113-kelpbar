#!/usr/bin/env python3
"""生成音频测试文件（WAV，44 字节头 + PCM 数据）"""
import struct, math, wave, sys

def gen(path, segs, rate=44100, amp=0.5):
    """segs: [(频率Hz, 时长秒), ...]"""
    data = bytearray()
    for freq, dur in segs:
        n = int(rate*dur)
        for i in range(n):
            t = i/rate
            fade = 1.0
            if i < rate*0.02:            fade = i/(rate*0.02)
            elif i > n - rate*0.02:      fade = (n-i)/(rate*0.02)
            v = int(32767*amp*fade*math.sin(2*math.pi*freq*t))
            data += struct.pack('<h', v)
    with wave.open(path, 'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(rate)
        w.writeframes(bytes(data))
    return os.path.getsize(path)

if __name__ == '__main__':
    print('test_440.wav  :', gen('test_440.wav',   [(440, 2.0)]), '字节')
    print('test_scale.wav:', gen('test_scale.wav', [(262,0.5),(294,0.5),(330,0.5),(349,0.5),(392,0.5),(440,1.0)]), '字节')
