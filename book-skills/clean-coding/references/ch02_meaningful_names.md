# Chapter 2: Meaningful Names

## Core Thesis
Names are everywhere. Because we name everything, we must name well. Good names eliminate the need for comments to explain intent.

## Rules for Meaningful Names

### 1. Use Intention-Revealing Names
The name must answer: *Why does it exist? What does it do? How is it used?*
If a name needs a comment, it doesn't reveal intent.

```python
# BAD
d = 0  # elapsed time in days
t = []  # active users

# GOOD
elapsed_time_in_days = 0
active_users: list[User] = []
```

### 2. Avoid Disinformation
Don't use names that suggest a type or structure that doesn't match reality.

```python
# BAD: Not a list, but named as if it is
account_list = {101: "Alice", 102: "Bob"}  # it's a dict!

# GOOD
accounts = {101: "Alice", 102: "Bob"}
accounts_by_id: dict[int, str] = {}

# BAD: l, O, I as variable names (look like 1, 0, 1)
l = 1
O = 0
I = l + O  # Is this 1 + 0 or l + O?

# GOOD
length = 1
offset = 0
index = length + offset
```

### 3. Make Meaningful Distinctions
Noise words and number-series are not meaningful distinctions.

```python
# BAD: What's the difference?
def copy_chars(a1: str, a2: str) -> None: ...
product_info = None
product_data = None
name_string = ""  # redundant — Name is already a string

# GOOD
def copy_chars(source: str, destination: str) -> None: ...
product = None
name = ""
```

### 4. Use Pronounceable Names
If you can't pronounce it, you can't discuss it.

```python
# BAD
genymdhms = datetime(2024, 1, 1)  # generate year month day hour minute second
modymdhms = datetime(2024, 1, 2)

# GOOD
generation_timestamp = datetime(2024, 1, 1)
modification_timestamp = datetime(2024, 1, 2)
```

### 5. Use Searchable Names
Single-letter names and numeric literals are not searchable. Use named constants.

```python
# BAD: What does 7 mean? Hard to find all usages
for i in range(7):
    ...
days_worked = number_of_tasks * 4

# GOOD
WORK_DAYS_PER_WEEK = 5
MAX_CLASSES_PER_STUDENT = 7

for _ in range(MAX_CLASSES_PER_STUDENT):
    ...
days_worked = number_of_tasks * WORK_DAYS_PER_WEEK
```

### 6. Avoid Encodings
Don't add type or scope prefixes — modern IDEs and type hints make them redundant.

```python
# BAD: Hungarian Notation, m_ member prefixes, I prefix for interface
m_description = ""
i_shape = None  # "interface" prefix
str_name = ""

# GOOD
description = ""
shape = None
name = ""
```

Python note: Use type hints instead of encoding type in names.
```python
# GOOD — Python way
name: str = ""
items: list[str] = []
user_cache: dict[int, User] = {}
```

### 7. Avoid Mental Mapping
Readers shouldn't translate your names to what they actually mean.

```python
# BAD: reader must remember that 'r' = lowercased URL without host and scheme
for r in url_list:
    process(r)

# GOOD
for url in urls:
    process(url)
```

### 8. Class Names: Nouns
Classes and objects should be nouns or noun phrases. Avoid Manager, Processor, Data, Info.

```python
# BAD: Vague, Manager-itis
class DataManager: ...
class UserProcessor: ...
class AccountInfo: ...

# GOOD
class Customer: ...
class WikiPage: ...
class Account: ...
class AddressParser: ...
```

### 9. Method Names: Verbs
Methods should be verbs or verb phrases. Use `get_`, `set_`, `is_`, `has_`, `can_` prefixes.

```python
class Employee:
    def get_name(self) -> str: ...
    def set_name(self, name: str) -> None: ...
    def is_manager(self) -> bool: ...
    def has_direct_reports(self) -> bool: ...

# Static/class factory methods
@classmethod
def from_id(cls, employee_id: int) -> "Employee": ...

@classmethod
def new_hire(cls, name: str, role: str) -> "Employee": ...
```

### 10. Don't Be Cute / Use One Word Per Concept
Don't use whimsical names. Don't mix synonyms for the same concept.

```python
# BAD: cute / inconsistent
def whack(item): ...     # should be kill() or delete()
def nuke(item): ...      # inconsistent with kill()
def bump_up(n): ...      # should be increment()

# BAD: multiple words for same concept
class UserFetcher: ...
class AccountRetriever: ...
class OrderGetter: ...

# GOOD: consistent vocabulary
class UserRepository: ...
class AccountRepository: ...
class OrderRepository: ...

def fetch_user(user_id: int) -> User: ...
def fetch_account(account_id: int) -> Account: ...
```

### 11. Don't Pun
One word, one concept. Don't reuse the same word for different meanings.

```python
# BAD: 'add' means two different things
class StringBuffer:
    def add(self, s: str) -> None: ...  # add = append/concatenate

class Calculator:
    def add(self, a: int, b: int) -> int: ...  # add = arithmetic add

# GOOD: different concepts, different names
class StringBuffer:
    def append(self, s: str) -> None: ...

class Calculator:
    def add(self, a: int, b: int) -> int: ...
```

### 12. Use Solution Domain Names
It's OK to use CS terms — your readers are programmers.

```python
# GOOD: reader knows these patterns
class JobQueue: ...
class AccountVisitor: ...
class EventBus: ...

ACCOUNT_REGISTRY: dict[str, Account] = {}
```

### 13. Use Problem Domain Names
When no programmer term exists, use the domain's language.

```python
# Finance domain — use the domain's vocabulary
class CompoundInterestCalculator: ...
class AccruedLiability: ...
tax_rate_basis_points: int = 0
```

### 14. Add Meaningful Context
Names sometimes need context to reveal meaning. Enclose in a class or use prefixes.

```python
# BAD: unclear what 'state' means alone
state = "TX"
city = "Austin"
zip_code = "78701"

# GOOD: class provides context
@dataclass
class Address:
    street: str
    city: str
    state: str
    zip_code: str
    country: str
```

### 15. Don't Add Gratuitous Context
Don't prefix everything with the app name.

```python
# BAD: In the GSD (Gas Station Deluxe) app:
class GSDAccountAddress: ...
class GSDMailingAddress: ...

# GOOD
class Address: ...
class MailingAddress: ...
```

## Quick Reference Cheat Sheet

| Rule | Bad | Good |
|------|-----|------|
| Reveal intent | `d`, `t`, `x` | `elapsed_days`, `active_users` |
| No disinformation | `account_list = {}` | `accounts = {}` |
| Pronounceable | `genymdhms` | `generation_timestamp` |
| Searchable | `range(7)` | `range(MAX_RETRIES)` |
| No encodings | `m_name`, `str_val` | `name`, `value: str` |
| Nouns for classes | `DataManager` | `Customer`, `Account` |
| Verbs for methods | `name()`, `flag()` | `get_name()`, `is_flagged()` |
| One word/concept | `fetch`, `get`, `retrieve` | pick one: `fetch` |
| Domain names | `visit_queue` | `job_queue` (CS) |
