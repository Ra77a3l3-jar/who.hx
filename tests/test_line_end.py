"""Run: python -B -m unittest discover -s tests -v (requires steel on PATH)."""

from pathlib import Path
import subprocess
import tempfile
import unittest


class LineEndTests(unittest.TestCase):
    def test_hint_is_inserted_before_the_line_ending(self):
        # Execute the real helper without loading Helix or registering hooks.
        source = (Path(__file__).resolve().parents[1] / "who.scm").read_text(
            encoding="utf-8"
        )
        start = source.index("(define (who-line-end-char-index ")
        end = source.index("(define (who-clear-hint!)", start)
        helper = source[start:end]
        cases = [
            ("LF first line", r'(list "abc" "de" "")', 0, 3),
            ("LF second line", r'(list "abc" "de" "")', 1, 6),
            ("CRLF first line", r'(list "abc\r" "de\r" "")', 0, 3),
            ("CRLF second line", r'(list "abc\r" "de\r" "")', 1, 7),
            ("CRLF trailing empty line", r'(list "abc\r" "de\r" "")', 2, 9),
            ("empty CRLF line", r'(list "\r" "abc\r")', 0, 0),
            ("after empty CRLF line", r'(list "\r" "abc\r")', 1, 5),
            ("Unicode CRLF line", r'(list "中文\r" "x")', 0, 2),
            ("after Unicode CRLF line", r'(list "中文\r" "x")', 1, 5),
            ("no final newline", r'(list "abc\r" "de")', 1, 7),
        ]
        with tempfile.TemporaryDirectory(prefix="who-line-end-") as directory:
            script = Path(directory) / "line-end.scm"
            for label, lines, index, expected in cases:
                with self.subTest(label=label):
                    check = (
                        f"\n(define actual (who-line-end-char-index {lines} {index}))\n"
                        f"(unless (= actual {expected})\n"
                        f'  (error (to-string (list "{label}" actual {expected}))))\n'
                    )
                    script.write_text(helper + check, encoding="utf-8")
                    result = subprocess.run(
                        ["steel", str(script)], capture_output=True, text=True,
                        encoding="utf-8", timeout=30,
                    )
                    self.assertEqual(result.returncode, 0, result.stdout + result.stderr)


if __name__ == "__main__":
    unittest.main()
