export default Ember.Component.extend({
  classNames: 'topic-tip',

  didInsertElement() {
    Ember.$(document).on('click', Ember.run.bind(this, this.documentClick));
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
})
