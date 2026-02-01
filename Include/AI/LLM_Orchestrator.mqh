//+------------------------------------------------------------------+
//| LLM_Orchestrator.mqh                                             |
//| Advanced LLM Orchestrator for Trading Decision Making            |
//| Copyright 2025, QuantEdge Institutional Systems                  |
//+------------------------------------------------------------------+
#property copyright "2025, QuantEdge Institutional Systems"
#property version   "2.0"
#property strict

#ifndef LLM_ORCHESTRATOR_MQH
#define LLM_ORCHESTRATOR_MQH

#include <Trade/Trade.mqh>
#include <Arrays/ArrayObj.mqh>
#include <Math/Stat/Math.mqh>
#include "../Environments/RiskManagementEnv.mqh"
#include "../Calendar/EconomicCalendar.mqh"
#include "../MarketContext/MarketContextAnalyzer.mqh"
#include "../Core/AI_JSON_FILE.mqh"

// Model Configuration and Capabilities
enum ENUM_MODEL_TYPE {
    MODEL_DEEPSEEK_V32,
    MODEL_QWEN3_MAX,
    MODEL_GROK_41,
    MODEL_CLAUDE_OPUS_45,
    MODEL_GEMINI_3PRO,
    MODEL_MINIMAX_21,
    MODEL_GPT_52_HIGH,
    MODEL_COUNT
};

enum MODEL_CAPABILITY {
    CAPABILITY_CHART_ANALYSIS     = 1 << 0,
    CAPABILITY_NEWS_ANALYSIS      = 1 << 1,
    CAPABILITY_SENTIMENT_ANALYSIS = 1 << 2,
    CAPABILITY_RISK_ASSESSMENT    = 1 << 3,
    CAPABILITY_TRADE_EXECUTION    = 1 << 4,
    CAPABILITY_MARKET_FORECASTING = 1 << 5
};

struct LLMModelConfig {
    string name;
    string apiEndpoint;
    string apiKey;
    int capabilities;
    double confidenceThreshold;
    int maxTokens;
    bool isActive;
    datetime lastUsed;
};

struct LLMResponse {
    string modelUsed;
    string rawResponse;
    int action;                  // BUY_SIGNAL, SELL_SIGNAL, NO_SIGNAL
    double confidence;
    double tpPrice;
    double slPrice;
    string reasoning;
    datetime timestamp;
    double latency;
    string marketContext;
};

class CLLMOrchestrator {
private:
    LLMModelConfig m_models[MODEL_COUNT];
    CMarketContextAnalyzer* m_contextAnalyzer;
    CRiskManagementEnv* m_riskManager;
    CEconomicCalendar* m_calendar;
    CTrade* m_trade;
    string m_tradingPair;
    int m_retryCount;

    // Cache for model responses to avoid duplicate calls
    CArrayObj* m_responseCache;

    // Connection management
    bool m_isConnected;
    datetime m_lastReconnectAttempt;

    // Throttling protection
    datetime m_lastRequestTime[MODEL_COUNT];
    int m_requestCounter[MODEL_COUNT];

public:
    CLLMOrchestrator();
    ~CLLMOrchestrator();

    bool Initialize(string tradingPair);
    void ConfigureModel(ENUM_MODEL_TYPE modelType, string apiKey, bool isActive = true);
    LLMResponse GetConsensusDecision(MqlRates &rates[], double atrValue);

    bool ExecuteTrade(int action, double volume, double sl, double tp);
    void UpdateMarketContext();
    void SetRiskManager(CRiskManagementEnv* riskManager);

    // System health monitoring
    bool IsModelHealthy(ENUM_MODEL_TYPE modelType);
    void ReconnectAllModels();

private:
    void SetupDefaultModels();
    LLMResponse GetModelDecision(ENUM_MODEL_TYPE modelType, MqlRates &rates[], double atrValue);
    string BuildPromptForModel(ENUM_MODEL_TYPE modelType, MqlRates &rates[], double atrValue);
    LLMResponse ParseModelResponse(string response, ENUM_MODEL_TYPE modelType, double latency);
    double CalculateConsensusConfidence(LLMResponse responses[], int count);
    LLMResponse AggregateResponses(LLMResponse responses[], int count);
    bool ValidateTradeSignal(LLMResponse &response, MqlRates &rates[]);
    string ConvertActionToString(int action);
    int ConvertStringToAction(string actionStr);
    bool CheckModelThrottling(ENUM_MODEL_TYPE modelType);
    void ResetModelThrottling(ENUM_MODEL_TYPE modelType);

