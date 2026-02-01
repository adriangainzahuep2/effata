//+------------------------------------------------------------------+
//| NewsAnalyzer.mqh                                                         |
//| News Sentiment Analysis Integration                              |
//| Copyright 2025, QuantEdge Institutional Systems                 |
//+------------------------------------------------------------------+
#property copyright "2025, QuantEdge Institutional Systems"
#property version   "1.15"
#property strict

#ifndef NEWS_MQH
#define NEWS_MQH

#include <Arrays/ArrayObj.mqh>
#include <Trade/SymbolInfo.mqh>
#include <WebRequest.mqh>
#include "../Calendar/EconomicCalendar.mqh"

// News source types
enum ENUM_NEWS_SOURCE {
    SOURCE_REUTERS,
    SOURCE_BLOOMBERG,
    SOURCE_FINANCIAL_TIMES,
    SOURCE_MARKETWATCH,
    SOURCE_FOREXFACTORY,
    SOURCE_TRADING_ECONOMICS,
    SOURCE_CUSTOM
};

// Sentiment levels
enum ENUM_SENTIMENT {
    SENTIMENT_VERY_NEGATIVE = -2,
    SENTIMENT_NEGATIVE = -1,
    SENTIMENT_NEUTRAL = 0,
    SENTIMENT_POSITIVE = 1,
    SENTIMENT_VERY_POSITIVE = 2
};

// News article structure
struct NewsArticle {
    datetime publishTime;
    string headline;
    string summary;
    string url;
    string source;
    string relatedSymbols[]; // Symbols affected by this news
    double sentimentScore; // -1.0 to 1.0
    ENUM_SENTIMENT sentimentLevel;
    int impactScore; // 0-100
    bool isTechnical;
    bool isFundamental;
    bool isSentiment;
    datetime lastAnalyzed;
};

// News source configuration
struct NewsSource {
    string name;
    string baseUrl;
    string apiUrl;
    string apiKey;
    ENUM_NEWS_SOURCE sourceType;
    bool isActive;
    datetime lastUpdate;
    int updateInterval; // seconds
};

class CNewsAnalyzer {
private:
    NewsArticle m_articles[];
    NewsSource m_sources[];
    int m_sourceCount;
    int m_maxArticles;
    datetime m_lastUpdate;
    int m_updateInterval;

    // Sentiment analysis configuration
    bool m_useExternalSentiment;
    string m_sentimentApiUrl;
    string m_sentimentApiKey;

    // Cache settings
    string m_cacheFile;
    bool m_useCache;

    // Economic calendar integration
    CEconomicCalendar* m_calendar;

    // Error handling
    string m_lastError;

public:
    CNewsAnalyzer();
    ~CNewsAnalyzer();

    // Initialization
    bool Initialize();
    void AddSource(ENUM_NEWS_SOURCE sourceType, string apiUrl, string apiKey = "", bool isActive = true);
    void SetEconomicCalendar(CEconomicCalendar* calendar);
    void SetCacheSettings(bool useCache, string cacheFile = "");
    void SetSentimentAnalysis(bool useExternal, string apiUrl = "", string apiKey = "");

    // Data retrieval and analysis
    bool UpdateNews(bool force = false);
    bool AnalyzeSentimentForSymbol(string symbol, datetime fromTime, datetime toTime,
                                   double& averageSentiment, int& articleCount, string& summary);
    NewsArticle* GetLatestArticles(int count, string symbolFilter = "");
    bool IsMarketSensitiveNews(string symbol, int bufferMinutes, int& minutesToNews, ENUM_SENTIMENT& sentiment);

    // Utility methods
    string GetLastError() { return m_lastError; }
    int GetArticleCount() { return ArraySize(m_articles); }

private:
    // Data fetching methods
    bool FetchNewsData(NewsSource& source);
    bool ParseNewsApiResponse(string response, NewsSource& source);

    // Sentiment analysis methods
    void AnalyzeArticleSentiment(NewsArticle& article);
    ENUM_SENTIMENT CalculateSentimentLevel(double score);

