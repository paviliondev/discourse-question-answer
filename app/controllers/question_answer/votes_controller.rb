# frozen_string_literal: true

module QuestionAnswer
  class VotesController < ::ApplicationController
    before_action :ensure_logged_in
    before_action :find_vote_post
    before_action :find_vote_user, only: [:create, :destroy]
    before_action :ensure_qa_enabled, only: [:create, :destroy]
    before_action :ensure_staff, only: [:set_as_answer]

    def create
      unless Topic.qa_can_vote(@post.topic, @user)
        raise Discourse::InvalidAccess.new(
          nil,
          nil,
          custom_message: 'vote.error.user_over_limit'
        )
      end

      unless @post.qa_can_vote(@user.id)
        raise Discourse::InvalidAccess.new(
          nil,
          nil,
          custom_message: 'vote.error.one_vote_per_post'
        )
      end

      if QuestionAnswer::Vote.vote(@post, @user, vote_args)
        render json: success_json.merge(
          qa_votes: Topic.qa_votes(@post.topic, @user).pluck(:post_id),
          qa_can_vote: Topic.qa_can_vote(@post.topic, @user)
        )
      else
        render json: failed_json, status: 422
      end
    end

    def destroy
      if Topic.qa_votes(@post.topic, @user).exists?
        raise Discourse::InvalidAccess.new(
          nil,
          nil,
          custom_message: 'vote.error.user_has_not_voted'
        )
      end

      if !QuestionAnswer::Vote.can_undo(@post, @user)
        window = SiteSetting.qa_undo_vote_action_window
        msg = I18n.t('vote.error.undo_vote_action_window', minutes: window)

        render_json_error(msg, status: 403)

        return
      end

      if QuestionAnswer::Vote.vote(@post, @user, vote_args)
        render json: success_json.merge(
          qa_votes: Topic.qa_votes(@post.topic, @user),
          qa_can_vote: Topic.qa_can_vote(@post.topic, @user)
        )
      else
        render json: failed_json, status: 422
      end
    end

    def set_as_answer
      @post.reply_to_post_number = nil

      @post.save!
      Topic.qa_update_vote_order(@post.topic)

      render json: success_json
    end

    def voters
      # TODO: Need to paginate
      # TODO: Should be distinct users?
      # TODO: Probably a site setting to hide/show voters
      @guardian.ensure_can_see!(@post)

      voters = User
        .joins(:question_answer_votes)
        .where(question_answer_votes: { post_id: @post.id })

      render_json_dump(
        voters: serialize_data(voters, BasicUserSerializer)
      )
    end

    private

    def vote_params
      params.require(:vote).permit(:post_id, :user_id, :direction)
    end

    def vote_args
      {
        direction: vote_params[:direction],
        action: action_name
      }
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

    def find_vote_user
      @user = User.find_by(id: vote_params[:user_id])

      raise Discourse::NotFound unless @user
    end

    def ensure_qa_enabled
      raise Discourse::InvalidAccess.new unless Topic.qa_enabled(@post.topic)
    end
  end
end
