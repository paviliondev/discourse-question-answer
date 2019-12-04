import { acceptance } from "helpers/qunit-helpers";

acceptance("Question Answer Composer", {
  loggedIn: true,
  pretend(server, helper) {
    server.get("/draft.json", () => {
      return helper.response({
        draft: null,
        draft_sequence: 42
      });
    });
    server.post("/uploads/lookup-urls", () => {
      return helper.response([]);
    });
  },
  settings: {
    enable_whispers: true
  }
});

QUnit.test("Composer Actions header content", async assert => {

});