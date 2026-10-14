//+------------------------------------------------------------------+
//| BreakoutForge_XAU_Hybrid.mq5                                      |
//| Dual-mode EA for XAUUSD                                          |
//| MODE 1: Breakout (Nova/Apex/Zenith/Pulse/Eclipse) - trending    |
//| MODE 2: Sideways Grid (ADR/ATR spacing, fixed lots, no martingale)|
//| Auto-switch on M5 regime detection (BB middle + ADX + range)     |
//| Inspired by MoonDog structure + TradeWithPat dual-mode idea      |
//| Original code — not affiliated with MoonDog or TradeWithPat      |
//| + Balance-based lot: 0.01 below 500, 0.02 at/above 500, back to |
//|   0.01 if 50% of profit above 500 is given back                  |
//| + v2.21: auto news reaction on NFP / CPI / FOMC + manual event  |
//+------------------------------------------------------------------+
#property copyright "BreakoutForge XAU Hybrid"
#property version   "2.21"
#property strict

#include <Trade/Trade.mqh>
CTrade trade;

//==================== GENERAL ====================
input group "=== General ==="
input long   InpBaseMagic        = 770001;
input string InpComment          = "BFH";
input int    InpDeviation        = 40;
input bool   InpShowPanel        = true;
input bool   InpPanelInTester    = false;
input int    InpMaxSpreadPts     = 50;

//==================== LOT ====================
input group "=== Lot Size (Breakout + Grid base) ==="
enum ENUM_LOT_MODE { LOT_FIXED=0, LOT_RISK_PCT=1 };
input ENUM_LOT_MODE InpLotMode   = LOT_FIXED;
input double InpFixedLot         = 0.01;
input double InpRiskPercent      = 1.0;
input double InpMaxLot           = 0.10;
input double InpMinLot           = 0.01;

//==================== BALANCE-BASED LOT ====================
input group "=== Balance-based Lot (overrides fixed / grid lot when ON) ==="
input bool   InpUseBalanceLot    = true;   // ON: lot follows the balance rule below
input double InpLotBase          = 0.01;   // lot while balance < threshold (or after give-back)
input double InpLotUp            = 0.02;   // lot once balance >= threshold
input double InpBalThreshold     = 500.0;  // balance (account currency) that unlocks InpLotUp
input double InpGiveBackPct      = 50.0;   // drop to base lot if this % of profit above threshold is given back
input bool   InpLotUseEquity     = false;  // false = use closed balance, true = use equity

//==================== SL / TP (gold pips) - Breakout only ====================
input group "=== SL / TP (gold pips) - Breakout ==="
input int    InpGoldPipPoints    = 10;          // points per gold pip (usually 10 for XAU)
input int    InpSL_GoldPips      = 20;
input int    InpTP_Apex_GP       = 140;
input int    InpTP_Other_GP      = 150;
input int    InpPendingOffsetGP  = 5;
input int    InpPendingExpiryBars= 12;

//==================== PROFIT LOCK - Breakout ====================
input group "=== Virtual Profit Lock - Breakout ==="
input bool   InpUseProfitLock    = true;
input double InpLockActivateMoney= 1.0;
input double InpLockPercent      = 50.0;
input bool   InpUseBreakEvenTrail= false;
input int    InpBE_StartGP       = 30;
input int    InpBE_LockGP        = 5;
input int    InpTrailStartGP     = 50;
input int    InpTrailStepGP      = 20;

//==================== MODULES (Breakout) ====================
input group "=== Modules ON/OFF (Breakout mode) ==="
input bool   InpMod_Nova         = true;
input bool   InpMod_Apex         = true;
input bool   InpMod_Zenith       = true;
input bool   InpMod_Pulse        = true;
input bool   InpMod_Eclipse      = true;

input group "=== Module lookbacks (M5 bars) ==="
input int    InpNova_Bars        = 24;
input int    InpApex_Bars        = 18;
input int    InpZenith_Fast      = 12;
input int    InpZenith_Slow      = 36;
input int    InpPulse_Bars       = 10;
input int    InpEclipse_Bars     = 48;

//==================== REGIME DETECTION (Sideways vs Trend) ====================
input group "=== Regime Detection (M5) ==="
input bool   InpUseAutoRegime    = true;        // true = auto switch, false = force Breakout
input int    InpBB_Period        = 20;          // Bollinger middle period (SMA)
input double InpBB_FlatThreshGP  = 6.0;         // tighter: max gold-pip change of BB middle = flat
input int    InpBB_FlatLookback  = 16;          // longer lookback for smoother slope
input int    InpADX_Period       = 14;
input double InpADX_SidewaysMax  = 18.0;        // stricter: ADX must be low to enter sideways
input double InpADX_TrendMin     = 25.0;        // exit sideways earlier when ADX rises
input int    InpRangeBars        = 36;          // longer range window
input double InpRangeATR_Mult    = 2.0;         // range must be tighter vs ATR
input int    InpRegimeConfirmBars= 5;           // more bars required before switching to sideways

//==================== SIDEWAYS GRID ====================
input group "=== Sideways Grid ==="
input bool   InpGridEnabled      = true;
input int    InpGridMagicOffset  = 100;         // magic = Base + Offset
input int    InpGrid_N           = 5;           // spacing = ATR / N  (lower N = wider spacing, safer)
input double InpGrid_MinSpacingGP= 25.0;        // higher floor for gold (was 15)
input int    InpGrid_L           = 4;           // fewer levels per side (was 5) → less stack risk
input double InpGrid_Lot         = 0.0;         // 0 = auto from D formula, else fixed
input double InpGrid_EquityStopPct = 6.0;       // slightly more room than 4%
input double InpGrid_D           = 0.12;        // more conservative floating DD fraction
input bool   InpGrid_ReanchorOnFlat = true;     // re-anchor only when flat
input int    InpGrid_ATR_Period  = 14;
input bool   InpGrid_UseADR      = true;        // prefer ADR for spacing (better for gold)
input int    InpGrid_ADR_Days    = 10;          // shorter ADR window reacts faster
input double InpGrid_RangePadGP  = 5.0;         // pad inside measured range so levels don't sit on extremes
input bool   InpGrid_FlattenOnTrend = true;     // close grid positions when regime flips to TREND
input int    InpGrid_MaxOpenTotal = 6;          // hard cap total open grid positions (both sides)

//==================== NEWS / WEEKEND ====================
input group "=== News & Weekend ==="
input bool   InpProtectNFP       = true;   // if true and reaction OFF → blackout
input bool   InpProtectCPI       = true;
input bool   InpProtectFOMC      = true;
input int    InpNFP_MinBefore    = 30;
input int    InpNFP_MinAfter     = 60;
input int    InpCPI_MinBefore    = 30;
input int    InpCPI_MinAfter     = 60;
input int    InpFOMC_MinBefore   = 60;
input int    InpFOMC_MinAfter    = 150;
input bool   InpWeekendShield    = true;
input int    InpFridayStopHour   = 20;
input int    InpMondayStartHour  = 2;

