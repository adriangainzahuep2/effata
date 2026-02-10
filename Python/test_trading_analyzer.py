"""
Comprehensive unit tests for trading_analyzer.py
Tests the main orchestrator combining TradingView and LMArena scrapers
"""
import pytest
import asyncio
from unittest.mock import Mock, AsyncMock, patch, MagicMock
from pathlib import Path
from datetime import datetime, timedelta
import json

from trading_analyzer import TradingAnalyzer


class TestTradingAnalyzerInitialization:
    """Test trading analyzer initialization"""

    def test_analyzer_init(self):
        """Test analyzer initialization"""
        analyzer = TradingAnalyzer()

        assert analyzer.tv_scraper is None
        assert analyzer.lm_scraper is None
        assert analyzer.running is False
        assert isinstance(analyzer.analysis_results, list)

    @pytest.mark.asyncio
    async def test_initialize_success(self):
        """Test successful initialization"""
        analyzer = TradingAnalyzer()

        with patch('trading_analyzer.TradingViewScraper') as mock_tv_class, \
             patch('trading_analyzer.LMArenaScaper') as mock_lm_class:

            mock_tv = AsyncMock()
            mock_tv.start = AsyncMock()
            mock_tv_class.return_value = mock_tv

            mock_lm = AsyncMock()
            mock_lm.start = AsyncMock()
            mock_lm_class.return_value = mock_lm

            await analyzer.initialize()

            assert analyzer.tv_scraper is not None
            assert analyzer.lm_scraper is not None
            mock_tv.start.assert_called_once()
            mock_lm.start.assert_called_once()

    @pytest.mark.asyncio
    async def test_initialize_failure_cleanup(self):
        """Test cleanup on initialization failure"""
        analyzer = TradingAnalyzer()
        analyzer.cleanup = AsyncMock()

        with patch('trading_analyzer.TradingViewScraper') as mock_tv_class:
            mock_tv_class.side_effect = Exception("Init failed")

            with pytest.raises(Exception):
                await analyzer.initialize()

            analyzer.cleanup.assert_called_once()


class TestTradingAnalyzerCaptureAndAnalyze:
    """Test capture and analyze functionality"""

    @pytest.mark.asyncio
    async def test_capture_and_analyze_success(self, tmp_path):
        """Test successful capture and analysis"""
        analyzer = TradingAnalyzer()
        analyzer._save_analysis_session = AsyncMock()

        mock_tv = AsyncMock()
        mock_tv.capture_chart_screenshot = AsyncMock(
            return_value=str(tmp_path / "chart.jpg")
        )
        analyzer.tv_scraper = mock_tv

        mock_lm = AsyncMock()
        mock_lm.analyze_chart = AsyncMock(return_value={
            "success": True,
            "model": "gpt-4",
            "response": "Test analysis"
        })
        analyzer.lm_scraper = mock_lm

        result = await analyzer.capture_and_analyze(["gpt-4"])

        assert result["success"] is True
        assert result["models_tested"] == 1
        assert len(result["analyses"]) == 1

    @pytest.mark.asyncio
    async def test_capture_and_analyze_screenshot_failure(self):
        """Test analysis when screenshot fails"""
        analyzer = TradingAnalyzer()

        mock_tv = AsyncMock()
        mock_tv.capture_chart_screenshot = AsyncMock(return_value=None)
        analyzer.tv_scraper = mock_tv

        result = await analyzer.capture_and_analyze()

        assert result["success"] is False
        assert "error" in result

    @pytest.mark.asyncio
    async def test_capture_and_analyze_multiple_models(self, tmp_path):
        """Test analyzing with multiple models"""
        analyzer = TradingAnalyzer()
        analyzer._save_analysis_session = AsyncMock()

        mock_tv = AsyncMock()
        mock_tv.capture_chart_screenshot = AsyncMock(
            return_value=str(tmp_path / "chart.jpg")
        )
        analyzer.tv_scraper = mock_tv

        mock_lm = AsyncMock()
        mock_lm.analyze_chart = AsyncMock(side_effect=[
            {"success": True, "model": "gpt-4"},
            {"success": True, "model": "claude"},
            {"success": False, "model": "failed-model"}
        ])
        analyzer.lm_scraper = mock_lm

        result = await analyzer.capture_and_analyze(["gpt-4", "claude", "failed-model"])

        assert result["models_tested"] == 2
        assert result["total_models"] == 3


