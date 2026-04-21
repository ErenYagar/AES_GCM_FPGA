from pathlib import Path
import sys
sys.path.insert(0, r'C:\project\FPGA')
from uart_aesgcm_rsp import parse_rsp
cases = parse_rsp(Path(r'C:\project\FPGA\txt\gcmEncryptExtIV256.rsp'))
for case in cases:
    if case.get('IVlen') == 96 and case.get('PTlen') == 104 and case.get('AADlen') == 720 and case.get('Taglen') == 96 and case.get('Count') == 6:
        for key in ['Count','Key','IV','PT','AAD','CT','Tag','Taglen','PTlen','AADlen','IVlen']:
            print(f'{key}={case.get(key, "")}')
        break
else:
    print('NOT_FOUND')
