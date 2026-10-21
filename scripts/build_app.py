"""Compile a UIKit frontend with the pinned static core. No account/signing/upload to Apple."""
from pathlib import Path
import argparse,json,hashlib,platform,plistlib,shutil,subprocess,zipfile
from build_core import build,run,capture,ROOT

def main(sdk):
 if platform.system()!='Darwin':raise SystemExit('App compilation needs macOS + Xcode. No iOS app is compiled on Windows.')
 build(sdk)
 sdkroot=capture(['xcrun','--sdk',sdk,'--show-sdk-path'])
 clang=capture(['xcrun','--sdk',sdk,'--find','clang++'])
 folder=ROOT/'build'/sdk;app=folder/'Legend.app';app.mkdir(exist_ok=True)
 target='arm64-apple-ios17.0'+('-simulator' if sdk=='iphonesimulator' else '')
 sources=[ROOT/'Sources/App/main.mm',ROOT/'Sources/App/LegendViews.mm',ROOT/'Sources/Core/PlayerCore.cpp',ROOT/'Sources/Core/GameData.cpp',ROOT/'Sources/Core/FusionAdvisor.cpp']
 args=[clang,'-target',target,'-isysroot',sdkroot,'-std=c++17','-fobjc-arc','-fblocks','-O2','-g','-Wall','-Wextra','-Wno-unused-parameter','-Wno-deprecated-declarations','-I'+str(ROOT/'Sources/Core'),'-I'+str(ROOT/'vendor/swanstation/dep/libretro-common/include'),*sources,folder/'LegendSwanStation.a','-o',app/'Legend']
 # The direct clang build does not enable Clang module autolinking. Link the
 # CoreGraphics APIs used by main.mm explicitly for device AND simulator.
 for framework in ['UIKit','Foundation','CoreFoundation','CoreGraphics','AVFoundation','AudioToolbox','QuartzCore','UniformTypeIdentifiers','GameController']:args+=['-framework',framework]
 args+=['-lobjc'];run(args)
 info=plistlib.loads((ROOT/'Resources/Info.plist').read_bytes());info['CFBundleSupportedPlatforms']=['iPhoneSimulator' if sdk=='iphonesimulator' else 'iPhoneOS'];info['DTPlatformName']=sdk;info['DTSDKName']=sdk+capture(['xcrun','--sdk',sdk,'--show-sdk-version'])
 for name in ['AppLogo.png','welcome.png','DuelTemple-v1.png','LICENSES.txt']:shutil.copyfile(ROOT/'Resources'/name,app/name)
 # Use Apple's own asset compiler for the app icon. Never package personal game files.
 catalog=folder/'Assets.xcassets';icon=catalog/'AppIcon.appiconset';icon.mkdir(parents=True,exist_ok=True)
 run(['sips','-z','1024','1024',ROOT/'Resources/AppLogo.png','--out',icon/'AppIcon.png'])
 (catalog/'Contents.json').write_text(json.dumps({'info':{'author':'xcode','version':1}}))
 (icon/'Contents.json').write_text(json.dumps({'images':[{'filename':'AppIcon.png','idiom':'universal','platform':'ios','size':'1024x1024'}],'info':{'author':'xcode','version':1}}))
 partial=folder/'asset-info.plist'
 run(['xcrun','actool',catalog,'--compile',app,'--platform',sdk,'--minimum-deployment-target','17.0','--target-device','iphone','--target-device','ipad','--app-icon','AppIcon','--output-partial-info-plist',partial,'--output-format','human-readable-text'])
 info.update(plistlib.loads(partial.read_bytes()));(app/'Info.plist').write_bytes(plistlib.dumps(info))
 # Simulator ad-hoc signing needs no Apple identity. Device output is intentionally unsigned.
 if sdk=='iphonesimulator':run(['codesign','--force','--sign','-',app])
 report={'stage':3,'app_version':info['CFBundleShortVersionString'],'app_build':info['CFBundleVersion'],'sdk':sdk,'target':target,'apple_sdk_app_compiled':True,'signed_for_device':False,'installable_on_iphone':False,'testflight_uploaded':False,'game_or_bios_tested':False,'executable_sha256':hashlib.sha256((app/'Legend').read_bytes()).hexdigest()}
 archive=folder/('Legend-Step2-'+sdk+'-unsigned-app.zip')
 with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED) as z:
  for p in app.rglob('*'):
   if p.is_file():z.write(p,p.relative_to(folder))
 (folder/'app_build_report.json').write_text(json.dumps(report,indent=2));print(json.dumps(report,indent=2))

if __name__=='__main__':
 parser=argparse.ArgumentParser();parser.add_argument('--sdk',choices=['iphoneos','iphonesimulator'],required=True);args=parser.parse_args();main(args.sdk)
