import sys
import time
import serial

sys.path.insert(0, r"C:\project\FPGA")
import uart_aesgcm_host as host


PORT = "COM4"
KEY = "2c371bef43adc22b8d8d009b38371dd14564562d5d00659bd4205d5957e3afed"
IV = "594672924e5570d611551985"
AAD = "a04f6e275cd29693bad0b2f8fd2b984a9e69d6af42a608e1e47377c9192e021bf2dfb15686480e3cb54a5d1e09bcdbe5"
PT = "e773fceddcc012e3fa4944cae6"
TAG = "00000000"


def main():
    with serial.Serial(PORT, 115200, timeout=5) as ser:
        time.sleep(0.05)
        ser.reset_input_buffer()
        ser.reset_output_buffer()

        host.send_packet(ser, host.CMD_MODE, 8, bytes([0]))
        time.sleep(0.01)
        host.send_packet(ser, host.CMD_KEY, 256, host.hex_to_bytes(KEY))
        time.sleep(0.01)
        host.send_packet(ser, host.CMD_IV, len(host.hex_to_bytes(IV)) * 8, host.hex_to_bytes(IV))
        time.sleep(0.01)
        host.send_packet(ser, host.CMD_AAD, len(host.hex_to_bytes(AAD)) * 8, host.hex_to_bytes(AAD))
        time.sleep(0.01)
        host.send_packet(ser, host.CMD_PT, len(host.hex_to_bytes(PT)) * 8, host.hex_to_bytes(PT))
        time.sleep(0.01)
        host.send_packet(ser, host.CMD_TAG, 32, host.hex_to_bytes(TAG))
        time.sleep(0.05)
        host.send_packet(ser, host.CMD_RUN, 0, b"")

        for idx in range(3):
            frame_type, bits, payload = host.recv_frame(ser)
            print(f"frame{idx}: type=0x{frame_type:02x} bits={bits} payload={payload.hex()}")


if __name__ == "__main__":
    main()