    // Helper methods
    void ClearArticles();
    void SortArticles();
    void FilterArticlesBySymbol(NewsArticle& articles[], int& count, string symbol);
    bool IsSymbolAffected(string articleText, string symbol);
    string ExtractCurrencyPairs(string text);
    bool IsRelevantToTrading(string text);
    bool LoadFromCache();
    bool SaveToCache();
    void HandleError(string error);
    bool CheckWebrequestPermissions();
};

CNewsAnalyzer::CNewsAnalyzer() {
    m_sourceCount = 0;
    m_maxArticles = 50;
    m_lastUpdate = 0;
    m_updateInterval = 1800; // 30 minutes default
    m_cacheFile = "news_data.dat";
    m_useCache = true;
    m_useExternalSentiment = false;
    m_calendar = NULL;
    ArrayResize(m_sources, 6); // Pre-allocate for 6 sources

    // Add default sources
    AddSource(SOURCE_REUTERS, "https://api.reuters.com/news/forex", "", true);
    AddSource(SOURCE_BLOOMBERG, "https://api.bloomberg.com/news/forex", "", true);
    AddSource(SOURCE_FINANCIAL_TIMES, "https://api.ft.com/content/forex", "", false);
}

CNewsAnalyzer::~CNewsAnalyzer() {
    ClearArticles();
}

void CNewsAnalyzer::SetEconomicCalendar(CEconomicCalendar* calendar) {
    m_calendar = calendar;
}

bool CNewsAnalyzer::Initialize() {
    if(m_useCache && FileIsExist(m_cacheFile)) {
        if(LoadFromCache()) {
            return true;
        }
    }

    return UpdateNews(true);
}

void CNewsAnalyzer::AddSource(ENUM_NEWS_SOURCE sourceType, string apiUrl, string apiKey = "", bool isActive = true) {
    if(m_sourceCount >= ArraySize(m_sources)) {
        HandleError("Maximum number of news sources reached");
        return;
    }

    NewsSource source;
    source.sourceType = sourceType;
    source.apiUrl = apiUrl;
    source.apiKey = apiKey;
    source.isActive = isActive;
    source.lastUpdate = 0;
    source.updateInterval = 1800; // 30 minutes default

    // Set source name based on type
    switch(sourceType) {
        case SOURCE_REUTERS: source.name = "Reuters"; break;
        case SOURCE_BLOOMBERG: source.name = "Bloomberg"; break;
        case SOURCE_FINANCIAL_TIMES: source.name = "Financial Times"; break;
        case SOURCE_MARKETWATCH: source.name = "MarketWatch"; break;
        case SOURCE_FOREXFACTORY: source.name = "ForexFactory"; break;
        case SOURCE_TRADING_ECONOMICS: source.name = "Trading Economics"; break;
        default: source.name = "Custom Source"; break;
    }

    m_sources[m_sourceCount] = source;
    m_sourceCount++;
}

void CNewsAnalyzer::SetCacheSettings(bool useCache, string cacheFile = "") {
    m_useCache = useCache;
    if(cacheFile != "") {
        m_cacheFile = cacheFile;
    }
}

void CNewsAnalyzer::SetSentimentAnalysis(bool useExternal, string apiUrl = "", string apiKey = "") {
    m_useExternalSentiment = useExternal;
    m_sentimentApiUrl = apiUrl;
    m_sentimentApiKey = apiKey;
}

bool CNewsAnalyzer::UpdateNews(bool force) {
    if(!force && (TimeCurrent() - m_lastUpdate) < m_updateInterval) {
        return true;
    }

    if(!CheckWebrequestPermissions()) {
        HandleError("Web requests are not allowed in terminal settings");
        return false;
    }

    ClearArticles();

    // If we have an economic calendar, check for high impact events
    if(m_calendar != NULL && m_calendar.IsUpdateNeeded()) {
        m_calendar.UpdateCalendar();
    }

    // Process each active source
    for(int i = 0; i < m_sourceCount; i++) {
        if(!m_sources[i].isActive || (TimeCurrent() - m_sources[i].lastUpdate) < m_sources[i].updateInterval) {
            continue;
        }

        if(FetchNewsData(m_sources[i])) {
            m_sources[i].lastUpdate = TimeCurrent();
        }
    }

    // Analyze sentiment for all articles
    for(int i = 0; i < ArraySize(m_articles); i++) {
        AnalyzeArticleSentiment(m_articles[i]);
    }

    // Sort articles by time (newest first)
    SortArticles();

    // Save to cache
    if(m_useCache) {
        SaveToCache();
    }

    m_lastUpdate = TimeCurrent();
    return ArraySize(m_articles) > 0;
}

