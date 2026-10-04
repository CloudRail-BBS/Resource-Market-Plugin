// Single source of truth for turning a resource payload into a URL segment.
//
// The backend accepts a slug OR a numeric id (ResourcesController#fetch_resource),
// and `slug` is always present on a serialized resource — it is a `null: false`
// column. Building the URL inline as
//
//   `/resource-hub/resources/${resource.slug ?? resource.id}/download.json`
//
// is fine until BOTH are missing, at which point the template literal quietly
// yields the literal string "undefined" and the request 404s as
// /resource-hub/resources/undefined/download.json. That failure is silent and
// easy to mistake for a routing or serializer bug, so the check lives here
// instead of being duplicated at each call site.
export function resourceSegment(resource) {
  const key = resource?.slug ?? resource?.id;

  if (key === undefined || key === null || key === "") {
    // Fail loudly in the console; the caller renders the user-facing message.
    // eslint-disable-next-line no-console
    console.error(
      "[resource-hub] resource payload has neither `slug` nor `id` — refusing to " +
        "build a URL. Payload was:",
      resource
    );
    return null;
  }

  return encodeURIComponent(key);
}
