import { createWidget } from 'discourse/widgets/widget';

export default createWidget('qa-button', {
  tagName: 'button.btn.qa-button',

  buildClasses(attrs) {
    return `fa fa-angle-${attrs.direction}`;
  },

  click() {
    this.sendWidgetAction('vote', this.attrs.direction);
  }
});
