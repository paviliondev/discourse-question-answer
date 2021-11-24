# frozen_string_literal: true

class CreateQuestionAnswerVotes < ActiveRecord::Migration[6.1]
  def up
    create_table :question_answer_votes do |t|
      t.integer :post_id, null: false
      t.integer :user_id, null: false
      t.datetime :created_at, null: false
    end

    add_index :question_answer_votes, [:post_id, :user_id], unique: true

    execute <<~SQL
    INSERT INTO question_answer_votes (post_id, user_id, created_at)
    SELECT
      X.post_id AS post_id,
      (X.value->>'user_id')::int AS user_id,
      (X.value->>'created_at')::timestamp AS created_at
    FROM (
      SELECT
        post_id,
        jsonb_array_elements(value::jsonb) AS value
      FROM post_custom_fields WHERE name = 'vote_history'
    ) AS X
    WHERE (X.value->>'action') != 'destroy'
    ORDER BY (X.value->>'created_at')::timestamp DESC
    ON CONFLICT DO NOTHING
    SQL

    execute <<~SQL
    DELETE FROM question_answer_votes
    USING (
      SELECT
        X.post_id AS post_id,
        (X.value->>'user_id')::int AS user_id,
        (X.value->>'created_at')::timestamp AS created_at
      FROM (
        SELECT
          post_id,
          jsonb_array_elements(value::jsonb) AS value
        FROM post_custom_fields WHERE name = 'vote_history'
      ) AS X
      WHERE (X.value->>'action') = 'destroy'
    ) AS Y
    WHERE question_answer_votes.post_id = Y.post_id
    AND question_answer_votes.user_id = Y.user_id
    AND question_answer_votes.created_at < Y.created_at
    SQL

    add_column :posts, :qa_vote_count, :integer, default: 0, null: true

    execute <<~SQL
    UPDATE posts p
    SET qa_vote_count = X.count
    FROM (
      SELECT
        post_id,
        COUNT(*) AS count
      FROM question_answer_votes
      GROUP BY post_id
    ) AS X
    WHERE X.post_id = p.id
    SQL
  end

  def down
    drop_table :question_answer_votes
    remove_index :question_answer_votes, [:post_id, :user_id]
  end
end
