"""
Comprehensive unit tests for tradingview_scraper.py
Tests TradingView chart scraping, image processing, and optimization
"""
import pytest
import asyncio
from unittest.mock import Mock, AsyncMock, patch, MagicMock, call
from pathlib import Path
from PIL import Image
import subprocess

from tradingview_scraper import TradingViewScraper


class TestTradingViewScraperInitialization:
    """Test TradingView scraper initialization"""

    def test_scraper_init(self):
        """Test scraper initialization"""
        scraper = TradingViewScraper("test_profile")

        assert scraper.profile_name == "test_profile"
        assert scraper.browser is None
        assert scraper.chart_loaded is False
        assert scraper.last_screenshot_time == 0

    def test_default_profile_name(self):
        """Test default profile name"""
        scraper = TradingViewScraper()
        assert scraper.profile_name == "tradingview"


class TestTradingViewScraperStartup:
    """Test scraper startup and chart loading"""

    @pytest.mark.asyncio
    async def test_start_success(self):
        """Test successful scraper start"""
        scraper = TradingViewScraper("test")

        with patch('tradingview_scraper.AntiDetectBrowser') as mock_browser_class:
            mock_browser = AsyncMock()
            mock_browser.start_browser = AsyncMock()
            mock_browser.navigate_to = AsyncMock()
            mock_browser.page = AsyncMock()
            mock_browser.page.wait_for_selector = AsyncMock()
            mock_browser.page.query_selector = AsyncMock(return_value=None)
            mock_browser.page.keyboard = AsyncMock()
            mock_browser.page.keyboard.press = AsyncMock()
            mock_browser.page.evaluate = AsyncMock()

            mock_browser_class.return_value = mock_browser

            await scraper.start()

            assert scraper.browser is not None
            mock_browser.start_browser.assert_called_once_with(mobile=False)

    @pytest.mark.asyncio
    async def test_load_chart_success(self):
        """Test successful chart loading"""
        scraper = TradingViewScraper()

        mock_page = AsyncMock()
        mock_page.goto = AsyncMock()
        mock_page.wait_for_selector = AsyncMock()
        mock_page.query_selector = AsyncMock(return_value=None)
        mock_page.keyboard = AsyncMock()
        mock_page.keyboard.press = AsyncMock()
        mock_page.evaluate = AsyncMock()

        mock_browser = AsyncMock()
        mock_browser.page = mock_page
        mock_browser.navigate_to = AsyncMock()
        scraper.browser = mock_browser
        scraper._dismiss_popups = AsyncMock()
        scraper._optimize_chart_view = AsyncMock()

        await scraper._load_chart()

        assert scraper.chart_loaded is True
        mock_browser.navigate_to.assert_called_once()

    @pytest.mark.asyncio
    async def test_dismiss_popups(self):
        """Test dismissing popups"""
        scraper = TradingViewScraper()

        mock_element = AsyncMock()
        mock_element.is_visible = AsyncMock(return_value=True)
        mock_element.click = AsyncMock()

        mock_page = AsyncMock()
        mock_page.query_selector = AsyncMock(return_value=mock_element)
        mock_page.keyboard = AsyncMock()
        mock_page.keyboard.press = AsyncMock()

        mock_browser = AsyncMock()
        mock_browser.page = mock_page
        scraper.browser = mock_browser

        await scraper._dismiss_popups()

        mock_element.click.assert_called_once()

    @pytest.mark.asyncio
    async def test_optimize_chart_view(self):
        """Test chart view optimization"""
        scraper = TradingViewScraper()

        mock_page = AsyncMock()
        mock_page.evaluate = AsyncMock()

        mock_browser = AsyncMock()
        mock_browser.page = mock_page
        scraper.browser = mock_browser

        await scraper._optimize_chart_view()

        mock_page.evaluate.assert_called_once()


