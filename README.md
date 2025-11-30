# SecurityShowcase - Corrected Analysis

⚠️ **DISCLAIMER**: This repository contains **deliberately vulnerable code**. These contracts are unsafe and should **NEVER** be used in production. This updated README reflects a strict manual audit and corrects hallucinations found in previous documentation.

## Overview

This ecosystem simulates a DeFi protocol with a Token, a Liquidity Pool, and an ETH Vault.
The contracts contain critical logic errors, accounting mismatches, and centralization risks commonly found in insecure DeFi projects.

## Vulnerabilities Analysis

### 💀 CRITICAL SEVERITY

#### 1. Infinite Money Glitch (Unverified Deposit)
*   **Contract:** `Vault.sol`
*   **Function:** `depositStable()`
*   **Description:** The function updates the user's internal balance (`stableBalances`) but does not verify if any Ether was actually sent. It lacks the `payable` modifier and a check on `msg.value`.
*   **Exploit:** An attacker can call `depositStable(1000 ether)` without sending funds, then call `withdrawStable` to drain all legitimate ETH stored in the contract.

#### 2. Ether Blackhole (Locked Funds)
*   **Contract:** `Vault.sol`
*   **Function:** `receive()`
*   **Description:** The contract accepts Ether via `receive()` but does not update any state variable (like `stableBalances`) or emit an event.
*   **Impact:** Any user sending ETH directly to the contract will lose their funds. They cannot withdraw them because their internal balance is never credited.

#### 3. Broken Swap Logic (DoS)
*   **Contract:** `Vault.sol` & `TokenPool.sol`
*   **Function:** `withdrawStable()` called by `pool.swapTokensForStable()`
*   **Description:** When the Pool attempts to swap tokens for stable (ETH), it calls `vault.withdrawStable(msg.sender, ...)`. However, the Vault checks `stableBalances[msg.sender]`. The Pool has no way to increase the user's balance in the Vault before this call.
*   **Impact:** Legitimate swaps will always revert.

---

### 🔴 HIGH SEVERITY

#### 4. Fee-on-Transfer Accounting Error (Insolvency)
*   **Contract:** `TokenPool.sol`
*   **Function:** `addLiquidity()`
*   **Description:** The `Token.sol` contract charges a fee on transfers. When users add liquidity, the Pool receives `amount - fee`, but credits the user for the full `amount` in `liquidityProviders`.
*   **Impact:** The `totalLiquidity` variable tracks more tokens than the contract actually holds. If all providers try to withdraw, the contract will run out of tokens before paying the last user (Insolvency / Denial of Service).

---

### 🟠 MEDIUM SEVERITY

#### 5. Honeypot Risk (Unlimited Fees)
*   **Contract:** `Token.sol`
*   **Function:** `setTransferFee()`
*   **Description:** The owner can set `transferFee` up to `10000` (100%).
*   **Impact:** A malicious owner can prevent users from selling or transferring tokens by taking 100% of the transaction value, effectively rug-pulling the holders.

#### 6. Centralization Risk (Arbitrary Blacklist)
*   **Contract:** `Token.sol`
*   **Function:** `addToBlacklist()`
*   **Description:** The owner can block any address from transferring tokens without any timelock or governance process.

---

### 🔵 LOW / INFORMATIONAL

#### 7. Precision Loss
*   **Contract:** `TokenPool.sol`
*   **Function:** `getProviderShare()`
*   **Description:** The calculation `(liquidityProviders[provider] * 100) / totalLiquidity` performs integer division.
*   **Impact:** Users with small shares (e.g., less than 1% of the pool) will see a result of `0`, even though they own funds. This is a display bug, not a fund loss.

---

## 🚫 False Positives (Common Audit Errors)

*The following vulnerabilities might be flagged by basic tools or inexperienced auditors but are **NOT** present in these contracts:*

#### ❌ Classic Reentrancy in `Vault.sol`
*   **Why it's not a bug:** The `withdrawStable` function follows the **Checks-Effects-Interactions** pattern. It decrements `stableBalances[user]` **before** making the external low-level call (`user.call`). Even if an attacker re-enters, their balance is already reduced, preventing double spending.

#### ❌ Sandwich Attack / Slippage in `TokenPool.sol`
*   **Why it's not a bug:** The pool uses a **Fixed Price Oracle** inside `Vault.sol` (`amount * 1000`). Since the price does not depend on the pool's reserves (unlike Uniswap), "slippage" does not exist mathematically here. Front-running a transaction yields no profit.

---

## Summary Table

| Contract | Vulnerability | Category | Severity |
|----------|---|---|---|
| **Vault.sol** | **Missing msg.value Check** | Logic Error | **CRITICAL** |
| **Vault.sol** | **Locked Ether (Blackhole)** | Logic Error | **CRITICAL** |
| **TokenPool.sol** | **Fee-on-Transfer Mismatch** | Accounting | **HIGH** |
| **Token.sol** | **100% Fee Setting** | Centralization | **MEDIUM** |
| **Token.sol** | **Blacklist Abuse** | Centralization | **MEDIUM** |
| **TokenPool.sol** | **Precision Loss** | Math | **LOW** |

---

## Setup & Compilation

```bash
npm install
npx hardhat compile
```

Requires:
- Solidity ^0.8.20
- @openzeppelin/contracts
