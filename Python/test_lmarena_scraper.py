"""
Comprehensive unit tests for lmarena_scraper.py
Tests LMArena chat scraping, model selection, and response extraction
"""
import pytest
import asyncio
from pathlib import Path
from unittest.mock import Mock, AsyncMock, patch, MagicMock
from datetime import datetime
import json

from lmarena_scraper import LMArenaScaper


class TestLMArenaScraperInit:
    """Test LMArenaScaper initialization"""

    def test_scraper_initialization(self):
        """Test scraper object creation"""
        scraper = LMArenaScaper("test_profile")

        assert scraper.profile_name == "test_profile"
        assert scraper.browser is None
        assert scraper.current_model is None
        assert scraper.session_active is False
        assert len(scraper.conversation_history) == 0

    def test_responses_directory_creation(self, tmp_path):
        """Test that responses directory is created"""
        with patch('lmarena_scraper.RESPONSES_DIR', tmp_path / "responses"):
            scraper = LMArenaScaper("test")
            assert (tmp_path / "responses").exists()


@pytest.mark.asyncio
class TestScraperStartup:
    """Test scraper startup and initialization"""

    async def test_start_scraper(self):
        """Test starting the scraper"""
        scraper = LMArenaScaper("test")

        with patch('lmarena_scraper.AntiDetectBrowser') as MockBrowser:
            mock_browser = AsyncMock()
            MockBrowser.return_value = mock_browser

            mock_browser.start_browser = AsyncMock()
            mock_browser.navigate_to = AsyncMock()
            mock_browser.page = AsyncMock()
            mock_browser.page.keyboard = AsyncMock()
            mock_browser.page.keyboard.press = AsyncMock()

            # Mock wait_for_chat_interface
            with patch.object(scraper, '_wait_for_chat_interface', AsyncMock()):
                with patch.object(scraper, '_dismiss_popups', AsyncMock()):
                    await scraper.start()

                    assert scraper.browser is not None
                    mock_browser.start_browser.assert_called_once()

    async def test_navigate_to_chat(self):
        """Test navigation to chat interface"""
        scraper = LMArenaScaper("test")
        scraper.browser = AsyncMock()
        scraper.browser.navigate_to = AsyncMock()
        scraper.browser.page = AsyncMock()
        scraper.browser.page.keyboard = AsyncMock()
        scraper.browser.page.keyboard.press = AsyncMock()

        with patch.object(scraper, '_dismiss_popups', AsyncMock()):
            with patch.object(scraper, '_wait_for_chat_interface', AsyncMock()):
                await scraper._navigate_to_chat()

                assert scraper.session_active is True
                scraper.browser.navigate_to.assert_called_once()


@pytest.mark.asyncio
class TestPopupHandling:
    """Test popup dismissal"""

    async def test_dismiss_popups(self):
        """Test popup dismissal functionality"""
        scraper = LMArenaScaper("test")
        scraper.browser = AsyncMock()

        mock_element = AsyncMock()
        mock_element.is_visible = AsyncMock(return_value=True)
        mock_element.click = AsyncMock()

        scraper.browser.page = AsyncMock()
        scraper.browser.page.query_selector = AsyncMock(return_value=mock_element)
        scraper.browser.page.keyboard = AsyncMock()
        scraper.browser.page.keyboard.press = AsyncMock()

        await scraper._dismiss_popups()

        scraper.browser.page.keyboard.press.assert_called_with("Escape")

    async def test_dismiss_popups_no_elements(self):
        """Test popup dismissal when no popups present"""
        scraper = LMArenaScaper("test")
        scraper.browser = AsyncMock()
        scraper.browser.page = AsyncMock()
        scraper.browser.page.query_selector = AsyncMock(return_value=None)
        scraper.browser.page.keyboard = AsyncMock()
        scraper.browser.page.keyboard.press = AsyncMock()

        await scraper._dismiss_popups()

        # Should still press Escape as fallback
        scraper.browser.page.keyboard.press.assert_called_with("Escape")


@pytest.mark.asyncio
class TestChatInterfaceWaiting:
    """Test waiting for chat interface"""

    async def test_wait_for_chat_interface_success(self):
        """Test successful wait for chat interface"""
        scraper = LMArenaScaper("test")
        scraper.browser = AsyncMock()
        scraper.browser.page = AsyncMock()
        scraper.browser.page.wait_for_selector = AsyncMock()

        await scraper._wait_for_chat_interface()

        scraper.browser.page.wait_for_selector.assert_called()

    async def test_wait_for_chat_interface_retry(self):
        """Test retry mechanism when first selector fails"""
        scraper = LMArenaScaper("test")
        scraper.browser = AsyncMock()
        scraper.browser.page = AsyncMock()

        # First call fails, second succeeds
        scraper.browser.page.wait_for_selector = AsyncMock(
            side_effect=[Exception("Not found"), None]
        )

        await scraper._wait_for_chat_interface()

        assert scraper.browser.page.wait_for_selector.call_count >= 1