//==================== NEWS REACTION TRADING ====================
input group "=== News Reaction Trading (auto + manual) ==="
input bool     InpNewsTradeEnabled   = true;   // master switch for all news reaction trades
input bool     InpNewsTradeNFP       = true;   // auto-trade NFP breakout
input bool     InpNewsTradeCPI       = true;   // auto-trade CPI breakout
input bool     InpNewsTradeFOMC      = true;   // auto-trade FOMC breakout
input datetime InpNewsEventTime      = D'1970.01.01 00:00'; // optional extra manual event (SERVER time)
input int      InpNewsRangeMinutes   = 5;      // M1 candles immediately before the event
input double   InpNewsBufferGP       = 2.0;    // Breakout buffer in gold pips
input double   InpNewsSL_GP          = 25.0;   // News trade stop loss in gold pips
input double   InpNewsRR             = 1.5;    // TP = SL * RR
input int      InpNewsTradeWindowMin = 10;     // Only take a breakout within this many minutes after release
input int      InpNewsMaxSpreadPts   = 80;     // Separate spread limit for news entries
input bool     InpNewsOneTradePerEvent = true;
input int      InpSessionStartH    = 1;
input int      InpSessionEndH      = 23;

//==================== DAILY LOSS ====================
input group "=== Daily Loss (optional) ==="
input bool   InpUseDailyLoss     = false;
input double InpDailyLossPct     = 5.0;

//==================== CONSTANTS ====================
#define MOD_NOVA    1
#define MOD_APEX    2
#define MOD_ZENITH  3
#define MOD_PULSE   4
#define MOD_ECLIPSE 5

enum ENUM_REGIME { REGIME_TREND=0, REGIME_SIDEWAYS=1 };

struct ModState
  {
   int      id;
   string   name;
   bool     enabled;
   ulong    pendingTicket;
   datetime pendingTime;
   double   peakProfit;
   ulong    posTicket;
  };

//==================== GLOBALS ====================
ModState gMod[5];
double   gDayStartEq=0;
int      gDayStamp=0;
bool     gDayStopped=false;

int      gAtrHandle=INVALID_HANDLE;
int      gEmaF=INVALID_HANDLE, gEmaS=INVALID_HANDLE;
int      gBBHandle=INVALID_HANDLE;
int      gADXHandle=INVALID_HANDLE;
int      gAtrGridHandle=INVALID_HANDLE;

ENUM_REGIME gRegime = REGIME_TREND;
int      gRegimeCount = 0;
ENUM_REGIME gPendingRegime = REGIME_TREND;

double   gGridAnchor = 0;
double   gGridSpacing = 0;
double   gEquityPeak = 0;
datetime gLastGridBar = 0;
bool     gGridActive = false;

int      gLotTier = 0;          // 0 = base lot, 1 = raised lot
double   gTierPeak = 0;         // highest balance seen while raised
double   gTierLockPeak = 0;     // peak at last give-back; balance must exceed it to raise the lot again
datetime gNewsTradedEvent = 0;  // last event timestamp we already traded
string   gNewsTradedTag   = ""; // "NFP" / "CPI" / "FOMC" / "MANUAL" for one-trade-per-event

//+------------------------------------------------------------------+
long MagicOf(int modId) { return InpBaseMagic + modId; }
long GridMagic() { return InpBaseMagic + InpGridMagicOffset; }

//+------------------------------------------------------------------+
int OnInit()
  {
   trade.SetDeviationInPoints(InpDeviation);
   trade.SetTypeFillingBySymbol(_Symbol);

   gMod[0].id=MOD_NOVA;    gMod[0].name="Nova";    gMod[0].enabled=InpMod_Nova;
   gMod[1].id=MOD_APEX;    gMod[1].name="Apex";    gMod[1].enabled=InpMod_Apex;
   gMod[2].id=MOD_ZENITH;  gMod[2].name="Zenith";  gMod[2].enabled=InpMod_Zenith;
   gMod[3].id=MOD_PULSE;   gMod[3].name="Pulse";   gMod[3].enabled=InpMod_Pulse;
   gMod[4].id=MOD_ECLIPSE; gMod[4].name="Eclipse"; gMod[4].enabled=InpMod_Eclipse;
   for(int i=0;i<5;i++)
     { gMod[i].pendingTicket=0; gMod[i].pendingTime=0; gMod[i].peakProfit=0; gMod[i].posTicket=0; }

   gAtrHandle      = iATR(_Symbol,PERIOD_M5,14);
   gEmaF          = iMA(_Symbol,PERIOD_M5,InpZenith_Fast,0,MODE_EMA,PRICE_CLOSE);
   gEmaS          = iMA(_Symbol,PERIOD_M5,InpZenith_Slow,0,MODE_EMA,PRICE_CLOSE);
   gBBHandle      = iBands(_Symbol,PERIOD_M5,InpBB_Period,0,2.0,PRICE_CLOSE);
   gADXHandle     = iADX(_Symbol,PERIOD_M5,InpADX_Period);
   gAtrGridHandle = iATR(_Symbol,PERIOD_M5,InpGrid_ATR_Period);

   if(gAtrHandle==INVALID_HANDLE || gBBHandle==INVALID_HANDLE || gADXHandle==INVALID_HANDLE)
     {
      Print("Indicator init failed");
      return INIT_FAILED;
     }

   gEquityPeak = AccountInfoDouble(ACCOUNT_EQUITY);
   ResetDay();
   LotTierInit();
   LotTierUpdate();
   Print("BreakoutForge XAU Hybrid v2.21 init — auto news reaction (NFP/CPI/FOMC + manual)");
   return INIT_SUCCEEDED;
  }

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(gAtrHandle!=INVALID_HANDLE)      IndicatorRelease(gAtrHandle);
   if(gEmaF!=INVALID_HANDLE)           IndicatorRelease(gEmaF);
   if(gEmaS!=INVALID_HANDLE)           IndicatorRelease(gEmaS);
   if(gBBHandle!=INVALID_HANDLE)       IndicatorRelease(gBBHandle);
   if(gADXHandle!=INVALID_HANDLE)      IndicatorRelease(gADXHandle);
   if(gAtrGridHandle!=INVALID_HANDLE)  IndicatorRelease(gAtrGridHandle);
   Comment("");
  }

//+------------------------------------------------------------------+
double GP2Price(double goldPips)
  {
   return goldPips * InpGoldPipPoints * SymbolInfoDouble(_Symbol,SYMBOL_POINT);
  }

double Price2GP(double priceDist)
  {
   double pt = SymbolInfoDouble(_Symbol,SYMBOL_POINT);
   if(pt<=0 || InpGoldPipPoints<=0) return 0;
   return priceDist / (InpGoldPipPoints * pt);
  }

//+------------------------------------------------------------------+
string TierKey(string n)
  {
   return "BFH_"+(string)AccountInfoInteger(ACCOUNT_LOGIN)+"_"+(string)InpBaseMagic+"_"+n;
  }

void LotTierSave()
  {
   GlobalVariableSet(TierKey("tier"),gLotTier);
   GlobalVariableSet(TierKey("peak"),gTierPeak);
   GlobalVariableSet(TierKey("lock"),gTierLockPeak);
  }

