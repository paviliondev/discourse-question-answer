export default {
  setupComponent(attrs, component) {
    const oneToMany = attrs.model.category && attrs.model.category.qa_one_to_many;

    let topicType = oneToMany ? 'qa_one_to_many' : 'qa';
    let label = `topic.tip.${topicType}.title`;
    let details = `topic.tip.${topicType}.details`;

    component.setProperties({
      label,
      details
    });
  }
}
