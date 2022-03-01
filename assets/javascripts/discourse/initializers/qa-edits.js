import I18n from "I18n";
import { withPluginApi } from "discourse/lib/plugin-api";

function initPlugin(api) {
  api.removePostMenuButton("reply", (attrs) => {
    return attrs.qa_enabled;
  });

  api.removePostMenuButton("like", (attrs) => {
    return attrs.qa_disable_like;
  });

  api.decorateWidget("post:before", (helper) => {
    const result = [];
    const post = helper.getModel();

    if (post.qa_enabled) {
      const topicController = helper.widget.register.lookup("controller:topic");

      const positionInStream =
        topicController.replies_to_post_number &&
        parseInt(topicController.replies_to_post_number, 10) !== 1
          ? 2
          : 1;

      if (post.id === post.topic.postStream.stream[positionInStream]) {
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
                I18n.t("qa.comments_count", { count: commentsCount })
              )
            );
          }
        } else {
          const answerCount = post.topic.answer_count;

          if (answerCount > 0) {
            result.push(
              helper.h(
                "div.qa-answer-count.small-action",
                I18n.t("qa.answer_count", { count: answerCount })
              )
            );
          }
        }
      }
    }

    return result;
  });

  api.decorateWidget("post-menu:after", (helper) => {
    const result = [];
    const attrs = helper.widget.attrs;

    if (
      attrs.qa_enabled &&
      !attrs.reply_to_post_number &&
      !helper.widget.state.filteredRepliesShown
    ) {
      result.push(helper.attach("qa-comments", attrs));
    }

    return result;
  });

  const widgetToDecorate = api.container.lookup("site:main").mobileView
    ? "post-article:before"
    : "post-avatar:after";

  api.decorateWidget(widgetToDecorate, function (helper) {
    const result = [];
    const model = helper.getModel();

    if (
      model &&
      model.get("qa_enabled") &&
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
    "comments",
    "comments_count",
    "qa_disable_like",
    "qa_user_voted_direction",
    "qa_has_votes"
  );

  api.addPostClassesCallback((attrs) => {
    if (attrs.qa_enabled) {
      return attrs.reply_to_post_number ? ["qa-is-comment"] : ["qa-is-answer"];
    }
  });

  api.addPostMenuButton("answer", (attrs) => {
    if (attrs.canCreatePost && attrs.qa_enabled && attrs.firstPost) {
      let postType = "answer";

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
