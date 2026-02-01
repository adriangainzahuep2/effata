//+------------------------------------------------------------------+
//|                                                    AdoColumn.mqh |
//|                                             Copyright GF1D, 2010 |
//|                                             garf1eldhome@mail.ru |
//+------------------------------------------------------------------+
#property copyright "GF1D, 2010"
#property link      "garf1eldhome@mail.ru"

#include <Object.mqh>
#include "..\AdoTypes.mqh"
//--------------------------------------------------------------------
/// \brief  \~russian \xca\xeb\xe0\xf1\xf1, \xef\xf0\xe5\xe4\xf1\xf2\xe0\xe2\xeb\xff\xfe\xf9\xe8\xe9 \xf1\xf2\xee\xeb\xe1\xe5\xf6 \xe2 AdoTable
///         \~english Represents a column of an AdoTable
class CAdoColumn : public CObject
  {
private:
   string            _Name;
   ENUM_ADOTYPES     _Type;

public:
   // properties

   /// \brief  \~russian \xc2\xee\xe7\xe2\xf0\xe0\xf9\xe0\xe5\xf2 \xe8\xec\xff \xf1\xf2\xee\xeb\xe1\xf6\xe0
   ///         \~english Gets column name
   const string ColumnName() { return _Name; }
   /// \brief  \~russian \xc7\xe0\xe4\xe0\xe5\xf2 \xe8\xec\xff \xf1\xf2\xee\xeb\xe1\xf6\xe0
   ///         \~english Sets column name
   void ColumnName(const string value) { _Name=value; }

   /// \brief  \~russian \xc2\xee\xe7\xe2\xf0\xe0\xf9\xe0\xe5\xf2 \xf2\xe8\xef \xf1\xf2\xee\xeb\xe1\xf6\xe0
   ///         \~english Gets type of a value stored in the column
   const ENUM_ADOTYPES ColumnType() { return _Type; }
   /// \brief  \~russian \xc7\xe0\xe4\xe0\xe5\xf2 \xf2\xe8\xef \xf1\xf2\xee\xeb\xe1\xf6\xe0
   ///         \~english Sets type of a value stored in the column
   void ColumnType(const ENUM_ADOTYPES value) { _Type=value; }

   /// \brief  \~russian \xc2\xee\xe7\xe2\xf0\xe0\xf9\xe0\xe5\xf2 \xf2\xe8\xef \xee\xe1\xfa\xe5\xea\xf2\xe0
   ///         \~english Gets type of the object
   virtual int Type() { return ADOTYPE_COLUMN; }
  };
//+------------------------------------------------------------------+
