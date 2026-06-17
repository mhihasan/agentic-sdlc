# Review Output Format

When reviewing existing tests, produce this exact structure for every test
function — no exceptions, no skipping violations to soften feedback.

---

## Per-Test Report Template

```
### `<function_name>`

**Violations**
- [Rule N] <specific description of what is wrong and why it matters>
- [Rule N] ...
- [Additional: <practice name>] ...

**Rewritten**
\```python
<corrected test code with all rules applied>
\```

**Changes**
- <one line per change, mapping each fix to the rule it satisfies>
```

---

## Example Report

Input test:
```python
def test_process(mocker):
    mocker.patch("src.service.Formatter.format")
    result = process_url("http://example.com")
    assert result != None
```

Output report:

---

### `test_process`

**Violations**
- [Rule 1] Name `test_process` has no verb, expectation, or scenario. On
  failure the output says `FAILED test_process` — this tells the reader
  nothing about what broke.
- [Rule 2] No docstring. The business intent of this test is undocumented.
- [Rule 6] `src.service.Formatter` is an internal module. Mocking it makes
  the formatter dead code in this test — if Formatter has a bug, this test
  will not catch it.
- [Additional: No Magic Values] `!= None` should be `is not None` (PEP 8;
  `!=` on None is ambiguous for objects with custom `__eq__`).

**Rewritten**
```python
def test_returns_result_when_url_is_reachable(mocker):
    """
    Given a well-formed URL pointing to a reachable endpoint
    When process_url is called
    Then a non-None result is returned — all internal validation
    runs for real; only the external HTTP call is mocked.
    """
    # Arrange
    mocker.patch("src.service.httpx.get",
                 return_value=MockResponse(status_code=HTTP_OK))

    # Act
    result = process_url("http://example.com")

    # Assert
    assert result is not None
```

**Changes**
- Renamed per Rule 1: `test_returns_result_when_url_is_reachable`
- Added BDD docstring explaining why internal validation is not mocked (Rule 2)
- Replaced internal mock with external HTTP boundary mock (Rule 6)
- Replaced `!= None` with `is not None` (Additional: No Magic Values / PEP 8)

---

## Aggregate Summary

After all individual reports, produce a one-table summary:

```
## Summary

| Test | Violations | Status |
|---|---|---|
| `test_foo` | Rule 1, Rule 3 | Needs rewrite |
| `test_bar` | None | ✅ Compliant |
```

If all tests pass, say so explicitly and state which rules were checked.
