# frozen_string_literal: true

# name: discourse-question-answer
# about: Question / Answer Style Topics
# version: 1.0.0
# authors: Angus McLeod, Muhlis Cahyono (muhlisbc@gmail.com)
# url: https://github.com/paviliondev/discourse-question-answer

%i[common desktop mobile].each do |type|
  register_asset "stylesheets/#{type}/question-answer.scss", type
end

enabled_site_setting :qa_enabled
require_relative 'lib/question_answer'

after_initialize do
  load File.expand_path('jobs/update_post_order.rb', __dir__)

  if respond_to?(:register_svg_icon)
    register_svg_icon 'angle-up'
    register_svg_icon 'info'
  end

  %w[
    qa_enabled
    qa_one_to_many
    qa_disable_like_on_answers
    qa_disable_like_on_questions
    qa_disable_like_on_comments
  ].each do |key|
    Category.register_custom_field_type(key, :boolean)
    add_to_serializer(:basic_category, key.to_sym) { object.send(key) }

    if Site.respond_to?(:preloaded_category_custom_fields)
      Site.preloaded_category_custom_fields << key
    end
  end

  class ::Guardian
    attr_accessor :post_opts
    prepend QuestionAnswer::GuardianExtension
  end

  class ::PostCreator
    prepend QuestionAnswer::PostCreatorExtension
  end

  class ::PostSerializer
    attributes(
      :qa_vote_count,
      :qa_voted,
      :qa_enabled,
      :last_answerer,
      :last_answered_at,
      :answer_count,
      :last_answer_post_number
    )

    prepend QuestionAnswer::PostSerializerExtension
  end

  register_post_custom_field_type('vote_history', :json)
  register_post_custom_field_type('vote_count', :integer)

  class ::Post
    include QuestionAnswer::PostExtension
  end

  PostActionType.types[:vote] = 100

  class ::PostActionType
    singleton_class.prepend QuestionAnswer::PostActionTypeExtension
  end

  class ::Topic
    include QuestionAnswer::TopicExtension
  end

  class ::TopicView
    prepend QuestionAnswer::TopicViewExtension
  end

  class ::TopicViewSerializer
    include QuestionAnswer::TopicViewSerializerExtension
  end

  class ::TopicListItemSerializer
    include QuestionAnswer::TopicListItemSerializerExtension
  end

  class ::Category
    include QuestionAnswer::CategoryExtension
  end

  class ::CategoryCustomField
    include QuestionAnswer::CategoryCustomFieldExtension
  end
end
