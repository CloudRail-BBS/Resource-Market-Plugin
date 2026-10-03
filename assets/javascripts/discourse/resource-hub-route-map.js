export default {
  resource: "resource-hub",
  path: "/resource-hub",
  map() {
    this.route("index", { path: "/" });
    this.route("new", { path: "/new" });
    this.route("show", { path: "/r/:slug" });
  },
};
