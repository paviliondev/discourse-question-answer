# frozen_string_literal: true

module QuestionAnswer
  class CommentsController < ::ApplicationController
    before_action :find_post, only: [:load_more_comments, :create]
    before_action :ensure_qa_enabled, only: [:load_more_comments, :create]
    before_action :ensure_logged_in, only: [:create, :destroy]

    def load_more_comments
      @guardian.ensure_can_see!(@post)
      params.require(:last_comment_id)

      if @post.reply_to_post_number.present? && @post.post_number != 1
        raise Discourse::InvalidParameters
      end

      comments =
        QuestionAnswerComment
          .includes(:user)
          .where("id > ? AND post_id = ?", comments_params[:last_comment_id], @post.id)
          .order(id: :asc)

      render_serialized(comments, QuestionAnswerCommentSerializer, root: "comments")
    end

    def create
      if !@guardian.can_create_post_on_topic?(@post.topic)
        raise Discourse::InvalidAccess
      end

      qa_comment = QuestionAnswerComment.new(
        user: current_user,
        post_id: @post.id,
        raw: comments_params[:raw]
      )

      if qa_comment.save
        render_serialized(qa_comment, QuestionAnswerCommentSerializer, root: false)
      else
        render_json_error(qa_comment.errors.full_messages, status: 403)
      end
    end

    def destroy
      params.require(:comment_id)

      qa_comment = QuestionAnswerComment.find_by(id: params[:comment_id])
      raise Discourse::NotFound if qa_comment.blank?

      @guardian.ensure_can_see!(qa_comment.post)

      if qa_comment.user_id != current_user.id && !@guardian.is_admin?
        raise Discourse::InvalidAccess
      end

      qa_comment.trash!

      render json: success_json
    end

    private

    def comments_params
      params.require(:post_id)
      params.permit(:post_id, :last_comment_id, :raw)
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
