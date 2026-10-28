## Installing

The installers are not code signed, so macOS and Windows warn on the first start:

- **macOS:** right click the app > Open, or System Settings > Privacy & Security > Open Anyway. Alternatively `xattr -dr com.apple.quarantine /Applications/backlog_manager.app`.
- **Windows:** More info > Run anyway.
- **Linux:** `chmod +x` the AppImage, or install the DEB or RPM with the package manager. The app needs **WebKitGTK 4.1** and libsoup 3 (`libwebkit2gtk-4.1-0` and `libsoup-3.0-0` on Debian and Ubuntu, `webkit2gtk4.1` and `libsoup3` on Fedora; the DEB and RPM pull them in, for the AppImage install them if `ldconfig -p | grep webkit2gtk-4.1` finds nothing). Without it the app does not start.
- **Windows 10:** the Keyforsteam window uses the WebView2 runtime; without it the links open in the browser.
- **Android** (8.0 or newer, `Backlog-Manager_*_android_arm64.apk`): open the APK on the device and allow your browser or file manager to install unknown apps when Android asks. Later versions install themselves from the app once you allow it there.
- **iOS** (16 or newer, `Backlog-Manager_*_ios.ipa`): the IPA is not signed. Sign and install it with a signing tool such as KravaSigner, and do the same with the IPA of each new version; the app tells you when one is out.

