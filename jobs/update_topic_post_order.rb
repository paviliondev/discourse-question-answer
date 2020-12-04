# frozen_string_literal: true

module Jobs
  class UpdateTopicPostOrder < ::Jobs::Base
    def execute(args)
      topic = Topic.find_by(id: args[:topic_id])

      return if topic.blank?
      
      if topic.qa_enabled
        Topic.qa_update_vote_order(topic.id)
      else
        topic.posts.each do |post|
          post.update_columns(sort_order: post.post_number)
        end
      end
    end
  end
end