    // Connection handling methods
    bool ConnectToModelAPI(ENUM_MODEL_TYPE modelType);
    void HandleAPIError(ENUM_MODEL_TYPE modelType, int errorCode);
    string GetModelEndpoint(ENUM_MODEL_TYPE modelType);

    // Risk-aware decision filtering
    void ApplyRiskFilters(LLMResponse &response);
};

CLLMOrchestrator::CLLMOrchestrator() {
    m_contextAnalyzer = new CMarketContextAnalyzer();
    m_calendar = new CEconomicCalendar();
    m_trade = new CTrade();
    m_retryCount = 3;
    m_responseCache = new CArrayObj();
    m_isConnected = false;

    // Initialize request tracking
    for(int i = 0; i < MODEL_COUNT; i++) {
        m_lastRequestTime[i] = 0;
        m_requestCounter[i] = 0;
    }

    SetupDefaultModels();
}

CLLMOrchestrator::~CLLMOrchestrator() {
    if(m_contextAnalyzer) delete m_contextAnalyzer;
    if(m_calendar) delete m_calendar;
    if(m_trade) delete m_trade;
    if(m_responseCache) delete m_responseCache;
}

void CLLMOrchestrator::SetupDefaultModels() {
    // Configure all available LLM models with their capabilities
    m_models[MODEL_DEEPSEEK_V32].name = "deepseek-v3.2";
    m_models[MODEL_DEEPSEEK_V32].capabilities = CAPABILITY_CHART_ANALYSIS | CAPABILITY_SENTIMENT_ANALYSIS | CAPABILITY_RISK_ASSESSMENT;
    m_models[MODEL_DEEPSEEK_V32].confidenceThreshold = 0.75;
    m_models[MODEL_DEEPSEEK_V32].maxTokens = 8192;
    m_models[MODEL_DEEPSEEK_V32].isActive = false;

    m_models[MODEL_QWEN3_MAX].name = "qwen3-max";
    m_models[MODEL_QWEN3_MAX].capabilities = CAPABILITY_CHART_ANALYSIS | CAPABILITY_NEWS_ANALYSIS | CAPABILITY_MARKET_FORECASTING;
    m_models[MODEL_QWEN3_MAX].confidenceThreshold = 0.80;
    m_models[MODEL_QWEN3_MAX].maxTokens = 32768;
    m_models[MODEL_QWEN3_MAX].isActive = false;

    m_models[MODEL_GROK_41].name = "grok-4.1-thinking";
    m_models[MODEL_GROK_41].capabilities = CAPABILITY_CHART_ANALYSIS | CAPABILITY_SENTIMENT_ANALYSIS | CAPABILITY_TRADE_EXECUTION;
    m_models[MODEL_GROK_41].confidenceThreshold = 0.70;
    m_models[MODEL_GROK_41].maxTokens = 16384;
    m_models[MODEL_GROK_41].isActive = false;

    m_models[MODEL_CLAUDE_OPUS_45].name = "claude-opus-4-5-20251101-thinking-32k";
    m_models[MODEL_CLAUDE_OPUS_45].capabilities = CAPABILITY_CHART_ANALYSIS | CAPABILITY_NEWS_ANALYSIS | CAPABILITY_SENTIMENT_ANALYSIS | CAPABILITY_RISK_ASSESSMENT | CAPABILITY_TRADE_EXECUTION | CAPABILITY_MARKET_FORECASTING;
    m_models[MODEL_CLAUDE_OPUS_45].confidenceThreshold = 0.85;
    m_models[MODEL_CLAUDE_OPUS_45].maxTokens = 32000;
    m_models[MODEL_CLAUDE_OPUS_45].isActive = false;

    m_models[MODEL_GEMINI_3PRO].name = "gemini-3-pro";
    m_models[MODEL_GEMINI_3PRO].capabilities = CAPABILITY_CHART_ANALYSIS | CAPABILITY_NEWS_ANALYSIS | CAPABILITY_SENTIMENT_ANALYSIS;
    m_models[MODEL_GEMINI_3PRO].confidenceThreshold = 0.78;
    m_models[MODEL_GEMINI_3PRO].maxTokens = 128000;
    m_models[MODEL_GEMINI_3PRO].isActive = false;

    m_models[MODEL_MINIMAX_21].name = "minimax-2.1-preview";
    m_models[MODEL_MINIMAX_21].capabilities = CAPABILITY_CHART_ANALYSIS | CAPABILITY_RISK_ASSESSMENT;
    m_models[MODEL_MINIMAX_21].confidenceThreshold = 0.72;
    m_models[MODEL_MINIMAX_21].maxTokens = 16384;
    m_models[MODEL_MINIMAX_21].isActive = false;

    m_models[MODEL_GPT_52_HIGH].name = "gpt-5.2-high";
    m_models[MODEL_GPT_52_HIGH].capabilities = CAPABILITY_CHART_ANALYSIS | CAPABILITY_NEWS_ANALYSIS | CAPABILITY_SENTIMENT_ANALYSIS | CAPABILITY_RISK_ASSESSMENT | CAPABILITY_TRADE_EXECUTION | CAPABILITY_MARKET_FORECASTING;
    m_models[MODEL_GPT_52_HIGH].confidenceThreshold = 0.88;
    m_models[MODEL_GPT_52_HIGH].maxTokens = 64000;
    m_models[MODEL_GPT_52_HIGH].isActive = false;
}

