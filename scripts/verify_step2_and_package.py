"""Verify downloaded CI artifacts and wrap the device app in an UNSIGNED IPA.

No Apple account, certificate, provisioning profile, upload, or device installation.
"""
from pathlib import Path,PurePosixPath
import argparse,hashlib,io,json,plistlib,shutil,stat,struct,tarfile,zipfile
ROOT=Path(__file__).resolve().parents[1]

def sha(data):return hashlib.sha256(data).hexdigest()
def version(value):return '.'.join(str(x) for x in (value>>16,(value>>8)&255,value&255))

def macho(data):
 if len(data)<32:raise ValueError('Truncated executable')
 magic,cpu,subtype,kind,count,length,flags,reserved=struct.unpack_from('<IiiIIIII',data)
 if magic!=0xfeedfacf or cpu!=0x0100000c or kind!=2:raise ValueError('Expected arm64 Mach-O executable')
 if 32+length>len(data):raise ValueError('Truncated load commands')
 result={'architecture':'arm64','platform':None,'minimum_os':None,'sdk':None,'encrypted':False,'linked_libraries':[]};at=32
 for _ in range(count):
  cmd,size=struct.unpack_from('<II',data,at)
  if size<8 or at+size>32+length:raise ValueError('Invalid load command')
  if cmd==0x32:
   platform,minimum,sdk=struct.unpack_from('<III',data,at+8)
   result.update(platform=platform,minimum_os=version(minimum),sdk=version(sdk))
  elif cmd in (0xc,0x80000018,0x8000001f,0x80000023):
   offset=struct.unpack_from('<I',data,at+8)[0]
   if offset>=size:raise ValueError('Invalid dylib name')
   result['linked_libraries'].append(data[at+offset:at+size].split(b'\0')[0].decode())
  elif cmd in (0x21,0x2c):result['encrypted']=struct.unpack_from('<I',data,at+16)[0]!=0
  at+=size
 if at!=32+length:raise ValueError('Load command length mismatch')
 return result

def safe_name(name):
 p=PurePosixPath(name)
 if p.is_absolute() or '..' in p.parts or '\\' in name:raise ValueError('Unsafe archive path')
 return p

