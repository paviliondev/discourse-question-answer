import { createWidget } from "discourse/widgets/widget";
import { iconNode } from "discourse-common/lib/icon-library";

export default createWidget("qa-button", {
  tagName: "button.btn.qa-button",

  buildClasses(attrs) {
    const result = [];

    if (attrs.direction === "up") {
      result.push("qa-button-upvote");
    }

    if (attrs.direction === "down") {
      result.push("qa-button-downvote");
    }

    if (attrs.voted) {
      result.push("qa-button-voted");
    }

    return result;
  },

  html(attrs) {
    return iconNode(`caret-${attrs.direction}`);
  },

  click() {
    this.sendWidgetAction(
      this.attrs.voted ? "removeVote" : "vote",
      this.attrs.direction
    );
  },
});
