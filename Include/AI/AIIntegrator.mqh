//+------------------------------------------------------------------+
//| AIIntegrator.mqh                                                 |
//| Advanced AI Integration for Trading Decisions                   |
//| Copyright 2025, QuantEdge Institutional Systems                 |
//+------------------------------------------------------------------+
#property copyright "2025, QuantEdge Institutional Systems"
#property version   "2.00"
#property strict

#ifndef AI_INTEGRATOR_MQH
#define AI_INTEGRATOR_MQH

#include <Arrays/ArrayObj.mqh>
#include <Trade/AccountInfo.mqh>
#include <Trade/SymbolInfo.mqh>
#include <Math/Stat/Math.mqh>
#include <WebRequest.mqh>
#include "../Calendar/EconomicCalendar.mqh"
#include "../News/NewsAnalyzer.mqh"
#include "../BrowserAgent/BrowserAgent.mqh"
#include "../Core/AI_JSON_FILE.mqh"

// AI model types
enum ENUM_AI_MODEL {
    MODEL_GPT4,
    MODEL_GPT5,
    MODEL_CLAUDE_OPUS_3,
    MODEL_CLAUDE_OPUS_4,
    MODEL_GEMINI_PRO,
    MODEL_LLAMA3,
    MODEL_MISTRAL,
    MODEL_DEEPSEEK_V32,
    MODEL_QWEN3,
    MODEL_MINIMAX21,
    MODEL_CUSTOM
};

// Trading actions
enum ENUM_TRADING_ACTION {
    ACTION_HOLD = 0,
    ACTION_BUY = 1,
    ACTION_SELL = 2,
    ACTION_CLOSE = 3,
    ACTION_REVERSE = 4
};

// Decision confidence levels
enum ENUM_CONFIDENCE_LEVEL {
    CONFIDENCE_VERY_LOW = 1,
    CONFIDENCE_LOW = 2,
    CONFIDENCE_MEDIUM = 3,
    CONFIDENCE_HIGH = 4,
    CONFIDENCE_VERY_HIGH = 5
};

// Market regime types
enum ENUM_MARKET_REGIME {
    REGIME_UNKNOWN,
    REGIME_TRENDING_UP,
    REGIME_TRENDING_DOWN,
    REGIME_RANGE_BOUND,
    REGIME_HIGH_VOLATILITY,
    REGIME_LOW_VOLATILITY,
    REGIME_BREAKOUT
};

// AI model configuration
struct AIModelConfig {
    string name;
    ENUM_AI_MODEL modelType;
    string apiUrl;
    string apiKey;
    string modelVersion;
    bool isActive;
    datetime lastUsed;
    int requestCount;
    double averageLatency;
    double successRate;
};

// Market context data
struct MarketContext {
    string symbol;
    double currentPrice;
    double bidPrice;
    double askPrice;
    double dailyRange;
    double atrValue;
    double volatility;
    ENUM_MARKET_REGIME marketRegime;
    double trendStrength;
    bool isRanging;
    bool isTrending;
    double supportLevel;
    double resistanceLevel;
    datetime lastUpdate;
};

// Technical indicators data
struct TechnicalIndicators {
    double rsi;
    double macd;
    double macdSignal;
    double macdHistogram;
    double stochK;
    double stochD;
    double bollingerUpper;
    double bollingerLower;
    double bollingerMiddle;
    double emaFast;
    double emaSlow;
    double volume;
    double obv;
    double adx;
    double diPlus;
    double diMinus;
};

// Trading decision structure
struct TradeDecision {
    ENUM_TRADING_ACTION action;
    ENUM_CONFIDENCE_LEVEL confidenceLevel;
    double confidenceScore; // 0.0 to 1.0
    double entryPrice;
    double stopLoss;
    double takeProfit;
    double positionSize; // Lot size
    string reasoning;
    datetime decisionTime;
    double latency; // Response time in ms
    string modelUsed;
    string marketContext;
    double expectedProfit;
    double riskRewardRatio;
    bool isValid;
};

class CAIIntegrator {
private:
    AIModelConfig m_models[];
    int m_modelCount;

    // Context providers
    CEconomicCalendar* m_calendar;
    CNewsAnalyzer* m_newsAnalyzer;

    // Cache and performance tracking
    string m_cacheFile;
    bool m_useCache;
    datetime m_lastCleanup;

    // Rate limiting
    datetime m_lastRequestTime[];
    int m_requestCount[];

    // Error handling
    string m_lastError;

    // Market context
    MarketContext m_marketContext;

    // Browser Agent
    CBrowserAgent* m_browserAgent;

public:
    CAIIntegrator();
    ~CAIIntegrator();

    // Initialization
    bool Initialize();
    void AddModel(ENUM_AI_MODEL modelType, string apiKey, string apiUrl = "", string modelVersion = "", bool isActive = true);
    void SetEconomicCalendar(CEconomicCalendar* calendar);
    void SetNewsAnalyzer(CNewsAnalyzer* newsAnalyzer);
    void SetCacheSettings(bool useCache, string cacheFile = "");

    // Core functionality
    TradeDecision GetDecisionFromModel(string modelName, string prompt);
    TradeDecision GetEnsembleDecision(string symbol, MqlRates& rates[], int ratesCount, TechnicalIndicators& indicators);
    TradeDecision GetDecisionForSymbol(string symbol, ENUM_AI_MODEL preferredModel = MODEL_GPT4);

