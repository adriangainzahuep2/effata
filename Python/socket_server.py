"""
Socket Server for MQL5 Communication
Acts as a bridge between MQL5 EA and Python Trading Analyzer
"""
import asyncio
import json
import socket
import threading
from typing import Dict, Any

from loguru import logger
from config import SOCKET_CONFIG, TRADING_PROMPT
from trading_analyzer import TradingAnalyzer

class MQL5SocketServer:
    def __init__(self, host=SOCKET_CONFIG["host"], port=SOCKET_CONFIG["port"]):
        self.host = host
        self.port = port
        self.server = None
        self.running = False
        self.analyzer = TradingAnalyzer()

    async def start(self):
        """Start the socket server"""
        await self.analyzer.initialize()

        self.server = await asyncio.start_server(
            self.handle_client, self.host, self.port
        )

        addr = self.server.sockets[0].getsockname()
        logger.info(f'Serving on {addr}')
        self.running = True

        async with self.server:
            await self.server.serve_forever()

    async def handle_client(self, reader, writer):
        """Handle incoming MQL5 connections"""
        addr = writer.get_extra_info('peername')
        logger.info(f"Connection from {addr}")

        try:
            data = await reader.read(SOCKET_CONFIG["buffer_size"])
            message = data.decode().strip()

            if not message:
                return

            logger.info(f"Received: {message}")

            try:
                request = json.loads(message)
                response = await self.process_request(request)
            except json.JSONDecodeError:
                response = {"error": "Invalid JSON"}

            response_str = json.dumps(response)
            logger.info(f"Sending: {response_str}")

            writer.write(response_str.encode())
            await writer.drain()

        except Exception as e:
            logger.error(f"Error handling client: {e}")
        finally:
            writer.close()
            await writer.wait_closed()

    async def process_request(self, request: Dict[str, Any]) -> Dict[str, Any]:
        """Process requests from MQL5"""
        action = request.get("action")

        if action == "analyze_chart":
            model = request.get("model")
            prompt = request.get("prompt") # Extract custom prompt
            logger.info(f"Analyzing chart with model: {model}")

            result = await self.analyzer.capture_and_analyze(
                models=[model] if model else None,
                custom_prompt=prompt
            )

            if result["success"] and result["analyses"]:
                # Extract the first analysis result
                analysis = result["analyses"][0]
                return {
                    "status": "success",
                    "signal": self._parse_signal(analysis.get("response", "")),
                    "raw_response": analysis.get("response", "")
                }
            else:
                return {"status": "error", "message": result.get("error", "Analysis failed")}

        elif action == "evaluate_script":
            script = request.get("script")
            logger.info(f"Evaluating script: {script[:50]}...")
            # Use anti_detect_browser or similar to execute script
            # For simplicity, we assume TradingAnalyzer has a browser instance
            try:
                # This is a hypothetical call to the browser in analyzer
                # If using Playwright in analyzer:
                if hasattr(self.analyzer, "browser") and self.analyzer.browser:
                    page = self.analyzer.browser.pages[0] if self.analyzer.browser.pages else await self.analyzer.browser.new_page()
                    result = await page.evaluate(script)
                    return {"status": "success", "result": str(result)}
                else:
                    return {"status": "error", "message": "Browser not initialized in analyzer"}
            except Exception as e:
                return {"status": "error", "message": str(e)}

        elif action == "ping":
            return {"status": "success", "message": "pong"}

        return {"status": "error", "message": "Unknown action"}

    def _parse_signal(self, response_text: str) -> Dict[str, Any]:
        """Best effort parsing of the AI text response into structured signal"""
        signal_data = {"action": "NONE", "confidence": 0.0, "reason": ""}

        try:
            # Try to find JSON block in response
            import re
            json_match = re.search(r'\{.*\}', response_text, re.DOTALL)
            if json_match:
                try:
                    data = json.loads(json_match.group(0))
                    signal_data.update(data)
                    return signal_data
                except:
                    pass

            # Fallback text parsing
            upper_text = response_text.upper()
            if "BUY" in upper_text:
                signal_data["action"] = "BUY"
                signal_data["confidence"] = 0.8
            elif "SELL" in upper_text:
                signal_data["action"] = "SELL"
                signal_data["confidence"] = 0.8

            signal_data["reason"] = response_text[:200]

        except Exception as e:
            logger.error(f"Error parsing signal: {e}")

        return signal_data

async def start_socket_server():
    server = MQL5SocketServer()
    await server.start()

if __name__ == "__main__":
    from utils import setup_logging
    setup_logging("INFO")
    try:
        asyncio.run(start_socket_server())
    except KeyboardInterrupt:
        pass