bool CLLMOrchestrator::Initialize(string tradingPair) {
    m_tradingPair = tradingPair;
    m_trade.PositionOpen = m_tradingPair;

    // Initialize context analyzer with current market pair
    if(!m_contextAnalyzer.Initialize(m_tradingPair)) {
        Print("Failed to initialize market context analyzer");
        return false;
    }

    // Update calendar data
    if(!m_calendar.UpdateCalendar()) {
        Print("Warning: Could not update economic calendar");
    }

    // Reconnect to all active models
    ReconnectAllModels();

    return m_isConnected;
}

void CLLMOrchestrator::ConfigureModel(ENUM_MODEL_TYPE modelType, string apiKey, bool isActive) {
    if(modelType < 0 || modelType >= MODEL_COUNT) return;

    m_models[modelType].apiKey = apiKey;
    m_models[modelType].isActive = isActive;

    // Set API endpoints based on model type
    switch(modelType) {
        case MODEL_DEEPSEEK_V32:
            m_models[modelType].apiEndpoint = "https://api.deepseek.com/v1/chat/completions";
            break;
        case MODEL_QWEN3_MAX:
            m_models[modelType].apiEndpoint = "https://dashscope.aliyuncs.com/api/v1/services/aigc/text-generation/generation";
            break;
        case MODEL_GROK_41:
            m_models[modelType].apiEndpoint = "https://api.x.ai/v1/chat/completions";
            break;
        case MODEL_CLAUDE_OPUS_45:
            m_models[modelType].apiEndpoint = "https://api.anthropic.com/v1/messages";
            break;
        case MODEL_GEMINI_3PRO:
            m_models[modelType].apiEndpoint = "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-pro:generateContent";
            break;
        case MODEL_MINIMAX_21:
            m_models[modelType].apiEndpoint = "https://api.minimax.chat/v1/text/chatcompletion_pro";
            break;
        case MODEL_GPT_52_HIGH:
            m_models[modelType].apiEndpoint = "https://api.openai.com/v1/chat/completions";
            break;
    }
}

