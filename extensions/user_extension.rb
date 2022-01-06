# frozen_string_literal: true

module QuestionAnswer
  module UserExtension
    def self.included(base)
      base.has_many :question_answer_votes
    end
  end
end
