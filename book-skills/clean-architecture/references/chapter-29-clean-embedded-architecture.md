# Chapter 29: Clean Embedded Architecture

## Summary
Embedded systems suffer identical architectural failures to server software — business logic entangled with hardware specifics. The **target hardware bottleneck**: code that only runs on the target device cannot be tested until the hardware exists, adding weeks to every test cycle. HAL (Hardware Abstraction Layer) and OSAL (OS Abstraction Layer) apply DIP to hardware, making business logic portable across processors and operating systems. Same four-ring model, same Dependency Rule.

## Key Principles
- **Hardware is a detail**: Processor, GPIO pins, sensor bus — volatile details, not architectural anchors.
- **HAL (Hardware Abstraction Layer)**: Protocol layer that makes business logic independent of specific hardware — DIP applied to hardware.
- **OSAL (OS Abstraction Layer)**: Makes business logic independent of RTOS or OS.
- **Test on development machine**: With HAL/OSAL, business logic tests run on a developer's laptop before hardware exists.

## Python Example

```python
# ❌ Bad: Business logic directly calls hardware — untestable without physical device
import RPi.GPIO as GPIO

def read_temperature_and_alert() -> None:
    GPIO.setmode(GPIO.BCM)
    GPIO.setup(4, GPIO.IN)
    raw = GPIO.input(4)                    # direct hardware call in business logic
    temp_c = raw * 0.0625
    if temp_c > 80:
        GPIO.setup(18, GPIO.OUT)
        GPIO.output(18, GPIO.HIGH)         # LED alert mixed with business logic
# Untestable without physical Raspberry Pi, wired sensors, and actual temperature.
```

```python
# ✅ Good: HAL via Protocol — business logic tested on any machine
from typing import Protocol
from dataclasses import dataclass

# --- HAL Protocols (inner ring — defined by business logic layer) ---
class TemperatureSensor(Protocol):
    def read_celsius(self) -> float: ...

class AlertActuator(Protocol):
    def trigger(self) -> None: ...
    def reset(self) -> None: ...

# --- Business Logic (inner ring — zero hardware imports) ---
class ThermalProtection:
    CRITICAL_TEMP = 80.0

    def __init__(self, sensor: TemperatureSensor, alert: AlertActuator) -> None:
        self._sensor = sensor
        self._alert = alert

    def check(self) -> bool:
        temp = self._sensor.read_celsius()
        if temp > self.CRITICAL_TEMP:
            self._alert.trigger()
            return True
        self._alert.reset()
        return False

# --- HAL Implementation (outer ring — hardware detail lives here only) ---
class RpiTemperatureSensor:                # satisfies TemperatureSensor Protocol
    def read_celsius(self) -> float:
        import RPi.GPIO as GPIO            # hardware import isolated to outer ring
        return GPIO.input(4) * 0.0625

class RpiLedAlert:                         # satisfies AlertActuator Protocol
    def trigger(self) -> None:
        import RPi.GPIO as GPIO
        GPIO.output(18, GPIO.HIGH)
    def reset(self) -> None:
        import RPi.GPIO as GPIO
        GPIO.output(18, GPIO.LOW)

# --- Test doubles (laptop tests — no hardware, no RPi import) ---
class FakeTemperatureSensor:
    def __init__(self, temperature: float) -> None:
        self._temp = temperature
    def read_celsius(self) -> float:
        return self._temp

class FakeAlertActuator:
    def __init__(self) -> None:
        self.triggered = False
    def trigger(self) -> None:
        self.triggered = True
    def reset(self) -> None:
        self.triggered = False

# Tests run on any machine, before hardware exists
def test_critical_temp_triggers_alert() -> None:
    sensor = FakeTemperatureSensor(temperature=85.0)
    alert = FakeAlertActuator()
    assert ThermalProtection(sensor, alert).check() is True
    assert alert.triggered is True

def test_safe_temp_resets_alert() -> None:
    sensor = FakeTemperatureSensor(temperature=60.0)
    alert = FakeAlertActuator()
    ThermalProtection(sensor, alert).check()
    assert alert.triggered is False

def test_boundary_exactly_at_critical() -> None:
    sensor = FakeTemperatureSensor(temperature=80.0)    # not strictly greater
    alert = FakeAlertActuator()
    assert ThermalProtection(sensor, alert).check() is False
```

```python
# OSAL pattern: abstract the OS/scheduler
from typing import Protocol

class TaskScheduler(Protocol):
    def schedule_periodic(self, fn: "Callable[[], None]", interval_ms: int) -> None: ...

class FreeRtosScheduler:
    def schedule_periodic(self, fn, interval_ms: int) -> None:
        # FreeRTOS task creation
        ...

class ThreadingScheduler:            # for dev/test on laptop
    def schedule_periodic(self, fn, interval_ms: int) -> None:
        import threading
        t = threading.Thread(target=lambda: [fn(), __import__('time').sleep(interval_ms/1000)], daemon=True)
        t.start()
```

## Quick Reference
- Embedded systems: same Dependency Rule, same four rings
- HAL = DIP applied to hardware — business logic never imports RPi.GPIO directly
- OSAL = DIP applied to OS — business logic never imports RTOS primitives directly
- Goal: entire business logic test suite runs on developer laptop before hardware ships
