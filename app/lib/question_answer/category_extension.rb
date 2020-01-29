module QuestionAnswer
  module CategoryExtension
    def qa_enabled
      ActiveModel::Type::Boolean.new.cast(self.custom_fields['qa_enabled'])
    end

    def qa_one_to_many
      ActiveModel::Type::Boolean.new.cast(self.custom_fields['qa_one_to_many'])
    end

    def qa_disable_like_on_answers
      ActiveModel::Type::Boolean.new.cast(self.custom_fields['qa_disable_like_on_answers'])
    end

    def qa_disable_like_on_questions
      ActiveModel::Type::Boolean.new.cast(self.custom_fields['qa_disable_like_on_questions'])
    end

    def qa_disable_like_on_comments
      ActiveModel::Type::Boolean.new.cast(self.custom_fields['qa_disable_like_on_comments'])
    end
  end
end
