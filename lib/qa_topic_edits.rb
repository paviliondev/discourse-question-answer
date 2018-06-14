module QATopicExtension
  def reload(options = nil)
    @answers = nil
    @comments = nil
    @last_answerer = nil
    super(options)
  end

  def answers
    @answers ||= posts.where(reply_to_post_number: [nil, '']).order("created_at DESC")
  end

  def comments
    @comments ||= posts.where.not(reply_to_post_number: [nil, '']).order("created_at DESC")
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
      @last_answerer ||= User.find(answers.last[:user_id])
    else
      nil
    end
  end
end

require_dependency 'topic'
class ::Topic
  prepend QATopicExtension
end

module TopicViewQAExtension
  def qa_enabled
    QAHelper.qa_enabled(@topic)
  end

  def filter_posts_by_ids(post_ids)
    if qa_enabled
      posts = Post.where(id: post_ids, topic_id: @topic.id)
        .includes(:user, :reply_to_user, :incoming_email)
      @posts = posts.order("case when post_number = 1 then 0 else 1 end, sort_order ASC")
      @posts = filter_post_types(@posts)
      @posts = @posts.with_deleted if @guardian.can_see_deleted_posts?
      @posts
    else
      super
    end
  end
end

class ::TopicView
  prepend TopicViewQAExtension
end

require 'topic_view_serializer'
class ::TopicViewSerializer
  attributes :qa_enabled,
             :voted,
             :last_answered_at,
             :last_commented_on,
             :answer_count,
             :comment_count,
             :last_answer_post_number,
             :last_answerer

  def qa_enabled
    @qa_enabled ||= QAHelper.qa_enabled(object.topic)
  end

  def voted
    scope.current_user && QAHelper.user_has_voted(object.topic, scope.current_user)
  end

  def last_answered_at
    object.topic.last_answered_at
  end

  def include_last_answered_at?
    qa_enabled
  end

  def last_commented_on
    object.topic.last_commented_on
  end

  def include_last_commented_on?
    qa_enabled
  end

  def answer_count
    object.topic.answer_count
  end

  def include_answer_count?
    qa_enabled
  end

  def comment_count
    object.topic.comment_count
  end

  def include_comment_count?
    qa_enabled
  end

  def last_answer_post_number
    object.topic.last_answer_post_number
  end

  def include_last_answer_post_number?
    qa_enabled
  end

  def last_answerer
    BasicUserSerializer.new(object.topic.last_answerer, scope: scope, root: false)
  end

  def include_last_answerer
    qa_enabled
  end
end
