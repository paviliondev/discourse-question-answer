# name: discourse-question-answer
# about: Question / Answer Style Topics
# version: 0.3
# authors: Angus McLeod
# url: https://github.com/angusmcleod/discourse-question-answer

register_asset 'stylesheets/common/question-answer.scss'
register_asset 'stylesheets/desktop/question-answer.scss', :desktop
register_asset 'stylesheets/mobile/question-answer.scss', :mobile

enabled_site_setting :qa_enabled

after_initialize do
  Category.register_custom_field_type('qa_enabled', :boolean)
  add_to_serializer(:basic_category, :qa_enabled) { object.custom_fields["qa_enabled"] }

  PostActionType.types[:vote] = 100

  module PostActionTypeExtension
    def public_types
      @public_types ||= super.except(:vote)
    end
  end

  require_dependency 'post_action_type'
  class ::PostActionType
    singleton_class.prepend PostActionTypeExtension
  end

  load File.expand_path('../lib/qa.rb', __FILE__)
  load File.expand_path('../lib/qa_post_edits.rb', __FILE__)
  load File.expand_path('../lib/qa_topic_edits.rb', __FILE__)
  load File.expand_path('../lib/qa_diary_edits.rb', __FILE__)
end