def main(directory,app_version,source_run):
 assert source_run.startswith('https://github.com/xuyendem249-cloud/Mod_LOGs/actions/runs/') and source_run.rsplit('/',1)[-1].isdigit()
 output=ROOT/('build/verified-'+app_version);output.mkdir(parents=True,exist_ok=True)
 lock=json.loads((ROOT/'sources.lock.json').read_text());reports=[];device_app=None
 for sdk in ['iphoneos','iphonesimulator','portable-tests']:
  path=Path(directory)/('Legend-Step2-'+sdk+'.zip')
  with zipfile.ZipFile(path) as outer:
   if outer.testzip() is not None:raise ValueError('Corrupt artifact '+path.name)
   for name in outer.namelist():safe_name(name)
   core=json.loads(outer.read('build_report.json' if sdk=='portable-tests' else 'app-artifacts/core_build_report.json'))
   assert core['core_commit']==lock['commit'] and core['required_symbols_verified'] and not core['jit_sources_compiled']
   item={'file':path.name,'zip_sha256':sha(path.read_bytes()),'core_report':core}
   if sdk=='portable-tests':
    assert core['macos_api_probe_passed'] and core['frontend_tests_passed'] and core['audio_tests_passed']
   else:
    source_matches=0
    with tarfile.open(fileobj=io.BytesIO(outer.read('app-artifacts/CorrespondingSource.tar.gz')),mode='r:gz') as source:
     for folder in ['Sources','Resources']:
      for local in (ROOT/folder).rglob('*'):
       if not local.is_file():continue
       name=local.relative_to(ROOT).as_posix();remote=source.extractfile(name)
       assert remote is not None,'Source artifact missing '+name
       expected=local.read_bytes();actual=remote.read()
       if local.suffix in ('.cpp','.hpp','.mm','.plist','.txt','.json'):expected=expected.replace(b'\r\n',b'\n');actual=actual.replace(b'\r\n',b'\n')
       assert actual==expected,'Source artifact differs from local '+name
       source_matches+=1
    report=json.loads(outer.read('app-artifacts/app_build_report.json'))
    assert report['sdk']==sdk and report['apple_sdk_app_compiled'] and not report['signed_for_device']
    nested='app-artifacts/Legend-Step2-'+sdk+'-unsigned-app.zip';app_data=outer.read(nested)
    with zipfile.ZipFile(io.BytesIO(app_data)) as app:
     assert app.testzip() is None
     for entry in app.infolist():
      safe_name(entry.filename)
      if stat.S_ISLNK(entry.external_attr>>16):raise ValueError('Unexpected symbolic link')
     executable=app.read('Legend.app/Legend');assert sha(executable)==report['executable_sha256']
     info=plistlib.loads(app.read('Legend.app/Info.plist'));binary=macho(executable)
     assert info['CFBundleShortVersionString']==app_version,'Artifact is not the requested app version'
     if app_version in ('0.3.0','0.3.1','0.3.2','0.3.3'):
      assert report['stage']==3 and report['app_version']==app_version
      assert any('/GameController.framework/' in name for name in binary['linked_libraries'])
      assert {'Legend.app/welcome.png','Legend.app/LICENSES.txt'}.issubset(app.namelist())
     if app_version in ('0.3.1','0.3.2','0.3.3'):
      assert app.read('Legend.app/DuelTemple-v1.png')==(ROOT/'Resources/DuelTemple-v1.png').read_bytes()
     assert info['CFBundleIdentifier']=='vn.anhchugia35.legend' and info['CFBundleExecutable']=='Legend'
     assert info['MinimumOSVersion']=='17.0' and binary['minimum_os']=='17.0.0'
     assert binary['platform']==(2 if sdk=='iphoneos' else 7) and not binary['encrypted']
     assert any('/CoreGraphics.framework/' in name for name in binary['linked_libraries'])
     if sdk=='iphoneos':
      assert info['CFBundleSupportedPlatforms']==['iPhoneOS']
      assert 'Legend.app/embedded.mobileprovision' not in app.namelist()
      assert 'Legend.app/_CodeSignature/CodeResources' not in app.namelist()
      device_app=app_data
     item.update(app_report=report,macho=binary,matching_source_resource_files=source_matches)
    (output/('Legend-'+sdk+'-app.zip')).write_bytes(app_data)
    if sdk=='iphonesimulator':
     smoke=json.loads(outer.read('iphonesimulator/simulator_smoke_report.json'))
     assert smoke['app_launched'] and smoke['all_14_buttons_inside_view'] and not smoke['game_or_bios_tested']
     if app_version in ('0.3.1','0.3.2','0.3.3'):assert smoke['approved_background_loaded']
     if app_version in ('0.3.2','0.3.3'):
      for mode in ('portrait','landscape'):
       for key in ('orientation_matches','logo_in_toolbar','speed_text_sync','speed_button_visibility','speed_button_inside_safe_area','landscape_game_fills_height','auto_ring_stops'):assert smoke['orientations'][mode][key],(mode,key)
     if app_version=='0.3.3':
      for mode in ('portrait','landscape'):assert smoke['orientations'][mode]['large_circular_logo']
     item['simulator_smoke']=smoke
   shutil.copyfile(path,output/path.name);reports.append(item)
 assert device_app is not None
 ipa=ROOT/('build/LegendPlayer-iOS-'+app_version+'-unsigned.ipa');excluded=[]
 with zipfile.ZipFile(io.BytesIO(device_app)) as app,zipfile.ZipFile(ipa,'w',zipfile.ZIP_DEFLATED) as target:
  for entry in app.infolist():
   path=safe_name(entry.filename)
   if any(p.endswith('.dSYM') for p in path.parts):excluded.append(entry.filename);continue
   assert path.parts[0]=='Legend.app'
   if entry.is_dir():continue
   name='Payload/'+entry.filename;z=zipfile.ZipInfo(name,entry.date_time);z.create_system=3
   z.external_attr=(stat.S_IFREG|(0o755 if entry.filename=='Legend.app/Legend' else 0o644))<<16
   z.compress_type=zipfile.ZIP_DEFLATED;target.writestr(z,app.read(entry.filename))
 with zipfile.ZipFile(ipa) as check:
  assert check.testzip() is None and 'Payload/Legend.app/Legend' in check.namelist()
  assert not any('.dSYM/' in n for n in check.namelist())
 result={'source_run':source_run,'app_version':app_version,'verified_artifacts':reports,'unsigned_ipa':str(ipa.relative_to(ROOT)),'ipa_sha256':sha(ipa.read_bytes()),'ipa_bytes':ipa.stat().st_size,'debug_symbols_excluded':excluded,'signed_for_device':False,'installable_without_signing':False,'iphone_runtime_tested':False,'game_or_bios_tested':False,'testflight_uploaded':False}
 (ROOT/('build/verified-'+app_version+'.json')).write_text(json.dumps(result,indent=2));print(json.dumps({k:v for k,v in result.items() if k!='verified_artifacts'},indent=2))
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('directory');p.add_argument('--version',default='0.3.3',choices=['0.2.0','0.3.0','0.3.1','0.3.2','0.3.3']);p.add_argument('--run',required=True);args=p.parse_args();main(args.directory,args.version,args.run)
