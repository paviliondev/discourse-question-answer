require_dependency 'application_controller'
require_dependency 'topic'

module QuestionAnswer
  Voter = Struct.new(:user)

  class VotesController < ApplicationController
    before_action :ensure_logged_in
    before_action :find_vote_post
    before_action :find_vote_user, only: [:create, :destroy]
    before_action :ensure_qa_enabled, only: [:create, :destroy]
    before_action :ensure_can_act, only: [:create, :destroy]

    def create
      if !::Topic.qa_can_vote(@post.topic, @user)
        raise Discourse::InvalidAccess.new(nil, nil,
          custom_message: 'vote.error.user_over_limit'
        )
      end

      if !@post.qa_can_vote(@user.id)
        raise Discourse::InvalidAccess.new(nil, nil,
          custom_message: 'vote.error.one_vote_per_post'
        )
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

    def destroy
      if Topic.qa_votes(@post.topic, @user).length == 0
        raise Discourse::InvalidAccess.new, I18n.t('vote.error.user_has_not_voted')
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

    def voters
      voters = []

      if @post.qa_voted.any?
        @post.qa_voted.each do |user_id|
          if user = User.find_by(id: user_id)
            voters.push(Voter.new(user))
          end
        end
      end

      render_json_dump(voters: serialize_data(voters, QuestionAnswer::VoterSerializer))
    end

    private

    def vote_params
      params.require(:vote).permit(:post_id, :user_id, :direction)
    end

    def vote_args
      {
        direction: vote_params[:direction],
        action: self.action_name
      }
    end

    def find_vote_post
      if params[:vote].present?
        post_id = vote_params[:post_id]
      else
        params.require(:post_id)
        post_id = params[:post_id]
      end

      if post = Post.find_by(id: post_id)
        @post = post
      else
        raise Discourse::NotFound
      end
    end

    def find_vote_user
      if vote_params[:user_id] && user = User.find_by(id: vote_params[:user_id])
        @user = user
      else
        raise Discourse::NotFound
      end
    end

    def ensure_qa_enabled
      Topic.qa_enabled(@post.topic)
    end

    def ensure_can_act
      if Topic.qa_votes(@post.topic, @user).present?
        if self.action_name === QuestionAnswer::Vote::CREATE
          raise Discourse::InvalidAccess.new, I18n.t('vote.error.alread_voted')
        end

        if self.action_name === QuestionAnswer::Vote::DESTROY && !QuestionAnswer::Vote.can_undo(@post, @user)
          raise Discourse::InvalidAccess.new, I18n.t('vote.error.undo_vote_action_window',
            minutes: SiteSetting.qa_undo_vote_action_window
          )
        end
      elsif self.action_name === QuestionAnswer::Vote::DESTROY
        raise Discourse::InvalidAccess.new, I18n.t('vote.error.user_has_not_voted')
      end
    end
  end
end
