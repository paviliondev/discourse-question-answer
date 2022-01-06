import { Promise } from "rsvp";
import { createWidget } from "discourse/widgets/widget";
import { h } from "virtual-dom";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { ajax } from "discourse/lib/ajax";
import { schedule } from "@ember/runloop";
import I18n from "I18n";

createWidget("qa-comments-menu-composer-textarea", {
  tagName: "textarea",

  buildClasses(attrs) {
    return [
      "qa-comments-menu-composer-textarea",
      `qa-comments-menu-composer-textarea-${attrs.id}`,
    ];
  },

  input(e) {
    this.sendWidgetAction("updateValue", e.target.value);
  },
});

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

export default createWidget("qa-comments-menu", {
  tagName: "div.qa-comments-menu",
  buildKey: (attrs) => `qa-comments-menu-${attrs.id}`,

  defaultState() {
    return { expanded: false };
  },

  html(attrs, state) {
    const result = [];

    if (state.expanded) {
      result.push(this.attach("qa-comments-menu-composer", attrs));
    } else {
      result.push(
        this.attach("link", {
          className: "qa-comment-add-link",
          action: "expandComposer",
          actionParam: {
            post_id: attrs.id,
            last_comment_id: attrs.lastCommentId,
          },
          contents: () => I18n.t("qa.post.add_comment"),
        })
      );
    }

    if (attrs.moreCommentCount > 0) {
      if (!state.expanded) {
        result.push(h("span.qa-comments-menu-seperator"));
      }

      result.push(
        h("div.qa-comments-menu-show-more", [
          this.attach("link", {
            className: "qa-comments-menu-show-more-link",
            action: "fetchComments",
            actionParam: {
              post_id: attrs.id,
              last_comment_id: attrs.lastCommentId,
            },
            contents: () =>
              I18n.t("qa.post.show_comment", { count: attrs.moreCommentCount }),
          }),
        ])
      );
    }

    return result;
  },

  expandComposer(data) {
    this.state.expanded = true;

    this.fetchComments(data).then(() => {
      schedule("afterRender", () => {
        const textArea = document.querySelector(
          `.qa-comments-menu-composer-textarea-${data.post_id}`
        );

        textArea.focus();
        textArea.select();
      });
    });
  },

  closeComposer() {
    this.state.expanded = false;
  },

  fetchComments(data) {
    if (!data.post_id) {
      return Promise.resolve();
    }

    return ajax("/qa/comments", {
      type: "GET",
      data,
    })
      .then((response) => {
        if (response.comments.length > 0) {
          this.sendWidgetAction("appendComments", response.comments);
        }
      })
      .catch(popupAjaxError);
  },
});
