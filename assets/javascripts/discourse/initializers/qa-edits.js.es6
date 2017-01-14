import { withPluginApi } from 'discourse/lib/plugin-api';
import { default as computed, on, observes } from 'ember-addons/ember-computed-decorators';
import TopicController from 'discourse/controllers/topic';
import Composer from 'discourse/models/composer';

export default {
  name: 'qa-edits',
  initialize(){
    withPluginApi('0.1', api => {
      api.includePostAttributes('qa_count')
      api.decorateWidget('post:before', function(helper) {
        const model = helper.getModel();
        if (model && model.get('topic.qa_enabled')) {
          return helper.attach('qa-post', {
            count: model.get('qa_count'),
            post: model
          })
        }
      })
    })

    TopicController.reopen({
      @observes('model.postStream.loaded')
      subscribeToQAUpdates() {
        let model = this.get('model'),
            postStream = model.get('postStream'),
            refresh = (args) => this.appEvents.trigger('post-stream:refresh', args);

        if (model.qa_enabled && postStream.get('loaded')) {
          this.messageBus.subscribe("/topic/" + model.id, function(data) {
            if (data.type === 'revised') {
              if (data.post_id !== undefined) {
                postStream.triggerChangedPost(data.post_id, data.updated_at).then(() =>
                  refresh({ id: data.post_id })
                );
              }
            }
          })
        }
      }
    })
  }
}
