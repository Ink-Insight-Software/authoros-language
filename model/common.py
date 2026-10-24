"""The one place the training text format is written, so training, evaluation and
serving cannot drift apart."""

from __future__ import annotations

MOMENTS = ("opening", "returning", "chat", "farewell")

# The tones are the Dart package's `VoiceTone` values, plus `unlabelled` for data
# that says nothing about voice (the public-domain text).
TONES = (
    "neutral", "warm", "gentle", "earnest", "dry", "sardonic", "blunt", "formal",
    "timid", "quiet", "playful", "stoic",
)
LENGTHS = ("terse", "measured", "expansive")


def prompt(
    moment: str, author: str = "", voice: str = "unlabelled", length: str = "measured"
) -> str:
    """Everything the model is given. It writes what follows `CHARACTER:`."""
    if moment not in MOMENTS:
        raise ValueError(f"unknown moment {moment!r}")
    return (
        f"VOICE: tone={voice} length={length}\n"
        f"MOMENT: {moment}\n"
        f"AUTHOR: {author.strip()}\n"
        f"CHARACTER:"
    )


def example(row: dict) -> tuple[str, str]:
    """(prompt, reply) for one JSONL row."""
    return (
        prompt(
            row["moment"],
            row.get("author", ""),
            row.get("voice", "unlabelled"),
            row.get("length", "measured"),
        ),
        " " + row["reply"].strip(),
    )


def first_line(text: str) -> str:
    """A reply is one line: cut at the first newline."""
    return text.split("\n", 1)[0].strip()
