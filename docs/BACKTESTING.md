# Backtesting checklist

Use this checklist for every EA version so results can be compared fairly.

## Test configuration

- [ ] EA filename, version, and source commit recorded
- [ ] Symbol and broker recorded
- [ ] Timeframe recorded
- [ ] Test start and end dates recorded
- [ ] Initial deposit, account currency, and leverage recorded
- [ ] Modelling method and historical-data source recorded
- [ ] Spread, commission, swap, and slippage assumptions reviewed
- [ ] EA input settings saved with the report

## Metrics to record

| Metric | Why it matters |
|---|---|
| Net profit | Historical result; not sufficient by itself |
| Maximum drawdown | Measures peak-to-trough loss |
| Profit factor | Gross profit divided by gross loss |
| Win rate | Percentage of closed trades that were profitable |
| Number of trades | Helps assess sample size |
| Average win / average loss | Shows the relationship between winners and losers |
| Long vs. short results | Reveals directional differences |
| Monthly results | Helps identify periods where performance degrades |

## Regime checks

- [ ] Strong trending periods included
- [ ] Sideways / choppy periods included
- [ ] High-volatility news periods reviewed separately
- [ ] Results not dependent on one unusually profitable period
- [ ] Out-of-sample period or forward test included

## Reporting template

Record the EA version, source commit, symbol/broker, timeframe, test period, deposit/leverage, modelling method, costs, net profit, maximum drawdown, profit factor, win rate, total trades, long/short results, and notes on trending and sideways periods.

## Interpretation

Backtests can be affected by data quality, overfitting, and execution assumptions. Prefer repeatable results across multiple market conditions over optimizing for one period. Historical performance is not a guarantee of future results.