    // Market context analysis
    bool UpdateMarketContext(string symbol);
    MarketContext GetMarketContext() { return m_marketContext; }

    // Utility methods
    string GetLastError() { return m_lastError; }
    string GetAvailableModels();
    void CleanupCache();

    // Browser Agent integration
    bool BrowserStart(bool headless = false) { return m_browserAgent.StartBrowser(headless); }
    bool BrowserLogin(string url, string user, string pass) {
        return m_browserAgent.Login(url, "input[type='text']", "input[type='password']", "button[type='submit']", user, pass);
    }
    bool BrowserRequestAnalysis(ENUM_AI_PROVIDER provider, string symbol, ENUM_TIMEFRAMES tf, SAnalysisResponse &resp) {
        return m_browserAgent.RequestAnalysis(provider, symbol, tf, resp);
    }

    // External Futures Data Integration
    string FetchExternalFuturesData(string symbol) {
        // Implementation for calling Python Data Bridge via WebRequest
        char data[], result[];
        string headers = "Content-Type: application/json\r\n";
        string url = "http://localhost:8000/futures_data?symbol=" + symbol;
        int res = WebRequest("GET", url, headers, 5000, data, result, headers);
        if(res == 200) return CharArrayToString(result);
        return "";
    }

private:
    // AI communication methods
    bool CanMakeRequest(ENUM_AI_MODEL modelType);
    string BuildApiPayload(AIModelConfig& model, string prompt);
    string GetAuthorizationHeader(AIModelConfig& model);
    TradeDecision ParseModelResponse(string response, AIModelConfig& model, double latency);

    // Prompt engineering methods
    string BuildTradingPrompt(string symbol, MqlRates& rates[], int ratesCount, TechnicalIndicators& indicators);
    string BuildRiskAwarePrompt(string symbol, MarketContext& context, string newsSummary, EconomicEvent* event);

    // Decision validation methods
    bool ValidateTradeDecision(TradeDecision& decision, string symbol);
    double CalculateRiskRewardRatio(TradeDecision& decision, double currentPrice);
    double CalculatePositionSizeBasedOnRisk(TradeDecision& decision, double riskPercent = 1.0);

    // Cache management methods
    bool LoadFromCache();
    bool SaveToCache();
    void ClearCache();

    // Helper methods
    string GetModelName(ENUM_AI_MODEL modelType);
    string GetFormattedTime(datetime time);
    bool ExtractPriceFromText(string text, double& price);
    bool CheckWebrequestPermissions();
    void HandleError(string error);
    double CalculateTrendStrength(MqlRates& rates[], int period = 50);
    ENUM_MARKET_REGIME DetectMarketRegime(MqlRates& rates[], TechnicalIndicators& indicators);
};

CAIIntegrator::CAIIntegrator() {
    m_modelCount = 0;
    ArrayResize(m_models, 10); // Pre-allocate for 10 models

    m_calendar = NULL;
    m_newsAnalyzer = NULL;
    m_browserAgent = new CBrowserAgent();

    m_cacheFile = "ai_decisions.dat";
    m_useCache = true;
    m_lastCleanup = 0;

    // Add default models
    AddModel(MODEL_GPT4, "", "https://api.openai.com/v1/chat/completions", "gpt-4-turbo");
    AddModel(MODEL_CLAUDE_OPUS_3, "", "https://api.anthropic.com/v1/messages", "claude-3-opus-20241101");
    AddModel(MODEL_GEMINI_PRO, "", "https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent", "gemini-1.5-pro");

    // Initialize request tracking arrays
    ArrayResize(m_lastRequestTime, 10);
    ArrayResize(m_requestCount, 10);
    ArrayInitialize(m_lastRequestTime, 0);
    ArrayInitialize(m_requestCount, 0);
}

CAIIntegrator::~CAIIntegrator() {
    if(CheckPointer(m_browserAgent) == POINTER_DYNAMIC) delete m_browserAgent;
}

bool CAIIntegrator::Initialize() {
    if(m_modelCount == 0) {
        HandleError("No AI models configured");
        return false;
    }

    return true;
}

void CAIIntegrator::AddModel(ENUM_AI_MODEL modelType, string apiKey, string apiUrl = "", string modelVersion = "", bool isActive = true) {
    if(m_modelCount >= ArraySize(m_models)) {
        HandleError("Maximum number of AI models reached");
        return;
    }

    AIModelConfig model;
    model.modelType = modelType;
    model.name = GetModelName(modelType);
    model.apiKey = apiKey;
    model.apiUrl = apiUrl;
    model.modelVersion = modelVersion;
    model.isActive = isActive;
    model.lastUsed = 0;
    model.requestCount = 0;
    model.averageLatency = 0.0;
    model.successRate = 0.0;

    // Set default API URLs if not provided
    if(apiUrl == "") {
        switch(modelType) {
            case MODEL_GPT4:
                model.apiUrl = "https://api.openai.com/v1/chat/completions";
                break;
            case MODEL_CLAUDE_OPUS_3:
                model.apiUrl = "https://api.anthropic.com/v1/messages";
                break;
            case MODEL_GEMINI_PRO:
                model.apiUrl = "https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent";
                break;
            case MODEL_LLAMA3:
                model.apiUrl = "https://api.llama-api.com/v1/chat/completions";
                break;
            case MODEL_MISTRAL:
                model.apiUrl = "https://api.mistral.ai/v1/chat/completions";
                break;
            default:
                model.apiUrl = "";
        }
    }

    m_models[m_modelCount] = model;
    m_modelCount++;
}