@pytest.mark.asyncio
class TestModelSelection:
    """Test AI model selection"""

    async def test_get_available_models(self):
        """Test getting list of available models"""
        scraper = LMArenaScaper("test")
        scraper.browser = AsyncMock()
        scraper.browser.page = AsyncMock()

        mock_dropdown = AsyncMock()
        mock_dropdown.is_visible = AsyncMock(return_value=True)
        mock_dropdown.click = AsyncMock()

        mock_option1 = AsyncMock()
        mock_option1.inner_text = AsyncMock(return_value="GPT-4")
        mock_option2 = AsyncMock()
        mock_option2.inner_text = AsyncMock(return_value="Claude")

        scraper.browser.page.query_selector = AsyncMock(return_value=mock_dropdown)
        scraper.browser.page.query_selector_all = AsyncMock(
            return_value=[mock_option1, mock_option2]
        )

        models = await scraper.get_available_models()

        assert len(models) >= 2

    async def test_get_available_models_fallback(self):
        """Test fallback to configured models"""
        scraper = LMArenaScaper("test")
        scraper.browser = AsyncMock()
        scraper.browser.page = AsyncMock()
        scraper.browser.page.query_selector = AsyncMock(return_value=None)

        with patch('lmarena_scraper.LMARENA_CONFIG', {"models": ["model1", "model2"]}):
            models = await scraper.get_available_models()

            assert "model1" in models
            assert "model2" in models

    async def test_select_model_success(self):
        """Test successful model selection"""
        scraper = LMArenaScaper("test")
        scraper.browser = AsyncMock()
        scraper.browser.page = AsyncMock()

        mock_dropdown = AsyncMock()
        mock_dropdown.is_visible = AsyncMock(return_value=True)
        mock_dropdown.click = AsyncMock()

        mock_option = AsyncMock()
        mock_option.click = AsyncMock()

        scraper.browser.page.query_selector = AsyncMock(
            side_effect=[mock_dropdown, mock_option]
        )

        result = await scraper.select_model("gpt-4")

        assert result is True
        assert scraper.current_model == "gpt-4"

    async def test_select_model_not_found(self):
        """Test model selection when model not found"""
        scraper = LMArenaScaper("test")
        scraper.browser = AsyncMock()
        scraper.browser.page = AsyncMock()
        scraper.browser.page.query_selector = AsyncMock(return_value=None)

        result = await scraper.select_model("nonexistent-model")

        assert result is False


@pytest.mark.asyncio
class TestMessageSending:
    """Test message sending functionality"""

    async def test_send_message_text_only(self):
        """Test sending text message"""
        scraper = LMArenaScaper("test")
        scraper.browser = AsyncMock()

        mock_input = AsyncMock()
        mock_input.is_visible = AsyncMock(return_value=True)
        mock_input.click = AsyncMock()

        mock_send_button = AsyncMock()
        mock_send_button.is_visible = AsyncMock(return_value=True)
        mock_send_button.click = AsyncMock()

        scraper.browser.page = AsyncMock()
        scraper.browser.page.query_selector = AsyncMock(
            side_effect=[mock_input, mock_send_button]
        )
        scraper.browser.page.keyboard = AsyncMock()
        scraper.browser.page.keyboard.press = AsyncMock()
        scraper.browser.type_text = AsyncMock()

        result = await scraper.send_message("Test message")

        assert result is True
        scraper.browser.type_text.assert_called_once()

    async def test_send_message_with_image(self):
        """Test sending message with image attachment"""
        scraper = LMArenaScaper("test")
        scraper.browser = AsyncMock()

        mock_input = AsyncMock()
        mock_input.is_visible = AsyncMock(return_value=True)
        mock_input.click = AsyncMock()

        scraper.browser.page = AsyncMock()
        scraper.browser.page.query_selector = AsyncMock(return_value=mock_input)
        scraper.browser.page.keyboard = AsyncMock()
        scraper.browser.type_text = AsyncMock()

        with patch.object(scraper, '_upload_image', AsyncMock()):
            with patch('pathlib.Path.exists', return_value=True):
                result = await scraper.send_message("Analyze this", "/tmp/chart.jpg")

                scraper._upload_image.assert_called_once_with("/tmp/chart.jpg")

    async def test_send_message_input_not_found(self):
        """Test error handling when input not found"""
        scraper = LMArenaScaper("test")
        scraper.browser = AsyncMock()
        scraper.browser.page = AsyncMock()
        scraper.browser.page.query_selector = AsyncMock(return_value=None)

        result = await scraper.send_message("Test")

        assert result is False


