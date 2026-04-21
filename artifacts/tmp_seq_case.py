from pathlib import Path
import sys
sys.path.insert(0, r'C:\project\FPGA')
from uart_aesgcm_rsp import parse_rsp, run_encrypt_case, case_label
cases = parse_rsp(Path(r'C:\project\FPGA\txt\gcmEncryptExtIV256.rsp'))
sel = [c for c in cases if c.get('IVlen')==96 and c.get('PTlen')==128 and c.get('AADlen')==0 and c.get('Taglen')==32 and c.get('Count') in (0,1,2,3)]
for c in sel:
    ok, detail = run_encrypt_case('COM4', 5.0, c)
    print(('PASS' if ok else 'FAIL'), case_label(c), detail)