bool CLLMOrchestrator::CheckModelThrottling(ENUM_MODEL_TYPE modelType) {
    datetime now = TimeCurrent();
    int minutesSinceLastRequest = (int)((now - m_lastRequestTime[modelType]) / 60);

    // Reset counter if more than 1 minute has passed
    if(minutesSinceLastRequest >= 1) {
        m_requestCounter[modelType] = 0;
    }

    // Check if we've exceeded request limits (model-specific)
    int maxRequestsPerMinute = 30; // Default limit

    switch(modelType) {
        case MODEL_DEEPSEEK_V32:
        case MODEL_QWEN3_MAX:
            maxRequestsPerMinute = 60;
            break;
        case MODEL_GROK_41:
        case MODEL_CLAUDE_OPUS_45:
            maxRequestsPerMinute = 20;
            break;
        case MODEL_GEMINI_3PRO:
            maxRequestsPerMinute = 15;
            break;
        case MODEL_MINIMAX_21:
            maxRequestsPerMinute = 40;
            break;
        case MODEL_GPT_52_HIGH:
            maxRequestsPerMinute = 10; // GPT has strictest limits
            break;
    }

    if(m_requestCounter[modelType] >= maxRequestsPerMinute) {
        PrintFormat("Model %s throttled: %d requests in last minute",
                   m_models[modelType].name, m_requestCounter[modelType]);
        return false;
    }

    // Increment counter and update timestamp
    m_requestCounter[modelType]++;
    m_lastRequestTime[modelType] = now;
    return true;
}

LLMResponse CLLMOrchestrator::GetConsensusDecision(MqlRates &rates[], double atrValue) {
    LLMResponse consensus;
    ZeroMemory(consensus);

    // Update market context before analysis
    UpdateMarketContext();

    // Get responses from all active models
    LLMResponse responses[MODEL_COUNT];
    int validResponses = 0;

    for(int i = 0; i < MODEL_COUNT; i++) {
        ENUM_MODEL_TYPE modelType = (ENUM_MODEL_TYPE)i;

        if(!m_models[i].isActive) continue;

        // Check if model is healthy and not throttled
        if(!IsModelHealthy(modelType) || !CheckModelThrottling(modelType)) {
            continue;
        }

        // Get model decision
        responses[validResponses] = GetModelDecision(modelType, rates, atrValue);

        // Only count valid responses with sufficient confidence
        if(responses[validResponses].confidence > m_models[i].confidenceThreshold) {
            validResponses++;
        }
    }

    // Fallback if no valid responses
    if(validResponses == 0) {
        consensus.action = NO_SIGNAL;
        consensus.confidence = 0.0;
        consensus.reasoning = "No valid model responses or confidence too low";
        return consensus;
    }

    // Calculate consensus decision
    consensus = AggregateResponses(responses, validResponses);

    // Apply risk management filters
    ApplyRiskFilters(consensus);

    // Validate the final signal
    if(!ValidateTradeSignal(consensus, rates)) {
        consensus.action = NO_SIGNAL;
        consensus.confidence = 0.0;
        consensus.reasoning = "Signal rejected by risk management validation";
    }

    return consensus;
}

