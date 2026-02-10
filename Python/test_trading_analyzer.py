"""
Comprehensive unit tests for trading_analyzer.py
Tests trading analysis orchestration, continuous analysis, and result management
"""
import pytest
import asyncio
from pathlib import Path
from unittest.mock import Mock, AsyncMock, patch, MagicMock
from datetime import datetime, timedelta
import json

from trading_analyzer import TradingAnalyzer


class TestTradingAnalyzerInit:
    """Test TradingAnalyzer initialization"""

    def test_analyzer_initialization(self):
        """Test analyzer object creation"""
        analyzer = TradingAnalyzer()

        assert analyzer.tv_scraper is None
        assert analyzer.lm_scraper is None
        assert analyzer.running is False
        assert len(analyzer.analysis_results) == 0
        assert analyzer.scheduler_thread is None


@pytest.mark.asyncio
class TestAnalyzerInitialization:
    """Test analyzer initialization"""

    async def test_initialize_success(self):
        """Test successful initialization of both scrapers"""
        analyzer = TradingAnalyzer()

        mock_tv_scraper = AsyncMock()
        mock_lm_scraper = AsyncMock()

        with patch('trading_analyzer.TradingViewScraper', return_value=mock_tv_scraper):
            with patch('trading_analyzer.LMArenaScaper', return_value=mock_lm_scraper):
                await analyzer.initialize()

                assert analyzer.tv_scraper is not None
                assert analyzer.lm_scraper is not None
                mock_tv_scraper.start.assert_called_once()
                mock_lm_scraper.start.assert_called_once()

    async def test_initialize_failure(self):
        """Test initialization failure handling"""
        analyzer = TradingAnalyzer()

        with patch('trading_analyzer.TradingViewScraper', side_effect=Exception("Init failed")):
            with patch.object(analyzer, 'cleanup', AsyncMock()):
                with pytest.raises(Exception):
                    await analyzer.initialize()

                analyzer.cleanup.assert_called_once()


@pytest.mark.asyncio
class TestCaptureAndAnalyze:
    """Test capture and analysis workflow"""

    async def test_capture_and_analyze_single_model(self):
        """Test capture and analysis with single model"""
        analyzer = TradingAnalyzer()
        analyzer.tv_scraper = AsyncMock()
        analyzer.lm_scraper = AsyncMock()

        analyzer.tv_scraper.capture_chart_screenshot = AsyncMock(
            return_value="/tmp/screenshot.jpg"
        )
        analyzer.lm_scraper.analyze_chart = AsyncMock(
            return_value={"success": True, "model": "gpt-4", "response": "Analysis"}
        )

        with patch.object(analyzer, '_save_analysis_session', AsyncMock()):
            result = await analyzer.capture_and_analyze(models=["gpt-4"])

            assert result["success"] is True
            assert result["models_tested"] == 1
            assert len(result["analyses"]) == 1

    async def test_capture_and_analyze_multiple_models(self):
        """Test capture and analysis with multiple models"""
        analyzer = TradingAnalyzer()
        analyzer.tv_scraper = AsyncMock()
        analyzer.lm_scraper = AsyncMock()

        analyzer.tv_scraper.capture_chart_screenshot = AsyncMock(
            return_value="/tmp/screenshot.jpg"
        )
        analyzer.lm_scraper.analyze_chart = AsyncMock(
            return_value={"success": True, "response": "Analysis"}
        )

        with patch.object(analyzer, '_save_analysis_session', AsyncMock()):
            result = await analyzer.capture_and_analyze(
                models=["gpt-4", "claude", "gemini"]
            )

            assert result["models_tested"] == 3
            assert analyzer.lm_scraper.analyze_chart.call_count == 3

    async def test_capture_and_analyze_screenshot_failure(self):
        """Test handling of screenshot capture failure"""
        analyzer = TradingAnalyzer()
        analyzer.tv_scraper = AsyncMock()
        analyzer.tv_scraper.capture_chart_screenshot = AsyncMock(return_value=None)

        result = await analyzer.capture_and_analyze()

        assert result["success"] is False
        assert "error" in result

    async def test_capture_and_analyze_with_failures(self):
        """Test handling of partial model failures"""
        analyzer = TradingAnalyzer()
        analyzer.tv_scraper = AsyncMock()
        analyzer.lm_scraper = AsyncMock()

        analyzer.tv_scraper.capture_chart_screenshot = AsyncMock(
            return_value="/tmp/screenshot.jpg"
        )

        # First succeeds, second fails, third succeeds
        analyzer.lm_scraper.analyze_chart = AsyncMock(
            side_effect=[
                {"success": True, "response": "Result1"},
                {"success": False},
                {"success": True, "response": "Result2"}
            ]
        )

        with patch.object(analyzer, '_save_analysis_session', AsyncMock()):
            result = await analyzer.capture_and_analyze(
                models=["model1", "model2", "model3"]
            )

            # Only 2 successful
            assert result["models_tested"] == 2

    async def test_capture_and_analyze_custom_prompt(self):
        """Test using custom analysis prompt"""
        analyzer = TradingAnalyzer()
        analyzer.tv_scraper = AsyncMock()
        analyzer.lm_scraper = AsyncMock()

        analyzer.tv_scraper.capture_chart_screenshot = AsyncMock(
            return_value="/tmp/screenshot.jpg"
        )
        analyzer.lm_scraper.analyze_chart = AsyncMock(
            return_value={"success": True}
        )

        custom_prompt = "Analyze this chart for momentum signals"

        with patch.object(analyzer, '_save_analysis_session', AsyncMock()):
            await analyzer.capture_and_analyze(
                models=["gpt-4"],
                custom_prompt=custom_prompt
            )

            # Check that custom prompt was passed
            call_args = analyzer.lm_scraper.analyze_chart.call_args
            assert call_args.kwargs.get("custom_prompt") == custom_prompt


