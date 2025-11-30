pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Token is ERC20, Ownable {
    mapping(address => bool) public blacklist;
    uint256 public transferFee = 100;
    address public feeRecipient;

    event Blacklisted(address indexed account);

    constructor(uint256 initialSupply) ERC20("TestToken", "TST") Ownable(msg.sender) {
        _mint(msg.sender, initialSupply);
        feeRecipient = msg.sender;
    }

    function addToBlacklist(address account) external onlyOwner {
        blacklist[account] = true;
        emit Blacklisted(account);
    }

    function removeFromBlacklist(address account) external onlyOwner {
        blacklist[account] = false;
    }

    function _update(address from, address to, uint256 amount) internal override {
        require(!blacklist[from] && !blacklist[to], "Blacklisted");

        uint256 fee = (amount * transferFee) / 10000;
        uint256 transferAmount = amount - fee;

        if (fee > 0) {
            super._update(from, feeRecipient, fee);
        }

        super._update(from, to, transferAmount);
    }

    function setFeeRecipient(address newRecipient) external onlyOwner {
        require(newRecipient != address(0), "Invalid recipient");
        feeRecipient = newRecipient;
    }

    function setTransferFee(uint256 newFee) external onlyOwner {
        require(newFee <= 10000, "Fee too high");
        transferFee = newFee;
    }

    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }
}
