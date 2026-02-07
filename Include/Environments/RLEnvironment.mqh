//+------------------------------------------------------------------+
//| RLEnvironment.mqh                                                |
//| Reinforcement Learning Environment for Trading                   |
//| Implements OpenAI Gym-style interface for MQL5                   |
//| Copyright 2025, EFFATA Trading Systems                           |
//+------------------------------------------------------------------+
#property copyright "2025, EFFATA Trading Systems"
#property link      "https://www.effata.ai"
#property version   "1.00"
#property strict

#include <Trade\Trade.mqh>
#include "..\MarketContext\MarketContextAnalyzer.mqh"
#include "..\Indicators\OrderFlow.mqh"
#include "..\Indicators\VolumeProfile.mqh"
#include "..\Indicators\VWAP.mqh"

// Action space
enum ENUM_RL_ACTION {
    RL_ACTION_HOLD = 0,
    RL_ACTION_BUY = 1,
    RL_ACTION_SELL = 2,
    RL_ACTION_CLOSE = 3
};

struct RLState {
    double features[128];
    int featureCount;
};

struct RLStepResult {
    RLState nextState;
    double reward;
    bool done;
    string info;
};

class CRLEnvironment {
private:
    CMarketContextAnalyzer* m_context;
    COrderFlow*             m_orderFlow;
    CVolumeProfile*         m_volumeProfile;
    CVWAP*                  m_vwap;
    CTrade                  m_trade;

    string m_symbol;
    ENUM_TIMEFRAMES m_timeframe;

    double m_lastEquity;
    int m_maxSteps;
    int m_currentStep;

public:
    CRLEnvironment(string symbol, ENUM_TIMEFRAMES tf) {
        m_symbol = symbol;
        m_timeframe = tf;
        m_context = new CMarketContextAnalyzer(symbol, tf);
        m_orderFlow = new COrderFlow();
        m_volumeProfile = new CVolumeProfile();
        m_vwap = new CVWAP(symbol, tf);

        m_lastEquity = AccountInfoDouble(ACCOUNT_EQUITY);
        m_maxSteps = 1000;
        m_currentStep = 0;
    }

    ~CRLEnvironment() {
        delete m_context;
        delete m_orderFlow;
        delete m_volumeProfile;
        delete m_vwap;
    }

    RLState Reset() {
        m_currentStep = 0;
        m_lastEquity = AccountInfoDouble(ACCOUNT_EQUITY);
        return GetState();
    }

    RLStepResult Step(ENUM_RL_ACTION action) {
        ExecuteAction(action);

        RLStepResult result;
        result.nextState = GetState();
        result.reward = CalculateReward();
        result.done = (m_currentStep >= m_maxSteps) || IsBankrupt();
        result.info = "Step " + IntegerToString(m_currentStep);

        m_currentStep++;
        return result;
    }

private:
    RLState GetState() {
        RLState state;
        ArrayInitialize(state.features, 0);

        UnifiedMarketState contextState = m_context->Analyze();

        int i = 0;
        state.features[i++] = contextState.price;
        state.features[i++] = contextState.vwap_deviation;
        state.features[i++] = contextState.delta;
        state.features[i++] = contextState.cumulative_delta;
        state.features[i++] = contextState.sentiment_score;
        state.features[i++] = contextState.hvn_distance;
        state.features[i++] = (double)contextState.stacked_imbalances;

        // Add more features from indicators
        state.features[i++] = m_vwap.GetDeviation();

        state.featureCount = i;
        return state;
    }

    void ExecuteAction(ENUM_RL_ACTION action) {
        switch(action) {
            case RL_ACTION_BUY:
                m_trade.Buy(0.1, m_symbol);
                break;
            case RL_ACTION_SELL:
                m_trade.Sell(0.1, m_symbol);
                break;
            case RL_ACTION_CLOSE:
                // Close all positions for this symbol
                break;
            case RL_ACTION_HOLD:
            default:
                break;
        }
    }

    double CalculateReward() {
        double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);
        double reward = currentEquity - m_lastEquity;
        m_lastEquity = currentEquity;
        return reward;
    }

    bool IsBankrupt() {
        return AccountInfoDouble(ACCOUNT_EQUITY) < AccountInfoDouble(ACCOUNT_MARGIN_SO_SO);
    }
};
