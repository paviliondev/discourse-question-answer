import { createWidget } from "discourse/widgets/widget";
import I18n from "I18n";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { ajax } from "discourse/lib/ajax";

createWidget("qa-comment-actions", {
  tagName: "span.qa-comment-actions",

  html(attrs) {
    return [
      this.attach("link", {
        className: "qa-comment-actions-edit-link",
        action: "expandEditor",
        icon: "pencil-alt",
      }),
      this.attach("link", {
        className: "qa-comment-actions-delete-link",
        action: "deleteComment",
        icon: "far-trash-alt",
        actionParam: {
          comment_id: attrs.id,
        },
      }),
    ];
  },

  deleteComment(data) {
    return bootbox.confirm(
      I18n.t("qa.post.qa_comment.delete_confirm"),
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
