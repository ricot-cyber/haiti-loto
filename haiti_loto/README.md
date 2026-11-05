# HAITI LOTO

## 1. Supabase
1. SQL Editor → kole `supabase/1_schema_v1.sql` → Run.
2. SQL Editor → kole `supabase/2_schema_v2.sql` → Run.
3. Authentication → Providers → Email → dezaktive **Confirm email**.
4. Authentication → Users → Add user (imèl: `direkte1@haitiloto.app`, yon password). Kopye UUID li.
5. SQL: `insert into profiles (id, role, username) values ('<UUID>', 'director', 'direkte1');`
6. Deploy fonksyon vandè yo (CLI Supabase):
   `supabase functions deploy create-vendor --project-ref jhbfthiuwzuycqociumh`

## 2. App Flutter
```
flutter create haiti_loto
# kopye lib/ ak pubspec.yaml sou pwojè a, epi:
flutter pub get
flutter build apk --release
```
AndroidManifest.xml (andedan `<application>`):
```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.BLUETOOTH"/>
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN"/>
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT"/>
<uses-permission android:name="android.permission.BLUETOOTH_SCAN"/>
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
```
`android/app/build.gradle` → `minSdkVersion 21` (oswa plis).

## 3. Koneksyon
Direktè a ak vandè yo konekte ak username + password. Anndan, username vin `username@haitiloto.app`.

## 4. Sa ki PA konfime (modifye si nesesè)
- To peman yo (`payout_rate` nan SQL) se plasèholdè.
- Loto 4 auto (Op1/Op2) ak Jwe grap loto3 se ipotèz.
- Jwe Pwen pa enplemante.
- Enprime an tèks ESC/POS (pa imaj) — pou enprimant Bluetooth 58mm.
- Delè anile fich = 5 minit pa defo (tab Konfig).
