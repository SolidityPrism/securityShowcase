pragma solidity ^0.8.20;

import "./Token.sol";
import "./Vault.sol";

contract TokenPool {
    Token public token;
    Vault public vault;
    mapping(address => uint256) public liquidityProviders;
    uint256 public totalLiquidity;

    event LiquidityAdded(address indexed provider, uint256 amount);
    event LiquidityRemoved(address indexed provider, uint256 amount);

    constructor(address tokenAddress, address vaultAddress) {
        token = Token(tokenAddress);
        vault = Vault(vaultAddress);
    }

    function addLiquidity(uint256 amount) external {
        require(amount > 0, "Amount must be positive");
        require(token.transferFrom(msg.sender, address(this), amount), "Transfer failed");

        liquidityProviders[msg.sender] += amount;
        totalLiquidity += amount;

        emit LiquidityAdded(msg.sender, amount);
    }

    function removeLiquidity(uint256 amount) external {
        require(liquidityProviders[msg.sender] >= amount, "Insufficient liquidity");
        require(amount > 0, "Amount must be positive");

        liquidityProviders[msg.sender] -= amount;
        totalLiquidity -= amount;

        require(token.transfer(msg.sender, amount), "Transfer failed");

        emit LiquidityRemoved(msg.sender, amount);
    }

    function swapTokensForStable(uint256 tokenAmount) external returns (uint256) {
        require(tokenAmount > 0, "Amount must be positive");
        require(token.transferFrom(msg.sender, address(this), tokenAmount), "Transfer failed");

        uint256 stableAmount = vault.getPrice(tokenAmount);
        require(vault.withdrawStable(msg.sender, stableAmount), "Vault withdrawal failed");

        return stableAmount;
    }

    function getPoolBalance() external view returns (uint256) {
        return token.balanceOf(address(this));
    }

    function getProviderShare(address provider) external view returns (uint256) {
        if (totalLiquidity == 0) return 0;
        return (liquidityProviders[provider] * 100) / totalLiquidity;
    }
}
