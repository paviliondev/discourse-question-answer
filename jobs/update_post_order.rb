# frozen_string_literal: true

module Jobs
  class UpdatePostOrder < ::Jobs::Base
    def execute(args)
      category = Category.find(args[:category_id])
      qa_enabled = category.qa_enabled

      Topic.where(category_id: args[:category_id]).each do |topic|
        if qa_enabled
          Topic.qa_update_vote_order(topic.id)
        else
          topic.posts.each do |post|
            post.update_columns(sort_order: post.post_number)
          end
        end
      end
    end
  end
end
