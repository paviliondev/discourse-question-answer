import { createWidget } from "discourse/widgets/widget";

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
