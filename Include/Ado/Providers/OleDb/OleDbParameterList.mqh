//+------------------------------------------------------------------+
//|                                           OleDbParameterList.mqh |
//|                                             Copyright GF1D, 2010 |
//|                                             garf1eldhome@mail.ru |
//+------------------------------------------------------------------+
#property copyright "GF1D, 2010"
#property link      "garf1eldhome@mail.ru"

#include "OleDbParameter.mqh"
#include "..\Base\DbParameterList.mqh"
//--------------------------------------------------------------------
/// \brief  \~russian \xca\xeb\xe0\xf1\xf1, \xef\xf0\xe5\xe4\xf1\xf2\xe0\xe2\xeb\xff\xfe\xf9\xe8\xe9 \xea\xee\xeb\xeb\xe5\xea\xf6\xe8\xfe \xef\xe0\xf0\xe0\xec\xe5\xf2\xf0\xee\xe2 \xea\xee\xec\xe0\xed\xe4\xfb OLE DB
///         \~english Represents parameter collection in an OLE DB data source
class COleDbParameterList : public CDbParameterList
  {
protected:
   virtual CDbParameter *CreateParameter() { return new COleDbParameter(); }

public:
   /// \brief  \~russian \xea\xee\xed\xf1\xf2\xf0\xf3\xea\xf2\xee\xf0 \xea\xeb\xe0\xf1\xf1\xe0
   ///         \~english constructor
                     COleDbParameterList();
  };
//--------------------------------------------------------------------
COleDbParameterList::COleDbParameterList()
  {
   MqlTypeName("COleDbParameterList");
  }
//+------------------------------------------------------------------+
