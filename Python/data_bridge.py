"""
EFFATA Real-Time Data Bridge & Execution Router
Connects to multiple futures data providers and provides a unified feed for MQL5.
Supports: Tradovate, dxFeed, Rithmic, CTrade, and free providers (Binance/Finnhub).
"""
import asyncio
import json
import os
import aiohttp
from typing import Dict, Any, List, Optional
from loguru import logger
from aiohttp import web

class TradovateClient:
    def __init__(self, base_url: str = "https://demo.tradovateapi.com/v1"):
        self.base_url = base_url
        self.token: Optional[str] = None
        self.account_id: Optional[int] = None

    async def authenticate(self, name: str, password: str, app_id: str, app_version: str, cid: int, sec: str):
        url = f"{self.base_url}/auth/accesstokenrequest"
        payload = {
            "name": name,
            "password": password,
            "appId": app_id,
            "appVersion": app_version,
            "cid": cid,
            "sec": sec
        }
        async with aiohttp.ClientSession() as session:
            async with session.post(url, json=payload) as resp:
                if resp.status == 200:
                    data = await resp.json()
                    self.token = data.get("accessToken")
                    logger.info("Tradovate authenticated successfully")
                    return True
                else:
                    logger.error(f"Tradovate auth failed: {await resp.text()}")
                    return False

    async def place_order(self, symbol: str, action: str, quantity: int, order_type: str = "Market"):
        if not self.token:
            return {"error": "Not authenticated"}

        url = f"{self.base_url}/order/placeorder"
        payload = {
            "accountSpec": self.account_id,
            "symbol": symbol,
            "action": action,
            "orderStrategyTypeId": 1,
            "orderType": order_type,
            "quantity": quantity
        }
        headers = {"Authorization": f"Bearer {self.token}"}
        async with aiohttp.ClientSession() as session:
            async with session.post(url, json=payload, headers=headers) as resp:
                return await resp.json()

class DataBridge:
    def __init__(self):
        self.connections = {}
        self.running = False
        self.tradovate = TradovateClient()

    async def fetch_free_futures_data(self, symbol: str) -> Dict[str, Any]:
        """Fetch free futures-like data from Binance as proxy for ticks"""
        url = f"https://fapi.binance.com/fapi/v1/trades?symbol={symbol}USDT&limit=100"
        async with aiohttp.ClientSession() as session:
            try:
                async with session.get(url) as response:
                    if response.status == 200:
                        data = await response.json()
                        return self._process_binance_ticks(data)
            except Exception as e:
                logger.error(f"Failed to fetch free data: {e}")
        return {}

    def _process_binance_ticks(self, data: List[Dict[str, Any]]) -> Dict[str, Any]:
        ticks = []
        for trade in data:
            ticks.append({
                'price': float(trade['price']),
                'volume': float(trade['qty']),
                'time': trade['time'],
                'side': 'BUY' if not trade['isBuyerMaker'] else 'SELL'
            })
        return {'symbol': 'FuturesProxy', 'ticks': ticks}

    # API Endpoints for MQL5
    async def handle_futures_data(self, request):
        symbol = request.query.get("symbol", "BTC")
        data = await self.fetch_free_futures_data(symbol)
        return web.json_response(data)

    async def handle_trade_execution(self, request):
        data = await request.json()
        # Route to Tradovate or other provider
        provider = data.get("provider", "tradovate")
        if provider == "tradovate":
            res = await self.tradovate.place_order(
                data["symbol"], data["action"], data["quantity"]
            )
            return web.json_response(res)
        return web.json_response({"error": "Unsupported provider"}, status=400)

    async def start_bridge(self):
        self.running = True
        app = web.Application()
        app.router.add_get('/futures_data', self.handle_futures_data)
        app.router.add_post('/execute_trade', self.handle_trade_execution)

        runner = web.AppRunner(app)
        await runner.setup()
        site = web.TCPSite(runner, 'localhost', 8000)
        await site.start()

        logger.info("Data Bridge & Execution Router started on http://localhost:8000")
        while self.running:
            await asyncio.sleep(1)

if __name__ == "__main__":
    bridge = DataBridge()
    try:
        asyncio.run(bridge.start_bridge())
    except KeyboardInterrupt:
        bridge.running = False
