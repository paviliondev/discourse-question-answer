import { getOwner } from "discourse-common/lib/get-owner";

export default {
  setupComponent(attrs, component) {
    const currentUser = component.get("currentUser");
    const topic = attrs.topic;
    const qaEnabled = topic.qa_enabled;
    const canCreatePost = topic.get("details.can_create_post");

    let showCreateAnswer = qaEnabled && canCreatePost;
    let label;
    let title;

    if (showCreateAnswer) {
      let topicType = "answer";
      label = `topic.${topicType}.title`;
      title = `topic.${topicType}.help`;
    }

    component.setProperties({
      showCreateAnswer,
      label,
      title,
    });
  },

  actions: {
    answerQuestion() {
      const controller = getOwner(this).lookup("controller:topic");
      controller.send("replyToPost");
    },
  },
};
