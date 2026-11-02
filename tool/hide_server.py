"""Prints the server address XOR the app's key, in hex, for
--dart-define=RH_X=… (lib/services/api.dart decodes it). The address then
is not readable as text in the APK or in the build log.

    python3 tool/hide_server.py https://example.com
"""
import sys

KEY = "rH#9v!Lq7@xP2^mZ"
url = sys.argv[1].strip().rstrip("/") if len(sys.argv) > 1 else ""
print("".join(f"{ord(c) ^ ord(KEY[i % len(KEY)]):02x}" for i, c in enumerate(url)))
