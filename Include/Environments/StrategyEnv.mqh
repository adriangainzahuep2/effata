//+------------------------------------------------------------------+
//| StrategyEnv.mqh                                                  |
//| Strategy Environment for EFFATA Orchestrator                     |
//| Copyright 2025, EFFATA Reinforcement Trading Systems             |
//+------------------------------------------------------------------+
#property copyright "2025, EFFATA Reinforcement Trading Systems"
#property version   "3.20"
#property strict

#include "../Core/Structures.mqh"
#include "../Strategies/BillionaireStrategies.mqh"

class CStrategyEnv {
private:
   // Strategies
   StrategyPivotsDay *m_stratPivotsDay;
   StrategyPivotsH4FibonacciR1S1Reversal *m_stratH4Rev;

   // Internal State
   double m_currentConfidence;

public:
   CStrategyEnv() {
      m_stratPivotsDay = new StrategyPivotsDay();
      m_stratH4Rev = new StrategyPivotsH4FibonacciR1S1Reversal();
   }

   ~CStrategyEnv() {
      delete m_stratPivotsDay;
      delete m_stratH4Rev;
   }

   bool Initialize() {
      return true;
   }

   void UpdateFromTick(const double &features[]) {
      m_stratPivotsDay->Calculate();
      m_stratH4Rev->Calculate();
   }

   // Self-Verification logic for strategies
   void SelfVerify(const double &features[]) {
      // Check consistency
   }

   void ConsolidateMemory() {
      // Clean up old signals
   }

   void OnSessionChange(const MarketContext &context) {
      // Adjust strategy parameters based on session
   }

   // Get combined signal
   int GetSignal() {
      int s1 = m_stratPivotsDay->GetSignal();
      int s2 = m_stratH4Rev->GetSignal();

      if(s1 == s2) return s1;
      return 0; // Conflict
   }

   TradeDecision GetTradingDecision(const double &features[], const MarketContext &ctx) {
       TradeDecision decision;
       decision.Initialize();

       int signal = GetSignal();
       if(signal != 0) {
           decision.action = (signal == 1) ? BUY_SIGNAL : SELL_SIGNAL;
           decision.confidence = 0.7; // Default strategy confidence
           decision.reasoning = "Institutional pivot alignment detected";

           double price = iClose(_Symbol, PERIOD_CURRENT, 0);
           double atr = iATR(_Symbol, PERIOD_CURRENT, 14, 0);

           if(decision.action == BUY_SIGNAL) {
               decision.stopLoss = price - atr * 1.5;
               decision.takeProfit = price + atr * 3.0;
           } else {
               decision.stopLoss = price + atr * 1.5;
               decision.takeProfit = price - atr * 3.0;
           }
       }

       return decision;
   }
};
