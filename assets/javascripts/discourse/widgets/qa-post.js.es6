import { createWidget } from 'discourse/widgets/widget';
import { ajax } from 'discourse/lib/ajax';
import { h } from 'virtual-dom';

export default createWidget('qa-post', {
  tagName: 'div.qa-post',

  sendShowLogin() {
    const appRoute = this.register.lookup('route:application');
    appRoute.send('showLogin');
  },

  html(attrs, state) {
    const contents = [
      this.attach('qa-button', { direction: 'up' }),
      h('div.count', `${attrs.count}`)
    ]
    return contents;
  },

  vote() {
    const post = this.attrs.post;
    if (post.get('topic.voted')) {
      return bootbox.alert(I18n.t('vote.already_voted'));
    }
    if (!this.currentUser) {
      return this.sendShowLogin();
    }
    post.set('topic.voted', true)
    const voteAction = post.get('actions_summary').findBy('id', 5);
    voteAction.act(post)
  }

})
