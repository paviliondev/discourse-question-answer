# frozen_string_literal: true

describe PostsController do
  fab!(:user) { Fabricate(:user) }

  describe '#create' do
    before do
      sign_in(user)
      SiteSetting.qa_enabled = true
    end

    it "creates a topic with the right subtype when create_as_qa param is provided" do
      post "/posts.json", params: {
        raw: 'this is some raw',
        title: 'this is some title',
        create_as_qa: true,
      }

      expect(response.status).to eq(200)

      topic = Topic.last

      expect(topic.is_qa?).to eq(true)
    end

    it "ignores create_as_qa param when trying to create private message" do
      post "/posts.json", params: {
        raw: 'this is some raw',
        title: 'this is some title',
        create_as_qa: true,
        archetype: Archetype.private_message,
        target_recipients: user.username
      }

      expect(response.status).to eq(200)

      topic = Topic.last

      expect(topic.is_qa?).to eq(false)
    end
  end
end