class TestTradingAnalyzerContinuous:
    """Test continuous analysis"""

    @pytest.mark.asyncio
    async def test_run_continuous_analysis_single_cycle(self):
        """Test single cycle of continuous analysis"""
        analyzer = TradingAnalyzer()
        analyzer.running = True
        analyzer.capture_and_analyze = AsyncMock(return_value={"success": True, "models_tested": 1})
        analyzer._cleanup_old_files = AsyncMock()

        # Run single iteration
        async def limited_run():
            result = await analyzer.capture_and_analyze()
            assert result["success"] is True

        await limited_run()

    @pytest.mark.asyncio
    async def test_cleanup_old_files(self, tmp_path):
        """Test cleanup of old files"""
        analyzer = TradingAnalyzer()

        mock_tv = AsyncMock()
        mock_tv.cleanup_old_screenshots = AsyncMock()
        analyzer.tv_scraper = mock_tv

        # Create test response files
        with patch('trading_analyzer.RESPONSES_DIR', tmp_path):
            for i in range(60):
                (tmp_path / f"response_{i}.txt").write_text("test")

            await analyzer._cleanup_old_files()

            remaining = list(tmp_path.glob("*.txt"))
            assert len(remaining) <= 50


class TestTradingAnalyzerSingleTests:
    """Test single analysis and model testing"""

    @pytest.mark.asyncio
    async def test_test_single_analysis(self, tmp_path):
        """Test single analysis"""
        analyzer = TradingAnalyzer()
        analyzer.capture_and_analyze = AsyncMock(return_value={
            "success": True,
            "models_tested": 1
        })

        result = await analyzer.test_single_analysis("gpt-4")

        assert result["success"] is True
        analyzer.capture_and_analyze.assert_called_once()

    @pytest.mark.asyncio
    async def test_test_multiple_models(self):
        """Test multiple model testing"""
        analyzer = TradingAnalyzer()
        analyzer.capture_and_analyze = AsyncMock(return_value={
            "success": True,
            "models_tested": 3,
            "total_models": 3
        })

        result = await analyzer.test_multiple_models(["gpt-4", "claude", "gemini"])

        assert result["models_tested"] == 3


class TestTradingAnalyzerScheduling:
    """Test scheduled analysis"""

    def test_setup_scheduled_analysis(self):
        """Test setting up scheduled analysis"""
        analyzer = TradingAnalyzer()

        with patch('trading_analyzer.schedule') as mock_schedule, \
             patch('trading_analyzer.threading.Thread') as mock_thread:

            analyzer.setup_scheduled_analysis(interval_minutes=15)

            mock_schedule.clear.assert_called_once()
            mock_thread.assert_called()


class TestTradingAnalyzerSummary:
    """Test analysis summary and export"""

    @pytest.mark.asyncio
    async def test_get_analysis_summary(self):
        """Test getting analysis summary"""
        analyzer = TradingAnalyzer()

        # Add test results
        analyzer.analysis_results = [
            {
                "timestamp": datetime.now().isoformat(),
                "success": True,
                "analyses": [{"model": "gpt-4"}]
            },
            {
                "timestamp": datetime.now().isoformat(),
                "success": False
            }
        ]

        summary = await analyzer.get_analysis_summary(hours=24)

        assert summary["total_analyses"] == 2
        assert summary["successful_analyses"] == 1

    @pytest.mark.asyncio
    async def test_export_results(self, tmp_path):
        """Test exporting results"""
        analyzer = TradingAnalyzer()
        analyzer.analysis_results = [
            {"timestamp": datetime.now().isoformat(), "success": True}
        ]

        with patch('trading_analyzer.OUTPUT_DIR', tmp_path):
            output_file = await analyzer.export_results()

            assert output_file != ""
            assert Path(output_file).exists()

            # Verify JSON content
            with open(output_file) as f:
                data = json.load(f)
                assert "results" in data
                assert len(data["results"]) == 1


class TestTradingAnalyzerCleanup:
    """Test cleanup and stop functionality"""

    @pytest.mark.asyncio
    async def test_stop(self):
        """Test stopping analyzer"""
        analyzer = TradingAnalyzer()
        analyzer.running = True

        with patch('trading_analyzer.schedule') as mock_schedule:
            await analyzer.stop()

            assert analyzer.running is False
            mock_schedule.clear.assert_called_once()

    @pytest.mark.asyncio
    async def test_cleanup(self):
        """Test cleanup"""
        analyzer = TradingAnalyzer()

        mock_tv = AsyncMock()
        mock_tv.cleanup = AsyncMock()
        analyzer.tv_scraper = mock_tv

        mock_lm = AsyncMock()
        mock_lm.cleanup = AsyncMock()
        analyzer.lm_scraper = mock_lm

        await analyzer.cleanup()

        mock_tv.cleanup.assert_called_once()
        mock_lm.cleanup.assert_called_once()
        assert analyzer.tv_scraper is None
        assert analyzer.lm_scraper is None

    @pytest.mark.asyncio
    async def test_context_manager(self):
        """Test async context manager"""
        analyzer = TradingAnalyzer()
        analyzer.initialize = AsyncMock()
        analyzer.cleanup = AsyncMock()

        async with analyzer:
            pass

        analyzer.initialize.assert_called_once()
        analyzer.cleanup.assert_called_once()