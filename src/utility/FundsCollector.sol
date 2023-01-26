//SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.13;

import "openzeppelin-contracts/token/ERC20/IERC20.sol";

abstract contract FundsCollector {

    mapping (address => uint256) public balances;
    address immutable public paymentToken;
    bool immutable enforceExactPayment;
    bool immutable allowPartialWithdrawls;

    event FundsReceived(address indexed from, address indexed to, uint256 amount);
    event FundsWithdrawn(address indexed by, uint256 amount, uint256 remainingBalance);
    event RefundAvailable(address indexed for_, uint256 amount);
    event AttemptToWithdrawZeroAmount();
    event AttemptToCollectZeroAmount();
    event AttemptToWithdrawFromZeroBalance();


    error UnableToWithdrawEther();
    error InsufficientEtherSent(uint256 received, uint256 expected);
    error PaymentByTokensOnly(uint256 etherSent);
    error ExactChangeNotReceived(uint256 received, uint256 expected);
    error TokenNotSet();
    error TokenTransferFailed();
    error CannotHaveAmountWithEntireBalanceOption();
    error CannotWithdrawMoreThanBalance(uint256 balance, uint256 withdrawAmount);

    constructor(address token, bool enforceExactPayment_, bool allowPartialWithdrawls_ ) {
        paymentToken = token;
        enforceExactPayment = enforceExactPayment_;
        allowPartialWithdrawls = allowPartialWithdrawls_;
    }

    function withdrawAll() external {
        withdraw(true,0);
    }

    function withdrawAmount(uint256 amount) external {
        withdraw(false, amount);
    }

    /// @notice implements the withdraw pattern
    function withdraw(bool entireBalance, uint256 amount) internal {
        if (entireBalance && (amount > 0)) revert CannotHaveAmountWithEntireBalanceOption();        
        uint256 currentBalance = balances[msg.sender];
        if (amount > currentBalance) revert CannotWithdrawMoreThanBalance(currentBalance, amount);
        if (!entireBalance && amount == 0) {
            emit AttemptToWithdrawZeroAmount();
            return;
        }

        if (currentBalance > 0) {
            balances[msg.sender] = currentBalance - amount;
            if (paymentToken == address(0)) {
                (bool success,) = payable(msg.sender).call{value: amount}("");
                if (!success) revert UnableToWithdrawEther();
            }
            else
                IERC20(paymentToken).transfer(msg.sender, amount);

            emit FundsWithdrawn(msg.sender, amount, currentBalance - amount);
        }
        else
            emit AttemptToWithdrawFromZeroBalance();
    }

    /// @notice balance available to withdrawl pattern
    function getBalance() external view returns(uint) {
        return balances[msg.sender];
    }

    ///@dev called as a hook
    function _collectPayment(address from, address to, uint256 amount) internal {
        if (amount == 0) {
            emit AttemptToCollectZeroAmount();
            return;
        }
        if (paymentToken == address(0)) {
            if (enforceExactPayment && amount != msg.value)
                revert ExactChangeNotReceived(msg.value, amount);
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