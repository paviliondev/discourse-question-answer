import { createWidget } from "discourse/widgets/widget";
import { h } from "virtual-dom";
import PostCooked from "discourse/widgets/post-cooked";
import DecoratorHelper from "discourse/widgets/decorator-helper";
import { longDateNoYear } from "discourse/lib/formatter";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { ajax } from "discourse/lib/ajax";
import bootbox from "bootbox";
import I18n from "I18n";

createWidget("qa-comment-actions", {
  tagName: "span.qa-comment-actions",

  html(attrs) {
    const result = [];

    result.push(
      this.attach("link", {
        className: "qa-comment-actions-delete-link",
        action: "deleteComment",
        icon: "far-trash-alt",
        actionParam: {
          comment_id: attrs.id,
        },
      })
    );

    return result;
  },

  deleteComment(data) {
    return bootbox.confirm(
      I18n.t("qa.post.delete_comment_confirm"),
      I18n.t("no_value"),
      I18n.t("yes_value"),
      (result) => {
        if (result) {
          ajax("/qa/comments", {
            type: "DELETE",
            data,
          })
            .then(() => {
              this.sendWidgetAction("removeComment", data.comment_id);
            })
            .catch(popupAjaxError);
        }
      }
    );
  },
});

export default createWidget("qa-comment", {
  tagName: "div.qa-comment",
  buildKey: (attrs) => `qa-comment-${attrs.id}`,

  html(attrs) {
    const result = [
      h(
        "span.qa-comment-cooked",
        new PostCooked(attrs, new DecoratorHelper(this), this.currentUser)
      ),
      h("span.qa-comment-info-separator", "–"),
      h("span.qa-comment-info-username", this.attach("poster-name", attrs)),
      h(
        "span.qa-comment-info-created",
        longDateNoYear(new Date(attrs.created_at))
      ),
    ];

    if (
      this.currentUser &&
      (attrs.user_id === this.currentUser.id || this.currentUser.admin)
    ) {
      result.push(this.attach("qa-comment-actions", attrs));
    }

    return [h("div.qa-comment-post", result)];
  },
});
