import { cookAsync } from "discourse/lib/text";

export default Ember.Component.extend({
  classNames: ["qa-topic-tip"],

  didInsertElement() {
    this._super(...arguments);

    $(document).on("click", Ember.run.bind(this, this.documentClick));

    const rawDetails = I18n.t(this.details, this.detailsOpts);

    if (rawDetails) {
      cookAsync(rawDetails).then(cooked => {
        this.set("cookedDetails", cooked);
      });
    }
  },

  willDestroyElement() {
    $(document).off("click", Ember.run.bind(this, this.documentClick));
  },

  documentClick(e) {
    const $element = $(this.element);
    const $target = $(e.target);

    if ($target.closest($element).length < 1 && this._state !== "destroying") {
      this.set("showDetails", false);
    }
  },

  actions: {
    toggleDetails() {
      this.toggleProperty("showDetails");
    }
  }
});
