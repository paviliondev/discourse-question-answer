# frozen_string_literal: true

require_relative '../../plugin_helper'

describe QuestionAnswer::PostSerializerExtension do
  fab!(:user) { Fabricate(:user) }
  fab!(:category) { Fabricate(:category) }
  fab!(:topic) { Fabricate(:topic, category: category) }
  fab!(:post) { Fabricate(:post, topic: topic) }
  let(:up) { QuestionAnswer::Vote::UP }
  let(:create) { QuestionAnswer::Vote::CREATE }
  let(:destroy) { QuestionAnswer::Vote::DESTROY }
  let(:guardian) { Guardian.new(user) }
  let(:vote) do
    ->(u) do
      QuestionAnswer::Vote.vote(post, u, { direction: up, action: create })
    end
  end
  let(:undo_vote) do
    ->(u) do
      QuestionAnswer::Vote.vote(post, u, { direction: up, action: destroy })
    end
  end
  let(:create_serializer) do
    ->(g = guardian) do
      PostSerializer.new(
        post,
        scope: g,
        root: false
      ).as_json
    end
  end

  let(:dependent_keys) do
    %i[last_answerer last_answered_at answer_count last_answer_post_number]
  end

  let(:obj_keys) { %i[qa_vote_count qa_voted qa_enabled] }

  context 'qa enabled' do
    before do
      category.custom_fields['qa_enabled'] = true
      category.custom_fields['qa_one_to_many'] = true

      category.save!
      category.reload
    end

    it 'should qa_enabled' do
      serializer = create_serializer.call

      expect(serializer[:qa_enabled]).to eq(true)
    end

    describe '#actions_summary' do
      let(:get_summary) do
        ->(g = guardian) do
          serializer = create_serializer.call(g)

          serializer[:actions_summary]
            .find { |x| x[:id] == PostActionType.types[:vote] }
        end
      end

      it 'should not include qa action if has no votes and not logged in' do
        g = Guardian.new

        expect(get_summary.call(g)).to eq(nil)
      end

      it 'should include qa action if not logged in but has votes' do
        g = Guardian.new
        vote.call(user)

        expect(get_summary.call(g)).to be_truthy
      end

      it 'should include qa summary if has votes' do
        vote.call(user)

        expect(get_summary.call).to be_truthy
      end

      it 'should can_act if never voted' do
        expect(get_summary.call[:can_act]).to eq(true)
      end

      it 'should acted if voted' do
        vote.call(user)

        expect(get_summary.call[:acted]).to eq(true)
      end
    end

    it 'should return correct value from post' do
      obj_keys.each do |k|
        expect(create_serializer.call[k]).to eq(post.public_send(k))
      end
    end

    it 'should return correct value from topic' do
      serializer = create_serializer.call

      expect(serializer[:last_answerer][:id]).to eq(post.user.id)
      expect(serializer[:last_answerer][:username]).to eq(post.user.username)
      expect(serializer[:last_answerer][:name]).to eq(post.user.name)
      expect(serializer[:last_answerer][:avatar_template]).to eq(post.user.avatar_template)
      expect(serializer[:last_answerer_at]).to eq(nil)
      expect(serializer[:answer_count]).to eq(0)
      expect(serializer[:last_answer_post_number]).to eq(1)
    end
  end

  context 'qa disabled' do
    it 'should not qa_enabled' do
      serializer = create_serializer.call

      expect(serializer[:qa_enabled]).to eq(false)
    end

    it 'should not include dependent_keys' do
      dependent_keys.each do |k|
        expect(create_serializer.call.has_key?(k)).to eq(false)
      end
    end
  end
end
