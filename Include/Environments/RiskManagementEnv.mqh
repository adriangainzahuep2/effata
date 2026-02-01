//+------------------------------------------------------------------+
//| RiskManagementEnv.mqh                                            |
//| Advanced Risk Management for Prop Firm and Institutional Trading |
//| Copyright 2025, QuantEdge Institutional Systems                  |
//+------------------------------------------------------------------+
#property copyright "2025, QuantEdge Institutional Systems"
#property version   "2.1"
#property strict

#ifndef RISK_MANAGEMENT_ENV_MQH
#define RISK_MANAGEMENT_ENV_MQH

#include <Trade/Trade.mqh>
#include <Trade/PositionInfo.mqh>
#include <Trade/AccountInfo.mqh>
#include <Math/Stat/Math.mqh>

// Account phases for prop firms
enum ENUM_ACCOUNT_PHASE {
    PHASE_CHALLENGE,
    PHASE_EVALUATION,
    PHASE_FUNDED,
    PHASE_SUSPENDED
};

enum ENUM_DRAWDOWN_TYPE {
    DRAWDOWN_FIXED,         // FTMO Style: based on start-of-day balance
    DRAWDOWN_TRAILING_EOD,  // MyForexFunds Style: based on end-of-day balance
    DRAWDOWN_TRAILING_INTRADAY // APEX/Tradeify Style: based on peak equity
};

// Prop firm rules structure
struct PropFirmRules {
    double maxDailyLoss;           // Maximum daily loss as percentage of account
    double maxTrailingDrawdown;    // Maximum trailing drawdown percentage
    ENUM_DRAWDOWN_TYPE drawdownType;
    double maxPositionSize;        // Maximum position size in lots
    double maxDailyTrades;         // Maximum number of trades per day
    double maxCorrelationExposure; // Maximum correlation exposure percentage
    double minTradingDays;         // Minimum trading days required
    double profitTarget;           // Profit target percentage
    ENUM_ACCOUNT_PHASE accountPhase;
    bool isWeekendTradingAllowed;
    bool isNewsTradingAllowed;
    double maxLeverage;
};

struct RiskMetrics {
    double dailyLoss;
    double trailingDrawdown;
    double currentExposure;
    double correlationRisk;
    double volatilityAdjustedRisk;
    int tradesToday;
    datetime lastTradeTime;
};

struct RiskDecision {
    bool approved;
    string rejectionReason;
    string reasoning;
    double recommendedSL;
    double recommendedTP;
    double positionSize;
};

class CRiskManagementEnv {
private:
    PropFirmRules m_rules;
    RiskMetrics m_metrics;
    CPositionInfo m_positions;
    CAccountInfo m_account;
    CTrade m_trade;
    string m_symbol;
    double m_initialBalance;
    double m_peakEquity;
    datetime m_tradingDayStart;

    // Risk factor weights
    double m_drawdownWeight;
    double m_correlationWeight;
    double m_volatilityWeight;
    double m_exposureWeight;

public:
    CRiskManagementEnv();
    ~CRiskManagementEnv();

    bool Initialize(PropFirmRules &rules);
    RiskDecision EvaluateSignal(string symbol, int action, double entryPrice, double slPrice, double tpPrice, double confidence);
    bool IsTradeAllowed(string symbol, int action);
    double CalculatePositionSize(string symbol, double slPrice, double riskPercent = 0.5);
    void UpdateRiskMetrics();
    void ResetDailyMetrics();
    void OnTradeExecuted(double volume);

    PropFirmRules GetPropFirmRules() { return m_rules; }
    RiskMetrics GetRiskMetrics() { return m_metrics; }
    double GetAvailableRiskPercentage();

private:
    double CalculatePositionRisk(string symbol, double slPrice, double entryPrice);
    double CalculateCorrelationRisk(string symbol);
    double CalculateVolatilityAdjustment(string symbol);
    bool CheckDailyLossLimit();
    bool CheckTrailingDrawdown();
    bool CheckPositionSizeLimit(double positionSize);
    bool CheckMaxTradesLimit();
    bool CheckNewsTradingRestriction();
    double CalculateRiskRewardRatio(double entryPrice, double slPrice, double tpPrice);
    double GetAccountCurrencyConversion(string symbol);
    bool IsWeekend();
    bool IsDuringNewsEvent(string symbol);
};

CRiskManagementEnv::CRiskManagementEnv() {
    m_initialBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    m_peakEquity = AccountInfoDouble(ACCOUNT_EQUITY);

    // Set default risk weights
    m_drawdownWeight = 0.4;
    m_correlationWeight = 0.25;
    m_volatilityWeight = 0.2;
    m_exposureWeight = 0.15;

    // Default initialization
    m_tradingDayStart = iTime(_Symbol, PERIOD_D1, 0);
    UpdateRiskMetrics();
}

