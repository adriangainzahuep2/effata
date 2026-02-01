import os
import json
from dotenv import load_dotenv
import requests

# ANSI color codes
class Colors:
    CYAN = '\033[96m'
    YELLOW = '\033[93m'
    GREEN = '\033[92m'
    RED = '\033[91m'
    MAGENTA = '\033[95m'
    BLUE = '\033[94m'
    RESET = '\033[0m'

# Load environment variables
load_dotenv()

# Retrieve API keys from environment variables
grok_api_key = os.getenv("GROK_API_KEY")


# Function to make Grok API calls
async def grok_completion(prompt):
    url = "https://api.x.ai/v1/chat/completions"
    headers = {
        "Content-Type": "application/json",
        "Authorization": f"Bearer {grok_api_key}"
    }
    data = {
        "messages": [
            {
                "role": "system",
                "content": "You are a helpful assistant."
            },
            {
                "role": "user",
                "content": prompt
            }
        ],
        "model": "grok-4.1-thinking",
        "stream": False,
        "temperature": 0
    }
    response = await requests.post(url, headers=headers, json=data)
    return response.json()['choices'][0]['message']['content']

# Find the page that most likely contains the objective
async def get_groq_response(objective):
    try:
        print(f"{Colors.CYAN}Understood. The objective is: {objective}{Colors.RESET}")

        prompt = f"""RESPOND ONLY WITH JSON.
        Analyzes the content to find the most relevant answer information for : {objective}

        Remember:
            - Return valid JSON if information is found
            - Return EXACTLY "Objective not met" if not found
            - No other text or explanations

        Return ONLY a JSON array in this exact format - no other text or explanation:
        """

        print(f"{Colors.YELLOW}Analyzing objective to determine optimal search parameter...{Colors.RESET}")
        response = await grok_completion(prompt)
        result = json.dumps(response, indent=2)
        return result

    except Exception as e:
        print(f"{Colors.RED}Error encountered during relevant page identification: {str(e)}{Colors.RESET}")
        return None

# Main function to execute the process
async def main():
    # Find the relevant objective
    result = await get_groq_response(objective)
    return result

if __name__ == "__main__":
    asyncio.run(main())