bool CNewsAnalyzer::CheckWebrequestPermissions() {
    if(!TerminalInfoInteger(TERMINAL_DLLS_ALLOWED)) {
        HandleError("DLLs are not allowed in terminal settings");
        return false;
    }

    if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED)) {
        HandleError("Trading is not allowed in terminal settings");
        return false;
    }

    return true;
}

bool CNewsAnalyzer::FetchNewsData(NewsSource& source) {
    string headers = "";

    // Add API key if needed
    if(source.apiKey != "") {
        headers = "Authorization: Bearer " + source.apiKey + "\r\nContent-Type: application/json";
    }

    // Add time range parameters
    datetime now = TimeCurrent();
    datetime yesterday = now - 86400;
    string url = source.apiUrl;

    if(StringFind(url, "{") >= 0) {
        string startDate = TimeToString(yesterday, TIME_DATE);
        string endDate = TimeToString(now, TIME_DATE);
        StringReplace(url, "{start_date}", startDate);
        StringReplace(url, "{end_date}", endDate);
    }

    char data[];
    string resultHeaders = "";
    int statusCode = 0;

    // Make the web request
    ResetLastError();
    statusCode = WebRequest("GET", url, headers, 15000, data, resultHeaders);

    if(statusCode != 200) {
        HandleError(StringFormat("News API request failed with status %d for source %s. Error: %d. URL: %s",
                   statusCode, source.name, GetLastError(), url));
        return false;
    }

    // Parse the response
    string response = CharArrayToString(data);
    return ParseNewsApiResponse(response, source);
}

bool CNewsAnalyzer::ParseNewsApiResponse(string response, NewsSource& source) {
    // This is a simplified implementation - actual parsing would depend on the API format

    // For demonstration, we'll create some sample articles from the calendar events
    if(m_calendar != NULL) {
        datetime now = TimeCurrent();
        datetime yesterday = now - 86400;

        int eventCount = 0;
        EconomicEvent* events = m_calendar.GetEventsInTimeframe(yesterday, now, eventCount);

        if(events != NULL) {
            for(int i = 0; i < eventCount && i < 10; i++) { // Limit to 10 articles
                EconomicEvent event = events[i];

                // Skip low impact events
                if(event.impactLevel < IMPACT_MEDIUM) {
                    continue;
                }

                NewsArticle article;
                article.publishTime = event.eventTime;
                article.headline = StringFormat("%s %s: %s",
                    event.currency, event.eventName,
                    event.isReleased ? "Released" : "Expected");

                article.summary = StringFormat("Economic event for %s: %s. ",
                    event.country, event.eventName);

                if(event.isReleased) {
                    article.summary += StringFormat("Actual: %s, Forecast: %s, Previous: %s",
                        event.actualValue != EMPTY_VALUE ? DoubleToString(event.actualValue, 2) : "N/A",
                        event.forecastValue != EMPTY_VALUE ? DoubleToString(event.forecastValue, 2) : "N/A",
                        event.previousValue != EMPTY_VALUE ? DoubleToString(event.previousValue, 2) : "N/A");
                } else {
                    article.summary += StringFormat("Expected to release soon. Forecast: %s, Previous: %s",
                        event.forecastValue != EMPTY_VALUE ? DoubleToString(event.forecastValue, 2) : "N/A",
                        event.previousValue != EMPTY_VALUE ? DoubleToString(event.previousValue, 2) : "N/A");
                }

                article.url = "https://www.forexfactory.com";
                article.source = source.name;

                // Determine affected symbols
                string symbols[];
                int symbolCount = 0;

                // Major pairs involving this currency
                if(event.currency == "USD") {
                    symbols = {"EURUSD", "GBPUSD", "USDJPY", "AUDUSD", "USDCAD", "USDCHF", "NZDUSD"};
                } else if(event.currency == "EUR") {
                    symbols = {"EURUSD", "EURGBP", "EURJPY", "EURAUD", "EURCAD", "EURCHF", "EURNZD"};
                } else if(event.currency == "GBP") {
                    symbols = {"GBPUSD", "EURGBP", "GBPJPY", "GBPAUD", "GBPCAD", "GBPCHF", "GBPNZD"};
                } else if(event.currency == "JPY") {
                    symbols = {"USDJPY", "EURJPY", "GBPJPY", "AUDJPY", "CADJPY", "CHFJPY", "NZDJPY"};
                } else {
                    // Default to USD pairs
                    symbols = {event.currency + "USD", "USD" + event.currency};
                }

                ArrayResize(article.relatedSymbols, ArraySize(symbols));
                for(int j = 0; j < ArraySize(symbols); j++) {
                    article.relatedSymbols[j] = symbols[j];
                }

                article.isTechnical = false;
                article.isFundamental = true;
                article.isSentiment = false;
                article.lastAnalyzed = TimeCurrent();

                // Add to articles array
                int size = ArraySize(m_articles);
                ArrayResize(m_articles, size + 1);
                m_articles[size] = article;
            }
        }

        return true;
    }

    HandleError("No economic calendar available for news generation");
    return false;
}

