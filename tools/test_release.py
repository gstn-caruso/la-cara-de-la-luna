import unittest
from release import HEADER, change_type, next_version


class ReleasePolicyTests(unittest.TestCase):
    def test_initial_release_and_non_product_changes(self):
        self.assertEqual(next_version("", ["feat: initial game"]), "0.1.0")
        self.assertEqual(next_version("v0.1.0", ["docs: clarify controls", "ci: update runner"]), "")

    def test_semver_increments(self):
        self.assertEqual(next_version("v0.1.0", ["fix(menu): restore focus"]), "0.1.1")
        self.assertEqual(next_version("v0.1.1", ["fix: correct names", "feat: add combat"]), "0.2.0")
        self.assertEqual(next_version("v0.2.0", ["feat(save)!: replace save format"]), "1.0.0")
        self.assertEqual(next_version("v2.3.4", ["refactor: replace storage\n\nBREAKING CHANGE: old saves need conversion"]), "3.0.0")
        self.assertEqual(next_version("v1.2.3", ["perf: reduce allocations"]), "1.2.4")

    def test_headers_and_scopes(self):
        self.assertIsNotNone(HEADER.fullmatch("feat(character-creation): add a class"))
        self.assertIsNone(HEADER.fullmatch("add a menu"))
        self.assertIsNone(HEADER.fullmatch("feat: title\nfix: body"))
        self.assertIsNone(change_type("Merge pull request #1 from feature/menu"))
        self.assertEqual(change_type("fix!: change controls"), "major")


if __name__ == "__main__":
    unittest.main()
