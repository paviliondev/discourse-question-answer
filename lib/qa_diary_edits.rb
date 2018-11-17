module DiaryGuardianExtension
  def can_create_post_on_topic?(topic)
    post = self.try(:post_opts) || {}
    if topic.category &&
      topic.category.custom_fields["qa_enabled"] &&
      SiteSetting.qa_diary_format &&
      post.present? &&
      !post[:reply_to_post_number]
      return @user.id == topic.user_id
    end
    super(topic)
  end
end

class ::Guardian
  attr_accessor :post_opts
  prepend DiaryGuardianExtension
end

module DiaryPostCreatorExtension
  def valid?
    guardian.post_opts = @opts
    super
  end
end

class ::PostCreator
  prepend DiaryPostCreatorExtension
end