void CNewsAnalyzer::AnalyzeArticleSentiment(NewsArticle& article) {
    if(m_useExternalSentiment) {
        // Call external sentiment API
        char data[];
        string headers = "Content-Type: application/json";
        if(m_sentimentApiKey != "") {
            headers = "Authorization: Bearer " + m_sentimentApiKey + "\r\n" + headers;
        }

        string payload = StringFormat("{\"text\": \"%s\", \"source\": \"%s\"}",
            StringReplace(article.headline + ". " + article.summary, "\"", "\\\"", 0),
            article.source);

        string resultHeaders = "";
        int statusCode = WebRequest("POST", m_sentimentApiUrl, headers, 10000, data, payload, resultHeaders);

        if(statusCode == 200) {
            string response = CharArrayToString(data);
            CJAVal json;
            if(json.Deserialize(response)) {
                article.sentimentScore = (float)json.Prop("sentiment_score").Dbl();
                article.impactScore = (int)json.Prop("impact_score").Int();
                article.sentimentLevel = (ENUM_SENTIMENT)json.Prop("sentiment_level").Int();
                return;
            }
        }
    }

    // Fallback to internal sentiment analysis
    string text = article.headline + " " + article.summary;
    StringToLower(text);

    // Simple keyword-based sentiment analysis
    int positiveCount = 0;
    int negativeCount = 0;

    // Positive keywords
    string positiveWords[] = {"increase", "growth", "strong", "positive", "beat", "rise", "gain", "bullish", "buy", "upside"};
    // Negative keywords
    string negativeWords[] = {"decrease", "decline", "weak", "negative", "miss", "fall", "drop", "bearish", "sell", "downside"};

    for(int i = 0; i < ArraySize(positiveWords); i++) {
        if(StringFind(text, positiveWords[i]) >= 0) {
            positiveCount++;
        }
    }

    for(int i = 0; i < ArraySize(negativeWords); i++) {
        if(StringFind(text, negativeWords[i]) >= 0) {
            negativeCount++;
        }
    }

    // Calculate sentiment score
    if(positiveCount + negativeCount > 0) {
        article.sentimentScore = (positiveCount - negativeCount) / (double)(positiveCount + negativeCount);
    } else {
        article.sentimentScore = 0.0;
    }

    // Determine impact score based on event importance and release status
    article.impactScore = 30; // Base score

    if(article.isFundamental) {
        article.impactScore += 20;
    }

    if(StringFind(text, "fed") >= 0 || StringFind(text, "ecb") >= 0 || StringFind(text, "boj") >= 0 ||
       StringFind(text, "bank of") >= 0 || StringFind(text, "interest rate") >= 0) {
        article.impactScore += 30;
    }

    if(StringFind(text, "gdp") >= 0 || StringFind(text, "nonfarm") >= 0 || StringFind(text, "jobs") >= 0 ||
       StringFind(text, "cpi") >= 0 || StringFind(text, "inflation") >= 0) {
        article.impactScore += 25;
    }

    if(StringFind(article.headline, "surprise") >= 0 || StringFind(article.headline, "shock") >= 0) {
        article.impactScore += 20;
    }

    // Cap impact score at 100
    if(article.impactScore > 100) {
        article.impactScore = 100;
    }

    // Set sentiment level
    article.sentimentLevel = CalculateSentimentLevel(article.sentimentScore);
}