@pytest.mark.asyncio
class TestSessionSaving:
    """Test analysis session saving"""

    async def test_save_analysis_session(self, tmp_path):
        """Test saving analysis session to file"""
        analyzer = TradingAnalyzer()

        result = {
            "success": True,
            "timestamp": datetime.now().isoformat(),
            "analyses": [{"model": "gpt-4", "response": "Test"}]
        }

        with patch('trading_analyzer.OUTPUT_DIR', tmp_path):
            await analyzer._save_analysis_session(result)

            # Check that file was created
            session_files = list(tmp_path.glob("analysis_session_*.json"))
            assert len(session_files) == 1

            # Verify content
            with open(session_files[0], 'r') as f:
                data = json.load(f)
                assert data["success"] is True

    async def test_save_analysis_session_error(self):
        """Test error handling in session saving"""
        analyzer = TradingAnalyzer()

        with patch('trading_analyzer.OUTPUT_DIR', Path("/invalid/path")):
            with patch('builtins.open', side_effect=PermissionError()):
                # Should not raise exception
                await analyzer._save_analysis_session({"test": "data"})


@pytest.mark.asyncio
class TestContinuousAnalysis:
    """Test continuous analysis functionality"""

    async def test_run_continuous_analysis(self):
        """Test continuous analysis loop"""
        analyzer = TradingAnalyzer()
        analyzer.running = True

        call_count = 0

        async def mock_capture():
            nonlocal call_count
            call_count += 1
            if call_count >= 2:
                analyzer.running = False
            return {"success": True, "models_tested": 1}

        with patch.object(analyzer, 'capture_and_analyze', side_effect=mock_capture):
            with patch.object(analyzer, '_cleanup_old_files', AsyncMock()):
                await analyzer.run_continuous_analysis(interval_minutes=0.01)

                assert call_count >= 2

    async def test_run_continuous_analysis_with_cleanup(self):
        """Test that cleanup runs periodically"""
        analyzer = TradingAnalyzer()
        analyzer.running = True
        analyzer.analysis_results = [{"test": "data"}] * 4

        call_count = 0

        async def mock_capture():
            nonlocal call_count
            call_count += 1
            if call_count >= 4:
                analyzer.running = False
            return {"success": True}

        with patch.object(analyzer, 'capture_and_analyze', side_effect=mock_capture):
            with patch.object(analyzer, '_cleanup_old_files', AsyncMock()) as mock_cleanup:
                await analyzer.run_continuous_analysis(interval_minutes=0.01)

                mock_cleanup.assert_called()