void CAIIntegrator::SetEconomicCalendar(CEconomicCalendar* calendar) {
    m_calendar = calendar;
}

void CAIIntegrator::SetNewsAnalyzer(CNewsAnalyzer* newsAnalyzer) {
    m_newsAnalyzer = newsAnalyzer;
}

void CAIIntegrator::SetCacheSettings(bool useCache, string cacheFile = "") {
    m_useCache = useCache;
    if(cacheFile != "") {
        m_cacheFile = cacheFile;
    }
}

bool CAIIntegrator::UpdateMarketContext(string symbol) {
    m_marketContext.symbol = symbol;
    m_marketContext.lastUpdate = TimeCurrent();

    // Get current prices
    m_marketContext.currentPrice = SymbolInfoDouble(symbol, SYMBOL_LAST);
    m_marketContext.bidPrice = SymbolInfoDouble(symbol, SYMBOL_BID);
    m_marketContext.askPrice = SymbolInfoDouble(symbol, SYMBOL_ASK);

    // Calculate volatility and ATR
    m_marketContext.atrValue = iATR(symbol, PERIOD_CURRENT, 14, 0);
    m_marketContext.dailyRange = iHigh(symbol, PERIOD_D1, 0) - iLow(symbol, PERIOD_D1, 0);
    m_marketContext.volatility = m_marketContext.dailyRange / m_marketContext.currentPrice;

    // Calculate support and resistance levels
    int lookback = 20;
    double highPrices[], lowPrices[];
    CopyHigh(symbol, PERIOD_H1, 0, lookback, highPrices);
    CopyLow(symbol, PERIOD_H1, 0, lookback, lowPrices);

    m_marketContext.resistanceLevel = 0.0;
    m_marketContext.supportLevel = 1e10; // Large number

    for(int i = 0; i < lookback; i++) {
        if(highPrices[i] > m_marketContext.resistanceLevel) {
            m_marketContext.resistanceLevel = highPrices[i];
        }
        if(lowPrices[i] < m_marketContext.supportLevel) {
            m_marketContext.supportLevel = lowPrices[i];
        }
    }

    // Get technical indicators
    TechnicalIndicators indicators;
    indicators.rsi = iRSI(symbol, PERIOD_CURRENT, 14, PRICE_CLOSE, 0);
    indicators.macd = iMACD(symbol, PERIOD_CURRENT, 12, 26, 9, PRICE_CLOSE, MODE_MAIN, 0);
    indicators.macdSignal = iMACD(symbol, PERIOD_CURRENT, 12, 26, 9, PRICE_CLOSE, MODE_SIGNAL, 0);
    indicators.macdHistogram = indicators.macd - indicators.macdSignal;
    indicators.adx = iADX(symbol, PERIOD_CURRENT, 14, MODE_MAIN, 0);
    indicators.diPlus = iADX(symbol, PERIOD_CURRENT, 14, MODE_PLUSDI, 0);
    indicators.diMinus = iADX(symbol, PERIOD_CURRENT, 14, MODE_MINUSDI, 0);

    // Determine market regime
    m_marketContext.marketRegime = DetectMarketRegime(highPrices, indicators);
    m_marketContext.trendStrength = indicators.adx;
    m_marketContext.isRanging = (indicators.adx < 20);
    m_marketContext.isTrending = (indicators.adx > 25);



    // Patterns
    PatternResult pattern = g_PatternEnv->DetectPatterns();
    features[11] = pattern.patternStrength;
    features[12] = pattern.confidence;

    // Risk
    RiskAssessment risk = g_RiskEnv->AssessCurrentRisk();
    features[16] = risk.riskScore;

    // Liquidity
    features[18] = g_ExecutionEnv->GetLiquidityScore();

    // NEW FEATURES FROM LIBRARIES
    // Andean Oscillator
    double bull, bear;
    int andeanSignal = g_Andean->Calculate(bull, bear);
    features[40] = bull;
    features[41] = bear;
    features[42] = (double)andeanSignal;

    // VWAP
    features[45] = g_VWAP->GetDeviation();

    // Fibonacci
    features[46] = g_Fibo->GetNearestGoldenLevelDist();

    // ICT Features
    g_ICT->Update(_Symbol);
    bool inFVG = g_ICT->IsPriceInFVG(features[0]);
    features[50] = inFVG ? 1.0 : 0.0;

    // CRT Theory
    g_CRT->Calculate(0);
    features[60] = g_CRT->isLarge ? 1.0 : 0.0;
    features[61] = g_CRT->isOutside ? 1.0 : 0.0;

    // Statistics Features
    PerformanceMetrics pm = g_StatsEnv->GetMetrics();
    features[30] = pm.winRate;
    features[31] = pm.profitFactor;
    features[32] = pm.drawdownPercent;


    return true;
}