ENUM_SENTIMENT CNewsAnalyzer::CalculateSentimentLevel(double score) {
    if(score >= 0.5) return SENTIMENT_VERY_POSITIVE;
    if(score >= 0.1) return SENTIMENT_POSITIVE;
    if(score <= -0.5) return SENTIMENT_VERY_NEGATIVE;
    if(score <= -0.1) return SENTIMENT_NEGATIVE;
    return SENTIMENT_NEUTRAL;
}

void CNewsAnalyzer::ClearArticles() {
    ArrayResize(m_articles, 0);
}

void CNewsAnalyzer::SortArticles() {
    int count = ArraySize(m_articles);
    if(count <= 1) return;

    // Bubble sort by publish time (newest first)
    for(int i = 0; i < count - 1; i++) {
        for(int j = 0; j < count - i - 1; j++) {
            if(m_articles[j].publishTime < m_articles[j+1].publishTime) {
                NewsArticle temp = m_articles[j];
                m_articles[j] = m_articles[j+1];
                m_articles[j+1] = temp;
            }
        }
    }
}

bool CNewsAnalyzer::AnalyzeSentimentForSymbol(string symbol, datetime fromTime, datetime toTime,
                                               double& averageSentiment, int& articleCount, string& summary) {
    // Force update if needed
    if((TimeCurrent() - m_lastUpdate) > m_updateInterval) {
        UpdateNews();
    }

    // Get relevant articles for the symbol in time range
    NewsArticle* articles = GetLatestArticles(20, symbol); // Get up to 20 recent articles
    if(articles == NULL) {
        averageSentiment = 0.0;
        articleCount = 0;
        summary = "No relevant news articles found";
        return false;
    }

    double totalSentiment = 0.0;
    int relevantCount = 0;
    string summaryText = "";

    for(int i = 0; i < ArraySize(m_articles); i++) {
        // Check if article is in time range and relevant to symbol
        if(m_articles[i].publishTime >= fromTime && m_articles[i].publishTime <= toTime) {
            bool isRelevant = false;

            // Check if symbol is in related symbols
            for(int j = 0; j < ArraySize(m_articles[i].relatedSymbols); j++) {
                if(m_articles[i].relatedSymbols[j] == symbol) {
                    isRelevant = true;
                    break;
                }
            }

            // Also check if article text mentions the symbol or its currencies
            if(!isRelevant) {
                string baseCurrency = StringSubstr(symbol, 0, 3);
                string quoteCurrency = StringSubstr(symbol, 3, 3);
                string articleText = m_articles[i].headline + " " + m_articles[i].summary;

                if(StringFind(articleText, baseCurrency) >= 0 || StringFind(articleText, quoteCurrency) >= 0) {
                    isRelevant = true;
                }
            }

            if(isRelevant) {
                totalSentiment += m_articles[i].sentimentScore * (m_articles[i].impactScore / 100.0); // Weight by impact
                relevantCount++;

                // Build summary
                if(relevantCount <= 5) { // Include first 5 articles in summary
                    if(summaryText != "") summaryText += "\n";
                    summaryText += StringFormat("[%s] %s: Sentiment %s",
                        TimeToString(m_articles[i].publishTime, TIME_MINUTES),
                        m_articles[i].headline,
                        EnumToString(m_articles[i].sentimentLevel));
                }
            }
        }
    }

    averageSentiment = (relevantCount > 0) ? totalSentiment / relevantCount : 0.0;
    articleCount = relevantCount;
    summary = (summaryText != "") ? summaryText : "No significant sentiment changes detected";

    return true;
}

