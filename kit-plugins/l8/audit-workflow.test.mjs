// Run: node --test kit-plugins/l8/audit-workflow.test.mjs
import { test } from 'node:test'
import assert from 'node:assert/strict'
import {
  capabilityRowsSchema,
  sectionPrompt,
  normalizeResults,
  flattenSections,
  runWorkflow,
} from './audit-workflow.js'

test('the schema has an object root with additionalProperties declared', () => {
  assert.equal(capabilityRowsSchema.type, 'object')
  assert.equal(capabilityRowsSchema.additionalProperties, false)
  assert.equal(capabilityRowsSchema.properties.rows.type, 'array')
})

test('a throwing stage drops that item, so the result must be filtered', () => {
  // pipeline() resolves a failed item to null — it does not reject the whole run.
  const results = [{ rows: [{ capability: 'a', providedBy: 'pkg' }] }, null, undefined]
  assert.equal(normalizeResults(results).length, 1)
})

test('a malformed result is dropped rather than crashing the flatten', () => {
  const results = [{ rows: [] }, { notRows: true }, 'nonsense', null]
  assert.deepEqual(normalizeResults(results), [{ rows: [] }])
})

test('flattening keeps rows in order and tags their section', () => {
  const results = [
    { rows: [{ capability: 'a', providedBy: 'x' }] },
    { rows: [{ capability: 'b', providedBy: 'y' }, { capability: 'c', providedBy: 'z' }] },
  ]
  assert.deepEqual(flattenSections(results), [
    { capability: 'a', providedBy: 'x', sectionIndex: 0 },
    { capability: 'b', providedBy: 'y', sectionIndex: 1 },
    { capability: 'c', providedBy: 'z', sectionIndex: 1 },
  ])
})

test('dense output survives a partially failed fan-out', () => {
  const results = [null, { rows: [{ capability: 'survivor', providedBy: 'pkg' }] }, null]
  const flat = flattenSections(results)
  assert.equal(flat.length, 1)
  assert.equal(flat[0].capability, 'survivor')
})

test('the prompt names the section verbatim', () => {
  assert.match(sectionPrompt('1. Plugin core'), /"1\. Plugin core"/)
})

test('runWorkflow drives pipeline, logs each item, and returns a dense array', async () => {
  const logged = []
  const phases = []
  const seen = []
  const deps = {
    pipeline: async (items, stage) => Promise.all(items.map((item, index) => stage(item, item, index))),
    phase: name => phases.push(name),
    log: message => logged.push(message),
    agent: async (prompt, opts) => {
      seen.push({ prompt, opts })
      return { rows: [{ capability: `cap-${seen.length}`, providedBy: 'pkg' }] }
    },
  }

  const out = await runWorkflow(deps, ['Section A', 'Section B'])

  assert.deepEqual(phases, ['audit'])
  assert.equal(logged.length, 2)
  assert.equal(out.length, 2, 'both items contributed a row')
  assert.equal(seen.length, 2, 'one agent per item')
  assert.equal(seen[0].opts.schema, capabilityRowsSchema, 'the schema is passed through')
  assert.match(seen[1].prompt, /Section B/)
})
