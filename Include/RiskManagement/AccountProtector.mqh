//+------------------------------------------------------------------+
//| AccountProtector.mqh                                             |
//| Automated Account Protection and Equity Shielding                |
//| Copyright 2025, EFFATA Trading Systems                           |
//+------------------------------------------------------------------+
#property copyright "2025, EFFATA Trading Systems"
#property version   "1.00"
#property strict

#include <Trade/Trade.mqh>
#include <Trade/PositionInfo.mqh>

class CAccountProtector {
private:
    CTrade          m_trade;
    CPositionInfo   m_position;
    double          m_max_daily_loss;
    double          m_max_drawdown;
    double          m_starting_equity;
    datetime        m_last_reset;

public:
    CAccountProtector(double max_daily_loss_pct = 0.19, double max_drawdown_pct = 5.0) {
        m_max_daily_loss = max_daily_loss_pct / 100.0;
        m_max_drawdown = max_drawdown_pct / 100.0;
        m_starting_equity = AccountInfoDouble(ACCOUNT_EQUITY);
        m_last_reset = TimeCurrent();
    }

    void Monitor() {
        CheckDailyReset();

        double current_equity = AccountInfoDouble(ACCOUNT_EQUITY);
        double current_drawdown = (m_starting_equity - current_equity) / m_starting_equity;

        if(current_drawdown >= m_max_daily_loss) {
            Print("!!! EMERGENCY SHUTDOWN: Daily loss limit reached !!!");
            CloseAllPositions();
            ExpertRemove();
        }
    }

    void CloseAllPositions() {
        for(int i = PositionsTotal() - 1; i >= 0; i--) {
            ulong ticket = PositionGetTicket(i);
            if(ticket > 0) {
                m_trade.PositionClose(ticket);
            }
        }
    }

private:
    void CheckDailyReset() {
        MqlDateTime now, start;
        TimeToStruct(TimeCurrent(), now);
        TimeToStruct(m_last_reset, start);

        if(now.day != start.day) {
            m_starting_equity = AccountInfoDouble(ACCOUNT_EQUITY);
            m_last_reset = TimeCurrent();
            Print("Account Protector: Daily reset performed.");
        }
    }
};