CRiskManagementEnv::~CRiskManagementEnv() {
}

bool CRiskManagementEnv::Initialize(PropFirmRules &rules) {
    m_rules = rules;
    m_initialBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    m_peakEquity = AccountInfoDouble(ACCOUNT_EQUITY);

    // Validate rules
    if(m_rules.maxDailyLoss <= 0 || m_rules.maxTrailingDrawdown <= 0) {
        Print("Invalid prop firm rules configuration");
        return false;
    }

    if(m_rules.accountPhase == PHASE_SUSPENDED) {
        Print("Account is suspended, risk management disabled");
        return false;
    }

    return true;
}

void CRiskManagementEnv::UpdateRiskMetrics() {
    double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);
    double currentBalance = AccountInfoDouble(ACCOUNT_BALANCE);

    // Update peak equity for trailing drawdown calculation
    if(currentEquity > m_peakEquity) {
        m_peakEquity = currentEquity;
    }

    // Calculate daily loss (from balance at start of day)
    datetime todayStart = iTime(_Symbol, PERIOD_D1, 0);
    if(todayStart > m_tradingDayStart) {
        // New trading day
        m_tradingDayStart = todayStart;
        m_initialBalance = currentBalance;
        m_metrics.tradesToday = 0;
    }

    m_metrics.dailyLoss = (m_initialBalance - currentBalance) / m_initialBalance;

    // Calculate drawdown based on firm-specific rules
    if(m_rules.drawdownType == DRAWDOWN_TRAILING_INTRADAY) {
        // APEX Style: uses peak equity
        m_metrics.trailingDrawdown = (m_peakEquity - currentEquity) / m_peakEquity;
    } else if(m_rules.drawdownType == DRAWDOWN_FIXED) {
        // FTMO Style: uses initial/daily balance
        m_metrics.trailingDrawdown = (m_initialBalance - currentEquity) / m_initialBalance;
    } else {
        m_metrics.trailingDrawdown = (m_initialBalance - currentEquity) / m_initialBalance;
    }

    // Calculate current exposure
    double marginUsed = AccountInfoDouble(ACCOUNT_MARGIN);
    double equity = AccountInfoDouble(ACCOUNT_EQUITY);
    m_metrics.currentExposure = marginUsed / equity;

    // Count trades today
    m_metrics.tradesToday = 0;
    datetime now = TimeCurrent();
    datetime today = StringToTime(TimeToString(now, TIME_DATE));
    HistorySelect(today, now + 86400);

    for(int i = 0; i < HistoryDealsTotal(); i++) {
        ulong ticket = HistoryDealGetTicket(i);
        if(HistoryDealGetInteger(ticket, DEAL_ENTRY) == DEAL_ENTRY_IN) {
            m_metrics.tradesToday++;
        }
    }

    // Calculate correlation risk for all open positions
    m_metrics.correlationRisk = 0.0;
    if(m_positions.Total() > 0) {
        double totalRisk = 0.0;

        for(int i = 0; i < m_positions.Total(); i++) {
            string symbol = m_positions.GetSymbol(i);
            double positionSize = m_positions.Volume(i);
            double slPrice = 0; // Need to calculate or store SL

            // Simple correlation risk calculation based on currency pairs
            string baseCurr = StringSubstr(symbol, 0, 3);
            string quoteCurr = StringSubstr(symbol, 3, 3);

            // Count positions with same base or quote currency
            int correlatedCount = 0;
            for(int j = 0; j < m_positions.Total(); j++) {
                if(i == j) continue;
                string otherSymbol = m_positions.GetSymbol(j);
                string otherBase = StringSubstr(otherSymbol, 0, 3);
                string otherQuote = StringSubstr(otherSymbol, 3, 3);

                if(baseCurr == otherBase || baseCurr == otherQuote ||
                   quoteCurr == otherBase || quoteCurr == otherQuote) {
                    correlatedCount++;
                }
            }

            // Risk contribution based on correlation
            double riskContribution = positionSize * (1 + correlatedCount * 0.2);
            totalRisk += riskContribution;
        }

        m_metrics.correlationRisk = totalRisk / equity;
    }

    // Calculate volatility-adjusted risk
    m_metrics.volatilityAdjustedRisk = 0.0;
    if(m_positions.Total() > 0) {
        double volatilitySum = 0.0;

        for(int i = 0; i < m_positions.Total(); i++) {
            string symbol = m_positions.GetSymbol(i);
            double atr = iATR(symbol, PERIOD_CURRENT, 14, 0);
            double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
            volatilitySum += atr / point;
        }

        m_metrics.volatilityAdjustedRisk = volatilitySum / m_positions.Total();
    }
}

