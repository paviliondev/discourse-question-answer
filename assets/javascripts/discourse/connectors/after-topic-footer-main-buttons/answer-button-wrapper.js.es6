import { getOwner } from 'discourse-common/lib/get-owner';

export default {
  setupComponent(attrs, component) {
    const currentUser = component.get('currentUser');
    const topic = attrs.topic;
    const diary = Discourse.SiteSettings.qa_diary_format;
    const qaEnabled = topic.qa_enabled;
    const canCreatePost = topic.get('details.can_create_post');
    component.set('showCreateAnswer', qaEnabled && canCreatePost && (!diary || topic.user_id == currentUser.id))
  },

  actions: {
    answerQuestion() {
      const controller = getOwner(this).lookup('controller:topic');
      controller.send('replyToPost');
    }
  }
};
