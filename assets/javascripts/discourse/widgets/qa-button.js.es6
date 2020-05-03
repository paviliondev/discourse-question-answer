import { createWidget } from "discourse/widgets/widget";
import { iconNode } from "discourse-common/lib/icon-library";

export default createWidget("qa-button", {
  tagName: "button.btn.qa-button",

  html(attrs) {
    return iconNode(`angle-${attrs.direction}`);
  },

  click() {
    this.sendWidgetAction("vote", this.attrs.direction);
  }
});