ENUM_MARKET_REGIME CAIIntegrator::DetectMarketRegime(MqlRates& rates[], TechnicalIndicators& indicators) {
    // Simple regime detection based on volatility and trend strength
    double volatility = m_marketContext.volatility;
    double adx = indicators.adx;

    if(adx > 30) {
        if(indicators.diPlus > indicators.diMinus) {
            return REGIME_TRENDING_UP;
        } else {
            return REGIME_TRENDING_DOWN;
        }
    }

    if(volatility > 0.02) { // 2% daily volatility
        return REGIME_HIGH_VOLATILITY;
    } else if(volatility < 0.005) { // 0.5% daily volatility
        return REGIME_LOW_VOLATILITY;
    }

    // Check for range-bound conditions
    double upperBB = indicators.bollingerUpper;
    double lowerBB = indicators.bollingerLower;
    double currentPrice = rates[rates-1].close;

    if(currentPrice > lowerBB && currentPrice < upperBB) {
        return REGIME_RANGE_BOUND;
    }

    // Check for breakout conditions
    if(currentPrice > upperBB || currentPrice < lowerBB) {
        return REGIME_BREAKOUT;
    }

    return REGIME_UNKNOWN;
}

TradeDecision CAIIntegrator::GetDecisionForSymbol(string symbol, ENUM_AI_MODEL preferredModel) {
    // Update market context
    if(!UpdateMarketContext(symbol)) {
        HandleError("Failed to update market context");
        TradeDecision invalidDecision;
        ZeroMemory(invalidDecision);
        invalidDecision.isValid = false;
        invalidDecision.reasoning = "Market context update failed";
        return invalidDecision;
    }

    // Get technical indicators
    TechnicalIndicators indicators;
    indicators.rsi = iRSI(symbol, PERIOD_CURRENT, 14, PRICE_CLOSE, 0);
    indicators.macd = iMACD(symbol, PERIOD_CURRENT, 12, 26, 9, PRICE_CLOSE, MODE_MAIN, 0);
    indicators.macdSignal = iMACD(symbol, PERIOD_CURRENT, 12, 26, 9, PRICE_CLOSE, MODE_SIGNAL, 0);
    indicators.adx = iADX(symbol, PERIOD_CURRENT, 14, MODE_MAIN, 0);

    // Get price history
    MqlRates rates[];
    int ratesCount = CopyRates(symbol, PERIOD_H1, 0, 100, rates);
    if(ratesCount < 50) {
        HandleError("Insufficient price history");
        TradeDecision invalidDecision;
        ZeroMemory(invalidDecision);
        invalidDecision.isValid = false;
        invalidDecision.reasoning = "Insufficient price history";
        return invalidDecision;
    }

    // Check for high-impact news
    string newsSummary = "";
    double averageSentiment = 0.0;
    int articleCount = 0;

    if(m_newsAnalyzer != NULL) {
        datetime fromTime = TimeCurrent() - 86400; // Last 24 hours
        datetime toTime = TimeCurrent();

        if(m_newsAnalyzer.AnalyzeSentimentForSymbol(symbol, fromTime, toTime, averageSentiment, articleCount, newsSummary)) {
            // Incorporate sentiment into context
        }
    }

    // Check for upcoming economic events
    EconomicEvent* nextEvent = NULL;
    if(m_calendar != NULL) {
        nextEvent = m_calendar.GetNextHighImpactEvent(TimeCurrent(), StringSubstr(symbol, 0, 3) + "," + StringSubstr(symbol, 3, 3));
    }

    // Build the prompt
    string prompt = BuildRiskAwarePrompt(symbol, m_marketContext, newsSummary, nextEvent);

    // Find the preferred model
    int modelIndex = -1;
    for(int i = 0; i < m_modelCount; i++) {
        if(m_models[i].modelType == preferredModel && m_models[i].isActive) {
            modelIndex = i;
            break;
        }
    }

    // Fallback to first active model if preferred not available
    if(modelIndex == -1) {
        for(int i = 0; i < m_modelCount; i++) {
            if(m_models[i].isActive) {
                modelIndex = i;
                break;
            }
        }
    }

    if(modelIndex == -1) {
        HandleError("No active AI models available");
        TradeDecision invalidDecision;
        ZeroMemory(invalidDecision);
        invalidDecision.isValid = false;
        invalidDecision.reasoning = "No active AI models available";
        return invalidDecision;
    }

    // Get decision from model
    TradeDecision decision = GetDecisionFromModel(m_models[modelIndex].name, prompt);

    // Validate the decision
    if(!ValidateTradeDecision(decision, symbol)) {
        decision.action = ACTION_HOLD;
        decision.confidenceLevel = CONFIDENCE_LOW;
        decision.confidenceScore = 0.3;
        decision.reasoning += " | Decision modified due to risk management constraints";
    }

    return decision;
}

