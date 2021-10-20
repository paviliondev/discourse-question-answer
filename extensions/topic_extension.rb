# frozen_string_literal: true

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
      @answers ||= begin
        posts
          .where(reply_to_post_number: nil)
          .order('created_at ASC')
      end
    end

    def first_answer
      posts
        .where(reply_to_post_number: nil)
        .where.not(post_number: 1)
        .order('sort_order')
        .first
    end

    def comments
      @comments ||= begin
        posts
          .where.not(reply_to_post_number: nil)
          .order('created_at ASC')
      end
    end

    def answer_count
      answers.count - 1 ## minus first post
    end

    def comment_count
      comments.count
    end

    def last_answered_at
      return unless answers.any?

      answers.last[:created_at]
    end

    def last_commented_on
      return unless comments.any?

      comments.last[:created_at]
    end

    def last_answer_post_number
      return unless answers.any?

      answers.last[:post_number]
    end

    def last_answerer
      return unless answers.any?

      @last_answerer ||= User.find(answers.last[:user_id])
    end

    def qa_enabled
      Topic.qa_enabled(self)
    end

    # class methods
    module ClassMethods
      def qa_can_vote(topic, user)
        return false if user.blank? || !SiteSetting.qa_enabled

        topic_vote_count = qa_votes(topic, user).count

        if topic_vote_count.positive? && !SiteSetting.qa_trust_level_vote_limits
          return false
        end

        trust_level = user.trust_level

        return false if trust_level.zero?

        topic_vote_limit = SiteSetting.send("qa_tl#{trust_level}_vote_limit")
        topic_vote_limit.to_i > topic_vote_count
      end

      # rename to something like qa_user_votes?
      def qa_votes(topic, user)
        return nil if !user || !SiteSetting.qa_enabled

        # This is a very inefficient way since the performance degrades as the
        # number of voted posts in the topic increases.
        QuestionAnswerVote
          .joins("INNER JOIN posts ON posts.id = question_answer_votes.post_id")
          .where(user: user)
          .where("posts.topic_id = ?", topic.id)
      end

      def qa_enabled(topic)
        return false unless SiteSetting.qa_enabled

        return false if !topic || topic&.is_category_topic?

        tags = topic.tags.map(&:name)

        if !(tags & SiteSetting.qa_blacklist_tags.split('|')).empty?
          return false
        end

        has_qa_tag = !(tags & SiteSetting.qa_tags.split('|')).empty?
        is_qa_category = topic.category.present? && topic.category.qa_enabled
        is_qa_subtype = topic.subtype == 'question'

        has_qa_tag || is_qa_category || is_qa_subtype
      end

      def qa_update_vote_order(topic_id)
        return unless SiteSetting.qa_enabled

        posts = Post.where(topic_id: topic_id)
        op = posts.find_by(post_number: 1)

        op.update(sort_order: 1)

        count = 2

        # OP comments
        op.comments.each do |c|
          c.update(sort_order: count)
          count += 1
        end

        answers = begin
          posts
            .where(reply_to_post_number: nil)
            .where.not(post_number: 1)
            .order("(
              SELECT COALESCE ((
                SELECT value::integer FROM post_custom_fields
                WHERE post_id = posts.id AND name = 'vote_count'
              ), 0)
            ) DESC, post_number ASC")
        end

        answers.each do |a|
          a.update(sort_order: count)

          comments = a.comments

          if comments.any?
            comments.each do |c|
              count += 1
              c.update(sort_order: count)
            end
          end

          count += 1
        end
      end
    end
  end
end
