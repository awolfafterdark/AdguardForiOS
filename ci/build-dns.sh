#!/bin/bash
# Build the exact DNS version from public source, without AdGuard registry access.
set -euo pipefail
root="$PWD"
mkdir -p .internal
git clone --depth 1 --branch v2.10.1 https://github.com/AdguardTeam/DnsLibs.git .internal/DnsLibs
cd .internal/DnsLibs
python scripts/bootstrap_conan_deps.py
# Fetch the same public CMake-Conan support bundle used by upstream. Patch its
# settings before CMake installs them: the bundle predates Apple Clang 21.
curl --fail --location --retry 3 \
  https://github.com/AdguardTeam/NativeLibsCommon/releases/latest/download/conanfiles.tar.gz \
  -o "$root/.internal/conanfiles.tar.gz"
mkdir -p conan
tar -xzf "$root/.internal/conanfiles.tar.gz" -C conan
mv conan/conan_provider.cmake cmake/conan_provider.cmake
python - <<'PY'
from pathlib import Path
import re, subprocess, yaml
p = Path("conan/settings_user.yml")
settings = yaml.safe_load(p.read_text()) or {}
version = re.search(r"Apple clang version (\d+)", subprocess.check_output(["xcrun", "clang", "--version"], text=True)).group(1)
versions = settings.setdefault("compiler", {}).setdefault("apple-clang", {}).setdefault("version", [])
for value in (version, version + ".0"):
    if value not in [str(v) for v in versions]:
        versions.append(value)
p.write_text(yaml.safe_dump(settings, sort_keys=False))
print("Added installed Apple Clang compiler version:", version)
PY
# Builder links the macOS SDK too. Only the host slice and iPhone device slice are needed.
host_arch="$(uname -m)"
for platform in "macos-$host_arch" ios; do
  bash platform/mac/framework/build_dnsproxy_framework.sh \
    --os "$platform" --bp "$root/.internal/dns-$platform" --fwp "$PWD/platform/mac/framework"
done
xcodebuild -create-xcframework \
  -framework "$root/.internal/dns-macos-$host_arch/AGDnsProxy.framework" \
  -framework "$root/.internal/dns-ios/AGDnsProxy.framework" \
  -output "$root/.internal/AGDnsProxy.xcframework"
