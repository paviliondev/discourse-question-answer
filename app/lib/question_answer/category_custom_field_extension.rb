module QuestionAnswer
  module CategoryCustomFieldExtension
    after_commit :update_post_order, if: :qa_enabled_changed

    def qa_enabled_changed
      name == 'qa_enabled'
    end

    def update_post_order
      Jobs.enqueue(:update_post_order, category_id: category_id)
    end
  end
end
