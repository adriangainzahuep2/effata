"""
Comprehensive unit tests for config.py
Tests configuration settings, directory creation, and validation
"""
import pytest
from pathlib import Path
import os

import config


class TestConfigurationStructure:
    """Test configuration structure and values"""

    def test_base_dir_exists(self):
        """Test that BASE_DIR is set correctly"""
        assert config.BASE_DIR is not None
        assert isinstance(config.BASE_DIR, Path)
        assert config.BASE_DIR.exists()

    def test_output_directories_defined(self):
        """Test that output directories are defined"""
        assert config.OUTPUT_DIR is not None
        assert config.SCREENSHOTS_DIR is not None
        assert config.RESPONSES_DIR is not None
        assert config.LOGS_DIR is not None

    def test_output_directories_created(self):
        """Test that output directories are created on import"""
        assert config.OUTPUT_DIR.exists()
        assert config.SCREENSHOTS_DIR.exists()
        assert config.RESPONSES_DIR.exists()
        assert config.LOGS_DIR.exists()

    def test_output_directories_are_subdirectories(self):
        """Test that output directories are properly nested"""
        assert config.SCREENSHOTS_DIR.parent == config.OUTPUT_DIR
        assert config.RESPONSES_DIR.parent == config.OUTPUT_DIR
        assert config.LOGS_DIR.parent == config.OUTPUT_DIR


class TestTradingViewConfiguration:
    """Test TradingView configuration settings"""

    def test_tradingview_config_exists(self):
        """Test that TRADINGVIEW_CONFIG is defined"""
        assert hasattr(config, 'TRADINGVIEW_CONFIG')
        assert isinstance(config.TRADINGVIEW_CONFIG, dict)

    def test_tradingview_url(self):
        """Test TradingView URL is valid"""
        assert 'url' in config.TRADINGVIEW_CONFIG
        assert config.TRADINGVIEW_CONFIG['url'].startswith('https://')
        assert 'tradingview.com' in config.TRADINGVIEW_CONFIG['url']

    def test_tradingview_screenshot_interval(self):
        """Test screenshot interval is reasonable"""
        assert 'screenshot_interval' in config.TRADINGVIEW_CONFIG
        interval = config.TRADINGVIEW_CONFIG['screenshot_interval']
        assert isinstance(interval, int)
        assert interval > 0
        assert interval <= 3600  # Max 1 hour

    def test_tradingview_selectors(self):
        """Test that required selectors are defined"""
        assert 'chart_selector' in config.TRADINGVIEW_CONFIG
        assert 'chart_area_selector' in config.TRADINGVIEW_CONFIG
        assert isinstance(config.TRADINGVIEW_CONFIG['chart_selector'], str)

    def test_tradingview_quality_settings(self):
        """Test chart quality settings"""
        assert 'chart_quality' in config.TRADINGVIEW_CONFIG
        quality = config.TRADINGVIEW_CONFIG['chart_quality']
        assert isinstance(quality, int)
        assert 1 <= quality <= 100

    def test_tradingview_image_size(self):
        """Test maximum image size configuration"""
        assert 'max_image_size' in config.TRADINGVIEW_CONFIG
        max_size = config.TRADINGVIEW_CONFIG['max_image_size']
        assert isinstance(max_size, tuple)
        assert len(max_size) == 2
        assert all(isinstance(x, int) and x > 0 for x in max_size)


class TestLMArenaConfiguration:
    """Test LMArena configuration settings"""

    def test_lmarena_config_exists(self):
        """Test that LMARENA_CONFIG is defined"""
        assert hasattr(config, 'LMARENA_CONFIG')
        assert isinstance(config.LMARENA_CONFIG, dict)

    def test_lmarena_urls(self):
        """Test LMArena URLs are valid"""
        assert 'base_url' in config.LMARENA_CONFIG
        assert 'chat_url' in config.LMARENA_CONFIG
        assert config.LMARENA_CONFIG['base_url'].startswith('https://')
        assert config.LMARENA_CONFIG['chat_url'].startswith('https://')
        assert 'lmarena.ai' in config.LMARENA_CONFIG['base_url']

    def test_lmarena_models_list(self):
        """Test that models list is defined and not empty"""
        assert 'models' in config.LMARENA_CONFIG
        assert isinstance(config.LMARENA_CONFIG['models'], list)
        assert len(config.LMARENA_CONFIG['models']) > 0

    def test_lmarena_default_model(self):
        """Test that default model is in models list"""
        assert 'default_model' in config.LMARENA_CONFIG
        default = config.LMARENA_CONFIG['default_model']
        models = config.LMARENA_CONFIG['models']
        assert default in models

    def test_lmarena_selectors(self):
        """Test that required selectors are defined"""
        assert 'selectors' in config.LMARENA_CONFIG
        selectors = config.LMARENA_CONFIG['selectors']

        required_selectors = [
            'model_dropdown',
            'model_option',
            'chat_input',
            'send_button',
            'response_area'
        ]

        for selector_name in required_selectors:
            assert selector_name in selectors
            assert isinstance(selectors[selector_name], str)

    def test_lmarena_timeouts(self):
        """Test timeout configurations"""
        assert 'wait_timeout' in config.LMARENA_CONFIG
        assert 'response_timeout' in config.LMARENA_CONFIG

        wait_timeout = config.LMARENA_CONFIG['wait_timeout']
        response_timeout = config.LMARENA_CONFIG['response_timeout']

        assert isinstance(wait_timeout, int)
        assert isinstance(response_timeout, int)
        assert wait_timeout > 0
        assert response_timeout > 0
        assert response_timeout >= wait_timeout


