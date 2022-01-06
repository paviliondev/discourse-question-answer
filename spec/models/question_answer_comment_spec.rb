# frozen_string_literal: true

require 'rails_helper'

describe QuestionAnswerComment do
  fab!(:post) { Fabricate(:post) }
  fab!(:user) { Fabricate(:user) }
  fab!(:tag) { Fabricate(:tag) }

  before do
    SiteSetting.qa_enabled = true
    SiteSetting.qa_tags = tag.name
    post.topic.tags << tag
  end

  context 'validations' do
    it 'does not allow comments to be created when qa is disabled' do
      SiteSetting.qa_enabled = false

      qa_comment = QuestionAnswerComment.new(raw: 'this is a **post**', post: post, user: user)

      expect(qa_comment.valid?).to eq(false)
      expect(qa_comment.errors.full_messages).to contain_exactly(I18n.t("qa.comment.errors.qa_not_enabled"))
    end

    it 'does not allow comments to be created when post is in reply to another post' do
      SiteSetting.qa_enabled = false
      post.update!(reply_to_post_number: 2)
      SiteSetting.qa_enabled = true

      qa_comment = QuestionAnswerComment.new(raw: 'this is a **post**', post: post, user: user)

      expect(qa_comment.valid?).to eq(false)
      expect(qa_comment.errors.full_messages).to contain_exactly(I18n.t("qa.comment.errors.not_permitted"))
    end

    it 'does not allow comments to be created when SiteSetting.qa_comment_limit_per_post has been reached' do
      SiteSetting.qa_comment_limit_per_post = 1

      QuestionAnswerComment.create!(raw: 'this is a **post**', post: post, user: user)
      qa_comment = QuestionAnswerComment.new(raw: 'this is a **post**', post: post, user: user)

      expect(qa_comment.valid?).to eq(false)

      expect(qa_comment.errors.full_messages).to contain_exactly(
        I18n.t("qa.comment.errors.limit_exceeded", limit: SiteSetting.qa_comment_limit_per_post)
      )
    end
  end

  context 'callbacks' do
    it 'cooks raw before saving' do
      qa_comment = QuestionAnswerComment.new(raw: 'this is a **post**', post: post, user: user)

      expect(qa_comment.valid?).to eq(true)
      expect(qa_comment.cooked).to eq("<p>this is a <strong>post</strong></p>")
      expect(qa_comment.cooked_version).to eq(described_class::COOKED_VERSION)
    end
  end

  describe '.cook' do
    it 'supports emphasis markdown rule' do
      qa_comment = Fabricate(:qa_comment, post: post, raw: "**bold**")

      expect(qa_comment.cooked).to eq("<p><strong>bold</strong></p>")
    end

    it 'supports backticks markdown rule' do
      qa_comment = Fabricate(:qa_comment, post: post, raw: "`test`")

      expect(qa_comment.cooked).to eq("<p><code>test</code></p>")
    end

    it 'supports link markdown rule' do
      qa_comment = Fabricate(:qa_comment, post: post, raw: "[test link](https://www.example.com)")

      expect(qa_comment.cooked).to eq("<p><a href=\"https://www.example.com\" rel=\"noopener nofollow ugc\">test link</a></p>")
    end

    it 'supports linkify markdown rule' do
      qa_comment = Fabricate(:qa_comment, post: post, raw: "https://www.example.com")

      expect(qa_comment.cooked).to eq("<p><a href=\"https://www.example.com\" rel=\"noopener nofollow ugc\">https://www.example.com</a></p>")
    end

    it 'supports emoji markdown engine' do
      qa_comment = Fabricate(:qa_comment, post: post, raw: ':grin:')

      expect(qa_comment.cooked).to eq("<p><img src=\"/images/emoji/twitter/grin.png?v=#{Emoji::EMOJI_VERSION}\" title=\":grin:\" class=\"emoji only-emoji\" alt=\":grin:\"></p>")
    end

    it 'supports censored markdown engine' do
      watched_word = Fabricate(:watched_word, action: WatchedWord.actions[:censor], word: "testing")

      qa_comment = Fabricate(:qa_comment, post: post, raw: watched_word.word)

      expect(qa_comment.cooked).to eq("<p>■■■■■■■</p>")
    end

    it 'removes newlines from raw as comments should only support a single paragraph' do
      qa_comment = Fabricate(:qa_comment, post: post, raw: <<~RAW)
      line 1

      line 2
      RAW

      expect(qa_comment.cooked).to eq("<p>line 1 line 2</p>")
    end
  end
end