void LotTierInit()
  {
   if(MQLInfoInteger(MQL_TESTER))
     {
      GlobalVariableDel(TierKey("tier")); GlobalVariableDel(TierKey("peak")); GlobalVariableDel(TierKey("lock"));
      gLotTier=0; gTierPeak=0; gTierLockPeak=0;
     }
   else
     {
      if(GlobalVariableCheck(TierKey("tier"))) gLotTier=(int)GlobalVariableGet(TierKey("tier"));
      if(GlobalVariableCheck(TierKey("peak"))) gTierPeak=GlobalVariableGet(TierKey("peak"));
      if(GlobalVariableCheck(TierKey("lock"))) gTierLockPeak=GlobalVariableGet(TierKey("lock"));
     }
  }

// Rules:
//  - balance >= threshold            -> raised lot (InpLotUp)
//  - balance < threshold             -> base lot (InpLotBase)
//  - raised, then profit above the threshold falls by InpGiveBackPct% from its peak -> base lot
//    (stays on base lot until balance makes a new high above that peak, or drops under the threshold and recovers)
void LotTierUpdate()
  {
   if(!InpUseBalanceLot) return;
   double v = InpLotUseEquity ? AccountInfoDouble(ACCOUNT_EQUITY) : AccountInfoDouble(ACCOUNT_BALANCE);
   int    oldTier=gLotTier;
   double oldPeak=gTierPeak, oldLock=gTierLockPeak;

   if(gLotTier==0)
     {
      if(v < InpBalThreshold) gTierLockPeak=0;
      else if(v > gTierLockPeak) { gLotTier=1; gTierPeak=v; }
     }
   else
     {
      if(v > gTierPeak) gTierPeak=v;
      if(v < InpBalThreshold) { gLotTier=0; gTierLockPeak=0; gTierPeak=0; }
      else
        {
         double profit=gTierPeak-InpBalThreshold;
         if(profit>0 && v <= gTierPeak - profit*InpGiveBackPct/100.0)
           { gLotTier=0; gTierLockPeak=gTierPeak; }
        }
     }

   if(gLotTier!=oldTier || gTierPeak!=oldPeak || gTierLockPeak!=oldLock)
      LotTierSave();
   if(gLotTier!=oldTier)
      PrintFormat("LOT TIER: %s  (value %.2f, peak %.2f)", gLotTier==1?"RAISED":"BASE", v, gTierPeak);
  }

double TierLot()
  {
   return (gLotTier==1) ? InpLotUp : InpLotBase;
  }

double CalcLot()
  {
   if(InpUseBalanceLot) return NormalizeLot(TierLot());
   double lot=InpFixedLot;
   if(InpLotMode==LOT_RISK_PCT)
     {
      double eq=AccountInfoDouble(ACCOUNT_EQUITY);
      double slPrice=GP2Price(InpSL_GoldPips);
      double pt=SymbolInfoDouble(_Symbol,SYMBOL_POINT);
      double tickVal=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE);
      double tickSz =SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
      if(slPrice>0 && tickSz>0 && pt>0)
        {
         double usdPerPt=tickVal*(pt/tickSz);
         double risk=eq*(InpRiskPercent/100.0);
         double stopPts=slPrice/pt;
         if(usdPerPt>0 && stopPts>0) lot=risk/(stopPts*usdPerPt);
        }
     }
   return NormalizeLot(lot);
  }

double NormalizeLot(double lot)
  {
   double step=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   double vmin=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
   double vmax=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX);
   if(step<=0) step=0.01;
   if(vmin<=0) vmin=0.01;
   lot=MathMax(InpMinLot, MathMin(InpMaxLot, lot));
   lot=MathFloor(lot/step)*step;
   lot=MathMax(vmin, MathMin(vmax, lot));
   return NormalizeDouble(lot,2);
  }

// Grid lot from floating-DD formula (fixed, no escalation)
double CalcGridLot(double spacingPrice)
  {
   if(InpUseBalanceLot) return NormalizeLot(TierLot());
   if(InpGrid_Lot > 0) return NormalizeLot(InpGrid_Lot);

   double eq = AccountInfoDouble(ACCOUNT_EQUITY);
   double pt = SymbolInfoDouble(_Symbol,SYMBOL_POINT);
   double tickVal = SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE);
   double tickSz  = SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   if(pt<=0 || tickSz<=0 || spacingPrice<=0) return NormalizeLot(InpFixedLot);

   double usdPerPt = tickVal * (pt / tickSz);
   // MaxFloat = lot * pip_value * spacing_in_pts * L*(L+1)/2
   // We approximate pip_value via usdPerPt * points_per_gold_pip, but work in price
   double spacingPts = spacingPrice / pt;
   double maxFloatFactor = spacingPts * InpGrid_L * (InpGrid_L + 1) / 2.0;
   if(maxFloatFactor <= 0 || usdPerPt <= 0) return NormalizeLot(InpFixedLot);

   double lot = (InpGrid_D * eq) / (usdPerPt * maxFloatFactor);
   return NormalizeLot(lot);
  }

//+------------------------------------------------------------------+
void ResetDay()
  {
   MqlDateTime dt; TimeToStruct(TimeCurrent(),dt);
   int stamp=dt.year*10000+dt.mon*100+dt.day;
   if(stamp!=gDayStamp)
     {
      gDayStamp=stamp;
      gDayStartEq=AccountInfoDouble(ACCOUNT_EQUITY);
      gDayStopped=false;
     }
  }

//+------------------------------------------------------------------+
void CancelPendingsOf(long magic)
  {
   for(int i=OrdersTotal()-1;i>=0;i--)
     {
      ulong t=OrderGetTicket(i);
      if(!t) continue;
      if(OrderGetString(ORDER_SYMBOL)==_Symbol &&
         OrderGetInteger(ORDER_MAGIC)==magic)
         trade.OrderDelete(t);
     }
  }

void CancelAllBreakoutPendings()
  {
   for(int m=0;m<5;m++)
     {
      CancelPendingsOf(MagicOf(gMod[m].id));
      gMod[m].pendingTicket=0;
     }
  }

void CancelAllGridOrders()
  {
   CancelPendingsOf(GridMagic());
  }

void CloseAllGridPositions()
  {
   for(int i=PositionsTotal()-1;i>=0;i--)
     {
      ulong t=PositionGetTicket(i);
      if(!t) continue;
      if(PositionGetString(POSITION_SYMBOL)==_Symbol &&
         PositionGetInteger(POSITION_MAGIC)==GridMagic())
        {
         trade.SetExpertMagicNumber(GridMagic());
         trade.PositionClose(t);
        }
     }
  }

//+------------------------------------------------------------------+
bool DailyLossHit()
  {
   if(!InpUseDailyLoss) return false;
   ResetDay();
   if(gDayStopped) return true;
   if(gDayStartEq<=0) return false;
   double eq=AccountInfoDouble(ACCOUNT_EQUITY);
   double dd=(gDayStartEq-eq)/gDayStartEq*100.0;
   if(dd>=InpDailyLossPct)
     {
      gDayStopped=true;
      CancelAllBreakoutPendings();
      CancelAllGridOrders();
      PrintFormat("Daily loss %.2f%% — stop new trades",dd);
      return true;
     }
   return false;
  }

