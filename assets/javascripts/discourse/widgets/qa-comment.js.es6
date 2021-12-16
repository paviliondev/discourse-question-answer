import { createWidget } from "discourse/widgets/widget";
import { h } from "virtual-dom";
import PostCooked from "discourse/widgets/post-cooked";
import DecoratorHelper from "discourse/widgets/decorator-helper";
import { longDateNoYear } from "discourse/lib/formatter";

export default createWidget("qa-comment", {
  tagName: "div.qa-comment",

  html(attrs) {
    return [
      h("div.qa-comment-post", [
        h(
          "span.qa-comment-post-body",
          new PostCooked(attrs, new DecoratorHelper(this), this.currentUser)
        ),
        h("span.qa-comment-post-info-separator", "–"),
        h(
          "span.qa-comment-post-info-username",
          this.attach("poster-name", attrs)
        ),
        h(
          "span.qa-comment-post-info-created",
          longDateNoYear(new Date(attrs.created_at))
        ),
      ]),
    ];
  },
});