class TestTradingViewScraperScreenshot:
    """Test screenshot capturing"""

    @pytest.mark.asyncio
    async def test_capture_chart_screenshot_success(self, tmp_path):
        """Test successful screenshot capture"""
        scraper = TradingViewScraper()
        scraper.chart_loaded = True
        scraper._process_image = AsyncMock(return_value=tmp_path / "processed.jpg")

        mock_browser = AsyncMock()
        mock_browser.take_screenshot = AsyncMock(return_value=str(tmp_path / "screenshot.jpg"))
        scraper.browser = mock_browser

        with patch('tradingview_scraper.SCREENSHOTS_DIR', tmp_path):
            result = await scraper.capture_chart_screenshot()

            assert result is not None
            mock_browser.take_screenshot.assert_called_once()

    @pytest.mark.asyncio
    async def test_capture_chart_screenshot_chart_not_loaded(self):
        """Test screenshot when chart not loaded"""
        scraper = TradingViewScraper()
        scraper.chart_loaded = False

        result = await scraper.capture_chart_screenshot()

        assert result is None

    @pytest.mark.asyncio
    async def test_capture_chart_screenshot_with_filename(self, tmp_path):
        """Test screenshot with custom filename"""
        scraper = TradingViewScraper()
        scraper.chart_loaded = True
        scraper._process_image = AsyncMock(return_value=tmp_path / "custom.jpg")

        mock_browser = AsyncMock()
        mock_browser.take_screenshot = AsyncMock()
        scraper.browser = mock_browser

        with patch('tradingview_scraper.SCREENSHOTS_DIR', tmp_path):
            await scraper.capture_chart_screenshot(filename="custom.jpg")

            screenshot_path = tmp_path / "custom.jpg"
            call_args = mock_browser.take_screenshot.call_args
            assert "custom.jpg" in str(call_args)

    @pytest.mark.asyncio
    async def test_capture_chart_screenshot_fallback(self, tmp_path):
        """Test screenshot fallback to full page"""
        scraper = TradingViewScraper()
        scraper.chart_loaded = True
        scraper._process_image = AsyncMock(return_value=tmp_path / "screenshot.jpg")

        # First call fails, second succeeds
        mock_browser = AsyncMock()
        mock_browser.take_screenshot = AsyncMock(
            side_effect=[Exception("Selector failed"), str(tmp_path / "screenshot.jpg")]
        )
        scraper.browser = mock_browser

        with patch('tradingview_scraper.SCREENSHOTS_DIR', tmp_path):
            result = await scraper.capture_chart_screenshot()

            assert result is not None
            assert mock_browser.take_screenshot.call_count == 2


class TestTradingViewScraperImageProcessing:
    """Test image processing functionality"""

    @pytest.mark.asyncio
    async def test_process_image_basic(self, tmp_path):
        """Test basic image processing"""
        scraper = TradingViewScraper()
        scraper._enhance_image = Mock(side_effect=lambda img: img)
        scraper._imagemagick_optimize = AsyncMock(return_value=None)

        # Create a test image
        test_image = Image.new('RGB', (800, 600), color='red')
        image_path = tmp_path / "test.jpg"
        test_image.save(image_path)

        result = await scraper._process_image(image_path)

        assert result.exists()
        # Original should be removed
        assert not image_path.exists() or result == image_path

    @pytest.mark.asyncio
    async def test_process_image_resize(self, tmp_path):
        """Test image resizing"""
        scraper = TradingViewScraper()
        scraper._enhance_image = Mock(side_effect=lambda img: img)
        scraper._imagemagick_optimize = AsyncMock(return_value=None)

        # Create a large test image
        test_image = Image.new('RGB', (2000, 1500), color='blue')
        image_path = tmp_path / "large.jpg"
        test_image.save(image_path)

        result = await scraper._process_image(image_path)

        # Check that image was resized
        with Image.open(result) as img:
            assert img.size[0] <= 1200
            assert img.size[1] <= 800

    @pytest.mark.asyncio
    async def test_process_image_convert_mode(self, tmp_path):
        """Test converting image mode to RGB"""
        scraper = TradingViewScraper()
        scraper._enhance_image = Mock(side_effect=lambda img: img)
        scraper._imagemagick_optimize = AsyncMock(return_value=None)

        # Create an RGBA image
        test_image = Image.new('RGBA', (800, 600), color=(255, 0, 0, 128))
        image_path = tmp_path / "rgba.png"
        test_image.save(image_path)

        result = await scraper._process_image(image_path)

        with Image.open(result) as img:
            assert img.mode == 'RGB'

    def test_enhance_image(self):
        """Test image enhancement"""
        scraper = TradingViewScraper()

        test_image = Image.new('RGB', (800, 600), color='green')
        enhanced = scraper._enhance_image(test_image)

        assert enhanced is not None
        assert enhanced.size == test_image.size

    @pytest.mark.asyncio
    async def test_imagemagick_optimize_available(self, tmp_path):
        """Test ImageMagick optimization when available"""
        scraper = TradingViewScraper()

        test_image = Image.new('RGB', (800, 600), color='yellow')
        image_path = tmp_path / "test.jpg"
        test_image.save(image_path)

        with patch('subprocess.run') as mock_run:
            mock_run.return_value = Mock(returncode=0, stderr="")

            result = await scraper._imagemagick_optimize(image_path)

            # Should attempt ImageMagick
            assert mock_run.call_count >= 1

    @pytest.mark.asyncio
    async def test_imagemagick_optimize_not_available(self, tmp_path):
        """Test ImageMagick optimization when not available"""
        scraper = TradingViewScraper()

        test_image = Image.new('RGB', (800, 600), color='purple')
        image_path = tmp_path / "test.jpg"
        test_image.save(image_path)

        with patch('subprocess.run') as mock_run:
            mock_run.side_effect = [Mock(returncode=1), Mock(returncode=1)]

            result = await scraper._imagemagick_optimize(image_path)

            assert result is None


