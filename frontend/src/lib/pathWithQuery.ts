type QueryValue = string | number | boolean | null | undefined;

/**
 * A path with the given values as its query string; undefined and null
 * values are left out.
 */
export function pathWithQuery(
  pathname: string,
  query: Record<string, QueryValue>,
) {
  const params = new URLSearchParams();
  for (const [key, value] of Object.entries(query)) {
    if (value !== undefined && value !== null) params.set(key, String(value));
  }
  const search = params.toString();
  return search ? `${pathname}?${search}` : pathname;
}