// Returns the approximate release datetime (broker server time) for a known event today,
// or 0 if that event is not scheduled today according to the simple calendar rules.
datetime ApproxNewsReleaseTime(const string tag)
  {
   datetime gmt = TimeGMT();
   MqlDateTime g; TimeToStruct(gmt, g);

   int releaseMin = -1;   // minutes from midnight GMT
   bool isToday   = false;

   if(tag == "NFP")
     {
      // First Friday of the month, ~12:30 GMT
      isToday = (g.day_of_week == 5 && g.day <= 7);
      releaseMin = 12 * 60 + 30;
     }
   else if(tag == "CPI")
     {
      // Rough mid-month weekday, ~12:30 GMT
      isToday = (g.day >= 10 && g.day <= 15 && g.day_of_week >= 1 && g.day_of_week <= 5);
      releaseMin = 12 * 60 + 30;
     }
   else if(tag == "FOMC")
     {
      // Wednesday, ~18:00 GMT (statement)
      isToday = (g.day_of_week == 3);
      releaseMin = 18 * 60;
     }

   if(!isToday || releaseMin < 0) return 0;

   // Build GMT datetime for the release, then convert to broker server time.
   MqlDateTime rel = g;
   rel.hour = releaseMin / 60;
   rel.min  = releaseMin % 60;
   rel.sec  = 0;
   datetime gmtRelease = StructToTime(rel);

   // Offset between server time and GMT
   datetime serverNow = TimeCurrent();
   datetime gmtNow    = TimeGMT();
   int      offsetSec = (int)(serverNow - gmtNow);

   return gmtRelease + offsetSec;
  }

// Active news event right now (reaction window only).
// tag = "NFP"/"CPI"/"FOMC"/"MANUAL", eventTime = release timestamp (server time)
bool GetActiveNewsEvent(string &tag, datetime &eventTime)
  {
   tag = "";
   eventTime = 0;
   if(!InpNewsTradeEnabled) return false;

   datetime now = TimeCurrent();
   int      win = InpNewsTradeWindowMin * 60;

   // Manual event has priority if set
   if(InpNewsEventTime > D'1970.01.02 00:00')
     {
      if(now >= InpNewsEventTime && now <= InpNewsEventTime + win)
        {
         tag = "MANUAL";
         eventTime = InpNewsEventTime;
         return true;
        }
     }

   // Auto events
   string candidates[3] = {"NFP", "CPI", "FOMC"};
   bool   enabled[3]    = {InpNewsTradeNFP, InpNewsTradeCPI, InpNewsTradeFOMC};

   for(int i = 0; i < 3; i++)
     {
      if(!enabled[i]) continue;
      datetime rel = ApproxNewsReleaseTime(candidates[i]);
      if(rel <= 0) continue;
      if(now >= rel && now <= rel + win)
        {
         tag = candidates[i];
         eventTime = rel;
         return true;
        }
     }
   return false;
  }

bool NewsBlackout()
  {
   // Blackout only when protection is on AND reaction trading for that event is off
   datetime gmt = TimeGMT();
   MqlDateTime g; TimeToStruct(gmt, g);
   int now = g.hour * 60 + g.min;

   if(InpProtectNFP && !InpNewsTradeNFP && g.day_of_week == 5 && g.day <= 7)
     {
      int rel = 12 * 60 + 30;
      if(now >= rel - InpNFP_MinBefore && now <= rel + InpNFP_MinAfter) return true;
     }
   if(InpProtectCPI && !InpNewsTradeCPI && g.day >= 10 && g.day <= 15 && g.day_of_week >= 1 && g.day_of_week <= 5)
     {
      int rel = 12 * 60 + 30;
      if(now >= rel - InpCPI_MinBefore && now <= rel + InpCPI_MinAfter) return true;
     }
   if(InpProtectFOMC && !InpNewsTradeFOMC && g.day_of_week == 3)
     {
      int rel = 18 * 60;
      if(now >= rel - InpFOMC_MinBefore && now <= rel + InpFOMC_MinAfter) return true;
     }
   return false;
  }

bool NewsTradeAlreadyTaken(const string tag, datetime eventTime)
  {
   if(!InpNewsOneTradePerEvent) return false;
   if(gNewsTradedEvent == eventTime && gNewsTradedTag == tag) return true;

   // Recover after restart: look for an open NEWS position from this event window
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(!ticket) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpBaseMagic + 900) continue;
      string cmt = PositionGetString(POSITION_COMMENT);
      if(StringFind(cmt, "NEWS") < 0) continue;
      // Any open news position blocks another trade while one-trade-per-event is on
      gNewsTradedEvent = eventTime;
      gNewsTradedTag   = tag;
      return true;
     }
   return false;
  }

bool TryNewsReactionTrade()
  {
   string   tag;
   datetime eventTime;
   if(!GetActiveNewsEvent(tag, eventTime)) return false;
   if(NewsTradeAlreadyTaken(tag, eventTime)) return true;
   if(WeekendBlocked() || !InSession()) return true;

   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double ask   = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid   = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(point <= 0 || ask <= 0 || bid <= 0) return true;
   if((ask - bid) / point > InpNewsMaxSpreadPts) return true;

   // Use only M1 bars that closed before the release timestamp
   int n = MathMax(2, InpNewsRangeMinutes);
   int shift = iBarShift(_Symbol, PERIOD_M1, eventTime, false) + 1;
   if(shift < 1) return true;

   double hi = -DBL_MAX, lo = DBL_MAX;
   for(int i = shift; i < shift + n; i++)
     {
      double h = iHigh(_Symbol, PERIOD_M1, i);
      double l = iLow(_Symbol, PERIOD_M1, i);
      if(h <= 0 || l <= 0) return true;
      if(h > hi) hi = h;
      if(l < lo) lo = l;
     }

   double buffer = GP2Price(InpNewsBufferGP);
   int dir = 0;
   if(ask > hi + buffer) dir = 1;
   else if(bid < lo - buffer) dir = -1;
   if(dir == 0) return true;   // still waiting for breakout inside the window

   double slDist = GP2Price(InpNewsSL_GP);
   if(slDist <= 0) return true;
   double tpDist = slDist * MathMax(0.1, InpNewsRR);
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double lot = CalcLot();

   trade.SetExpertMagicNumber(InpBaseMagic + 900);
   trade.SetDeviationInPoints(InpDeviation);

   string cmt = StringFormat("BFH-NEWS-%s-%s", tag, dir > 0 ? "BUY" : "SELL");
   bool ok = false;
   if(dir > 0)
      ok = trade.Buy(lot, _Symbol, 0.0,
                     NormalizeDouble(ask - slDist, digits),
                     NormalizeDouble(ask + tpDist, digits), cmt);
   else
      ok = trade.Sell(lot, _Symbol, 0.0,
                      NormalizeDouble(bid + slDist, digits),
                      NormalizeDouble(bid - tpDist, digits), cmt);

   if(ok)
     {
      gNewsTradedEvent = eventTime;
      gNewsTradedTag   = tag;
      PrintFormat("NEWS reaction (%s): %s lot=%.2f rangeHigh=%.2f rangeLow=%.2f",
                  tag, dir > 0 ? "BUY" : "SELL", lot, hi, lo);
     }
   else
      PrintFormat("NEWS trade (%s) failed: retcode=%d %s",
                  tag, trade.ResultRetcode(), trade.ResultRetcodeDescription());
   return true;
  }

