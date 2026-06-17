# Core Rules Reference

Full specification for all six non-negotiable rules.

---

## Rule 1 — Naming: `test_<verb>_<expectation>_<scenario>`

Function names must be descriptive lowercase snake_case. Every name has three
segments:

- **verb** — the action under test: `returns`, `raises`, `updates`, `rejects`,
  `processes`, `emits`, `persists`
- **expectation** — the observable outcome: `403`, `empty_list`, `value_error`,
  `none`, `true`
- **scenario** — the condition producing that outcome: `if_user_does_not_exist`,
  `when_token_is_expired`, `if_input_is_empty`

```python
# BAD — gives zero information when it fails
def test_login(): ...
def test_user(): ...
def test_process(): ...

# GOOD — failure output is self-documenting
def test_returns_403_if_user_does_not_exist(): ...
def test_raises_value_error_if_url_is_none(): ...
def test_returns_empty_list_when_no_records_found(): ...
def test_rejects_request_if_token_is_expired(): ...
```

When the scenario is already fully expressed by the expectation (rare), the
scenario segment may be omitted. When in doubt, include it.

---

## Rule 2 — BDD Docstring

Add a docstring **only when the function name cannot carry the business reason** — a non-obvious security constraint, a regulatory requirement, a subtle domain invariant, or a gotcha that would surprise a reader. If the name already says everything, omit the docstring.

```python
# GOOD — docstring explains the non-obvious security reason the name can't fit
def test_returns_403_if_user_does_not_exist(api_client):
    """
    Given a request targeting a user ID with no matching database record
    When the endpoint is called
    Then 403 Forbidden is returned — not 404 — to avoid leaking the
    existence of user IDs to potential enumerators.
    """

# GOOD — no docstring; name is fully self-explanatory
def test_returns_correct_sum_when_given_two_positive_integers():
    ...

# BAD — docstring restates the name, adds zero value
def test_returns_403_if_user_does_not_exist():
    """Returns 403 if user does not exist."""

# BAD — manufactured business reason for an obvious utility function
def test_returns_true_when_list_is_empty():
    """
    Given an empty list
    When is_empty() is called
    Then True is returned — callers rely on this to skip iteration.
    """
```

When a docstring is warranted, use Given/When/Then format with the business reason in the Then clause.

---

## Rule 3 — No Magic Values

Never assert raw literals. Every value with business significance must be bound
to a named constant or domain enum.

```python
# BAD
assert response.status_code == 403
assert result.retry_count == 3
assert record.status == "PROCESSED"

# GOOD
HTTP_FORBIDDEN = 403
MAX_RETRY_ATTEMPTS = 3
from src.orders import OrderStatus

assert response.status_code == HTTP_FORBIDDEN
assert result.retry_count == MAX_RETRY_ATTEMPTS
assert order.status == OrderStatus.COMPLETED
```

Applies to: HTTP status codes, string enum values, numeric thresholds, timeout
values, and any sentinel representing a domain concept.

For floats, use `pytest.approx()` — never assert exact float equality:

```python
# BAD — fails due to floating point representation
assert calculate_score(doc) == 0.857142857142857

# GOOD
assert calculate_score(doc) == pytest.approx(0.857, rel=1e-3)
```

---

## Rule 4 — Self-Contained Tests

A test must produce the same result whether run alone or as part of the full
suite. Three requirements:

- **No shared mutable state** — module-level variables must not be mutated
  across tests
- **No execution order dependency** — test B must not assume test A already ran
- **Guaranteed cleanup** — use `yield` fixtures so teardown runs even on failure

```python
# VIOLATION — assumes a prior test inserted id=1
def test_returns_updated_record():
    update_record(id=1, name="new")
    assert get_record(1).name == "new"

# CORRECT — fixture owns setup and teardown atomically
@pytest.fixture
def existing_record(db_session):
    record = insert_record(db_session, {"name": "original"})
    yield record
    delete_record(db_session, record.id)  # runs even if the test fails

def test_returns_updated_name_after_record_is_modified(existing_record, db_session):
    """
    Given a record that exists in the database
    When its name field is updated
    Then the persisted record reflects the new value
    """
    # Arrange
    NEW_NAME = "updated"

    # Act
    update_record(db_session, id=existing_record.id, name=NEW_NAME)

    # Assert
    assert get_record(db_session, existing_record.id).name == NEW_NAME
```

**Isolation check:** Run `pytest path/to/test.py::test_fn -v`. If the result
differs from running the full suite, the test is not self-contained.

---

## Rule 5 — Test Features, Not Implementation Details

Tests verify **observable behaviour through the public interface only**. Never
call private methods, inspect internal state, or assert on internal call
sequences.

The decision rule: if you refactor internals without changing the external
contract, no test should break.

```python
# BAD — calls a private method directly
def test_formats_address_internally():
    result = OrderService()._format("123 main st")
    assert result == "123 Main St"

# BAD — asserts on an internal call chain
def test_calls_queue_on_submit(mocker):
    mock_queue = mocker.patch("src.service.InternalQueue")
    NotificationService().send("usr_123")
    mock_queue.push.assert_called_once_with("usr_123")  # tests the how, not the what

# GOOD — tests observable output through the public method
def test_returns_formatted_address_when_lowercase_input_is_given():
    """
    Given an address with lowercase input
    When processed through the public interface
    Then the returned address is properly capitalised
    """
    result = OrderService().submit(address="123 main st")
    assert result.address == "123 Main St"
```

---

## Rule 6 — Mock External Boundaries Only

Mock boundaries exist only at I/O points the service does not own. Never mock
internal modules, internal classes, or internal helpers.

**Always mock:**

| Boundary | Examples |
|---|---|
| HTTP clients | `httpx`, `requests`, `aiohttp` |
| Cloud SDKs | `boto3`, `aioboto3` — S3, DynamoDB, SQS, Lambda |
| Database drivers | `psycopg2`, `asyncpg`, SQLAlchemy engine |
| Message queues | SQS, EventBridge, Kafka producers/consumers |
| Third-party APIs | SERP APIs, scraping services, auth providers |
| System clock | `datetime.now()`, `time.time()` when time drives business logic |

**Never mock:**
- Internal service classes
- Internal utility/helper/validator modules
- Anything in `src/` that is not itself a thin I/O wrapper

```python
# BAD — AddressFormatter is internal; this test is hollow
def test_returns_order_result_for_valid_address(mocker):
    mocker.patch("src.orders.AddressFormatter.format",
                 return_value="123 Main St")
    result = OrderService().submit("123 main st")
    assert result is not None

# GOOD — only the external HTTP call is mocked
def test_returns_confirmation_when_order_is_submitted(mocker):
    """
    Given a valid order payload
    When the order is submitted
    Then a confirmation is returned with SUBMITTED status
    """
    mocker.patch(
        "src.orders.httpx.AsyncClient.post",
        return_value=MockResponse(status_code=HTTP_OK, content=b'{"id": "ord_1"}')
    )
    result = OrderService().submit("123 Main St")
    assert result.status == OrderStatus.SUBMITTED
    assert result.order_id is not None
```

**Boundary test:** Ask — *"If I remove this mock, does a real external system
get called?"* If no → it is mocking an internal. Remove it.
