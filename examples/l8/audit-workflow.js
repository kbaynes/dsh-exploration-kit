/**
 * Lesson 8's workflow script: audit the capability map by section, in parallel.
 *
 * This file is what you pass to the `workflow` tool. It has two parts deliberately:
 *
 *  - `capabilityRowsSchema` and `normalizeResults` are PURE. They are what the
 *    orchestration actually promises — a validated shape and a dense array — and they
 *    are unit-tested in `audit-workflow.test.mjs` without running a single agent.
 *  - `runWorkflow` is the part that needs a model.
 *
 * The same split as Lesson 6's projection: the logic worth trusting is testable; the
 * part that needs a provider is honestly marked as such.
 */

/** The result shape every fan-out returns. An object root is required. */
export const capabilityRowsSchema = {
  type: 'object',
  properties: {
    rows: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          capability: { type: 'string' },
          providedBy: { type: 'string' },
        },
        required: ['capability', 'providedBy'],
        additionalProperties: false,
      },
    },
  },
  required: ['rows'],
  additionalProperties: false,
}

/**
 * A stage that throws drops THAT item to `null` rather than failing the run, so the
 * caller must filter. Doing it centrally is what keeps the returned array dense.
 */
export function normalizeResults(results) {
  return results.filter(result => result !== null && result !== undefined && Array.isArray(result.rows))
}

/** Flatten one section's rows into the shape the audit table wants. */
export function flattenSections(results) {
  return normalizeResults(results).flatMap((result, index) =>
    result.rows.map(row => ({ ...row, sectionIndex: index })),
  )
}

/** Build the per-section prompt. Pure, so the wording is testable too. */
export function sectionPrompt(section) {
  return `Read content/feature-map.md and return the rows under "${section}" ` +
    'as a JSON array of {capability, providedBy}.'
}

/**
 * The workflow body. `agent`, `pipeline`, `phase`, and `log` are injected by the
 * workflow engine, so this function is only called from inside the tool.
 */
export async function runWorkflow({ agent, pipeline, phase, log }, sections) {
  phase('audit')

  const results = await pipeline(sections, async (section, _item, index) => {
    log(`auditing ${section}`)
    return agent(sectionPrompt(section), {
      label: `audit-${index}`,
      schema: capabilityRowsSchema,
    })
  })

  return flattenSections(results)
}
