# frozen_string_literal: true

module QuestionAnswer
  class Vote
    CREATE = 'create'
    DESTROY = 'destroy'
    UP = 'up'
    DOWN = 'down'

    def self.vote(post, user, args)
      modifier = 0

      voted = post.qa_voted

      if args[:direction] == UP
        if args[:action] == CREATE
          voted.push(user.id)
          modifier = 1
        elsif args[:action] == DESTROY
          modifier = 0
          voted.delete_if do |user_id|
            if user_id == user.id
              modifier -= 1
              true
            end
          end
        end
      end

      post.custom_fields['vote_count'] = post.qa_vote_count + modifier
      post.custom_fields['voted'] = voted

      votes = post.qa_vote_history

      votes.push(
        direction: args[:direction],
        action: args[:action],
        user_id: user.id,
        created_at: Time.now
      )

      post.custom_fields['vote_history'] = votes

      if post.save_custom_fields(true)
        Topic.qa_update_vote_order(post.topic)
        post.publish_change_to_clients! :acted
        true
      else
        false
      end
    end

    def self.can_undo(post, user)
      window = SiteSetting.qa_undo_vote_action_window.to_i
      window.zero? || post.qa_last_voted(user.id).to_i > window.minutes.ago.to_i
    end
  end
end
