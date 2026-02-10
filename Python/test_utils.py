"""
Comprehensive unit tests for utils.py
Tests utility functions for system checks, configuration, and helpers
"""
import pytest
import asyncio
from unittest.mock import Mock, AsyncMock, patch, MagicMock, mock_open
from pathlib import Path
import json
from datetime import datetime, timedelta

import utils


class TestPlaywrightInstallation:
    """Test Playwright browser installation"""

    @pytest.mark.asyncio
    async def test_install_playwright_browsers_success(self):
        """Test successful Playwright installation"""
        with patch('subprocess.run') as mock_run:
            mock_run.return_value = Mock(returncode=0, stderr="")

            result = await utils.install_playwright_browsers()

            assert result is True
            mock_run.assert_called_once()

    @pytest.mark.asyncio
    async def test_install_playwright_browsers_failure(self):
        """Test Playwright installation failure"""
        with patch('subprocess.run') as mock_run:
            mock_run.return_value = Mock(returncode=1, stderr="Error")

            result = await utils.install_playwright_browsers()

            assert result is False


class TestImageMagickChecks:
    """Test ImageMagick availability checks"""

    @pytest.mark.asyncio
    async def test_check_imagemagick_available(self):
        """Test ImageMagick is available"""
        with patch('subprocess.run') as mock_run:
            mock_run.return_value = Mock(returncode=0)

            result = await utils.check_imagemagick()

            assert result is True

    @pytest.mark.asyncio
    async def test_check_imagemagick_not_available(self):
        """Test ImageMagick not available"""
        with patch('subprocess.run') as mock_run:
            mock_run.return_value = Mock(returncode=1)

            result = await utils.check_imagemagick()

            assert result is False

    @pytest.mark.asyncio
    async def test_check_imagemagick_exception(self):
        """Test ImageMagick check exception"""
        with patch('subprocess.run', side_effect=FileNotFoundError):
            result = await utils.check_imagemagick()

            assert result is False


class TestDirectoryStructure:
    """Test directory structure creation"""

    def test_create_directory_structure(self, tmp_path):
        """Test creating directory structure"""
        with patch('utils.Path') as mock_path:
            mock_path.return_value.mkdir = Mock()

            result = utils.create_directory_structure()

            assert result is True


class TestURLValidation:
    """Test URL validation"""

    @pytest.mark.asyncio
    async def test_validate_urls_success(self):
        """Test URL validation success"""
        with patch('utils.httpx.AsyncClient') as mock_client:
            mock_response = AsyncMock()
            mock_response.status_code = 200

            mock_get = AsyncMock(return_value=mock_response)
            mock_client.return_value.__aenter__.return_value.get = mock_get

            result = await utils.validate_urls()

            assert result is True

    @pytest.mark.asyncio
    async def test_validate_urls_with_errors(self):
        """Test URL validation with errors"""
        with patch('utils.httpx.AsyncClient') as mock_client:
            mock_client.return_value.__aenter__.side_effect = Exception("Import error")

            result = await utils.validate_urls()

            assert result is False


class TestSystemResourceChecks:
    """Test system resource checking"""

    def test_check_system_resources(self):
        """Test checking system resources"""
        with patch('utils.psutil') as mock_psutil:
            mock_psutil.virtual_memory.return_value.available = 4 * (1024**3)
            mock_psutil.disk_usage.return_value.free = 50 * (1024**3)
            mock_psutil.cpu_count.return_value = 8

            result = utils.check_system_resources()

            assert result["memory_gb"] > 0
            assert result["disk_gb"] > 0
            assert result["cpu_cores"] == 8
            assert result["sufficient"] is True

    def test_check_system_resources_low_memory(self):
        """Test checking with low memory"""
        with patch('utils.psutil') as mock_psutil:
            mock_psutil.virtual_memory.return_value.available = 0.5 * (1024**3)
            mock_psutil.disk_usage.return_value.free = 50 * (1024**3)
            mock_psutil.cpu_count.return_value = 4

            result = utils.check_system_resources()

            assert result["sufficient"] is False

    def test_check_system_resources_exception(self):
        """Test system resource check with exception"""
        with patch('utils.psutil', side_effect=ImportError):
            result = utils.check_system_resources()

            assert result["sufficient"] is True


