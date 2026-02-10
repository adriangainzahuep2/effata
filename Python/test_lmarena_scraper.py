"""
Comprehensive unit tests for lmarena_scraper.py
Tests LMArena chat scraping, model selection, and response extraction
"""
import pytest
import asyncio
from unittest.mock import Mock, AsyncMock, patch, MagicMock
from pathlib import Path
from datetime import datetime

from lmarena_scraper import LMArenaScaper


class TestLMArenaScaperInitialization:
    """Test LMArena scraper initialization"""

    def test_scraper_init(self):
        """Test scraper initialization"""
        scraper = LMArenaScaper("test_profile")

        assert scraper.profile_name == "test_profile"
        assert scraper.browser is None
        assert scraper.current_model is None
        assert scraper.session_active is False
        assert isinstance(scraper.conversation_history, list)
        assert len(scraper.conversation_history) == 0

    def test_responses_directory_creation(self):
        """Test that responses directory is ensured to exist"""
        scraper = LMArenaScaper()
        # Directory should be created during init
        from config import RESPONSES_DIR
        assert RESPONSES_DIR.exists()


class TestLMArenaScaperStartup:
    """Test scraper startup and navigation"""

    @pytest.mark.asyncio
    async def test_start_success(self):
        """Test successful scraper start"""
        scraper = LMArenaScaper("test")

        with patch('lmarena_scraper.AntiDetectBrowser') as mock_browser_class:
            mock_browser = AsyncMock()
            mock_browser.start_browser = AsyncMock()
            mock_browser.navigate_to = AsyncMock()
            mock_browser.page = AsyncMock()
            mock_browser.page.keyboard = AsyncMock()
            mock_browser.page.keyboard.press = AsyncMock()
            mock_browser.page.query_selector = AsyncMock(return_value=None)
            mock_browser.page.wait_for_selector = AsyncMock()

            mock_browser_class.return_value = mock_browser

            await scraper.start()

            assert scraper.browser is not None
            mock_browser.start_browser.assert_called_once_with(mobile=True, proxy=None)
            mock_browser.navigate_to.assert_called_once()

    @pytest.mark.asyncio
    async def test_start_with_navigation_failure(self):
        """Test start with navigation failure"""
        scraper = LMArenaScaper("test")

        with patch('lmarena_scraper.AntiDetectBrowser') as mock_browser_class:
            mock_browser = AsyncMock()
            mock_browser.start_browser = AsyncMock()
            mock_browser.navigate_to = AsyncMock(side_effect=Exception("Navigation failed"))
            mock_browser.cleanup = AsyncMock()

            mock_browser_class.return_value = mock_browser

            with pytest.raises(Exception, match="Navigation failed"):
                await scraper.start()


class TestLMArenaScaperModelSelection:
    """Test model selection functionality"""

    @pytest.mark.asyncio
    async def test_get_available_models_success(self):
        """Test getting available models"""
        scraper = LMArenaScaper()

        mock_option = AsyncMock()
        mock_option.inner_text = AsyncMock(return_value="gpt-4")

        mock_dropdown = AsyncMock()
        mock_dropdown.is_visible = AsyncMock(return_value=True)
        mock_dropdown.click = AsyncMock()

        mock_page = AsyncMock()
        mock_page.query_selector = AsyncMock(return_value=mock_dropdown)
        mock_page.query_selector_all = AsyncMock(return_value=[mock_option])

        mock_browser = AsyncMock()
        mock_browser.page = mock_page
        scraper.browser = mock_browser

        models = await scraper.get_available_models()

        assert isinstance(models, list)
        assert len(models) > 0

    @pytest.mark.asyncio
    async def test_get_available_models_fallback(self):
        """Test falling back to configured models"""
        scraper = LMArenaScaper()

        mock_page = AsyncMock()
        mock_page.query_selector = AsyncMock(return_value=None)

        mock_browser = AsyncMock()
        mock_browser.page = mock_page
        scraper.browser = mock_browser

        models = await scraper.get_available_models()

        # Should return configured models
        from config import LMARENA_CONFIG
        assert models == LMARENA_CONFIG["models"]

    @pytest.mark.asyncio
    async def test_select_model_success(self):
        """Test successful model selection"""
        scraper = LMArenaScaper()

        mock_option = AsyncMock()
        mock_option.click = AsyncMock()

        mock_dropdown = AsyncMock()
        mock_dropdown.is_visible = AsyncMock(return_value=True)
        mock_dropdown.click = AsyncMock()

        mock_page = AsyncMock()
        mock_page.query_selector = AsyncMock(side_effect=[mock_dropdown, mock_option])

        mock_browser = AsyncMock()
        mock_browser.page = mock_page
        scraper.browser = mock_browser

        result = await scraper.select_model("gpt-4")

        assert result is True
        assert scraper.current_model == "gpt-4"

    @pytest.mark.asyncio
    async def test_select_model_not_found(self):
        """Test model selection when model not found"""
        scraper = LMArenaScaper()

        mock_page = AsyncMock()
        mock_page.query_selector = AsyncMock(return_value=None)
        mock_page.query_selector_all = AsyncMock(return_value=[])

        mock_browser = AsyncMock()
        mock_browser.page = mock_page
        scraper.browser = mock_browser

        result = await scraper.select_model("nonexistent-model")

        assert result is False


