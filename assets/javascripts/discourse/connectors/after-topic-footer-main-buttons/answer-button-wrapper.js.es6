import { getOwner } from "discourse-common/lib/get-owner";

export default {
  setupComponent(attrs, component) {
    const currentUser = component.get("currentUser");
    const topic = attrs.topic;
    const oneToMany = topic.category && topic.category.qa_one_to_many;
    const qaEnabled = topic.qa_enabled;
    const canCreatePost = topic.get("details.can_create_post");

    let showCreateAnswer =
      qaEnabled &&
      canCreatePost &&
      (!oneToMany || topic.user_id == currentUser.id);
    let label;
    let title;

    if (showCreateAnswer) {
      let topicType = oneToMany ? "one_to_many" : "answer";
      label = `topic.${topicType}.title`;
      title = `topic.${topicType}.help`;
    }

    component.setProperties({
      showCreateAnswer,
      label,
      title
    });
  },

  actions: {
    answerQuestion() {
      const controller = getOwner(this).lookup("controller:topic");
      controller.send("replyToPost");
    }
  }
};
