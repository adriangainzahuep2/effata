"""
Comprehensive unit tests for utils.py
Tests utility functions for system checks, file management, and helpers
"""
import pytest
import asyncio
from pathlib import Path
from unittest.mock import Mock, AsyncMock, patch, MagicMock
import json

from utils import (
    install_playwright_browsers, check_imagemagick, create_directory_structure,
    check_system_resources, compress_image, cleanup_temp_files,
    TempFileManager, PerformanceMonitor
)


@pytest.mark.asyncio
class TestPlaywrightInstallation:
    """Test Playwright installation"""

    async def test_install_playwright_browsers_success(self):
        with patch('subprocess.run') as mock_run:
            mock_run.return_value = MagicMock(returncode=0, stdout="", stderr="")
            result = await install_playwright_browsers()
            assert result is True

    async def test_install_playwright_browsers_failure(self):
        with patch('subprocess.run') as mock_run:
            mock_run.return_value = MagicMock(returncode=1, stdout="", stderr="Error")
            result = await install_playwright_browsers()
            assert result is False


@pytest.mark.asyncio
class TestImageMagickCheck:
    """Test ImageMagick check"""

    async def test_check_imagemagick_available(self):
        with patch('subprocess.run') as mock_run:
            mock_run.return_value = MagicMock(returncode=0)
            result = await check_imagemagick()
            assert result is True

    async def test_check_imagemagick_not_available(self):
        with patch('subprocess.run') as mock_run:
            mock_run.return_value = MagicMock(returncode=1)
            result = await check_imagemagick()
            assert result is False


def test_create_directory_structure(tmp_path):
    """Test directory structure creation"""
    with patch('utils.OUTPUT_DIR', tmp_path / "outputs"):
        with patch('utils.SCREENSHOTS_DIR', tmp_path / "screenshots"):
            with patch('utils.RESPONSES_DIR', tmp_path / "responses"):
                with patch('utils.LOGS_DIR', tmp_path / "logs"):
                    result = create_directory_structure()
                    assert result is True


def test_check_system_resources():
    """Test system resource checking"""
    with patch('utils.psutil') as mock_psutil:
        mock_psutil.virtual_memory.return_value = MagicMock(available=4*1024**3)
        mock_psutil.disk_usage.return_value = MagicMock(free=10*1024**3)
        mock_psutil.cpu_count.return_value = 4

        resources = check_system_resources()
        assert resources["sufficient"] is True
        assert resources["cpu_cores"] == 4


@pytest.mark.asyncio
class TestImageCompression:
    """Test image compression"""

    async def test_compress_image(self, tmp_path):
        from PIL import Image

        # Create test image
        test_image = tmp_path / "test.jpg"
        img = Image.new('RGB', (1500, 1000), color='green')
        img.save(test_image, "JPEG")

        result = await compress_image(str(test_image), quality=85)
        assert result is not None
        assert Path(result).exists()

    async def test_compress_image_nonexistent(self):
        result = await compress_image("/nonexistent/image.jpg")
        assert result is None


@pytest.mark.asyncio
class TestTempFileCleanup:
    """Test temporary file cleanup"""

    async def test_cleanup_temp_files(self, tmp_path):
        from datetime import datetime, timedelta

        # Create old and new files
        old_file = tmp_path / "old.txt"
        old_file.write_text("old")

        # Modify file time to be old
        old_time = (datetime.now() - timedelta(hours=48)).timestamp()
        import os
        os.utime(old_file, (old_time, old_time))

        new_file = tmp_path / "new.txt"
        new_file.write_text("new")

        await cleanup_temp_files(str(tmp_path), max_age_hours=24)

        assert not old_file.exists()
        assert new_file.exists()


class TestTempFileManager:
    """Test temporary file manager"""

    @pytest.mark.asyncio
    async def test_temp_file_manager(self, tmp_path):
        async with TempFileManager(str(tmp_path)) as manager:
            temp_file = manager.create_temp_file(".txt")
            temp_file.write_text("test")
            assert temp_file.exists()

        # File should be cleaned up after exit
        assert not temp_file.exists()


class TestPerformanceMonitor:
    """Test performance monitor"""

    def test_performance_monitor(self):
        monitor = PerformanceMonitor("test")
        monitor.start()

        import time
        time.sleep(0.1)

        duration = monitor.stop("test_operation")
        assert duration >= 0.1

        summary = monitor.get_summary()
        assert summary["total_operations"] == 1
        assert summary["total_time"] >= 0.1


if __name__ == "__main__":
    pytest.main([__file__, "-v", "--tb=short"])