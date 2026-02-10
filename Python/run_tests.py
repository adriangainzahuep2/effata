#!/usr/bin/env python3
"""
Test Runner for EFFATA Trading System
Runs all available tests and reports results
"""
import subprocess
import sys
from pathlib import Path


def run_test_file(test_file: str) -> bool:
    """Run a single test file and return success status"""
    print(f"\n{'='*60}")
    print(f"Running: {test_file}")
    print('='*60)

    try:
        result = subprocess.run(
            ["python", "-m", "pytest", test_file, "-v", "--tb=short"],
            capture_output=True,
            text=True,
            timeout=60
        )

        print(result.stdout)
        if result.stderr:
            print("STDERR:", result.stderr)

        return result.returncode == 0

    except subprocess.TimeoutExpired:
        print(f"❌ {test_file} timed out")
        return False
    except Exception as e:
        print(f"❌ Error running {test_file}: {e}")
        return False


def main():
    """Run all test files"""
    print("""
╔════════════════════════════════════════════════════════╗
║   EFFATA Trading System - Test Suite Runner           ║
╚════════════════════════════════════════════════════════╝
    """)

    test_files = [
        "test_config.py",
        "test_anti_detect_browser.py",
        "test_lmarena_scraper.py",
        "test_tradingview_scraper.py",
        "test_trading_analyzer.py",
        "test_utils.py",
    ]

    results = {}
    for test_file in test_files:
        if Path(test_file).exists():
            results[test_file] = run_test_file(test_file)
        else:
            print(f"⚠️  {test_file} not found")
            results[test_file] = None

    # Print summary
    print("\n")
    print("═"*60)
    print("TEST SUMMARY")
    print("═"*60)

    passed = sum(1 for v in results.values() if v is True)
    failed = sum(1 for v in results.values() if v is False)
    skipped = sum(1 for v in results.values() if v is None)

    for test_file, result in results.items():
        if result is True:
            status = "✓ PASS"
        elif result is False:
            status = "✗ FAIL"
        else:
            status = "⊘ SKIP"

        print(f"  {status}  {test_file}")

    print("─"*60)
    print(f"  Total:   {len(results)}")
    print(f"  Passed:  {passed}")
    print(f"  Failed:  {failed}")
    print(f"  Skipped: {skipped}")
    print("═"*60)

    if failed == 0 and passed > 0:
        print("✓ All tests passed!")
        return 0
    else:
        print("⚠ Some tests failed or were skipped")
        return 1


if __name__ == "__main__":
    sys.exit(main())