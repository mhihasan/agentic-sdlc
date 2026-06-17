# Chapter 25: Layers and Boundaries

## Summary
Even simple systems have more potential boundaries than are obvious. Using a game example, Martin shows how boundaries proliferate as language variants, storage backends, and rendering targets are added. The architect's job is to decide which boundaries to implement fully, which partially, and which to defer entirely — based on expected rates of change, not on theoretical completeness.

## Key Principles
- **Boundaries proliferate with requirements**: Every new dimension of variation (language, storage, UI target) is a potential boundary.
- **Cost vs. risk tradeoff**: Under-investing in boundaries = painful future refactors. Over-investing = unnecessary complexity now.
- **Architect = boundary investment decision-maker**: Not all potential boundaries should be implemented.

## Python Example

```python
# A game engine revealing three potential boundaries
# Decision: which to implement now vs. defer?
from typing import Protocol
from dataclasses import dataclass

@dataclass
class Board:
    grid: list[list[str]]
    current_player: str

# Boundary 1: Game rules vs. rendering ← HIGH VALUE, implement now
# Rules change for game variants; renderer changes for UI targets. Different rates.
class GameRules(Protocol):
    def is_valid_move(self, board: Board, move: tuple[int, int]) -> bool: ...
    def check_winner(self, board: Board) -> str | None: ...

class TicTacToeRules:
    def is_valid_move(self, board: Board, move: tuple[int, int]) -> bool:
        row, col = move
        return board.grid[row][col] == ""

    def check_winner(self, board: Board) -> str | None:
        for row in board.grid:
            if len(set(row)) == 1 and row[0]:
                return row[0]
        return None


# Boundary 2: Rendering vs. output device ← MEDIUM VALUE, implement as Protocol
class Renderer(Protocol):
    def draw(self, board: Board, message: str) -> None: ...

class CliRenderer:
    def draw(self, board: Board, message: str) -> None:
        for row in board.grid:
            print("|".join(cell or "." for cell in row))
        print(message)

# Later: GuiRenderer, WebRenderer — new classes, no changes to game logic


# Boundary 3: Language/i18n ← DEFER, no evidence yet
# Don't create a Translator Protocol until internationalisation is actually needed.
# Hardcoded English in CliRenderer is fine until it isn't.

class Game:
    def __init__(self, rules: GameRules, renderer: Renderer) -> None:
        self._rules = rules
        self._renderer = renderer

    def play_turn(self, board: Board, move: tuple[int, int]) -> Board:
        if not self._rules.is_valid_move(board, move):
            self._renderer.draw(board, "Invalid move!")
            return board
        new_grid = [row[:] for row in board.grid]
        new_grid[move[0]][move[1]] = board.current_player
        new_board = Board(new_grid, "O" if board.current_player == "X" else "X")
        winner = self._rules.check_winner(new_board)
        msg = f"{winner} wins!" if winner else "Next player"
        self._renderer.draw(new_board, msg)
        return new_board

# Cost analysis:
# Boundary 1 (rules/render): high payoff — game variants and UI targets vary independently
# Boundary 2 (render/output): medium payoff — CLI vs GUI is plausible
# Boundary 3 (i18n): deferred — no evidence of need; adds complexity for zero current benefit
```

## Quick Reference
- Every dimension of variation is a potential boundary — most should be deferred
- Implement boundaries where rate-of-change difference is already evident, not theoretical
- Over-engineering boundaries costs as much as under-engineering them
- Start with `Protocol` (cheap); upgrade to separate packages only when needed
