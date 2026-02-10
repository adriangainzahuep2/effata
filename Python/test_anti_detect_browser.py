"""
Comprehensive unit tests for anti_detect_browser.py
Tests browser initialization, fingerprint generation, navigation, and stealth features
"""
import pytest
import asyncio
from unittest.mock import Mock, AsyncMock, patch, MagicMock
from pathlib import Path
import json

from anti_detect_browser import AntiDetectBrowser, BrowserFingerprint


class TestBrowserFingerprint:
    """Test BrowserFingerprint dataclass"""

    def test_fingerprint_creation(self):
        """Test creating a browser fingerprint"""
        fingerprint = BrowserFingerprint(
            user_agent="Mozilla/5.0",
            viewport={"width": 1920, "height": 1080},
            locale="en-US",
            timezone="America/New_York",
            platform="Win32",
            languages=["en-US", "en"],
            plugins=["Chrome PDF Plugin"],
            webgl_vendor="Google Inc.",
            webgl_renderer="ANGLE",
            screen_resolution={"width": 1920, "height": 1080},
            color_depth=24,
            pixel_ratio=1.0
        )

        assert fingerprint.user_agent == "Mozilla/5.0"
        assert fingerprint.viewport["width"] == 1920
        assert fingerprint.locale == "en-US"
        assert fingerprint.timezone == "America/New_York"