RiskDecision CRiskManagementEnv::EvaluateSignal(string symbol, int action, double entryPrice, double slPrice, double tpPrice, double confidence) {
    RiskDecision decision;
    ZeroMemory(decision);
    decision.approved = true;
    decision.recommendedSL = slPrice;
    decision.recommendedTP = tpPrice;

    // Update risk metrics first
    UpdateRiskMetrics();

    // Check if trading is allowed at all
    if(!IsTradeAllowed(symbol, action)) {
        decision.approved = false;
        decision.rejectionReason = "Trading not allowed due to account restrictions";
        return decision;
    }

    // Validate risk-reward ratio
    double rrRatio = CalculateRiskRewardRatio(entryPrice, slPrice, tpPrice);
    if(rrRatio < 1.5) {
        decision.approved = false;
        decision.rejectionReason = StringFormat("Poor risk-reward ratio: %.2f (minimum 1.5 required)", rrRatio);
        return decision;
    }

    // Calculate position risk
    double positionRisk = CalculatePositionRisk(symbol, slPrice, entryPrice);

    // Calculate volatility adjustment
    double volatilityFactor = CalculateVolatilityAdjustment(symbol);

    // Calculate correlation risk
    double correlationRisk = CalculateCorrelationRisk(symbol);

    // Apply risk adjustment factors
    double adjustedRisk = positionRisk * volatilityFactor * (1 + correlationRisk);

    // Check against maximum risk per trade (usually 1% of equity)
    double maxRiskPerTrade = 0.01; // 1%
    if(adjustedRisk > maxRiskPerTrade) {
        // Recalculate position size to meet risk limit
        double equity = AccountInfoDouble(ACCOUNT_EQUITY);
        double riskAmount = equity * maxRiskPerTrade;

        // Calculate new position size
        double priceDiff = MathAbs(entryPrice - slPrice);
        double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
        double point = SymbolInfoDouble(symbol, SYMBOL_POINT);

        decision.positionSize = riskAmount / (priceDiff / point * tickValue);

        // Recalculate SL to maintain risk with standard lot size
        double standardLotSize = 0.1; // Minimum trade size
        if(decision.positionSize < standardLotSize) {
            decision.positionSize = standardLotSize;
            decision.recommendedSL = entryPrice - (riskAmount / (standardLotSize * tickValue)) * (action == SELL_SIGNAL ? -1 : 1) * point;
        } else {
            decision.recommendedSL = slPrice; // Keep original SL
        }

        decision.reasoning += StringFormat("Risk adjusted: %.2f%% > %.2f%% max. New size: %.2f lots\n",
            adjustedRisk*100, maxRiskPerTrade*100, decision.positionSize);
    } else {
        decision.positionSize = CalculatePositionSize(symbol, slPrice);
        decision.reasoning = StringFormat("Risk accepted: %.2f%%\nVolatility factor: %.2f\nCorrelation risk: %.2f%%",
            adjustedRisk*100, volatilityFactor, correlationRisk*100);
    }

    // Apply prop firm rules checks
    // Daily loss limit (0.19% as per requirements)
    if(m_metrics.dailyLoss >= 0.0019) {
        decision.approved = false;
        decision.rejectionReason = StringFormat("CRITICAL: Daily loss limit (0.19%%) reached: %.4f%%", m_metrics.dailyLoss*100);
        return decision;
    }

    if(m_rules.accountPhase == PHASE_CHALLENGE || m_rules.accountPhase == PHASE_EVALUATION || m_rules.accountPhase == PHASE_FUNDED) {
        // Challenge/evaluation/funded phase has strict rules

        // Check trailing drawdown
        if(m_metrics.trailingDrawdown >= m_rules.maxTrailingDrawdown) {
            decision.approved = false;
            decision.rejectionReason = StringFormat("Trailing drawdown exceeded: %.2f%% (max: %.2f%%)",
                m_metrics.trailingDrawdown*100, m_rules.maxTrailingDrawdown*100);
            return decision;
        }

        // Check position size limit
        if(!CheckPositionSizeLimit(decision.positionSize)) {
            decision.approved = false;
            decision.rejectionReason = StringFormat("Position size exceeds limit: %.2f lots (max: %.2f lots)",
                decision.positionSize, m_rules.maxPositionSize);
            return decision;
        }

        // Check max trades per day
        if(!CheckMaxTradesLimit()) {
            decision.approved = false;
            decision.rejectionReason = StringFormat("Maximum daily trades reached: %d (max: %.0f)",
                m_metrics.tradesToday, m_rules.maxDailyTrades);
            return decision;
        }

        // Check news trading restriction
        if(!m_rules.isNewsTradingAllowed && IsDuringNewsEvent(symbol)) {
            decision.approved = false;
            decision.rejectionReason = "News trading not allowed during challenge phase";
            return decision;
        }
    }

    // Weekend trading check
    if(!m_rules.isWeekendTradingAllowed && IsWeekend()) {
        decision.approved = false;
        decision.rejectionReason = "Weekend trading not allowed";
        return decision;
    }

    // Final risk score calculation
    double riskScore = (m_metrics.trailingDrawdown / m_rules.maxTrailingDrawdown) * m_drawdownWeight +
                      (m_metrics.correlationRisk / m_rules.maxCorrelationExposure) * m_correlationWeight +
                      (m_metrics.volatilityAdjustedRisk / 2.0) * m_volatilityWeight + // Normalize volatility
                      (m_metrics.currentExposure / 0.3) * m_exposureWeight; // Assuming 30% is high exposure

    if(riskScore > 0.7) { // High risk score threshold
        decision.approved = false;
        decision.rejectionReason = StringFormat("Overall risk score too high: %.2f (threshold: 0.7)", riskScore);
        return decision;
    }

    // Apply risk score to confidence
    decision.confidence = confidence * (1 - riskScore);

    // Final risk-reward check with adjusted confidence
    if(decision.confidence < 0.6 && rrRatio < 2.0) {
        decision.approved = false;
        decision.rejectionReason = StringFormat("Low confidence (%.2f) with moderate risk-reward (%.2f)",
            decision.confidence, rrRatio);
    }

    return decision;
}

