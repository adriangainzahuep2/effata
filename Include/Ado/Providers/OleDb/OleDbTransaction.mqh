//+------------------------------------------------------------------+
//|                                             OleDbTransaction.mqh |
//|                                             Copyright GF1D, 2010 |
//|                                             garf1eldhome@mail.ru |
//+------------------------------------------------------------------+
#property copyright "GF1D, 2010"
#property link      "garf1eldhome@mail.ru"

#include "..\Base\DbTransaction.mqh"
//--------------------------------------------------------------------
/// \brief  \~russian \xca\xeb\xe0\xf1\xf1, \xef\xf0\xe5\xe4\xf1\xf2\xe0\xe2\xeb\xff\xfe\xf9\xe8\xe9 \xf2\xf0\xe0\xed\xe7\xe0\xea\xf6\xe8\xfe OLE DB
///         \~english Represents transaction in an OLE DB data source
class COleDbTransaction : public CDbTransaction
  {
public:
   /// \brief  \~russian \xea\xee\xed\xf1\xf2\xf0\xf3\xea\xf2\xee\xf0 \xea\xeb\xe0\xf1\xf1\xe0
   ///         \~english constructor
                     COleDbTransaction();
  };
//--------------------------------------------------------------------
COleDbTransaction::COleDbTransaction()
  {
   MqlTypeName("COleDbTransaction");
  }
//+------------------------------------------------------------------+
