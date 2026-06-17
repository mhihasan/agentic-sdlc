# Chapter 5: Formatting

## Core Thesis
Code formatting is **communication**. A team's formatting style must be consistent, agreed upon, and enforced by tools. Your code style outlives any individual feature — it communicates professionalism and care.

> "Code formatting is about communication, and communication is the professional developer's first order of business."

## Vertical Formatting

### Newspaper Metaphor
A source file should read like a newspaper article:
- **Headline at top**: class/module name — high-level purpose
- **Details increase downward**: high-level functions first, low-level utilities at the bottom
- Readers should be able to stop reading whenever they have enough context

```python
# GOOD: high-level flow at top, details below
class ArticlePublisher:
    def publish(self, article: Article) -> None:
        self._validate(article)
        self._store(article)
        self._notify_subscribers(article)

    def _validate(self, article: Article) -> None:
        self._check_title(article.title)
        self._check_body(article.body)

    def _store(self, article: Article) -> None:
        self._repository.save(article)

    def _notify_subscribers(self, article: Article) -> None:
        for subscriber in self._subscribers:
            subscriber.on_article_published(article)

    # --- Low-level implementation details below ---
    def _check_title(self, title: str) -> None:
        if not title or len(title) > MAX_TITLE_LENGTH:
            raise ValidationError(f"Title must be 1-{MAX_TITLE_LENGTH} characters")

    def _check_body(self, body: str) -> None:
        if not body or len(body) < MIN_BODY_LENGTH:
            raise ValidationError(f"Body must be at least {MIN_BODY_LENGTH} characters")
```

### Vertical Openness Between Concepts
Blank lines separate distinct thoughts. Each blank line is a visual cue: "new concept ahead."

```python
# BAD: all run together
import os
import sys
class Config:
    DEBUG = False
    DATABASE_URL = "postgres://localhost/mydb"
    def load(self):
        pass
def create_app():
    pass

# GOOD: blank lines as paragraph breaks
import os
import sys

MAX_CONNECTIONS = 100
DEFAULT_TIMEOUT = 30

class Config:
    DEBUG = False
    DATABASE_URL = "postgres://localhost/mydb"

    def load(self) -> None:
        ...


def create_app() -> Flask:
    ...
```

### Vertical Density
Lines that are closely related should be close together. Don't separate related lines with comments or blank lines.

```python
# BAD: comments break up related code
class ReporterConfig:
    # The class name of the reporter listener
    m_className: str

    # The properties of the reporter listener
    m_properties: list[Property] = []

    def add_property(self, prop: Property) -> None:
        self.m_properties.append(prop)

# GOOD: tightly related code stays together
class ReporterConfig:
    class_name: str
    properties: list[Property] = field(default_factory=list)

    def add_property(self, prop: Property) -> None:
        self.properties.append(prop)
```

### Vertical Distance — Keep Related Things Close

**Variable declarations**: Declare variables as close to their use as possible.

```python
# BAD: declared far from use
def process_order(order_id: int) -> None:
    discount = 0.0       # declared here...
    shipping_cost = 0.0  # ...and here

    order = fetch_order(order_id)
    items = fetch_items(order_id)
    # ... 20 lines of code ...
    
    discount = calculate_discount(order)  # used way down here
    total = sum(i.price for i in items) - discount + shipping_cost

# GOOD: declared near use
def process_order(order_id: int) -> None:
    order = fetch_order(order_id)
    items = fetch_items(order_id)
    
    discount = calculate_discount(order)
    shipping_cost = calculate_shipping(order)
    total = sum(i.price for i in items) - discount + shipping_cost
```

**Dependent functions**: Caller should be above callee (top-down narrative).

