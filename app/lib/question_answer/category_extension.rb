# frozen_string_literal: true

module QuestionAnswer
  module CategoryExtension
    def qa_cast(key)
      ActiveModel::Type::Boolean.new.cast(custom_fields[key])
    end

    %i[
      qa_enabled
      qa_one_to_many
      qa_disable_like_on_answers
      qa_disable_like_on_questions
      qa_disable_like_on_comments
    ].each do |key|
      define_method(key) { qa_cast(key) }
    end
  end
end