NewsArticle* CNewsAnalyzer::GetLatestArticles(int count, string symbolFilter) {
    // Force update if needed
    if((TimeCurrent() - m_lastUpdate) > m_updateInterval) {
        UpdateNews();
    }

    // Filter articles by symbol if needed
    int filteredCount = 0;
    NewsArticle filteredArticles[];

    for(int i = 0; i < ArraySize(m_articles); i++) {
        bool include = true;

        if(symbolFilter != "") {
            include = false;

            // Check if symbol is in related symbols
            for(int j = 0; j < ArraySize(m_articles[i].relatedSymbols); j++) {
                if(m_articles[i].relatedSymbols[j] == symbolFilter) {
                    include = true;
                    break;
                }
            }

            // Also check if article text mentions the symbol or its currencies
            if(!include) {
                string baseCurrency = StringSubstr(symbolFilter, 0, 3);
                string quoteCurrency = StringSubstr(symbolFilter, 3, 3);
                string articleText = m_articles[i].headline + " " + m_articles[i].summary;

                if(StringFind(articleText, baseCurrency) >= 0 || StringFind(articleText, quoteCurrency) >= 0) {
                    include = true;
                }
            }
        }

        if(include) {
            int currentSize = ArraySize(filteredArticles);
            ArrayResize(filteredArticles, currentSize + 1);
            filteredArticles[currentSize] = m_articles[i];
            filteredCount++;

            if(filteredCount >= count) {
                break;
            }
        }
    }

    if(filteredCount == 0) {
        return NULL;
    }

    return GetPointer(filteredArticles[0]);
}

bool CNewsAnalyzer::IsMarketSensitiveNews(string symbol, int bufferMinutes, int& minutesToNews, ENUM_SENTIMENT& sentiment) {
    datetime now = TimeCurrent();
    datetime endTime = now + bufferMinutes * 60;

    // Get high impact events from calendar that might affect this symbol
    int eventCount = 0;
    EconomicEvent* events = NULL;

    if(m_calendar != NULL) {
        events = m_calendar.GetEventsInTimeframe(now, endTime, eventCount);
    }

    if(events == NULL || eventCount == 0) {
        minutesToNews = 0;
        sentiment = SENTIMENT_NEUTRAL;
        return false;
    }

    // Get currencies from symbol
    string baseCurrency = StringSubstr(symbol, 0, 3);
    string quoteCurrency = StringSubstr(symbol, 3, 3);

    // Check for high impact events for these currencies
    for(int i = 0; i < eventCount; i++) {
        if((events[i].currency == baseCurrency || events[i].currency == quoteCurrency) &&
           events[i].impactLevel >= IMPACT_HIGH) {
            minutesToNews = (int)((events[i].eventTime - now) / 60);

            // Determine sentiment based on forecast vs previous
            if(events[i].isReleased) {
                if(events[i].actualValue > events[i].forecastValue) {
                    sentiment = (baseCurrency == "USD" || baseCurrency == events[i].currency) ?
                                 SENTIMENT_POSITIVE : SENTIMENT_NEGATIVE;
                } else if(events[i].actualValue < events[i].forecastValue) {
                    sentiment = (baseCurrency == "USD" || baseCurrency == events[i].currency) ?
                                 SENTIMENT_NEGATIVE : SENTIMENT_POSITIVE;
                } else {
                    sentiment = SENTIMENT_NEUTRAL;
                }
            } else {
                // For upcoming events, use neutral sentiment or analyze forecast vs previous
                if(events[i].forecastValue > events[i].previousValue) {
                    sentiment = (baseCurrency == "USD" || baseCurrency == events[i].currency) ?
                                 SENTIMENT_POSITIVE : SENTIMENT_NEGATIVE;
                } else if(events[i].forecastValue < events[i].previousValue) {
                    sentiment = (baseCurrency == "USD" || baseCurrency == events[i].currency) ?
                                 SENTIMENT_NEGATIVE : SENTIMENT_POSITIVE;
                } else {
                    sentiment = SENTIMENT_NEUTRAL;
                }
            }

            return true;
        }
    }

    minutesToNews = 0;
    sentiment = SENTIMENT_NEUTRAL;
    return false;
}

