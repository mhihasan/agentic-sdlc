# Chapter 3: Functions

## Core Thesis
Functions should be **small**, do **one thing**, operate at **one level of abstraction**, and have **no side effects**. The craft of writing clean functions is the craft of breaking problems down well.

## Rules for Clean Functions

### 1. Small — and Smaller Than That
Functions should rarely be more than 20 lines. Ideal: 2–5 lines. Every function should tell a story.

```python
# BAD: 40+ line function doing many things
def render_page_with_setups_and_teardowns(page_data, is_suite):
    page_name = page_data.get_name()
    if page_data.has_attribute("Test"):
        if is_suite:
            suite_setup = page_crawler.get_inherited_page("SuiteSetUp", page)
            if suite_setup is not None:
                setup_path = wiki_page.get_page_crawler().get_full_path(suite_setup)
                ...
        # 30 more lines...

# GOOD: small, each tells a story
def render_page_with_setups_and_teardowns(page_data: PageData, is_suite: bool) -> str:
    if is_test_page(page_data):
        include_setup_and_teardown_pages(page_data, is_suite)
    return page_data.get_html()

def is_test_page(page_data: PageData) -> bool:
    return page_data.has_attribute("Test")
```

### 2. Do One Thing
A function does one thing if all steps inside it are one level of abstraction below its name. If you can extract another function with a name that is NOT a restatement of the implementation — the function is doing more than one thing.

```python
# BAD: doing multiple things
def process_user(user_id: int) -> None:
    # level 1: fetch
    user = db.query(f"SELECT * FROM users WHERE id = {user_id}")
    # level 2: validate
    if not user.email or "@" not in user.email:
        raise ValueError("Invalid email")
    # level 3: notify
    smtp.send(user.email, "Welcome!", "Thanks for signing up")
    # level 4: audit
    audit_log.append(f"{datetime.now()}: processed user {user_id}")

# GOOD: one thing at each level
def process_user(user_id: int) -> None:
    user = fetch_user(user_id)
    validate_user(user)
    send_welcome_email(user)
    log_user_processed(user_id)
```

### 3. One Level of Abstraction per Function
Don't mix high-level policy with low-level detail.

```python
# BAD: mixes abstraction levels
def generate_report(data: list[dict]) -> str:
    report = "<html><body>"           # low-level HTML detail
    for row in data:
        report += f"<tr><td>{row['name']}</td></tr>"  # low-level
    report += "</body></html>"        # low-level
    return report.replace("  ", " ")  # micro-optimization

# GOOD: consistent abstraction levels
def generate_report(data: list[dict]) -> str:
    rows = [format_row(row) for row in data]
    return wrap_in_html_table(rows)

def format_row(row: dict) -> str:
    return f"<tr><td>{row['name']}</td></tr>"

def wrap_in_html_table(rows: list[str]) -> str:
    return f"<html><body>{''.join(rows)}</body></html>"
```

### 4. The Stepdown Rule (Top-Down Narrative)
Code should read like a top-down narrative. Every function should be followed by the next level of abstraction.

```python
# The "TO" paragraph test:
# TO publish_article, we validate it, then store it, then notify subscribers.
def publish_article(article: Article) -> None:
    validate_article(article)
    store_article(article)
    notify_subscribers(article)

# TO validate_article, we check title, body, and author.
def validate_article(article: Article) -> None:
    check_title(article.title)
    check_body(article.body)
    check_author(article.author)
```

### 5. Switch Statements / if-elif Chains
Avoid switch statements that must change when new types are added. Bury them in a factory.

```python
# BAD: every new employee type requires changing this function
def calculate_pay(employee: Employee) -> float:
    if employee.type == "COMMISSIONED":
        return calculate_commissioned_pay(employee)
    elif employee.type == "HOURLY":
        return calculate_hourly_pay(employee)
    elif employee.type == "SALARIED":
        return calculate_salaried_pay(employee)
    else:
        raise ValueError(f"Unknown type: {employee.type}")

# GOOD: polymorphism via abstract base class
from abc import ABC, abstractmethod

class Employee(ABC):
    @abstractmethod
    def calculate_pay(self) -> float: ...

class CommissionedEmployee(Employee):
    def calculate_pay(self) -> float:
        return self.base_pay + self.commission_rate * self.sales

class HourlyEmployee(Employee):
    def calculate_pay(self) -> float:
        return self.hours_worked * self.hourly_rate

# In Python, often prefer Protocol + dispatch dict over class hierarchy:
PayCalculator = Callable[[Employee], float]
PAY_CALCULATORS: dict[str, PayCalculator] = {
    "COMMISSIONED": calculate_commissioned_pay,
    "HOURLY": calculate_hourly_pay,
    "SALARIED": calculate_salaried_pay,
}

def calculate_pay(employee: Employee) -> float:
    calculator = PAY_CALCULATORS.get(employee.type)
    if calculator is None:
        raise ValueError(f"Unknown employee type: {employee.type}")
    return calculator(employee)
```

### 6. Descriptive Names
A long descriptive name is better than a short enigmatic name. Don't be afraid of long function names.

```python
# BAD
def incl(pg, nc, s): ...
def proc(u): ...

# GOOD — even if "verbose"
def include_setup_and_teardown_pages(page: WikiPage, new_content: StringBuffer, is_suite: bool) -> None: ...
def process_user_registration(user: User) -> None: ...
```

