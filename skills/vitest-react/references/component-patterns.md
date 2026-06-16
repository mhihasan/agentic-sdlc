# Component Testing Patterns

## Table of Contents
1. [Context Providers](#context-providers)
2. [Error Boundaries](#error-boundaries)
3. [Portals](#portals)
4. [Controlled vs Uncontrolled Inputs](#controlled-vs-uncontrolled-inputs)
5. [Router-dependent Components](#router-dependent-components)

---

## Context Providers

When a component depends on React context, wrap it in the provider during the test.
Prefer a custom render helper over repeating the wrapper in every test.

```ts
// test-utils.tsx
import { render, RenderOptions } from '@testing-library/react'
import { ThemeProvider } from './ThemeProvider'
import { AuthProvider } from './AuthProvider'

function AllProviders({ children }: { children: React.ReactNode }) {
  return (
    <ThemeProvider theme="light">
      <AuthProvider initialUser={null}>
        {children}
      </AuthProvider>
    </ThemeProvider>
  )
}

function renderWithProviders(
  ui: React.ReactElement,
  options?: Omit<RenderOptions, 'wrapper'>,
) {
  return render(ui, { wrapper: AllProviders, ...options })
}

export * from '@testing-library/react'
export { renderWithProviders as render }
```

Usage:
```ts
// Import from test-utils, not from @testing-library/react
import { render, screen } from '../test-utils'

it('shows the logout button when authenticated', () => {
  render(<Header />) // already wrapped in AuthProvider
  expect(screen.getByRole('button', { name: /log out/i })).toBeInTheDocument()
})
```

### Testing context values directly
When testing a component that reads from context, control the context value:

```ts
it('renders the admin panel when the user role is admin', () => {
  render(
    <AuthProvider initialUser={createUser({ role: 'admin' })}>
      <Dashboard />
    </AuthProvider>
  )
  expect(screen.getByRole('region', { name: /admin panel/i })).toBeInTheDocument()
})
```

---

## Error Boundaries

Error boundaries require a test that deliberately throws. Suppress the expected
`console.error` so it doesn't pollute test output:

```ts
function BrokenComponent() {
  throw new Error('Intentional render error')
}

describe('ErrorBoundary', () => {
  beforeEach(() => {
    vi.spyOn(console, 'error').mockImplementation(() => {})
  })

  it('renders the fallback UI when a child throws', () => {
    render(
      <ErrorBoundary fallback={<p>Something went wrong</p>}>
        <BrokenComponent />
      </ErrorBoundary>
    )
    expect(screen.getByText('Something went wrong')).toBeInTheDocument()
  })
})
```

---

## Portals

Components rendered via `ReactDOM.createPortal` (modals, toasts, tooltips) are
appended to `document.body`, not the render container. `screen` queries work
across the entire document so no special handling is needed:

```ts
it('renders the modal in the document body', () => {
  render(<Modal isOpen={true} title="Confirm" onClose={vi.fn()} />)
  // screen queries the whole document, including portals
  expect(screen.getByRole('dialog', { name: /confirm/i })).toBeInTheDocument()
})

it('closes the modal when the close button is clicked', async () => {
  const user = userEvent.setup()
  const handleClose = vi.fn()
  render(<Modal isOpen={true} title="Confirm" onClose={handleClose} />)

  await user.click(screen.getByRole('button', { name: /close/i }))

  expect(handleClose).toHaveBeenCalledOnce()
})
```

---

## Controlled vs Uncontrolled Inputs

Prefer `userEvent.type()` for typing into inputs — it fires all real keyboard events
including focus, keydown, keypress, input, and keyup:

```ts
it('calls onChange with the typed value', async () => {
  const user = userEvent.setup()
  const handleChange = vi.fn()
  render(<SearchInput onChange={handleChange} />)

  await user.type(screen.getByRole('textbox', { name: /search/i }), 'hello')

  expect(handleChange).toHaveBeenLastCalledWith('hello')
})

it('clears the input when the clear button is clicked', async () => {
  const user = userEvent.setup()
  render(<SearchInput defaultValue="existing" onChange={vi.fn()} />)

  await user.click(screen.getByRole('button', { name: /clear/i }))

  expect(screen.getByRole('textbox', { name: /search/i })).toHaveValue('')
})
```

---

## Router-dependent Components

Wrap in a `MemoryRouter` (React Router) or equivalent. Control the initial route:

```ts
import { MemoryRouter, Route, Routes } from 'react-router-dom'

function renderWithRouter(
  ui: React.ReactElement,
  { initialEntries = ['/'] } = {},
) {
  return render(
    <MemoryRouter initialEntries={initialEntries}>
      {ui}
    </MemoryRouter>
  )
}

it('displays the 404 page for an unknown route', () => {
  renderWithRouter(
    <Routes>
      <Route path="/" element={<Home />} />
      <Route path="*" element={<NotFound />} />
    </Routes>,
    { initialEntries: ['/does-not-exist'] }
  )
  expect(screen.getByRole('heading', { name: /page not found/i })).toBeInTheDocument()
})
```
