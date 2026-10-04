// Run: node --test kit-plugins/l6/
import { test } from 'node:test'
import assert from 'node:assert/strict'
import { foldEvents, projection } from './fold.js'

test('folds l6/step events into the reported total', () => {
  const events = [
    { type: 'tool/result' },
    { type: 'l6/step', data: { label: 'tool-result', count: 1 } },
    { type: 'assistant/message' },
    { type: 'l6/step', data: { label: 'tool-result', count: 2 } },
    { type: 'l6/step', data: { label: 'tool-result', count: 3 } },
  ]
  assert.deepEqual(foldEvents(events), { total: 3 })
})

test('returns the SAME reference for unrelated events', () => {
  const state = projection.init()
  const next = projection.apply(state, { type: 'tool/result' })
  assert.equal(next, state, 'an unrelated event must not allocate new state')
})

test('returns a NEW reference for a relevant event', () => {
  const state = projection.init()
  const next = projection.apply(state, { type: 'l6/step', data: { count: 5 } })
  assert.notEqual(next, state)
  assert.deepEqual(next, { total: 5 })
})

test('a delta-shaped event would corrupt the total — the reason for complete state', () => {
  // Each event says "1", not "the running total". Folding gives 1, not 3.
  const deltaShaped = [
    { type: 'l6/step', data: { count: 1 } },
    { type: 'l6/step', data: { count: 1 } },
    { type: 'l6/step', data: { count: 1 } },
  ]
  assert.deepEqual(foldEvents(deltaShaped), { total: 1 })
  // The contract: producers must send the complete post-change total.
})
