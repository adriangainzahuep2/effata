"""
Comprehensive unit tests for config.py
Tests configuration loading and validation
"""
import pytest
from pathlib import Path

from config import (
    TRADINGVIEW_CONFIG, LMARENA_CONFIG, BROWSER_CONFIG,
    ANTI_DETECT_CONFIG, IMAGE_CONFIG, TRADING_PROMPT,
    OUTPUT_DIR, SCREENSHOTS_DIR, RESPONSES_DIR, LOGS_DIR
)


class TestDirectoryConfiguration:
    """Test directory configuration"""

    def test_directories_exist(self):
        """Test that configured directories exist"""
        assert OUTPUT_DIR.exists()
        assert SCREENSHOTS_DIR.exists()
        assert RESPONSES_DIR.exists()
        assert LOGS_DIR.exists()

    def test_directories_are_paths(self):
        """Test that directories are Path objects"""
        assert isinstance(OUTPUT_DIR, Path)
        assert isinstance(SCREENSHOTS_DIR, Path)


class TestTradingViewConfig:
    """Test TradingView configuration"""

    def test_tradingview_url_valid(self):
        """Test TradingView URL is valid"""
        assert "tradingview.com" in TRADINGVIEW_CONFIG["url"]
        assert TRADINGVIEW_CONFIG["url"].startswith("https://")

    def test_tradingview_selectors_present(self):
        """Test required selectors are present"""
        assert "chart_selector" in TRADINGVIEW_CONFIG
        assert "chart_area_selector" in TRADINGVIEW_CONFIG

    def test_tradingview_timing_config(self):
        """Test timing configuration"""
        assert TRADINGVIEW_CONFIG["screenshot_interval"] > 0
        assert TRADINGVIEW_CONFIG["wait_for_chart"] > 0


class TestLMArenaConfig:
    """Test LMArena configuration"""

    def test_lmarena_urls_valid(self):
        """Test LMArena URLs are valid"""
        assert "lmarena.ai" in LMARENA_CONFIG["base_url"]
        assert "lmarena.ai" in LMARENA_CONFIG["chat_url"]

    def test_models_configured(self):
        """Test AI models are configured"""
        assert len(LMARENA_CONFIG["models"]) > 0
        assert LMARENA_CONFIG["default_model"] in LMARENA_CONFIG["models"]

    def test_selectors_complete(self):
        """Test all selectors are present"""
        required_selectors = [
            "model_dropdown", "chat_input", "send_button", "response_area"
        ]
        for selector in required_selectors:
            assert selector in LMARENA_CONFIG["selectors"]


class TestBrowserConfig:
    """Test browser configuration"""

    def test_browser_settings(self):
        """Test browser settings are valid"""
        assert isinstance(BROWSER_CONFIG["headless"], bool)
        assert "viewport" in BROWSER_CONFIG
        assert BROWSER_CONFIG["viewport"]["width"] > 0
        assert BROWSER_CONFIG["viewport"]["height"] > 0

    def test_geolocation_configured(self):
        """Test geolocation is properly configured"""
        assert "geolocation" in BROWSER_CONFIG
        assert "latitude" in BROWSER_CONFIG["geolocation"]
        assert "longitude" in BROWSER_CONFIG["geolocation"]


class TestAntiDetectConfig:
    """Test anti-detection configuration"""

    def test_user_agents_present(self):
        """Test user agents are configured"""
        assert len(ANTI_DETECT_CONFIG["user_agents"]) > 0
        for ua in ANTI_DETECT_CONFIG["user_agents"]:
            assert "Mozilla" in ua

    def test_delay_configuration(self):
        """Test delay configuration"""
        assert isinstance(ANTI_DETECT_CONFIG["random_delays"], bool)
        assert len(ANTI_DETECT_CONFIG["delay_range"]) == 2
        assert ANTI_DETECT_CONFIG["delay_range"][0] < ANTI_DETECT_CONFIG["delay_range"][1]

    def test_retry_configuration(self):
        """Test retry configuration"""
        assert ANTI_DETECT_CONFIG["max_retries"] > 0
        assert ANTI_DETECT_CONFIG["retry_delay"] > 0


class TestImageConfig:
    """Test image configuration"""

    def test_image_size_limits(self):
        """Test image size limits"""
        assert len(IMAGE_CONFIG["max_size"]) == 2
        assert IMAGE_CONFIG["max_size"][0] > 0
        assert IMAGE_CONFIG["max_size"][1] > 0

    def test_image_quality_settings(self):
        """Test image quality settings"""
        assert 0 < IMAGE_CONFIG["quality"] <= 100
        assert IMAGE_CONFIG["format"] in ["JPEG", "PNG"]


class TestTradingPrompt:
    """Test trading prompt configuration"""

    def test_prompt_not_empty(self):
        """Test trading prompt is not empty"""
        assert len(TRADING_PROMPT) > 50

    def test_prompt_contains_key_terms(self):
        """Test prompt contains key trading terms"""
        key_terms = ["chart", "trading", "forex", "XAUUSD"]
        prompt_lower = TRADING_PROMPT.lower()
        matches = sum(1 for term in key_terms if term.lower() in prompt_lower)
        assert matches >= 2  # At least 2 key terms present


class TestConfigValidation:
    """Test configuration validation"""

    def test_no_none_critical_values(self):
        """Test that critical config values are not None"""
        assert TRADINGVIEW_CONFIG is not None
        assert LMARENA_CONFIG is not None
        assert BROWSER_CONFIG is not None
        assert TRADING_PROMPT is not None

    def test_config_types(self):
        """Test configuration types are correct"""
        assert isinstance(TRADINGVIEW_CONFIG, dict)
        assert isinstance(LMARENA_CONFIG, dict)
        assert isinstance(BROWSER_CONFIG, dict)
        assert isinstance(ANTI_DETECT_CONFIG, dict)
        assert isinstance(IMAGE_CONFIG, dict)
        assert isinstance(TRADING_PROMPT, str)


if __name__ == "__main__":
    pytest.main([__file__, "-v", "--tb=short"])