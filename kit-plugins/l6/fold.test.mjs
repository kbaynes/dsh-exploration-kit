// Run: node --test kit-plugins/l6/fold.test.mjs
import { test } from 'node:test'
import assert from 'node:assert/strict'
import { foldEvents, projection, FOLDED_EVENT } from './fold.js'

test('folds the known event type into the reported mode', () => {
  const events = [
    { type: 'assistant/message' },
    { type: FOLDED_EVENT, data: { mode: 'workspace-write' } },
    { type: 'agent/inbox/spliced' },
  ]
  assert.deepEqual(foldEvents(events), { mode: 'workspace-write' })
})

test('the LATEST event wins, because the event carries complete state', () => {
  const events = [
    { type: FOLDED_EVENT, data: { mode: 'workspace-write' } },
    { type: FOLDED_EVENT, data: { mode: 'danger-full-access' } },
  ]
  assert.deepEqual(foldEvents(events), { mode: 'danger-full-access' })
})

test('folds a type the harness knows, not a plugin-declared one', () => {
  // The lesson's whole correction: an invented type makes the log unreadable after a
  // restart, so the unit must fold vocabulary the harness already has.
  assert.equal(FOLDED_EVENT, 'sandbox/mode')
  assert.ok(!/^l6\//.test(FOLDED_EVENT), 'the folded type must not be plugin-declared')
})

test('returns the SAME reference for unrelated events', () => {
  const state = projection.init()
  const next = projection.apply(state, { type: 'assistant/message' })
  assert.equal(next, state, 'an unrelated event must not allocate new state')
})

test('returns a NEW reference for a relevant event', () => {
  const state = projection.init()
  const next = projection.apply(state, { type: FOLDED_EVENT, data: { mode: 'read-only' } })
  assert.notEqual(next, state)
  assert.deepEqual(next, { mode: 'read-only' })
})
