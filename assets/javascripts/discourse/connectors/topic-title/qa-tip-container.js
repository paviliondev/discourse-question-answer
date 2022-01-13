export default {
  setupComponent(attrs, component) {
    const siteSettings = attrs.model.siteSettings;
    const showTip = attrs.model.showQaTip;

    let topicType = "qa";
    let label = `topic.tip.${topicType}.title`;
    let details = `topic.tip.${topicType}.details`;
    let detailsOpts = {
      tl1Limit: siteSettings.qa_tl1_vote_limit,
      tl2Limit: siteSettings.qa_tl2_vote_limit,
      tl3Limit: siteSettings.qa_tl3_vote_limit,
      tl4Limit: siteSettings.qa_tl4_vote_limit,
    };

    component.setProperties({
      showTip,
      label,
      details,
      detailsOpts,
    });
  },
};