string CAIIntegrator::BuildRiskAwarePrompt(string symbol, MarketContext& context, string newsSummary, EconomicEvent* event) {
    string prompt = "";

    // Market context header
    prompt += StringFormat("TRADING DECISION REQUEST\nSymbol: %s\nCurrent Price: %.5f\nMarket Regime: %s\n",
        symbol, context.currentPrice, EnumToString(context.marketRegime));

    // Technical context
    prompt += StringFormat("\nTECHNICAL CONTEXT:\nVolatility: %.2f%%\nATR(14): %.5f\n",
        context.volatility * 100, context.atrValue);

    // Add resistance/support levels if available
    if(context.resistanceLevel > 0 && context.supportLevel > 0) {
        prompt += StringFormat("Resistance: %.5f\nSupport: %.5f\n",
            context.resistanceLevel, context.supportLevel);
    }

    // News context
    if(newsSummary != "") {
        prompt += "\nRECENT NEWS SENTIMENT:\n" + newsSummary + "\n";
    }

    // Economic calendar context
    if(event != NULL) {
        prompt += StringFormat("\nUPCOMING HIGH-IMPACT EVENT:\nTime: %s\nEvent: %s (%s)\nCurrency: %s\n",
            GetFormattedTime(event.eventTime),
            event.eventName,
            EnumToString(event.impactLevel),
            event.currency);

        if(!event.isReleased) {
            prompt += StringFormat("Forecast: %s\nPrevious: %s\n",
                event.forecastValue != EMPTY_VALUE ? DoubleToString(event.forecastValue, 2) : "N/A",
                event.previousValue != EMPTY_VALUE ? DoubleToString(event.previousValue, 2) : "N/A");
        }
    }

    // Account risk context
    double balance = AccountInfoDouble(ACCOUNT_BALANCE);
    double equity = AccountInfoDouble(ACCOUNT_EQUITY);
    double margin = AccountInfoDouble(ACCOUNT_MARGIN);
    double freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
    double marginLevel = AccountInfoDouble(ACCOUNT_MARGIN_LEVEL);

    prompt += StringFormat("\nACCOUNT RISK CONTEXT:\nBalance: $%.2f\nEquity: $%.2f\nMargin Used: $%.2f\nFree Margin: $%.2f\nMargin Level: %.2f%%\n",
        balance, equity, margin, freeMargin, marginLevel);

    // Trading instructions
    prompt += "\nINSTRUCTIONS:\n";
    prompt += "1. Analyze the current market conditions and provide a trading decision\n";
    prompt += "2. Consider volatility, trend strength, support/resistance levels, and upcoming events\n";
    prompt += "3. If high-impact news is imminent (<1 hour), prefer conservative positions or HOLD\n";
    prompt += "4. Calculate appropriate stop loss and take profit levels with minimum 1:2 risk-reward ratio\n";
    prompt += "5. Position size should risk no more than 1% of equity\n";
    prompt += "6. If market is ranging, avoid trend-following positions\n";

    // Output format specification (JSON)
    prompt += "\nRESPONSE FORMAT (STRICT JSON):\n";
    prompt += "{\n";
    prompt += "  \"action\": \"HOLD\" | \"BUY\" | \"SELL\",\n";
    prompt += "  \"confidence\": 0.0 to 1.0,\n";
    prompt += "  \"entry_price\": number,\n";
    prompt += "  \"stop_loss\": number,\n";
    prompt += "  \"take_profit\": number,\n";
    prompt += "  \"position_size\": number (in lots),\n";
    prompt += "  \"reasoning\": \"concise explanation of decision factors\"\n";
    prompt += "}\n";

    // Constraints
    prompt += "\nCONSTRAINTS:\n";
    prompt += "- If volatility > 2%, reduce position size or avoid trading\n";
    prompt += "- If margin level < 200%, no new positions\n";
    prompt += "- If upcoming high-impact event < 30 minutes, default to HOLD unless confidence > 0.9\n";
    prompt += "- Stop loss must be at least 1.5x ATR away from entry price\n";
    prompt += "- Take profit must be at least 2x stop loss distance\n";
    prompt += "- Never risk more than 1% of equity on a single trade\n";

    return prompt;
}

TradeDecision CAIIntegrator::GetDecisionFromModel(string modelName, string prompt) {
    // Find the model
    int modelIndex = -1;
    for(int i = 0; i < m_modelCount; i++) {
        if(m_models[i].name == modelName && m_models[i].isActive) {
            modelIndex = i;
            break;
        }
    }

    if(modelIndex == -1) {
        HandleError(StringFormat("Model not found or inactive: %s", modelName));
        TradeDecision invalidDecision;
        ZeroMemory(invalidDecision);
        invalidDecision.isValid = false;
        invalidDecision.reasoning = StringFormat("Model not found: %s", modelName);
        return invalidDecision;
    }

    AIModelConfig& model = m_models[modelIndex];

    // Check rate limiting
    if(!CanMakeRequest(model.modelType)) {
        HandleError(StringFormat("Rate limit exceeded for model: %s", modelName));
        TradeDecision invalidDecision;
        ZeroMemory(invalidDecision);
        invalidDecision.isValid = false;
        invalidDecision.reasoning = "Rate limit exceeded";
        return invalidDecision;
    }

    // Check web request permissions
    if(!CheckWebrequestPermissions()) {
        HandleError("Web requests are not allowed in terminal settings");
        TradeDecision invalidDecision;
        ZeroMemory(invalidDecision);
        invalidDecision.isValid = false;
        invalidDecision.reasoning = "Web requests disabled in terminal settings";
        return invalidDecision;
    }

    // Build API payload
    string payload = BuildApiPayload(model, prompt);
    string headers = GetAuthorizationHeader(model);

    // Make the request
    datetime startTime = GetMicrosecondCount();

    char data[], resultData[];
    string resultHeaders = "";
    int statusCode = 0;

    ResetLastError();
    statusCode = WebRequest("POST", model.apiUrl, headers, 30000, data, payload, resultData, resultHeaders);

    double latency = (GetMicrosecondCount() - startTime) / 1000.0; // Convert to milliseconds

    // Update model statistics
    model.lastUsed = TimeCurrent();
    model.requestCount++;
    model.averageLatency = (model.averageLatency * (model.requestCount - 1) + latency) / model.requestCount;

    if(statusCode != 200) {
        HandleError(StringFormat("API request failed with status %d. Error: %d. Model: %s",
                   statusCode, GetLastError(), modelName));

        // Update success rate
        model.successRate = (model.successRate * (model.requestCount - 1)) / model.requestCount;

        TradeDecision failedDecision;
        ZeroMemory(failedDecision);
        failedDecision.isValid = false;
        failedDecision.reasoning = StringFormat("API request failed: %d", statusCode);
        failedDecision.latency = latency;
        failedDecision.modelUsed = modelName;
        return failedDecision;
    }

    // Parse the response
    string response = CharArrayToString(resultData);

    // Update success rate
    model.successRate = (model.successRate * (model.requestCount - 1) + 1) / model.requestCount;

    return ParseModelResponse(response, model, latency);
}

