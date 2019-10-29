# name: discourse-question-answer
# about: Question / Answer Style Topics
# version: 0.3
# authors: Angus McLeod
# url: https://github.com/angusmcleod/discourse-question-answer

register_asset 'stylesheets/common/question-answer.scss'
register_asset 'stylesheets/desktop/question-answer.scss', :desktop
register_asset 'stylesheets/mobile/question-answer.scss', :mobile

enabled_site_setting :qa_enabled

if respond_to?(:register_svg_icon)
  register_svg_icon "angle-up"
  register_svg_icon "info"
end

after_initialize do
  [
    'qa_enabled',
    'qa_one_to_many',
    'qa_disable_like_on_answers',
    'qa_disable_like_on_questions',
    'qa_disable_like_on_comments',
    'qa_disable_bottom_votes'
  ].each do |key|
    Category.register_custom_field_type(key, :boolean)
    Site.preloaded_category_custom_fields << key if Site.respond_to? :preloaded_category_custom_fields
    add_to_serializer(:basic_category, key.to_sym) { object.send(key) }
  end

  require_dependency 'category'
  class ::Category
    def qa_enabled
      ActiveModel::Type::Boolean.new.cast(self.custom_fields['qa_enabled'])
    end

    def qa_one_to_many
      ActiveModel::Type::Boolean.new.cast(self.custom_fields['qa_one_to_many'])
    end
    
    def qa_disable_like_on_answers
      ActiveModel::Type::Boolean.new.cast(self.custom_fields['qa_disable_like_on_answers'])
    end
    
    def qa_disable_like_on_questions
      ActiveModel::Type::Boolean.new.cast(self.custom_fields['qa_disable_like_on_questions'])
    end
    
    def qa_disable_like_on_comments
      ActiveModel::Type::Boolean.new.cast(self.custom_fields['qa_disable_like_on_comments'])
    end
	
    def qa_disable_bottom_votes
      ActiveModel::Type::Boolean.new.cast(self.custom_fields['qa_disable_bottom_votes'])
    end
  end

  require_dependency 'category_custom_field'
  class ::CategoryCustomField
    after_commit :update_post_order, if: :qa_enabled_changed

    def qa_enabled_changed
      name == 'qa_enabled'
    end

    def update_post_order
      Jobs.enqueue(:update_post_order, category_id: category_id)
    end
  end

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
  
  register_post_custom_field_type('vote_history', :json)

  load File.expand_path('../lib/qa.rb', __FILE__)
  load File.expand_path('../lib/qa_post_edits.rb', __FILE__)
  load File.expand_path('../lib/qa_topic_edits.rb', __FILE__)
  load File.expand_path('../lib/qa_one_to_many_edits.rb', __FILE__)
  load File.expand_path('../jobs/update_post_order.rb', __FILE__)
end
