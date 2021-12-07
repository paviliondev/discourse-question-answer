import Component from "@ember/component";
import discourseComputed from "discourse-common/utils/decorators";
import I18n from "I18n";
import { htmlSafe } from "@ember/template";

export default Component.extend({
  classNames: ["user-vote-count"],

  @discourseComputed("voteCount")
  userVoteCountText(voteCount) {
    return htmlSafe(I18n.t("user_vote_count", { voteCount }));
  },
});
