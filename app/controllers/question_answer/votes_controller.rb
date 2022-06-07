# frozen_string_literal: true

module QuestionAnswer
  class VotesController < ::ApplicationController
    before_action :ensure_logged_in
    before_action :find_vote_post, only: [:create, :destroy, :voters]
    before_action :ensure_can_see_post, only: [:create, :destroy, :voters]
    before_action :ensure_qa_enabled, only: [:create, :destroy]

    def create
      ensure_can_vote(@post)

      if QuestionAnswer::VoteManager.vote(@post, current_user, direction: vote_params[:direction])
        render json: success_json
      else
        render json: failed_json, status: 422
      end
    end

    def create_comment_vote
      comment = find_comment
      ensure_can_see_comment!(comment)
      ensure_can_vote(comment)

      if QuestionAnswer::VoteManager.vote(comment, current_user, direction: QuestionAnswerVote.directions[:up])
        render json: success_json
      else
        render json: failed_json, status: 422
      end
    end

    def destroy
      if !Topic.qa_votes(@post.topic, current_user).exists?
        raise Discourse::InvalidAccess.new(
          nil,
          nil,
          custom_message: 'vote.error.user_has_not_voted'
        )
      end

      if !QuestionAnswer::VoteManager.can_undo(@post, current_user)
        window = SiteSetting.qa_undo_vote_action_window
        msg = I18n.t('vote.error.undo_vote_action_window', minutes: window)

        render_json_error(msg, status: 403)

        return
      end

      if QuestionAnswer::VoteManager.remove_vote(@post, current_user)
        render json: success_json
      else
        render json: failed_json, status: 422
      end
    end

    def destroy_comment_vote
      comment = find_comment
      ensure_can_see_comment!(comment)

      if !QuestionAnswerVote.exists?(votable: comment, user: current_user)
        raise Discourse::InvalidAccess.new(
          nil,
          nil,
          custom_message: 'vote.error.user_has_not_voted'
        )
      end

      if QuestionAnswer::VoteManager.remove_vote(comment, current_user)
        render json: success_json
      else
        render json: failed_json, status: 422
      end
    end

    VOTERS_LIMIT = 20

    def voters
      # TODO: Probably a site setting to hide/show voters
      voters = User
        .joins(:question_answer_votes)
        .where(question_answer_votes: { votable_id: @post.id, votable_type: 'Post' })
        .order("question_answer_votes.created_at DESC")
        .select("users.*", "question_answer_votes.direction")
        .limit(VOTERS_LIMIT)

      render_json_dump(
        voters: serialize_data(voters, BasicVoterSerializer)
      )
    end

    private

    def vote_params
      params.permit(:post_id, :comment_id, :direction)
    end

    def find_vote_post
      if params[:vote].present?
        post_id = vote_params[:post_id]
      else
        params.require(:post_id)
        post_id = params[:post_id]
      end

      @post = Post.find_by(id: post_id)

      raise Discourse::NotFound unless @post
    end

    def ensure_can_see_post
      @guardian.ensure_can_see!(@post)
    end

    def ensure_qa_enabled
      raise Discourse::InvalidAccess.new unless @post.is_qa_topic?
    end

    def find_comment
      comment = QuestionAnswerComment.find_by(id: vote_params[:comment_id])
      raise Discourse::NotFound if comment.blank?
      comment
    end

    def ensure_can_see_comment!(comment)
      @guardian.ensure_can_see!(comment.post)
    end

    def ensure_can_vote(votable)
      error_message = nil
      error_message_params = {}

      if votable.user_id == current_user.id
        error_message = "post.qa.errors.self_voting_not_permitted"
      elsif votable.class.name == "Post"
        direction = vote_params[:direction] || QuestionAnswerVote.directions[:up]
        if QuestionAnswerVote.exists?(votable: votable, user_id: current_user.id, direction: direction)
          error_message = "vote.error.one_vote_per_post"
        elsif !QuestionAnswer::VoteManager.can_undo(votable, current_user)
          error_message = "vote.error.undo_vote_action_window"
          error_message_params = { minutes: SiteSetting.qa_undo_vote_action_window }
        end
      elsif votable.class.name == "QuestionAnswerComment"
        if QuestionAnswerVote.exists?(votable: votable, user: current_user)
          error_message = "vote.error.one_vote_per_comment"
        end
      end

      if error_message.present?
        raise Discourse::InvalidAccess.new(
          nil,
          nil,
          custom_message: error_message,
          custom_message_params: error_message_params
        )
      end
    end
  end
end
