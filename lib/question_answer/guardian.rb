# frozen_string_literal: true

module QuestionAnswer
  module Guardian
    def can_edit_comment?(comment)
      return false if !self.user
      return true if comment.user_id == self.user.id
      return true if self.is_admin?
      false
    end

    def can_delete_comment?(comment)
      can_edit_comment?(comment)
    end
  end
end
