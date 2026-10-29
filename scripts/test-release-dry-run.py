#!/usr/bin/env python3
"""Exercise packaging control flow with a fake build and forbidden credential tools."""

import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parent.parent
BUILD = ROOT / "build"


class DryRunTests(unittest.TestCase):
    def setUp(self):
        BUILD.mkdir(exist_ok=True)
        self.temp = tempfile.TemporaryDirectory(prefix="dry-run-test-", dir=BUILD)
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        for name in ["project.yml", "LICENSE", "scripts/release.sh", "scripts/check-licenses.sh",
                     "Thermals/Fonts/OFL.txt", "Thermals/Notices/Sparkle-LICENSE.txt"]:
            target = self.root / name
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(ROOT / name, target)
        self.bin = self.root / "bin"
        self.bin.mkdir()
        self.calls = self.root / "calls"
        stub = self.bin / "stub"
        stub.write_text("#!" + shutil.which("python3") + "\n" + r'''
import os, pathlib, shutil, sys, zipfile
root = pathlib.Path.cwd()
name = pathlib.Path(sys.argv[0]).name
with (root / "calls").open("a") as log:
    log.write(name + "\n")
if name in {"security", "gh", "brew", "xcrun", "sign_update", "git"}:
    sys.exit("Forbidden production operation: " + name)
if name == "xcodebuild":
    resources = root / "build/release/derived/Build/Products/Release/Thermals.app/Contents/Resources"
    resources.mkdir(parents=True)
    for source in ["LICENSE", "Thermals/Notices/Sparkle-LICENSE.txt", "Thermals/Fonts/OFL.txt"]:
        if not (os.environ.get("OMIT_LICENSE") and source == "LICENSE"):
            shutil.copyfile(root / source, resources / pathlib.Path(source).name)
    signer = root / "build/release/derived/SourcePackages/artifacts/sparkle/Sparkle/bin/sign_update"
    signer.parent.mkdir(parents=True)
    signer.symlink_to(root / "bin/stub")
elif name == "ditto":
    if "-c" in sys.argv:
        source = pathlib.Path(sys.argv[-2])
        with zipfile.ZipFile(sys.argv[-1], "w") as archive:
            for file in source.rglob("*"):
                if file.is_file():
                    archive.write(file, file.relative_to(source.parent))
    else:
        shutil.copytree(sys.argv[-2], sys.argv[-1])
elif name == "codesign" and "--sign" in sys.argv:
    assert sys.argv[sys.argv.index("--sign") + 1] == "-"
''')
        stub.chmod(0o755)
        for name in ["xcodegen", "xcodebuild", "ditto", "codesign", "security", "gh", "brew", "xcrun", "git"]:
            (self.bin / name).symlink_to(stub)
        self.env = {"PATH": str(self.bin) + os.pathsep + os.environ["PATH"],
                    "HOME": str(self.root), "LANG": "C"}

    def run_script(self, *args):
        return subprocess.run(["bash", "scripts/release.sh", *args], cwd=self.root,
                              env=self.env, capture_output=True, text=True)

    def test_dry_run_without_production_credentials(self):
        result = self.run_script("--dry-run")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        archives = list((self.root / "build/release").glob("*/Thermals-*.zip"))
        self.assertEqual(len(archives), 1)
        self.assertTrue((archives[0].parent / "thermals.rb").is_file())
        self.assertFalse(list(self.root.rglob("appcast.xml")))
        self.assertNotIn("sign_update", self.calls.read_text())

    def test_dry_run_ignores_incomplete_production_environment(self):
        self.env.update(SPARKLE_ED_PRIVATE_KEY="invalid-test-value", NOTARY_KEY_PATH="missing-test-key")
        result = self.run_script("--dry-run")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertNotIn("sign_update", self.calls.read_text())

    def test_missing_notice_stops_packaging(self):
        self.env["OMIT_LICENSE"] = "1"
        result = self.run_script("--dry-run")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("LICENSE", result.stderr)
        self.assertNotIn("codesign", self.calls.read_text())
        self.assertFalse(list(self.root.rglob("*.zip")))


if __name__ == "__main__":
    unittest.main()
