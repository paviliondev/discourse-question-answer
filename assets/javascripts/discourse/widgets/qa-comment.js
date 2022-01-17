import { createWidget } from "discourse/widgets/widget";
import { h } from "virtual-dom";
import PostCooked from "discourse/widgets/post-cooked";
import DecoratorHelper from "discourse/widgets/decorator-helper";
import { longDateNoYear } from "discourse/lib/formatter";

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