class TestLMArenaScaperMessaging:
    """Test message sending functionality"""

    @pytest.mark.asyncio
    async def test_send_message_success(self):
        """Test successful message sending"""
        scraper = LMArenaScaper()

        mock_input = AsyncMock()
        mock_input.is_visible = AsyncMock(return_value=True)
        mock_input.click = AsyncMock()

        mock_send_button = AsyncMock()
        mock_send_button.is_visible = AsyncMock(return_value=True)
        mock_send_button.click = AsyncMock()

        mock_page = AsyncMock()
        mock_page.query_selector = AsyncMock(side_effect=[mock_input, mock_send_button])
        mock_page.keyboard = AsyncMock()
        mock_page.keyboard.press = AsyncMock()

        mock_browser = AsyncMock()
        mock_browser.page = mock_page
        mock_browser.type_text = AsyncMock()
        scraper.browser = mock_browser

        result = await scraper.send_message("Test message")

        assert result is True
        mock_browser.type_text.assert_called_once()

    @pytest.mark.asyncio
    async def test_send_message_with_image(self):
        """Test sending message with image"""
        scraper = LMArenaScaper()
        scraper._upload_image = AsyncMock()

        mock_input = AsyncMock()
        mock_input.is_visible = AsyncMock(return_value=True)
        mock_input.click = AsyncMock()

        mock_page = AsyncMock()
        mock_page.query_selector = AsyncMock(return_value=mock_input)
        mock_page.keyboard = AsyncMock()
        mock_page.keyboard.press = AsyncMock()

        mock_browser = AsyncMock()
        mock_browser.page = mock_page
        mock_browser.type_text = AsyncMock()
        scraper.browser = mock_browser

        # Create a temporary file
        import tempfile
        with tempfile.NamedTemporaryFile(suffix='.jpg', delete=False) as tmp:
            tmp.write(b'fake image data')
            tmp_path = tmp.name

        try:
            result = await scraper.send_message("Test message", image_path=tmp_path)
            scraper._upload_image.assert_called_once_with(tmp_path)
        finally:
            Path(tmp_path).unlink()

    @pytest.mark.asyncio
    async def test_send_message_input_not_found(self):
        """Test message sending when input not found"""
        scraper = LMArenaScaper()

        mock_page = AsyncMock()
        mock_page.query_selector = AsyncMock(return_value=None)

        mock_browser = AsyncMock()
        mock_browser.page = mock_page
        scraper.browser = mock_browser

        result = await scraper.send_message("Test message")

        assert result is False


