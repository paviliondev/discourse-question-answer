import { createWidget } from "discourse/widgets/widget";
import { h } from "virtual-dom";
import PostCooked from "discourse/widgets/post-cooked";
import DecoratorHelper from "discourse/widgets/decorator-helper";
import { longDateNoYear } from "discourse/lib/formatter";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { ajax } from "discourse/lib/ajax";
import bootbox from "bootbox";
import I18n from "I18n";

createWidget("qa-comment-editor", {
  tagName: "div",
  buildKey: (attrs) => `qa-comment-editor-${attrs.id}`,

  buildClasses(attrs) {
    return ["qa-comment-editor", `qa-comment-editor-${attrs.id}}`];
  },

  defaultState(attrs) {
    return { updatingComment: false, value: attrs.raw };
  },

  html(attrs, state) {
    return [
      h("textarea", attrs.raw),
      this.attach("button", {
        action: "editComment",
        disabled: state.updatingComment,
        contents: I18n.t("qa.post.edit_comment"),
        icon: "pencil-alt",
        className: "btn-primary qa-comment-editor-submit",
      }),
      this.attach("link", {
        action: "collapseEditor",
        className: "qa-comment-editor-cancel",
        contents: () => I18n.t("qa.post.cancel_comment"),
      }),
    ];
  },

  input(e) {
    this.state.value = e.target.value;
  },

  keyDown(e) {
    if (e.key === "Enter" && (e.ctrlKey || e.metaKey)) {
      this.sendWidgetAction("editComment");
    }
  },

  editComment(data) {
    this.state.updatingComment = true;

    return ajax("/qa/comments", {
      type: "PUT",
      data: {
        comment_id: this.attrs.id,
        raw: this.state.value,
      },
    })
      .then((response) => {
        this.sendWidgetAction("updateComment", response);
      })
      .catch(popupAjaxError)
      .finally(() => {
        this.sendWidgetAction("collapseEditor");
        this.state.updatingComment = false;
      });
  },
});

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

  defaultState() {
    return { isEditing: false };
  },

  html(attrs, state) {
    if (state.isEditing) {
      return [this.attach("qa-comment-editor", attrs)];
    } else {
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
    }
  },

  expandEditor() {
    this.state.isEditing = true;
  },

  collapseEditor() {
    this.state.isEditing = false;
  },
});
