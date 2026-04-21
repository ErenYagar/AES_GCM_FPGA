import serial, time
print('start')
PORT='COM4'
BAUD=115200
TIMEOUT=2.0
CMD_MODE=0x01
CMD_KEY=0x02
CMD_IV=0x03
CMD_AAD=0x04
CMD_PT=0x05
CMD_TAG=0x07
CMD_DEBUG=0x09
RSP_NAMES={0x90:'DBG_HDR',0x91:'DBG_IV',0x92:'DBG_AAD',0x93:'DBG_DATA',0x94:'DBG_TAG',0x80:'STATUS',0x81:'PC',0x82:'TAG'}
def send_packet(ser, cmd, bitlen, payload):
    frame=bytearray([cmd,(bitlen>>8)&0xff,bitlen&0xff]); frame.extend(payload); ser.write(frame); ser.flush()
def recv_exact(ser, count):
    data=bytearray(); deadline=time.time()+ser.timeout
    while len(data)<count:
        chunk=ser.read(count-len(data))
        if chunk:
            data.extend(chunk); continue
        if time.time()>deadline:
            raise TimeoutError(f'timeout waiting {count}, got {len(data)}')
    return bytes(data)
def recv_frame(ser):
    hdr=recv_exact(ser,3); t=hdr[0]; bits=(hdr[1]<<8)|hdr[2]; bc=(bits+7)//8; payload=recv_exact(ser,bc) if bc else b''; return t,bits,payload
key=bytes.fromhex('78dc4e0aaf52d935c3c01eea57428f00ca1fd475f5da86a49c8dd73d68c8e223')
iv=bytes.fromhex('d79cf22d504cc793c3fb6c8a')
aad=bytes.fromhex('b96baa8c1c75a671bfb2d08d06be5f36')
pt=b''
tag=bytes(16)
with serial.Serial(PORT, BAUD, timeout=TIMEOUT) as ser:
    print('opened')
    time.sleep(0.05)
    ser.reset_input_buffer(); ser.reset_output_buffer()
    send_packet(ser, CMD_MODE, 8, bytes([0]))
    send_packet(ser, CMD_KEY, 256, key)
    send_packet(ser, CMD_IV, len(iv)*8, iv)
    send_packet(ser, CMD_AAD, len(aad)*8, aad)
    send_packet(ser, CMD_PT, 0, pt)
    send_packet(ser, CMD_TAG, 128, tag)
    send_packet(ser, CMD_DEBUG, 0, b'')
    frames=[]
    while True:
        try:
            t,bits,payload=recv_frame(ser)
            frames.append((t,bits,payload))
        except TimeoutError as e:
            print('timeout', e)
            break
for i,(t,bits,payload) in enumerate(frames):
    print(f'{i}: {RSP_NAMES.get(t,hex(t))} bits={bits} payload={payload.hex()}')