bool CAIIntegrator::CanMakeRequest(ENUM_AI_MODEL modelType) {
    datetime now = TimeCurrent();
    int index = (int)modelType;

    if(index >= ArraySize(m_lastRequestTime)) {
        ArrayResize(m_lastRequestTime, index + 1);
        ArrayResize(m_requestCount, index + 1);
        m_lastRequestTime[index] = 0;
        m_requestCount[index] = 0;
    }

    // Reset counter if more than 60 seconds have passed
    if(now - m_lastRequestTime[index] > 60) {
        m_requestCount[index] = 0;
        m_lastRequestTime[index] = now;
    }

    // Rate limits (requests per minute) by model type
    int rateLimit = 20; // Default

    switch(modelType) {
        case MODEL_GPT4:
        case MODEL_GPT5:
        case MODEL_CLAUDE_OPUS_3:
        case MODEL_CLAUDE_OPUS_4:
            rateLimit = 10; // Stricter limits for premium models
            break;
        case MODEL_GEMINI_PRO:
            rateLimit = 15;
            break;
        case MODEL_LLAMA3:
        case MODEL_MISTRAL:
            rateLimit = 30; // More generous limits for open models
            break;
        default:
            rateLimit = 20;
    }

    if(m_requestCount[index] >= rateLimit) {
        return false;
    }

    m_requestCount[index]++;
    return true;
}

string CAIIntegrator::BuildApiPayload(AIModelConfig& model, string prompt) {
    string payload = "";

    switch(model.modelType) {
        case MODEL_GPT4: {
            payload = "{";
            payload += "\"model\": \"" + (model.modelVersion != "" ? model.modelVersion : "gpt-4-turbo") + "\",";
            payload += "\"messages\": [";
            payload += "{\"role\": \"system\", \"content\": \"You are an expert forex trading AI that provides precise, risk-aware trading signals. Always respond in valid JSON format.\"},";
            payload += "{\"role\": \"user\", \"content\": \"" + StringReplace(prompt, "\"", "\\\"", 0) + "\"}";
            payload += "],";
            payload += "\"temperature\": 0.7,";
            payload += "\"max_tokens\": 500,";
            payload += "\"response_format\": {\"type\": \"json_object\"}";
            payload += "}";
            break;
        }

        case MODEL_GPT5: {
            payload = "{";
            payload += "\"model\": \"" + (model.modelVersion != "" ? model.modelVersion : "gpt-5.2-high") + "\",";
            payload += "\"messages\": [";
            payload += "{\"role\": \"system\", \"content\": \"You are an expert forex trading AI that provides precise, risk-aware trading signals. Always respond in valid JSON format.\"},";
            payload += "{\"role\": \"user\", \"content\": \"" + StringReplace(prompt, "\"", "\\\"", 0) + "\"}";
            payload += "],";
            payload += "\"temperature\": 0.7,";
            payload += "\"max_tokens\": 500,";
            payload += "\"response_format\": {\"type\": \"json_object\"}";
            payload += "}";
            break;
        }


        case MODEL_DEEPSEEK_V32: return "deepseek-v3.2";
        case MODEL_QWEN3: return "qwen3-max";
        case MODEL_MINIMAX21: return "minimax-2.1-preview";


        case MODEL_CLAUDE_OPUS_3: {
            payload = "{";
            payload += "\"model\": \"" + (model.modelVersion != "" ? model.modelVersion : "claude-3-opus-20241101") + "\",";
            payload += "\"max_tokens\": 1024,";
            payload += "\"temperature\": 0.7,";
            payload += "\"system\": \"You are an expert forex trading AI that provides precise, risk-aware trading signals. Always respond in valid JSON format.\",";
            payload += "\"messages\": [";
            payload += "{\"role\": \"user\", \"content\": \"" + StringReplace(prompt, "\"", "\\\"", 0) + "\"}";
            payload += "]";
            payload += "}";
            break;
        }

        case MODEL_CLAUDE_OPUS_4: {
            payload = "{";
            payload += "\"model\": \"" + (model.modelVersion != "" ? model.modelVersion : "claude-opus-4-5-20251101-thinking-32k") + "\",";
            payload += "\"max_tokens\": 1024,";
            payload += "\"temperature\": 0.7,";
            payload += "\"system\": \"You are an expert forex trading AI that provides precise, risk-aware trading signals. Always respond in valid JSON format.\",";
            payload += "\"messages\": [";
            payload += "{\"role\": \"user\", \"content\": \"" + StringReplace(prompt, "\"", "\\\"", 0) + "\"}";
            payload += "]";
            payload += "}";
            break;
        }

        case MODEL_GEMINI_PRO: {
            // Gemini uses a different format
            payload = "{";
            payload += "\"contents\": [";
            payload += "{\"role\": \"user\", \"parts\": [{\"text\": \"" + StringReplace(prompt, "\"", "\\\"", 0) + "\"}]}";
            payload += "],";
            payload += "\"generationConfig\": {";
            payload += "\"temperature\": 0.7,";
            payload += "\"maxOutputTokens\": 500,";
            payload += "\"responseMimeType\": \"application/json\"";
            payload += "}";
            payload += "}";

            // Add API key to URL for Gemini
            if(model.apiKey != "") {
                model.apiUrl += "?key=" + model.apiKey;
            }
            break;
        }

        default: {
            // Generic format for other models
            payload = "{";
            payload += "\"model\": \"" + (model.modelVersion != "" ? model.modelVersion : "default") + "\",";
            payload += "\"messages\": [";
            payload += "{\"role\": \"system\", \"content\": \"You are an expert forex trading AI that provides precise, risk-aware trading signals. Always respond in valid JSON format.\"},";
            payload += "{\"role\": \"user\", \"content\": \"" + StringReplace(prompt, "\"", "\\\"", 0) + "\"}";
            payload += "],";
            payload += "\"temperature\": 0.7,";
            payload += "\"max_tokens\": 500";
            payload += "}";
            break;
        }
    }

    return payload;
}