bool WeekendBlocked()
  {
   if(!InpWeekendShield) return false;
   MqlDateTime dt; TimeToStruct(TimeCurrent(),dt);
   if(dt.day_of_week==5 && dt.hour>=InpFridayStopHour) return true;
   if(dt.day_of_week==6 || dt.day_of_week==0) return true;
   if(dt.day_of_week==1 && dt.hour<InpMondayStartHour) return true;
   return false;
  }

bool InSession()
  {
   MqlDateTime dt; TimeToStruct(TimeCurrent(),dt);
   if(InpSessionStartH<InpSessionEndH)
      return (dt.hour>=InpSessionStartH && dt.hour<InpSessionEndH);
   return (dt.hour>=InpSessionStartH || dt.hour<InpSessionEndH);
  }

//+------------------------------------------------------------------+
int CountPosMagic(long magic)
  {
   int n=0;
   for(int i=PositionsTotal()-1;i>=0;i--)
     {
      ulong t=PositionGetTicket(i);
      if(!t) continue;
      if(PositionGetString(POSITION_SYMBOL)==_Symbol &&
         PositionGetInteger(POSITION_MAGIC)==magic) n++;
     }
   return n;
  }

int CountPendMagic(long magic)
  {
   int n=0;
   for(int i=OrdersTotal()-1;i>=0;i--)
     {
      ulong t=OrderGetTicket(i);
      if(!t) continue;
      if(OrderGetString(ORDER_SYMBOL)==_Symbol &&
         OrderGetInteger(ORDER_MAGIC)==magic) n++;
     }
   return n;
  }

int CountPosSide(long magic, long type) // type = POSITION_TYPE_BUY or SELL
  {
   int n=0;
   for(int i=PositionsTotal()-1;i>=0;i--)
     {
      ulong t=PositionGetTicket(i);
      if(!t) continue;
      if(PositionGetString(POSITION_SYMBOL)==_Symbol &&
         PositionGetInteger(POSITION_MAGIC)==magic &&
         PositionGetInteger(POSITION_TYPE)==type) n++;
     }
   return n;
  }

//+------------------------------------------------------------------+
bool RangeHL(int bars, double &hi, double &lo)
  {
   MqlRates r[];
   if(CopyRates(_Symbol,PERIOD_M5,1,bars,r)<bars) return false;
   hi=r[0].high; lo=r[0].low;
   for(int i=1;i<bars;i++)
     {
      if(r[i].high>hi) hi=r[i].high;
      if(r[i].low<lo)  lo=r[i].low;
     }
   return true;
  }

double ATRVal()
  {
   double a[];
   if(CopyBuffer(gAtrHandle,0,0,1,a)<1) return 0;
   return a[0];
  }

double ATRGridVal()
  {
   double a[];
   if(CopyBuffer(gAtrGridHandle,0,0,1,a)<1) return 0;
   return a[0];
  }

//+------------------------------------------------------------------+
// Regime detection (PDF-inspired: BB middle flat + ADX + range)
//+------------------------------------------------------------------+
bool IsBBFlat()
  {
   double mid[];
   if(CopyBuffer(gBBHandle,0,0,InpBB_FlatLookback+1,mid) < InpBB_FlatLookback+1) return false;
   ArraySetAsSeries(mid,true);
   double change = MathAbs(mid[0] - mid[InpBB_FlatLookback]);
   return (Price2GP(change) <= InpBB_FlatThreshGP);
  }

double GetADX()
  {
   double a[];
   if(CopyBuffer(gADXHandle,0,0,1,a)<1) return 50; // fail-safe to trend
   return a[0];
  }

bool IsRangeContained()
  {
   double hi,lo;
   if(!RangeHL(InpRangeBars,hi,lo)) return false;
   double atr = ATRVal();
   if(atr<=0) return false;
   return ((hi-lo) <= atr * InpRangeATR_Mult);
  }

ENUM_REGIME DetectRawRegime()
  {
   if(!InpUseAutoRegime) return REGIME_TREND;

   double adx = GetADX();
   bool flat  = IsBBFlat();
   bool rng   = IsRangeContained();

   // Hysteresis
   if(gRegime == REGIME_SIDEWAYS)
     {
      // Stay sideways unless ADX rises strongly or BB starts sloping hard
      if(adx >= InpADX_TrendMin) return REGIME_TREND;
      if(!flat && !rng) return REGIME_TREND;
      return REGIME_SIDEWAYS;
     }
   else
     {
      // Enter sideways only if all three agree
      if(adx <= InpADX_SidewaysMax && flat && rng) return REGIME_SIDEWAYS;
      return REGIME_TREND;
     }
  }

void UpdateRegime()
  {
   ENUM_REGIME raw = DetectRawRegime();
   if(raw == gPendingRegime)
     {
      gRegimeCount++;
      if(gRegimeCount >= InpRegimeConfirmBars && raw != gRegime)
        {
         ENUM_REGIME old = gRegime;
         gRegime = raw;
         PrintFormat("REGIME SWITCH: %s -> %s", 
                     old==REGIME_TREND?"TREND":"SIDEWAYS",
                     gRegime==REGIME_TREND?"TREND":"SIDEWAYS");

         if(gRegime == REGIME_SIDEWAYS)
           {
            CancelAllBreakoutPendings();
            gGridActive = false; // force re-anchor next time
            gGridAnchor = 0;
           }
         else
           {
            // Leaving sideways → cancel pending grid orders
            CancelAllGridOrders();
            // Optionally flatten open grid positions immediately (safer on trend start)
            if(InpGrid_FlattenOnTrend)
               CloseAllGridPositions();
            gGridActive = false;
            gGridAnchor = 0;
           }
        }
     }
   else
     {
      gPendingRegime = raw;
      gRegimeCount = 1;
     }
  }

//+------------------------------------------------------------------+
// Breakout detection modules (unchanged logic)
//+------------------------------------------------------------------+
int DetectNova(double &level)
  {
   double hi,lo;
   if(!RangeHL(InpNova_Bars,hi,lo)) return 0;
   double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   double off=GP2Price(InpPendingOffsetGP);
   if(ask < hi) { level=hi+off; return 1; }
   if(bid > lo) { level=lo-off; return -1; }
   return 0;
  }

int DetectApex(double &level)
  {
   double hi,lo;
   if(!RangeHL(InpApex_Bars,hi,lo)) return 0;
   double atr=ATRVal();
   if(atr<=0) return 0;
   if((hi-lo) > atr*2.2) return 0;
   double off=GP2Price(InpPendingOffsetGP);
   double mid=(hi+lo)/2.0;
   double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   if(bid>=mid) { level=hi+off; return 1; }
   level=lo-off; return -1;
  }

int DetectZenith(double &level)
  {
   double f[],s[];
   if(CopyBuffer(gEmaF,0,0,3,f)<3 || CopyBuffer(gEmaS,0,0,3,s)<3) return 0;
   ArraySetAsSeries(f,true); ArraySetAsSeries(s,true);
   double hi,lo;
   if(!RangeHL(8,hi,lo)) return 0;
   double off=GP2Price(InpPendingOffsetGP);
   if(f[0]>s[0] && f[1]>s[1]) { level=hi+off; return 1; }
   if(f[0]<s[0] && f[1]<s[1]) { level=lo-off; return -1; }
   return 0;
  }

