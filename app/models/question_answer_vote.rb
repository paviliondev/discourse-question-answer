# frozen_string_literal: true

class QuestionAnswerVote < ActiveRecord::Base
  belongs_to :post
  belongs_to :user

  validates :direction, inclusion: { in: ['up', 'down'] }
  validates :post_id, presence: true
  validates :user_id, presence: true
  validate :ensure_valid_post

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

  def ensure_valid_post
    if !post.qa_enabled
      errors.add(:base, I18n.t("post.qa.errors.qa_not_enabled"))
    elsif post.post_number == 1 || post.reply_to_post_number.present?
      errors.add(:base, I18n.t("post.qa.errors.voting_not_permitted"))
    end
  end
end
