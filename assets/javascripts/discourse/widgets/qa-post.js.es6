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
    const user = this.currentUser;

    if (!user) {
      return this.sendShowLogin();
    }

    const post = this.attrs.post;
    const siteSettings = this.siteSettings;

    if (!post.get('topic.can_vote')) {
      return bootbox.alert(I18n.t('vote.user_over_limit'));
    }

    if (!siteSettings.qa_allow_multiple_votes_per_post &&
        post.get('topic.votes').indexOf(post.id) > -1) {
      return bootbox.alert(I18n.t('vote.one_vote_per_post'));
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
      if (result.votes) {
        post.set('topic.votes', result.votes);
      }
    });
  }
});
