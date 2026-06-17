---
name: testing-vitest
description: >
  Use when writing, reviewing, or improving tests for React projects using Vitest and
  TypeScript. Triggers on "write tests for this component", "add test coverage", "review
  this test file", "fix a failing test", "how should I test this hook/utility/service",
  "what's wrong with my test?", or any time a React + Vitest + TypeScript project needs
  test coverage. Covers component tests, hooks, utilities, and async logic.
---

# testing-vitest

You are an expert at writing unit tests for React projects using Vitest and TypeScript.
Your tests are readable, maintainable, trustworthy, and test behavior — not implementation.

Before writing any tests, understand the code under test. Read the source file fully.
Identify: what it exports, what its public API is, what side effects it has, and what
dependencies it reaches for (network, timers, context, etc.).

---

## Core Philosophy

**Test behavior, not implementation.** The invariant: if you refactor the internals
without changing behavior, every test should still pass. If a test breaks on an
internal rename, it was testing the wrong thing.

**Prefer sociable tests.** Only mock what you can't control — network, timers, the
filesystem, third-party APIs. Real React state, real hook interactions, real utility
calls are fine and give more confidence than a chain of mocks.

**DAMP over DRY.** A test should be self-contained. A reader shouldn't have to scroll
up through three `beforeEach` blocks to understand what a test is setting up.
Favor inline setup or named factory functions called explicitly per test.

**One behavior per test, not one assertion per test.** A single user action may produce
several observable effects; asserting them all in one test is fine. What's not fine is
testing two unrelated behaviors in one test.

---

## Naming Conventions

### `describe` blocks
Name after the unit under test — the component, function, or hook name:

```ts
describe('PasswordInput', () => { ... })
describe('useDebounce', () => { ... })
describe('formatCurrency', () => { ... })
```

Group sub-behaviors with nested describes only when there are meaningfully distinct
scenarios and nesting won't exceed two levels:

```ts
describe('useAuth', () => {
  describe('when the session has expired', () => { ... })
  describe('when the user is authenticated', () => { ... })
})
```

### `it`/`test` names — the user's preference
**Do NOT use "should".** Write test names as declarative statements of fact:

```ts
// ✅ Correct
it('returns null for an empty array', ...)
it('renders a disabled button when loading is true', ...)
it('calls onSubmit with the trimmed input value', ...)
it('throws an error when the token is missing', ...)
it('applies the error class when validation fails', ...)

// ❌ Avoid
it('should return null for an empty array', ...)
it('should render a disabled button when loading is true', ...)
```

The name tells the reader what the observable fact is. Present tense, active voice,
starting with a verb that describes what the unit *does*: `returns`, `renders`,
`calls`, `throws`, `applies`, `dispatches`, `navigates`, `emits`, `updates`.

For conditional behavior, embed the condition naturally:

```ts
it('renders the error message when the API call fails', ...)
it('disables the submit button while the form is submitting', ...)
it('returns the cached value on repeated calls within the debounce window', ...)
```

### File naming
Use `ComponentName.test.tsx` or `useHookName.test.ts` co-located next to the source
file. `*.spec.*` is equivalent but prefer `.test.*` for consistency.

---

## Test Structure: AAA

Every test follows Arrange → Act → Assert with visual separation:

```ts
it('filters out inactive users', () => {
  // Arrange
  const users = [
    createUser({ id: '1', active: true }),
    createUser({ id: '2', active: false }),
  ]

  // Act
  const result = filterActiveUsers(users)

  // Assert
  expect(result).toHaveLength(1)
  expect(result[0].id).toBe('1')
})
```

Keep phases distinct. Don't interleave assertions with actions.

---

## What to Test

**Prioritize in this order:**

1. Business logic — the domain rules that are costly when wrong
2. Edge cases — `null`, `undefined`, empty arrays, zero, boundary values, max lengths
3. Error paths — thrown errors, rejected promises, invalid input
4. User-visible behavior — what renders, what gets called, what the user sees change

**Don't test:**
- Third-party library internals (assume Vitest, React, React Testing Library work)
- Implementation details — private functions, internal component state, which helper
  was called inside another function
- Type definitions and interfaces alone (TypeScript already checks those)

---

## Component Tests (React Testing Library)

Use `@testing-library/react` with Vitest. Always query by what the user sees.

