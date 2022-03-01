# frozen_string_literal: true

module QuestionAnswer
  class VoteManager
    def self.vote(obj, user, direction: nil)
      direction ||= QuestionAnswerVote.directions[:up]

      ActiveRecord::Base.transaction do
        existing_vote = QuestionAnswerVote.find_by(
          user: user,
          votable: obj,
          direction: QuestionAnswerVote.reverse_direction(direction)
        )

        count_change =
          if existing_vote
            QuestionAnswerVote.directions[:up] == direction ? 2 : -2
          else
            QuestionAnswerVote.directions[:up] == direction ? 1 : -1
          end

        existing_vote.destroy! if existing_vote

        vote = QuestionAnswerVote.create!(
          user: user,
          votable: obj,
          direction: direction
        )

        obj.update!(qa_vote_count: (obj.qa_vote_count || 0) + count_change)

        vote
      end
    end

    def self.remove_vote(obj, user)
      ActiveRecord::Base.transaction do
        vote = QuestionAnswerVote.find_by(votable: obj, user: user)
        direction = vote.direction
        vote.destroy!
        count_change = QuestionAnswerVote.directions[:up] == direction ? -1 : 1
        obj.update!(qa_vote_count: obj.qa_vote_count + count_change)
      end
    end

    def self.can_undo(post, user)
      window = SiteSetting.qa_undo_vote_action_window.to_i
      window.zero? || post.qa_last_voted(user.id).to_i > window.minutes.ago.to_i
    end
  end
end