class TestTradingPromptConfiguration:
    """Test trading prompt configuration"""

    def test_trading_prompt_exists(self):
        """Test that TRADING_PROMPT is defined"""
        assert hasattr(config, 'TRADING_PROMPT')
        assert isinstance(config.TRADING_PROMPT, str)
        assert len(config.TRADING_PROMPT) > 0

    def test_trading_prompt_content(self):
        """Test that trading prompt contains relevant keywords"""
        prompt = config.TRADING_PROMPT.lower()

        trading_keywords = [
            'trading', 'chart', 'forex', 'gold', 'xauusd',
            'entry', 'exit', 'support', 'resistance'
        ]

        found_keywords = sum(1 for keyword in trading_keywords if keyword in prompt)
        assert found_keywords >= 5, "Prompt should contain relevant trading terms"

    def test_trading_prompt_json_request(self):
        """Test that prompt requests JSON response"""
        assert 'json' in config.TRADING_PROMPT.lower()


class TestBrowserConfiguration:
    """Test browser configuration settings"""

    def test_browser_config_exists(self):
        """Test that BROWSER_CONFIG is defined"""
        assert hasattr(config, 'BROWSER_CONFIG')
        assert isinstance(config.BROWSER_CONFIG, dict)

    def test_browser_headless_setting(self):
        """Test headless mode configuration"""
        assert 'headless' in config.BROWSER_CONFIG
        assert isinstance(config.BROWSER_CONFIG['headless'], bool)

    def test_browser_viewport(self):
        """Test viewport configuration"""
        assert 'viewport' in config.BROWSER_CONFIG
        viewport = config.BROWSER_CONFIG['viewport']
        assert isinstance(viewport, dict)
        assert 'width' in viewport
        assert 'height' in viewport
        assert viewport['width'] > 0
        assert viewport['height'] > 0

    def test_browser_locale_settings(self):
        """Test locale and timezone settings"""
        assert 'locale' in config.BROWSER_CONFIG
        assert 'timezone_id' in config.BROWSER_CONFIG
        assert isinstance(config.BROWSER_CONFIG['locale'], str)
        assert isinstance(config.BROWSER_CONFIG['timezone_id'], str)

    def test_browser_permissions(self):
        """Test permissions configuration"""
        assert 'permissions' in config.BROWSER_CONFIG
        permissions = config.BROWSER_CONFIG['permissions']
        assert isinstance(permissions, list)

    def test_browser_geolocation(self):
        """Test geolocation configuration"""
        assert 'geolocation' in config.BROWSER_CONFIG
        geo = config.BROWSER_CONFIG['geolocation']
        assert isinstance(geo, dict)
        assert 'latitude' in geo
        assert 'longitude' in geo
        assert -90 <= geo['latitude'] <= 90
        assert -180 <= geo['longitude'] <= 180

    def test_browser_http_headers(self):
        """Test HTTP headers configuration"""
        assert 'extra_http_headers' in config.BROWSER_CONFIG
        headers = config.BROWSER_CONFIG['extra_http_headers']
        assert isinstance(headers, dict)
        assert 'Accept-Language' in headers
        assert 'Accept-Encoding' in headers


