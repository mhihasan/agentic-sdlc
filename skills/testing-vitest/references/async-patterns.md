# Async Testing Patterns

## Table of Contents
1. [findBy vs waitFor](#findby-vs-waitfor)
2. [Testing Loading and Error States](#testing-loading-and-error-states)
3. [waitForElementToBeRemoved](#waitforelementtoberemoved)
4. [Async Hooks](#async-hooks)
5. [Polling and Retry Logic](#polling-and-retry-logic)
6. [WebSocket Mocks](#websocket-mocks)

---

## findBy vs waitFor

**`findBy*`** — the right tool when waiting for a single element to appear.
It's a combination of `getBy*` + `waitFor`. Use it over `waitFor(() => getBy*(...))`.

```ts
// ✅ Clear and concise
it('shows the user name after data loads', async () => {
  render(<UserCard userId="1" />)
  expect(await screen.findByText('Jane Doe')).toBeInTheDocument()
})

// ❌ Verbose and redundant
it('shows the user name after data loads', async () => {
  render(<UserCard userId="1" />)
  await waitFor(() => {
    expect(screen.getByText('Jane Doe')).toBeInTheDocument()
  })
})
```

**`waitFor`** — use when you need to assert on something that requires multiple
conditions, or when asserting on the absence of an element:

```ts
it('removes the loading spinner and shows content', async () => {
  render(<DataTable />)
  await waitFor(() => {
    expect(screen.queryByRole('progressbar')).not.toBeInTheDocument()
    expect(screen.getByRole('table')).toBeInTheDocument()
  })
})
```

Keep `waitFor` callbacks synchronous — don't `await` inside `waitFor`.

---

## Testing Loading and Error States

A complete test suite for a data-fetching component covers three states:

```ts
describe('UserCard', () => {
  it('renders the loading skeleton initially', () => {
    // Don't resolve the mock — just check the initial state
    mockedFetchUser.mockReturnValue(new Promise(() => {})) // never resolves
    render(<UserCard userId="1" />)
    expect(screen.getByRole('status', { name: /loading/i })).toBeInTheDocument()
  })

  it('renders the user details after successful fetch', async () => {
    mockedFetchUser.mockResolvedValueOnce(createUser({ name: 'Jane Doe' }))
    render(<UserCard userId="1" />)
    expect(await screen.findByText('Jane Doe')).toBeInTheDocument()
    expect(screen.queryByRole('status', { name: /loading/i })).not.toBeInTheDocument()
  })

  it('renders the error message when the fetch fails', async () => {
    mockedFetchUser.mockRejectedValueOnce(new Error('Not found'))
    render(<UserCard userId="1" />)
    expect(await screen.findByRole('alert')).toHaveTextContent(/not found/i)
  })
})
```

---

## waitForElementToBeRemoved

More expressive than `waitFor(() => expect(el).not.toBeInTheDocument())`:

```ts
it('hides the spinner after the request completes', async () => {
  mockedFetchUser.mockResolvedValueOnce(createUser())
  render(<UserCard userId="1" />)

  const spinner = screen.getByRole('progressbar')
  await waitForElementToBeRemoved(spinner)

  expect(screen.getByText('Test User')).toBeInTheDocument()
})
```

You can also pass a callback: `waitForElementToBeRemoved(() => screen.queryByRole('progressbar'))`

---

## Async Hooks

When a hook triggers async work (fetches data, writes to a store), wrap state updates
in `act` and await the result:

```ts
import { renderHook, act, waitFor } from '@testing-library/react'
import { useUserData } from './useUserData'

describe('useUserData', () => {
  it('fetches and returns the user', async () => {
    mockedFetchUser.mockResolvedValueOnce(createUser({ name: 'Jane' }))
    const { result } = renderHook(() => useUserData('1'))

    expect(result.current.loading).toBe(true)

    await waitFor(() => expect(result.current.loading).toBe(false))

    expect(result.current.user?.name).toBe('Jane')
    expect(result.current.error).toBeNull()
  })

  it('sets the error when the fetch fails', async () => {
    mockedFetchUser.mockRejectedValueOnce(new Error('Server error'))
    const { result } = renderHook(() => useUserData('1'))

    await waitFor(() => expect(result.current.loading).toBe(false))

    expect(result.current.error?.message).toBe('Server error')
    expect(result.current.user).toBeNull()
  })
})
```

---

## Polling and Retry Logic

When testing a hook or component that polls (repeatedly fetches on an interval),
use fake timers to advance time without real waiting:

```ts
describe('usePollStatus', () => {
  beforeEach(() => vi.useFakeTimers())
  afterEach(() => vi.useRealTimers())

  it('re-fetches every 5 seconds', async () => {
    mockedFetchStatus.mockResolvedValue({ status: 'pending' })
    renderHook(() => usePollStatus('job-123'))

    expect(mockedFetchStatus).toHaveBeenCalledOnce()

    // Use async variant when timers and promises interleave
    await act(async () => {
      await vi.advanceTimersByTimeAsync(5_000)
    })

    expect(mockedFetchStatus).toHaveBeenCalledTimes(2)
  })

  it('stops polling when status is "complete"', async () => {
    mockedFetchStatus.mockResolvedValue({ status: 'complete' })
    renderHook(() => usePollStatus('job-123'))

    await act(async () => {
      await vi.advanceTimersByTimeAsync(15_000)
    })

    // Should not keep retrying after terminal state
    expect(mockedFetchStatus).toHaveBeenCalledOnce()
  })
})
```

---

## WebSocket Mocks

For components or hooks that use WebSocket, mock the global constructor:

```ts
class MockWebSocket {
  static instances: MockWebSocket[] = []
  url: string
  onmessage: ((event: MessageEvent) => void) | null = null
  onclose: (() => void) | null = null
  onerror: ((event: Event) => void) | null = null
  send = vi.fn()
  close = vi.fn()

  constructor(url: string) {
    this.url = url
    MockWebSocket.instances.push(this)
  }

  // Helper to simulate receiving a message from the server
  simulateMessage(data: unknown) {
    this.onmessage?.(new MessageEvent('message', { data: JSON.stringify(data) }))
  }
}

describe('useLiveUpdates', () => {
  beforeEach(() => {
    MockWebSocket.instances = []
    vi.stubGlobal('WebSocket', MockWebSocket)
  })

  afterEach(() => {
    vi.unstubAllGlobals()
  })

  it('updates the state when a message is received', async () => {
    const { result } = renderHook(() => useLiveUpdates('/ws/feed'))

    const socket = MockWebSocket.instances[0]
    act(() => socket.simulateMessage({ type: 'update', value: 42 }))

    expect(result.current.value).toBe(42)
  })
})
```
