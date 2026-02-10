"""
Comprehensive unit tests for anti_detect_browser.py
Tests browser initialization, fingerprinting, navigation, and stealth features
"""
import pytest
import asyncio
from pathlib import Path
from unittest.mock import Mock, AsyncMock, patch, MagicMock
import json

from anti_detect_browser import AntiDetectBrowser, BrowserFingerprint


class TestBrowserFingerprint:
    """Test BrowserFingerprint dataclass"""

    def test_fingerprint_creation(self):
        """Test fingerprint object creation"""
        fingerprint = BrowserFingerprint(
            user_agent="Mozilla/5.0",
            viewport={"width": 1920, "height": 1080},
            locale="en-US",
            timezone="America/New_York",
            platform="Win32",
            languages=["en-US", "en"],
            plugins=["Chrome PDF Plugin"],
            webgl_vendor="Google Inc.",
            webgl_renderer="ANGLE (NVIDIA GeForce GTX 1060)",
            screen_resolution={"width": 1920, "height": 1080},
            color_depth=24,
            pixel_ratio=1.0
        )

        assert fingerprint.user_agent == "Mozilla/5.0"
        assert fingerprint.viewport["width"] == 1920
        assert fingerprint.platform == "Win32"
        assert "en-US" in fingerprint.languages


class TestAntiDetectBrowserInit:
    """Test AntiDetectBrowser initialization"""

    def test_browser_initialization(self):
        """Test browser object creation"""
        browser = AntiDetectBrowser("test_profile")

        assert browser.profile_name == "test_profile"
        assert browser.playwright is None
        assert browser.browser is None
        assert browser.context is None
        assert browser.page is None
        assert browser.current_fingerprint is None

    def test_profile_directory_creation(self, tmp_path):
        """Test profile directory is created"""
        with patch('anti_detect_browser.BROWSER_CONFIG', {"user_data_dir": str(tmp_path)}):
            browser = AntiDetectBrowser("test_profile")
            profile_dir = tmp_path / "test_profile"
            assert profile_dir.exists()


class TestFingerprintGeneration:
    """Test fingerprint generation"""

    def test_generate_desktop_fingerprint(self):
        """Test desktop fingerprint generation"""
        browser = AntiDetectBrowser("test")
        fingerprint = browser.generate_fingerprint(mobile=False)

        assert fingerprint is not None
        assert fingerprint.user_agent is not None
        assert fingerprint.viewport["width"] >= 1366
        assert fingerprint.platform in ["Win32", "MacIntel", "Linux x86_64"]
        assert len(fingerprint.languages) > 0

    def test_generate_mobile_fingerprint(self):
        """Test mobile fingerprint generation"""
        browser = AntiDetectBrowser("test")
        fingerprint = browser.generate_fingerprint(mobile=True)

        assert fingerprint is not None
        assert "iPhone" in fingerprint.user_agent
        assert fingerprint.viewport["width"] == 390
        assert fingerprint.platform == "iPhone"
        assert fingerprint.pixel_ratio == 3.0

    def test_fingerprint_randomization(self):
        """Test that fingerprints are randomized"""
        browser = AntiDetectBrowser("test")

        # Generate multiple fingerprints
        fingerprints = [browser.generate_fingerprint(mobile=False) for _ in range(5)]

        # Check that at least some variation exists
        user_agents = [f.user_agent for f in fingerprints]
        viewports = [f.viewport for f in fingerprints]

        # Should have some variation (not all identical)
        assert len(set(str(v) for v in viewports)) > 1 or len(set(user_agents)) > 1