class TestAntiDetectConfiguration:
    """Test anti-detection configuration"""

    def test_anti_detect_config_exists(self):
        """Test that ANTI_DETECT_CONFIG is defined"""
        assert hasattr(config, 'ANTI_DETECT_CONFIG')
        assert isinstance(config.ANTI_DETECT_CONFIG, dict)

    def test_user_agents_list(self):
        """Test user agents list"""
        assert 'user_agents' in config.ANTI_DETECT_CONFIG
        user_agents = config.ANTI_DETECT_CONFIG['user_agents']
        assert isinstance(user_agents, list)
        assert len(user_agents) > 0

        # All user agents should be strings starting with Mozilla
        for ua in user_agents:
            assert isinstance(ua, str)
            assert 'Mozilla' in ua

    def test_anti_detect_flags(self):
        """Test anti-detection boolean flags"""
        flags = ['proxy_rotation', 'fingerprint_rotation', 'random_delays']

        for flag in flags:
            assert flag in config.ANTI_DETECT_CONFIG
            assert isinstance(config.ANTI_DETECT_CONFIG[flag], bool)

    def test_delay_range(self):
        """Test delay range configuration"""
        assert 'delay_range' in config.ANTI_DETECT_CONFIG
        delay_range = config.ANTI_DETECT_CONFIG['delay_range']
        assert isinstance(delay_range, tuple)
        assert len(delay_range) == 2
        assert delay_range[0] < delay_range[1]
        assert delay_range[0] >= 0

    def test_retry_settings(self):
        """Test retry configuration"""
        assert 'max_retries' in config.ANTI_DETECT_CONFIG
        assert 'retry_delay' in config.ANTI_DETECT_CONFIG

        max_retries = config.ANTI_DETECT_CONFIG['max_retries']
        retry_delay = config.ANTI_DETECT_CONFIG['retry_delay']

        assert isinstance(max_retries, int)
        assert isinstance(retry_delay, (int, float))
        assert max_retries > 0
        assert retry_delay > 0


class TestImageConfiguration:
    """Test image processing configuration"""

    def test_image_config_exists(self):
        """Test that IMAGE_CONFIG is defined"""
        assert hasattr(config, 'IMAGE_CONFIG')
        assert isinstance(config.IMAGE_CONFIG, dict)

    def test_image_max_size(self):
        """Test maximum image size"""
        assert 'max_size' in config.IMAGE_CONFIG
        max_size = config.IMAGE_CONFIG['max_size']
        assert isinstance(max_size, tuple)
        assert len(max_size) == 2
        assert all(x > 0 for x in max_size)

    def test_image_quality(self):
        """Test image quality setting"""
        assert 'quality' in config.IMAGE_CONFIG
        quality = config.IMAGE_CONFIG['quality']
        assert isinstance(quality, int)
        assert 1 <= quality <= 100

    def test_image_format(self):
        """Test image format setting"""
        assert 'format' in config.IMAGE_CONFIG
        image_format = config.IMAGE_CONFIG['format']
        assert isinstance(image_format, str)
        assert image_format in ['JPEG', 'PNG', 'WEBP']

    def test_imagemagick_options(self):
        """Test ImageMagick options"""
        assert 'imagemagick_options' in config.IMAGE_CONFIG
        options = config.IMAGE_CONFIG['imagemagick_options']
        assert isinstance(options, list)


class TestLoggingConfiguration:
    """Test logging configuration"""

    def test_logging_config_exists(self):
        """Test that LOGGING_CONFIG is defined"""
        assert hasattr(config, 'LOGGING_CONFIG')
        assert isinstance(config.LOGGING_CONFIG, dict)

    def test_logging_level(self):
        """Test logging level"""
        assert 'level' in config.LOGGING_CONFIG
        level = config.LOGGING_CONFIG['level']
        assert level in ['DEBUG', 'INFO', 'WARNING', 'ERROR', 'CRITICAL']

    def test_logging_format(self):
        """Test logging format"""
        assert 'format' in config.LOGGING_CONFIG
        log_format = config.LOGGING_CONFIG['format']
        assert isinstance(log_format, str)
        assert '{time' in log_format
        assert '{level' in log_format

    def test_logging_rotation(self):
        """Test log rotation settings"""
        assert 'rotation' in config.LOGGING_CONFIG
        assert 'retention' in config.LOGGING_CONFIG

        rotation = config.LOGGING_CONFIG['rotation']
        retention = config.LOGGING_CONFIG['retention']

        assert isinstance(rotation, str)
        assert isinstance(retention, str)