@pytest.mark.asyncio
class TestSingleAnalysis:
    """Test single analysis operations"""

    async def test_single_analysis_success(self):
        """Test single analysis test"""
        analyzer = TradingAnalyzer()

        with patch.object(analyzer, 'capture_and_analyze', AsyncMock(
            return_value={"success": True, "models_tested": 1}
        )):
            result = await analyzer.test_single_analysis("gpt-4")

            assert result["success"] is True

    async def test_single_analysis_failure(self):
        """Test single analysis test failure"""
        analyzer = TradingAnalyzer()

        with patch.object(analyzer, 'capture_and_analyze', AsyncMock(
            return_value={"success": False, "error": "Test error"}
        )):
            result = await analyzer.test_single_analysis()

            assert result["success"] is False

    async def test_multiple_models_test(self):
        """Test multiple model testing"""
        analyzer = TradingAnalyzer()

        with patch.object(analyzer, 'capture_and_analyze', AsyncMock(
            return_value={"success": True, "models_tested": 3, "total_models": 3}
        )):
            result = await analyzer.test_multiple_models(["model1", "model2", "model3"])

            assert result["models_tested"] == 3


@pytest.mark.asyncio
class TestFileCleanup:
    """Test file cleanup functionality"""

    async def test_cleanup_old_screenshots(self, tmp_path):
        """Test cleanup of old screenshot files"""
        analyzer = TradingAnalyzer()
        analyzer.tv_scraper = AsyncMock()
        analyzer.tv_scraper.cleanup_old_screenshots = AsyncMock()

        with patch('trading_analyzer.RESPONSES_DIR', tmp_path):
            await analyzer._cleanup_old_files()

            analyzer.tv_scraper.cleanup_old_screenshots.assert_called_once()

    async def test_cleanup_old_responses(self, tmp_path):
        """Test cleanup of old response files"""
        analyzer = TradingAnalyzer()
        analyzer.tv_scraper = None

        # Create test response files
        for i in range(60):
            response_file = tmp_path / f"trading_analysis_{i}.txt"
            response_file.write_text("test")

        with patch('trading_analyzer.RESPONSES_DIR', tmp_path):
            with patch('trading_analyzer.SCHEDULE_CONFIG', {"max_responses": 50}):
                await analyzer._cleanup_old_files()

                # Should have only 50 files left
                remaining_files = list(tmp_path.glob("*.txt"))
                assert len(remaining_files) <= 50

    async def test_cleanup_old_sessions(self, tmp_path):
        """Test cleanup of old session files"""
        analyzer = TradingAnalyzer()

        # Create test session files
        for i in range(30):
            session_file = tmp_path / f"analysis_session_{i}.json"
            session_file.write_text("{}")

        with patch('trading_analyzer.OUTPUT_DIR', tmp_path):
            await analyzer._cleanup_old_files()

            # Should have only 20 session files left
            session_files = list(tmp_path.glob("analysis_session_*.json"))
            assert len(session_files) <= 20


@pytest.mark.asyncio
class TestAnalysisSummary:
    """Test analysis summary generation"""

    async def test_get_analysis_summary(self):
        """Test getting analysis summary"""
        analyzer = TradingAnalyzer()

        now = datetime.now()
        analyzer.analysis_results = [
            {
                "timestamp": now.isoformat(),
                "success": True,
                "analyses": [{"model": "gpt-4"}]
            },
            {
                "timestamp": (now - timedelta(hours=2)).isoformat(),
                "success": True,
                "analyses": [{"model": "claude"}]
            },
            {
                "timestamp": (now - timedelta(hours=30)).isoformat(),
                "success": False,
                "analyses": []
            }
        ]

        summary = await analyzer.get_analysis_summary(hours=24)

        assert summary["total_analyses"] == 2  # Only within 24 hours
        assert summary["successful_analyses"] == 2
        assert len(summary["models_used"]) == 2

    async def test_get_analysis_summary_empty(self):
        """Test summary with no results"""
        analyzer = TradingAnalyzer()
        analyzer.analysis_results = []

        summary = await analyzer.get_analysis_summary(hours=24)

        assert summary["total_analyses"] == 0
        assert summary["success_rate"] == 0


