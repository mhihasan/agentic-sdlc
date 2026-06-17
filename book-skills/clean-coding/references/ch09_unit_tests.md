# Chapter 9: Unit Tests

## Core Thesis
**Test code is just as important as production code.** Dirty tests are worse than no tests — they rot, become a liability, and ultimately get discarded. When tests are lost, production code rots because fear of change replaces confidence.

> "It is unit tests that keep our code flexible, maintainable, and reusable."

---

## The Three Laws of TDD

1. **You may not write production code until you have written a failing unit test.**
2. **You may not write more of a unit test than is sufficient to fail.**
3. **You may not write more production code than is sufficient to pass the failing test.**

This keeps the test/code cycle under ~30 seconds. Tests and code evolve together.

---

## Clean Tests: BUILD-OPERATE-CHECK

Every test follows a clear pattern. In Python this maps to **Arrange-Act-Assert (AAA)**.

```python
# BAD: All logic in one block, unclear what's being tested
def test_get_pages():
    wiki = WikiPage("root")
    wiki.add_page("PageOne")
    wiki.add_page("PageOne.ChildOne")
    wiki.add_page("PageTwo")
    request = HttpRequest(resource="root", type="pages")
    responder = SerializedPageResponder()
    response = responder.make_response(FitNesseContext(wiki), request)
    xml = response.content
    assert response.content_type == "text/xml"
    assert "<n>PageOne</n>" in xml
    assert "<n>PageTwo</n>" in xml
    assert "<n>ChildOne</n>" in xml


# GOOD: AAA pattern with domain-specific test helpers
def test_xml_includes_all_pages():
    # ARRANGE
    wiki = _build_wiki_with_pages(["PageOne", "PageOne.ChildOne", "PageTwo"])

    # ACT
    xml = _request_page_hierarchy_as_xml(wiki)

    # ASSERT
    _assert_xml_contains_pages(xml, ["PageOne", "PageTwo", "ChildOne"])


def _build_wiki_with_pages(pages: list[str]) -> WikiPage:
    wiki = WikiPage("root")
    for page in pages:
        wiki.add_page(page)
    return wiki

def _request_page_hierarchy_as_xml(wiki: WikiPage) -> str:
    request = HttpRequest(resource="root", type="pages")
    response = SerializedPageResponder().make_response(
        FitNesseContext(wiki), request
    )
    assert response.content_type == "text/xml"
    return response.content

def _assert_xml_contains_pages(xml: str, page_names: list[str]) -> None:
    for name in page_names:
        assert f"<n>{name}</n>" in xml
```

---

## Domain-Specific Testing Language

Build a **testing API** on top of your production code — test utilities that hide noise and let tests express domain intent.

```python
# BAD: Low-level noise in every test
def test_thermostat_cooling_on_at_high_temp():
    hw = MockControlHardware()
    controller = EnvironmentController(hw)
    
    state = HvacState()
    state.temperature = 77  # Fahrenheit
    state.humidity = 0.6
    state.heater_state = False
    state.cooler_state = False
    state.blower_state = False
    state.hi_temp_alarm = False
    state.lo_temp_alarm = False
    
    controller.tick(state)
    
    assert hw.heater_state == False
    assert hw.cooler_state == True
    assert hw.blower_state == True
    assert hw.hi_temp_alarm == False


# GOOD: Domain-specific test helpers express intent
def test_thermostat_cooling_on_at_high_temp():
    _set_temperature(77)  # degrees Fahrenheit
    _tick()
    _assert_cooling_running()

# Helpers build a "testing DSL"
def _set_temperature(fahrenheit: float) -> None:
    hw.temperature = fahrenheit

def _tick() -> None:
    controller.tick()

def _assert_cooling_running() -> None:
    assert hw.cooler_state is True
    assert hw.blower_state is True
    assert hw.heater_state is False
```

---

## F.I.R.S.T. Principles for Clean Tests

| Letter | Principle | Meaning |
|---|---|---|
| **F** | Fast | Tests must run quickly — slow tests don't get run |
| **I** | Independent | Tests must not depend on each other; any order must work |
| **R** | Repeatable | Same result in any environment (dev, CI, offline) |
| **S** | Self-validating | Pass or fail — no manual inspection required |
| **T** | Timely | Write tests just before the production code they test |