class TestScheduleConfiguration:
    """Test schedule configuration"""

    def test_schedule_config_exists(self):
        """Test that SCHEDULE_CONFIG is defined"""
        assert hasattr(config, 'SCHEDULE_CONFIG')
        assert isinstance(config.SCHEDULE_CONFIG, dict)

    def test_schedule_intervals(self):
        """Test schedule interval settings"""
        intervals = ['screenshot_interval', 'analysis_interval', 'cleanup_interval']

        for interval_name in intervals:
            assert interval_name in config.SCHEDULE_CONFIG
            interval = config.SCHEDULE_CONFIG[interval_name]
            assert isinstance(interval, str)
            assert any(unit in interval for unit in ['minute', 'hour', 'day'])

    def test_schedule_limits(self):
        """Test schedule limit settings"""
        assert 'max_screenshots' in config.SCHEDULE_CONFIG
        assert 'max_responses' in config.SCHEDULE_CONFIG

        max_screenshots = config.SCHEDULE_CONFIG['max_screenshots']
        max_responses = config.SCHEDULE_CONFIG['max_responses']

        assert isinstance(max_screenshots, int)
        assert isinstance(max_responses, int)
        assert max_screenshots > 0
        assert max_responses > 0


class TestSocketConfiguration:
    """Test socket server configuration"""

    def test_socket_config_exists(self):
        """Test that SOCKET_CONFIG is defined"""
        assert hasattr(config, 'SOCKET_CONFIG')
        assert isinstance(config.SOCKET_CONFIG, dict)

    def test_socket_host(self):
        """Test socket host configuration"""
        assert 'host' in config.SOCKET_CONFIG
        host = config.SOCKET_CONFIG['host']
        assert isinstance(host, str)
        assert host in ['127.0.0.1', 'localhost', '0.0.0.0'] or host.count('.') == 3

    def test_socket_port(self):
        """Test socket port configuration"""
        assert 'port' in config.SOCKET_CONFIG
        port = config.SOCKET_CONFIG['port']
        assert isinstance(port, int)
        assert 1024 <= port <= 65535

    def test_socket_buffer_size(self):
        """Test socket buffer size"""
        assert 'buffer_size' in config.SOCKET_CONFIG
        buffer_size = config.SOCKET_CONFIG['buffer_size']
        assert isinstance(buffer_size, int)
        assert buffer_size > 0


class TestConfigurationIntegrity:
    """Test overall configuration integrity"""

    def test_all_required_configs_present(self):
        """Test that all required configurations are present"""
        required_configs = [
            'TRADINGVIEW_CONFIG',
            'LMARENA_CONFIG',
            'TRADING_PROMPT',
            'BROWSER_CONFIG',
            'ANTI_DETECT_CONFIG',
            'IMAGE_CONFIG',
            'LOGGING_CONFIG',
            'SCHEDULE_CONFIG',
            'SOCKET_CONFIG'
        ]

        for config_name in required_configs:
            assert hasattr(config, config_name), f"{config_name} is missing"

    def test_no_syntax_errors(self):
        """Test that config file has no syntax errors"""
        # If we got here, the import succeeded
        assert True

    def test_config_types_consistency(self):
        """Test that configuration types are consistent"""
        # All *_CONFIG should be dictionaries
        config_vars = [name for name in dir(config) if name.endswith('_CONFIG')]

        for var_name in config_vars:
            var_value = getattr(config, var_name)
            assert isinstance(var_value, dict), f"{var_name} should be a dict"

    def test_directories_writable(self):
        """Test that output directories are writable"""
        test_file = config.OUTPUT_DIR / '.test_write'

        try:
            test_file.write_text('test')
            test_file.unlink()
            assert True
        except Exception as e:
            pytest.fail(f"Output directory not writable: {e}")


class TestConfigurationEdgeCases:
    """Test edge cases and boundary conditions"""

    def test_empty_models_list_handling(self):
        """Test behavior with empty models list"""
        # Should have at least one model
        assert len(config.LMARENA_CONFIG['models']) > 0

    def test_negative_timeout_prevention(self):
        """Test that timeouts are positive"""
        assert config.LMARENA_CONFIG['wait_timeout'] > 0
        assert config.LMARENA_CONFIG['response_timeout'] > 0
        assert config.TRADINGVIEW_CONFIG['wait_for_chart'] > 0

    def test_quality_bounds(self):
        """Test that quality settings are within valid bounds"""
        assert 0 < config.TRADINGVIEW_CONFIG['chart_quality'] <= 100
        assert 0 < config.IMAGE_CONFIG['quality'] <= 100

    def test_path_existence(self):
        """Test that all configured paths exist or can be created"""
        paths_to_check = [
            config.BASE_DIR,
            config.OUTPUT_DIR,
            config.SCREENSHOTS_DIR,
            config.RESPONSES_DIR,
            config.LOGS_DIR
        ]

        for path in paths_to_check:
            assert path.exists(), f"Path does not exist: {path}"
            assert path.is_dir(), f"Path is not a directory: {path}"