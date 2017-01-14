import { createWidget } from 'discourse/widgets/widget';
import { ajax } from 'discourse/lib/ajax';
import { h } from 'virtual-dom';

export default createWidget('qa-post', {
  tagName: 'div.qa-post',

  html(attrs) {
    return [
      this.attach('qa-button', {
        direction: 'up'
      }),
      h('div.count', attrs.count),
      this.attach('qa-button', {
        direction: 'down'
      })
    ]
  },

  vote(direction) {
    let change = direction === 'up' ? 1 : -1
    ajax("/qa/vote", {
      type: 'POST',
      data: {
        id: this.attrs.post.id,
        change: change
      }
    }).then(function (result, error) {
      if (error) {
        popupAjaxError(error);
      }
    });
  }

})
