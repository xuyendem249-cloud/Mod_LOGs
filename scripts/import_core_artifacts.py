"""Verify and preserve downloaded step-1 artifacts without executing binaries."""
from pathlib import Path
import argparse,hashlib,json,shutil,zipfile
ROOT=Path(__file__).resolve().parents[1]

def main(directory):
 output=ROOT/'build/step1-verified';output.mkdir(parents=True,exist_ok=True);reports=[]
 lock=json.loads((ROOT/'sources.lock.json').read_text())
 for sdk in ['macosx','iphoneos']:
  path=Path(directory)/('Legend-Step1-'+sdk+'.zip')
  with zipfile.ZipFile(path) as archive:
   assert archive.testzip() is None,path
   report=json.loads(archive.read('artifacts/build_report.json'));library=archive.read('artifacts/LegendSwanStation.a')
   assert report['sdk']==sdk and report['architecture']=='arm64' and report['core_commit']==lock['commit']
   assert report['required_symbols_verified'] and not report['jit_sources_compiled']
   assert not report['installable_app'] and not report['game_or_bios_tested']
   assert library.startswith(b'!<arch>\n') and hashlib.sha256(library).hexdigest()==report['sha256']
   if sdk=='macosx':assert report['macos_api_probe_passed'] and report['frontend_tests_passed']
   folder=output/sdk;folder.mkdir(exist_ok=True)
   for name in ['build_report.json','core_patch_report.json','LegendSwanStation.a','SwanStation_LICENSE.txt','CorrespondingSource.tar.gz']:
    (folder/name).write_bytes(archive.read('artifacts/'+name))
   shutil.copyfile(path,output/path.name)
   reports.append({'file':path.name,'zip_sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'report':report})
 result={'verified_artifacts':reports,'source_run':'https://github.com/xuyendem249-cloud/Mod_LOGs/actions/runs/39557932135','iphone_runtime_tested':False,'ipa_available':False}
 (ROOT/'build/step1_verified_report.json').write_text(json.dumps(result,indent=2));print(json.dumps(result,indent=2))
if __name__=='__main__':
 parser=argparse.ArgumentParser();parser.add_argument('directory');args=parser.parse_args();main(args.directory)
