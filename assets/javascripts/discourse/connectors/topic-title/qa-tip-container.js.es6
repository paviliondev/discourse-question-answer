export default {
  setupComponent(attrs, component) {
    const oneToMany =
      attrs.model.category && attrs.model.category.qa_one_to_many;
    const siteSettings = attrs.model.siteSettings;
    const showTip = attrs.model.showQaTip;

    let topicType = oneToMany ? "qa_one_to_many" : "qa";
    let label = `topic.tip.${topicType}.title`;
    let details = `topic.tip.${topicType}.details`;
    let detailsOpts = {
      tl1Limit: siteSettings.qa_tl1_vote_limit,
      tl2Limit: siteSettings.qa_tl2_vote_limit,
      tl3Limit: siteSettings.qa_tl3_vote_limit,
      tl4Limit: siteSettings.qa_tl4_vote_limit
    };

    component.setProperties({
      showTip,
      label,
      details,
      detailsOpts
    });
  }
};
