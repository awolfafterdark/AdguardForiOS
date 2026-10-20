"""Package a device build without invoking signed exportArchive."""
from pathlib import Path
import os, plistlib, shutil, subprocess, json, hashlib, zipfile
from PIL import Image, ImageDraw

root = Path(__file__).resolve().parents[1]
products = root/'.derived/Build/Products'/f'{os.environ.get("CONFIGURATION", "Release")}-iphoneos'
apps = list(products.glob('AdguardPro.app'))
if len(apps) != 1:
    raise SystemExit(f'Expected one device AdguardPro.app in {products}, found {len(apps)}')
out = root/'out'
payload = out/'Payload'
payload.mkdir(parents=True, exist_ok=True)
app = payload/apps[0].name
shutil.copytree(apps[0], app, symlinks=True, dirs_exist_ok=True)
name = os.environ.get('APP_NAME', 'aWolfAfterDar’s Ad Getr3kt').strip()
if not name or len(name) > 80 or any(ord(c) < 32 for c in name):
    raise SystemExit('App name must contain 1–80 printable characters')
plist = app/'Info.plist'
info = plistlib.loads(plist.read_bytes())
info['CFBundleDisplayName'] = name
info['CFBundleName'] = name
# Localized display names otherwise override the custom name.
for strings in app.glob('*.lproj/InfoPlist.strings'):
    try:
        values = plistlib.loads(strings.read_bytes())
    except Exception:
        # plutil converts Xcode's old-style strings format losslessly.
        values = plistlib.loads(subprocess.check_output(['plutil','-convert','xml1','-o','-',str(strings)]))
    for key in ('CFBundleDisplayName', 'CFBundleName'):
        if key in values: values[key] = name
    strings.write_bytes(plistlib.dumps(values))
for label, color in [('Midnight', '#16213e'), ('Violet', '#663399'), ('Forest', '#176b45')]:
    for suffix, size in [('60@2x',120), ('60@3x',180), ('76@2x~ipad',152), ('83.5@2x~ipad',167)]:
        im = Image.new('RGB', (size,size), color)
        d = ImageDraw.Draw(im)
        d.polygon([(size*.5,size*.15),(size*.82,size*.3),(size*.75,size*.7),(size*.5,size*.88),(size*.25,size*.7),(size*.18,size*.3)], fill='white')
        d.line([(size*.34,size*.51),(size*.46,size*.63),(size*.68,size*.39)], fill=color, width=max(3,int(size*.065)))
        im.save(app/f'Internal{label}{suffix}.png')
for key in ('CFBundleIcons','CFBundleIcons~ipad'):
    icons = info.setdefault(key,{})
    icons['CFBundleAlternateIcons'] = {
        label: {'CFBundleIconFiles': [f'Internal{label}60', f'Internal{label}76', f'Internal{label}83.5'], 'UIPrerenderedIcon': False}
        for label in ('Midnight','Violet','Forest')
    }
plist.write_bytes(plistlib.dumps(info))
# Strip signatures from embedded prebuilt binaries as well as app/extensions.
for signature in app.rglob('_CodeSignature'):
    if signature.is_dir(): shutil.rmtree(signature)
for profile in app.rglob('embedded.mobileprovision'): profile.unlink()
for f in app.rglob('*'):
    if not f.is_file() or f.is_symlink(): continue
    with f.open('rb') as src: magic = src.read(4)
    if magic in [b'\xcf\xfa\xed\xfe', b'\xfe\xed\xfa\xcf', b'\xca\xfe\xba\xbe', b'\xbe\xba\xfe\xca']:
        signed = subprocess.run(['codesign','-d',str(f)], capture_output=True).returncode == 0
        if signed: subprocess.run(['codesign','--remove-signature',str(f)], check=True)
        if subprocess.run(['codesign','-d',str(f)],capture_output=True).returncode == 0:
            raise SystemExit(f'Binary still signed: {f}')
if not list((app/'PlugIns').glob('*.appex')):
    raise SystemExit('No embedded extensions; refusing incomplete IPA')
references = {}
for bundle in [app, *sorted((app/'PlugIns').glob('*.appex'))]:
    p = plistlib.loads((bundle/'Info.plist').read_bytes())
    references[str(bundle.relative_to(payload))] = {'bundle_id':p['CFBundleIdentifier'],'executable':p['CFBundleExecutable']}
references['note'] = 'Unsigned IPA. Sign every nested framework, extension and app with matching profiles. Preserve app groups and Network Extension capabilities. Reference source entitlements remain in the repository.'
(out/'signing-reference.json').write_text(json.dumps(references,indent=2)+'\n')
ipa = out/'Ad-Getr3kt-unsigned.ipa'
subprocess.run(['ditto','-c','-k','--keepParent',str(payload),str(ipa)],check=True)
with zipfile.ZipFile(ipa) as z:
    if z.testzip() is not None: raise SystemExit('Corrupt IPA')
    assert f'Payload/{app.name}/Info.plist' in z.namelist()
(out/(ipa.name+'.sha256')).write_text(hashlib.sha256(ipa.read_bytes()).hexdigest()+'  '+ipa.name+'\n')
print(f'Created unsigned {ipa} with {len(references)-1} bundles')
