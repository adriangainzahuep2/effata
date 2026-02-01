//+------------------------------------------------------------------+
//|                                              OleDbConnection.mqh |
//|                                             Copyright GF1D, 2010 |
//|                                             garf1eldhome@mail.ru |
//+------------------------------------------------------------------+
#property copyright "GF1D, 2010"
#property link      "garf1eldhome@mail.ru"

#include "..\Base\DbConnection.mqh"
#include "OleDbTransaction.mqh"
//--------------------------------------------------------------------
/// \brief  \~russian \xca\xeb\xe0\xf1\xf1, \xef\xee\xe7\xe2\xee\xeb\xff\xfe\xf9\xe8\xe9 \xf3\xf1\xf2\xe0\xed\xe0\xe2\xeb\xe8\xe2\xe0\xf2\xfc \xef\xee\xe4\xea\xeb\xfe\xf7\xe5\xed\xe8\xe5 \xea \xe8\xf1\xf2\xee\xf7\xed\xe8\xea\xf3 \xe4\xe0\xed\xed\xfb\xf5 OLE DB
///         \~english Represents a connection to an OLE DB data source
class COleDbConnection : public CDbConnection
  {
protected:
   virtual CDbTransaction *CreateTransaction() { return new COleDbTransaction(); }

public:
   /// \brief  \~russian \xea\xee\xed\xf1\xf2\xf0\xf3\xea\xf2\xee\xf0
   ///         \~english constructor
                     COleDbConnection();
  };
//--------------------------------------------------------------------
COleDbConnection::COleDbConnection()
  {
   MqlTypeName("COleDbConnection");
   CreateClrObject("System.Data","System.Data.OleDb.OleDbConnection");
  }
//+------------------------------------------------------------------+