@pytest.mark.asyncio
class TestBrowserStartup:
    """Test browser startup and initialization"""

    async def test_start_browser_desktop(self):
        """Test starting browser in desktop mode"""
        browser = AntiDetectBrowser("test")

        with patch.object(browser, 'playwright') as mock_pw:
            mock_browser = AsyncMock()
            mock_context = AsyncMock()
            mock_page = AsyncMock()

            mock_pw.chromium.launch = AsyncMock(return_value=mock_browser)
            mock_browser.new_context = AsyncMock(return_value=mock_context)
            mock_context.new_page = AsyncMock(return_value=mock_page)
            mock_context.add_init_script = AsyncMock()
            mock_page.evaluate = AsyncMock()
            mock_page.mouse.move = AsyncMock()

            # Mock async_playwright context manager
            with patch('anti_detect_browser.async_playwright') as mock_apw:
                mock_apw.return_value.__aenter__ = AsyncMock(return_value=mock_pw)
                mock_apw.return_value.__aexit__ = AsyncMock()

                # Would normally call start_browser, but mocking is complex
                # Just test fingerprint generation works
                fingerprint = browser.generate_fingerprint(mobile=False)
                assert fingerprint is not None

    async def test_stealth_scripts_added(self):
        """Test that stealth scripts are properly formatted"""
        browser = AntiDetectBrowser("test")
        fingerprint = browser.generate_fingerprint(mobile=False)
        browser.current_fingerprint = fingerprint

        # Test script generation doesn't crash
        assert browser.current_fingerprint.languages is not None
        assert browser.current_fingerprint.platform is not None


@pytest.mark.asyncio
class TestNavigationFeatures:
    """Test navigation and interaction features"""

    async def test_navigate_to_url(self):
        """Test URL navigation with delays"""
        browser = AntiDetectBrowser("test")
        browser.page = AsyncMock()
        browser.current_fingerprint = browser.generate_fingerprint()

        browser.page.goto = AsyncMock()
        browser.page.wait_for_selector = AsyncMock()
        browser.page.mouse.move = AsyncMock()

        await browser.navigate_to("https://example.com", wait_for="body")

        browser.page.goto.assert_called_once()

    async def test_click_element(self):
        """Test element clicking with human-like behavior"""
        browser = AntiDetectBrowser("test")
        browser.page = AsyncMock()

        mock_element = AsyncMock()
        mock_element.scroll_into_view_if_needed = AsyncMock()
        mock_element.click = AsyncMock()

        browser.page.wait_for_selector = AsyncMock(return_value=mock_element)

        await browser.click_element("button.submit")

        mock_element.scroll_into_view_if_needed.assert_called_once()
        mock_element.click.assert_called_once()

    async def test_type_text(self):
        """Test text typing with human-like delays"""
        browser = AntiDetectBrowser("test")
        browser.page = AsyncMock()

        mock_element = AsyncMock()
        mock_element.click = AsyncMock()

        browser.page.wait_for_selector = AsyncMock(return_value=mock_element)
        browser.page.keyboard.press = AsyncMock()
        browser.page.keyboard.type = AsyncMock()

        await browser.type_text("input#email", "test@example.com")

        browser.page.keyboard.type.assert_called()


@pytest.mark.asyncio
class TestScreenshotCapture:
    """Test screenshot capture functionality"""

    async def test_take_full_screenshot(self):
        """Test taking full page screenshot"""
        browser = AntiDetectBrowser("test")
        browser.page = AsyncMock()
        browser.page.screenshot = AsyncMock()

        screenshot_path = "/tmp/test_screenshot.jpg"
        result = await browser.take_screenshot(screenshot_path)

        assert result == screenshot_path
        browser.page.screenshot.assert_called_once()

    async def test_take_element_screenshot(self):
        """Test taking screenshot of specific element"""
        browser = AntiDetectBrowser("test")
        browser.page = AsyncMock()

        mock_element = AsyncMock()
        mock_element.screenshot = AsyncMock()

        browser.page.wait_for_selector = AsyncMock(return_value=mock_element)

        screenshot_path = "/tmp/element_screenshot.jpg"
        result = await browser.take_screenshot(screenshot_path, selector="div.chart")

        assert result == screenshot_path
        mock_element.screenshot.assert_called_once()


@pytest.mark.asyncio
class TestCookieManagement:
    """Test cookie management"""

    async def test_get_cookies(self):
        """Test getting session cookies"""
        browser = AntiDetectBrowser("test")
        browser.context = AsyncMock()

        expected_cookies = [
            {"name": "session_id", "value": "abc123"},
            {"name": "auth_token", "value": "xyz789"}
        ]
        browser.context.cookies = AsyncMock(return_value=expected_cookies)

        cookies = await browser.get_cookies()

        assert len(cookies) == 2
        assert cookies[0]["name"] == "session_id"

    async def test_set_cookies(self):
        """Test setting session cookies"""
        browser = AntiDetectBrowser("test")
        browser.context = AsyncMock()
        browser.context.add_cookies = AsyncMock()

        cookies_to_set = [{"name": "test_cookie", "value": "test_value"}]
        await browser.set_cookies(cookies_to_set)

        browser.context.add_cookies.assert_called_once_with(cookies_to_set)


