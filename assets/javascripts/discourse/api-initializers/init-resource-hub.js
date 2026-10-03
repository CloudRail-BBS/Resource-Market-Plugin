import { apiInitializer } from "discourse/lib/api";
import { i18n } from "discourse-i18n";

export default apiInitializer((api) => {
  const siteSettings = api.container.lookup("service:site-settings");

  if (!siteSettings.resource_hub_enabled || !siteSettings.resource_hub_nav_link) {
    return;
  }

  // The hub is surfaced in the header navigation bar only.
  //
  // IMPORTANT: `name` is not just an identifier. Discourse's `NavigationItem`
  // renders it verbatim as a class on the generated `<li>`:
  //
  //   <li class={{dConcatClass (if this.active "active") ... this.content.name}}>
  //
  // A nav item named "resource-hub" therefore produced
  // `<li class="... resource-hub">`, which collided with this plugin's own
  // page-level `.resource-hub` rule (`max-width: 1100px; margin: 0 auto;
  // padding: 1.5em 1em 4em`) and stretched the entire navigation bar. The
  // `-link` suffix keeps the two namespaces apart; the page rule is
  // additionally guarded with `div.` — see stylesheets/resource-hub.scss.
  api.addNavigationBarItem({
    name: "resource-hub-link",
    displayName: i18n("resource_hub.nav_title"),
    href: "/resource-hub",
    title: i18n("resource_hub.title"),
    forceActive: (category, args, router) =>
      router.currentURL?.includes("/resource-hub"),
  });
});
