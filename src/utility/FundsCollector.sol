//SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.13;

import "openzeppelin-contracts/token/ERC20/IERC20.sol";

abstract contract FundsCollector {

    mapping (address => uint256) public balances;
    address immutable public paymentToken;

    event FundsReceived(address indexed from, address indexed to, uint256 amount);
    event FundsWithdrawn(address indexed by, uint256 amount);
    event RefundAvailable(address indexed for_, uint256 amount);
    event AttemptToCollectNoFunds();

    error UnableToWithdrawEther();
    error InsufficientEtherSent(uint256 received, uint256 expected);
    error PaymentByTokensOnly(uint256 etherSent);
    error TokenNotSet();
    error TokenTransferFailed();

    constructor(address token) {
        paymentToken = token;
    }

    /// @notice implements the withdraw pattern
    function withdraw() external {
        uint256 wholeAmount = balances[msg.sender];
        //require(wholeAmount > 0, "nothing to withdraw");
        if (wholeAmount > 0) {
            balances[msg.sender] = 0;
            if (paymentToken == address(0)) {
                (bool success,) = payable(msg.sender).call{value: wholeAmount}("");
                if (!success) revert UnableToWithdrawEther();
            }
            else
                IERC20(paymentToken).transfer(msg.sender,wholeAmount);

            emit FundsWithdrawn(msg.sender, wholeAmount);
        }
    }

    /// @notice balance available to withdrawl pattern
    function getBalance() external view returns(uint) {
        return balances[msg.sender];
    }

    ///@dev called as a hook
    function _collectPayment(address from, address to, uint256 amount) internal {
        if (amount == 0) {
            emit AttemptToCollectNoFunds();
            return;
        }
        if (paymentToken == address(0)) {
            //require(price == msg.value,"expected ether was not sent");
            if (msg.value < amount)
                revert InsufficientEtherSent(msg.value, amount);
            if (to != address(0)) {
                balances[to] += amount;
                emit FundsReceived(from, to, amount);
            }
            if (msg.value > amount) {
                balances[from] += msg.value - amount;
                emit RefundAvailable(from, msg.value - amount);
            }
        }
        else {
            if (msg.value > 0) revert PaymentByTokensOnly(msg.value);
            if (paymentToken == address(0)) revert TokenNotSet();
            
            //tokens are held in the contract till withdraw time, so that there is a uniform interface for interaction
            bool result = IERC20(paymentToken).transferFrom(from, address(this), amount);
            if (!result) revert TokenTransferFailed();
            if (to != address(0))
                balances[to] += amount;
        }
    }
}