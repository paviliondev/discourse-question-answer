import { withPluginApi } from "discourse/lib/plugin-api";

export default {
  name: "custom-post-message-callbacks",
  initialize(container) {
    const siteSettings = container.lookup("site-settings:main");

    if (!siteSettings.qa_enabled) {
      return;
    }

    withPluginApi("1.2.0", (api) => {
      api.registerCustomPostMessageCallback(
        "qa_post_comment_edited",
        (topicController, message) => {
          const postStream = topicController.get("model.postStream");
          const post = postStream.findLoadedPost(message.id);

          if (post) {
            let refresh = false;

            post.comments.forEach((comment) => {
              if (
                comment.id === message.comment_id &&
                comment.raw !== message.comment_raw
              ) {
                comment.raw = message.comment_raw;
                comment.cooked = message.comment_cooked;
                refresh = true;
              }
            });

            if (refresh) {
              topicController.appEvents.trigger("post-stream:refresh", {
                id: post.id,
              });
            }
          }
        }
      );

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

            if (
              post.comments_count - post.comments.length <= 1 &&
              topicController.currentUser.id !== message.comment.user_id
            ) {
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
    });
  },
};
