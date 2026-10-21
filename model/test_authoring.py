import tempfile
import unittest
from pathlib import Path

import authoring

GOOD = """
written-by: Test Author
rights: own
ai-assisted: no

voice: dry
length: terse

[opening]
Ah. There you are.

[chat]
> Good morning!
Is it.

[farewell]
> I should go now.
Do.
"""


def load(text: str, name: str = "t.md"):
    with tempfile.TemporaryDirectory() as d:
        p = Path(d) / name
        p.write_text(text, encoding="utf-8")
        return authoring.load([str(p)])


class Authoring(unittest.TestCase):
    def test_a_good_file_parses_into_rows(self):
        rows, problems = load(GOOD)
        self.assertEqual(problems.errors, [])
        self.assertEqual(
            [(r.voice, r.length, r.moment, r.author, r.reply) for r in rows],
            [
                ("dry", "terse", "opening", "", "Ah. There you are."),
                ("dry", "terse", "chat", "Good morning!", "Is it."),
                ("dry", "terse", "farewell", "I should go now.", "Do."),
            ],
        )

    def test_the_attestations_are_required(self):
        for drop, expect in (
            ("written-by: Test Author\n", "written-by"),
            ("rights: own\n", "rights"),
            ("ai-assisted: no\n", "ai-assisted"),
        ):
            _, p = load(GOOD.replace(drop, ""))
            self.assertTrue(any(expect in e for e in p.errors), expect)
        _, p = load(GOOD.replace("ai-assisted: no", "ai-assisted: yes"))
        self.assertTrue(any("ai-assisted" in e for e in p.errors))
        _, p = load(GOOD.replace("rights: own", "rights: found-it-online"))
        self.assertTrue(any("rights" in e for e in p.errors))

    def test_unknown_voice_length_and_moment_are_errors(self):
        for bad in ("voice: cheerful", "length: huge"):
            key = bad.split(":")[0]
            _, p = load(GOOD.replace(f"{key}: {'dry' if key == 'voice' else 'terse'}", bad))
            self.assertTrue(p.errors, bad)
        _, p = load(GOOD.replace("[opening]", "[nonsense]"))
        self.assertTrue(any("nonsense" in e for e in p.errors))

    def test_replies_are_held_to_the_guards_rules(self):
        for reply, why in (
            ("Ah, Tom. There you are.", "name"),
            ("Come back in 5 minutes.", "digit"),
            ("**Sighs.** There you are.", "markup"),
            ('"Ah." There you are.', "quot"),
            (" ".join(["word"] * 40), "words"),
        ):
            _, p = load(GOOD.replace("Ah. There you are.", reply))
            self.assertTrue(p.errors, why)

    def test_sentence_initial_capitals_and_I_are_fine(self):
        _, p = load(GOOD.replace("Ah. There you are.", "Well. I did wonder. Now then."))
        self.assertEqual(p.errors, [])

    def test_structure_errors(self):
        _, p = load(GOOD.replace("> Good morning!\n", ""))
        self.assertTrue(any("no `>` author line" in e for e in p.errors))
        _, p = load(GOOD.replace("[opening]\nAh. There you are.", "[opening]\n> Hello\nAh."))
        self.assertTrue(any("has no author line" in e for e in p.errors))
        _, p = load(GOOD + "\n[chat]\n> Anyone there?\n")
        self.assertTrue(any("no reply" in e for e in p.errors))

    def test_example_files_are_never_built(self):
        rows, p = load(GOOD, name="x.example.md")
        self.assertEqual((rows, p.errors), ([], []))

    def test_duplicates_warn(self):
        rows, p = load(GOOD + "\n[chat]\n> Good morning!\nIs it.\n")
        self.assertEqual(len(p.warnings), 1)

    def test_the_split_holds_out_a_tenth_of_a_cell_with_five_or_more(self):
        rows = [
            authoring.Row("dry", "measured", "chat", f"a{i}", f"r{i}", "f", i)
            for i in range(20)
        ]
        train, held = authoring.split(rows)
        self.assertEqual((len(train), len(held)), (18, 2))
        few = rows[:4]
        train, held = authoring.split(few)
        self.assertEqual((len(train), len(held)), (4, 0))

    def test_coverage_reports_gaps(self):
        rows, _ = load(GOOD)
        text = authoring.coverage(rows)
        self.assertIn("dry", text)
        self.assertIn("under target", text)

    def test_the_template_itself_is_valid(self):
        path = Path(__file__).parent / "authoring" / "TEMPLATE.example.md"
        problems = authoring.Problems()
        rows = authoring.parse(path, problems)
        self.assertEqual(problems.errors, [])
        self.assertTrue(rows)


if __name__ == "__main__":
    unittest.main()