class TestLMArenaScaperResponseHandling:
    """Test response waiting and extraction"""

    @pytest.mark.asyncio
    async def test_wait_for_response_success(self):
        """Test successful response waiting"""
        scraper = LMArenaScaper()

        mock_element = AsyncMock()
        mock_element.inner_text = AsyncMock(return_value="This is a response from the AI model")

        mock_page = AsyncMock()
        mock_page.query_selector_all = AsyncMock(return_value=[mock_element])

        mock_browser = AsyncMock()
        mock_browser.page = mock_page
        scraper.browser = mock_browser

        response = await scraper.wait_for_response(timeout=5000)

        assert response is not None
        assert "response" in response

    @pytest.mark.asyncio
    async def test_wait_for_response_timeout(self):
        """Test response waiting with timeout"""
        scraper = LMArenaScaper()
        scraper._extract_response_with_bs4 = AsyncMock(return_value=None)

        mock_page = AsyncMock()
        mock_page.query_selector_all = AsyncMock(return_value=[])

        mock_browser = AsyncMock()
        mock_browser.page = mock_page
        scraper.browser = mock_browser

        response = await scraper.wait_for_response(timeout=1000)

        assert response is None

    @pytest.mark.asyncio
    async def test_extract_response_with_bs4(self):
        """Test fallback response extraction with BeautifulSoup"""
        scraper = LMArenaScaper()

        html_content = """
        <html>
            <div class="message-content">Test AI response</div>
        </html>
        """

        mock_page = AsyncMock()
        mock_page.content = AsyncMock(return_value=html_content)

        mock_browser = AsyncMock()
        mock_browser.page = mock_page
        scraper.browser = mock_browser

        response = await scraper._extract_response_with_bs4()

        assert response is not None
        assert len(response) > 10


class TestLMArenaScaperResponseSaving:
    """Test response saving functionality"""

    @pytest.mark.asyncio
    async def test_save_response(self, tmp_path):
        """Test saving response to file"""
        scraper = LMArenaScaper()
        scraper.current_model = "gpt-4"

        response_text = "This is a test trading analysis response"

        with patch('lmarena_scraper.RESPONSES_DIR', tmp_path):
            output_file = await scraper.save_response(
                response_text,
                model_name="gpt-4",
                image_path="/path/to/image.jpg"
            )

            assert output_file != ""
            output_path = Path(output_file)
            assert output_path.exists()
            assert output_path.suffix == '.txt'

            # Check content
            content = output_path.read_text()
            assert response_text in content
            assert "gpt-4" in content

            # Check JSON file
            json_path = output_path.with_suffix('.json')
            assert json_path.exists()


class TestLMArenaScaperChartAnalysis:
    """Test chart analysis workflow"""

    @pytest.mark.asyncio
    async def test_analyze_chart_success(self, tmp_path):
        """Test successful chart analysis"""
        scraper = LMArenaScaper()
        scraper.current_model = "gpt-4"
        scraper.select_model = AsyncMock(return_value=True)
        scraper.send_message = AsyncMock(return_value=True)
        scraper.wait_for_response = AsyncMock(return_value="Analysis response")
        scraper.save_response = AsyncMock(return_value=str(tmp_path / "response.txt"))

        # Create temp image
        image_path = tmp_path / "test_chart.jpg"
        image_path.write_bytes(b"fake image")

        result = await scraper.analyze_chart(str(image_path))

        assert result is not None
        assert result["success"] is True
        assert result["model"] == "gpt-4"
        assert result["response"] == "Analysis response"

    @pytest.mark.asyncio
    async def test_analyze_chart_with_custom_prompt(self, tmp_path):
        """Test chart analysis with custom prompt"""
        scraper = LMArenaScaper()
        scraper.current_model = "gpt-4"
        scraper.select_model = AsyncMock(return_value=True)
        scraper.send_message = AsyncMock(return_value=True)
        scraper.wait_for_response = AsyncMock(return_value="Custom analysis")
        scraper.save_response = AsyncMock(return_value=str(tmp_path / "response.txt"))

        image_path = tmp_path / "test_chart.jpg"
        image_path.write_bytes(b"fake image")

        custom_prompt = "Analyze this chart for scalping opportunities"
        result = await scraper.analyze_chart(str(image_path), custom_prompt=custom_prompt)

        assert result["success"] is True
        scraper.send_message.assert_called_once()
        call_args = scraper.send_message.call_args[0]
        assert call_args[0] == custom_prompt

    @pytest.mark.asyncio
    async def test_analyze_chart_send_failure(self, tmp_path):
        """Test chart analysis when message sending fails"""
        scraper = LMArenaScaper()
        scraper.select_model = AsyncMock(return_value=True)
        scraper.send_message = AsyncMock(return_value=False)

        image_path = tmp_path / "test_chart.jpg"
        image_path.write_bytes(b"fake image")

        result = await scraper.analyze_chart(str(image_path))

        assert result is None


