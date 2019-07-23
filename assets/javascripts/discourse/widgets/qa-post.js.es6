import { createWidget } from 'discourse/widgets/widget';
import { castVote } from '../lib/qa-utilities';
import { h } from 'virtual-dom';

export default createWidget('qa-post', {
  tagName: 'div.qa-post',

  sendShowLogin() {
    const appRoute = this.register.lookup('route:application');
    appRoute.send('showLogin');
  },

  html(attrs) {
    const contents = [
      this.attach('qa-button', { direction: 'up' }),
      h('div.count', `${attrs.count}`)
    ];
    return contents;
  },

  vote(direction) {
    const post = this.attrs.post;
    const user = this.currentUser;

    if (!post.get('topic.can_vote')) {
      return bootbox.alert(I18n.t('vote.user_over_limit'));
    }

    if (!user) {
      return this.sendShowLogin();
    }

    post.set('topic.voted', true);

    let vote = {
      user_id: user.id,
      post_id: post.id,
      direction
    };

    castVote({ 
      vote 
    }).then(result => {
      if (result.can_vote) {
        post.set('topic.can_vote', result.can_vote);
      }
      if (result.vote_count) {
        post.set('topic.vote_count', result.vote_count);
      }
    });
  }
});
