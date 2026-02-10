"""
Comprehensive unit tests for tradingview_scraper.py
Tests TradingView chart scraping, screenshot capture, and image processing
"""
import pytest
import asyncio
from pathlib import Path
from unittest.mock import Mock, AsyncMock, patch, MagicMock
from PIL import Image

from tradingview_scraper import TradingViewScraper


class TestTradingViewScraperInit:
    """Test scraper initialization"""

    def test_scraper_initialization(self):
        scraper = TradingViewScraper("test_profile")
        assert scraper.profile_name == "test_profile"
        assert scraper.browser is None
        assert scraper.chart_loaded is False


@pytest.mark.asyncio
class TestChartLoading:
    """Test chart loading"""

    async def test_load_chart_success(self):
        scraper = TradingViewScraper("test")
        scraper.browser = AsyncMock()
        scraper.browser.navigate_to = AsyncMock()
        scraper.browser.page = AsyncMock()
        scraper.browser.page.wait_for_selector = AsyncMock()
        scraper.browser.page.evaluate = AsyncMock()
        scraper.browser.page.keyboard = AsyncMock()

        with patch.object(scraper, '_dismiss_popups', AsyncMock()):
            with patch.object(scraper, '_optimize_chart_view', AsyncMock()):
                await scraper._load_chart()
                assert scraper.chart_loaded is True


@pytest.mark.asyncio
class TestScreenshotCapture:
    """Test screenshot capture"""

    async def test_capture_chart_screenshot_success(self, tmp_path):
        scraper = TradingViewScraper("test")
        scraper.chart_loaded = True
        scraper.browser = AsyncMock()

        screenshot_path = tmp_path / "chart.jpg"
        scraper.browser.take_screenshot = AsyncMock(return_value=str(screenshot_path))

        # Create dummy image for processing
        img = Image.new('RGB', (800, 600), color='blue')
        img.save(screenshot_path, "JPEG")

        with patch('tradingview_scraper.SCREENSHOTS_DIR', tmp_path):
            with patch.object(scraper, '_process_image', AsyncMock(return_value=screenshot_path)):
                result = await scraper.capture_chart_screenshot()
                assert result is not None

    async def test_capture_chart_screenshot_not_loaded(self):
        scraper = TradingViewScraper("test")
        scraper.chart_loaded = False

        result = await scraper.capture_chart_screenshot()
        assert result is None


@pytest.mark.asyncio
class TestImageProcessing:
    """Test image processing"""

    async def test_process_image(self, tmp_path):
        scraper = TradingViewScraper("test")

        # Create test image
        test_image = tmp_path / "test.jpg"
        img = Image.new('RGB', (2000, 1500), color='red')
        img.save(test_image, "JPEG")

        with patch('tradingview_scraper.IMAGE_CONFIG', {
            "max_size": (1200, 800),
            "quality": 85,
            "format": "JPEG"
        }):
            result = await scraper._process_image(test_image)
            assert result.exists()

    def test_enhance_image(self):
        scraper = TradingViewScraper("test")
        img = Image.new('RGB', (100, 100), color='blue')

        enhanced = scraper._enhance_image(img)
        assert enhanced is not None
        assert enhanced.mode == 'RGB'


@pytest.mark.asyncio
class TestCleanup:
    """Test cleanup"""

    async def test_cleanup_old_screenshots(self, tmp_path):
        scraper = TradingViewScraper("test")

        # Create 60 test screenshots
        for i in range(60):
            (tmp_path / f"xauusd_chart_{i}.jpg").write_text("test")

        with patch('tradingview_scraper.SCREENSHOTS_DIR', tmp_path):
            await scraper.cleanup_old_screenshots(max_files=50)

            remaining = list(tmp_path.glob("xauusd_chart_*.jpg"))
            assert len(remaining) <= 50


if __name__ == "__main__":
    pytest.main([__file__, "-v", "--tb=short"])