# frozen_string_literal: true

module Jobs
  class UpdateCategoryPostOrder < ::Jobs::Base
    def execute(args)
      category = Category.find_by(id: args[:category_id])

      return if category.blank?

      qa_enabled = category.qa_enabled

      Topic.where(category_id: category.id).each do |topic|
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