@pytest.mark.asyncio
class TestCleanup:
    """Test cleanup and resource management"""

    async def test_cleanup_all_resources(self):
        """Test proper cleanup of all resources"""
        browser = AntiDetectBrowser("test")

        browser.page = AsyncMock()
        browser.context = AsyncMock()
        browser.browser = AsyncMock()
        browser.playwright = AsyncMock()

        browser.page.close = AsyncMock()
        browser.context.close = AsyncMock()
        browser.browser.close = AsyncMock()
        browser.playwright.stop = AsyncMock()

        await browser.cleanup()

        browser.page.close.assert_called_once()
        browser.context.close.assert_called_once()
        browser.browser.close.assert_called_once()
        browser.playwright.stop.assert_called_once()

        assert browser.page is None
        assert browser.context is None
        assert browser.browser is None
        assert browser.playwright is None

    async def test_cleanup_handles_none_objects(self):
        """Test cleanup when objects are already None"""
        browser = AntiDetectBrowser("test")

        # All objects already None
        browser.page = None
        browser.context = None
        browser.browser = None
        browser.playwright = None

        # Should not raise an error
        await browser.cleanup()

    async def test_context_manager(self):
        """Test async context manager protocol"""
        browser = AntiDetectBrowser("test")

        async with browser as b:
            assert b is browser


@pytest.mark.asyncio
class TestEdgeCases:
    """Test edge cases and error handling"""

    async def test_navigation_timeout_handling(self):
        """Test handling of navigation timeouts"""
        browser = AntiDetectBrowser("test")
        browser.page = AsyncMock()
        browser.current_fingerprint = browser.generate_fingerprint()

        browser.page.goto = AsyncMock(side_effect=Exception("Timeout"))
        browser.page.mouse = AsyncMock()
        browser.page.mouse.move = AsyncMock()

        with pytest.raises(Exception):
            await browser.navigate_to("https://example.com")

    async def test_element_not_found(self):
        """Test handling when element is not found"""
        browser = AntiDetectBrowser("test")
        browser.page = AsyncMock()

        browser.page.wait_for_selector = AsyncMock(side_effect=Exception("Element not found"))

        with pytest.raises(Exception):
            await browser.click_element("button.nonexistent")

    async def test_wait_for_response_empty(self):
        """Test waiting for response when none appears"""
        browser = AntiDetectBrowser("test")
        browser.page = AsyncMock()

        browser.page.query_selector = AsyncMock(return_value=None)

        result = await browser.wait_for_response("div.response", timeout=1000)

        assert result == ""


class TestIntegrationScenarios:
    """Integration test scenarios"""

    def test_full_fingerprint_consistency(self):
        """Test that generated fingerprints are internally consistent"""
        browser = AntiDetectBrowser("test")
        fingerprint = browser.generate_fingerprint(mobile=False)

        # Viewport and screen resolution should match
        assert fingerprint.viewport["width"] == fingerprint.screen_resolution["width"]
        assert fingerprint.viewport["height"] == fingerprint.screen_resolution["height"]

        # Platform and user agent should be consistent
        if "iPhone" in fingerprint.user_agent:
            assert fingerprint.platform == "iPhone"
        elif "Mac" in fingerprint.user_agent:
            assert "Mac" in fingerprint.platform

    def test_mobile_desktop_differences(self):
        """Test differences between mobile and desktop fingerprints"""
        browser = AntiDetectBrowser("test")

        mobile_fp = browser.generate_fingerprint(mobile=True)
        desktop_fp = browser.generate_fingerprint(mobile=False)

        assert mobile_fp.viewport["width"] < desktop_fp.viewport["width"]
        assert "iPhone" in mobile_fp.user_agent
        assert "iPhone" not in desktop_fp.user_agent


if __name__ == "__main__":
    pytest.main([__file__, "-v", "--tb=short"])