string CAIIntegrator::GetAuthorizationHeader(AIModelConfig& model) {
    string headers = "Content-Type: application/json\r\n";

    if(model.apiKey == "") {
        return headers;
    }

    switch(model.modelType) {
        case MODEL_GPT4:
        case MODEL_GPT5:
            headers += "Authorization: Bearer " + model.apiKey + "\r\n";
            break;
        case MODEL_CLAUDE_OPUS_3:
            headers += "x-api-key: " + model.apiKey + "\r\n";
            headers += "anthropic-version: 2023-06-01\r\n";
            break;
        case MODEL_CLAUDE_OPUS_4:
            headers += "x-api-key: " + model.apiKey + "\r\n";
            headers += "anthropic-version: 2025-11-01\r\n";
            break;
        case MODEL_GEMINI_PRO:
            // API key handled in URL for Gemini
            break;
        case MODEL_LLAMA3:
        case MODEL_MISTRAL:
            headers += "Authorization: Bearer " + model.apiKey + "\r\n";
            break;
        default:
            headers += "Authorization: Bearer " + model.apiKey + "\r\n";
    }

    return headers;
}

TradeDecision CAIIntegrator::ParseModelResponse(string response, AIModelConfig& model, double latency) {
    TradeDecision decision;
    ZeroMemory(decision);
    decision.decisionTime = TimeCurrent();
    decision.latency = latency;
    decision.modelUsed = model.name;
    decision.isValid = false;

    // Extract JSON from response if needed
    int jsonStart = StringFind(response, "{");
    int jsonEnd = StringFind(response, "}", 0, 1) + 1; // Find the last }

    if(jsonStart >= 0 && jsonEnd > jsonStart) {
        response = StringSubstr(response, jsonStart, jsonEnd - jsonStart);
    }

    // Parse JSON response
    char jsonChars[];
    int len = StringToCharArray(response, jsonChars);
    int index = 0;

    JsonValue json;
    if(!json.DeserializeFromArray(jsonChars, len, index)) {
        decision.reasoning = "Failed to parse JSON response: " + response;
        return decision;
    }

    // Extract action
    string actionStr = json["action"].ToString();
    StringToUpper(actionStr);

    if(StringFind(actionStr, "BUY") >= 0 || StringFind(actionStr, "LONG") >= 0) {
        decision.action = ACTION_BUY;
    } else if(StringFind(actionStr, "SELL") >= 0 || StringFind(actionStr, "SHORT") >= 0) {
        decision.action = ACTION_SELL;
    } else {
        decision.action = ACTION_HOLD;
    }

    // Extract confidence
    decision.confidenceScore = json["confidence"].ToDouble();
    if(decision.confidenceScore == 0) decision.confidenceScore = 0.5;

    // Map confidence score to level
    if(decision.confidenceScore >= 0.9) {
        decision.confidenceLevel = CONFIDENCE_VERY_HIGH;
    } else if(decision.confidenceScore >= 0.7) {
        decision.confidenceLevel = CONFIDENCE_HIGH;
    } else if(decision.confidenceScore >= 0.5) {
        decision.confidenceLevel = CONFIDENCE_MEDIUM;
    } else if(decision.confidenceScore >= 0.3) {
        decision.confidenceLevel = CONFIDENCE_LOW;
    } else {
        decision.confidenceLevel = CONFIDENCE_VERY_LOW;
    }

    // Extract prices
    decision.entryPrice = json["entry_price"].ToDouble();
    decision.stopLoss = json["stop_loss"].ToDouble();
    decision.takeProfit = json["take_profit"].ToDouble();
    decision.positionSize = json["position_size"].ToDouble();

    // Extract reasoning
    decision.reasoning = json["reasoning"].ToString();

    // Validate decision
    decision.isValid = (decision.confidenceScore > 0.2); // Minimum confidence threshold

    // Calculate risk-reward ratio
    if(decision.stopLoss > 0 && decision.takeProfit > 0 && decision.entryPrice > 0) {
        double risk = MathAbs(decision.entryPrice - decision.stopLoss);
        double reward = MathAbs(decision.takeProfit - decision.entryPrice);

        if(risk > 0) {
            decision.riskRewardRatio = reward / risk;
        }
    }

    return decision;
}

