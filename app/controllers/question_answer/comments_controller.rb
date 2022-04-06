# frozen_string_literal: true

module QuestionAnswer
  class CommentsController < ::ApplicationController
    before_action :find_post, only: [:load_more_comments, :create]
    before_action :ensure_qa_enabled, only: [:load_more_comments, :create]
    before_action :ensure_logged_in, only: [:create, :destroy, :update]

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

      comment = QuestionAnswer::CommentCreator.create(
        user: current_user,
        post_id: @post.id,
        raw: comments_params[:raw]
      )

      if comment.errors.present?
        render_json_error(comment.errors.full_messages, status: 403)
      else
        render_serialized(comment, QuestionAnswerCommentSerializer, root: false)
      end
    end

    def update
      params.require(:comment_id)
      params.require(:raw)

      comment = find_comment(params[:comment_id])
      @guardian.ensure_can_see!(comment.post)

      raise Discourse::InvalidAccess if !@guardian.can_edit_comment?(comment)

      if comment.update(raw: params[:raw])
        render_serialized(comment, QuestionAnswerCommentSerializer, root: false)
      else
        render_json_error(comment.errors.full_messages, status: 403)
      end
    end

    def destroy
      params.require(:comment_id)
      comment = find_comment(params[:comment_id])

      @guardian.ensure_can_see!(comment.post)
      raise Discourse::InvalidAccess if !@guardian.can_delete_comment?(comment)

      comment.trash!

      Scheduler::Defer.later("Publish trash Q&A comment") do
        comment.post.publish_change_to_clients!(
          :qa_post_comment_trashed,
          comment_id: comment.id,
          comments_count: QuestionAnswerComment.where(post_id: comment.post_id).count
        )
      end

      render json: success_json
    end

    private

    def comments_params
      params.require(:post_id)
      params.permit(:post_id, :last_comment_id, :raw)
    end

    def find_comment(comment_id)
      comment = QuestionAnswerComment.find_by(id: comment_id)
      raise Discourse::NotFound if comment.blank?
      comment
    end

    def find_post
      @post = Post.find_by(id: comments_params[:post_id])
      raise Discourse::NotFound if @post.blank?
    end

    def ensure_qa_enabled
      raise Discourse::InvalidAccess if !@post.is_qa_topic?
    end
  end
end
