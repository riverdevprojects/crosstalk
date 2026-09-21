#!/bin/sh
set -eu
# Select an installed iPhone runtime rather than hard-code a runner-specific device.
device_id=$(xcrun simctl list devices available -j | python3 -c '
import json, sys
runtimes = json.load(sys.stdin)["devices"]
for runtime in sorted(runtimes, reverse=True):
    for device in runtimes[runtime]:
        if "iPhone" in device["name"] and device.get("isAvailable"):
            print(device["udid"])
            sys.exit(0)
sys.exit("No available iPhone simulator. Install an iOS runtime in Xcode.")
')
xcodebuild -project Crosstalk.xcodeproj -scheme Crosstalk -configuration Debug \
  -destination "platform=iOS Simulator,id=$device_id" \
  -derivedDataPath build -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO test
