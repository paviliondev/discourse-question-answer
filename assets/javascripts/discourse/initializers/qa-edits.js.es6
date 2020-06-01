import { withPluginApi } from "discourse/lib/plugin-api";
import discourseComputed, {
  on,
  observes
} from "discourse-common/utils/decorators";
import { h } from "virtual-dom";
import { avatarFor } from "discourse/widgets/post";
import { dateNode, numberNode } from "discourse/helpers/node";
import { REPLY } from "discourse/models/composer";
import { undoVote, whoVoted } from "../lib/qa-utilities";
import { avatarAtts } from "discourse/widgets/actions-summary";
import PostsWithPlaceholders from "discourse/lib/posts-with-placeholders";

function initPlugin(api) {
  const store = api.container.lookup("store:main");
  const currentUser = api.getCurrentUser();

  api.reopenWidget("post-menu", {
    menuItems() {
      const attrs = this.attrs;
      let result = this.siteSettings.post_menu.split("|");
      if (attrs.qa_enabled) {
        const post = this.findAncestorModel();
        const category = post.topic.category;

        let type = attrs.firstPost
          ? "questions"
          : attrs.reply_to_post_number
          ? "comments"
          : "answers";

        let disableLikes =
          this.siteSettings.qa_disable_like_on_answers ||
          (category && category[`qa_disable_like_on_${type}`]);

        if (disableLikes) {
          result = result.filter(b => b !== "like");
        }

        result = result.filter(b => b !== "reply");
      }
      return result;
    }
  });

  api.decorateWidget("post:before", function(helper) {
    const model = helper.getModel();

    if (
      model &&
      model.get("post_number") !== 1 &&
      !model.get("reply_to_post_number") &&
      model.get("qa_enabled")
    ) {
      return helper.attach("qa-post", {
        count: model.get("qa_vote_count"),
        post: model
      });
    }
  });

  api.decorateWidget("post:after", function(helper) {
    const model = helper.getModel();
    if (model.attachCommentToggle && model.hiddenComments > 0) {
      let type =
        Number(helper.widget.siteSettings.qa_comments_default) > 0 ? "more" : "all";
      return helper.attach("link", {
        action: "showComments",
        actionParam: model.answerId,
        rawLabel: I18n.t(`topic.comment.show_comments.${type}`, {
          count: model.hiddenComments
        }),
        className: "show-comments"
      });
    }
  });

  api.reopenWidget("post-stream", {
    buildKey: () => "post-stream",

    defaultState(attrs, state) {
      let defaultState = this._super(attrs, state);
      defaultState["showComments"] = [];
      return defaultState;
    },

    showComments(answerId) {
      let showComments = this.state.showComments;
      if (showComments.indexOf(answerId) === -1) {
        showComments.push(answerId);
        this.state.showComments = showComments;
        this.appEvents.trigger("post-stream:refresh", { force: true });
      }
    },

    html(attrs, state) {
      let posts = attrs.posts || [];
      let postArray = this.capabilities.isAndroid ? posts : posts.toArray();

      if (postArray[0] && postArray[0].qa_enabled) {
        let answerId = null;
        let showComments = state.showComments;
        let defaultComments = Number(this.siteSettings.qa_comments_default);
        let commentCount = 0;
        let lastVisible = null;

        postArray.forEach((p, i) => {
          p["oneToMany"] = p.topic.category.qa_one_to_many;

          if (p.reply_to_post_number) {
            commentCount++;
            p["comment"] = true;
            p["showComment"] =
              showComments.indexOf(answerId) > -1 ||
              commentCount <= defaultComments;
            p["answerId"] = answerId;
            p["attachCommentToggle"] = false;

            if (p["showComment"]) lastVisible = i;

            if (
              (!postArray[i + 1] ||
                !postArray[i + 1].reply_to_post_number) &&
              !p["showComment"]
            ) {
              postArray[lastVisible]["answerId"] = answerId;
              postArray[lastVisible]["attachCommentToggle"] = true;
              postArray[lastVisible]["hiddenComments"] =
                commentCount - defaultComments;
            }
          } else {
            p["attachCommentToggle"] = !p["oneToMany"];
            p["topicUserId"] = p.topic.user_id;
            answerId = p.id;
            commentCount = 0;
            lastVisible = i;
          }
        });

        if (this.capabilities.isAndroid) {
          attrs.posts = postArray;
        } else {
          attrs.posts = PostsWithPlaceholders.create({
            posts: postArray,
            store
          });
        }
      }

      return this._super(attrs, state);
    }
  });

  api.includePostAttributes(
    "qa_enabled",
    "reply_to_post_number",
    "comment",
    "showComment",
    "answerId",
    "lastComment",
    "last_answerer",
    "last_answered_at",
    "answer_count",
    "last_answer_post_number",
    "last_answerer",
    "topicUserId",
    "oneToMany"
  );

  api.addPostClassesCallback(attrs => {
    if (attrs.qa_enabled && !attrs.firstPost) {
      if (attrs.comment) {
        let classes = ["comment"];
        if (attrs.showComment) {
          classes.push("show");
        }
        return classes;
      } else {
        return ["answer"];
      }
    }
  });

  api.addPostMenuButton("answer", attrs => {
    if (
      attrs.canCreatePost &&
      attrs.qa_enabled &&
      attrs.firstPost &&
      (!attrs.oneToMany || attrs.topicUserId === currentUser.id)
    ) {
      let postType = attrs.oneToMany ? "one_to_many" : "answer";

      let args = {
        action: "replyToPost",
        title: `topic.${postType}.help`,
        icon: "reply",
        className: "answer create fade-out"
      };

      if (!attrs.mobileView) {
        args.label = `topic.${postType}.title`;
      }

      return args;
    }
  });

  api.addPostMenuButton("comment", attrs => {
    if (
      attrs.canCreatePost &&
      attrs.qa_enabled &&
      !attrs.firstPost &&
      !attrs.reply_to_post_number
    ) {
      let args = {
        action: "openCommentCompose",
        title: "topic.comment.help",
        icon: "comment",
        className: "comment create fade-out"
      };

      if (!attrs.mobileView) {
        args.label = "topic.comment.title";
      }

      return args;
    }
  });

  api.modifyClass("component:composer-actions", {
    @on("init")
    setupPost() {
      const composerPost = this.get("composerModel.post");
      if (composerPost) {
        this.set("pluginPostSnapshot", composerPost);
      }
    },

    @discourseComputed("pluginPostSnapshot")
    commenting(post) {
      return (
        post &&
        post.get("topic.qa_enabled") &&
        !post.get("firstPost") &&
        !post.reply_to_post_number
      );
    },

    computeHeaderContent() {
      let content = this._super();

      if (
        this.get("commenting") &&
        this.get("action") === REPLY &&
        this.get("options.userAvatar")
      ) {
        content.icon = "comment";
      }

      return content;
    },

    @discourseComputed("options", "canWhisper", "action", "commenting")
    content(options, canWhisper, action, commenting) {
      let items = this._super(...arguments);

      if (commenting) {
        items.forEach(item => {
          if (item.id === "reply_to_topic") {
            item.name = I18n.t(
              "composer.composer_actions.reply_to_question.label"
            );
            item.description = I18n.t(
              "composer.composer_actions.reply_to_question.desc"
            );
          }
          if (item.id === "reply_to_post") {
            item.icon = "comment";
            item.name = I18n.t(
              "composer.composer_actions.comment_on_answer.label",
              {
                postUsername: this.get("pluginPostSnapshot.username")
              }
            );
            item.description = I18n.t(
              "composer.composer_actions.comment_on_answer.desc"
            );
          }
        });
      }

      return items;
    }
  });

  api.reopenWidget("post-body", {
    buildKey: attrs => `post-body-${attrs.id}`,

    defaultState(attrs) {
      let state = this._super();
      if (attrs.qa_enabled) {
        state = $.extend({}, state, { voters: [] });
      }
      return state;
    },

    html(attrs, state) {
      let contents = this._super(attrs, state);
      const model = this.findAncestorModel();
      let action = model.actionByName["vote"];

      if (action && attrs.qa_enabled) {
        let voteLinks = [];

        attrs.actionsSummary = attrs.actionsSummary.filter(
          as => as.action !== "vote"
        );

        if (action.acted && action.can_undo) {
          voteLinks.push(
            this.attach("link", {
              action: "undoUserVote",
              rawLabel: I18n.t("post.actions.undo.vote")
            })
          );
        }

        if (action.count > 0) {
          voteLinks.push(
            this.attach("link", {
              action: "toggleWhoVoted",
              rawLabel: `${action.count} ${I18n.t(
                "post.actions.people.vote"
              )}`
            })
          );
        }

        if (voteLinks.length) {
          let voteContents = [h("div.vote-links", voteLinks)];

          if (state.voters.length) {
            voteContents.push(
              this.attach("small-user-list", {
                users: state.voters,
                listClassName: "voters"
              })
            );
          }

          let actionSummaryIndex = contents
            .map(w => w && w.name)
            .indexOf("actions-summary");
          let insertAt = actionSummaryIndex + 1;

          contents.splice(
            insertAt - 1,
            0,
            h("div.vote-container", voteContents)
          );
        }
      }

      return contents;
    },

    undoUserVote() {
      const post = this.findAncestorModel();
      const user = this.currentUser;
      const vote = {
        user_id: user.id,
        post_id: post.id,
        direction: "up"
      };

      undoVote({ vote }).then(result => {
        if (result.success) {
          post.set("topic.voted", false);
        }
      });
    },

    toggleWhoVoted() {
      const state = this.state;
      if (state.voters.length) {
        state.voters = [];
      } else {
        return this.getWhoVoted();
      }
    },

    getWhoVoted() {
      const { attrs, state } = this;
      const post = {
        post_id: attrs.id
      };

      whoVoted(post).then(result => {
        if (result.voters) {
          state.voters = result.voters.map(avatarAtts);
          this.scheduleRerender();
        }
      });
    }
  });

  api.modifyClass("model:topic", {
    @discourseComputed("qa_enabled")
    showQaTip(qaEnabled) {
      return qaEnabled && this.siteSettings.qa_show_topic_tip;
    }
  });

  api.modifyClass("component:topic-footer-buttons", {
    @on("didInsertElement")
    @observes("topic.qa_enabled")
    hideFooterReply() {
      const qaEnabled = this.get("topic.qa_enabled");
      Ember.run.scheduleOnce("afterRender", () => {
        $(
          ".topic-footer-main-buttons > button.create:not(.answer)",
          this.element
        ).toggle(!qaEnabled);
      });
    }
  });

  api.modifyClass("model:post-stream", {
    prependPost(post) {
      const stored = this.storePost(post);
      if (stored) {
        const posts = this.get("posts");
        let insertPost = () => posts.unshiftObject(stored);

        const qaEnabled = this.get("topic.qa_enabled");
        if (
          qaEnabled &&
          post.post_number === 2 &&
          posts[0].post_number === 1
        ) {
          insertPost = () => posts.insertAt(1, stored);
        }

        insertPost();
      }

      return post;
    },

    appendPost(post) {
      const stored = this.storePost(post);
      if (stored) {
        const posts = this.get("posts");

        if (!posts.includes(stored)) {
          const replyingTo = post.get("reply_to_post_number");
          const qaEnabled = this.get("topic.qa_enabled");
          let insertPost = () => posts.pushObject(stored);

          if (qaEnabled && replyingTo) {
            let passed = false;
            posts.some((p, i) => {
              if (passed && !p.reply_to_post_number) {
                insertPost = () => posts.insertAt(i, stored);
                return true;
              }

              if (p.post_number === replyingTo && i < posts.length - 1) {
                passed = true;
              }
            });
          }

          if (!this.get("loadingBelow")) {
            this.get("postsWithPlaceholders").appendPost(insertPost);
          } else {
            insertPost();
          }
        }

        if (stored.get("id") !== -1) {
          this.set("lastAppended", stored);
        }
      }
      return post;
    }
  });

  api.modifyClass("component:topic-progress", {
    @discourseComputed(
      "postStream.loaded",
      "topic.currentPost",
      "postStream.filteredPostsCount",
      "topic.qa_enabled"
    )
    hideProgress(loaded, currentPost, filteredPostsCount, qaEnabled) {
      return (
        qaEnabled ||
        !loaded ||
        !currentPost ||
        (!this.site.mobileView && filteredPostsCount < 2)
      );
    },

    @discourseComputed(
      "progressPosition",
      "topic.last_read_post_id",
      "topic.qa_enabled"
    )
    showBackButton(position, lastReadId, qaEnabled) {
      if (!lastReadId || qaEnabled) {
        return;
      }

      const stream = this.get("postStream.stream");
      const readPos = stream.indexOf(lastReadId) || 0;
      return readPos < stream.length - 1 && readPos > position;
    }
  });

  api.modifyClass("component:topic-navigation", {
    _performCheckSize() {
      if (!this.element || this.isDestroying || this.isDestroyed) return;

      if (this.get("topic.qa_enabled")) {
        const info = this.get("info");
        info.setProperties({
          renderTimeline: false,
          renderAdminMenuButton: true
        });
      } else {
        this._super(...arguments);
      }
    }
  });

  api.reopenWidget("post", {
    html(attrs) {
      if (attrs.cloaked) {
        return "";
      }

      if (attrs.qa_enabled && !attrs.firstPost) {
        attrs.replyToUsername = null;
        if (attrs.reply_to_post_number) {
          attrs.canCreatePost = false;
          api.changeWidgetSetting("post-avatar", "size", "small");
        } else {
          attrs.replyCount = null;
          api.changeWidgetSetting("post-avatar", "size", "large");
        }
      }

      return this.attach("post-article", attrs);
    },

    openCommentCompose() {
      this.sendWidgetAction("showComments", this.attrs.id);
      this.sendWidgetAction("replyToPost", this.model);
    }
  });

  function renderParticipants(userFilters, participants) {
    if (!participants) {
      return;
    }

    userFilters = userFilters || [];
    return participants.map(p => {
      return this.attach("topic-participant", p, {
        state: { toggled: userFilters.includes(p.username) }
      });
    });
  }

  api.reopenWidget("topic-map-summary", {
    html(attrs, state) {
      if (attrs.qa_enabled) {
        return this.qaMap(attrs, state);
      } else {
        return this._super(attrs, state);
      }
    },

    qaMap(attrs, state) {
      const contents = [];

      contents.push(
        h("li", [
          h("h4", I18n.t("created_lowercase")),
          h("div.topic-map-post.created-at", [
            avatarFor("tiny", {
              username: attrs.createdByUsername,
              template: attrs.createdByAvatarTemplate,
              name: attrs.createdByName
            }),
            dateNode(attrs.topicCreatedAt)
          ])
        ])
      );

      let lastAnswerUrl =
        attrs.topicUrl + "/" + attrs.last_answer_post_number;
      let postType = attrs.oneToMany ? "one_to_many" : "answer";

      contents.push(
        h(
          "li",
          h("a", { attributes: { href: lastAnswerUrl } }, [
            h("h4", I18n.t(`last_${postType}_lowercase`)),
            h("div.topic-map-post.last-answer", [
              avatarFor("tiny", {
                username: attrs.last_answerer.username,
                template: attrs.last_answerer.avatar_template,
                name: attrs.last_answerer.name
              }),
              dateNode(attrs.last_answered_at)
            ])
          ])
        )
      );

      contents.push(
        h("li", [
          numberNode(attrs.answer_count),
          h(
            "h4",
            I18n.t(`${postType}_lowercase`, { count: attrs.answer_count })
          )
        ])
      );

      contents.push(
        h("li.secondary", [
          numberNode(attrs.topicViews, { className: attrs.topicViewsHeat }),
          h("h4", I18n.t("views_lowercase", { count: attrs.topicViews }))
        ])
      );

      contents.push(
        h("li.secondary", [
          numberNode(attrs.participantCount),
          h(
            "h4",
            I18n.t("users_lowercase", { count: attrs.participantCount })
          )
        ])
      );

      if (attrs.topicLikeCount) {
        contents.push(
          h("li.secondary", [
            numberNode(attrs.topicLikeCount),
            h(
              "h4",
              I18n.t("likes_lowercase", { count: attrs.topicLikeCount })
            )
          ])
        );
      }

      if (attrs.topicLinkLength > 0) {
        contents.push(
          h("li.secondary", [
            numberNode(attrs.topicLinkLength),
            h(
              "h4",
              I18n.t("links_lowercase", { count: attrs.topicLinkLength })
            )
          ])
        );
      }

      if (
        state.collapsed &&
        attrs.topicPostsCount > 2 &&
        attrs.participants.length > 0
      ) {
        const participants = renderParticipants.call(
          this,
          attrs.userFilters,
          attrs.participants.slice(0, 3)
        );
        contents.push(h("li.avatars", participants));
      }

      const nav = h(
        "nav.buttons",
        this.attach("button", {
          title: "topic.toggle_information",
          icon: state.collapsed ? "chevron-down" : "chevron-up",
          action: "toggleMap",
          className: "btn"
        })
      );

      return [nav, h("ul.clearfix", contents)];
    }
  });
}

export default {
  name: "qa-edits",
  initialize(container) {
    const siteSettings = container.lookup("site-settings:main");

    if (!siteSettings.qa_enabled) return;

    withPluginApi("0.8.12", initPlugin);
  }
};
