# Strategy overview

FakeMoonDog is an experimental MetaTrader 5 Expert Advisor focused primarily on Gold (XAUUSD). Its exact entry and exit behavior is defined by the source code for each version.

## Market context

Previous project notes recommend checking the H1 chart before enabling the EA:

- **Directional trend / clear swing:** potentially more suitable for investigation.
- **Choppy / sideways market:** potentially higher risk for trend-oriented logic, where repeated false signals can contribute to drawdown.

This is a qualitative filter, not a reliable prediction. Market regimes can change quickly.

## News-related behavior

Some versions have experimented with news-related trading or protection using MT5 economic-calendar data. Do not assume every version behaves the same way. Inspect the active build's inputs and implementation. Calendar availability, broker time, event classification, spreads, and execution delays can affect results.

## Evaluating changes

1. State the hypothesis before testing.
2. Change one major factor at a time where practical.
3. Use consistent symbol, timeframe, test interval, deposit, and cost assumptions.
4. Include both trending and sideways periods.
5. Compare drawdown and trade count alongside net profit.
6. Record the tested source version and settings.

This document does not claim a specific win rate or expected return. Those figures must come from reproducible tests and should not be treated as forecasts.