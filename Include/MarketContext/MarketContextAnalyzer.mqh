//+------------------------------------------------------------------+
//| MarketContextAnalyzer.mqh                                        |
//| Unified Market State Analysis integrating VWAP, VP and OrderFlow |
//| Copyright 2025, EFFATA Trading Systems                           |
//+------------------------------------------------------------------+
#property copyright "2025, EFFATA Trading Systems"
#property version   "1.00"


#include "../Indicators/VWAP.mqh"
#include "../Indicators/VolumeProfile.mqh"
#include "../Indicators/OrderFlow.mqh"

struct UnifiedMarketState {
    double price;
    double vwap_deviation;
    double hvn_distance;
    ENUM_PROFILE_SHAPE profile_shape;
    double delta;
    double cumulative_delta;
    bool   delta_divergence;
    int    stacked_imbalances; // 1: Buy, -1: Sell, 0: None
    bool   unfinished_business;
    double sentiment_score;    // -1 to 1
};

class CMarketContextAnalyzer {
private:
    string              m_symbol;
    ENUM_TIMEFRAMES     m_period;
    CVWAP*              m_vwap;
    CVolumeProfile*     m_vp;
    COrderFlowAnalyzer* m_of;

public:
    CMarketContextAnalyzer(string symbol, ENUM_TIMEFRAMES period) {
        m_symbol = symbol;
        m_period = period;
        m_vwap = new CVWAP(symbol, period);
        m_vp = new CVolumeProfile(symbol, period);
        m_of = new COrderFlowAnalyzer(symbol, period);
    }

    ~CMarketContextAnalyzer() {
        delete m_vwap;
        delete m_vp;
        delete m_of;
    }

    UnifiedMarketState Analyze() {
        UnifiedMarketState state;
        state.price = iClose(m_symbol, m_period, 0);

        // 1. VWAP Analysis
        state.vwap_deviation = m_vwap->GetDeviation();

        // 2. Volume Profile Analysis
        m_vp->Calculate(1000);
        state.hvn_distance = state.price - m_vp->GetHVN();
        state.profile_shape = m_vp->DetectShape();

        // 3. Order Flow Analysis
        m_of->Update(100);
        state.delta = m_of->GetDelta(0);
        state.cumulative_delta = m_of->GetCumulativeDelta(0);
        state.delta_divergence = m_of->DetectDeltaDivergence(0);
        state.stacked_imbalances = m_of->DetectStackedImbalances(0);
        state.unfinished_business = m_of->HasUnfinishedBusiness(0);

        // 4. Sentiment Integration
        state.sentiment_score = CalculateSentiment(state);

        return state;
    }

private:
    double CalculateSentiment(const UnifiedMarketState &state) {
        double score = 0;

        // VWAP Contribution
        score += (state.vwap_deviation > 0 ? 0.2 : -0.2);

        // Profile Shape Contribution
        if(state.profile_shape == SHAPE_P) score += 0.3;
        if(state.profile_shape == SHAPE_B) score -= 0.3;

        // Order Flow Contribution
        if(state.delta > 0) score += 0.2;
        else score -= 0.2;

        if(state.stacked_imbalances == 1) score += 0.4;
        if(state.stacked_imbalances == -1) score -= 0.4;

        if(state.delta_divergence) score *= 0.5; // Neutralize on divergence

        // Cap score
        if(score > 1.0) score = 1.0;
        if(score < -1.0) score = -1.0;

        return score;
    }
};
