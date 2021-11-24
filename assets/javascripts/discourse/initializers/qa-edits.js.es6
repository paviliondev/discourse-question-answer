import I18n from "I18n";
import { withPluginApi } from "discourse/lib/plugin-api";
import discourseComputed, {
  observes,
  on,
} from "discourse-common/utils/decorators";
import { h } from "virtual-dom";
import { avatarFor } from "discourse/widgets/post";
import { dateNode, numberNode } from "discourse/helpers/node";
import { REPLY } from "discourse/models/composer";
import { setAsAnswer, undoVote, whoVoted } from "../lib/qa-utilities";
import { smallUserAtts } from "discourse/widgets/actions-summary";
import PostsWithPlaceholders from "discourse/lib/posts-with-placeholders";
import { next } from "@ember/runloop";
import Post from "discourse/models/post";

function initPlugin(api) {
  const store = api.container.lookup("store:main");
  const currentUser = api.getCurrentUser();
  const pluginId = "discourse-question-answer";

  api.removePostMenuButton("reply", (attrs) => {
    return attrs.qa_enabled;
  });

  api.removePostMenuButton("like", (attrs) => {
    return attrs.qa_disable_like;
  });

  api.decorateWidget("post:before", (helper) => {
    const result = [];
    const post = helper.getModel();

    if (post.qa_enabled && post.id === post.topic.postStream.stream[1]) {
      const topicController = helper.widget.register.lookup("controller:topic");

      if (topicController.replies_to_post_number) {
        const commentsCount = post.topic
          .get("postStream")
          .postForPostNumber(
            parseInt(topicController.replies_to_post_number, 10)
          ).comments_count;

        if (commentsCount > 0) {
          result.push(
            helper.h(
              "div.qa-comments-count.small-action",
              I18n.t("qa.comments_count", { commentsCount })
            )
          );
        }
      } else {
        const answerCount = post.topic.answer_count;

        if (answerCount > 0) {
          result.push(
            helper.h(
              "div.qa-answer-count.small-action",
              I18n.t("qa.answer_count", { answerCount })
            )
          );
        }
      }
    }

    return result;
  });

  api.reopenWidget("post-menu", {
    openCommentComposer() {
      const post = this.findAncestorModel();

      this.sendWidgetAction("toggleFilteredRepliesView").then(() => {
        this.sendWidgetAction("replyToPost", post).then(() => {
          next(this, () => {
            // FIXME: We have to do this because core on the client side does not allow
            // a post to be a reply to the first post. We need to do this to
            // support comments on the first post.
            const composer = api.container.lookup("controller:composer");

            if (!composer.model.post) {
              composer.model.set("post", post);
            }
          });
        });
      });
    },
  });

  api.decorateWidget("post-menu:after", (helper) => {
    const result = [];
    const post = helper.getModel();

    if (
      post &&
      post.qa_enabled &&
      !post.reply_to_post_number &&
      !helper.widget.state.filteredRepliesShown
    ) {
      const commentLinks = [];

      if (helper.widget.attrs.canCreatePost) {
        commentLinks.push(
          helper.h("div.qa-comment-add", [
            helper.attach("link", {
              className: "qa-comment-add-link",
              action: "openCommentComposer",
              contents: () => I18n.t("qa.post.add_comment"),
            }),
          ])
        );
      }

      const postCommentsLength = post.comments?.length || 0;

      if (postCommentsLength > 0) {
        for (let i = 0; i < postCommentsLength; i++) {
          result.push(helper.attach("qa-comment", post.comments[i]));
        }

        const mostPostCount = post.comments_count - postCommentsLength;

        if (mostPostCount > 0) {
          commentLinks.push(helper.h("span.qa-comment-seperator"));

          commentLinks.push(
            helper.h("div.qa-comment-show-more", [
              helper.attach("link", {
                className: "qa-comment-show-more-link",
                action: "toggleFilteredRepliesView",
                contents: () =>
                  I18n.t("qa.post.show_comment", { count: mostPostCount }),
              }),
            ])
          );
        }
      }

      result.push(helper.h("div.qa-comment-link", commentLinks));
    }

    return result;
  });

  api.decorateWidget("post-avatar:after", function (helper) {
    const result = [];
    const model = helper.getModel();

    if (
      model &&
      model.get("qa_enabled") &&
      model.get("post_number") !== 1 &&
      !model.get("reply_to_post_number")
    ) {
      const qaPost = helper.attach("qa-post", {
        count: model.get("qa_vote_count"),
        post: model,
      });

      result.push(qaPost);
    }

    return result;
  });

  api.includePostAttributes(
    "qa_enabled",
    "topicUserId",
    "oneToMany",
    "comments",
    "qa_disable_like"
  );

  api.addPostClassesCallback((attrs) => {
    if (attrs.qa_enabled) {
      return attrs.reply_to_post_number ? ["qa-is-comment"] : ["qa-is-answer"];
    }
  });

  api.addPostMenuButton("answer", (attrs) => {
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
        className: "answer create fade-out",
      };

      if (!attrs.mobileView) {
        args.label = `topic.${postType}.title`;
      }

      return args;
    }
  });

  // api.addPostMenuButton("comment", (attrs) => {
  //   if (
  //     attrs.canCreatePost &&
  //     attrs.qa_enabled &&
  //     !attrs.reply_to_post_number
  //   ) {
  //     let args = {
  //       action: "openCommentCompose",
  //       title: "topic.comment.help",
  //       icon: "comment",
  //       className: "comment create fade-out",
  //     };
  //
  //     if (!attrs.mobileView) {
  //       args.label = "topic.comment.title";
  //     }
  //
  //     return args;
  //   }
  // });

  api.modifyClass("component:composer-actions", {
    pluginId: pluginId,

    @on("init")
    setupPost() {
      const composerPost = this.get("composerModel.post");
      if (composerPost) {
        this.set("pluginPostSnapshot", composerPost);
      }
    },

    @discourseComputed("pluginPostSnapshot")
    commenting(post) {
      return post && post.get("topic.qa_enabled") && !post.reply_to_post_number;
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
        items.forEach((item) => {
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
                postUsername: this.get("pluginPostSnapshot.username"),
              }
            );
            item.description = I18n.t(
              "composer.composer_actions.comment_on_answer.desc"
            );
          }
        });
      }

      return items;
    },
  });

  api.reopenWidget("post-body", {
    buildKey: (attrs) => `post-body-${attrs.id}`,

    defaultState(attrs) {
      let state = this._super(...arguments);
      if (attrs.qa_enabled) {
        state = $.extend({}, state, { voters: [] });
      }
      return state;
    },

    html(attrs, state) {
      let contents = this._super(...arguments);

      const model = this.findAncestorModel();
      let action = model.actionByName["vote"];

      if (action && attrs.qa_enabled) {
        let voteLinks = [];

        attrs.actionsSummary = attrs.actionsSummary.filter(
          (as) => as.action !== "vote"
        );

        if (action.acted && action.can_undo) {
          voteLinks.push(
            this.attach("link", {
              action: "undoUserVote",
              rawLabel: I18n.t("post.actions.undo.vote"),
            })
          );
        }

        // if (action.count > 0) {
        //   voteLinks.push(
        //     this.attach("link", {
        //       action: "toggleWhoVoted",
        //       rawLabel: `${action.count} ${I18n.t("post.actions.people.vote")}`,
        //     })
        //   );
        // }
        //
        // if (voteLinks.length) {
        //   let voteContents = [h("div.vote-links", voteLinks)];
        //
        //   if (state.voters.length) {
        //     voteContents.push(
        //       this.attach("small-user-list", {
        //         users: state.voters,
        //         listClassName: "voters",
        //       })
        //     );
        //   }
        //
        //   let actionSummaryIndex = contents
        //     .map((w) => w && w.name)
        //     .indexOf("actions-summary");
        //   let insertAt = actionSummaryIndex + 1;
        //
        //   contents.splice(
        //     insertAt - 1,
        //     0,
        //     h("div.vote-container", voteContents)
        //   );
        // }
      }

      return contents;
    },

    undoUserVote() {
      const post = this.findAncestorModel();
      const user = this.currentUser;
      const vote = {
        user_id: user.id,
        post_id: post.id,
        direction: "up",
      };

      undoVote({ vote }).then((result) => {
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
        post_id: attrs.id,
      };

      whoVoted(post).then((result) => {
        if (result.voters) {
          state.voters = result.voters.map(smallUserAtts);
          this.scheduleRerender();
        }
      });
    },
  });

  api.modifyClass("model:topic", {
    pluginId: pluginId,

    @discourseComputed("qa_enabled")
    showQaTip(qaEnabled) {
      return qaEnabled && this.siteSettings.qa_show_topic_tip;
    },
  });

  api.modifyClass("component:topic-footer-buttons", {
    pluginId: pluginId,

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
    },
  });

  api.reopenWidget("post", {
    openCommentCompose() {
      this.sendWidgetAction("replyToPost", this.model).then(() => {
        next(this, () => {
          const composer = api.container.lookup("controller:composer");

          if (!composer.model.post) {
            composer.model.set("post", this.model);
          }
        });
      });
    },
  });

  function renderParticipants(userFilters, participants) {
    if (!participants) {
      return;
    }

    userFilters = userFilters || [];
    return participants.map((p) => {
      return this.attach("topic-participant", p, {
        state: { toggled: userFilters.includes(p.username) },
      });
    });
  }

  // Disable this function override and figure out how we can extend this in core
  // api.reopenWidget("topic-map-summary", {
  //   html(attrs, state) {
  //     if (attrs.qa_enabled) {
  //       return this.qaMap(attrs, state);
  //     } else {
  //       return this._super(attrs, state);
  //     }
  //   },
  //
  //   qaMap(attrs, state) {
  //     const contents = [];
  //
  //     contents.push(
  //       h("li", [
  //         h("h4", I18n.t("created_lowercase")),
  //         h("div.topic-map-post.created-at", [
  //           avatarFor("tiny", {
  //             username: attrs.createdByUsername,
  //             template: attrs.createdByAvatarTemplate,
  //             name: attrs.createdByName,
  //           }),
  //           dateNode(attrs.topicCreatedAt),
  //         ]),
  //       ])
  //     );
  //
  //     let lastAnswerUrl = attrs.topicUrl + "/" + attrs.last_answer_post_number;
  //     let postType = attrs.oneToMany ? "one_to_many" : "answer";
  //
  //     contents.push(
  //       h(
  //         "li",
  //         h("a", { attributes: { href: lastAnswerUrl } }, [
  //           h("h4", I18n.t(`last_${postType}_lowercase`)),
  //           h("div.topic-map-post.last-answer", [
  //             avatarFor("tiny", {
  //               username: attrs.last_answerer.username,
  //               template: attrs.last_answerer.avatar_template,
  //               name: attrs.last_answerer.name,
  //             }),
  //             dateNode(attrs.last_answered_at),
  //           ]),
  //         ])
  //       )
  //     );
  //
  //     contents.push(
  //       h("li", [
  //         numberNode(attrs.answer_count),
  //         h(
  //           "h4",
  //           I18n.t(`${postType}_lowercase`, { count: attrs.answer_count })
  //         ),
  //       ])
  //     );
  //
  //     contents.push(
  //       h("li.secondary", [
  //         numberNode(attrs.topicViews, { className: attrs.topicViewsHeat }),
  //         h("h4", I18n.t("views_lowercase", { count: attrs.topicViews })),
  //       ])
  //     );
  //
  //     contents.push(
  //       h("li.secondary", [
  //         numberNode(attrs.participantCount),
  //         h("h4", I18n.t("users_lowercase", { count: attrs.participantCount })),
  //       ])
  //     );
  //
  //     if (attrs.topicLikeCount) {
  //       contents.push(
  //         h("li.secondary", [
  //           numberNode(attrs.topicLikeCount),
  //           h("h4", I18n.t("likes_lowercase", { count: attrs.topicLikeCount })),
  //         ])
  //       );
  //     }
  //
  //     if (attrs.topicLinkLength > 0) {
  //       contents.push(
  //         h("li.secondary", [
  //           numberNode(attrs.topicLinkLength),
  //           h(
  //             "h4",
  //             I18n.t("links_lowercase", { count: attrs.topicLinkLength })
  //           ),
  //         ])
  //       );
  //     }
  //
  //     if (
  //       state.collapsed &&
  //       attrs.topicPostsCount > 2 &&
  //       attrs.participants.length > 0
  //     ) {
  //       const participants = renderParticipants.call(
  //         this,
  //         attrs.userFilters,
  //         attrs.participants.slice(0, 3)
  //       );
  //       contents.push(h("li.avatars", participants));
  //     }
  //
  //     const nav = h(
  //       "nav.buttons",
  //       this.attach("button", {
  //         title: "topic.toggle_information",
  //         icon: state.collapsed ? "chevron-down" : "chevron-up",
  //         action: "toggleMap",
  //         className: "btn",
  //       })
  //     );
  //
  //     return [nav, h("ul.clearfix", contents)];
  //   },
  // });

  api.reopenWidget("post-admin-menu", {
    html() {
      const result = this._super(...arguments);

      if (this.attrs.qa_enabled && this.attrs.reply_to_post_number) {
        const button = {
          label: "qa.set_as_answer",
          action: "setAsAnswer",
          className: "popup-menu-button",
          secondaryAction: "closeAdminMenu",
        };

        result.children.push(this.attach("post-admin-menu-button", button));
      }

      return result;
    },

    setAsAnswer() {
      const post = this.findAncestorModel();

      setAsAnswer(post).then((result) => {
        location.reload();
      });
    },
  });
}

export default {
  name: "qa-edits",
  initialize(container) {
    const siteSettings = container.lookup("site-settings:main");

    if (!siteSettings.qa_enabled) {
      return;
    }

    withPluginApi("0.13.0", initPlugin);
  },
};