@pytest.mark.asyncio
class TestImageUpload:
    """Test image upload functionality"""

    async def test_upload_image_success(self):
        """Test successful image upload"""
        scraper = LMArenaScaper("test")
        scraper.browser = AsyncMock()

        mock_file_input = AsyncMock()
        mock_file_input.set_input_files = AsyncMock()

        scraper.browser.page = AsyncMock()
        scraper.browser.page.query_selector = AsyncMock(return_value=mock_file_input)

        await scraper._upload_image("/tmp/test.jpg")

        mock_file_input.set_input_files.assert_called_once_with("/tmp/test.jpg")

    async def test_upload_image_not_found(self):
        """Test upload when file input not found"""
        scraper = LMArenaScaper("test")
        scraper.browser = AsyncMock()
        scraper.browser.page = AsyncMock()
        scraper.browser.page.query_selector = AsyncMock(return_value=None)

        # Should not raise exception
        await scraper._upload_image("/tmp/test.jpg")


@pytest.mark.asyncio
class TestResponseWaiting:
    """Test waiting for and extracting responses"""

    async def test_wait_for_response_success(self):
        """Test successful response extraction"""
        scraper = LMArenaScaper("test")
        scraper.browser = AsyncMock()

        mock_element = AsyncMock()
        mock_element.inner_text = AsyncMock(return_value="AI response text here")

        scraper.browser.page = AsyncMock()
        scraper.browser.page.query_selector_all = AsyncMock(return_value=[mock_element])

        response = await scraper.wait_for_response(timeout=5000)

        assert response == "AI response text here"

    async def test_wait_for_response_timeout(self):
        """Test response timeout handling"""
        scraper = LMArenaScaper("test")
        scraper.browser = AsyncMock()
        scraper.browser.page = AsyncMock()
        scraper.browser.page.query_selector_all = AsyncMock(return_value=[])
        scraper.browser.page.content = AsyncMock(return_value="<html></html>")

        with patch.object(scraper, '_extract_response_with_bs4', AsyncMock(return_value=None)):
            response = await scraper.wait_for_response(timeout=1000)

            assert response is None

    async def test_extract_response_with_bs4(self):
        """Test BeautifulSoup fallback extraction"""
        scraper = LMArenaScaper("test")
        scraper.browser = AsyncMock()

        html_content = """
        <html>
            <div class="message-content">This is the AI response</div>
        </html>
        """
        scraper.browser.page = AsyncMock()
        scraper.browser.page.content = AsyncMock(return_value=html_content)

        response = await scraper._extract_response_with_bs4()

        assert "AI response" in response


@pytest.mark.asyncio
class TestResponseSaving:
    """Test response saving functionality"""

    async def test_save_response(self, tmp_path):
        """Test saving response to file"""
        scraper = LMArenaScaper("test")

        with patch('lmarena_scraper.RESPONSES_DIR', tmp_path):
            output_file = await scraper.save_response(
                "Test AI response",
                "gpt-4",
                "/tmp/chart.jpg"
            )

            assert output_file != ""
            output_path = Path(output_file)
            assert output_path.exists()

            # Check content
            content = output_path.read_text()
            assert "Test AI response" in content
            assert "gpt-4" in content

    async def test_save_response_creates_json(self, tmp_path):
        """Test that JSON file is also created"""
        scraper = LMArenaScaper("test")

        with patch('lmarena_scraper.RESPONSES_DIR', tmp_path):
            output_file = await scraper.save_response(
                "Test response",
                "claude",
                None
            )

            json_file = Path(output_file).with_suffix('.json')
            assert json_file.exists()

            # Check JSON content
            with open(json_file, 'r') as f:
                data = json.load(f)
                assert data["model"] == "claude"
                assert data["response"] == "Test response"