### 7. Function Arguments — Fewer is Better

- **Niladic (0 args)** — ideal
- **Monadic (1 arg)** — good; two common forms: asking a question about it, or transforming it
- **Dyadic (2 args)** — acceptable; use with care
- **Triadic (3 args)** — requires justification
- **Polyadic (4+ args)** — wrap in an object

```python
# BAD: 5 arguments
def make_circle(x: float, y: float, radius: float, color: str, filled: bool) -> Circle: ...

# GOOD: wrap into objects
@dataclass
class Point:
    x: float
    y: float

@dataclass
class CircleStyle:
    color: str
    filled: bool

def make_circle(center: Point, radius: float, style: CircleStyle) -> Circle: ...

# Flag arguments (boolean parameters) are a code smell — split the function
# BAD
def render(page, is_suite: bool) -> str: ...

# GOOD
def render_suite_page(page) -> str: ...
def render_test_page(page) -> str: ...
```

### 8. No Side Effects
Side effects are hidden lies. Your function promises one thing but does something else secretly.

```python
# BAD: checkPassword does more than check — it initializes a session (side effect)
def check_password(username: str, password: str) -> bool:
    user = find_user(username)
    if user and user.password_hash == hash(password):
        Session.initialize()  # SIDE EFFECT — hidden!
        return True
    return False

# GOOD: separate concerns
def check_password(username: str, password: str) -> bool:
    user = find_user(username)
    return user is not None and user.password_hash == hash(password)

def login(username: str, password: str) -> Session:
    if not check_password(username, password):
        raise AuthenticationError("Invalid credentials")
    return Session.create(username)
```

### 9. Command Query Separation
A function should either **do something** (command) or **answer something** (query), not both.

```python
# BAD: does something AND returns something — confusing
def set_and_check(attribute: str, value: str) -> bool:
    if attribute in self._attributes:
        self._attributes[attribute] = value
        return True
    return False

# BAD usage — reads like a question but has a side effect
if set_and_check("username", "bob"):
    ...

# GOOD: separated
def set_attribute(attribute: str, value: str) -> None:
    if not self.has_attribute(attribute):
        raise AttributeError(f"Unknown attribute: {attribute}")
    self._attributes[attribute] = value

def has_attribute(attribute: str) -> bool:
    return attribute in self._attributes
```

### 10. Prefer Exceptions to Error Codes
Returning error codes forces callers to handle errors immediately, creating nested structures. Exceptions let you separate happy path from error handling.

```python
# BAD: error code style
def delete_page(page) -> int:
    if logger.delete_page(page) == E_OK:
        if registry.delete_reference(page.name) == E_OK:
            if config_keys.delete_key(page.name.make_key()) == E_OK:
                logger.info("page deleted")
            else:
                logger.error("config key not deleted")
                return E_ERROR
        else:
            logger.error("reference not deleted")
            return E_ERROR
    else:
        logger.error("delete failed")
        return E_ERROR
    return E_OK

# GOOD: exception style
def delete_page(page: WikiPage) -> None:
    """Delete the page and all its references. Raises DeletionError on failure."""
    delete_page_from_log(page)
    delete_page_references(page)
    delete_page_config(page)

def delete_page_from_log(page: WikiPage) -> None:
    try:
        logger.delete_page(page)
    except LoggerError as e:
        raise DeletionError(f"Failed to delete page from log: {page.name}") from e
```

### 11. Extract Try/Catch Blocks
Error handling is one thing. Functions that handle errors should do nothing else.

```python
# BAD: error handling mixed with logic
def delete_page(page: WikiPage) -> None:
    try:
        # business logic mixed with error handling
        logger.delete_page(page)
        references.delete(page.name)
        config.delete(page.name.make_key())
    except Exception as e:
        logger.error(e)

# GOOD: isolated
def delete_page(page: WikiPage) -> None:
    try:
        delete_page_internals(page)
    except DeletionError as e:
        logger.error(e)

def delete_page_internals(page: WikiPage) -> None:
    logger.delete_page(page)
    references.delete(page.name)
    config.delete(page.name.make_key())
```

### 12. Don't Repeat Yourself (DRY)
Duplication is the root of all evil. Every time you see repeated structure, extract a function.

```python
# BAD: duplicated setup logic in every test
def test_login(): 
    user = User(name="Bob", email="bob@test.com")
    db.save(user)
    ...

def test_profile():
    user = User(name="Bob", email="bob@test.com")
    db.save(user)
    ...

# GOOD: extracted
def make_test_user() -> User:
    user = User(name="Bob", email="bob@test.com")
    db.save(user)
    return user
```

## Summary Table

| Rule | Target | Danger Sign |
|------|--------|-------------|
| Small | ≤ 20 lines, ideally 2-5 | Scrolling to see entire function |
| One thing | Single concept/action | Can extract non-restatement |
| One abstraction level | Consistent altitude | Mixed SQL + HTML + business logic |
| Descriptive names | Self-explanatory | Abbreviations, single letters |
| ≤ 2 args | Niladic ideal | 4+ parameters |
| No side effects | Pure or explicit | Hidden session/state mutation |
| CQS | Command OR query | Returns value AND mutates |
| Exceptions not codes | Propagate errors | Nested `if result == E_OK` |
| DRY | Single definition | Copy-paste code |
