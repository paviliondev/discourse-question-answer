# frozen_string_literal: true

module QuestionAnswer
  module TopicTagExtension
    def self.included(base)
      base.after_destroy :update_post_order, if: :qa_tag?
    end
    
    def qa_tag?
      if tag = Tag.find_by(id: tag_id)
        !([tag.name] & SiteSetting.qa_tags.split('|')).empty? 
      else
        false
      end
    end

    def update_post_order
      Jobs.enqueue(:update_topic_post_order, topic_id: topic_id)
    end
  end
end
