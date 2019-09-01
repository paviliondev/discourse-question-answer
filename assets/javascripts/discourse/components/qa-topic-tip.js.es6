import { cookAsync } from "discourse/lib/text";

export default Ember.Component.extend({
  classNames: 'qa-topic-tip',

  didInsertElement() {
    Ember.$(document).on('click', Ember.run.bind(this, this.documentClick));

    let rawDetails = I18n.t(this.get('details'), this.get('detailsOpts'));

    cookAsync(rawDetails).then(cooked => {
      this.set('cookedDetails', cooked);
    });
  },

  willDestroyElement() {
    Ember.$(document).off('click', Ember.run.bind(this, this.documentClick));
  },

  documentClick(e) {
    let $element = this.$();
    let $target = $(e.target);
    if ($target.closest($element).length < 1 &&
        this._state !== 'destroying') {
      this.set('showDetails', false);
    }
  },

  actions: {
    toggleDetails() {
      this.toggleProperty('showDetails');
    }
  }
});
