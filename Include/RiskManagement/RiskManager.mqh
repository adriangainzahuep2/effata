//+------------------------------------------------------------------+
//| RiskManager.mqh                                                  |
//| Multi-Asset Risk Orchestration                                   |
//| Copyright 2025, EFFATA Trading Systems                           |
//+------------------------------------------------------------------+
#property copyright "2025, EFFATA Trading Systems"
#property version   "1.00"
#property strict

#include "../Environments/RiskManagementEnv.mqh"
#include "AccountProtector.mqh"

class CRiskManager {
private:
    CRiskManagementEnv* m_env;
    CAccountProtector*  m_protector;

public:
    CRiskManager() {
        m_env = new CRiskManagementEnv();
        m_protector = new CAccountProtector(0.19, 5.0);
    }

    ~CRiskManager() {
        delete m_env;
        delete m_protector;
    }

    bool ValidateSignal(string symbol, int action, double entry, double sl, double tp, double confidence) {
        RiskDecision decision = m_env->EvaluateSignal(symbol, action, entry, sl, tp, confidence);
        if(!decision.approved) {
            Print("Signal Rejected: ", decision.rejectionReason);
            return false;
        }
        return true;
    }

    void Update() {
        m_protector->Monitor();
        m_env->UpdateRiskMetrics();
    }

    double GetPositionSize(string symbol, double sl) {
        return m_env->CalculatePositionSize(symbol, sl, 0.5);
    }
};
