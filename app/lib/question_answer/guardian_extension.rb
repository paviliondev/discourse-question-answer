# frozen_string_literal: true

module QuestionAnswer
  module GuardianExtension
    def can_create_post_on_topic?(topic)
      post = self.try(:post_opts) || {}
      category = topic.category

      if category.present? &&
         category.qa_enabled &&
         category.qa_one_to_many &&
         post.present? &&
         !post[:reply_to_post_number]

        return @user.id == topic.user_id
      end

      super(topic)
    end
  end
end
