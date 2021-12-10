# frozen_string_literal: true

module QuestionAnswer
  class CommentsController < ::ApplicationController
    before_action :find_post
    before_action :ensure_qa_enabled

    def load_comments
      @guardian.ensure_can_see!(@post)
      params.require(:post_number)

      if @post.reply_to_post_number.present? && @post.post_number != 1
        raise Discourse::InvalidParameters
      end

      posts =
        Post
          .where(
            topic_id: @post.topic_id,
            reply_to_post_number: @post.post_number,
            post_type: Post.types[:regular],
          )
          .where("post_number > ?", params[:post_number])
          .order(post_number: :asc)

      render_serialized(posts, QuestionAnswer::CommentSerializer, root: "comments")
    end

    def create
      if !@guardian.can_create_post?(@post.topic)
        raise Discourse::InvalidAccess
      end

      new_post_manager = NewPostManager.new(current_user,
        raw: comments_params[:raw],
        reply_to_post_number: @post.post_number,
        topic_id: @post.topic_id,
        typing_duration_msecs: comments_params[:typing_duration]
      )

      render_serialized(new_post_manager.perform.post, QuestionAnswer::CommentSerializer, root: false)
    end

    private

    def comments_params
      params.require(:post_id)
      params.permit(:post_id, :post_number, :raw, :typing_duration)
    end

    def find_post
      @post = Post.find_by(id: comments_params[:post_id])
      raise Discourse::NotFound if @post.blank?
    end

    def ensure_qa_enabled
      raise Discourse::InvalidAccess if !@post.qa_enabled
    end
  end
end
