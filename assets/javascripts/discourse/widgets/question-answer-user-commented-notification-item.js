import { DefaultNotificationItem } from "discourse/widgets/default-notification-item";
import { createWidgetFrom } from "discourse/widgets/widget";
import { iconNode } from "discourse-common/lib/icon-library";
import { postUrl } from "discourse/lib/utilities";
import { buildAnchorId } from "../widgets/qa-comment";

createWidgetFrom(
  DefaultNotificationItem,
  "question-answer-user-commented-notification-item",
  {
    url(data) {
      const attrs = this.attrs;
      const url = postUrl(attrs.slug, attrs.topic_id, attrs.post_number);
      return `${url}#${buildAnchorId(data.qa_comment_id)}`;
    },

    icon() {
      return iconNode("comment");
    },
  }
);
