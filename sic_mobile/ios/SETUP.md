# iOS Configuration for SIC Mobile

## Fichiers à configurer

### ios/Runner/Info.plist

Ajouter les clés suivantes :

```xml
<!-- Permissions -->
<key>NSFaceIDUsageDescription</key>
<string>Nous utilisons Face ID pour vous authentifier de manière sécurisée</string>

<key>NSCameraUsageDescription</key>
<string>Nous utilisons la caméra pour prendre des photos de vos documents KYC</string>

<key>NSPhotoLibraryUsageDescription</key>
<string>Nous accédons à vos photos pour sélectionner des documents</string>

<!-- App Transport Security -->
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <true/>
</dict>
```

### ios/Runner/Runner.entitlements

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.developer.applesignin</key>
    <array>
        <string>Default</string>
    </array>
</dict>
</plist>
```

## Notes

- iOS 12.0+ requis pour la plupart des fonctionnalités
- iOS 13.0+ requis pour local_auth (biométrique)
