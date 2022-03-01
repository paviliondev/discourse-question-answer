# frozen_string_literal: true

module QuestionAnswer
  module TopicViewExtension
    def self.included(base)
      base.attr_accessor(
        :comments,
        :comments_counts,
        :posts_user_voted,
        :comments_user_voted,
        :posts_voted_on
      )

      unless base.const_defined?(:PRELOAD_COMMENTS_COUNT)
        base.const_set :PRELOAD_COMMENTS_COUNT, 5
      end
    end
  end
end
