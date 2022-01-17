import { createWidget } from "discourse/widgets/widget";
import I18n from "I18n";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { ajax } from "discourse/lib/ajax";

createWidget("qa-comments-menu-composer", {
  tagName: "div.qa-comments-menu-composer",
  buildKey: (attrs) => `qa-comments-menu-composer-${attrs.id}`,

  defaultState() {
    return { value: "", creatingPost: false };
  },

  html(attrs, state) {
    const result = [];

    result.push(
      this.attach("qa-comments-menu-composer-textarea", {
        value: state.value,
        id: attrs.id,
      })
    );

    result.push(
      this.attach("button", {
        action: "submitComment",
        actionParam: {
          raw: state.value,
          post_id: attrs.id,
        },
        disabled: state.creatingPost,
        contents: I18n.t("qa.post.submit_comment"),
        icon: "reply",
        className: "btn-primary qa-comments-menu-composer-submit",
      })
    );

    result.push(
      this.attach("link", {
        action: "closeComposer",
        className: "qa-comments-menu-composer-cancel",
        contents: () => I18n.t("qa.post.cancel_comment"),
      })
    );

    return result;
  },

  updateValue(value) {
    this.state.value = value;
  },

  submitComment(data) {
    this.state.creatingPost = true;

    return ajax("/qa/comments", {
      type: "POST",
      data,
    })
      .then((response) => {
        this.sendWidgetAction("appendComments", [response]);
        this.state.value = "";
        this.sendWidgetAction("closeComposer");
      })
      .catch(popupAjaxError)
      .finally(() => {
        this.state.creatingPost = false;
      });
  },
});
