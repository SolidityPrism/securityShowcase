# SecurityShowcase - Solidity Audit Test Suite

⚠️ **DISCLAIMER**: This repository contains **deliberately vulnerable code for testing and educational purposes only**. These contracts are intentionally insecure and should **NEVER** be used in production or deployed to mainnet. They are designed to stress-test audit tools and demonstrate vulnerability patterns.

## Overview

This repository contains a deliberately vulnerable ERC20 token system designed to stress-test smart contract auditing tools. It simulates a realistic multi-file token ecosystem with intentional vulnerabilities of varying difficulty levels.

The system consists of three interconnected contracts:
- **Token.sol**: ERC20 token with fee mechanism and blacklist
- **TokenPool.sol**: Liquidity pool for token swaps
- **Vault.sol**: Stable coin vault with ETH withdrawal logic

## Intentional Vulnerabilities

### Token.sol

#### Vulnerability 1: Integer Overflow in Fee Calculation (EASY)
**Location**: `_update()` function, line 29
**Issue**: 
```
uint256 fee = (amount * transferFee) / 10000;
```
In Solidity versions < 0.8, this would overflow. While 0.8.20 has built-in overflow protection, auditors should flag this as a potential precision loss when `amount * transferFee` exceeds `type(uint256).max` during operations at scale.

**Expected Detection**: Basic overflow/precision analysis
**Actual Risk**: Low in 0.8.20, but pattern indicates unsafe arithmetic thinking

---

#### Vulnerability 2: Unsafe State Update Before External Call (MODERATE)
**Location**: `_update()` function, lines 28-34
**Issue**: 
The function calls `super._update()` twice without proper checks. If a malicious `feeRecipient` is set to a contract with a callback, the second `_update()` call could be exploited via reentrancy. While the check is explicit here, the pattern mirrors classic reentrancy vulnerabilities.

**Expected Detection**: Reentrancy pattern recognition
**Actual Risk**: Moderate - depends on fee recipient type

---

### TokenPool.sol

#### Vulnerability 3: Precision Loss in Share Calculation (EASY)
**Location**: `getProviderShare()` function, line 51
**Issue**:
```
return (liquidityProviders[provider] * 100) / totalLiquidity;
```
Integer division causes precision loss. If a provider has 1 token and totalLiquidity is 301, they get 0% share. Rounding errors accumulate.

**Expected Detection**: Arithmetic precision analysis
**Actual Risk**: Easy to spot, impacts fairness

---

#### Vulnerability 4: Missing Slippage Protection (DIFFICULT)
**Location**: `swapTokensForStable()` function, lines 53-63
**Issue**:
The price calculation is deterministic (`tokenAmount * 1000`), but in production swaps, users are vulnerable to price manipulation via sandwich attacks. The function accepts tokens, calls vault without checking slippage, and sends stables back without verifying the rate hasn't changed mid-transaction.

**Expected Detection**: Access control / transaction ordering analysis
**Actual Risk**: Difficult - requires understanding MEV and state assumptions

---

### Vault.sol

#### Vulnerability 5: Classic Reentrancy via Low-Level Call (VERY DIFFICULT)
**Location**: `withdrawStable()` function, lines 45-53
**Issue**:
```solidity
(bool success, ) = user.call{value: amount}("");
require(success, "Withdrawal failed");
```

This is a textbook reentrancy vector. The balance is updated BEFORE the call, but:
1. A malicious contract can re-enter `withdrawStable()` in its receive() fallback
2. The state check (`stableBalances[user] >= amount`) passes on the first call
3. The attacker drains the vault before the check fails

**Pattern Similarity**: Matches the classic Reentrancy-eth hack (similar to early Weth exploits)

**Expected Detection**: Advanced reentrancy detection with call flow analysis
**Actual Risk**: CRITICAL - standard reentrancy but combined with ETH native calls

---

#### Vulnerability 6: Semantic Type Mismatch / Logic Error (VERY DIFFICULT)
**Location**: `withdrawStable()` function & `depositStable()` function
**Issue**:
The contract mixes two concepts:
- `stableBalances` tracks a token-like balance (mapped to addresses)
- `withdrawStable()` sends **ETH native value** via `.call{value: amount}("")`

This is a semantic vulnerability:
- The balance is updated as if tokens, but ETH is sent
- If the contract receives 1 ETH but someone deposits a "1" token balance claim, the accounting is broken
- No invariant checks ensure `stableBalances.sum() <= address(this).balance`

This mirrors real exploits like the **Curve Finance vulnerability** where accounting mismatches between internal state and actual funds allowed draining.

**Expected Detection**: Requires semantic analysis of token vs. native ETH handling
**Actual Risk**: CRITICAL - funds can be drained

---

## Summary Table

| Contract | Vulnerability | Type | Difficulty | Risk Level |
|----------|---|---|---|---|
| Token.sol | Integer Overflow in Fee | Arithmetic | Easy | Low |
| Token.sol | Unsafe State Update Pattern | Reentrancy | Moderate | Moderate |
| TokenPool.sol | Precision Loss in Share | Arithmetic | Easy | Low |
| TokenPool.sol | Missing Slippage Protection | MEV/Ordering | Difficult | High |
| Vault.sol | Classic Reentrancy (Low-Level Call) | Reentrancy | Very Difficult | Critical |
| Vault.sol | Type Mismatch (Token vs ETH) | Semantic Logic | Very Difficult | Critical |

## Expected Tool Coverage

- **Easy vulnerabilities (2)**: Standard tools should catch both
- **Moderate vulnerabilities (1)**: Requires reentrancy pattern detection
- **Difficult vulnerabilities (1)**: Requires MEV/ordering analysis or flow tracing
- **Very Difficult vulnerabilities (2)**: Requires deep semantic analysis and state invariant checking

---

## Setup & Compilation

```bash
npm install
npx hardhat compile
```

Requires:
- Solidity ^0.8.20
- @openzeppelin/contracts ^4.9.0 or ^5.0.0

---

## Files

- `Token.sol` - ERC20 with fee mechanism
- `TokenPool.sol` - Liquidity pool interactions
- `Vault.sol` - ETH vault with withdrawal logic
