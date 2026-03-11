# Background Audio / Lock Screen Fix

## Problem

When the iPhone is locked and a user interacts via CarPlay, async JS callbacks (`handleTrackLoad`, browse callbacks, search callbacks) hang indefinitely. `fetch()` never resolves, `setTimeout` never fires.

## Root Cause Chain

1. **RCTTiming pauses when locked**: iOS suspends `CADisplayLink`, which RCTTiming uses to fire `setTimeout`/`setInterval` callbacks.
2. **`whatwg-fetch` uses `setTimeout(fn, 0)`**: In `xhr.onload`, `xhr.onerror`, `xhr.ontimeout`, and `xhr.onabort`, the polyfill wraps Promise resolve/reject in `setTimeout(fn, 0)`.
3. **Result**: Even though the entire native networking chain completes successfully, the fetch Promise never resolves because the `setTimeout(fn, 0)` callback is never fired.

## What Works When Locked

- **Process**: Alive (background audio entitlement keeps it running)
- **JS thread**: Alive, CFRunLoop processes blocks
- **RuntimeScheduler**: Tasks execute normally via `scheduleWork`
- **Microtask draining**: `queueMicrotask` and `Promise.resolve()` work because Hermes `drainMicrotasks()` is called by RuntimeScheduler after each event loop tick
- **Native URLSession.shared**: HTTP requests complete fine
- **Nitro/JSI callbacks**: Void callbacks go through `CallInvokerDispatcher` → `RuntimeScheduler::scheduleWork` → JS thread CFRunLoop
- **`_jsTick` mechanism**: A void Nitro callback called on a 100ms timer, forces RuntimeScheduler to process tasks and drain microtasks

## What Breaks When Locked

- **`setTimeout` / `setInterval`**: RCTTiming pauses its CADisplayLink
- **`fetch()`**: Because whatwg-fetch defers resolve/reject via `setTimeout(fn, 0)`
- **Any code depending on RCTTiming**: Animations, debounce timers, etc.

## Diagnostic Trail

We traced the full chain with NSLog/LOG(INFO) statements to confirm:

1. `RCTNetworking.mm` `sendRequest` → called ✓
2. `dispatch_async(_methodQueue)` → executes ✓
3. `RCTHTTPRequestHandler.mm` `[task resume]` → URLSession data task starts ✓
4. URLSession delegate callbacks fire → completion with no error ✓
5. `RCTEventEmitter.m` `sendEventWithName:` → all 4 events dispatched ✓
   - `didReceiveNetworkResponse`, `didReceiveNetworkDataProgress`, `didReceiveNetworkData`, `didCompleteNetworkResponse`
6. `RCTCallableJSModules.m` → bridgeless invoker path ✓
7. `RCTInstance.mm` `callFunctionOnJSModule` → `_valid=1`, weakSelf not nil ✓
8. `ReactInstance.cpp` `callFunctionOnModule` → `bufferedRuntimeExecutor_->execute()` → scheduled ✓
9. **`callFunctionOnModule` lambda EXECUTES on JS thread** → `RCTDeviceEventEmitter.emit` runs ✓
10. **But fetch() Promise never resolves** → because `whatwg-fetch` wraps resolve in `setTimeout(fn, 0)` ✗

## The Fix

### 1. `_jsTick` mechanism (keeps JS event loop alive)

In `src/native.ts`, a void Nitro callback is set from JS:
```typescript
nativeBrowser._jsTick = () => {}
```

Native side (`RunLoopKeepAlive.swift`) calls this on a 100ms DispatchSource timer during async operations. Each call goes through Nitro → CallInvoker → RuntimeScheduler → JS thread, which triggers `drainMicrotasks()`.

### 2. `setTimeout(fn, 0)` → `queueMicrotask` patch

In `src/native.ts`, we monkey-patch `globalThis.setTimeout` so zero-delay calls use `queueMicrotask`:
```typescript
const _originalSetTimeout = globalThis.setTimeout
globalThis.setTimeout = (handler, timeout, ...args) => {
  if (timeout === undefined || timeout === 0) {
    queueMicrotask(() => handler(...args))
    return -1
  }
  return _originalSetTimeout(handler, timeout, ...args)
}
```

This fixes `whatwg-fetch` (and any other library using `setTimeout(fn, 0)` as a "next tick" pattern) without requiring patches to node_modules.

### 3. `withMainRunLoopKeepAlive` wrapper

Native async operations that invoke JS callbacks (track load, browse, search) are wrapped in `withMainRunLoopKeepAlive(jsTick:)` which manages the timer lifecycle.

## Key Architecture Details

### BufferedRuntimeExecutor
- After startup, `isBufferingEnabled_` is `false` (set by `flush()` after JS bundle loads)
- Fast path: directly calls `runtimeScheduler->scheduleWork()`
- Same path as Nitro's CallInvoker

### RuntimeScheduler_Modern
- `scheduleWork` → `scheduleTask(ImmediatePriority)` → `scheduleEventLoop()`
- `runEventLoop` loops through ALL pending tasks via `selectTask()` while loop
- Each `runEventLoopTick` calls `executeTask` then `performMicrotaskCheckpoint` → `drainMicrotasks()`

### Event delivery path (bridgeless/new arch)
```
RCTNetworking → RCTEventEmitter.sendEventWithName
  → RCTCallableJSModules.invokeModule
    → _bridgelessJSModuleMethodInvoker (set in RCTInstance.mm)
      → [self callFunctionOnJSModule:]
        → ReactInstance::callFunctionOnModule
          → BufferedRuntimeExecutor::execute
            → RuntimeScheduler::scheduleWork
              → scheduleEventLoop → runtimeExecutor_ → CFRunLoopPerformBlock on JS thread
                → runEventLoop → runEventLoopTick → executeTask (calls RCTDeviceEventEmitter.emit)
                  → performMicrotaskCheckpoint → drainMicrotasks
```

## Files Modified

- `src/native.ts` — setTimeout patch + _jsTick assignment
- `ios/Util/RunLoopKeepAlive.swift` — Timer-based JS event loop pump
- `ios/Browser/BrowserConfig.swift` — `awaitTrackLoadHandler` uses `withMainRunLoopKeepAlive`
- `ios/Browser/BrowserManager.swift` — Browse/search callbacks use `withMainRunLoopKeepAlive`
- `ios/HybridAudioBrowser.swift` — `_jsTick` property + `_httpGet` method
- `android/src/main/java/com/audiobrowser/AudioBrowser.kt` — `_jsTick` + `_httpGet` stubs
- `src/specs/audio-browser.nitro.ts` — `_jsTick` and `_httpGet` in Nitro spec
- `src/features/network.ts` — `nativeHttpGet` export
- `src/web/NativeAudioBrowser.ts` — Web stubs

## Diagnostic files modified in node_modules (temporary, revert on install)

- `Libraries/Network/RCTNetworking.mm` — NSLog at sendRequest, dispatch_async, completion, sendEvent
- `Libraries/Network/RCTHTTPRequestHandler.mm` — NSLog after [task resume]
- `React/Modules/RCTEventEmitter.m` — NSLog at sendEventWithName
- `React/Base/RCTCallableJSModules.m` — NSLog at invokeModule
- `ReactCommon/react/runtime/platform/ios/ReactCommon/RCTInstance.mm` — NSLog at bridgeless invoker + callFunctionOnJSModule
- `ReactCommon/react/runtime/ReactInstance.cpp` — LOG(INFO) at scheduling + executing
