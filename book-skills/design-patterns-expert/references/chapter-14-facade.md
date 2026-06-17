# Chapter 14: Structural — Facade

## Summary
Facade provides a simplified interface to a complex subsystem — a library, a framework, or
a body of interrelated classes. It doesn't prevent clients from accessing the subsystem
directly, but it provides a convenient default entry point for the most common use cases.
The Facade itself has no business logic; its only job is orchestration and simplification.
It is one of the most pragmatic patterns in the book: every well-designed SDK, framework
entry point, and service layer is a Facade over its own complexity.

## Key Principles
- **Simplified interface**: The Facade exposes a small, focused set of methods that cover the most frequent use cases.
- **No new behaviour**: The Facade doesn't do new work — it delegates everything to the underlying subsystem.
- **Doesn't lock out power users**: Clients that need full subsystem access can still bypass the Facade.
- **Hides complexity**: Consumers of the Facade are protected from changes to the subsystem's internal structure.
- **One Facade per bounded context**: Multiple Facades can exist over the same subsystem for different client needs (e.g., an admin Facade vs. a user-facing Facade).

## Python Example

```python
from dataclasses import dataclass
from typing import Optional

# ══════════════════════════════════════════════════════════
# Complex subsystem — video conversion pipeline
# (clients should not need to know all these classes exist)
# ══════════════════════════════════════════════════════════

class VideoFile:
    def __init__(self, path: str) -> None:
        self.path = path
        self.codec = path.split(".")[-1]

class CodecFactory:
    def extract(self, file: VideoFile) -> str:
        return f"raw_{file.codec}_stream"

class BitrateReader:
    @staticmethod
    def read(codec_stream: str, codec: str) -> str:
        return f"bitrate_data({codec_stream})"

class AudioMixer:
    @staticmethod
    def fix(bitrate_data: str) -> str:
        return f"mixed({bitrate_data})"

class VideoConverter:
    @staticmethod
    def convert(mixed: str, target_codec: str) -> "VideoFile":
        return VideoFile(f"output.{target_codec}")


# ❌ Bad: Client orchestrates the entire subsystem — tightly coupled and verbose
def convert_video_bad(filename: str, target: str) -> VideoFile:
    file = VideoFile(filename)
    factory = CodecFactory()
    codec_stream = factory.extract(file)
    bitrate_data = BitrateReader.read(codec_stream, file.codec)
    mixed = AudioMixer.fix(bitrate_data)
    result = VideoConverter.convert(mixed, target)
    return result
# Must be repeated everywhere video conversion is needed


# ✅ Good: Facade hides all orchestration

class VideoConversionFacade:
    """Single entry point for video conversion use cases."""

    def __init__(self) -> None:
        self._factory = CodecFactory()

    def convert(self, filename: str, target_format: str) -> VideoFile:
        """Convert a video file to the target format."""
        file = VideoFile(filename)
        codec_stream = self._factory.extract(file)
        bitrate_data = BitrateReader.read(codec_stream, file.codec)
        mixed = AudioMixer.fix(bitrate_data)
        return VideoConverter.convert(mixed, target_format)

    def extract_audio(self, filename: str) -> str:
        """Extract audio track only."""
        file = VideoFile(filename)
        codec_stream = self._factory.extract(file)
        return AudioMixer.fix(BitrateReader.read(codec_stream, file.codec))


# Client is clean — doesn't know about CodecFactory, BitrateReader, etc.
converter = VideoConversionFacade()
result = converter.convert("my_movie.mp4", "avi")
assert result.codec == "avi"

audio = converter.extract_audio("interview.mkv")
assert "mixed" in audio


# ── Real-world: Service layer as Facade over repositories + domain ─────────

@dataclass
class User:
    id: int
    email: str
    name: str

class UserRepository:
    def find_by_id(self, user_id: int) -> Optional[User]: ...
    def save(self, user: User) -> None: ...

class EmailService:
    def send_welcome(self, email: str) -> None: ...

class AnalyticsService:
    def track_signup(self, user_id: int) -> None: ...

# Facade for the "registration" use case
class RegistrationFacade:
    def __init__(
        self,
        users: UserRepository,
        email: EmailService,
        analytics: AnalyticsService,
    ) -> None:
        self._users = users
        self._email = email
        self._analytics = analytics

    def register(self, user_id: int, email: str, name: str) -> User:
        user = User(user_id, email, name)
        self._users.save(user)
        self._email.send_welcome(email)
        self._analytics.track_signup(user_id)
        return user
```

## Quick Reference
- **Intent**: Provide a simple interface to a complex subsystem
- **Use when**: A subsystem is complex and most clients only need a small subset of its capabilities
- **No business logic**: Facade only orchestrates and delegates; business logic stays in the subsystem
- **Layered architecture**: Each layer is a Facade over the layer below it
- **vs Adapter**: Adapter makes an incompatible interface compatible; Facade simplifies a complex interface
- **vs Mediator**: Mediator coordinates communication between subsystem components; Facade provides a simplified outward-facing API
- **vs Abstract Factory**: Abstract Factory can be used to configure which subsystem objects the Facade works with
- **Real uses**: Django ORM (Facade over SQL), `boto3` high-level clients, service layers in hexagonal architecture
