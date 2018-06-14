::PostSerializer.class_eval do
  attributes :vote_count
end

require 'post_actions_controller'
class ::PostActionsController
  before_action :check_if_voted, only: :create

  def check_if_voted
    if current_user && params[:post_action_type_id].to_i === PostActionType.types[:vote] &&
      QAHelper.qa_enabled(@post.topic) && QAHelper.user_has_voted(@post.topic, current_user)
      raise Discourse::InvalidAccess.new, I18n.t('vote.alread_voted')
    end
  end
end

class ::Post
  after_create :update_qa_order, if: :qa_enabled

  def qa_enabled
    QAHelper.qa_enabled(topic)
  end

  def update_qa_order
    QAHelper.update_order(topic_id)
  end
end

class ::PostAction
  after_commit :update_qa_order, if: :is_vote?

  def is_vote?
    post_action_type_id == PostActionType.types[:vote]
  end

  def notify_subscribers
    if (is_like? || is_flag? || is_vote?) && post
      post.publish_change_to_clients! :acted
    end
  end

  def update_qa_order
    topic_id = Post.where(id: post_id).pluck(:topic_id).first
    QAHelper.update_order(topic_id)
  end
end

module PostGuardianVoteExtension
  def can_delete_post_action?(post_action)
    # only use extension if post_action is a vote
    return super(post_action) unless post_action.post_action_type_id == PostActionType.types[:vote]

    # You can only undo your own actions
    return false unless is_my_own?(post_action) && not(post_action.is_private_message?)

    # Apply vote action window if it exists
    vote_window = SiteSetting.qa_undo_vote_action_window.to_i
    if vote_window == 0
      return true
    elsif vote_window.present?
      return post_action.created_at > vote_window.minutes.ago
    end

    # Use post action setting as default
    post_action.created_at > SiteSetting.post_undo_action_window_mins.minutes.ago
  end
end

require_dependency 'guardian'
class ::Guardian
  prepend PostGuardianVoteExtension
end
