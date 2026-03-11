import { NitroModules } from 'react-native-nitro-modules'
import type { AudioBrowser as AudioBrowserSpec } from './specs/audio-browser.nitro.ts'

// Patch setTimeout so that zero-delay calls use queueMicrotask instead.
// When the phone is locked, RCTTiming pauses its CADisplayLink which breaks
// setTimeout entirely. Libraries like whatwg-fetch use setTimeout(fn, 0) to
// defer Promise resolution, causing fetch() to hang when backgrounded.
// queueMicrotask still works because it goes through Hermes's microtask queue
// which is drained by RuntimeScheduler after each event loop tick.
const _originalSetTimeout = globalThis.setTimeout
// @ts-expect-error - setTimeout overload signatures
globalThis.setTimeout = (handler: (...args: unknown[]) => void, timeout?: number, ...args: unknown[]) => {
  if (timeout === undefined || timeout === 0) {
    queueMicrotask(() => handler(...args))
    return -1
  }
  return _originalSetTimeout(handler, timeout, ...args)
}

export const nativeBrowser =
  NitroModules.createHybridObject<AudioBrowserSpec>('AudioBrowser')
