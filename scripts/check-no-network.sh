#!/usr/bin/env bash
# Uygulama kodunda ağ API'si veya harici paket bağımlılığı olmadığını denetler.
# CI'da derlemeden önce çalışır; bir eşleşme bulunursa build başarısız olur.
set -euo pipefail
cd "$(dirname "$0")/.."

PATTERN='URLSession|URLRequest|NWConnection|NWPathMonitor|NWBrowser|import Network|CFNetwork|CFStream|WKWebView|SFSafariViewController|https?://'

if grep -rnE "$PATTERN" Kandirilmama --include='*.swift'; then
  echo "::error::Uygulama kodunda ağ API'si bulundu. Uygulama tamamen çevrimdışı olmalı."
  exit 1
fi

if grep -nE '^[[:space:]]*packages:' project.yml; then
  echo "::error::project.yml içinde harici paket bağımlılığı var."
  exit 1
fi

if ls Kandirilmama/*.entitlements >/dev/null 2>&1 && grep -l 'icloud' Kandirilmama/*.entitlements; then
  echo "::error::iCloud entitlement bulundu. iCloud senkronizasyonu kapalı olmalı."
  exit 1
fi

echo "Ağ denetimi geçti: ağ API'si, harici paket ve iCloud entitlement yok."
