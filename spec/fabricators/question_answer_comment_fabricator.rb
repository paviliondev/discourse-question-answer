# frozen_string_literal: true

Fabricator(:qa_comment, class_name: :question_answer_comment) do
  user
  post
  raw "Hello world"
end
