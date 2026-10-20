"""Prepare local binary package and neutralize explicit signing phases only."""
from pathlib import Path
import re
import json

root = Path(__file__).resolve().parents[1]
binary = root / '.internal/AGDnsProxy.xcframework'
if not binary.is_dir():
    raise SystemExit('Missing DNS xcframework; run ci/build-dns.sh first')
package = root / '.internal/DNSPackage'
package.mkdir(exist_ok=True)
(package/'Package.swift').write_text('''// swift-tools-version:5.9
import PackageDescription
let package = Package(name: "AGDnsProxy", platforms: [.iOS(.v13), .macOS(.v10_15)],
 products: [.library(name: "AGDnsProxy", targets: ["AGDnsProxy"])],
 targets: [.binaryTarget(name: "AGDnsProxy", path: "AGDnsProxy.xcframework")])
''')
link = package/'AGDnsProxy.xcframework'
if not link.exists():
    link.symlink_to(binary, target_is_directory=True)
for project in [root/'AdguardExtension/Adguard.xcodeproj/project.pbxproj', root/'AdGuardSDK/AdGuardSDK.xcodeproj/project.pbxproj']:
    text = project.read_text()
    pattern = r'isa = XCRemoteSwiftPackageReference;\s*repositoryURL = "core\.dns-libs";\s*requirement = \{[^}]+\};'
    text, count = re.subn(pattern, 'isa = XCLocalSwiftPackageReference;\n\t\t\trelativePath = "../.internal/DNSPackage";', text)
    if count != 1:
        raise SystemExit(f'Expected exactly one registry DNS reference in {project}; got {count}')
    # The old framework codesign workaround ignores CODE_SIGNING_ALLOWED.
    text = text.replace('shellScript = "# xcode 12 does not sign', 'shellScript = "if [ \\"${CODE_SIGNING_ALLOWED}\\" = \\"NO\\" ]; then exit 0; fi\\n# xcode 12 does not sign')
    project.write_text(text)
# A registry pin cannot resolve as a local package. Keep all other version pins.
lock = root/'AdguardSafariExtension-iOS.xcworkspace/xcshareddata/swiftpm/Package.resolved'
obj = json.loads(lock.read_text())
obj['pins'] = [p for p in obj['pins'] if p['identity'] != 'core.dns-libs']
lock.write_text(json.dumps(obj, indent=2)+'\n')
print('Prepared local DNS package and disabled manual framework signing when unsigned')