LLMResponse CLLMOrchestrator::GetModelDecision(ENUM_MODEL_TYPE modelType, MqlRates &rates[], double atrValue) {
    LLMResponse response;
    ZeroMemory(response);
    response.modelUsed = m_models[modelType].name;
    response.timestamp = TimeCurrent();

    datetime startTime = GetMicrosecondCount();

    // Build prompt for the specific model
    string prompt = BuildPromptForModel(modelType, rates, atrValue);

    // Create JSON payload for API request
    string jsonPayload = "{";

    switch(modelType) {
        case MODEL_CLAUDE_OPUS_45:
            jsonPayload += "\"model\": \"claude-opus-4-5-20251101-thinking-32k\",";
            jsonPayload += "\"max_tokens\": " + (string)m_models[modelType].maxTokens + ",";
            jsonPayload += "\"temperature\": 0.3,";
            jsonPayload += "\"system\": \"You are an expert forex trading AI that provides precise, risk-aware trading signals.\",";
            jsonPayload += "\"messages\": [{\"role\": \"user\", \"content\": \"" + StringReplace(prompt, "\"", "\\\"", 0) + "\"}]";
            break;

        case MODEL_GPT_52_HIGH:
            jsonPayload += "\"model\": \"gpt-5.2-high\",";
            jsonPayload += "\"messages\": [{\"role\": \"system\", \"content\": \"You are an expert forex trading AI that provides precise, risk-aware trading signals.\"},";
            jsonPayload += "{\"role\": \"user\", \"content\": \"" + StringReplace(prompt, "\"", "\\\"", 0) + "\"}],";
            jsonPayload += "\"temperature\": 0.2,";
            jsonPayload += "\"max_tokens\": " + (string)m_models[modelType].maxTokens;
            break;

        case MODEL_GEMINI_3PRO:
            jsonPayload += "\"contents\": [{\"role\": \"user\", \"parts\": [{\"text\": \"" + StringReplace(prompt, "\"", "\\\"", 0) + "\"}]}],";
            jsonPayload += "\"generationConfig\": {\"temperature\": 0.25, \"maxOutputTokens\": " + (string)m_models[modelType].maxTokens + "}";
            break;

        default:
            // Default format for other models
            jsonPayload += "\"model\": \"" + m_models[modelType].name + "\",";
            jsonPayload += "\"messages\": [{\"role\": \"user\", \"content\": \"" + StringReplace(prompt, "\"", "\\\"", 0) + "\"}],";
            jsonPayload += "\"temperature\": 0.3,";
            jsonPayload += "\"max_tokens\": " + (string)m_models[modelType].maxTokens;
    }

    jsonPayload += "}";

    // Prepare headers
    string headers = "";
    switch(modelType) {
        case MODEL_DEEPSEEK_V32:
            headers = "Authorization: Bearer " + m_models[modelType].apiKey + "\r\nContent-Type: application/json";
            break;
        case MODEL_QWEN3_MAX:
            headers = "Authorization: Bearer " + m_models[modelType].apiKey + "\r\nContent-Type: application/json";
            break;
        case MODEL_GROK_41:
            headers = "Authorization: Bearer " + m_models[modelType].apiKey + "\r\nContent-Type: application/json";
            break;
        case MODEL_CLAUDE_OPUS_45:
            headers = "x-api-key: " + m_models[modelType].apiKey + "\r\nanthropic-version: 2023-06-01\r\nContent-Type: application/json";
            break;
        case MODEL_GEMINI_3PRO:
            // API key appended to URL for Gemini
            break;
        case MODEL_MINIMAX_21:
            headers = "Authorization: Bearer " + m_models[modelType].apiKey + "\r\nContent-Type: application/json";
            break;
        case MODEL_GPT_52_HIGH:
            headers = "Authorization: Bearer " + m_models[modelType].apiKey + "\r\nContent-Type: application/json";
            break;
    }

    // Execute API call
    char data[], resultData[];
    string resultHeaders = "";
    string requestUrl = GetModelEndpoint(modelType);

    // For Gemini, API key is in the URL
    if(modelType == MODEL_GEMINI_3PRO) {
        requestUrl += "?key=" + m_models[modelType].apiKey;
    }

    // Make the request
    int statusCode = 0;
    int retryCount = 0;
    bool requestSuccess = false;

    while(retryCount < m_retryCount && !requestSuccess) {
        ResetLastError();
        statusCode = WebRequest("POST", requestUrl, headers, 15000, data, jsonPayload, resultData, resultHeaders);

        if(statusCode == 200) {
            requestSuccess = true;
        } else {
            int error = GetLastError();
            HandleAPIError(modelType, statusCode);

            // Exponential backoff for retries
            Sleep((int)MathPow(2, retryCount) * 1000);
            retryCount++;
        }
    }

    // Calculate latency in milliseconds
    response.latency = (GetMicrosecondCount() - startTime) / 1000.0;

    if(!requestSuccess || statusCode != 200) {
        response.action = NO_SIGNAL;
        response.confidence = 0.0;
        response.reasoning = "API request failed with status: " + (string)statusCode + " | Error: " + (string)GetLastError();
        Print("LLM API Error for ", m_models[modelType].name, ": ", response.reasoning);
        return response;
    }

    // Parse the JSON response
    string jsonResponse =CharArrayToString(resultData);
    response = ParseModelResponse(jsonResponse, modelType, response.latency);

    // Log the model usage
    m_models[modelType].lastUsed = TimeCurrent();

    return response;
}