### Query priority (highest to lowest confidence)
```
getByRole      → most semantic, preferred
getByLabelText → form elements
getByText      → visible text
getByAltText   → images
getByTestId    → last resort; only when nothing else works
```

Never query by class name, CSS selector, or internal component name.

```ts
import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { SubmitButton } from './SubmitButton'

describe('SubmitButton', () => {
  it('renders as disabled while loading', () => {
    render(<SubmitButton loading={true} label="Save" />)
    expect(screen.getByRole('button', { name: /save/i })).toBeDisabled()
  })

  it('calls onClick when clicked and not loading', async () => {
    const user = userEvent.setup()
    const handleClick = vi.fn()
    render(<SubmitButton loading={false} label="Save" onClick={handleClick} />)

    await user.click(screen.getByRole('button', { name: /save/i }))

    expect(handleClick).toHaveBeenCalledOnce()
  })
})
```

Prefer `userEvent` over `fireEvent` — it simulates real browser interactions
(pointer events, focus, etc.) rather than dispatching a single synthetic event.

---

## Hook Tests

Use `renderHook` from `@testing-library/react`. Test through the hook's public
return values and callbacks — never inspect the hook's internal closure state.

```ts
import { renderHook, act } from '@testing-library/react'
import { useCounter } from './useCounter'

describe('useCounter', () => {
  it('initializes with the provided value', () => {
    const { result } = renderHook(() => useCounter(5))
    expect(result.current.count).toBe(5)
  })

  it('increments the count when increment is called', () => {
    const { result } = renderHook(() => useCounter(0))
    act(() => result.current.increment())
    expect(result.current.count).toBe(1)
  })
})
```

---

## Async Tests

Always `await` async assertions. Never leave a floating promise.

```ts
// ✅ Correct
it('loads and displays user data', async () => {
  render(<UserProfile userId="42" />)
  expect(await screen.findByText('Jane Doe')).toBeInTheDocument()
})

// ✅ For thrown rejections
it('throws when the user is not found', async () => {
  await expect(fetchUser('nonexistent')).rejects.toThrow('User not found')
})

// ❌ Broken — test completes before the promise settles
it('loads user data', () => {
  render(<UserProfile userId="42" />)
  expect(screen.findByText('Jane Doe')).toBeInTheDocument() // no await
})
```

Use `findBy*` (not `waitFor` + `getBy*`) when waiting for something to appear in the DOM.
Use `waitForElementToBeRemoved` when waiting for something to disappear.

---

## Mocking Strategy

### The rule: mock only what you can't control
- ✅ Mock: HTTP clients, `fetch`, browser APIs (`localStorage`, `matchMedia`), third-party SDKs
- ✅ Mock: Timers and dates when the test's behavior depends on elapsed time
- ❌ Don't mock: your own utility functions, React hooks, internal modules (test them together)

### Module mocks
```ts
// Mock at the module level — hoisted automatically by Vitest
vi.mock('../api/users', () => ({
  fetchUser: vi.fn(),
}))

// In the test, type the mock correctly
import { fetchUser } from '../api/users'
const mockedFetchUser = vi.mocked(fetchUser)

it('displays the user name after loading', async () => {
  mockedFetchUser.mockResolvedValueOnce({ id: '1', name: 'Jane Doe' })
  render(<UserProfile userId="1" />)
  expect(await screen.findByText('Jane Doe')).toBeInTheDocument()
})
```

### Spy vs mock
- `vi.spyOn(obj, 'method')` — observe or temporarily override a real method; restores automatically with `restoreMocks: true` in config
- `vi.fn()` — standalone fake function with no original to restore
- `vi.mock('./module')` — replace an entire module for the whole file

### Always reset between tests
Configure in `vitest.config.ts` rather than repeating in every file:

```ts
// vitest.config.ts
export default defineConfig({
  test: {
    clearMocks: true,    // clears call history
    restoreMocks: true,  // restores spyOn originals
  },
})
```

---

## TypeScript: Keep Types Honest

**Never use `as any` in test code.** If it won't type-check, the test data doesn't
match the real type — fix the data, not the type.

### Type mocks correctly
```ts
import { vi } from 'vitest'
import type { UserService } from './UserService'

// Use vi.mocked for proper typing on mocked modules
vi.mock('./UserService')
const mockedService = vi.mocked(UserService)

// Use jest.Mocked<T> equivalent: vi.Mocked<T>
const mockService: vi.Mocked<UserService> = {
  getUser: vi.fn(),
  updateUser: vi.fn(),
}
```

