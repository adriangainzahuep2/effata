//+------------------------------------------------------------------+
//|                                                    AdoErrors.mqh |
//|                                             Copyright GF1D, 2010 |
//|                                             garf1eldhome@mail.ru |
//+------------------------------------------------------------------+
#property copyright "GF1D, 2010"
#property link      "garf1eldhome@mail.ru"

#define ADOERR_FIRST    5000
#define ADOERR_LAST     5100
//#define ADOERR_CONNECTION_ERROR    5001
//#define ADOERR_TRANSACTION_ERROR    5002

//-------------------------------------------------------------------------
/// \brief  \~russian \xcf\xf0\xee\xe2\xe5\xf0\xff\xe5\xf2 \xe2\xee\xe7\xed\xe8\xea\xeb\xe0 \xeb\xe8 \xee\xf8\xe8\xe1\xea\xe0, \xf1\xe2\xff\xe7\xe0\xed\xed\xe0\xff \xf1 AdoSuite
///         \~english Checks if there was an error caused by AdoSuite
bool CheckAdoError()
  {
   return _LastError>=ERR_USER_ERROR_FIRST+ADOERR_FIRST && _LastError<=ERR_USER_ERROR_FIRST+ADOERR_LAST;
  }
//-------------------------------------------------------------------------
/// \brief  \~russian \xd1\xe1\xf0\xe0\xf1\xfb\xe2\xe0\xe5\xf2 \xee\xf8\xe8\xe1\xea\xf3, \xe5\xf1\xeb\xe8 \xee\xed\xe0 \xf1\xe2\xff\xe7\xe0\xed\xe0 \xf1 AdoSuite
///         \~english Resets the last Ado error if there was one
void ResetAdoError()
  {
   if(CheckAdoError()) ResetLastError();
  }
//+------------------------------------------------------------------+
