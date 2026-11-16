#!/usr/bin/env bash
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Build the Dex toolchain the .dx files are checked with, at pinned commits,
# into dex/.toolchain (git-ignored). Written for Ubuntu 24.04 with ghcup.
#
# Dex's last commit (January 2024) needs LLVM 12, GHC 8.10.7 and an llvm-hs
# fork. Ubuntu 24.04 does not package LLVM 12, but Ubuntu 22.04's packages of
# it install cleanly. The sources are fetched by git, not as GitHub archives,
# because some proxies refuse archive downloads.
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
tc="$here/.toolchain"
DEX_COMMIT=25e2e389b90403ae2f8d67fb6d52f47d23c439ee
LLVM_HS_COMMIT=423220bffac4990d019fc088c46c5f25310d5a33
LLVM12=12.0.1-19ubuntu3
SUDO=$([ "$(id -u)" = 0 ] && echo "" || echo sudo)
mkdir -p "$tc"

# 1. LLVM 12.
if [ ! -x /usr/lib/llvm-12/bin/llvm-config ]; then
  mkdir -p "$tc/debs"
  (
    cd "$tc/debs"
    for p in libllvm12 llvm-12 llvm-12-dev llvm-12-runtime llvm-12-tools llvm-12-linker-tools \
             clang-12 libclang1-12 libclang-cpp12 libclang-common-12-dev; do
      curl -sSfO "http://archive.ubuntu.com/ubuntu/pool/universe/l/llvm-toolchain-12/${p}_${LLVM12}_amd64.deb"
    done
    $SUDO apt-get install -y ./*.deb
  )
fi
export PATH="/usr/lib/llvm-12/bin:$HOME/.ghcup/bin:$PATH"

# 2. GHC 8.10.7 and Stack, alongside the GHC 9.10.1 the rest of the repo uses.
ghcup install ghc 8.10.7
ghcup install stack 2.15.7

# 3. Dex and llvm-hs, at their pinned commits.
fetch() {
  local dir=$1 url=$2 commit=$3
  if [ ! -d "$dir/.git" ]; then
    git init -q "$dir"
    git -C "$dir" remote add origin "$url"
  fi
  git -C "$dir" fetch -q --depth 1 origin "$commit"
  git -C "$dir" checkout -q -f FETCH_HEAD
}
fetch "$tc/dex-lang" https://github.com/google-research/dex-lang "$DEX_COMMIT"
fetch "$tc/dex-lang/llvm-hs-src" https://github.com/llvm-hs/llvm-hs "$LLVM_HS_COMMIT"

cd "$tc/dex-lang"
# Use the local llvm-hs in place of Stack's GitHub extra-dep.
sed -i -e '/- github: llvm-hs\/llvm-hs/,/- llvm-hs-pure/c\  - ./llvm-hs-src/llvm-hs\n  - ./llvm-hs-src/llvm-hs-pure' stack.yaml
grep -q -- '- ./llvm-hs-src/llvm-hs-pure' stack.yaml

# The runtime, as LLVM bitcode, by Dex's own makefile rule.
make dexrt-llvm
# The web notebook's script; `dex script` does not use it, but the install
# step lists it.
touch static/index.js

stack --system-ghc --compiler ghc-8.10.7 --no-install-ghc build --copy-bins --local-bin-path "$tc/bin"

# Compile the prelude once, so that no check prints "Compiling prelude".
"$tc/bin/dex" script /dev/null > /dev/null
"$tc/bin/dex" script /dev/null