@pytest.mark.asyncio
class TestResultsExport:
    """Test results export functionality"""

    async def test_export_results(self, tmp_path):
        """Test exporting analysis results"""
        analyzer = TradingAnalyzer()
        analyzer.analysis_results = [
            {"timestamp": datetime.now().isoformat(), "success": True},
            {"timestamp": datetime.now().isoformat(), "success": False}
        ]

        with patch('trading_analyzer.OUTPUT_DIR', tmp_path):
            export_file = await analyzer.export_results()

            assert export_file != ""
            export_path = Path(export_file)
            assert export_path.exists()

            # Verify content
            with open(export_path, 'r') as f:
                data = json.load(f)
                assert data["total_results"] == 2
                assert len(data["results"]) == 2

    async def test_export_results_custom_path(self, tmp_path):
        """Test exporting with custom output path"""
        analyzer = TradingAnalyzer()
        analyzer.analysis_results = [{"test": "data"}]

        custom_path = str(tmp_path / "custom_export.json")

        export_file = await analyzer.export_results(output_file=custom_path)

        assert export_file == custom_path
        assert Path(custom_path).exists()


@pytest.mark.asyncio
class TestStopAndCleanup:
    """Test stop and cleanup operations"""

    async def test_stop(self):
        """Test stopping analyzer"""
        analyzer = TradingAnalyzer()
        analyzer.running = True

        await analyzer.stop()

        assert analyzer.running is False

    async def test_cleanup_all_resources(self):
        """Test cleanup of all resources"""
        analyzer = TradingAnalyzer()
        analyzer.tv_scraper = AsyncMock()
        analyzer.lm_scraper = AsyncMock()
        analyzer.tv_scraper.cleanup = AsyncMock()
        analyzer.lm_scraper.cleanup = AsyncMock()

        with patch.object(analyzer, 'stop', AsyncMock()):
            await analyzer.cleanup()

            analyzer.stop.assert_called_once()
            analyzer.tv_scraper.cleanup.assert_called_once()
            analyzer.lm_scraper.cleanup.assert_called_once()
            assert analyzer.tv_scraper is None
            assert analyzer.lm_scraper is None

    async def test_context_manager(self):
        """Test async context manager"""
        analyzer = TradingAnalyzer()

        with patch.object(analyzer, 'initialize', AsyncMock()):
            with patch.object(analyzer, 'cleanup', AsyncMock()):
                async with analyzer as a:
                    assert a is analyzer

                analyzer.cleanup.assert_called_once()


@pytest.mark.asyncio
class TestScheduling:
    """Test scheduled analysis"""

    def test_setup_scheduled_analysis(self):
        """Test setting up scheduled analysis"""
        analyzer = TradingAnalyzer()

        with patch('trading_analyzer.schedule'):
            with patch('trading_analyzer.threading.Thread') as MockThread:
                analyzer.setup_scheduled_analysis(interval_minutes=15)

                MockThread.assert_called_once()

    def test_run_scheduled_analysis(self):
        """Test running scheduled analysis wrapper"""
        analyzer = TradingAnalyzer()

        with patch('asyncio.new_event_loop') as mock_loop_factory:
            with patch('asyncio.set_event_loop'):
                mock_loop = MagicMock()
                mock_loop_factory.return_value = mock_loop
                mock_loop.run_until_complete = MagicMock(
                    return_value={"success": True}
                )

                analyzer._run_scheduled_analysis()

                mock_loop.run_until_complete.assert_called_once()


@pytest.mark.asyncio
class TestEdgeCases:
    """Test edge cases and error handling"""

    async def test_capture_and_analyze_exception(self):
        """Test exception handling in capture_and_analyze"""
        analyzer = TradingAnalyzer()
        analyzer.tv_scraper = AsyncMock()
        analyzer.tv_scraper.capture_chart_screenshot = AsyncMock(
            side_effect=Exception("Capture failed")
        )

        result = await analyzer.capture_and_analyze()

        assert result["success"] is False
        assert "error" in result

    async def test_export_results_error(self):
        """Test error handling in export"""
        analyzer = TradingAnalyzer()

        with patch('builtins.open', side_effect=PermissionError()):
            export_file = await analyzer.export_results("/invalid/path.json")

            assert export_file == ""

    async def test_continuous_analysis_keyboard_interrupt(self):
        """Test handling keyboard interrupt in continuous analysis"""
        analyzer = TradingAnalyzer()
        analyzer.running = True

        with patch.object(analyzer, 'capture_and_analyze', AsyncMock(
            side_effect=KeyboardInterrupt()
        )):
            await analyzer.run_continuous_analysis(interval_minutes=0.01)

            assert analyzer.running is False


if __name__ == "__main__":
    pytest.main([__file__, "-v", "--tb=short"])