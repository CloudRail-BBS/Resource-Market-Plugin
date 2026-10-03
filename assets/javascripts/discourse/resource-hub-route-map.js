// Plugin route maps are collected and applied by
// `frontend/discourse/app/mapping-router.js`.
//
// Two forms are accepted and they are NOT interchangeable:
//
//   export default function () { ... }              // adds to the route tree root
//   export default { resource: "admin", map() {} }  // mounts onto an EXISTING node
//
// The object form is resolved with `tree.findPath(resource)`. When that lookup
// fails the map is dropped *silently* — no error is raised, the route simply
// never exists, and the URL falls through to the catch-all 404. So the object
// form is only for attaching routes to a resource that already exists
// (`admin`, `user`, ...).
//
// `resource-hub` is a brand new top-level route, so there is no node to mount
// onto: this file must export a function, exactly as core does in
// `app/routes/app-route-map.js` and as discourse-cakeday does for `/cakeday`.
//
// Child paths are relative to the parent, so `{ path: "r/:slug" }` resolves to
// `/resource-hub/r/:slug` — matching the server routes in config/routes.rb.
export default function () {
  this.route("resource-hub", { path: "/resource-hub" }, function () {
    this.route("index", { path: "/" });
    this.route("new");
    this.route("show", { path: "r/:slug" });
  });
}
