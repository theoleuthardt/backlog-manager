const SETUP_PATH = "/setup";

/**
 * Where RequireAuth must send an authenticated user for the current
 * path: unfinished users are funnelled into the wizard from every guarded
 * page, finished users are bounced out of it, null means stay.
 */
export function setupRedirect(
  user: { setupCompleted: boolean },
  pathname: string,
): string | null {
  const onWizard = pathname === SETUP_PATH;
  if (!user.setupCompleted && !onWizard) return SETUP_PATH;
  if (user.setupCompleted && onWizard) return "/dashboard";
  return null;
}
