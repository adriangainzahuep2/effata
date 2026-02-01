//+------------------------------------------------------------------+
//|                                                     AdoTable.mqh |
//|                                             Copyright GF1D, 2010 |
//|                                             garf1eldhome@mail.ru |
//+------------------------------------------------------------------+
#property copyright "GF1D, 2010"
#property link      "garf1eldhome@mail.ru"

#include "AdoColumnList.mqh"
#include "AdoRecordList.mqh"
#include "AdoRecord.mqh"
#include "..\AdoTypes.mqh"
//--------------------------------------------------------------------
/// \brief  \~russian \xca\xeb\xe0\xf1\xf1, \xef\xf0\xe5\xe4\xf1\xf2\xe0\xe2\xeb\xff\xfe\xf9\xe8\xe9 \xf2\xe0\xe1\xeb\xe8\xf6\xf3 \xf1 \xe4\xe0\xed\xed\xfb\xec\xe8
///         \~english Represents table
class CAdoTable
  {
private:
   CAdoColumnList   *_Columns;
   CAdoRecordList   *_Records;
   string            _TableName;

protected:
   /// \brief  \~russian \xd1\xee\xe7\xe4\xe0\xe5\xf2 \xea\xee\xeb\xeb\xe5\xea\xf6\xe8\xfe \xf1\xf2\xee\xeb\xe1\xf6\xee\xe2 \xf2\xe0\xe1\xeb\xe8\xf6\xfb. \xc2\xe8\xf0\xf2\xf3\xe0\xeb\xfc\xed\xfb\xe9 \xec\xe5\xf2\xee\xe4
   ///         \~english Creates column collection for the table
   virtual CAdoColumnList *CreateColumns() { return new CAdoColumnList(); }
   /// \brief  \~russian \xd1\xee\xe7\xe4\xe0\xe5\xf2 \xea\xee\xeb\xeb\xe5\xea\xf6\xe8\xfe \xe7\xe0\xef\xe8\xf1\xe5\xe9 \xf2\xe0\xe1\xeb\xe8\xf6\xfb. \xc2\xe8\xf0\xf2\xf3\xe0\xeb\xfc\xed\xfb\xe9 \xec\xe5\xf2\xee\xe4
   ///         \~english Creates row collection for the table
   virtual CAdoRecordList *CreateRecords() { return new CAdoRecordList(); }

public:
   /// \brief  \~russian \xe4\xe5\xf1\xf2\xf0\xf3\xea\xf2\xee\xf0 \xea\xeb\xe0\xf1\xf1\xe0
   ///         \~english destructor
                    ~CAdoTable();

   // proprerties

   /// \brief  \~russian \xc2\xee\xe7\xe2\xf0\xe0\xf9\xe0\xe5\xf2 \xe8\xec\xff \xf2\xe0\xe1\xeb\xe8\xf6\xfb
   ///         \~english Gets table name
   const string TableName() { return _TableName; }
   /// \brief  \~russian \xc7\xe0\xe4\xe0\xe5\xf2 \xe8\xec\xff \xf2\xe0\xe1\xeb\xe8\xf6\xfb
   ///         \~english Sets table name
   void TableName(const string value) { _TableName=value; }

   /// \brief  \~russian \xc2\xee\xe7\xe2\xf0\xe0\xf9\xe0\xe5\xf2 \xea\xee\xeb\xeb\xe5\xea\xf6\xe8\xfe \xf1\xf2\xee\xeb\xe1\xf6\xee\xe2
   ///         \~english Gets column collection
   CAdoColumnList   *Columns();
   /// \brief  \~russian \xc2\xee\xe7\xe2\xf0\xe0\xf9\xe0\xe5\xf2 \xea\xee\xeb\xeb\xe5\xea\xf6\xe8\xfe \xe7\xe0\xef\xe8\xf1\xe5\xe9
   ///         \~english Gets row collection
   CAdoRecordList   *Records();

   /// \brief  \~russian \xcf\xf0\xee\xe2\xe5\xf0\xff\xe5\xf2 \xe5\xf1\xf2\xfc \xeb\xe8 \xe7\xe0\xef\xe8\xf1\xe8 \xe2 \xf2\xe0\xe1\xeb\xe8\xf6\xe5
   ///         \~english Checks if the table has rows
   const bool HasRows() { return Records().Total()>0; }

   // method

   /// \brief  \~russian \xd1\xee\xe7\xe4\xe0\xe5\xf2 \xe7\xe0\xef\xe8\xf1\xfc \xf1 \xed\xe5\xee\xe1\xf5\xee\xe4\xe8\xec\xee\xe9 \xf1\xf2\xf0\xf3\xea\xf2\xf3\xf0\xee\xe9. \xd1\xeb\xe5\xe4\xf3\xe5\xf2 \xe8\xf1\xef\xee\xeb\xfc\xe7\xee\xe2\xe0\xf2\xfc \xf2\xee\xeb\xfc\xea\xee \xfd\xf2\xee\xf2 \xec\xe5\xf2\xee\xe4!
   ///         \~english Creates new row with neccessary scheme. You should use this method only!
   CAdoRecord       *CreateRecord();
  };
//--------------------------------------------------------------------
CAdoTable::~CAdoTable(void)
  {
   if(CheckPointer(_Columns)) delete _Columns;
   if(CheckPointer(_Records)) delete _Records;
  }
//--------------------------------------------------------------------
CAdoColumnList *CAdoTable::Columns()
  {
   if(!CheckPointer(_Columns))
      _Columns=CreateColumns();

   return _Columns;
  }
//--------------------------------------------------------------------
CAdoRecordList *CAdoTable::Records(void)
  {
   if(!CheckPointer(_Records))
      _Records=CreateRecords();

   return _Records;
  }
//--------------------------------------------------------------------
CAdoRecord *CAdoTable::CreateRecord()
  {
   CAdoRecord *rec=Records().CreateElement();
   rec.SetColumns(Columns());
   return rec;
  }
//+------------------------------------------------------------------+
