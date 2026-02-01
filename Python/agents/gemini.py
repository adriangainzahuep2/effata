import asyncio
import os
import sys
import json
import re
import requests
from requests.exceptions import RequestException
from dotenv import load_dotenv
import google.genai as genai

gemini_api_key = "AIzaSyBDDUOoP0F62Jew5JaejuvUr6kHjYCC-Q8"

client = genai.Client(api_key=gemini_api_key)  # Create Gemini client
#model_name = "gemini-2.5-pro-exp-03-25"
model_name = "gemini-3-pro"

types = genai.types

# ANSI color codes


class Colors:
    CYAN = '\033[96m'
    YELLOW = '\033[93m'
    GREEN = '\033[92m'
    RED = '\033[91m'
    MAGENTA = '\033[95m'
    BLUE = '\033[94m'
    RESET = '\033[0m'

async def get_gemini_response(objective, model="gemini-3-pro"):

	prompt = f"""RESPOND ONLY WITH TEXT STRING FORMAT.
	Analyzes the content to find the most relevant answer information for : {objective}

	Remember:
        - Return EXACTLY "Objective not met" if not found
        - No other text or explanations

	Return ONLY a text string in this exact format - no other text or explanation:
	"""

	response = await client.models.generate_content(
	    model=model,
	    contents=[prompt]
	)

	result = response.text.strip()

    if result != "Objective not met":
    print(
        f"{Colors.GREEN}Objective potentially fulfilled. Relevant information identified.{Colors.RESET}")
    if '{' in result and '}' in result:
        start_idx = result.find('{')
        end_idx = result.rfind('}') + 1
        json_str = result[start_idx:end_idx]
        return json_str
    else:
        print(
            f"{Colors.RED}No string found in response{Colors.RESET}")

else:
    print(
        f"{Colors.YELLOW}Objective not met on this page. Proceeding to next link...{Colors.RESET}")

async def main():
	objective="You are a Hedge Fund like Goldman Sachs operating HFT and Institutional Trading using Central Bank Delivery Content IPDA Algorithm in Forex markets. Analize trends from high timeframes to low timefrimes, previous day high, previous day low, breaker of previous day high with high probabilities, breaker of previous weekly high with high probabilities, breaker of previous weekly low with high probabilities. Use wick pattern for entries with high volume. Analize Liquidity Sweeps in Retests Zones of prices with high probabilities. Analyze url like: https://cnbc.com, https://finviz.com for alerting from news that can be generate high impact and price movements with high volatility. Analyze if volume are high of average for looking for opportunities for entries and exits, time confluence, Multi-Timeframes, York-London Session Confluence. Only trades london session and New York Session. Analyze Liquidity Zones between sessions like London-Asia and New York and London session. Be precise. Don't hallucinate. Analize Liquidity zones where the prices could be return and sweep stop-loss of retails traders with high probabilities, Sentiment Markets Analyzer, Fibonacci Retracement OTE, correlate pairs, ICT patterns for automatic trading and recommending entries and exits with hight probabilities based in this analysis of tradingview charts of Multi-Timeframes of and London session from 1:45 AM, New York-London session, New York session. And write the code for connect to broker using Python and take action or entry to market, take profits, close partial profits or move stop-loss to breakeven or trailing stop, or exit trades based in the analysis of dynamic conditions of Forex market. Be patiente. Don't take much risk. Use dynamic risk management for generate the most high performance and the most high return with maximum of 1.9% of drawdown."
	response = await find_objective(objective)
    return response


if __name__ == "__main__":
	asyncio.run(main())