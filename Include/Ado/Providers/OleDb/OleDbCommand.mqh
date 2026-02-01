//+------------------------------------------------------------------+
//|                                                 OleDbCommand.mqh |
//|                                             Copyright GF1D, 2010 |
//|                                             garf1eldhome@mail.ru |
//+------------------------------------------------------------------+
#property copyright "GF1D, 2010"
#property link      "garf1eldhome@mail.ru"

#include "..\Base\DbCommand.mqh"
#include "OleDbParameterList.mqh"
#include "OleDbDataReader.mqh"
//--------------------------------------------------------------------
/// \brief  \~russian \xca\xeb\xe0\xf1\xf1, \xef\xf0\xe5\xe4\xf1\xf2\xe0\xe2\xeb\xff\xfe\xf9\xe8\xe9 \xe8\xf1\xef\xee\xeb\xed\xff\xe5\xec\xf3\xfe \xea\xee\xec\xe0\xed\xe4\xf3 \xe2 \xe8\xf1\xf2\xee\xf7\xed\xe8\xea\xe5 \xe4\xe0\xed\xed\xfb\xf5 OLE DB
///         \~english Represents an SQL statement or stored procedure to execute against an OLE DB data source
class COleDbCommand : public CDbCommand
  {
protected:
   virtual CDbParameterList *CreateParameters() { return new COleDbParameterList(); }
   virtual CDbDataReader *CreateReader() { return new COleDbDataReader(); }

public:
   /// \brief  \~russian \xea\xee\xed\xf1\xf2\xf0\xf3\xea\xf2\xee\xf0
   ///         \~english constructor
                     COleDbCommand();
  };
//--------------------------------------------------------------------
COleDbCommand::COleDbCommand()
  {
   MqlTypeName("COleDbCommand");
   CreateClrObject("System.Data","System.Data.OleDb.OleDbCommand");
  }
//+------------------------------------------------------------------+
