module QuestionAnswer
  module TopicExtension
    def self.included(base)
      base.extend(ClassMethods)
    end

    def reload(options = nil)
      @answers = nil
      @comments = nil
      @last_answerer = nil
      super(options)
    end

    def answers
      @answers ||= posts.where(reply_to_post_number: [nil, '']).order("created_at ASC")
    end

    def comments
      @comments ||= posts.where.not(reply_to_post_number: [nil, '']).order("created_at ASC")
    end

    def answer_count
      answers.count - 1 ## minus first post
    end

    def comment_count
      comments.count
    end

    def last_answered_at
      if answers.any?
        answers.last[:created_at]
      else
        nil
      end
    end

    def last_commented_on
      if comments.any?
        comments.last[:created_at]
      else
        nil
      end
    end

    def last_answer_post_number
      if answers.any?
        answers.last[:post_number]
      else
        nil
      end
    end

    def last_answerer
      if answers.any?
        @last_answerer ||= ::User.find(answers.last[:user_id])
      else
        nil
      end
    end

    module ClassMethods
      def qa_can_vote(topic, user)
        return false if !user || !SiteSetting.qa_enabled
        topic_vote_count = self.qa_votes(topic, user).length
        return false if topic_vote_count > 0 && !SiteSetting.qa_trust_level_vote_limits
        trust_level = user.trust_level
        return false if trust_level == 0
        topic_vote_limit = SiteSetting.send("qa_tl#{trust_level}_vote_limit")
        topic_vote_limit.to_i >= topic_vote_count
      end

      def qa_votes(topic, user) #rename to something like qa_user_votes?
        return nil if !user || !SiteSetting.qa_enabled
        PostCustomField.where(post_id: topic.posts.map(&:id),
                              name: 'voted',
                              value: user.id).pluck(:post_id)
      end

      def qa_enabled(topic)
        return false if !SiteSetting.qa_enabled
        return false if !topic || !topic.respond_to?(:is_category_topic?) || topic.is_category_topic?

        tags = topic.tags.map(&:name)
        has_qa_tag = !(tags & SiteSetting.qa_tags.split('|')).empty?
        is_qa_category = topic.category && topic.category.custom_fields["qa_enabled"]
        is_qa_subtype = topic.subtype == 'question'

        has_qa_tag || is_qa_category || is_qa_subtype
      end

      def qa_update_vote_order(topic_id)
        return if !SiteSetting.qa_enabled

        posts = Post.where(topic_id: topic_id)

        posts.where(post_number: 1).update(sort_order: 1)

        answers = posts.where(reply_to_post_number: [nil, ''])
          .where.not(post_number: 1)
          .order("(
            SELECT COALESCE ((
              SELECT value::integer FROM post_custom_fields
              WHERE post_id = posts.id AND name = 'vote_count'
            ), 0)
          ) DESC, post_number ASC")

        count = 2
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
end
