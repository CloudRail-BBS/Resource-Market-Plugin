import { apiInitializer } from "discourse/lib/api";
import { i18n } from "discourse-i18n";

// Route name of the hub landing page, as declared in
// `assets/javascripts/discourse/resource-hub-route-map.js`.
const HUB_ROUTE = "resource-hub.index";

export default apiInitializer((api) => {
  const siteSettings = api.container.lookup("service:site-settings");

  if (!siteSettings.resource_hub_enabled || !siteSettings.resource_hub_nav_link) {
    return;
  }

  // Discourse has two navigation surfaces and a forum renders one or the other
  // depending on the `navigation_menu` site setting:
  //
  //   sidebar (the default since 3.2) -> community section links
  //   header / legacy                 -> navigation bar items
  //
  // Registering only a nav bar item leaves the hub with no visible entry point
  // on any forum using the default sidebar menu, so register on both.
  api.addCommunitySectionLink({
    name: "resource-hub",
    route: HUB_ROUTE,
    title: i18n("resource_hub.title"),
    text: i18n("resource_hub.nav_title"),
    icon: "book-open",
  });

  api.addNavigationBarItem({
    name: "resource-hub",
    displayName: i18n("resource_hub.nav_title"),
    href: "/resource-hub",
    title: i18n("resource_hub.title"),
    forceActive: (category, args, router) =>
      router.currentURL?.includes("/resource-hub"),
  });
});
