import { createWidget } from "discourse/widgets/widget";

export default createWidget("qa-comments", {
  tagName: "div.qa-comments",
  buildKey: (attrs) => `qa-comments-${attrs.id}`,

  defaultState(attrs) {
    return {
      comments: attrs.comments || [],
    };
  },

  html(attrs, state) {
    const result = [],
      postCommentsLength = state.comments.length;

    if (postCommentsLength > 0) {
      for (let i = 0; i < postCommentsLength; i++) {
        result.push(this.attach("qa-comment", state.comments[i]));
      }
    }

    if (attrs.canCreatePost) {
      result.push(
        this.attach("qa-comments-menu", {
          id: attrs.id,
          moreCommentCount: attrs.comments_count - postCommentsLength,
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
});