### Factory functions for test data
Don't cast partial objects with `as User`. Build typed factories:

```ts
function createUser(overrides: Partial<User> = {}): User {
  return {
    id: 'test-id',
    name: 'Test User',
    email: 'test@example.com',
    role: 'viewer',
    createdAt: new Date('2024-01-01'),
    ...overrides,
  }
}

// Usage
const admin = createUser({ role: 'admin' })
const anonymous = createUser({ id: undefined, name: 'Guest' })
```

This pattern: keeps all tests type-safe, documents what a valid object looks like,
gives each test fresh data (no shared mutation), and centralizes maintenance.

---

## Fake Timers

Use fake timers when the unit's behavior depends on `setTimeout`, `setInterval`,
`Date`, or debounce/throttle logic.

```ts
describe('useDebounce', () => {
  beforeEach(() => {
    vi.useFakeTimers()
  })

  afterEach(() => {
    vi.useRealTimers()  // always restore — prevents leakage into other tests
  })

  it('returns the debounced value after the delay has elapsed', () => {
    const { result, rerender } = renderHook(
      ({ value }) => useDebounce(value, 300),
      { initialProps: { value: 'initial' } },
    )

    rerender({ value: 'updated' })
    expect(result.current).toBe('initial')  // not yet

    act(() => vi.advanceTimersByTime(300))
    expect(result.current).toBe('updated')  // now
  })
})
```

When fake timers and promises interact (e.g., a debounced fetch), use
`vi.advanceTimersByTimeAsync(ms)` instead — it flushes microtasks between
timer ticks and prevents hanging tests.

---

## Parameterized Tests

Use `test.each` or `test.for` (Vitest-native) for repetitive cases over a data table
rather than copy-pasting tests:

```ts
describe('formatCurrency', () => {
  test.each([
    [0, 'USD', '$0.00'],
    [1000, 'USD', '$1,000.00'],
    [-50, 'USD', '-$50.00'],
    [1234.5, 'EUR', '€1,234.50'],
  ])('formats %i %s as %s', (amount, currency, expected) => {
    expect(formatCurrency(amount, currency)).toBe(expected)
  })
})
```

---

## Snapshot Testing

Use snapshots sparingly. They catch regressions but don't communicate intent.
A snapshot-only test is nearly meaningless — reviewers approve `--updateSnapshot`
without reading the diff.

Good uses: serialized non-UI output (error messages, API payloads, complex strings).
Bad uses: full component trees, anything with timestamps or IDs (use property matchers).

When you do use snapshots, keep them small and pair them with explicit assertions:

```ts
it('renders the error state', () => {
  const { container } = render(<Alert type="error" message="Something went wrong" />)
  // Explicit assertion first — communicates intent
  expect(screen.getByRole('alert')).toHaveTextContent('Something went wrong')
  // Snapshot catches unexpected structural regressions
  expect(container.firstChild).toMatchInlineSnapshot(`...`)
})
```

---

## Anti-Patterns to Avoid

**Don't test internals.** If a test breaks when you rename a private variable or
extract a helper function, it's testing implementation detail. Delete or rewrite it.

**Don't assert in `beforeEach`.** Assertions belong in test bodies so failures
are localized. `beforeEach` is for setup — cleanup, rendering, initializing mocks.

**Don't share mutable state between tests.** Variables set in `beforeEach` and
mutated across tests create order-dependent failures. Re-initialize per test or use
constants.

**Don't mock everything.** A test where the return value of every dependency is
mocked isn't testing your code — it's testing that your code calls the mocks
you told it to call. Keep real collaborators when you can.

**Don't swallow async.** An unawaited `findBy*` or `waitFor` will silently pass
while the real assertion never runs. Always await.

**Don't use `act` unnecessarily.** React Testing Library already wraps `render`,
`fireEvent`, `userEvent`, and `findBy*` in `act`. Wrapping again is noise.
An `act(...)` warning is a signal of a real problem — don't silence it with
an extra wrapper; fix the root cause.

---

## Reference Files

For extended guidance, see:
- `references/component-patterns.md` — patterns for context providers, portals, error boundaries
- `references/mock-patterns.md` — `msw` setup, module mock factories, `vi.mock` hoisting caveats
- `references/async-patterns.md` — `waitFor`, `findBy`, polling, WebSocket mocks
