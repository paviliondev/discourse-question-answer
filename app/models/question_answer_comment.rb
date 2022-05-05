# frozen_string_literal: true

class QuestionAnswerComment < ActiveRecord::Base
  include Trashable

  # Bump this when changing MARKDOWN_FEATURES or MARKDOWN_IT_RULES
  COOKED_VERSION = 1

  belongs_to :post
  belongs_to :user

  validates :post_id, presence: true
  validates :user_id, presence: true
  validates :raw, presence: true
  validates :cooked, presence: true
  validates :cooked_version, presence: true

  validate :ensure_can_comment, on: [:create]

  validates_with QuestionAnswerCommentValidator

  before_validation :cook_raw, if: :will_save_change_to_raw?

  has_many :votes, class_name: "QuestionAnswerVote", as: :votable, dependent: :delete_all

  MARKDOWN_FEATURES = %w{
    censored
    emoji
  }

  MARKDOWN_IT_RULES = %w{
    emphasis
    backticks
    linkify
    link
  }

  def self.cook(raw)
    raw.gsub!(/(\n)+/, " ")
    PrettyText.cook(raw, features_override: MARKDOWN_FEATURES, markdown_it_rules: MARKDOWN_IT_RULES)
  end

  private

  def cook_raw
    self.cooked = self.class.cook(self.raw)
    self.cooked_version = COOKED_VERSION #TODO automatic rebaking once version is bumped
  end

  def ensure_can_comment
    if !post.is_qa_topic?
      errors.add(:base, I18n.t("qa.comment.errors.qa_not_enabled"))
    elsif post.reply_to_post_number.present?
      errors.add(:base, I18n.t("qa.comment.errors.not_permitted"))
    elsif self.class.where(post_id: self.post_id).count >= SiteSetting.qa_comment_limit_per_post
      errors.add(:base, I18n.t("qa.comment.errors.limit_exceeded", limit: SiteSetting.qa_comment_limit_per_post))
    end
  end
end

# == Schema Information
#
# Table name: question_answer_comments
#
#  id             :bigint           not null, primary key
#  post_id        :integer          not null
#  user_id        :integer          not null
#  raw            :text             not null
#  cooked         :text             not null
#  cooked_version :integer
#  deleted_at     :datetime
#  deleted_by_id  :integer
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  qa_vote_count  :integer          default(0)
#
# Indexes
#
#  index_question_answer_comments_on_deleted_by_id  (deleted_by_id) WHERE (deleted_by_id IS NOT NULL)
#  index_question_answer_comments_on_post_id        (post_id)
#  index_question_answer_comments_on_user_id        (user_id)
#
