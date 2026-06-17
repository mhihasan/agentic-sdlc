# Chapter 31: The Web Is a Detail


## Summary
The Web is a GUI — one of many possible I/O delivery mechanisms, no different architecturally from a CLI, a desktop app, or a batch job. It has oscillated between thin-client and thick-client at least five times since the 1990s. An architecture that has the Web at its centre is fragile to that oscillation. Use cases must be deliverable via HTTP, CLI, gRPC, or a message queue without modification.

## Key Principles
- **The Web is a delivery mechanism**: HTTP is a transport detail, not an architectural organiser.
- **Use cases are UI-agnostic**: The same PlaceOrder use case should work whether invoked via HTTP, CLI, or an event queue.
- **Controllers are translators**: They convert HTTP requests into use case inputs, and use case outputs into HTTP responses.

## Python Example

```python
# Use case: completely web-agnostic
class GenerateReport:
    def __init__(self, data_service: "DataService"):
        self._data = data_service

    def execute(self, report_type: str, period: str) -> "ReportResult":
        data = self._data.fetch(report_type, period)
        return ReportResult(title=f"{report_type} ({period})", rows=data)

# Same use case, three delivery mechanisms:

# --- HTTP (Web) ---
from fastapi import FastAPI
app = FastAPI()
use_case = GenerateReport(...)

@app.get("/reports/{report_type}")
def http_report(report_type: str, period: str):
    result = use_case.execute(report_type, period)
    return {"title": result.title, "data": result.rows}

# --- CLI ---
import argparse

def cli_report():
    parser = argparse.ArgumentParser()
    parser.add_argument("report_type")
    parser.add_argument("--period", default="monthly")
    args = parser.parse_args()
    result = use_case.execute(args.report_type, args.period)
    print(result.title)
    for row in result.rows:
        print(row)

# --- Event queue (AWS Lambda, SQS) ---
def lambda_handler(event: dict, context) -> dict:
    result = use_case.execute(event["report_type"], event["period"])
    return {"statusCode": 200, "body": {"title": result.title, "rows": result.rows}}

# GenerateReport unchanged across all three delivery mechanisms.
```

## Quick Reference
- Web = delivery mechanism = outermost ring only
- Use cases must be invocable from HTTP, CLI, or event queue without modification
- "HTTP framework at the top of the architecture" = architectural mistake

---

