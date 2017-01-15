import { withPluginApi } from 'discourse/lib/plugin-api';
import { default as computed, on, observes } from 'ember-addons/ember-computed-decorators';
import TopicController from 'discourse/controllers/topic';
import Composer from 'discourse/models/composer';

export default {
  name: 'qa-edits',
  initialize(){
    withPluginApi('0.1', api => {
      api.decorateWidget('post:before', function(helper) {
        const model = helper.getModel();
        if (model && model.get('post_number') !== 1 && model.get('topic.qa_enabled')) {
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
  }
}
