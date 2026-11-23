import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Preserve the application and upstream license alongside dependency notices.
abstract final class ProjectLicenses {
  static bool _registered = false;

  static final Future<LicenseEntry> license = rootBundle
      .loadString('LICENSE')
      .then((text) => LicenseEntryWithLineBreaks(['Velo', 'Plezy'], text));

  static final Future<LicenseEntry> notoSansSc = rootBundle
      .loadString('assets/fonts/NotoSansSC-OFL.txt')
      .then((text) => LicenseEntryWithLineBreaks(['Noto Sans SC'], text));

  static void register() {
    if (_registered) return;
    _registered = true;
    LicenseRegistry.addLicense(() async* {
      yield await license;
      yield await notoSansSc;
    });
  }
}
