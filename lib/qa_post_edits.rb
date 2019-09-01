module PostSerializerQAExtension
  def actions_summary
    summaries = super.reject { |s| s[:id] === PostActionType.types[:vote] }

    if object.qa_enabled
      user = scope.current_user
      summary = {
        id: PostActionType.types[:vote],
        count: object.qa_vote_count
      }

      if user
        voted = object.qa_voted.include?(user.id)

        if voted
          summary[:acted] = true
          summary[:can_undo] = ::QuestionAnswer::Vote.can_undo(object, user)
        else
          summary[:can_act] = true
        end
      end

      summary.delete(:count) if summary[:count] == 0

      if summary[:can_act] || summary[:count]
        summaries + [summary]
      else
        summaries
      end
    else
      summaries
    end
  end
end

require_dependency 'post_serializer'
class ::PostSerializer
  prepend PostSerializerQAExtension

  attributes :qa_vote_count,
             :qa_voted,
             :qa_enabled,
             :last_answerer,
             :last_answered_at,
             :answer_count,
             :last_answer_post_number,
             :last_answerer

  def qa_vote_count
    object.qa_vote_count
  end

  def qa_voted
    object.qa_voted
  end

  def qa_enabled
    object.qa_enabled
  end

  def last_answerer
    object.topic.last_answerer
  end

  def include_last_answerer?
    object.qa_enabled
  end

  def last_answered_at
    object.topic.last_answered_at
  end

  def include_last_answered_at?
    object.qa_enabled
  end

  def answer_count
    object.topic.answer_count
  end

  def include_answer_count?
    object.qa_enabled
  end

  def last_answer_post_number
    object.topic.last_answer_post_number
  end

  def include_last_answer_post_number?
    object.qa_enabled
  end

  def last_answerer
    object.topic.last_answerer
  end

  def include_last_answerer?
    object.qa_enabled
  end
end

## 'qa_vote_count' and 'qa_voted' are used for quick access, whereas 'qa_vote_history' is used for record keeping
## See QuestionAnswer::Vote for how these fields are saved / updated

Post.register_custom_field_type('vote_count', :integer)
Post.register_custom_field_type('vote_history', :json)

class ::Post
  after_create :qa_update_vote_order, if: :qa_enabled

  self.ignored_columns = %w(vote_count)

  def qa_vote_count
    if custom_fields['vote_count'].present?
      custom_fields['vote_count'].to_i
    else
      0
    end
  end

  def qa_voted
    if custom_fields['voted'].present?
      [*custom_fields['voted']].map(&:to_i)
    else
      []
    end
  end

  def qa_vote_history
    if custom_fields['vote_history'].present?
      [*custom_fields['vote_history']]
    else
      []
    end
  end

  def qa_enabled
    ::Topic.qa_enabled(topic)
  end

  def qa_update_vote_order
    ::Topic.qa_update_vote_order(topic_id)
  end

  def qa_last_voted(user_id)
    user_votes = qa_vote_history.select do |v|
      v['user_id'].to_i === user_id && v['action'] === 'create'
    end

    if user_votes.any?
      user_votes.sort_by { |v| v['created_at'].to_i }.first['created_at'].to_datetime
    else
      nil
    end
  end
  
  def qa_can_vote(user_id)
    SiteSetting.qa_tl_allow_multiple_votes_per_post ||
    !qa_voted.include?(user_id)
  end
end
