#!/bin/zsh
# One-time setup on a Mac: checks the tools, installs pandas, builds the app.
# Run from this folder with:  zsh setup.sh
cd "$(dirname "$0")"
echo "Network Compass setup"

if ! xcode-select -p >/dev/null 2>&1 || ! command -v swiftc >/dev/null 2>&1; then
  echo "Apple's command line tools are missing. A window will open: click Install."
  echo "When that finishes, run this again:  zsh setup.sh"
  xcode-select --install 2>/dev/null
  exit 1
fi
echo "OK   Apple command line tools"

if ! python3 -c 'import sys; sys.exit(sys.version_info < (3, 9))' 2>/dev/null; then
  echo "Python 3.9 or newer is needed. Get it from python.org/downloads, then run this again."
  exit 1
fi
echo "OK   $(python3 --version)"

if ! python3 -c 'import pandas' 2>/dev/null; then
  echo "...  Installing pandas"
  python3 -m pip install --user --quiet pandas || { echo "Could not install pandas. Check your internet connection and run this again."; exit 1; }
fi
echo "OK   pandas"

mkdir -p export
if python3 -m unittest discover -s tests 2>/dev/null; then echo "OK   Self-test on made-up data"; else
  echo "The self-test failed. Open Claude Code in this folder and ask it to run: python3 -m unittest discover -s tests"; exit 1; fi

echo "...  Building the app (about a minute)"
zsh app/build.sh >/tmp/network-compass-build.log 2>&1 || { echo "The app did not build. Details: /tmp/network-compass-build.log"; exit 1; }
echo "OK   Network Compass app"
echo
echo "All set. Next: type  claude  and then  /setup-network"
