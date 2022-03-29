import I18n from "I18n";
import { test } from "qunit";
import { visit } from "@ember/test-helpers";
import { acceptance, queryAll } from "discourse/tests/helpers/qunit-helpers";

acceptance("Discourse Question Answer - notifications", function (needs) {
  needs.user();

  needs.pretender((server, helper) => {
    server.get("/notifications", () => {
      return helper.response({
        notifications: [
          {
            id: 1,
            user_id: 26,
            notification_type: 35,
            post_number: 1,
            topic_id: 59,
            fancy_title: "some fancy title",
            slug: "some-slug",
            data: {
              display_username: "someuser",
              qa_comment_id: 123,
            },
          },
        ],
        total_rows_notifications: 1,
      });
    });
  });

  test("viewing comments notifications", async (assert) => {
    await visit("/u/eviltrout/notifications");

    const notification = queryAll("ul.notifications")[0];

    assert.strictEqual(
      notification.textContent,
      "someuser some fancy title",
      "displays the username of user that commented and topic's title in notification"
    );

    assert.ok(
      notification
        .querySelector("a")
        .href.includes("/t/some-slug/59#qa-comment-123"),
      "displays a link with a hash fragment pointing to the comment id"
    );

    assert.strictEqual(
      notification.querySelector("a").title,
      I18n.t("notifications.titles.question_answer_user_commented"),
      "displays the right title"
    );
  });
});
