import { createWidget } from "discourse/widgets/widget";

export default createWidget("qa-comments", {
  tagName: "div.qa-comments",
  buildKey: (attrs) => `qa-comments-${attrs.id}`,

  defaultState(attrs) {
    return {
      comments: attrs.comments || [],
      commentCount: attrs.comments_count || 0,
    };
  },

  html(attrs, state) {
    const result = [];
    const postCommentsLength = state.comments.length;

    if (postCommentsLength > 0) {
      for (let i = 0; i < postCommentsLength; i++) {
        result.push(this.attach("qa-comment", state.comments[i]));
      }
    }

    if (attrs.canCreatePost) {
      result.push(
        this.attach("qa-comments-menu", {
          id: attrs.id,
          moreCommentCount: state.commentCount - postCommentsLength,
          lastCommentId: state.comments
            ? state.comments[state.comments.length - 1]?.id || 0
            : 0,
        })
      );
    }

    return result;
  },

  appendComments(comments) {
    this.state.comments = this.state.comments.concat(comments);
  },

  removeComment(commentId) {
    let removed = false;

    this.state.comments = this.state.comments.filter((comment) => {
      if (comment.id === commentId) {
        removed = true;
        return false;
      } else {
        return true;
      }
    });

    if (removed) {
      this.state.commentCount--;
    }
  },

  updateComment(comment) {
    const index = this.state.comments.findIndex(
      (oldComment) => oldComment.id === comment.id
    );
    this.state.comments[index] = comment;
    this.scheduleRerender();
  },
});
