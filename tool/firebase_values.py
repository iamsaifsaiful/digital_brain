"""Writes Firebase's Android settings (what the google-services Gradle plugin
would make) for one package, so push works without that plugin.

    python3 tool/firebase_values.py tool/google-services.json <package> <out.xml>

Without the JSON, or without that package in it, nothing is written and the
app runs with push off. These values are not secret (every APK carries them).
"""
import json
import os
import sys
from xml.sax.saxutils import escape

src, package, out = sys.argv[1:4]
if not os.path.exists(src):
    print(f"No {src}: push is off in this build.")
    sys.exit(0)
cfg = json.load(open(src, encoding="utf-8"))
info = cfg.get("project_info", {})
client = next((c for c in cfg.get("client", []) if c.get("client_info", {}).get("android_client_info", {}).get("package_name") == package), None)
if client is None:
    print(f"{package} is not in {src}: push is off in this build.")
    sys.exit(0)
values = {
    "google_app_id": client["client_info"]["mobilesdk_app_id"],
    "gcm_defaultSenderId": info.get("project_number", ""),
    "project_id": info.get("project_id", ""),
    "google_storage_bucket": info.get("storage_bucket", ""),
    "google_api_key": (client.get("api_key") or [{}])[0].get("current_key", ""),
    "google_crash_reporting_api_key": (client.get("api_key") or [{}])[0].get("current_key", ""),
}
with open(out, "w", encoding="utf-8") as f:
    f.write('<?xml version="1.0" encoding="utf-8"?>\n<resources>\n')
    for k, v in values.items():
        if v:
            f.write(f'    <string name="{k}" translatable="false">{escape(v)}</string>\n')
    f.write("</resources>\n")
print(f"Firebase settings for {package} written to {out}.")
