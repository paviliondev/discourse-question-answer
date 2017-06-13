import { withPluginApi } from 'discourse/lib/plugin-api';
import { default as computed } from 'ember-addons/ember-computed-decorators';
import Topic from 'discourse/models/topic';

export default {
  name: 'qa-edits',
  initialize(){
    withPluginApi('0.1', api => {
      api.decorateWidget('post:before', function(helper) {
        const model = helper.getModel();
        if (model && model.get('post_number') !== 1 && model.get('topic.qaEnabled')) {
          return helper.attach('qa-post', {
            count: model.get('vote_count'),
            post: model
          })
        }
      })

      api.attachWidgetAction('post', 'undoPostAction', function(typeId) {
        const post = this.model;
        if (typeId === 5) {
          post.set('topic.voted', false)
        }
        return post.get('actions_summary').findBy('id', typeId).undo(post);
      })
    })

    Topic.reopen({
      @computed('tags', 'category', 'subtype')
      qaEnabled(tags, category, subtype) {
        const qaTags = this.siteSettings.qa_tags.split('|');
        let hasTag = tags.filter(function(t){ return qaTags.indexOf(t) !== -1; }).length > 0;
        let isCategory = category && category.qa_enabled;
        let isSubtype = subtype === 'question';

        return hasTag || isCategory || isSubtype;
      },

      @computed('qaEnabled')
      showQaTip(qaEnabled) {
        return qaEnabled && this.siteSettings.qa_show_topic_tip;
      }
    })
  }
}
