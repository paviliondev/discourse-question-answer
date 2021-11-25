import { createWidget } from "discourse/widgets/widget";
import { h } from "virtual-dom";
import { dateNode } from "discourse/helpers/node";
import RawHtml from "discourse/widgets/raw-html";
import { avatarFor } from "discourse/widgets/post";

export default createWidget("qa-comment", {
  tagName: "div.qa-comment",

  html(attrs) {
    return [
      h("div.qa-comment-post", [
        h("div.qa-comment-post-info", [
          avatarFor("tiny", {
            username: attrs.username,
            template: attrs.avatar_template,
            name: attrs.name,
            className: "qa-comment-post-avatar",
          }),
          h("span.qa-comment-post-username", this.attach("poster-name", attrs)),
          h(
            "span.qa-comment-post-info-created",
            dateNode(new Date(attrs.created_at))
          ),
        ]),
        h(
          "div.qa-comment-post-body",
          new RawHtml({
            html: attrs.cooked,
          })
        ),
      ]),
    ];
  },
});
