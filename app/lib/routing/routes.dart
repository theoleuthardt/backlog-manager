/// The paths of the route table. Sign-in, the wizard and the loading state
/// are full-window pages; the rest live inside the main window.
abstract final class AppRoutes {
  static const home = '/';
  static const library = '/library';
  static const steam = '/steam';
  static const import = '/import';
  static const export = '/export';
  static const creationTool = '/creation-tool';
  static const appearance = '/appearance';
  static const space = '/space';
  static const settings = '/settings';
  static const setup = '/setup';
  static const signIn = '/sign-in';
  static const loading = '/loading';

  /// The development gallery of the UI kit, debug builds only.
  static const gallery = '/gallery';
}