```python
# GOOD: caller before callee
def build_report(data: list[dict]) -> str:
    rows = _format_rows(data)
    return _wrap_table(rows)

def _format_rows(data: list[dict]) -> list[str]:  # called from build_report
    return [_format_row(row) for row in data]

def _format_row(row: dict) -> str:  # called from _format_rows
    return f"<tr><td>{row['name']}</td><td>{row['value']}</td></tr>"

def _wrap_table(rows: list[str]) -> str:
    return f"<table>{''.join(rows)}</table>"
```

**Conceptual affinity**: Code that does similar things should be near each other.

```python
# GOOD: related assertions together
def assert_valid_user(user: User) -> None:
    assert_not_empty(user.name, "name")
    assert_valid_email(user.email)
    assert_valid_age(user.age)

def assert_not_empty(value: str, field: str) -> None:
    if not value:
        raise ValidationError(f"{field} cannot be empty")

def assert_valid_email(email: str) -> None:
    if "@" not in email:
        raise ValidationError(f"Invalid email: {email}")
```

---

## Horizontal Formatting

### Line Width: 80–120 Characters
Martin's rule: never scroll right. Keep lines short. The PEP 8 standard is 79; many teams use 100-120.

```python
# BAD: requires horizontal scrolling
result = some_really_long_function_name(first_argument, second_argument, third_argument, fourth_argument)

# GOOD
result = some_really_long_function_name(
    first_argument,
    second_argument,
    third_argument,
    fourth_argument,
)
```

### Horizontal Openness and Density
Use spaces around operators to show precedence and grouping.

```python
# BAD
x=(-b+math.sqrt(b**2-4*a*c))/(2*a)

# GOOD: spaces show grouping
x = (-b + math.sqrt(b**2 - 4*a*c)) / (2*a)

# Multiplication binds tighter — no space shows that
numerator = -b + math.sqrt(b**2 - 4*a*c)
denominator = 2*a
x = numerator / denominator
```

### Horizontal Alignment — Don't Over-Align
Aligned assignments look neat but obscure the structure and create unnecessary diff noise.

```python
# BAD: over-aligned (looks neat but is actually harder to maintain)
first_name  = "John"
last_name   = "Doe"
age         = 30
email       = "john@example.com"

# GOOD: standard alignment
first_name = "John"
last_name = "Doe"
age = 30
email = "john@example.com"
```

### Indentation
Always indent consistently. Python enforces this, but be consistent with levels.

```python
# BAD: inconsistent indentation breaks readability
class Foo:
  def bar(self):   # 2 spaces
      if True:     # 6 spaces
        pass       # 8 spaces

# GOOD: PEP 8 — 4 spaces everywhere
class Foo:
    def bar(self) -> None:
        if True:
            pass
```

---

## Team Rules — The Most Important Rule

**The team decides the style, and everyone follows it without exception.**

Individual preferences are subordinated to team consistency. Automated formatters enforce this.

```python
# In Python: use Black + isort + ruff/flake8
# pyproject.toml
[tool.black]
line-length = 100
target-version = ["py311"]

[tool.isort]
profile = "black"
line_length = 100

[tool.ruff]
line-length = 100
select = ["E", "F", "W", "I"]
```

```yaml
# .pre-commit-config.yaml — enforce on every commit
repos:
  - repo: https://github.com/psf/black
    rev: 23.1.0
    hooks:
      - id: black
  - repo: https://github.com/PyCQA/isort
    rev: 5.12.0
    hooks:
      - id: isort
  - repo: https://github.com/astral-sh/ruff-pre-commit
    rev: v0.1.0
    hooks:
      - id: ruff
```

---

## Summary: Formatting Rules

| Concern | Rule | Python Tool |
|---|---|---|
| File length | Prefer < 200 lines; max ~500 | N/A |
| Line width | 80–120 characters | Black |
| Blank lines | Separate distinct concepts | Black |
| Variable placement | Declare near use | N/A (manual) |
| Function order | Caller above callee | N/A (manual) |
| Indentation | 4 spaces (PEP 8) | Black |
| Team consistency | All tools enforced in CI | pre-commit |
