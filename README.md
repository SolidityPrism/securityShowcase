# Vulnerable DeFi Ecosystem - CTF & Audit Practice

⚠️ **DISCLAIMER**: This repository contains **deliberately vulnerable smart contracts**. They are designed for educational purposes, security research, and audit practice. **DO NOT USE THIS CODE IN PRODUCTION.**

## 📖 Overview

This repository simulates a small DeFi ecosystem consisting of three interacting contracts:
1.  **`Token.sol`**: An ERC20 token with transfer fees and a blacklist mechanism.
2.  **`Vault.sol`**: A contract holding ETH deposits (Stable) and calculating prices.
3.  **`TokenPool.sol`**: A liquidity pool allowing users to add liquidity and swap Tokens for ETH (Stable).

The code contains a mix of **syntax errors**, **accounting mismatches**, and **complex business logic flaws** that range from obvious to subtle.

---

## 🏆 Vulnerability Classification & Difficulty

This table categorizes findings based on **Severity** (Impact) and **Detection Difficulty** (how hard it is for an automated tool or a human to spot it).

| Contract | Vulnerability | Severity | Detection Difficulty | Type |
| :--- | :--- | :--- | :--- | :--- |
| **Vault.sol** | **Infinite Money Glitch** | **CRITICAL** | 🟢 **Easy** | Logic / Missing Modifier |
| **TokenPool.sol** | **Fee-on-Transfer Insolvency** | **CRITICAL** | 🟡 **Medium** | Accounting Mismatch |
| **TokenPool.sol** | **Broken Swap Logic** | **HIGH** | 🔴 **Hard** | Business Logic |
| **Vault.sol** | **Arbitrary User Withdrawal** | **HIGH** | 🟢 **Easy** | Access Control |
| **Token.sol** | **Honeypot / 100% Fee** | **HIGH** | 🟡 **Medium** | Centralization Risk |
| **TokenPool.sol** | **Precision Loss** | **LOW** | 🟢 **Easy** | Math Error |

*   **🟢 Easy:** Often caught by automated tools (Slither, Mythril) or basic visual review.
*   **🟡 Medium:** Requires context awareness or understanding cross-contract interactions.
*   **🔴 Hard:** Pure semantic/logic errors. The code runs "correctly" but does the opposite of the intended economic behavior. Tools usually miss these.

---

## 🔍 Vulnerabilities Analysis

### 💀 CRITICAL SEVERITY

#### 1. Infinite Money Glitch (Fake Deposit)
*   **Contract:** `Vault.sol`
*   **Function:** `depositStable()`
*   **Difficulty:** 🟢 Easy
*   **Description:** The function updates the user's `stableBalances` mapping (`+= amount`) but the function is not marked as `payable`, nor does it transfer tokens from the user.
*   **Exploit:** An attacker can call `depositStable(1000000)` to mint unlimited internal balance, then drain the contract using `withdrawStable`.

#### 2. Insolvency via Fee-on-Transfer
*   **Contract:** `TokenPool.sol`
*   **Function:** `addLiquidity()`
*   **Difficulty:** 🟡 Medium
*   **Description:** The `Token.sol` contract charges a fee on transfers. When `addLiquidity` calls `transferFrom`, the Pool receives `amount - fee`. However, the Pool updates `liquidityProviders` with the full `amount`.
*   **Impact:** The Pool tracks more debt than it holds in assets. The last liquidity providers to withdraw will find the contract empty (Insolvency).

---

### 🔴 HIGH SEVERITY

#### 3. Broken Swap Logic (The "User Pays to Withdraw Own Funds")
*   **Contract:** `TokenPool.sol`
*   **Function:** `swapTokensForStable()`
*   **Difficulty:** 🔴 **Hard**
*   **Description:**
    1. The user sends Tokens to the Pool.
    2. The Pool calculates the ETH value.
    3. The Pool calls `vault.withdrawStable(msg.sender, stableAmount)`.
    *The flaw:* The Vault's withdrawal function deducts funds from `msg.sender`'s (the user's) balance in the Vault.
*   **Impact:** The user pays tokens to the Pool, but receives **their own** previously deposited ETH from the Vault. If they haven't deposited ETH in the Vault, the transaction reverts. The Pool keeps the tokens for free.

#### 4. Arbitrary Withdrawal (Griefing / Theft)
*   **Contract:** `Vault.sol`
*   **Function:** `withdrawStable()`
*   **Difficulty:** 🟢 Easy
*   **Description:** The function accepts an `address user` parameter and decrements `stableBalances[user]`, but does not verify if `msg.sender == user`.
*   **Exploit:** An attacker can call this function passing a victim's address.
    *   *Scenario A:* Attacker forces the victim to withdraw their ETH (Griefing/Tax implications).
    *   *Scenario B:* If the `user.call{value...}` sends funds to a location the attacker controls (unlikely here as it sends to `user`), or simply burns the victim's position in the vault.

#### 5. Centralization / Honeypot Risk
*   **Contract:** `Token.sol`
*   **Function:** `setTransferFee()`
*   **Difficulty:** 🟡 Medium
*   **Description:** The owner can set the `transferFee` up to `10000` (100%).
*   **Impact:** The owner can turn the token into a Honeypot by setting fees to 100%, effectively confiscating all tokens upon transfer and preventing users from selling.

---

### 🔵 LOW / INFORMATIONAL

#### 6. Precision Loss (Rounding to Zero)
*   **Contract:** `TokenPool.sol`
*   **Function:** `getProviderShare()`
*   **Difficulty:** 🟢 Easy
*   **Description:** The formula `(liquidityProviders[provider] * 100) / totalLiquidity` uses a multiplier of only `100`.
*   **Impact:** If a user owns less than 1% of the pool, the integer division results in `0`. This breaks UI displays or other contracts relying on this view.

---

## 🛠 Setup & Testing

To analyze these files with your own tools:

1. **Clone the repo**
2. **Install Dependencies**
   ```bash
   npm install
   ```
3. **Compile**
   ```bash
   npx hardhat compile
   ```