class TestAntiDetectBrowser:
    """Test AntiDetectBrowser class"""

    @pytest.fixture
    def browser(self):
        """Create browser instance for testing"""
        return AntiDetectBrowser(profile_name="test_profile")

    def test_browser_initialization(self, browser):
        """Test browser initialization"""
        assert browser.profile_name == "test_profile"
        assert browser.playwright is None
        assert browser.browser is None
        assert browser.context is None
        assert browser.page is None
        assert browser.current_fingerprint is None
        assert isinstance(browser.session_cookies, dict)

    def test_profile_directory_creation(self, browser, tmp_path):
        """Test that profile directory is created"""
        # The directory should be created on initialization
        assert browser.profile_dir.exists()

    def test_generate_fingerprint_desktop(self, browser):
        """Test generating desktop browser fingerprint"""
        fingerprint = browser.generate_fingerprint(mobile=False)

        assert isinstance(fingerprint, BrowserFingerprint)
        assert fingerprint.user_agent is not None
        assert fingerprint.viewport["width"] >= 1366
        assert fingerprint.viewport["height"] >= 768
        assert fingerprint.platform in ["Win32", "MacIntel", "Linux x86_64"]
        assert len(fingerprint.languages) > 0
        assert fingerprint.color_depth in [24, 32]

    def test_generate_fingerprint_mobile(self, browser):
        """Test generating mobile browser fingerprint"""
        fingerprint = browser.generate_fingerprint(mobile=True)

        assert isinstance(fingerprint, BrowserFingerprint)
        assert "iPhone" in fingerprint.user_agent or "Mobile" in fingerprint.user_agent
        assert fingerprint.viewport["width"] == 390
        assert fingerprint.viewport["height"] == 844
        assert fingerprint.platform == "iPhone"
        assert fingerprint.pixel_ratio == 3.0

    def test_generate_fingerprint_randomness(self, browser):
        """Test that fingerprint generation produces different results"""
        fingerprint1 = browser.generate_fingerprint(mobile=False)
        fingerprint2 = browser.generate_fingerprint(mobile=False)

        # At least some properties should be different due to randomization
        differences = sum([
            fingerprint1.user_agent != fingerprint2.user_agent,
            fingerprint1.viewport != fingerprint2.viewport,
            fingerprint1.timezone != fingerprint2.timezone,
            fingerprint1.webgl_renderer != fingerprint2.webgl_renderer
        ])

        assert differences > 0, "Fingerprints should have some randomness"

    @pytest.mark.asyncio
    async def test_start_browser_desktop(self, browser):
        """Test starting browser in desktop mode"""
        with patch('anti_detect_browser.async_playwright') as mock_playwright:
            mock_pw = AsyncMock()
            mock_browser = AsyncMock()
            mock_context = AsyncMock()
            mock_page = AsyncMock()

            mock_playwright.return_value.start = AsyncMock(return_value=mock_pw)
            mock_pw.chromium.launch = AsyncMock(return_value=mock_browser)
            mock_browser.new_context = AsyncMock(return_value=mock_context)
            mock_context.new_page = AsyncMock(return_value=mock_page)
            mock_context.add_init_script = AsyncMock()

            await browser.start_browser(mobile=False)

            assert browser.playwright is not None
            assert browser.browser is not None
            assert browser.context is not None
            assert browser.page is not None
            assert browser.current_fingerprint is not None

            # Cleanup
            await browser.cleanup()

    @pytest.mark.asyncio
    async def test_start_browser_with_proxy(self, browser):
        """Test starting browser with proxy configuration"""
        proxy_config = {
            "server": "http://proxy.example.com:8080",
            "username": "user",
            "password": "pass"
        }

        with patch('anti_detect_browser.async_playwright') as mock_playwright:
            mock_pw = AsyncMock()
            mock_browser = AsyncMock()
            mock_context = AsyncMock()
            mock_page = AsyncMock()

            mock_playwright.return_value.start = AsyncMock(return_value=mock_pw)
            mock_pw.chromium.launch = AsyncMock(return_value=mock_browser)
            mock_browser.new_context = AsyncMock(return_value=mock_context)
            mock_context.new_page = AsyncMock(return_value=mock_page)
            mock_context.add_init_script = AsyncMock()

            await browser.start_browser(proxy=proxy_config)

            # Verify proxy was passed to context
            call_kwargs = mock_browser.new_context.call_args[1]
            assert "proxy" in call_kwargs
            assert call_kwargs["proxy"] == proxy_config

            await browser.cleanup()

    @pytest.mark.asyncio
    async def test_navigate_to(self, browser):
        """Test navigation to URL"""
        mock_page = AsyncMock()
        mock_page.goto = AsyncMock()
        mock_page.wait_for_selector = AsyncMock()
        mock_page.mouse.move = AsyncMock()
        browser.page = mock_page
        browser.current_fingerprint = browser.generate_fingerprint()

        await browser.navigate_to("https://example.com", wait_for="body")

        mock_page.goto.assert_called_once()
        mock_page.wait_for_selector.assert_called_once_with("body", timeout=30000)

    @pytest.mark.asyncio
    async def test_click_element(self, browser):
        """Test clicking an element"""
        mock_element = AsyncMock()
        mock_element.scroll_into_view_if_needed = AsyncMock()
        mock_element.click = AsyncMock()

        mock_page = AsyncMock()
        mock_page.wait_for_selector = AsyncMock(return_value=mock_element)
        browser.page = mock_page

        await browser.click_element(".test-selector")

        mock_page.wait_for_selector.assert_called_once()
        mock_element.scroll_into_view_if_needed.assert_called_once()
        mock_element.click.assert_called_once()

    @pytest.mark.asyncio
    async def test_type_text(self, browser):
        """Test typing text into an element"""
        mock_element = AsyncMock()
        mock_element.click = AsyncMock()

        mock_page = AsyncMock()
        mock_page.wait_for_selector = AsyncMock(return_value=mock_element)
        mock_page.keyboard.press = AsyncMock()
        mock_page.keyboard.type = AsyncMock()
        browser.page = mock_page

        test_text = "Hello World"
        await browser.type_text(".input-selector", test_text)

        mock_page.wait_for_selector.assert_called_once()
        assert mock_page.keyboard.type.call_count == len(test_text)

    @pytest.mark.asyncio
    async def test_take_screenshot(self, browser, tmp_path):
        """Test taking a screenshot"""
        screenshot_path = tmp_path / "test_screenshot.jpg"

        mock_page = AsyncMock()
        mock_page.screenshot = AsyncMock()
        browser.page = mock_page

        result = await browser.take_screenshot(str(screenshot_path))

        mock_page.screenshot.assert_called_once()
        assert result == str(screenshot_path)

    @pytest.mark.asyncio
    async def test_take_screenshot_with_selector(self, browser, tmp_path):
        """Test taking screenshot of specific element"""
        screenshot_path = tmp_path / "test_screenshot.jpg"

        mock_element = AsyncMock()
        mock_element.screenshot = AsyncMock()

        mock_page = AsyncMock()
        mock_page.wait_for_selector = AsyncMock(return_value=mock_element)
        browser.page = mock_page

        result = await browser.take_screenshot(
            str(screenshot_path),
            selector=".chart-container"
        )

        mock_page.wait_for_selector.assert_called_once()
        mock_element.screenshot.assert_called_once()
        assert result == str(screenshot_path)

    @pytest.mark.asyncio
    async def test_wait_for_response(self, browser):
        """Test waiting for response text"""
        mock_element = AsyncMock()
        mock_element.inner_text = AsyncMock(return_value="Test response text")

        mock_page = AsyncMock()
        mock_page.wait_for_selector = AsyncMock()
        mock_page.query_selector = AsyncMock(return_value=mock_element)
        browser.page = mock_page

        result = await browser.wait_for_response(".response-selector")

        assert result == "Test response text"
        mock_page.wait_for_selector.assert_called_once()

    @pytest.mark.asyncio
    async def test_get_cookies(self, browser):
        """Test getting session cookies"""
        mock_cookies = [
            {"name": "session", "value": "abc123"},
            {"name": "token", "value": "xyz789"}
        ]

        mock_context = AsyncMock()
        mock_context.cookies = AsyncMock(return_value=mock_cookies)
        browser.context = mock_context

        result = await browser.get_cookies()

        assert result == mock_cookies
        mock_context.cookies.assert_called_once()

    @pytest.mark.asyncio
    async def test_set_cookies(self, browser):
        """Test setting session cookies"""
        test_cookies = [
            {"name": "session", "value": "abc123"}
        ]

        mock_context = AsyncMock()
        mock_context.add_cookies = AsyncMock()
        browser.context = mock_context

        await browser.set_cookies(test_cookies)

        mock_context.add_cookies.assert_called_once_with(test_cookies)

    @pytest.mark.asyncio
    async def test_cleanup(self, browser):
        """Test cleanup of browser resources"""
        mock_page = AsyncMock()
        mock_context = AsyncMock()
        mock_browser = AsyncMock()
        mock_playwright = AsyncMock()

        mock_page.close = AsyncMock()
        mock_context.close = AsyncMock()
        mock_browser.close = AsyncMock()
        mock_playwright.stop = AsyncMock()

        browser.page = mock_page
        browser.context = mock_context
        browser.browser = mock_browser
        browser.playwright = mock_playwright

        await browser.cleanup()

        mock_page.close.assert_called_once()
        mock_context.close.assert_called_once()
        mock_browser.close.assert_called_once()
        mock_playwright.stop.assert_called_once()

        assert browser.page is None
        assert browser.context is None
        assert browser.browser is None
        assert browser.playwright is None

    @pytest.mark.asyncio
    async def test_context_manager(self, browser):
        """Test async context manager usage"""
        with patch.object(browser, 'cleanup', new_callable=AsyncMock) as mock_cleanup:
            async with browser:
                pass

            mock_cleanup.assert_called_once()

    @pytest.mark.asyncio
    async def test_random_mouse_movement(self, browser):
        """Test random mouse movement simulation"""
        mock_page = AsyncMock()
        mock_page.mouse.move = AsyncMock()
        browser.page = mock_page
        browser.current_fingerprint = browser.generate_fingerprint()

        await browser._random_mouse_movement()

        mock_page.mouse.move.assert_called_once()
        call_args = mock_page.mouse.move.call_args[0]
        assert 100 <= call_args[0] <= browser.current_fingerprint.viewport["width"] - 100
        assert 100 <= call_args[1] <= browser.current_fingerprint.viewport["height"] - 100

    @pytest.mark.asyncio
    async def test_error_handling_start_browser(self, browser):
        """Test error handling when browser start fails"""
        with patch('anti_detect_browser.async_playwright') as mock_playwright:
            mock_playwright.return_value.start = AsyncMock(
                side_effect=Exception("Browser launch failed")
            )

            with pytest.raises(Exception, match="Browser launch failed"):
                await browser.start_browser()

    @pytest.mark.asyncio
    async def test_error_handling_navigation(self, browser):
        """Test error handling when navigation fails"""
        mock_page = AsyncMock()
        mock_page.goto = AsyncMock(side_effect=Exception("Navigation failed"))
        browser.page = mock_page
        browser.current_fingerprint = browser.generate_fingerprint()

        with pytest.raises(Exception, match="Navigation failed"):
            await browser.navigate_to("https://example.com")

    @pytest.mark.asyncio
    async def test_stealth_scripts_injection(self, browser):
        """Test that stealth scripts are properly injected"""
        mock_context = AsyncMock()
        mock_context.add_init_script = AsyncMock()
        browser.context = mock_context
        browser.current_fingerprint = browser.generate_fingerprint()

        await browser._add_stealth_scripts()

        mock_context.add_init_script.assert_called_once()
        script = mock_context.add_init_script.call_args[0][0]

        # Verify key stealth features are in the script
        assert "navigator.webdriver" in script
        assert "navigator.plugins" in script
        assert "navigator.languages" in script
        assert "navigator.platform" in script
        assert "WebGLRenderingContext" in script

    @pytest.mark.asyncio
    async def test_apply_stealth_measures(self, browser):
        """Test applying stealth measures to page"""
        mock_page = AsyncMock()
        mock_page.evaluate = AsyncMock()
        mock_page.mouse.move = AsyncMock()
        browser.page = mock_page
        browser.current_fingerprint = browser.generate_fingerprint()

        await browser._apply_stealth_measures()

        # Should call evaluate to delete automation detection properties
        mock_page.evaluate.assert_called()
        eval_script = mock_page.evaluate.call_args[0][0]
        assert "cdc_adoQpoasnfa76pfcZLmcfl" in eval_script


