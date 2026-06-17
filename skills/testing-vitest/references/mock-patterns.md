# Mock Patterns

## Table of Contents
1. [Module Mock Factories](#module-mock-factories)
2. [vi.mock Hoisting Caveats](#vimock-hoisting-caveats)
3. [MSW for HTTP Mocking](#msw-for-http-mocking)
4. [Browser API Mocks](#browser-api-mocks)
5. [Date Mocking](#date-mocking)

---

## Module Mock Factories

Prefer typed factory functions over inline mock objects. They keep tests type-safe,
give each test fresh data, and reduce copy-paste.

```ts
// factories/createUser.ts — used across all test files
import type { User } from '../types'

export function createUser(overrides: Partial<User> = {}): User {
  return {
    id: 'user-1',
    name: 'Test User',
    email: 'test@example.com',
    role: 'viewer',
    active: true,
    createdAt: new Date('2024-01-01T00:00:00Z'),
    ...overrides,
  }
}

// In tests:
const admin = createUser({ role: 'admin' })
const inactive = createUser({ active: false, name: 'Old User' })
```

For mocked service objects (e.g., a class instance or injected dependency):

```ts
function createMockUserService(): vi.Mocked<UserService> {
  return {
    getUser: vi.fn(),
    updateUser: vi.fn(),
    deleteUser: vi.fn(),
  }
}

describe('UserProfile', () => {
  let mockService: vi.Mocked<UserService>

  beforeEach(() => {
    mockService = createMockUserService()
  })

  it('renders the user name returned by the service', async () => {
    mockService.getUser.mockResolvedValueOnce(createUser({ name: 'Jane Doe' }))
    render(<UserProfile service={mockService} userId="1" />)
    expect(await screen.findByText('Jane Doe')).toBeInTheDocument()
  })
})
```

---

## vi.mock Hoisting Caveats

`vi.mock(...)` calls are **hoisted to the top of the file** before any imports,
even if written further down. This means:

```ts
// ⚠️ This won't work — `myFn` isn't in scope when vi.mock runs
const myFn = vi.fn()
vi.mock('../api', () => ({ fetchData: myFn }))

// ✅ This works — factory is evaluated after hoisting
vi.mock('../api', () => ({
  fetchData: vi.fn(),
}))

import { fetchData } from '../api'
const mockedFetch = vi.mocked(fetchData)

beforeEach(() => {
  mockedFetch.mockResolvedValue({ data: [] })
})
```

### Internal references limitation
`vi.spyOn` only wraps *external* access to a module's exports. If a module calls
its own exported function internally (same-file call), the spy doesn't intercept it.
To mock an internally-referenced function, use `vi.mock` with a factory and restructure
the module to call through the module object, or refactor to accept the dependency as a parameter.

---

## MSW for HTTP Mocking

[MSW (Mock Service Worker)](https://mswjs.io) is the preferred approach for mocking
HTTP in component and integration tests. It intercepts requests at the network level,
meaning you test the real fetch/axios code path.

```ts
// mocks/handlers.ts
import { http, HttpResponse } from 'msw'

export const handlers = [
  http.get('/api/users/:id', ({ params }) => {
    return HttpResponse.json({
      id: params.id,
      name: 'Jane Doe',
      email: 'jane@example.com',
    })
  }),

  http.post('/api/users', async ({ request }) => {
    const body = await request.json()
    return HttpResponse.json({ id: 'new-id', ...body }, { status: 201 })
  }),
]
```

```ts
// mocks/server.ts
import { setupServer } from 'msw/node'
import { handlers } from './handlers'

export const server = setupServer(...handlers)
```

```ts
// vitest.setup.ts
import { server } from './mocks/server'
import '@testing-library/jest-dom'

beforeAll(() => server.listen({ onUnhandledRequest: 'error' }))
afterEach(() => server.resetHandlers())
afterAll(() => server.close())
```

Override handlers per test to simulate errors:

```ts
import { http, HttpResponse } from 'msw'
import { server } from '../mocks/server'

it('shows the error message when the API returns 500', async () => {
  server.use(
    http.get('/api/users/:id', () => {
      return new HttpResponse(null, { status: 500 })
    })
  )

  render(<UserProfile userId="1" />)
  expect(await screen.findByRole('alert')).toHaveTextContent(/something went wrong/i)
})
```

---

## Browser API Mocks

Browser APIs unavailable in jsdom must be manually stubbed. Do this in
`vitest.setup.ts` or in a `beforeEach` when the mock needs to vary per test.

### localStorage / sessionStorage
jsdom provides these, but you may want to spy or reset:

```ts
beforeEach(() => {
  localStorage.clear()
  sessionStorage.clear()
})
```

### window.matchMedia
jsdom doesn't implement this — mock it globally:

```ts
// vitest.setup.ts
Object.defineProperty(window, 'matchMedia', {
  writable: true,
  value: vi.fn().mockImplementation((query: string) => ({
    matches: false,
    media: query,
    onchange: null,
    addListener: vi.fn(),
    removeListener: vi.fn(),
    addEventListener: vi.fn(),
    removeEventListener: vi.fn(),
    dispatchEvent: vi.fn(),
  })),
})
```

### IntersectionObserver
```ts
// vitest.setup.ts
const mockIntersectionObserver = vi.fn().mockImplementation(() => ({
  observe: vi.fn(),
  unobserve: vi.fn(),
  disconnect: vi.fn(),
}))
Object.defineProperty(window, 'IntersectionObserver', {
  writable: true,
  value: mockIntersectionObserver,
})
```

---

## Date Mocking

Use `vi.setSystemTime` (requires `vi.useFakeTimers`) to control the current date.
This works for `new Date()`, `Date.now()`, and `performance.now()`.

```ts
describe('ExpiryBadge', () => {
  beforeEach(() => {
    vi.useFakeTimers()
    vi.setSystemTime(new Date('2024-06-15'))
  })

  afterEach(() => {
    vi.useRealTimers()
  })

  it('shows "Expired" for a date in the past', () => {
    render(<ExpiryBadge expiryDate={new Date('2024-01-01')} />)
    expect(screen.getByText('Expired')).toBeInTheDocument()
  })

  it('shows the days remaining for a future date', () => {
    render(<ExpiryBadge expiryDate={new Date('2024-06-20')} />)
    expect(screen.getByText('5 days remaining')).toBeInTheDocument()
  })
})
```
