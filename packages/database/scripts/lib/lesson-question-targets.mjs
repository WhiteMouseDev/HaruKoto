/** Validate source-only SRS references without inferring targets from question order/type. */
export function validateQuestionSrsTarget(
  question,
  { level, vocabularyByLevel, grammarByLevel }
) {
  const errors = [];
  const targetFields = ['vocabulary_order', 'grammar_order'];
  const references = targetFields.filter((field) =>
    Object.hasOwn(question, field)
  );
  const hasSkip = Object.hasOwn(question, 'srs_skip_reason');

  if (
    Object.hasOwn(question, 'vocabulary_id') ||
    Object.hasOwn(question, 'grammar_id')
  ) {
    errors.push(
      'source questions must use level-scoped order references, not database UUIDs'
    );
  }

  if (hasSkip) {
    if (
      typeof question.srs_skip_reason !== 'string' ||
      question.srs_skip_reason.trim() === ''
    ) {
      errors.push('srs_skip_reason must be a non-empty review reason');
    }
    if (references.length > 0) {
      errors.push('srs_skip_reason cannot be combined with an SRS target');
    }
    return errors;
  }

  if (references.length !== 1) {
    errors.push(
      'exactly one vocabulary_order or grammar_order, or srs_skip_reason, is required'
    );
    return errors;
  }

  const field = references[0];
  const order = question[field];
  if (!Number.isInteger(order) || order < 1) {
    errors.push(`${field} must be a positive integer`);
    return errors;
  }

  const catalog =
    field === 'vocabulary_order' ? vocabularyByLevel : grammarByLevel;
  if (!catalog.get(level)?.has(order)) {
    errors.push(`${field} ${order} not found for ${level}`);
  }
  return errors;
}
