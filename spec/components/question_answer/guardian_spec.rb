# frozen_string_literal: true

require 'rails_helper'

describe QuestionAnswer::GuardianExtension do
  fab!(:user1) { Fabricate(:user) }
  fab!(:user2) { Fabricate(:user) }
  fab!(:category) { Fabricate(:category) }
  fab!(:topic) { Fabricate(:topic, category: category, user: user1) }
  let(:post_opts) { { raw: 'blah' } }

  before do
    category.custom_fields['qa_enabled'] = true
    category.custom_fields['qa_one_to_many'] = true

    category.save!
    category.reload
  end

  it 'should can create post if user.id equal topic.user_id' do
    guardian = Guardian.new(user1)
    guardian.post_opts = post_opts

    expect(guardian.can_create_post_on_topic?(topic)).to eq(true)
  end

  it "should can't create post if user.id not equal topic.user_id" do
    guardian = Guardian.new(user2)
    guardian.post_opts = post_opts

    expect(guardian.can_create_post_on_topic?(topic)).to eq(false)
  end
end