int DetectPulse(double &level)
  {
   double hi,lo;
   if(!RangeHL(InpPulse_Bars,hi,lo)) return 0;
   double off=GP2Price(InpPendingOffsetGP);
   double close=iClose(_Symbol,PERIOD_M5,1);
   double loc=(close-lo)/MathMax(hi-lo, _Point);
   if(loc>=0.65) { level=hi+off; return 1; }
   if(loc<=0.35) { level=lo-off; return -1; }
   return 0;
  }

int DetectEclipse(double &level)
  {
   double hi,lo;
   if(!RangeHL(InpEclipse_Bars,hi,lo)) return 0;
   double atr=ATRVal();
   if(atr>0 && (hi-lo) < atr*1.5) return 0;
   double off=GP2Price(InpPendingOffsetGP);
   double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   double mid=(hi+lo)/2.0;
   if(bid>=mid) { level=hi+off; return 1; }
   level=lo-off; return -1;
  }

int DetectModule(int modId, double &level)
  {
   switch(modId)
     {
      case MOD_NOVA:    return DetectNova(level);
      case MOD_APEX:    return DetectApex(level);
      case MOD_ZENITH:  return DetectZenith(level);
      case MOD_PULSE:   return DetectPulse(level);
      case MOD_ECLIPSE: return DetectEclipse(level);
     }
   return 0;
  }

int TP_GoldPips(int modId)
  {
   if(modId==MOD_APEX) return InpTP_Apex_GP;
   return InpTP_Other_GP;
  }

//+------------------------------------------------------------------+
void PlacePending(int modIdx, int dir, double level)
  {
   ModState m=gMod[modIdx];
   long magic=MagicOf(m.id);
   if(CountPosMagic(magic)>0) return;
   if(CountPendMagic(magic)>0) return;

   double pt=SymbolInfoDouble(_Symbol,SYMBOL_POINT);
   double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   if((ask-bid)/pt > InpMaxSpreadPts) return;

   long stops=SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL);
   double minDist=(stops+5)*pt;
   if(dir>0 && level < ask+minDist) level=ask+minDist;
   if(dir<0 && level > bid-minDist) level=bid-minDist;

   double slDist=GP2Price(InpSL_GoldPips);
   double tpDist=GP2Price(TP_GoldPips(m.id));
   double lot=CalcLot();
   int dg=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
   level=NormalizeDouble(level,dg);

   trade.SetExpertMagicNumber(magic);
   string cmt=StringFormat("%s-%s",InpComment,m.name);

   bool ok=false;
   if(dir>0)
     {
      double sl=NormalizeDouble(level-slDist,dg);
      double tp=NormalizeDouble(level+tpDist,dg);
      ok=trade.BuyStop(lot,level,_Symbol,sl,tp,ORDER_TIME_GTC,0,cmt);
     }
   else
     {
      double sl=NormalizeDouble(level+slDist,dg);
      double tp=NormalizeDouble(level-tpDist,dg);
      ok=trade.SellStop(lot,level,_Symbol,sl,tp,ORDER_TIME_GTC,0,cmt);
     }

   if(ok)
     {
      gMod[modIdx].pendingTicket=trade.ResultOrder();
      gMod[modIdx].pendingTime=TimeCurrent();
      PrintFormat("%s pending %s @ %.2f lot=%.2f",m.name,dir>0?"BUYSTOP":"SELLSTOP",level,lot);
     }
  }

void ExpirePendings()
  {
   if(InpPendingExpiryBars<=0) return;
   for(int i=0;i<5;i++)
     {
      if(!gMod[i].enabled) continue;
      long magic=MagicOf(gMod[i].id);
      if(CountPendMagic(magic)==0) { gMod[i].pendingTicket=0; continue; }
      if(gMod[i].pendingTime==0) continue;
      int bars=Bars(_Symbol,PERIOD_M5,gMod[i].pendingTime,TimeCurrent());
      if(bars>=InpPendingExpiryBars)
        {
         CancelPendingsOf(magic);
         gMod[i].pendingTicket=0;
        }
     }
  }

void ManageProfitLock()
  {
   double pt=SymbolInfoDouble(_Symbol,SYMBOL_POINT);
   int dg=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);

   for(int i=PositionsTotal()-1;i>=0;i--)
     {
      ulong ticket=PositionGetTicket(i);
      if(!ticket) continue;
      if(PositionGetString(POSITION_SYMBOL)!=_Symbol) continue;
      long magic=PositionGetInteger(POSITION_MAGIC);
      if(magic<InpBaseMagic || magic>InpBaseMagic+10) continue; // only breakout magics
      if(!PositionSelectByTicket(ticket)) continue;

      double open=PositionGetDouble(POSITION_PRICE_OPEN);
      double vol =PositionGetDouble(POSITION_VOLUME);
      double sl  =PositionGetDouble(POSITION_SL);
      double tp  =PositionGetDouble(POSITION_TP);
      double bid =SymbolInfoDouble(_Symbol,SYMBOL_BID);
      double ask =SymbolInfoDouble(_Symbol,SYMBOL_ASK);
      long type  =PositionGetInteger(POSITION_TYPE);
      double profit=PositionGetDouble(POSITION_PROFIT)+PositionGetDouble(POSITION_SWAP);

      int mi=-1;
      for(int k=0;k<5;k++) if(MagicOf(gMod[k].id)==magic) { mi=k; break; }
      if(mi<0) continue;

      if(InpUseProfitLock && !InpUseBreakEvenTrail)
        {
         double activate=InpLockActivateMoney*(vol/0.01);
         if(profit > gMod[mi].peakProfit) gMod[mi].peakProfit=profit;
         if(gMod[mi].peakProfit>=activate)
           {
            double lockLevel=gMod[mi].peakProfit*(InpLockPercent/100.0);
            if(profit <= lockLevel && gMod[mi].peakProfit>0)
              {
               trade.SetExpertMagicNumber(magic);
               trade.PositionClose(ticket);
               gMod[mi].peakProfit=0;
               continue;
              }
           }
        }
      else if(InpUseBreakEvenTrail)
        {
         double beStart=GP2Price(InpBE_StartGP);
         double beLock =GP2Price(InpBE_LockGP);
         double trStart=GP2Price(InpTrailStartGP);
         double trStep =GP2Price(InpTrailStepGP);
         if(type==POSITION_TYPE_BUY)
           {
            if((bid-open)>=beStart)
              {
               double nsl=NormalizeDouble(open+beLock,dg);
               if(nsl>sl) trade.PositionModify(ticket,nsl,tp);
              }
            if((bid-open)>=trStart)
              {
               double nsl=NormalizeDouble(bid-trStep,dg);
               if(nsl>sl+pt) trade.PositionModify(ticket,nsl,tp);
              }
           }
         else
           {
            if((open-ask)>=beStart)
              {
               double nsl=NormalizeDouble(open-beLock,dg);
               if(sl==0||nsl<sl) trade.PositionModify(ticket,nsl,tp);
              }
            if((open-ask)>=trStart)
              {
               double nsl=NormalizeDouble(ask+trStep,dg);
               if(sl==0||nsl<sl-pt) trade.PositionModify(ticket,nsl,tp);
              }
           }
        }
     }

   for(int k=0;k<5;k++)
     if(CountPosMagic(MagicOf(gMod[k].id))==0)
        gMod[k].peakProfit=0;
  }

