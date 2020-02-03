import { createWidget } from "discourse/widgets/widget";
import { castVote } from "../lib/qa-utilities";
import { h } from "virtual-dom";

export default createWidget("qa-post", {
  tagName: "div.qa-post",

  sendShowLogin() {
    const appRoute = this.register.lookup("route:application");
    appRoute.send("showLogin");
  },

  html(attrs) {
    const contents = [
      this.attach("qa-button", { direction: "up" }),
      h("div.count", `${attrs.count}`)
    ];
    return contents;
  },

  vote(direction) {
    const user = this.currentUser;

    if (!user) {
      return this.sendShowLogin();
    }

    const post = this.attrs.post;

    let vote = {
      user_id: user.id,
      post_id: post.id,
      direction
    };

    castVote({ vote }).then(result => {
      if (result.success) {
        post.set("topic.qa_voted", true);

        if (result.qa_can_vote) {
          post.set("topic.qa_can_vote", result.qa_can_vote);
        }
        if (result.qa_votes) {
          post.set("topic.qa_votes", result.qa_votes);
        }
      }
    });
  }
});
