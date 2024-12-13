1. [OFF CHAIN] Unambiguous Claims Creator: Unambiguous Claims from Breaking News that can be resolved
2. [ON CHAIN] Outcome Tokens Creator: Initialize the condition for a market and create outcome tokens based on the provided collateral using Gnosis CTF

✅ State Variables & Struct
Condition struct with all necessary fields
IConditionalTokens interface
Mappings for conditions
Oracle address
Collateral token
✅ Core Functions
createCondition
splitPosition
mergePosition
reportPayouts (oracle)
redeemPositions
✅ Admin Functions
setOracle
setCollateralToken
pause/unpause
✅ Getter Functions
getCondition
getConditionCollateral
getUserPosition
✅ Events
OutcomeTokenSplit
OutcomeTokenMerged
ConditionResolved
PayoutRedeemed

3. [ON CHAIN] Enable Trading Outcome Tokens: Allow participants with tokens to buy and sell outcome tokens using Seaport protocol
4. [OFF CHAIN] Order Book: An off chain order book to match orders - saves gas costs - custom implementation
5. [ON CHAIN] Dex Oracle: UMA's Optimistic Oracle to resolve markets after the specified period or event.
