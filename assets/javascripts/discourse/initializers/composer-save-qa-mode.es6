import { withPluginApi } from "discourse/lib/plugin-api";

export default {
  name: "composer-topic-qa-mode",

  initialize(container) {
    const siteSettings = container.lookup("site-settings:main");
    const currentUser = container.lookup("current-user:main");

    if (
      siteSettings.qa_enabled &&
      siteSettings.qa_enabled_globally &&
      currentUser
    ) {
      withPluginApi("0.12.3", (api) => {
        api.serializeOnCreate("is_question", "isQuestion");
      });
    }
  },
};
