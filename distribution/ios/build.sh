#!/usr/bin/env bash
set -e

[ -f "$HOME/.zshrc" ] && source "$HOME/.zshrc" || true
[ -f "$HOME/.zprofile" ] && source "$HOME/.zprofile" || true
[ -f "$HOME/.bash_profile" ] && source "$HOME/.bash_profile" || true
[ -f "$HOME/.bashrc" ] && source "$HOME/.bashrc" || true

export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

DOTNET=$(command -v dotnet || true)

if [ -z "$DOTNET" ]; then
  for candidate in \
    "/opt/homebrew/bin/dotnet" \
    "/usr/local/bin/dotnet" \
    "/usr/local/share/dotnet/dotnet"
  do
    if [ -x "$candidate" ]; then
      DOTNET="$candidate"
      break
    fi
  done
fi

if [ -z "$DOTNET" ]; then
  echo "dotnet not found"
  exit 1
fi

dotnet publish -c Release -r ios-arm64 -p:ExtraDefineConstants=DISABLE_UPDATER src/Ryujinx.Library --self-contained true
