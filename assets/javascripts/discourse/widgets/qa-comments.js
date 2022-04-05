import { createWidget } from "discourse/widgets/widget";

export default createWidget("qa-comments", {
  tagName: "div.qa-comments",
  buildKey: (attrs) => `qa-comments-${attrs.id}`,

  html(attrs) {
    const result = [];
    const postCommentsLength = attrs.comments.length;

    if (postCommentsLength > 0) {
      for (let i = 0; i < postCommentsLength; i++) {
        result.push(this.attach("qa-comment", attrs.comments[i]));
      }
    }

    if (attrs.canCreatePost) {
      result.push(
        this.attach("qa-comments-menu", {
          id: attrs.id,
          postNumber: attrs.post_number,
          moreCommentCount: attrs.comments_count - postCommentsLength,
          lastCommentId: attrs.comments
            ? attrs.comments[attrs.comments.length - 1]?.id || 0
            : 0,
        })
      );
    }

    return result;
  },

  appendComments(comments) {
    const post = this.findAncestorModel();

    comments.forEach((comment) => {
      post.comments.pushObject(comment);
    });
  },

  removeComment(commentId) {
    const post = this.findAncestorModel();

    const commentToRemove = post.comments.find((comment) => {
      return comment.id === commentId;
    });

    if (commentToRemove) {
      post.comments.removeObject(commentToRemove);
      post.comments_count--;
    }
  },

  updateComment(comment) {
    const post = this.findAncestorModel();

    const index = post.comments.findIndex(
      (oldComment) => oldComment.id === comment.id
    );
    post.comments[index] = comment;
    this.scheduleRerender();
  },
});
