# Installation and setup

## Requirements

- MetaTrader 5 desktop terminal
- MetaEditor (included with MT5)
- The EA's .mq5 source file
- A demo account for initial testing

## Install the Expert Advisor

1. In MT5, select **Tools → MetaQuotes Language Editor**, or press F4.
2. In MetaEditor, locate the terminal's data folder.
3. Open the MQL5/Experts/ folder.
4. Copy fakemoondog_VERYnewstoo.mq5 into that folder.
5. Open the file in MetaEditor and click **Compile**.
6. Return to MT5. In **Navigator → Expert Advisors**, right-click and choose **Refresh**.
7. Attach the EA to the intended chart and review every input before enabling automated trading.

## Before running

- Confirm the broker's exact Gold symbol, such as XAUUSD or a broker-specific suffix.
- Confirm the intended timeframe and that sufficient historical data is available.
- Review lot sizing, maximum exposure, stop loss, take profit, spread filters, and daily-loss controls in the source.
- Check the terminal's Experts and Journal tabs for errors.
- If the EA uses the MT5 economic calendar, confirm that calendar data is available and understand how the code handles unavailable data.

## Recommended workflow

1. Compile successfully.
2. Backtest on historical data.
3. Use realistic spread, commission, and slippage assumptions.
4. Forward-test on a demo account.
5. Independently review the risks and behavior before considering live use.

Successful compilation does not establish that a strategy is profitable or safe.