"""Generate portable text/compatibility constants from standard encoding + Android metadata."""
from pathlib import Path
import json,unicodedata,hashlib
ROOT=Path(__file__).resolve().parents[1]

def main():
 source=ROOT.parent/'legend_android/assets/compat.json'
 config=json.loads(source.read_text());out=ROOT/'Sources/Core'
 rows=[]
 for lead in list(range(0x81,0xa0))+list(range(0xe0,0xf0)):
  for trail in range(256):
   try:s=unicodedata.normalize('NFKC',bytes([lead,trail]).decode('shift_jis'))
   except UnicodeDecodeError:continue
   escaped=''.join('\\x%02x'%b for b in s.encode())
   rows.append('{0x%04x,"%s"}'%((lead<<8)|trail,escaped))
 (out/'ShiftJisTable.hpp').write_text('// Generated from Python standard Shift_JIS + NFKC; no game assets.\n#pragma once\n#include <cstdint>\nnamespace Legend { struct GlyphEntry {uint16_t code;const char* text;};\ninline constexpr GlyphEntry glyphTable[]={\n'+',\n'.join(rows)+'\n};\n}\n',encoding='utf-8')
 lines=['// Generated from Android compatibility metadata; RAM only, no ISO bytes.','#pragma once','#include "ModCompatibility.hpp"','namespace Legend {','inline ModCompatibility defaultCompatibility(){ ModCompatibility c;']
 for digest in config['known']:lines.append('c.known.insert("'+digest+'");')
 def patch(at,old,new):return '{%d,fromHex("%s"),fromHex("%s")}'%(at,old,new)
 for at,old,write,update in config['simple']:
  # Reject reintroduction of the old +8 exporter bug; keep the native BEQ intact.
  if at==0xb1d4:
   assert old=='000017240a80073cd5b1e7801900e0101a80073c' and update=='0a80073cd5b1e78000001724'
   assert write==at
  b=bytearray.fromhex(old);b[write-at:write-at+len(bytes.fromhex(update))]=bytes.fromhex(update)
  lines.append('c.simple.push_back('+patch(at,old,b.hex())+');')
 b=config['battle'];old=bytes.fromhex(b['old']);new=bytes.fromhex(b['new'])+old[len(bytes.fromhex(b['new'])):]
 lines.append('c.groups.push_back({{'+patch(b['at'],b['old'],new.hex())+'},{{%d,fromHex("%s")}}});'%(b['cave'],b['code']))
 lines.append('c.groups.push_back({{'+','.join(patch(*p) for p in config['traps'])+'},{'+','.join('{%d,fromHex("%s")}'%tuple(p) for p in config['caves'])+'}});')
 for group in config.get('effect_groups',[]):
  lines.append('c.groups.push_back({{'+','.join(patch(*p) for p in group['patches'])+'},{'+','.join('{%d,fromHex("%s")}'%tuple(p) for p in group['caves'])+'}});')
 for at,code in config['hand_signatures']:lines.append('c.handSignatures.push_back({%d,fromHex("%s")});'%(at,code))
 lines+=['return c;}','}'];(out/'CompatibilityTables.hpp').write_text('\n'.join(lines)+'\n',encoding='utf-8')
 print(json.dumps({'glyphs':len(rows),'compatibility_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'simple':len(config['simple']),'trap_sites':len(config['traps'])}))
if __name__=='__main__':main()
