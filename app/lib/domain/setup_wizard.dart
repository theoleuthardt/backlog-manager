const _setupPath = '/setup';

/// Where the route guard must send a signed-in user for the current
/// [pathname]: unfinished users are funnelled into the wizard from every
/// guarded page, finished users are bounced out of it, null means stay.
String? setupRedirect({
  required bool setupCompleted,
  required String pathname,
}) {
  final onWizard = pathname == _setupPath;
  if (!setupCompleted && !onWizard) return _setupPath;
  if (setupCompleted && onWizard) return '/dashboard';
  return null;
}