string CLLMOrchestrator::BuildPromptForModel(ENUM_MODEL_TYPE modelType, MqlRates &rates[], double atrValue) {
    // Get market context
    string marketContext = m_contextAnalyzer.GetMarketContext();
    EconomicEvent nextEvent = m_calendar.GetNextHighImpactEvent();
    string eventContext = "";

    if(nextEvent.time > 0 && nextEvent.time - TimeCurrent() < 3600) { // Event in next hour
        eventContext = StringFormat("\nHIGH IMPACT EVENT IMMINENT:\nEvent: %s\nCurrency: %s\nExpected Time: %s\nForecast: %s\nPrevious: %s\n",
            nextEvent.title, nextEvent.currency, TimeToString(nextEvent.time), nextEvent.forecast, nextEvent.previous);
    }

    // Get technical indicators
    double rsi = iRSI(m_tradingPair, PERIOD_CURRENT, 14, PRICE_CLOSE, 0);
    double macdMain = iMACD(m_tradingPair, PERIOD_CURRENT, 12, 26, 9, PRICE_CLOSE, MODE_MAIN, 0);
    double macdSignal = iMACD(m_tradingPair, PERIOD_CURRENT, 12, 26, 9, PRICE_CLOSE, MODE_SIGNAL, 0);
    double stochK = iStochastic(m_tradingPair, PERIOD_CURRENT, 5, 3, 3, MODE_SMA, STO_LOWHIGH, MODE_MAIN, 0);
    double stochD = iStochastic(m_tradingPair, PERIOD_CURRENT, 5, 3, 3, MODE_SMA, STO_LOWHIGH, MODE_SIGNAL, 0);

    // Build candlestick data for the last 50 periods
    string candles = "\"candles\": [\n";
    int count = MathMin(50, ArraySize(rates));

    for(int i = count-1; i >= 0; i--) {
        candles += StringFormat("{\"time\": \"%s\", \"open\": %.5f, \"high\": %.5f, \"low\": %.5f, \"close\": %.5f, \"volume\": %.0f}",
            TimeToString(rates[i].time, TIME_DATE|TIME_MINUTES),
            rates[i].open,
            rates[i].high,
            rates[i].low,
            rates[i].close,
            rates[i].tick_volume
        );

        if(i > 0) candles += ",";
        candles += "\n";
    }
    candles += "]";

    // Account risk context
    double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    double equity = AccountInfoDouble(ACCOUNT_EQUITY);
    double margin = AccountInfoDouble(ACCOUNT_MARGIN);
    double marginLevel = AccountInfoDouble(ACCOUNT_MARGIN_LEVEL);
    double riskExposure = (margin / equity) * 100.0;

    // Build prop firm context
    string propFirmContext = "";
    if(m_riskManager) {
        PropFirmRules rules = m_riskManager.GetPropFirmRules();
        propFirmContext = StringFormat(
            "\nTRADE CONSTRAINTS:\nMax Daily Loss: %.2f%%\nMax Trailing Drawdown: %.2f%%\nMax Position Size: %.2f lots\nMax Correlation Exposure: %.2f%%\nAccount Phase: %s",
            rules.maxDailyLoss * 100,
            rules.maxTrailingDrawdown * 100,
            rules.maxPositionSize,
            rules.maxCorrelationExposure * 100,
            EnumToString(rules.accountPhase)
        );
    }

    // Build model-specific prompt
    string prompt = "";

    // Base prompt structure for all models
    string basePrompt = StringFormat(
        "You are an institutional-grade forex trading AI that makes precise, risk-aware decisions. Current market: %s\n\n" +
        "TECHNICAL INDICATORS:\nRSI(14): %.2f\nMACD: %.5f (Main), %.5f (Signal)\nStochastic: %.2f%% (K), %.2f%% (D)\nATR(14): %.5f\n\n" +
        "%s\n\n%s\n\n%s\n\n" +
        "ACCOUNT CONTEXT:\nBalance: $%.2f\nEquity: $%.2f\nMargin Level: %.2f%%\nRisk Exposure: %.2f%%\n\n" +
        "CHART DATA:\n%s\n\n" +
        "TASK: Analyze the chart and market context. Provide a JSON response with the following structure:\n" +
        "{\n" +
        "  \"action\": \"BUY\" or \"SELL\" or \"HOLD\",\n" +
        "  \"confidence\": 0.0 to 1.0,\n" +
        "  \"take_profit\": number (price level),\n" +
        "  \"stop_loss\": number (price level),\n" +
        "  \"reasoning\": \"concise explanation of decision factors\"\n" +
        "}\n\n" +
        "CRITICAL RULES:\n" +
        "1. If HIGH IMPACT EVENT is imminent, default to HOLD unless you have extremely high confidence (>0.95)\n" +
        "2. Stop loss must be at least 1.5x ATR away from entry\n" +
        "3. Take profit must be at least 2x stop loss distance (minimum 1:2 risk-reward)\n" +
        "4. If account risk exposure > 30%, default to HOLD\n" +
        "5. NEVER suggest trades that violate prop firm rules if provided\n",
        m_tradingPair,
        rsi, macdMain, macdSignal, stochK, stochD, atrValue,
        marketContext,
        eventContext,
        propFirmContext,
        accountBalance, equity, marginLevel, riskExposure,
        candles
    );

    // Model-specific adjustments
    switch(modelType) {
        case MODEL_CLAUDE_OPUS_45:
            prompt = "Human: " + basePrompt + "\n\nAssistant: Here is my analysis in JSON format:\n{";
            break;

        case MODEL_GEMINI_3PRO:
            prompt = basePrompt + "\n\nRespond with ONLY valid JSON, no other text. Start with {\n";
            break;

        case MODEL_GROK_41:
            prompt = basePrompt + "\n\nProvide your analysis in strict JSON format without any additional commentary. Start with {\n";
            break;

        default:
            prompt = basePrompt + "\n\nRespond with ONLY valid JSON. Start with {\n";
    }

    return prompt;
}

