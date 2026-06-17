# Anti-Patterns Quick Reference

Fast lookup during review. For full rule specification, see `rules.md`.

| Anti-pattern | Rule | Correct pattern |
|---|---|---|
| `def test_login():` | Rule 1 | `def test_returns_200_if_credentials_are_valid():` |
| `def test_user():` | Rule 1 | `def test_returns_user_when_id_is_valid():` |
| Docstring restates the function name | Rule 2 | Add business reason — the *why*, not the *what* |
| No docstring at all | Rule 2 | Given/When/Then with business reason |
| `assert code == 200` | Rule 3 | `assert code == HTTP_OK` |
| `assert status == "active"` | Rule 3 | `assert status == OrderStatus.ACTIVE` |
| `assert value == 0.333333` | Rule 3 | `assert value == pytest.approx(0.333, rel=1e-3)` |
| `assert x != None` | Rule 3 | `assert x is not None` |
| `assert flag == True` | Rule 3 | `assert flag is True` |
| Test B assumes Test A ran first | Rule 4 | Use `yield` fixture to own setup + teardown |
| No cleanup after DB insert | Rule 4 | `yield` fixture with `delete_record(...)` after yield |
| `processor._normalize(...)` in test | Rule 5 | Call through public method only |
| `mock.assert_called_once()` on internal | Rule 5 | Assert on the observable return value instead |
| `mocker.patch("src.service.InternalQueue")` | Rule 6 | Only patch external I/O boundaries |
| `mocker.patch("src.orders.Formatter")` | Rule 6 | Let internal formatters run for real |
| `time.sleep(N)` in test body | Practices | Patch `datetime` or use clock injection |
| `try/except` to catch expected exception | Practices | `pytest.raises(ExcType, match="...")` |
| Multiple unrelated `assert` blocks | Practices | Split into separate test functions |
| Test logic or constants in `conftest.py` | Practices | Move to the relevant test module |
| All fixtures scoped to `session` | Practices | Use `function` scope unless sharing is intentional |