bool CAIIntegrator::ValidateTradeDecision(TradeDecision& decision, string symbol) {
    if(!decision.isValid) {
        return false;
    }

    if(decision.action == ACTION_HOLD) {
        return true; // HOLD decisions are always valid
    }

    // Get current prices
    double currentBid = SymbolInfoDouble(symbol, SYMBOL_BID);
    double currentAsk = SymbolInfoDouble(symbol, SYMBOL_ASK);
    double currentPrice = (currentBid + currentAsk) / 2.0;

    // Validate entry price
    if(decision.entryPrice == 0) {
        decision.entryPrice = (decision.action == ACTION_BUY) ? currentAsk : currentBid;
    }

    // Validate stop loss and take profit
    if(decision.stopLoss == 0 || decision.takeProfit == 0) {
        decision.reasoning += " | Invalid SL/TP levels. Using defaults.";

        double atr = iATR(symbol, PERIOD_CURRENT, 14, 0);

        if(decision.action == ACTION_BUY) {
            decision.stopLoss = decision.entryPrice - atr * 1.5;
            decision.takeProfit = decision.entryPrice + atr * 3.0; // 1:2 risk-reward
        } else {
            decision.stopLoss = decision.entryPrice + atr * 1.5;
            decision.takeProfit = decision.entryPrice - atr * 3.0; // 1:2 risk-reward
        }
    }

    // Check risk-reward ratio (minimum 1:1.5)
    double risk = MathAbs(decision.entryPrice - decision.stopLoss);
    double reward = MathAbs(decision.takeProfit - decision.entryPrice);

    if(risk == 0 || reward / risk < 1.5) {
        decision.reasoning += " | Poor risk-reward ratio. Adjusting targets.";

        // Adjust take profit to meet minimum ratio
        if(decision.action == ACTION_BUY) {
            decision.takeProfit = decision.entryPrice + risk * 1.5;
        } else {
            decision.takeProfit = decision.entryPrice - risk * 1.5;
        }
    }

    // Check position size risk (no more than 1% of equity)
    double equity = AccountInfoDouble(ACCOUNT_EQUITY);
    double riskAmount = equity * 0.01; // 1% risk

    double pointValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
    double point = SymbolInfoDouble(symbol, SYMBOL_POINT);

    if(decision.positionSize == 0) {
        // Calculate position size based on risk
        decision.positionSize = riskAmount / (risk / point * pointValue);

        // Apply maximum position size limits
        double maxLotSize = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
        double minLotSize = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
        double lotStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);

        if(decision.positionSize > maxLotSize) {
            decision.positionSize = maxLotSize;
        }

        if(decision.positionSize < minLotSize) {
            decision.positionSize = minLotSize;
        }

        // Round to nearest step
        decision.positionSize = MathFloor(decision.positionSize / lotStep) * lotStep;
    }

    // Final validation checks
    if(decision.positionSize <= 0) {
        decision.reasoning += " | Invalid position size";
        return false;
    }

    if(decision.action == ACTION_BUY && decision.stopLoss >= decision.entryPrice) {
        decision.reasoning += " | Invalid stop loss for buy position";
        return false;
    }

    if(decision.action == ACTION_SELL && decision.stopLoss <= decision.entryPrice) {
        decision.reasoning += " | Invalid stop loss for sell position";
        return false;
    }

    return true;
}

string CAIIntegrator::GetModelName(ENUM_AI_MODEL modelType) {
    switch(modelType) {
        case MODEL_GPT4: return "gpt-4-turbo";
        case MODEL_CLAUDE_OPUS_3: return "claude-opus-3-20230601";
        case MODEL_CLAUDE_OPUS_4: return "claude-opus-4-5-20251101-thinking-32k";
        case MODEL_GEMINI_PRO: return "gemini-3-pro";
        case MODEL_LLAMA3: return "llama-3";
        case MODEL_MISTRAL: return "mistral";

        case MODEL_DEEPSEEK_V32: return "deepseek-v3.2";
        case MODEL_GPT5: return "gpt-5.2-high";
        case MODEL_QWEN3: return "qwen3-max";
        case MODEL_MINIMAX21: return "minimax-2.1-preview";

        default: return "Custom Model";
    }
}

string CAIIntegrator::GetAvailableModels() {
    string models = "";
    for(int i = 0; i < m_modelCount; i++) {
        if(m_models[i].isActive) {
            if(models != "") models += ", ";
            models += m_models[i].name + " (Success: " + DoubleToString(m_models[i].successRate * 100, 1) + "%)";
        }
    }
    return models;
}

bool CAIIntegrator::CheckWebrequestPermissions() {
    if(!TerminalInfoInteger(TERMINAL_DLLS_ALLOWED)) {
        return false;
    }

    if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED)) {
        return false;
    }

    return true;
}

void CAIIntegrator::HandleError(string error) {
    m_lastError = error;
    Print("AIIntegrator Error: ", error);
}

#endif // AI_INTEGRATOR_MQH