class TestAntiDetectBrowserIntegration:
    """Integration tests for browser functionality"""

    @pytest.mark.asyncio
    @pytest.mark.integration
    async def test_full_browser_lifecycle(self):
        """Test complete browser lifecycle (requires playwright installation)"""
        browser = AntiDetectBrowser("test_integration")

        # This test requires actual playwright - skip if not available
        try:
            from playwright.async_api import async_playwright
        except ImportError:
            pytest.skip("Playwright not installed")

        # Test would require actual browser automation
        # Placeholder for integration test
        pass

    def test_browser_profile_isolation(self):
        """Test that different profiles are isolated"""
        browser1 = AntiDetectBrowser("profile1")
        browser2 = AntiDetectBrowser("profile2")

        assert browser1.profile_dir != browser2.profile_dir
        assert browser1.profile_name != browser2.profile_name


# Edge cases and boundary tests
class TestAntiDetectBrowserEdgeCases:
    """Test edge cases and boundary conditions"""

    def test_empty_profile_name(self):
        """Test browser with empty profile name"""
        browser = AntiDetectBrowser("")
        assert browser.profile_name == ""

    @pytest.mark.asyncio
    async def test_navigate_without_browser(self):
        """Test navigation when browser not started"""
        browser = AntiDetectBrowser("test")

        with pytest.raises(AttributeError):
            await browser.navigate_to("https://example.com")

    @pytest.mark.asyncio
    async def test_get_cookies_without_context(self):
        """Test getting cookies when context is None"""
        browser = AntiDetectBrowser("test")
        result = await browser.get_cookies()
        assert result == []

    @pytest.mark.asyncio
    async def test_set_cookies_without_context(self):
        """Test setting cookies when context is None"""
        browser = AntiDetectBrowser("test")
        # Should not raise exception
        await browser.set_cookies([{"name": "test", "value": "val"}])

    @pytest.mark.asyncio
    async def test_cleanup_when_already_clean(self):
        """Test cleanup when resources are already None"""
        browser = AntiDetectBrowser("test")
        # Should not raise exception
        await browser.cleanup()

    def test_fingerprint_languages_variety(self):
        """Test that fingerprint generates various language combinations"""
        browser = AntiDetectBrowser("test")
        languages_seen = set()

        for _ in range(10):
            fingerprint = browser.generate_fingerprint()
            languages_seen.add(tuple(fingerprint.languages))

        # Should have at least 2 different language combinations
        assert len(languages_seen) >= 2

    def test_fingerprint_timezone_variety(self):
        """Test that fingerprint generates various timezones"""
        browser = AntiDetectBrowser("test")
        timezones_seen = set()

        for _ in range(10):
            fingerprint = browser.generate_fingerprint()
            timezones_seen.add(fingerprint.timezone)

        # Should have at least 2 different timezones
        assert len(timezones_seen) >= 2