```python
# F - Fast: avoid slow I/O in unit tests
# BAD
def test_user_save():
    user = User(name="Bob")
    db = PostgresDatabase("postgres://localhost/testdb")  # slow!
    db.save(user)
    assert db.find(user.id).name == "Bob"

# GOOD: use in-memory or mock
def test_user_save():
    db = InMemoryDatabase()
    user = User(name="Bob")
    db.save(user)
    assert db.find(user.id).name == "Bob"


# I - Independent: each test arranges its own state
# BAD: test_b depends on test_a running first
def test_a():
    global shared_list
    shared_list = [1, 2, 3]

def test_b():
    assert shared_list[0] == 1  # breaks if run alone!

# GOOD: each test arranges its own fixture
def test_b():
    items = [1, 2, 3]
    assert items[0] == 1


# R - Repeatable: no external dependencies
# BAD: depends on system clock
def test_subscription_expires():
    sub = Subscription(start_date=datetime.now())
    assert sub.is_active()  # fails at different times!

# GOOD: inject the clock
def test_subscription_expires():
    fixed_now = datetime(2024, 1, 1)
    sub = Subscription(start_date=fixed_now, clock=FakeClock(fixed_now))
    assert sub.is_active()


# S - Self-validating: assert, don't print
# BAD
def test_format_date():
    result = format_date(datetime(2024, 6, 15))
    print(result)  # someone has to read this manually!

# GOOD
def test_format_date():
    result = format_date(datetime(2024, 6, 15))
    assert result == "June 15, 2024"
```

---

## One Concept Per Test

Each test should test **one concept**. This means it may have multiple assertions, but they all serve a single behavioral question.

```python
# BAD: tests multiple unrelated behaviors in one test
def test_add_months():
    dt = SerialDate(31, 5, 2004)
    
    result = dt.add_months(1)
    assert result.day == 30      # concept 1: end of month clamping
    assert result.month == 6
    
    result = dt.add_months(2)
    assert result.day == 31      # concept 2: July has 31 days
    assert result.month == 7
    
    result = dt.add_months(1)    # starting from June 30
    assert result.day == 31      # concept 3: August has 31 days


# GOOD: one concept per test, named clearly
def test_add_month_to_31st_clamps_to_end_of_month():
    dt = SerialDate(31, 5, 2004)
    result = dt.add_months(1)
    assert result == SerialDate(30, 6, 2004)  # June has only 30 days

def test_add_two_months_from_may_31_preserves_31_in_july():
    dt = SerialDate(31, 5, 2004)
    result = dt.add_months(2)
    assert result == SerialDate(31, 7, 2004)  # July has 31 days
```

---

## pytest Best Practices

```python
# Use fixtures for shared arrangement
import pytest

@pytest.fixture
def user_service():
    db = InMemoryUserRepository()
    return UserService(db)

def test_create_user(user_service):
    user = user_service.create(name="Alice", email="alice@example.com")
    assert user.id is not None
    assert user.name == "Alice"

def test_duplicate_email_raises(user_service):
    user_service.create(name="Alice", email="alice@example.com")
    with pytest.raises(DuplicateEmailError):
        user_service.create(name="Bob", email="alice@example.com")


# Parametrize to test multiple cases cleanly
@pytest.mark.parametrize("temperature,expected_mode", [
    (60, "heating"),
    (70, "off"),
    (80, "cooling"),
])
def test_thermostat_mode(temperature, expected_mode, thermostat):
    thermostat.set_temperature(temperature)
    assert thermostat.get_mode() == expected_mode
```

---

## Summary

| Rule | Violation | Fix |
|---|---|---|
| Clean tests | Long setup, cryptic assertions | Extract test helpers; AAA pattern |
| One concept | Multiple unrelated asserts | Split into focused tests |
| F.I.R.S.T. | Slow, ordered, environment-dependent | Mock I/O; use fixtures; inject time |
| Tests enable change | Fear of refactoring | Write tests first; high coverage = confidence |
| Test DSL | `assert "<n>PageOne</n>" in xml` | `_assert_xml_contains_page("PageOne")` |