@pytest.mark.asyncio
class TestChartAnalysis:
    """Test complete chart analysis workflow"""

    async def test_analyze_chart_success(self):
        """Test successful chart analysis"""
        scraper = LMArenaScaper("test")
        scraper.current_model = "gpt-4"

        with patch.object(scraper, 'send_message', AsyncMock(return_value=True)):
            with patch.object(scraper, 'wait_for_response', AsyncMock(return_value="Analysis result")):
                with patch.object(scraper, 'save_response', AsyncMock(return_value="/tmp/output.txt")):
                    result = await scraper.analyze_chart("/tmp/chart.jpg")

                    assert result is not None
                    assert result["success"] is True
                    assert result["response"] == "Analysis result"
                    assert result["model"] == "gpt-4"

    async def test_analyze_chart_send_failed(self):
        """Test chart analysis when message sending fails"""
        scraper = LMArenaScaper("test")

        with patch.object(scraper, 'send_message', AsyncMock(return_value=False)):
            result = await scraper.analyze_chart("/tmp/chart.jpg")

            assert result is None

    async def test_analyze_chart_no_response(self):
        """Test chart analysis when no response received"""
        scraper = LMArenaScaper("test")

        with patch.object(scraper, 'send_message', AsyncMock(return_value=True)):
            with patch.object(scraper, 'wait_for_response', AsyncMock(return_value=None)):
                result = await scraper.analyze_chart("/tmp/chart.jpg")

                assert result is None

    async def test_analyze_chart_with_model_switch(self):
        """Test chart analysis with model switching"""
        scraper = LMArenaScaper("test")
        scraper.current_model = "model1"

        with patch.object(scraper, 'select_model', AsyncMock(return_value=True)):
            with patch.object(scraper, 'send_message', AsyncMock(return_value=True)):
                with patch.object(scraper, 'wait_for_response', AsyncMock(return_value="Result")):
                    with patch.object(scraper, 'save_response', AsyncMock(return_value="/tmp/out.txt")):
                        result = await scraper.analyze_chart(
                            "/tmp/chart.jpg",
                            model_name="model2"
                        )

                        scraper.select_model.assert_called_once_with("model2")


@pytest.mark.asyncio
class TestMultipleModels:
    """Test testing with multiple models"""

    async def test_test_multiple_models(self):
        """Test analyzing with multiple AI models"""
        scraper = LMArenaScaper("test")

        with patch.object(scraper, 'analyze_chart', AsyncMock(return_value={"success": True})):
            results = await scraper.test_multiple_models(
                "/tmp/chart.jpg",
                ["model1", "model2", "model3"]
            )

            assert len(results) == 3
            assert scraper.analyze_chart.call_count == 3

    async def test_test_multiple_models_with_failures(self):
        """Test multiple models with some failures"""
        scraper = LMArenaScaper("test")

        # First succeeds, second fails, third succeeds
        with patch.object(scraper, 'analyze_chart', AsyncMock(
            side_effect=[
                {"success": True},
                None,
                {"success": True}
            ]
        )):
            results = await scraper.test_multiple_models(
                "/tmp/chart.jpg",
                ["model1", "model2", "model3"]
            )

            assert len(results) == 2  # Only successful ones


@pytest.mark.asyncio
class TestConversationHistory:
    """Test conversation history management"""

    async def test_get_conversation_history(self):
        """Test getting conversation history"""
        scraper = LMArenaScaper("test")
        scraper.conversation_history = [
            {"timestamp": "2024-01-01", "response": "Response 1"},
            {"timestamp": "2024-01-02", "response": "Response 2"}
        ]

        history = await scraper.get_conversation_history()

        assert len(history) == 2
        assert history[0]["response"] == "Response 1"

    async def test_clear_conversation_history(self):
        """Test clearing conversation history"""
        scraper = LMArenaScaper("test")
        scraper.conversation_history = [{"test": "data"}]

        await scraper.clear_conversation_history()

        assert len(scraper.conversation_history) == 0


@pytest.mark.asyncio
class TestCleanup:
    """Test cleanup and resource management"""

    async def test_cleanup(self):
        """Test proper cleanup"""
        scraper = LMArenaScaper("test")
        scraper.browser = AsyncMock()
        scraper.browser.cleanup = AsyncMock()
        scraper.session_active = True

        await scraper.cleanup()

        assert scraper.browser is None
        assert scraper.session_active is False

    async def test_context_manager(self):
        """Test async context manager"""
        scraper = LMArenaScaper("test")

        with patch.object(scraper, 'start', AsyncMock()):
            with patch.object(scraper, 'cleanup', AsyncMock()):
                async with scraper as s:
                    assert s is scraper

                scraper.cleanup.assert_called_once()


@pytest.mark.asyncio
class TestEdgeCases:
    """Test edge cases and error handling"""

    async def test_analyze_chart_exception(self):
        """Test exception handling in analyze_chart"""
        scraper = LMArenaScaper("test")

        with patch.object(scraper, 'send_message', AsyncMock(side_effect=Exception("Error"))):
            result = await scraper.analyze_chart("/tmp/chart.jpg")

            assert result is not None
            assert result["success"] is False
            assert "error" in result

    async def test_save_response_error(self, tmp_path):
        """Test error handling in save_response"""
        scraper = LMArenaScaper("test")

        # Make directory read-only to cause write error
        with patch('lmarena_scraper.RESPONSES_DIR', Path("/invalid/path")):
            with patch('builtins.open', side_effect=PermissionError()):
                output_file = await scraper.save_response("Test", "model", None)

                assert output_file == ""


if __name__ == "__main__":
    pytest.main([__file__, "-v", "--tb=short"])