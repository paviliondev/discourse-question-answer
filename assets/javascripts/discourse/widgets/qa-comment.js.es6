import { createWidget } from "discourse/widgets/widget";
import { h } from "virtual-dom";
import { dateNode } from "discourse/helpers/node";

export default createWidget("qa-comment", {
  tagName: "div.qa-comment",

  html(attrs) {
    return [
      h("div.qa-comment-post", [
        h("div.qa-comment-post-info", [
          h("span.qa-comment-post-username", this.attach("poster-name", attrs)),
          h(
            "span.qa-comment-post-info-created",
            dateNode(new Date(attrs.created_at))
          ),
        ]),
        h("div.qa-comment-post-body", attrs.excerpt),
      ]),
    ];
  },
});
