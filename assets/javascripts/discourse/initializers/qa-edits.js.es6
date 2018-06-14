import { withPluginApi } from 'discourse/lib/plugin-api';
import { default as computed, on } from 'ember-addons/ember-computed-decorators';
import { h } from 'virtual-dom';
import { avatarImg, avatarFor } from 'discourse/widgets/post';
import { dateNode, numberNode } from 'discourse/helpers/node';
import { REPLY } from "discourse/models/composer";

export default {
  name: 'qa-edits',
  initialize(){

    if (!Discourse.SiteSettings.qa_enabled) return;

    withPluginApi('0.8.12', api => {

      api.reopenWidget('post-menu', {
        menuItems() {
          const attrs = this.attrs;
          let result = this.siteSettings.post_menu.split('|');

          if (attrs.topic.qa_enabled && !attrs.firstPost) {
            if (this.siteSettings.qa_disable_like_on_answers && !attrs.reply_to_post_number) {
              result = result.filter((b) => b !== 'like');
            }

            if (!attrs.reply_to_post_number) {
              result = result.filter((b) => b !== 'reply');
            }
          }

          return result;
        },
      });

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

      api.addPostMenuButton('comment', (attrs) => {
        if (attrs.canCreatePost &&
            attrs.topic.qa_enabled &&
            !attrs.firstPost &&
            !attrs.reply_to_post_number) {

          let args = {
            action: 'replyToPost',
            title: 'topic.comment.help',
            icon: 'comment',
            className: 'comment create fade-out'
          };

          if (!attrs.mobileView) {
            args.label = 'topic.comment.title';
          }

          return args;
        };
      });

      api.modifyClass('component:composer-actions', {
        @on('init')
        setupPost() {
          const composerPost = this.get('composerModel.post');
          if (composerPost) {
            this.set('pluginPostSnapshot', composerPost);
          }
        },

        @computed('pluginPostSnapshot')
        commenting(post) {
          return post && post.topic.qa_enabled && !post.get('firstPost') && !post.reply_to_post_number;
        },

        computeHeaderContent() {
          let content = this._super();

          if (this.get('commenting') &&
              this.get("action") === REPLY &&
              this.get('options.userAvatar')) {
            content.icon = 'comment';
          }

          return content;
        },

        @computed("options", "canWhisper", "action", 'commenting')
        content(options, canWhisper, action, commenting) {
          let items = this._super(...arguments);

          if (commenting) {
            items.forEach((item) => {
              if (item.id === 'reply_to_topic') {
                item.name = I18n.t('composer.composer_actions.reply_to_question.label');
                item.description = I18n.t('composer.composer_actions.reply_to_question.desc');
              }
              if (item.id === 'reply_to_post') {
                item.icon = 'comment';
                item.name = I18n.t('composer.composer_actions.comment_on_answer.label', {
                  postUsername: this.get('pluginPostSnapshot.username')
                });
                item.description = I18n.t('composer.composer_actions.comment_on_answer.desc');
              }
            })
          }

          return items;
        }
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

      function renderParticipants(userFilters, participants) {
        if (!participants) { return; }

        userFilters = userFilters || [];
        return participants.map(p => {
          return this.attach('topic-participant', p, { state: { toggled: userFilters.includes(p.username) } });
        });
      }

      api.reopenWidget('topic-map-summary', {
        html(attrs, state) {
          if (attrs.topic.qa_enabled) {
            return this.qaMap(attrs, state);
          } else {
            return this._super(attrs, state);
          }
        },

        qaMap(attrs, state) {
          const contents = [];

          contents.push(h('li',
            [
              h('h4', I18n.t('created_lowercase')),
              h('div.topic-map-post.created-at', [
                avatarFor('tiny', {
                  username: attrs.createdByUsername,
                  template: attrs.createdByAvatarTemplate,
                  name: attrs.createdByName
                }),
                dateNode(attrs.topicCreatedAt)
              ])
            ]
          ));

          let lastAnswerUrl = '/t/' + attrs.topic.slug + '/' + attrs.topic.id + '/' + attrs.topic.last_answer_post_number;

          contents.push(h('li',
            h('a', { attributes: { href: lastAnswerUrl } }, [
              h('h4', I18n.t('last_answer_lowercase')),
              h('div.topic-map-post.last-answer', [
                avatarFor('tiny', {
                  username: attrs.topic.last_answerer.username,
                  template: attrs.topic.last_answerer.avatar_template,
                  name: attrs.topic.last_answerer.name
                }),
                dateNode(attrs.topic.last_answered_at)
              ])
            ])
          ));

          contents.push(h('li', [
            numberNode(attrs.topic.answer_count),
            h('h4', I18n.t('answers_lowercase', { count: attrs.topic.answer_count }))
          ]));

          contents.push(h('li.secondary', [
            numberNode(attrs.topicViews, { className: attrs.topicViewsHeat }),
            h('h4', I18n.t('views_lowercase', { count: attrs.topicViews }))
          ]));

          contents.push(h('li.secondary', [
            numberNode(attrs.participantCount),
            h('h4', I18n.t('users_lowercase', { count: attrs.participantCount }))
          ]));

          if (attrs.topicLikeCount) {
            contents.push(h('li.secondary', [
              numberNode(attrs.topicLikeCount),
              h('h4', I18n.t('likes_lowercase', { count: attrs.topicLikeCount }))
            ]));
          }

          if (attrs.topicLinkLength > 0) {
            contents.push(h('li.secondary', [
              numberNode(attrs.topicLinkLength),
              h('h4', I18n.t('links_lowercase', { count: attrs.topicLinkLength }))
            ]));
          }

          if (state.collapsed && attrs.topicPostsCount > 2 && attrs.participants.length > 0) {
            const participants = renderParticipants.call(this, attrs.userFilters, attrs.participants.slice(0, 3));
            contents.push(h('li.avatars', participants));
          }

          const nav = h('nav.buttons', this.attach('button', {
            title: 'topic.toggle_information',
            icon: state.collapsed ? 'chevron-down' : 'chevron-up',
            action: 'toggleMap',
            className: 'btn',
          }));

          return [nav, h('ul.clearfix', contents)];
        }
      })
    });
  }
};
