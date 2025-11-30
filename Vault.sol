pragma solidity ^0.8.20;

import "./TokenPool.sol";

contract Vault {
    TokenPool public pool;
    mapping(address => uint256) public stableBalances;
    address public admin;
    uint256 constant PRICE_MULTIPLIER = 1000;

    event StableWithdrawn(address indexed user, uint256 amount);
    event StableDeposited(address indexed user, uint256 amount);

    constructor(address poolAddress) {
        pool = TokenPool(poolAddress);
        admin = msg.sender;
    }

    function getPrice(uint256 tokenAmount) external pure returns (uint256) {
        return tokenAmount * PRICE_MULTIPLIER;
    }

    function depositStable(uint256 amount) external {
        stableBalances[msg.sender] += amount;
        emit StableDeposited(msg.sender, amount);
    }

    function withdrawStable(address user, uint256 amount) external returns (bool) {
        require(stableBalances[user] >= amount, "Insufficient stable balance");

        stableBalances[user] -= amount;
        (bool success, ) = user.call{value: amount}("");

        require(success, "Withdrawal failed");
        emit StableWithdrawn(user, amount);

        return true;
    }

    function getVaultBalance() external view returns (uint256) {
        return address(this).balance;
    }

    receive() external payable {}
}
