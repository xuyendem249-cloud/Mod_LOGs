from pathlib import Path
import zipfile,json,hashlib
ROOT=Path(__file__).resolve().parents[1]
def main():
 version=json.loads((ROOT/'project.json').read_text())['version']
 output=ROOT/('Legend-iOS-'+version+'-source.zip');files=[]
 for folder in ['scripts','Sources','tests','.github','Resources']:
  files.extend(p for p in (ROOT/folder).rglob('*') if p.is_file() and '__pycache__' not in p.parts)
 files.extend(ROOT/name for name in ['README.md','CHANGELOG.md','PARITY.md','CAI_DAT_0.3.md','CAI_DAT_0.3.1.md','project.json','sources.lock.json','.gitignore','THIRD_PARTY.md'])
 files.append(ROOT/'build/local_check_report.json')
 files.append(ROOT/'build/step1_verified_report.json')
 for name in ['native-effects/ios_effects_report.json','native-effects/player_traps_report.json','native-effects/player_summon_destruction_report.json','native-effects/summon_cpp_report.json','parity_check_report.json']:
  if (ROOT/'build'/name).exists():files.append(ROOT/'build'/name)
 for name in ['card-effects/mobile_effects_report.json','card-effects/player_card_effects_report.json','card-effects/player_traps_report.json','card-effects/player_summon_destruction_report.json','verified-'+version+'.json']:
  if (ROOT/'build'/name).exists():files.append(ROOT/'build'/name)
 with zipfile.ZipFile(output,'w',zipfile.ZIP_DEFLATED) as z:
  for path in sorted(files):
   relative=path.relative_to(ROOT).as_posix();assert not relative.endswith(('.iso','.bin','.img','.mcr','.mcd','.state','.p8','.p12','.mobileprovision','.ipa'))
   z.write(path,relative)
 with zipfile.ZipFile(output) as z:
  assert z.testzip() is None
  assert '.github/workflows/core-build.yml' in z.namelist()
 report=dict(source_bundle=output.name,bytes=output.stat().st_size,sha256=hashlib.sha256(output.read_bytes()).hexdigest(),no_game_bios_saves_or_signing_keys=True,installable=False)
 (ROOT/'build/source_bundle_report.json').write_text(json.dumps(report,indent=2));print(json.dumps(report,indent=2))
if __name__=='__main__':main()