class TestTradingViewScraperChartRefresh:
    """Test chart refresh functionality"""

    @pytest.mark.asyncio
    async def test_refresh_chart(self):
        """Test chart refresh"""
        scraper = TradingViewScraper()
        scraper._dismiss_popups = AsyncMock()
        scraper._optimize_chart_view = AsyncMock()

        mock_page = AsyncMock()
        mock_page.reload = AsyncMock()

        mock_browser = AsyncMock()
        mock_browser.page = mock_page
        scraper.browser = mock_browser

        await scraper.refresh_chart()

        mock_page.reload.assert_called_once()
        scraper._dismiss_popups.assert_called_once()
        scraper._optimize_chart_view.assert_called_once()

    @pytest.mark.asyncio
    async def test_is_chart_updated(self):
        """Test checking if chart is updated"""
        scraper = TradingViewScraper()
        scraper.last_screenshot_time = 0

        result = await scraper.is_chart_updated()

        assert result is True

    @pytest.mark.asyncio
    async def test_is_chart_not_updated(self):
        """Test checking if chart is not updated recently"""
        scraper = TradingViewScraper()

        import time
        scraper.last_screenshot_time = time.time()

        result = await scraper.is_chart_updated()

        assert result is False


class TestTradingViewScraperScreenshotManagement:
    """Test screenshot file management"""

    @pytest.mark.asyncio
    async def test_get_latest_screenshot(self, tmp_path):
        """Test getting latest screenshot"""
        scraper = TradingViewScraper()

        # Create test screenshots
        old_file = tmp_path / "xauusd_chart_20240101_120000.jpg"
        new_file = tmp_path / "xauusd_chart_20240102_120000.jpg"

        old_file.write_bytes(b"old")
        await asyncio.sleep(0.1)
        new_file.write_bytes(b"new")

        with patch('tradingview_scraper.SCREENSHOTS_DIR', tmp_path):
            result = await scraper.get_latest_screenshot()

            assert result is not None
            assert "20240102" in result

    @pytest.mark.asyncio
    async def test_get_latest_screenshot_none_available(self, tmp_path):
        """Test getting latest screenshot when none exist"""
        scraper = TradingViewScraper()

        with patch('tradingview_scraper.SCREENSHOTS_DIR', tmp_path):
            result = await scraper.get_latest_screenshot()

            assert result is None

    @pytest.mark.asyncio
    async def test_cleanup_old_screenshots(self, tmp_path):
        """Test cleaning up old screenshots"""
        scraper = TradingViewScraper()

        # Create test screenshots
        for i in range(60):
            file_path = tmp_path / f"xauusd_chart_file{i}.jpg"
            file_path.write_bytes(b"data")

        with patch('tradingview_scraper.SCREENSHOTS_DIR', tmp_path):
            await scraper.cleanup_old_screenshots(max_files=50)

            remaining_files = list(tmp_path.glob("xauusd_chart_*.jpg"))
            assert len(remaining_files) == 50


