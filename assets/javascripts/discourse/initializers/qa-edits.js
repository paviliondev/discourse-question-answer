import I18n from "I18n";
import { withPluginApi } from "discourse/lib/plugin-api";

export const ORDER_BY_ACTIVITY_FILTER = "activity";
const pluginId = "discourse-question-answer";

function initPlugin(api) {
  api.registerCustomPostMessageCallback(
    "qa_post_comment_trashed",
    (topicController, message) => {
      const postStream = topicController.get("model.postStream");
      const post = postStream.findLoadedPost(message.id);

      if (post) {
        const commentToDelete = post.comments.find(
          (comment) => comment.id === message.comment_id && !comment.deleted
        );

        if (commentToDelete) {
          commentToDelete.deleted = true;
        }

        post.set("comments_count", message.comments_count);

        topicController.appEvents.trigger("post-stream:refresh", {
          id: post.id,
        });
      }
    }
  );

  api.registerCustomPostMessageCallback(
    "qa_post_commented",
    (topicController, message) => {
      const postStream = topicController.get("model.postStream");
      const post = postStream.findLoadedPost(message.id);

      if (
        post &&
        !post.comments.some((comment) => comment.id === message.comment.id)
      ) {
        post.setProperties({
          comments_count: message.comments_count,
        });

        if (post.comments_count - post.comments.length <= 1) {
          post.comments.pushObject(message.comment);
        }

        topicController.appEvents.trigger("post-stream:refresh", {
          id: post.id,
        });
      }
    }
  );

  api.registerCustomPostMessageCallback(
    "qa_post_voted",
    (topicController, message) => {
      const postStream = topicController.get("model.postStream");
      const post = postStream.findLoadedPost(message.id);

      if (post) {
        const props = {
          qa_vote_count: message.qa_vote_count,
          qa_has_votes: message.qa_has_votes,
        };

        if (topicController.currentUser.id === message.qa_user_voted_id) {
          props.qa_user_voted_direction = message.qa_user_voted_direction;
        }

        post.setProperties(props);

        topicController.appEvents.trigger("post-stream:refresh", {
          id: post.id,
        });
      }
    }
  );

  api.removePostMenuButton("reply", (attrs) => {
    return attrs.qa_has_votes !== undefined && attrs.post_number !== 1;
  });

  api.removePostMenuButton("like", (_attrs, _state, siteSetting) => {
    return siteSetting.qa_disable_like_on_answers;
  });

  api.modifyClass("model:post-stream", {
    pluginId,

    orderStreamByActivity() {
      this.cancelFilter();
      this.set("filter", ORDER_BY_ACTIVITY_FILTER);
      return this.refreshAndJumptoSecondVisible();
    },

    orderStreamByVotes() {
      this.cancelFilter();
      return this.refreshAndJumptoSecondVisible();
    },
  });

  function customLastUnreadUrl(context) {
    if (context.is_qa && context.last_read_post_number) {
      if (context.highest_post_number <= context.last_read_post_number) {
        // link to OP if no unread
        return context.urlForPostNumber(1);
      } else if (
        context.last_read_post_number ===
        context.highest_post_number - 1
      ) {
        return context.urlForPostNumber(context.last_read_post_number + 1);
      } else {
        // sort by activity if user has 2+ unread posts
        return `${context.urlForPostNumber(
          context.last_read_post_number + 1
        )}?filter=activity`;
      }
    }
  }
  api.registerCustomLastUnreadUrlCallback(customLastUnreadUrl);

  api.reopenWidget("post", {
    orderByVotes() {
      this._topicController()
        .model.postStream.orderStreamByVotes()
        .then(() => {
          this._refreshController();
        });
    },

    orderByActivity() {
      this._topicController()
        .model.postStream.orderStreamByActivity()
        .then(() => {
          this._refreshController();
        });
    },

    _refreshController() {
      this._topicController().updateQueryParams();
      this._topicController().appEvents.trigger("qa-topic-updated");
    },

    _topicController() {
      return this.register.lookup("controller:topic");
    },
  });

  api.decorateWidget("post-article:before", (helper) => {
    const result = [];
    const post = helper.getModel();

    if (!post.topic.is_qa) {
      return result;
    }

    const topicController = helper.widget.register.lookup("controller:topic");
    let positionInStream;

    if (
      topicController.replies_to_post_number &&
      parseInt(topicController.replies_to_post_number, 10) !== 1
    ) {
      positionInStream = 2;
    } else {
      positionInStream = 1;
    }

    const answersCount = post.topic.posts_count - 1;

    if (
      answersCount <= 0 ||
      post.id !== post.topic.postStream.stream[positionInStream]
    ) {
      return result;
    }

    result.push(
      helper.h("div.qa-answers-header.small-action", [
        helper.h(
          "span.qa-answers-headers-count",
          I18n.t("qa.topic.answer_count", { count: answersCount })
        ),
        helper.h("span.qa-answers-headers-sort", [
          helper.h("span", I18n.t("qa.topic.sort_by")),
          helper.attach("button", {
            action: "orderByVotes",
            contents: I18n.t("qa.topic.votes"),
            disabled: topicController.filter !== ORDER_BY_ACTIVITY_FILTER,
            className: `qa-answers-headers-sort-votes ${
              topicController.filter === ORDER_BY_ACTIVITY_FILTER
                ? ""
                : "active"
            }`,
          }),
          helper.attach("button", {
            action: "orderByActivity",
            contents: I18n.t("qa.topic.activity"),
            disabled: topicController.filter === ORDER_BY_ACTIVITY_FILTER,
            className: `qa-answers-headers-sort-activity ${
              topicController.filter === ORDER_BY_ACTIVITY_FILTER
                ? "active"
                : ""
            }`,
          }),
        ]),
      ])
    );

    return result;
  });

  api.decorateWidget("post-menu:after", (helper) => {
    const result = [];
    const attrs = helper.widget.attrs;

    if (
      attrs.qa_has_votes !== undefined &&
      !attrs.reply_to_post_number &&
      !helper.widget.state.filteredRepliesShown
    ) {
      result.push(helper.attach("qa-comments", attrs));
    }

    return result;
  });

  api.decorateWidget("post-avatar:after", function (helper) {
    const result = [];
    const model = helper.getModel();

    if (model.topic.is_qa) {
      const qaPost = helper.attach("qa-post", {
        count: model.get("qa_vote_count"),
        post: model,
      });

      result.push(qaPost);
    }

    return result;
  });

  api.includePostAttributes(
    "comments",
    "comments_count",
    "qa_user_voted_direction",
    "qa_has_votes"
  );
}

export default {
  name: "qa-edits",
  initialize(container) {
    const siteSettings = container.lookup("site-settings:main");

    if (!siteSettings.qa_enabled) {
      return;
    }

    withPluginApi("1.2.0", initPlugin);
  },
};
