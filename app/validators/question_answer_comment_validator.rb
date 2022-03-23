# frozen_string_literal: true

class QuestionAnswerCommentValidator < ActiveModel::Validator
  def validate(record)
    raw_validator(record)
  end

  private

  def raw_validator(record)
    StrippedLengthValidator.validate(
      record, :raw, record.raw, SiteSetting.min_post_length..SiteSetting.qa_comment_max_raw_length
    )
  end
end
