import { CREATE_TOPIC } from "discourse/models/composer";

export default {
  shouldRender(args, component) {
    return (
      component.siteSettings.qa_enabled_globally &&
      args.model.action === CREATE_TOPIC
    );
  },
};
