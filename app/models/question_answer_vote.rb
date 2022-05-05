# frozen_string_literal: true

class QuestionAnswerVote < ActiveRecord::Base
  belongs_to :votable, polymorphic: true
  belongs_to :user

  VOTABLE_TYPES = %w{Post QuestionAnswerComment}

  validates :direction, inclusion: { in: ['up', 'down'] }
  validates :votable_type, presence: true, inclusion: { in: VOTABLE_TYPES }
  validates :votable_id, presence: true
  validates :user_id, presence: true
  validate :ensure_valid_post, if: -> { votable_type == 'Post' }
  validate :ensure_valid_comment, if: -> { votable_type == 'QuestionAnswerComment' }

  def self.directions
    @directions ||= {
      up: 'up',
      down: 'down'
    }
  end

  def self.reverse_direction(direction)
    if direction == directions[:up]
      directions[:down]
    elsif direction == directions[:down]
      directions[:up]
    else
      raise "Invalid direction: #{direction}"
    end
  end

  private

  def ensure_valid_comment
    comment = votable

    if direction != QuestionAnswerVote.directions[:up]
      errors.add(:base, I18n.t("post.qa.errors.comment_cannot_be_downvoted"))
    end

    if !comment.post.is_qa_topic?
      errors.add(:base, I18n.t("post.qa.errors.qa_not_enabled"))
    end
  end

  def ensure_valid_post
    post = votable

    if !post.is_qa_topic?
      errors.add(:base, I18n.t("post.qa.errors.qa_not_enabled"))
    elsif post.reply_to_post_number.present?
      errors.add(:base, I18n.t("post.qa.errors.voting_not_permitted"))
    end
  end
end

# == Schema Information
#
# Table name: question_answer_votes
#
#  id           :bigint           not null, primary key
#  user_id      :integer          not null
#  created_at   :datetime         not null
#  direction    :string           not null
#  votable_type :string           not null
#  votable_id   :integer          not null
#
# Indexes
#
#  idx_votable_user_id  (votable_type,votable_id,user_id) UNIQUE
#
