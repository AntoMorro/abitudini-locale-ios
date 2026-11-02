import json
import subprocess
import sys
import re

data = json.loads(subprocess.check_output(["xcrun", "simctl", "list", "devices", "available", "--json"], text=True))
sdk = subprocess.check_output(["xcrun", "--sdk", "iphonesimulator", "--show-sdk-version"], text=True).strip()
sdk_version = tuple(int(part) for part in sdk.split('.')[:2])
for runtime, devices in sorted(data["devices"].items(), reverse=True):
    if "iOS" not in runtime:
        continue
    version = re.search(r'iOS-(\d+)-(\d+)', runtime)
    if not version or (int(version[1]), int(version[2])) > sdk_version:
        continue
    for device in devices:
        if device.get("isAvailable") and device["name"].startswith("iPhone"):
            print("SIMULATOR_ID=" + device["udid"])
            sys.exit(0)
raise SystemExit("Nessun simulatore iPhone disponibile sul runner macOS.")