LLMResponse CLLMOrchestrator::ParseModelResponse(string response, ENUM_MODEL_TYPE modelType, double latency) {
    LLMResponse result;
    ZeroMemory(result);
    result.modelUsed = m_models[modelType].name;
    result.latency = latency;
    result.timestamp = TimeCurrent();
    result.rawResponse = response;

    // Clean response (remove any non-JSON text before/after actual JSON)
    int jsonStart = StringFind(response, "{");
    int jsonEnd = StringFind(response, "}", 0, 1) + 1; // Find last }

    if(jsonStart >= 0 && jsonEnd > jsonStart) {
        response = StringSubstr(response, jsonStart, jsonEnd - jsonStart);
    }

    // Parse JSON response
    char jsonChars[];
    int len = StringToCharArray(response, jsonChars);
    int index = 0;

    JsonValue json;
    if(!json.DeserializeFromArray(jsonChars, len, index)) {
        result.action = NO_SIGNAL;
        result.confidence = 0.0;
        result.reasoning = "Failed to parse JSON response: " + response;
        return result;
    }

    // Extract action
    string actionStr = json["action"].ToString();
    result.action = ConvertStringToAction(actionStr);

    // Extract confidence
    result.confidence = json["confidence"].ToDouble();

    // Extract take profit and stop loss
    result.tpPrice = json["take_profit"].ToDouble();
    result.slPrice = json["stop_loss"].ToDouble();

    // Extract reasoning
    result.reasoning = json["reasoning"].ToString();
    result.marketContext = m_contextAnalyzer.GetMarketContextSummary();

    return result;
}

int CLLMOrchestrator::ConvertStringToAction(string actionStr) {
    StringToLower(actionStr);

    if(StringFind(actionStr, "buy") >= 0 || StringFind(actionStr, "long") >= 0) {
        return BUY_SIGNAL;
    } else if(StringFind(actionStr, "sell") >= 0 || StringFind(actionStr, "short") >= 0) {
        return SELL_SIGNAL;
    } else {
        return NO_SIGNAL;
    }
}

