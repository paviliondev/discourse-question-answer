module QAHelper
  class << self
    def qa_enabled(topic)
      return false if !SiteSetting.qa_enabled
      return false if topic.is_category_topic?
      
      tags = topic.tags.map(&:name)
      has_qa_tag = !(tags & SiteSetting.qa_tags.split('|')).empty?
      is_qa_category = topic.category && topic.category.custom_fields["qa_enabled"]
      is_qa_subtype = topic.subtype == 'question'
      has_qa_tag || is_qa_category || is_qa_subtype
    end

    ## This should be replaced with a :voted? property in TopicUser - but how to do this properly in a plugin?
    def user_has_voted(topic, user)
      return nil if !user || !SiteSetting.qa_enabled

      PostAction.exists?(post_id: topic.posts.map(&:id),
                         user_id: user.id,
                         post_action_type_id: PostActionType.types[:vote])
    end

    def update_order(topic_id)
      return if !SiteSetting.qa_enabled

      posts = Post.where(topic_id: topic_id)

      answers = posts.where(reply_to_post_number: [nil, ''])
        .where.not(post_number: 1)
        .order("vote_count DESC, post_number ASC")

      count = 1
      answers.each do |a|
        a.update(sort_order: count)
        comments = posts.where(reply_to_post_number: a.post_number)
          .order("post_number ASC")
        if comments.any?
          comments.each do |c|
            count += 1
            c.update(sort_order: count)
          end
        else
          count += 1
        end
      end
    end
  end
end