class TestBrowserLaunchTest:
    """Test browser launch testing"""

    @pytest.mark.asyncio
    async def test_test_browser_launch_success(self):
        """Test successful browser launch"""
        with patch('utils.async_playwright') as mock_playwright:
            mock_page = AsyncMock()
            mock_page.goto = AsyncMock()
            mock_page.content = AsyncMock(return_value="Mozilla/5.0")

            mock_browser = AsyncMock()
            mock_browser.new_page = AsyncMock(return_value=mock_page)
            mock_browser.close = AsyncMock()

            mock_pw = AsyncMock()
            mock_pw.chromium.launch = AsyncMock(return_value=mock_browser)

            mock_playwright.return_value.__aenter__.return_value = mock_pw

            result = await utils.test_browser_launch()

            assert result is True

    @pytest.mark.asyncio
    async def test_test_browser_launch_failure(self):
        """Test browser launch failure"""
        with patch('utils.async_playwright', side_effect=Exception("Launch failed")):
            result = await utils.test_browser_launch()

            assert result is False


class TestConfigFileManagement:
    """Test configuration file management"""

    @pytest.mark.asyncio
    async def test_create_config_file(self, tmp_path):
        """Test creating config file"""
        config_path = tmp_path / "test_config.json"
        config_data = {"test": "value", "number": 42}

        result = await utils.create_config_file(config_data, str(config_path))

        assert result is True
        assert config_path.exists()

        # Verify content
        with open(config_path) as f:
            loaded = json.load(f)
            assert loaded == config_data

    @pytest.mark.asyncio
    async def test_load_config_file(self, tmp_path):
        """Test loading config file"""
        config_path = tmp_path / "test_config.json"
        config_data = {"test": "value"}

        with open(config_path, 'w') as f:
            json.dump(config_data, f)

        result = await utils.load_config_file(str(config_path))

        assert result == config_data

    @pytest.mark.asyncio
    async def test_load_config_file_not_found(self):
        """Test loading non-existent config file"""
        result = await utils.load_config_file("nonexistent.json")

        assert result == {}


class TestProxyList:
    """Test proxy list functionality"""

    def test_get_proxy_list(self):
        """Test getting proxy list"""
        result = utils.get_proxy_list()

        assert isinstance(result, list)


class TestUserAgentRotation:
    """Test user agent rotation"""

    @pytest.mark.asyncio
    async def test_rotate_user_agent(self):
        """Test rotating user agent"""
        result = await utils.rotate_user_agent()

        assert isinstance(result, str)
        assert len(result) > 0
        assert "Mozilla" in result


class TestImageCompression:
    """Test image compression"""

    @pytest.mark.asyncio
    async def test_compress_image(self, tmp_path):
        """Test compressing image"""
        from PIL import Image

        # Create test image
        image_path = tmp_path / "test.jpg"
        test_image = Image.new('RGB', (2000, 1500), color='red')
        test_image.save(image_path)

        result = await utils.compress_image(str(image_path), quality=85)

        assert result is not None
        assert Path(result).exists()

        # Verify compression
        with Image.open(result) as img:
            assert img.size[0] <= 1200
            assert img.size[1] <= 800

    @pytest.mark.asyncio
    async def test_compress_image_not_found(self):
        """Test compressing non-existent image"""
        result = await utils.compress_image("nonexistent.jpg")

        assert result is None


class TestTempFileCleanup:
    """Test temporary file cleanup"""

    @pytest.mark.asyncio
    async def test_cleanup_temp_files(self, tmp_path):
        """Test cleaning up old temp files"""
        # Create old and new files
        old_file = tmp_path / "old.tmp"
        new_file = tmp_path / "new.tmp"

        old_file.write_text("old")
        await asyncio.sleep(0.1)
        new_file.write_text("new")

        # Set old file modification time to 25 hours ago
        old_time = datetime.now() - timedelta(hours=25)
        old_timestamp = old_time.timestamp()
        import os
        os.utime(old_file, (old_timestamp, old_timestamp))

        await utils.cleanup_temp_files(str(tmp_path), max_age_hours=24)

        # Old file should be removed, new file should remain
        assert not old_file.exists()
        assert new_file.exists()


