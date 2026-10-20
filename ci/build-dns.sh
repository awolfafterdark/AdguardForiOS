#!/bin/bash
# Build the exact DNS version from public source, without AdGuard registry access.
set -euo pipefail
root="$PWD"
mkdir -p .internal
git clone --depth 1 --branch v2.10.1 https://github.com/AdguardTeam/DnsLibs.git .internal/DnsLibs
cd .internal/DnsLibs
python scripts/bootstrap_conan_deps.py
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
