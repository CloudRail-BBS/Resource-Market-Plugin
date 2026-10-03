// Parent template for the `resource-hub` route.
//
// A route that has children MUST render an `{{outlet}}`, otherwise the child
// templates (`resource-hub/index`, `resource-hub/new`, `resource-hub/show`)
// have nowhere to render and the page comes up blank even though the route
// itself resolved. Core does the same thing — `templates/user.gjs` ends with
// `{{outlet}}` — and so does discourse-cakeday's `templates/cakeday.gjs`.
export default <template>{{outlet}}</template>;
