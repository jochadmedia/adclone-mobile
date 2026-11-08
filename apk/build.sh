#!/data/data/com.termux/files/usr/bin/bash
set -e
cd "$(dirname "$0")"

SDK=/opt/android-sdk
JAR=$SDK/platforms/android-29/android.jar
BUILD=$SDK/build-tools/35.0.0
OUT=build

echo "==> Clean"
rm -rf "$OUT"
mkdir -p "$OUT/gen" "$OUT/classes" "$OUT/dex"

echo "==> Compile resources"
/usr/bin/aapt2 compile --dir app/res -o "$OUT/res.zip"

echo "==> Link resources + manifest"
/usr/bin/aapt2 link -o "$OUT/app-unsigned.apk" \
  -I "$JAR" \
  --manifest app/AndroidManifest.xml \
  --java "$OUT/gen" \
  --min-sdk-version 26 \
  --target-sdk-version 35 \
  --version-code 1 --version-name 1.0 \
  "$OUT/res.zip"

echo "==> Compile Java"
javac --release 11 -encoding UTF-8 -cp "$JAR" -d "$OUT/classes" \
  $(find app/src "$OUT/gen" -name '*.java')

echo "==> Dex"
"$BUILD/d8" --min-api 26 --output "$OUT/dex" \
  $(find "$OUT/classes" -name '*.class')

echo "==> Package dex + assets into APK"
cp "$OUT/app-unsigned.apk" "$OUT/pack.apk"
(
  cd app
  zip -q -r "../$OUT/pack.apk" assets
)
cd "$OUT"
zip -q pack.apk -j dex/classes.dex

echo "==> Align"
/usr/bin/zipalign -f -p 4 pack.apk app-aligned.apk

echo "==> Sign"
keytool -genkeypair -keystore debug.keystore \
  -storepass android -keypass android -alias adclone \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -dname "CN=AdClone, OU=Demo, O=AdClone, L=Local, ST=Local, C=US" >/dev/null 2>&1

/usr/bin/apksigner sign --ks debug.keystore \
  --ks-pass pass:android --key-pass pass:android \
  --out AdClone.apk app-aligned.apk

echo "==> Verify"
/usr/bin/apksigner verify --verbose AdClone.apk | head -5

echo "==> Copy to project root + Downloads"
cp AdClone.apk ../AdClone.apk
cp AdClone.apk /storage/emulated/0/Download/AdClone.apk 2>/dev/null || true

echo ""
echo "BUILD OK: $(pwd)/AdClone.apk ($(du -h AdClone.apk | cut -f1))"
