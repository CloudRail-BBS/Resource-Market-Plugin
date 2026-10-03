import { apiInitializer } from "discourse/lib/api";
import { i18n } from "discourse-i18n";

export default apiInitializer("1.0", (api) => {
  const siteSettings = api.container.lookup("service:site-settings");

  if (!siteSettings.resource_hub_enabled || !siteSettings.resource_hub_nav_link) {
    return;
  }

  api.addNavigationBarItem({
    name: "resource-hub",
    displayName: i18n("resource_hub.nav_title"),
    href: "/resource-hub",
    title: i18n("resource_hub.title"),
    forceActive: (category, args, router) => {
      return router.currentURL?.includes("/resource-hub");
    },
  });
});
