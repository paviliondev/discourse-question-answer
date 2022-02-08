import { createWidget } from "discourse/widgets/widget";
import { h } from "virtual-dom";
import RawHtml from "discourse/widgets/raw-html";
import { dateNode } from "discourse/helpers/node";
import { formatUsername } from "discourse/lib/utilities";

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
          new RawHtml({
            html: attrs.cooked,
          })
        ),
        h("span.qa-comment-info-separator", "–"),
        h(
          "a.qa-comment-info-username",
          {
            attributes: {
              "data-user-card": attrs.username,
            },
          },
          formatUsername(attrs.username)
        ),
        h("span.qa-comment-info-created", dateNode(new Date(attrs.created_at))),
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