class TestLMArenaScaperMultiModel:
    """Test multiple model testing"""

    @pytest.mark.asyncio
    async def test_test_multiple_models(self, tmp_path):
        """Test analyzing with multiple models"""
        scraper = LMArenaScaper()
        scraper.analyze_chart = AsyncMock(
            return_value={"success": True, "model": "test-model"}
        )

        image_path = tmp_path / "test_chart.jpg"
        image_path.write_bytes(b"fake image")

        models = ["gpt-4", "claude", "gemini"]
        results = await scraper.test_multiple_models(str(image_path), models)

        assert len(results) == 3
        assert scraper.analyze_chart.call_count == 3


class TestLMArenaScaperConversationHistory:
    """Test conversation history management"""

    @pytest.mark.asyncio
    async def test_get_conversation_history(self):
        """Test getting conversation history"""
        scraper = LMArenaScaper()
        scraper.conversation_history = [
            {"model": "gpt-4", "response": "Test 1"},
            {"model": "claude", "response": "Test 2"}
        ]

        history = await scraper.get_conversation_history()

        assert len(history) == 2
        assert history[0]["model"] == "gpt-4"

    @pytest.mark.asyncio
    async def test_clear_conversation_history(self):
        """Test clearing conversation history"""
        scraper = LMArenaScaper()
        scraper.conversation_history = [{"test": "data"}]

        await scraper.clear_conversation_history()

        assert len(scraper.conversation_history) == 0


class TestLMArenaScaperCleanup:
    """Test cleanup functionality"""

    @pytest.mark.asyncio
    async def test_cleanup(self):
        """Test scraper cleanup"""
        scraper = LMArenaScaper()

        mock_browser = AsyncMock()
        mock_browser.cleanup = AsyncMock()
        scraper.browser = mock_browser
        scraper.session_active = True

        await scraper.cleanup()

        mock_browser.cleanup.assert_called_once()
        assert scraper.browser is None
        assert scraper.session_active is False

    @pytest.mark.asyncio
    async def test_context_manager(self):
        """Test async context manager"""
        scraper = LMArenaScaper()
        scraper.start = AsyncMock()
        scraper.cleanup = AsyncMock()

        async with scraper:
            pass

        scraper.start.assert_called_once()
        scraper.cleanup.assert_called_once()


class TestLMArenaScaperEdgeCases:
    """Test edge cases and error handling"""

    @pytest.mark.asyncio
    async def test_dismiss_popups_no_popups(self):
        """Test dismissing popups when none exist"""
        scraper = LMArenaScaper()

        mock_page = AsyncMock()
        mock_page.query_selector = AsyncMock(return_value=None)
        mock_page.keyboard = AsyncMock()
        mock_page.keyboard.press = AsyncMock()

        mock_browser = AsyncMock()
        mock_browser.page = mock_page
        scraper.browser = mock_browser

        # Should not raise exception
        await scraper._dismiss_popups()

    @pytest.mark.asyncio
    async def test_wait_for_chat_interface_timeout(self):
        """Test waiting for chat interface with timeout"""
        scraper = LMArenaScaper()

        mock_page = AsyncMock()
        mock_page.wait_for_selector = AsyncMock(
            side_effect=Exception("Timeout")
        )

        mock_browser = AsyncMock()
        mock_browser.page = mock_page
        scraper.browser = mock_browser

        with pytest.raises(Exception):
            await scraper._wait_for_chat_interface()

    @pytest.mark.asyncio
    async def test_upload_image_no_upload_button(self):
        """Test uploading image when no upload button found"""
        scraper = LMArenaScaper()

        mock_page = AsyncMock()
        mock_page.query_selector = AsyncMock(return_value=None)

        mock_browser = AsyncMock()
        mock_browser.page = mock_page
        scraper.browser = mock_browser

        # Should not raise exception, just log warning
        await scraper._upload_image("/path/to/image.jpg")

    def test_scraper_with_default_profile(self):
        """Test scraper with default profile name"""
        scraper = LMArenaScaper()
        assert scraper.profile_name == "lmarena"