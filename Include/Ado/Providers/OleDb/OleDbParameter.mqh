//+------------------------------------------------------------------+
//|                                               OleDbParameter.mqh |
//|                                             Copyright GF1D, 2010 |
//|                                             garf1eldhome@mail.ru |
//+------------------------------------------------------------------+
#property copyright "GF1D, 2010"
#property link      "garf1eldhome@mail.ru"

#include "..\Base\DbParameter.mqh"
//--------------------------------------------------------------------
/// \brief  \~russian \xca\xeb\xe0\xf1\xf1, \xef\xf0\xe5\xe4\xf1\xf2\xe0\xe2\xeb\xff\xfe\xf9\xe8\xe9 \xef\xe0\xf0\xe0\xec\xe5\xf2\xf0 \xea\xee\xec\xe0\xed\xe4\xfb OLE DB
///         \~english Represents command parameter in an OLE DB data source
class COleDbParameter : public CDbParameter
  {
public:
   /// \brief  \~russian \xea\xee\xed\xf1\xf2\xf0\xf3\xea\xf2\xee\xf0 \xea\xeb\xe0\xf1\xf1\xe0
   ///         \~english constructor
                     COleDbParameter();
  };
//--------------------------------------------------------------------
COleDbParameter::COleDbParameter()
  {
   MqlTypeName("COleDbParameter");
   CreateClrObject("System.Data","System.Data.OleDb.OleDbParameter");
  }
//+------------------------------------------------------------------+
