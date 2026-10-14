# FakeMoonDog — MetaTrader 5 Expert Advisor

An ongoing MQL5 algorithmic-trading project focused primarily on **XAUUSD (Gold)**. This repository documents the EA, its setup, and its testing process.

> **Risk notice:** This is an experimental trading system, not financial advice. Automated trading can lose money rapidly. Backtests do not predict future results. Test on a demo account before considering live use.

## Project goals

- Automate trade execution using the rules implemented in the EA.
- Study trend-following opportunities across different market regimes.
- Evaluate volatility, choppy conditions, and news-related behavior.
- Improve the research process through repeatable backtests and documented changes.

## Current status

This project is under active development. Results depend on the source-code version, broker, symbol settings, spread, execution conditions, and test period.

Previous project notes recommend checking the H1 chart before enabling the EA. Strong trends or clear directional swings may be more suitable than choppy, sideways conditions. This is a heuristic, not a guarantee of performance.

## Repository structure

- **Experts/** — current MQL5 Expert Advisor source
- **docs/** — installation, strategy, and backtesting documentation
- **backtests/** — Strategy Tester reports and exported results
- **images/** — screenshots, equity curves, and chart examples
- **versions/** — version history and archived builds
- **README.md** — project overview and quick start

The source file should be placed at **Experts/fakemoondog_VERYnewstoo.mq5**. If it is not visible in the folder, upload the current source file there.

## Project scope

The intended scope includes automated trade execution, a focus on Gold markets, strategy experimentation, and testing across different market conditions. Some versions have explored news-related logic. Always inspect the exact source code and input settings to confirm which features are present and enabled in a particular build.

## Quick start

1. Review the EA source code and input parameters.
2. Open MetaTrader 5 and launch MetaEditor through **Tools → MetaQuotes Language Editor**.
3. Copy the .mq5 file into the terminal's MQL5/Experts/ directory.
4. Compile it in MetaEditor and resolve any compiler errors.
5. In MT5, refresh **Navigator → Expert Advisors** and attach the EA to a chart.
6. Confirm the symbol, timeframe, lot sizing, stop-loss/take-profit settings, and risk controls.
7. Backtest with realistic assumptions, then demo-forward-test before considering live use.

See [Installation](docs/INSTALLATION.md) for details.

## Testing and reporting

Do not evaluate a strategy from net profit alone. Record:

- Test dates, symbol, broker, and timeframe
- Starting deposit, leverage, modelling method, and cost assumptions
- Net profit, maximum drawdown, profit factor, win rate, and trade count
- Long-versus-short performance
- Results during trending, sideways, and high-volatility periods

Use the [backtesting checklist](docs/BACKTESTING.md) to keep comparisons consistent. Put screenshots in images/ and reports in backtests/.

## Documentation

- [Installation guide](docs/INSTALLATION.md)
- [Strategy overview](docs/STRATEGY.md)
- [Backtesting checklist](docs/BACKTESTING.md)
- [Backtest reports](backtests/)
- [Screenshots](images/)
- [Version notes](versions/)

## Development workflow

For each meaningful change, record what changed, why it changed, and how it performed in a comparable backtest. Keep experimental builds separate from the recommended build, and avoid calling a version profitable or production-ready without supporting test evidence.

## Disclaimer

This repository is provided for educational, research, and software-development purposes only. It is not investment advice or a recommendation to buy or sell any instrument. Trading leveraged products involves substantial risk, including loss of capital. No guarantee is made about accuracy, profitability, or future results.