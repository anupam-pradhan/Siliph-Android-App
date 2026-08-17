# Google Play Store Release & Update Guide

This guide walks through building, signing, and submitting release updates for **Siliph - PDF & File Tools** on the Google Play Console.

---

## 1. Versioning Checklist

Before building an update, update the version in [`pubspec.yaml`](../pubspec.yaml):

```yaml
version: 1.0.0+1
```
- The number before `+` (`1.0.0`) is the **`versionName`** shown to users on Google Play.
- The integer after `+` (`1`) is the **`versionCode`** (must be incremented for every new release update, e.g., `+2`, `+3`, etc.).

---

## 2. Release Signing Setup

### A. Generate an Upload Keystore (One-Time Setup)
If you do not already have an upload keystore:

```bash
keytool -genkey -v -keystore ~/siliph-upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias siliph-upload
```

### B. Configure `android/key.properties`
Copy [`android/key.properties.example`](../android/key.properties.example) to `android/key.properties`:

```properties
storeFile=/Users/yourname/siliph-upload-keystore.jks
storePassword=YOUR_KEYSTORE_PASSWORD
keyAlias=siliph-upload
keyPassword=YOUR_KEY_PASSWORD
```

> **Security Note**: `android/key.properties` and `*.jks` files are strictly excluded in `.gitignore` and must never be committed to source control.

---

## 3. Build the Release Artifacts

### A. Build the Android App Bundle (AAB) — **Preferred for Play Store**
Google Play requires `.aab` (Android App Bundle) format:

```bash
flutter build appbundle --release
```
**Output location**:
📁 `build/app/outputs/bundle/release/app-release.aab`

### B. Build a Release APK (For Local Device Testing)
```bash
flutter build apk --release
```
**Output location**:
📁 `build/app/outputs/flutter-apk/app-release.apk`

---

## 4. Google Play Console Submission Checklist

### 1. App Information & Store Listing
- **App Name**: `Siliph - PDF & File Tools`
- **Short Description**: `All-in-one local-first PDF, image, scanner, OCR and document tools. Private & fast.`
- **Full Description**: See [`docs/store_metadata.md`](store_metadata.md)
- **App Icon (512×512 PNG)**: [`android/app/src/main/ic_launcher-playstore.png`](../android/app/src/main/ic_launcher-playstore.png)
- **Feature Graphic (1024×500 PNG)**
- **Category**: Productivity / Tools

### 2. Privacy Policy URL
- Host the content from [`docs/privacy_policy.md`](privacy_policy.md) on your website or GitHub Pages and paste the public URL in Play Console -> *Policy and programs* -> *App content* -> *Privacy Policy*.

### 3. Data Safety Form Answers
- **Data Collection**: **No** (Siliph does not collect, transmit, or share personal user data or document contents).
- **Network Access**: Local processing on device.
- **Account / Login**: No account required.

### 4. Target SDK & Permissions
- **Target SDK**: Android 16 / API 36 (`targetSdk = 36`, `compileSdk = 36`).
- **Permissions Used**:
  - Camera (`android.permission.CAMERA`) — Only requested when the user opens the Document Scanner.
  - Storage / Photos — Handled via Scoped Storage and system photo picker without broad file system access.

---

## 5. Release Tracks & Rollout

1. In Google Play Console, go to **Production** (or **Internal Testing** / **Closed Testing** for pre-release verification).
2. Click **Create new release**.
3. Upload `build/app/outputs/bundle/release/app-release.aab`.
4. Enter release notes:
   ```text
   - All-in-one local PDF reader, editor, merger, compressor, and scanner.
   - On-device OCR (English & Hindi) and document summarization.
   - Image conversion, exact KB compressor, and archive tools.
   - 100% private and offline-first processing.
   ```
5. Review and roll out to users.