bool CNewsAnalyzer::LoadFromCache() {
    int handle = FileOpen(m_cacheFile, FILE_READ|FILE_BIN);
    if(handle == INVALID_HANDLE) {
        HandleError("Failed to open cache file for reading");
        return false;
    }

    ClearArticles();

    // Read header info
    int version = FileReadInteger(handle);
    datetime timestamp = FileReadLong(handle);
    int articleCount = FileReadInteger(handle);

    // Check if cache is still valid
    if((TimeCurrent() - timestamp) > m_updateInterval * 2) { // Allow some flexibility
        FileClose(handle);
        return false;
    }

    // Read articles
    ArrayResize(m_articles, articleCount);
    for(int i = 0; i < articleCount; i++) {
        m_articles[i].publishTime = FileReadLong(handle);
        FileReadString(handle, m_articles[i].headline, 128);
        FileReadString(handle, m_articles[i].summary, 256);
        FileReadString(handle, m_articles[i].url, 128);
        FileReadString(handle, m_articles[i].source, 32);

        // Read related symbols
        int symbolCount = FileReadInteger(handle);
        ArrayResize(m_articles[i].relatedSymbols, symbolCount);
        for(int j = 0; j < symbolCount; j++) {
            FileReadString(handle, m_articles[i].relatedSymbols[j], 16);
        }

        m_articles[i].sentimentScore = FileReadDouble(handle);
        m_articles[i].sentimentLevel = (ENUM_SENTIMENT)FileReadInteger(handle);
        m_articles[i].impactScore = FileReadInteger(handle);
        m_articles[i].isTechnical = FileReadInteger(handle) != 0;
        m_articles[i].isFundamental = FileReadInteger(handle) != 0;
        m_articles[i].isSentiment = FileReadInteger(handle) != 0;
        m_articles[i].lastAnalyzed = FileReadLong(handle);
    }

    FileClose(handle);
    m_lastUpdate = timestamp;
    return true;
}

bool CNewsAnalyzer::SaveToCache() {
    int handle = FileOpen(m_cacheFile, FILE_WRITE|FILE_BIN);
    if(handle == INVALID_HANDLE) {
        HandleError("Failed to open cache file for writing");
        return false;
    }

    // Write header info
    FileWriteInteger(handle, 1); // Version
    FileWriteLong(handle, TimeCurrent());
    FileWriteInteger(handle, ArraySize(m_articles));

    // Write articles
    for(int i = 0; i < ArraySize(m_articles); i++) {
        FileWriteLong(handle, m_articles[i].publishTime);
        FileWriteString(handle, m_articles[i].headline);
        FileWriteString(handle, m_articles[i].summary);
        FileWriteString(handle, m_articles[i].url);
        FileWriteString(handle, m_articles[i].source);

        // Write related symbols
        int symbolCount = ArraySize(m_articles[i].relatedSymbols);
        FileWriteInteger(handle, symbolCount);
        for(int j = 0; j < symbolCount; j++) {
            FileWriteString(handle, m_articles[i].relatedSymbols[j]);
        }

        FileWriteDouble(handle, m_articles[i].sentimentScore);
        FileWriteInteger(handle, m_articles[i].sentimentLevel);
        FileWriteInteger(handle, m_articles[i].impactScore);
        FileWriteInteger(handle, m_articles[i].isTechnical ? 1 : 0);
        FileWriteInteger(handle, m_articles[i].isFundamental ? 1 : 0);
        FileWriteInteger(handle, m_articles[i].isSentiment ? 1 : 0);
        FileWriteLong(handle, m_articles[i].lastAnalyzed);
    }

    FileClose(handle);
    return true;
}

void CNewsAnalyzer::HandleError(string error) {
    m_lastError = error;
    Print("NewsAnalyzer Error: ", error);
}

#endif // NEWS_MQH