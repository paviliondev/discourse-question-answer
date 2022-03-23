import { Promise } from "rsvp";
import { createWidget } from "discourse/widgets/widget";
import { h } from "virtual-dom";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { ajax } from "discourse/lib/ajax";
import { schedule } from "@ember/runloop";
import I18n from "I18n";

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
          action: this.currentUser ? "expandComposer" : "showLogin",
          actionParam: {
            postId: attrs.id,
            postNumber: attrs.postNumber,
            lastCommentId: attrs.lastCommentId,
          },
          contents: () => I18n.t("qa.post.qa_comment.add"),
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
              I18n.t("qa.post.qa_comment.show", {
                count: attrs.moreCommentCount,
              }),
          }),
        ])
      );
    }

    return result;
  },

  expandComposer(data) {
    this.state.expanded = true;

    this.fetchComments({
      post_id: data.postId,
      last_comment_id: data.lastCommentId,
    }).then(() => {
      schedule("afterRender", () => {
        const textArea = document.querySelector(
          `#post_${data.postNumber} .qa-comment-composer .qa-comment-composer-textarea`
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
