import { createWidget } from "discourse/widgets/widget";
import { h } from "virtual-dom";
import I18n from "I18n";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { ajax } from "discourse/lib/ajax";

createWidget("qa-comment-editor", {
  tagName: "div",
  buildKey: (attrs) => `qa-comment-editor-${attrs.id}`,

  buildClasses(attrs) {
    return ["qa-comment-editor", `qa-comment-editor-${attrs.id}`];
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

  editComment() {
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
        this.sendWidgetAction("collapseEditor");
      })
      .catch(popupAjaxError)
      .finally(() => {
        this.state.updatingComment = false;
      });
  },
});
