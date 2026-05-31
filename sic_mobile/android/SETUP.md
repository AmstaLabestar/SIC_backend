# Android Manifest Configuration for SIC Mobile

## Fichiers à configurer

### android/app/src/main/AndroidManifest.xml

Ajouter les permissions suivantes :

```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.USE_BIOMETRIC"/>
<uses-permission android:name="android.permission.USE_FINGERPRINT"/>
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>
<uses-permission android:name="android.permission.CAMERA"/>
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"/>
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE"/>
```

### android/app/build.gradle

Vérifier la configuration minSdkVersion :

```gradle
defaultConfig {
    applicationId "com.sic.mobile"
    minSdkVersion 23
    targetSdkVersion 34
    versionCode 1
    versionName "1.0.0"
}
```

## Notes

- minSdkVersion 23 requis pour local_auth (biométrique)
- minSdkVersion 21 requis pour la plupart des fonctionnalités