//+------------------------------------------------------------------+
// SIDEWAYS GRID LOGIC (improved)
//+------------------------------------------------------------------+
double GetADR()
  {
   // Average Daily Range over InpGrid_ADR_Days (using D1 highs/lows)
   MqlRates r[];
   int need = InpGrid_ADR_Days + 1;
   if(CopyRates(_Symbol, PERIOD_D1, 1, need, r) < need) return 0;
   double sum = 0;
   for(int i=0; i<InpGrid_ADR_Days; i++)
      sum += (r[i].high - r[i].low);
   return sum / InpGrid_ADR_Days;
  }

double ComputeSpacing()
  {
   double base = 0;

   if(InpGrid_UseADR)
     {
      base = GetADR();
      if(base > 0)
         base = base / MathMax(InpGrid_N, 1);   // ADR / N
     }

   if(base <= 0)
     {
      double atr = ATRGridVal();
      if(atr <= 0) atr = ATRVal();
      if(atr > 0) base = atr / MathMax(InpGrid_N, 1);
     }

   double floor = GP2Price(InpGrid_MinSpacingGP);
   if(base < floor) base = floor;
   return base;
  }

bool NeedReanchor()
  {
   if(!gGridActive || gGridAnchor <= 0) return true;
   if(CountPosMagic(GridMagic()) > 0) return false; // never re-anchor with open positions
   if(!InpGrid_ReanchorOnFlat) return false;

   double mid = (SymbolInfoDouble(_Symbol,SYMBOL_BID) + SymbolInfoDouble(_Symbol,SYMBOL_ASK)) / 2.0;
   // only re-anchor if price has drifted more than 2.5 spacings (was 2.0)
   if(gGridSpacing > 0 && MathAbs(mid - gGridAnchor) > gGridSpacing * 2.5) return true;
   return false;
  }

void PlaceGrid()
  {
   if(!InpGridEnabled) return;
   if(gRegime != REGIME_SIDEWAYS) return;

   double pt  = SymbolInfoDouble(_Symbol,SYMBOL_POINT);
   double ask = SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol,SYMBOL_BID);
   if(pt>0 && (ask-bid)/pt > InpMaxSpreadPts) return;

   // --- Equity stop ---
   double eq = AccountInfoDouble(ACCOUNT_EQUITY);
   if(eq > gEquityPeak) gEquityPeak = eq;
   if(gEquityPeak > 0 && InpGrid_EquityStopPct > 0)
     {
      double dd = (gEquityPeak - eq) / gEquityPeak * 100.0;
      if(dd >= InpGrid_EquityStopPct)
        {
         PrintFormat("GRID EQUITY STOP hit: DD=%.2f%% — flattening grid", dd);
         CancelAllGridOrders();
         CloseAllGridPositions();
         gGridActive = false;
         gGridAnchor = 0;
         gEquityPeak = eq;
         return;
        }
     }

   int buyPos  = CountPosSide(GridMagic(), POSITION_TYPE_BUY);
   int sellPos = CountPosSide(GridMagic(), POSITION_TYPE_SELL);
   int totalPos = buyPos + sellPos;

   // Hard total position cap
   if(totalPos >= InpGrid_MaxOpenTotal)
     {
      CancelAllGridOrders(); // no new levels while maxed
      return;
     }

   if(buyPos >= InpGrid_L && sellPos >= InpGrid_L)
      return;

   // --- Measured range (support / resistance box) ---
   double rangeHi, rangeLo;
   if(!RangeHL(InpRangeBars, rangeHi, rangeLo)) return;
   double pad = GP2Price(InpGrid_RangePadGP);
   double boxTop = rangeHi - pad;
   double boxBot = rangeLo + pad;
   if(boxTop <= boxBot) return; // range too tight

   // Price must still be inside the box — if it breaks out, do not add levels
   double mid = (bid + ask) / 2.0;
   if(mid > boxTop || mid < boxBot)
     {
      // price left the range → cancel pending, keep open positions to TP/equity-stop
      CancelAllGridOrders();
      return;
     }

   // --- Re-anchor (only when flat) ---
   if(NeedReanchor())
     {
      CancelAllGridOrders();
      gGridSpacing = ComputeSpacing();
      // Anchor near middle of current box (more stable than raw mid-price)
      gGridAnchor  = NormalizeDouble((boxTop + boxBot) / 2.0, (int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS));
      gGridActive  = true;
      PrintFormat("GRID ANCHOR @ %.2f  spacing=%.2f (%.1f GP)  box=[%.2f .. %.2f]",
                  gGridAnchor, gGridSpacing, Price2GP(gGridSpacing), boxBot, boxTop);
     }

   if(gGridSpacing <= 0 || gGridAnchor <= 0) return;

   double lot = CalcGridLot(gGridSpacing);
   int dg = (int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
   long stops = SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL);
   double minDist = (stops + 5) * pt;

   trade.SetExpertMagicNumber(GridMagic());
   string cmt = StringFormat("%s-Grid", InpComment);

   // How many levels actually fit inside the box?
   int maxBuyLvls  = (int)MathFloor((gGridAnchor - boxBot) / gGridSpacing);
   int maxSellLvls = (int)MathFloor((boxTop - gGridAnchor) / gGridSpacing);
   if(maxBuyLvls  > InpGrid_L) maxBuyLvls  = InpGrid_L;
   if(maxSellLvls > InpGrid_L) maxSellLvls = InpGrid_L;
   if(maxBuyLvls  < 1) maxBuyLvls  = 1;
   if(maxSellLvls < 1) maxSellLvls = 1;

   // --- BuyLimits below anchor (only inside box) ---
   if(buyPos < maxBuyLvls && totalPos < InpGrid_MaxOpenTotal)
     {
      for(int lvl=1; lvl<=maxBuyLvls; lvl++)
        {
         if(totalPos + CountPendMagic(GridMagic()) >= InpGrid_MaxOpenTotal) break;

         double price = NormalizeDouble(gGridAnchor - lvl * gGridSpacing, dg);
         if(price < boxBot) continue;                 // outside range
         if(price >= bid - minDist) continue;         // too close

         bool exists = false;
         for(int i=OrdersTotal()-1; i>=0; i--)
           {
            ulong t=OrderGetTicket(i);
            if(!t) continue;
            if(OrderGetString(ORDER_SYMBOL)==_Symbol &&
               OrderGetInteger(ORDER_MAGIC)==GridMagic() &&
               OrderGetInteger(ORDER_TYPE)==ORDER_TYPE_BUY_LIMIT &&
               MathAbs(OrderGetDouble(ORDER_PRICE_OPEN)-price) < gGridSpacing*0.35)
              { exists=true; break; }
           }
         if(exists) continue;

         for(int i=PositionsTotal()-1; i>=0; i--)
           {
            ulong t=PositionGetTicket(i);
            if(!t) continue;
            if(PositionGetString(POSITION_SYMBOL)==_Symbol &&
               PositionGetInteger(POSITION_MAGIC)==GridMagic() &&
               PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY &&
               MathAbs(PositionGetDouble(POSITION_PRICE_OPEN)-price) < gGridSpacing*0.4)
              { exists=true; break; }
           }
         if(exists) continue;

         double tp = NormalizeDouble(price + gGridSpacing, dg);
         trade.BuyLimit(lot, price, _Symbol, 0, tp, ORDER_TIME_GTC, 0, cmt);
        }
     }

   // --- SellLimits above anchor (only inside box) ---
   if(sellPos < maxSellLvls && totalPos < InpGrid_MaxOpenTotal)
     {
      for(int lvl=1; lvl<=maxSellLvls; lvl++)
        {
         if(totalPos + CountPendMagic(GridMagic()) >= InpGrid_MaxOpenTotal) break;

         double price = NormalizeDouble(gGridAnchor + lvl * gGridSpacing, dg);
         if(price > boxTop) continue;                 // outside range
         if(price <= ask + minDist) continue;

         bool exists = false;
         for(int i=OrdersTotal()-1; i>=0; i--)
           {
            ulong t=OrderGetTicket(i);
            if(!t) continue;
            if(OrderGetString(ORDER_SYMBOL)==_Symbol &&
               OrderGetInteger(ORDER_MAGIC)==GridMagic() &&
               OrderGetInteger(ORDER_TYPE)==ORDER_TYPE_SELL_LIMIT &&
               MathAbs(OrderGetDouble(ORDER_PRICE_OPEN)-price) < gGridSpacing*0.35)
              { exists=true; break; }
           }
         if(exists) continue;

         for(int i=PositionsTotal()-1; i>=0; i--)
           {
            ulong t=PositionGetTicket(i);
            if(!t) continue;
            if(PositionGetString(POSITION_SYMBOL)==_Symbol &&
               PositionGetInteger(POSITION_MAGIC)==GridMagic() &&
               PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_SELL &&
               MathAbs(PositionGetDouble(POSITION_PRICE_OPEN)-price) < gGridSpacing*0.4)
              { exists=true; break; }
           }
         if(exists) continue;

         double tp = NormalizeDouble(price - gGridSpacing, dg);
         trade.SellLimit(lot, price, _Symbol, 0, tp, ORDER_TIME_GTC, 0, cmt);
        }
     }
  }

