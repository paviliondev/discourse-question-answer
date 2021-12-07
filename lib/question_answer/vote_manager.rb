# frozen_string_literal: true

module QuestionAnswer
  class VoteManager
    def self.vote(post, user, direction: nil)
      direction ||= QuestionAnswerVote.directions[:up]

      ActiveRecord::Base.transaction do
        vote = QuestionAnswerVote.create!(
          user: user,
          post: post,
          direction: direction
        )

        count_change = QuestionAnswerVote.directions[:up] == direction ? 1 : -1
        post.update!(qa_vote_count: (post.qa_vote_count || 0) + count_change)
        post.publish_change_to_clients!(:acted)

        vote
      end
    end

    def self.remove_vote(post, user)
      ActiveRecord::Base.transaction do
        vote = QuestionAnswerVote.find_by(post: post, user: user)
        direction = vote.direction
        vote.destroy!
        count_change = QuestionAnswerVote.directions[:up] == direction ? -1 : 1
        post.update!(qa_vote_count: (post.qa_vote_count) + count_change)
      end
    end

    def self.can_undo(post, user)
      window = SiteSetting.qa_undo_vote_action_window.to_i
      window.zero? || post.qa_last_voted(user.id).to_i > window.minutes.ago.to_i
    end
  end
end
