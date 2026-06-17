# Additional Practices Reference

Enforced practices beyond the six core rules.

---

## One Logical Concern Per Test

Each test verifies one behaviour. Multiple `assert` statements are acceptable
when they together describe a single observable outcome (e.g., both status code
and response body for one HTTP call). Asserting unrelated outcomes in one test
is a violation — split them.

```python
# BAD — two unrelated operations, two unrelated outcomes
def test_user_endpoint():
    r1 = client.get("/users/usr_123")
    assert r1.status_code == 200
    r2 = client.post("/users", json={})   # completely different concern
    assert r2.status_code == 422

# GOOD — each test has a single, clear purpose
def test_returns_200_when_user_exists(): ...
def test_returns_422_when_required_fields_are_missing(): ...
```

---

## AAA Structure With Comments

Structure every test body with `# Arrange`, `# Act`, `# Assert` comments.
These map 1:1 to the Given/When/Then docstring and make the test scannable
at a glance.

```python
def test_returns_404_if_resource_does_not_exist(api_client):
    """
    Given a resource ID with no corresponding record
    When a GET request is made for that resource
    Then 404 Not Found is returned
    """
    # Arrange
    NON_EXISTENT_ID = "res_does_not_exist_xyz"

    # Act
    response = api_client.get(f"/resources/{NON_EXISTENT_ID}")

    # Assert
    assert response.status_code == HTTP_NOT_FOUND
```

When Arrange is handled entirely by fixtures, the comment may be omitted for
that section.

---

## No `time.sleep()` in Tests

`time.sleep()` makes tests slow, non-deterministic, and fragile under CI load.
Mock the clock instead using `unittest.mock.patch`:

```python
# BAD
def test_returns_expired_if_token_is_old():
    token = create_token(user_id="usr_123")
    time.sleep(2)
    assert is_expired(token) is True

# GOOD — mock datetime so the test is instant and deterministic
from unittest.mock import patch
import datetime

def test_returns_expired_if_token_age_exceeds_ttl():
    """
    Given a token created more than 24 hours ago
    When expiry is checked
    Then the token is marked as expired — TTL enforcement keeps sessions bounded
    """
    CREATION_TIME = datetime.datetime(2024, 1, 1, 10, 0, 0)
    EXPIRED_TIME = datetime.datetime(2024, 1, 2, 11, 0, 0)  # 25h later

    with patch("src.auth.datetime") as mock_dt:
        mock_dt.now.return_value = CREATION_TIME
        token = create_token(user_id="usr_123")

        mock_dt.now.return_value = EXPIRED_TIME
        assert is_expired(token) is True
```

---

## Use `pytest.raises` for Exception Testing

A bare `try/except` in a test body is a defect — if the exception is never
raised, the test silently passes. Always use `pytest.raises` with a `match`
argument to assert on both the exception type and its message.

```python
# BAD — passes vacuously if no exception is raised
def test_raises_if_url_is_none():
    try:
        process_url(None)
    except ValueError:
        pass

# GOOD
def test_raises_value_error_if_url_is_none():
    """
    Given a None value passed as a URL
    When the processor is called
    Then a ValueError is raised — callers must not pass None URLs
    """
    with pytest.raises(ValueError, match="URL is required"):
        process_url(None)
```

---

## `conftest.py` Is for Shared Fixtures Only

- Fixtures used by a **single** test module stay in that module
- Fixtures shared across **multiple** modules go in `conftest.py`
- Never put test logic, helper functions, or constants in `conftest.py`

---

## Fixture Scope Is a Performance Contract

Scope choice is not aesthetic — it determines whether state is shared across
tests, which directly affects isolation and speed.

| Scope | When to use |
|---|---|
| `function` (default) | Fixture mutates state or creates unique objects per test |
| `module` | Fixture is read-only and expensive to rebuild each test |
| `session` | Shared infrastructure: DB connections, test HTTP servers |

Defaulting all fixtures to `session` is a bug — it creates hidden cross-test
state dependencies that produce intermittent failures.
