# frozen_string_literal: true

module QuestionAnswer
  module PostActionTypeExtension
    def public_types
      @public_types ||= super.except(:vote)
    end
  end
end
