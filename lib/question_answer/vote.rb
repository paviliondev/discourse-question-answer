# frozen_string_literal: true

module QuestionAnswer
  class Vote
    CREATE = 'create'
    DESTROY = 'destroy'
    UP = 'up'
    DOWN = 'down'

    def self.vote(post, user, args)
      ActiveRecord::Base.transaction do
        modifier = 0

        if args[:direction] == UP
          if args[:action] == CREATE
            QuestionAnswerVote.create!(user: user, post: post)
            modifier = 1
          elsif args[:action] == DESTROY
            modifier = -(QuestionAnswerVote.where(user: user, post: post).delete_all)
          end
        end

        post.qa_vote_count = post.qa_vote_count + modifier

        if post.save
          post.publish_change_to_clients! :acted
          true
        else
          false
        end
      end
    end

    def self.can_undo(post, user)
      window = SiteSetting.qa_undo_vote_action_window.to_i
      window.zero? || post.qa_last_voted(user.id).to_i > window.minutes.ago.to_i
    end
  end
end