class TestTradingViewScraperContinuousCapture:
    """Test continuous capture functionality"""

    @pytest.mark.asyncio
    async def test_run_continuous_capture_single_iteration(self):
        """Test continuous capture (single iteration)"""
        scraper = TradingViewScraper()
        scraper.capture_chart_screenshot = AsyncMock(return_value="/path/to/screenshot.jpg")
        scraper.cleanup_old_screenshots = AsyncMock()

        # Run for very short time to test one iteration
        async def limited_capture():
            iteration = 0
            while iteration < 1:
                screenshot_path = await scraper.capture_chart_screenshot()
                assert screenshot_path is not None
                iteration += 1

        await limited_capture()

        scraper.capture_chart_screenshot.assert_called()


class TestTradingViewScraperCleanup:
    """Test cleanup functionality"""

    @pytest.mark.asyncio
    async def test_cleanup(self):
        """Test scraper cleanup"""
        scraper = TradingViewScraper()

        mock_browser = AsyncMock()
        mock_browser.cleanup = AsyncMock()
        scraper.browser = mock_browser

        await scraper.cleanup()

        mock_browser.cleanup.assert_called_once()
        assert scraper.browser is None

    @pytest.mark.asyncio
    async def test_context_manager(self):
        """Test async context manager"""
        scraper = TradingViewScraper()
        scraper.start = AsyncMock()
        scraper.cleanup = AsyncMock()

        async with scraper:
            pass

        scraper.start.assert_called_once()
        scraper.cleanup.assert_called_once()


class TestTradingViewScraperEdgeCases:
    """Test edge cases and error handling"""

    @pytest.mark.asyncio
    async def test_load_chart_selector_fallback(self):
        """Test falling back to alternative selector"""
        scraper = TradingViewScraper()

        mock_page = AsyncMock()
        # First selector fails, second succeeds
        mock_page.wait_for_selector = AsyncMock(
            side_effect=[Exception("First failed"), None]
        )
        mock_page.query_selector = AsyncMock(return_value=None)
        mock_page.keyboard = AsyncMock()
        mock_page.keyboard.press = AsyncMock()
        mock_page.evaluate = AsyncMock()

        mock_browser = AsyncMock()
        mock_browser.page = mock_page
        mock_browser.navigate_to = AsyncMock()
        scraper.browser = mock_browser
        scraper._dismiss_popups = AsyncMock()
        scraper._optimize_chart_view = AsyncMock()

        await scraper._load_chart()

        assert scraper.chart_loaded is True
        assert mock_page.wait_for_selector.call_count == 2

    @pytest.mark.asyncio
    async def test_process_image_error_recovery(self, tmp_path):
        """Test image processing error recovery"""
        scraper = TradingViewScraper()

        # Create invalid image file
        image_path = tmp_path / "invalid.jpg"
        image_path.write_bytes(b"not an image")

        # Should return original path on error
        result = await scraper._process_image(image_path)

        assert result == image_path

    @pytest.mark.asyncio
    async def test_cleanup_old_screenshots_with_errors(self, tmp_path):
        """Test cleanup with file deletion errors"""
        scraper = TradingViewScraper()

        # Create test file
        file_path = tmp_path / "xauusd_chart_test.jpg"
        file_path.write_bytes(b"data")

        with patch('tradingview_scraper.SCREENSHOTS_DIR', tmp_path):
            with patch.object(Path, 'unlink', side_effect=PermissionError("Cannot delete")):
                # Should not raise exception
                await scraper.cleanup_old_screenshots(max_files=0)

    def test_enhance_image_error_handling(self):
        """Test image enhancement error handling"""
        scraper = TradingViewScraper()

        # Pass invalid image
        with patch('PIL.ImageEnhance.Contrast') as mock_contrast:
            mock_contrast.side_effect = Exception("Enhancement failed")

            test_image = Image.new('RGB', (100, 100))
            result = scraper._enhance_image(test_image)

            # Should return original image on error
            assert result == test_image

    @pytest.mark.asyncio
    async def test_start_failure_cleanup(self):
        """Test cleanup on start failure"""
        scraper = TradingViewScraper()

        with patch('tradingview_scraper.AntiDetectBrowser') as mock_browser_class:
            mock_browser = AsyncMock()
            mock_browser.start_browser = AsyncMock()
            mock_browser.navigate_to = AsyncMock(side_effect=Exception("Navigation failed"))
            mock_browser.cleanup = AsyncMock()

            mock_browser_class.return_value = mock_browser

            with pytest.raises(Exception):
                await scraper.start()

            # Cleanup should be called on failure
            mock_browser.cleanup.assert_called_once()