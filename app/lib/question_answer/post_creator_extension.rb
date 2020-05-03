# frozen_string_literal: true

module QuestionAnswer
  module PostCreatorExtension
    def valid?
      guardian.post_opts = @opts
      super
    end
  end
end