//+------------------------------------------------------------------+
void DrawPanel()
  {
   if(!InpShowPanel) return;
   if(MQLInfoInteger(MQL_TESTER) && !InpPanelInTester) return;

   double eq=AccountInfoDouble(ACCOUNT_EQUITY);
   double bal=AccountInfoDouble(ACCOUNT_BALANCE);
   double spr=(SymbolInfoDouble(_Symbol,SYMBOL_ASK)-SymbolInfoDouble(_Symbol,SYMBOL_BID))
              /SymbolInfoDouble(_Symbol,SYMBOL_POINT);

   string mode = (gRegime==REGIME_SIDEWAYS) ? "SIDEWAYS-GRID" : "BREAKOUT";
   string s="=== BreakoutForge Hybrid ===\n";
   s+=StringFormat("MODE: %s | ADX:%.1f\n", mode, GetADX());
   s+=StringFormat("Eq: %.2f  Bal: %.2f  Spr: %.0f\n",eq,bal,spr);
   if(InpUseBalanceLot) s+=StringFormat("Lot: %.2f (%s)  Peak: %.2f\n",TierLot(),gLotTier==1?"RAISED":"BASE",gTierPeak);
   string newsTag=""; datetime newsEvt=0;
   bool newsActive = GetActiveNewsEvent(newsTag, newsEvt);
   s+=StringFormat("News:%s Wknd:%s DayStop:%s\n",
                   newsActive ? ("TRADE-"+newsTag) : (NewsBlackout()?"BLK":"n"),
                   WeekendBlocked()?"Y":"n", gDayStopped?"Y":"n");

   if(gRegime==REGIME_SIDEWAYS)
     {
      s+=StringFormat("Grid Anchor: %.2f  Spc: %.2f (%.1fGP)\n",
                      gGridAnchor, gGridSpacing, Price2GP(gGridSpacing));
      s+=StringFormat("Grid Pos B/S: %d/%d  Pend: %d\n",
                      CountPosSide(GridMagic(),POSITION_TYPE_BUY),
                      CountPosSide(GridMagic(),POSITION_TYPE_SELL),
                      CountPendMagic(GridMagic()));
     }
   else
     {
      for(int i=0;i<5;i++)
        {
         long mg=MagicOf(gMod[i].id);
         s+=StringFormat("%s: %s pos=%d pend=%d\n",
                         gMod[i].name, gMod[i].enabled?"ON":"off",
                         CountPosMagic(mg), CountPendMagic(mg));
        }
     }
   Comment(s);
  }

//+------------------------------------------------------------------+
void OnTick()
  {
   // Always manage open breakout positions
   LotTierUpdate();
   ManageProfitLock();
   ExpirePendings();
   ResetDay();

   // Update equity peak (used by grid equity stop)
   double eq = AccountInfoDouble(ACCOUNT_EQUITY);
   if(eq > gEquityPeak) gEquityPeak = eq;

   if(DailyLossHit()) { DrawPanel(); return; }

   // Explicit news reaction mode takes priority during the configured event window.
   // Outside this window, the EA returns to its existing protection/strategy logic.
   if(TryNewsReactionTrade()) { DrawPanel(); return; }
   if(NewsBlackout()) 
     { 
      CancelAllBreakoutPendings(); 
      CancelAllGridOrders(); 
      DrawPanel(); 
      return; 
     }
   if(WeekendBlocked()) 
     { 
      CancelAllBreakoutPendings(); 
      CancelAllGridOrders(); 
      DrawPanel(); 
      return; 
     }
   if(!InSession()) { DrawPanel(); return; }

   double pt=SymbolInfoDouble(_Symbol,SYMBOL_POINT);
   double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   if(pt>0 && (ask-bid)/pt > InpMaxSpreadPts) { DrawPanel(); return; }

   // Regime update (on new M5 bar ideally, but cheap enough every tick)
   static datetime lastBar=0;
   datetime curBar = iTime(_Symbol,PERIOD_M5,0);
   if(curBar != lastBar)
     {
      lastBar = curBar;
      UpdateRegime();
     }

   // ---------- MODE SWITCH ----------
   if(gRegime == REGIME_SIDEWAYS && InpGridEnabled)
     {
      // Sideways mode: no breakout orders
      PlaceGrid();
     }
   else
     {
      // Trend / Breakout mode
      for(int i=0;i<5;i++)
        {
         if(!gMod[i].enabled) continue;
         long magic=MagicOf(gMod[i].id);
         if(CountPosMagic(magic)>0) continue;
         if(CountPendMagic(magic)>0) continue;

         double level=0;
         int dir=DetectModule(gMod[i].id, level);
         if(dir==0) continue;
         PlacePending(i, dir, level);
        }
     }

   DrawPanel();
  }
//+------------------------------------------------------------------+