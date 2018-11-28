module Jobs
  class UpdatePostOrder < Jobs::Base
    def execute(args)
      category = Category.find(args[:category_id])
      qa_enabled = category.qa_enabled

      Topic.where(category_id: args[:category_id]).each do |topic|
        puts "HERE IS THE TOPIC: #{topic.title}"
        if qa_enabled
          Topic.update_vote_order(topic.id)
        else
          topic.posts.each do |post|
            puts "UPDATING COLUMN: #{post.post_number}"
            post.update_columns(sort_order: post.post_number)
          end
        end
      end
    end
  end
end
