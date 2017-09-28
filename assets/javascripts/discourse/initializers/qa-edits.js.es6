import { withPluginApi } from 'discourse/lib/plugin-api';
import { default as computed } from 'ember-addons/ember-computed-decorators';

export default {
  name: 'qa-edits',
  initialize(){
    withPluginApi('0.8.10', api => {
      api.decorateWidget('post:before', function(helper) {
        const model = helper.getModel();
        if (model && model.get('post_number') !== 1
            && !model.get('reply_to_post_number')
            && model.get('topic.qa_enabled')) {
          return helper.attach('qa-post', {
            count: model.get('vote_count'),
            post: model
          });
        }
      });

      api.includePostAttributes('reply_to_post_number', 'topic');

      api.addPostClassesCallback((attrs) => {
        if (attrs.topic.qa_enabled && !attrs.firstPost) {
          return attrs.reply_to_post_number ? ["comment"] : ["answer"];
        };
      });

      api.attachWidgetAction('post', 'undoPostAction', function(typeId) {
        const post = this.model;
        if (typeId === 5) {
          post.set('topic.voted', false);
        }
        return post.get('actions_summary').findBy('id', typeId).undo(post);
      });

      api.modifyClass('model:topic', {
        @computed('qa_enabled')
        showQaTip(qaEnabled) {
          return qaEnabled && this.siteSettings.qa_show_topic_tip;
        }
      });

      api.modifyClass('model:post-stream', {
        prependPost(post) {
          const stored = this.storePost(post);
          if (stored) {
            const posts = this.get('posts');
            let insertPost = () => posts.unshiftObject(stored);

            const qaEnabled = this.get('topic.qa_enabled');
            if (qaEnabled && post.post_number === 2 && posts[0].post_number === 1) {
              insertPost = () => posts.insertAt(1, stored);
            };

            insertPost();
          }

          return post;
        },

        appendPost(post) {
          const stored = this.storePost(post);
          if (stored) {
            const posts = this.get('posts');

            if (!posts.includes(stored)) {
              const replyingTo = post.get('reply_to_post_number');
              const qaEnabled = this.get('topic.qa_enabled');
              let insertPost = () => posts.pushObject(stored);

              if (qaEnabled && replyingTo) {
                let passed = false;
                posts.some((p, i) => {
                  if (passed && !p.reply_to_post_number) {
                    insertPost = () => posts.insertAt(i, stored);
                    return true;
                  };

                  if (p.post_number === replyingTo && i < posts.length - 1) {
                    passed = true;
                  };
                });
              };

              if (!this.get('loadingBelow')) {
                this.get('postsWithPlaceholders').appendPost(insertPost);
              } else {
                insertPost();
              }
            }

            if (stored.get('id') !== -1) {
              this.set('lastAppended', stored);
            }
          }
          return post;
        }
      });

      api.modifyClass("component:topic-progress", {
        @computed('postStream.loaded', 'topic.currentPost', 'postStream.filteredPostsCount', 'topic.qa_enabled')
        hideProgress(loaded, currentPost, filteredPostsCount, qaEnabled) {
          return qaEnabled || (!loaded) || (!currentPost) || (!this.site.mobileView && filteredPostsCount < 2);
        },

        @computed('progressPosition', 'topic.last_read_post_id', 'topic.qa_enabled')
        showBackButton(position, lastReadId, qaEnabled) {
          if (!lastReadId || qaEnabled) { return; }

          const stream = this.get('postStream.stream');
          const readPos = stream.indexOf(lastReadId) || 0;
          return (readPos < (stream.length - 1)) && (readPos > position);
        },
      });

      api.modifyClass("component:topic-navigation", {
        _performCheckSize() {
          if (!this.element || this.isDestroying || this.isDestroyed) return;

          if (this.get('topic.qa_enabled')) {
            const info = this.get('info');
            info.setProperties({
              renderTimeline: false,
              renderAdminMenuButton: true
            });
          } else {
            this._super(...arguments);
          }
        }
      });

      api.reopenWidget('post', {
        html(attrs) {
          if (attrs.cloaked) { return ''; }

          if (attrs.topic.qa_enabled && !attrs.firstPost) {
            attrs.replyToUsername = null;
            if (attrs.reply_to_post_number) {
              attrs.canCreatePost = false;
              api.changeWidgetSetting('post-avatar', 'size', 'small');
            } else {
              attrs.replyCount = null;
              api.changeWidgetSetting('post-avatar', 'size', 'large');
            }
          }

          return this.attach('post-article', attrs);
        },
      });
    });
  }
};