double CRiskManagementEnv::CalculatePositionSize(string symbol, double slPrice, double riskPercent) {
    if(slPrice == 0) return 0.1; // Default to 0.1 lots if no SL

    double equity = AccountInfoDouble(ACCOUNT_EQUITY);
    double riskAmount = equity * (riskPercent / 100.0);

    double entryPrice = (PositionSelect(symbol) && PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ?
                        SymbolInfoDouble(symbol, SYMBOL_BID) : SymbolInfoDouble(symbol, SYMBOL_ASK);

    double priceDiff = MathAbs(entryPrice - slPrice);
    double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
    double point = SymbolInfoDouble(symbol, SYMBOL_POINT);

    double positionSize = riskAmount / (priceDiff / point * tickValue);

    // Apply maximum position size limit
    if(positionSize > m_rules.maxPositionSize) {
        positionSize = m_rules.maxPositionSize;
    }

    // Apply minimum lot size
    double minLotSize = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
    double lotStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);

    if(positionSize < minLotSize) {
        return 0.0; // Too small to trade
    }

    // Round to nearest lot step
    positionSize = MathFloor(positionSize / lotStep) * lotStep;

    return positionSize;
}

double CRiskManagementEnv::CalculateRiskRewardRatio(double entryPrice, double slPrice, double tpPrice) {
    if(slPrice == 0 || tpPrice == 0) return 0.0;

    double risk = MathAbs(entryPrice - slPrice);
    double reward = MathAbs(tpPrice - entryPrice);

    if(risk == 0) return 0.0;

    return reward / risk;
}

bool CRiskManagementEnv::IsTradeAllowed(string symbol, int action) {
    // Check account status
    if(m_rules.accountPhase == PHASE_SUSPENDED) {
        return false;
    }

    // Check leverage limits
    double currentLeverage = AccountInfoDouble(ACCOUNT_LEVERAGE);
    if(currentLeverage > m_rules.maxLeverage) {
        return false;
    }

    // Check symbol-specific restrictions
    if(m_rules.accountPhase == PHASE_CHALLENGE) {
        // In challenge phase, only allow major pairs
        string base = StringSubstr(symbol, 0, 3);
        string quote = StringSubstr(symbol, 3, 3);

        if(!(base == "EUR" || base == "USD" || base == "GBP" || base == "JPY" || base == "AUD" || base == "CAD" || base == "CHF" ||
             quote == "EUR" || quote == "USD" || quote == "GBP" || quote == "JPY" || quote == "AUD" || quote == "CAD" || quote == "CHF")) {
            return false;
        }
    }

    return true;
}

void CRiskManagementEnv::OnTradeExecuted(double volume) {
    m_metrics.tradesToday++;
    m_metrics.lastTradeTime = TimeCurrent();
    UpdateRiskMetrics();
}

// Other methods (implementation details for brevity)

#endif // RISK_MANAGEMENT_ENV_MQH