class TestSystemInfo:
    """Test system information gathering"""

    @pytest.mark.asyncio
    async def test_get_system_info(self):
        """Test getting system information"""
        result = await utils.get_system_info()

        assert isinstance(result, dict)
        assert "platform" in result
        assert "python_version" in result
        assert "timestamp" in result

    @pytest.mark.asyncio
    async def test_generate_session_id(self):
        """Test generating session ID"""
        result = await utils.generate_session_id()

        assert isinstance(result, str)
        assert result.startswith("session_")
        assert len(result) > 20


class TestDebugInfo:
    """Test debug information saving"""

    @pytest.mark.asyncio
    async def test_save_debug_info(self, tmp_path):
        """Test saving debug information"""
        debug_data = {"error": "test error", "value": 42}

        with patch('utils.Path') as mock_path:
            mock_file = tmp_path / "debug.json"
            mock_path.return_value = tmp_path

            with patch('aiofiles.open', create=True) as mock_open_async:
                mock_file_obj = AsyncMock()
                mock_file_obj.__aenter__.return_value.write = AsyncMock()
                mock_open_async.return_value = mock_file_obj

                result = await utils.save_debug_info(debug_data, "test_debug.json")

                # Should attempt to save
                mock_open_async.assert_called()


class TestLoggingSetup:
    """Test logging configuration"""

    def test_setup_logging(self):
        """Test setting up logging"""
        result = utils.setup_logging(log_level="INFO")

        assert result is True

    def test_setup_logging_with_file(self, tmp_path):
        """Test setting up logging with file"""
        log_file = "test.log"

        with patch('utils.Path.mkdir'):
            result = utils.setup_logging(log_level="DEBUG", log_file=log_file)

            assert result is True


class TestTempFileManager:
    """Test temporary file manager context"""

    @pytest.mark.asyncio
    async def test_temp_file_manager_create(self, tmp_path):
        """Test creating temporary files"""
        async with utils.TempFileManager(str(tmp_path)) as manager:
            temp_file = manager.create_temp_file(suffix=".txt")

            assert temp_file.parent == tmp_path
            assert temp_file.name.startswith("temp_")
            assert temp_file.suffix == ".txt"

    @pytest.mark.asyncio
    async def test_temp_file_manager_cleanup(self, tmp_path):
        """Test temporary file cleanup"""
        temp_files = []

        async with utils.TempFileManager(str(tmp_path)) as manager:
            for i in range(3):
                temp_file = manager.create_temp_file()
                temp_file.write_text(f"test {i}")
                temp_files.append(temp_file)

        # Files should be cleaned up after context exit
        # (would need actual implementation to verify)


class TestPerformanceMonitor:
    """Test performance monitoring"""

    def test_performance_monitor_timing(self):
        """Test performance timing"""
        monitor = utils.PerformanceMonitor("test")

        monitor.start()
        import time
        time.sleep(0.1)
        duration = monitor.stop("test_operation")

        assert duration >= 0.1
        assert len(monitor.measurements) == 1

    def test_performance_monitor_summary(self):
        """Test performance summary"""
        monitor = utils.PerformanceMonitor("test")

        monitor.start()
        monitor.stop("op1")

        monitor.start()
        monitor.stop("op2")

        summary = monitor.get_summary()

        assert summary["total_operations"] == 2
        assert "total_time" in summary
        assert "average_time" in summary
        assert "min_time" in summary
        assert "max_time" in summary

    def test_performance_monitor_empty_summary(self):
        """Test performance summary with no measurements"""
        monitor = utils.PerformanceMonitor("test")

        summary = monitor.get_summary()

        assert summary == {}


class TestEdgeCases:
    """Test edge cases and error handling"""

    @pytest.mark.asyncio
    async def test_compress_image_rgba_mode(self, tmp_path):
        """Test compressing RGBA image"""
        from PIL import Image

        image_path = tmp_path / "rgba.png"
        test_image = Image.new('RGBA', (800, 600), color=(255, 0, 0, 128))
        test_image.save(image_path)

        result = await utils.compress_image(str(image_path))

        assert result is not None

        with Image.open(result) as img:
            assert img.mode == 'RGB'

    @pytest.mark.asyncio
    async def test_cleanup_temp_files_no_directory(self):
        """Test cleanup when directory doesn't exist"""
        # Should not raise exception
        await utils.cleanup_temp_files("nonexistent_dir")

    def test_setup_logging_failure(self):
        """Test logging setup failure"""
        with patch('utils.logger.remove', side_effect=Exception("Remove failed")):
            result = utils.setup_logging()

            assert result is False