LLMResponse CLLMOrchestrator::AggregateResponses(LLMResponse responses[], int count) {
    LLMResponse consensus;
    ZeroMemory(consensus);

    // Weight models by their historical accuracy and capabilities
    double weights[] = {0.15, 0.12, 0.10, 0.25, 0.18, 0.08, 0.12}; // Base weights

    // Adjust weights based on current market conditions
    string marketRegime = m_contextAnalyzer.GetMarketRegime();
    if(marketRegime == "HIGH_VOLATILITY") {
        // In high volatility, give more weight to risk-aware models
        weights[MODEL_CLAUDE_OPUS_45] += 0.10;
        weights[MODEL_GPT_52_HIGH] += 0.08;
        weights[MODEL_DEEPSEEK_V32] += 0.05;
    } else if(marketRegime == "LOW_VOLATILITY") {
        // In low volatility, give more weight to predictive models
        weights[MODEL_QWEN3_MAX] += 0.10;
        weights[MODEL_GEMINI_3PRO] += 0.08;
    }

    // Normalize weights
    double totalWeight = 0;
    for(int i = 0; i < count; i++) {
        totalWeight += weights[i];
    }

    if(totalWeight > 0) {
        for(int i = 0; i < count; i++) {
            weights[i] /= totalWeight;
        }
    }

    // Calculate weighted consensus
    double buyScore = 0.0;
    double sellScore = 0.0;
    double holdScore = 0.0;
    double totalConfidence = 0.0;
    double weightedConfidence = 0.0;
    double weightedTP = 0.0;
    double weightedSL = 0.0;
    string combinedReasoning = "";

    for(int i = 0; i < count; i++) {
        double weight = weights[i];
        totalConfidence += responses[i].confidence;
        weightedConfidence += responses[i].confidence * weight;

        switch(responses[i].action) {
            case BUY_SIGNAL:
                buyScore += responses[i].confidence * weight;
                break;
            case SELL_SIGNAL:
                sellScore += responses[i].confidence * weight;
                break;
            default:
                holdScore += responses[i].confidence * weight;
        }

        if(responses[i].tpPrice != 0) weightedTP += responses[i].tpPrice * weight;
        if(responses[i].slPrice != 0) weightedSL += responses[i].slPrice * weight;

        combinedReasoning += StringFormat("[%s] %s | Confidence: %.2f | Latency: %.1fms\n",
            responses[i].modelUsed,
            responses[i].reasoning,
            responses[i].confidence,
            responses[i].latency);
    }

    // Determine consensus action
    if(buyScore > sellScore && buyScore > holdScore && buyScore > 0.5) {
        consensus.action = BUY_SIGNAL;
    } else if(sellScore > buyScore && sellScore > holdScore && sellScore > 0.5) {
        consensus.action = SELL_SIGNAL;
    } else {
        consensus.action = NO_SIGNAL;
    }

    consensus.confidence = weightedConfidence;
    consensus.tpPrice = weightedTP;
    consensus.slPrice = weightedSL;
    consensus.reasoning = StringFormat("Consensus: %.2f BUY | %.2f SELL | %.2f HOLD\nWeighted Confidence: %.2f\nModel reasoning:\n%s",
        buyScore, sellScore, holdScore, weightedConfidence, combinedReasoning);

    return consensus;
}

void CLLMOrchestrator::ApplyRiskFilters(LLMResponse &response) {
    if(!m_riskManager) return;

    // Get current price
    double currentPrice = SymbolInfoDouble(m_tradingPair, SYMBOL_BID);
    if(response.action == BUY_SIGNAL) {
        currentPrice = SymbolInfoDouble(m_tradingPair, SYMBOL_ASK);
    }

    // Apply risk manager filters
    RiskDecision riskDecision = m_riskManager.EvaluateSignal(
        m_tradingPair,
        response.action,
        currentPrice,
        response.slPrice,
        response.tpPrice,
        response.confidence
    );

    if(!riskDecision.approved) {
        response.action = NO_SIGNAL;
        response.confidence = 0.0;
        response.reasoning = "Risk management rejected signal: " + riskDecision.rejectionReason;
    } else {
        // Update SL/TP based on risk manager recommendations
        if(riskDecision.recommendedSL != 0) response.slPrice = riskDecision.recommendedSL;
        if(riskDecision.recommendedTP != 0) response.tpPrice = riskDecision.recommendedTP;

        // Append risk manager reasoning
        response.reasoning += "\nRisk Manager: " + riskDecision.reasoning;
    }
}

void CLLMOrchestrator::SetRiskManager(CRiskManagementEnv* riskManager) {
    m_riskManager = riskManager;
}

// Additional methods for trading execution, connection management, etc.
// (Implementation details for brevity)

#endif // LLM_ORCHESTRATOR_MQH
