// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title ValoraVault
 * @dev A secure vault smart contract for depositing and withdrawing Ether
 * @notice This contract implements time-locked deposits with fee management
 */
contract ValoraVault {
    
    // State variables
    address payable public owner;
    uint256 public feePercent;
    uint256 public lockDuration;
    uint256 public totalDeposits;
    bool private locked; // Reentrancy guard
    
    // Mappings
    mapping(address => uint256) public balances;
    mapping(address => uint256) public depositTimestamps;
    mapping(address => uint256) public totalUserDeposits;
    
    // Events
    event Deposit(address indexed user, uint256 amount, uint256 fee, uint256 timestamp);
    event Withdrawal(address indexed user, uint256 amount, uint256 timestamp);
    event FeeUpdated(uint256 oldFee, uint256 newFee);
    event LockDurationUpdated(uint256 oldDuration, uint256 newDuration);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event EmergencyWithdrawal(address indexed owner, uint256 amount);
    
    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "ValoraVault: Caller is not the owner");
        _;
    }
    
    modifier noReentrant() {
        require(!locked, "ValoraVault: Reentrant call detected");
        locked = true;
        _;
        locked = false;
    }
    
    modifier validAmount() {
        require(msg.value > 0, "ValoraVault: Amount must be greater than zero");
        _;
    }
    
    /**
     * @dev Constructor sets the deployer as owner with default parameters
     */
    constructor() {
        owner = payable(msg.sender);
        feePercent = 2; // 2% default fee
        lockDuration = 7 days; // 7 days default lock period
        locked = false;
    }
    
    /**
     * @dev Allows users to deposit Ether into the vault
     * @notice A fee is deducted from the deposit and transferred to the owner
     */
    function deposit() external payable validAmount noReentrant {
        uint256 fee = (msg.value * feePercent) / 100;
        uint256 depositAmount = msg.value - fee;
        
        require(depositAmount > 0, "ValoraVault: Deposit amount too small");
        
        // Transfer fee to owner
        (bool feeSuccess, ) = owner.call{value: fee}("");
        require(feeSuccess, "ValoraVault: Fee transfer failed");
        
        // Update state (checks-effects-interactions pattern)
        balances[msg.sender] += depositAmount;
        depositTimestamps[msg.sender] = block.timestamp;
        totalUserDeposits[msg.sender] += depositAmount;
        totalDeposits += depositAmount;
        
        emit Deposit(msg.sender, depositAmount, fee, block.timestamp);
    }
    
    /**
     * @dev Allows users to withdraw their funds after lock duration
     */
    function withdraw() external noReentrant {
        uint256 balance = balances[msg.sender];
        require(balance > 0, "ValoraVault: No balance to withdraw");
        require(
            block.timestamp >= depositTimestamps[msg.sender] + lockDuration,
            "ValoraVault: Funds are still locked"
        );
        
        // Update state before transfer (checks-effects-interactions pattern)
        balances[msg.sender] = 0;
        totalDeposits -= balance;
        
        // Transfer funds
        (bool success, ) = payable(msg.sender).call{value: balance}("");
        require(success, "ValoraVault: Withdrawal transfer failed");
        
        emit Withdrawal(msg.sender, balance, block.timestamp);
    }
    
    /**
     * @dev Allows users to withdraw a specific amount after lock duration
     * @param amount The amount to withdraw
     */
    function withdrawPartial(uint256 amount) external noReentrant {
        require(amount > 0, "ValoraVault: Amount must be greater than zero");
        uint256 balance = balances[msg.sender];
        require(balance >= amount, "ValoraVault: Insufficient balance");
        require(
            block.timestamp >= depositTimestamps[msg.sender] + lockDuration,
            "ValoraVault: Funds are still locked"
        );
        
        // Update state before transfer
        balances[msg.sender] -= amount;
        totalDeposits -= amount;
        
        // Transfer funds
        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "ValoraVault: Partial withdrawal failed");
        
        emit Withdrawal(msg.sender, amount, block.timestamp);
    }
    
    /**
     * @dev Returns the user's current balance
     * @param user The address to check
     * @return The balance of the user
     */
    function checkBalance(address user) external view returns (uint256) {
        return balances[user];
    }
    
    /**
     * @dev Returns the time remaining until funds can be withdrawn
     * @param user The address to check
     * @return Time remaining in seconds, 0 if unlocked
     */
    function timeUntilUnlock(address user) external view returns (uint256) {
        uint256 unlockTime = depositTimestamps[user] + lockDuration;
        if (block.timestamp >= unlockTime) {
            return 0;
        }
        return unlockTime - block.timestamp;
    }
    
    /**
     * @dev Allows owner to update the fee percentage
     * @param newFeePercent The new fee percentage (must be <= 10%)
     */
    function updateFee(uint256 newFeePercent) external onlyOwner {
        require(newFeePercent <= 10, "ValoraVault: Fee cannot exceed 10%");
        uint256 oldFee = feePercent;
        feePercent = newFeePercent;
        emit FeeUpdated(oldFee, newFeePercent);
    }
    
    /**
     * @dev Allows owner to update the lock duration
     * @param newLockDuration The new lock duration in seconds
     */
    function updateLockDuration(uint256 newLockDuration) external onlyOwner {
        require(newLockDuration >= 1 days, "ValoraVault: Lock duration too short");
        require(newLockDuration <= 365 days, "ValoraVault: Lock duration too long");
        uint256 oldDuration = lockDuration;
        lockDuration = newLockDuration;
        emit LockDurationUpdated(oldDuration, newLockDuration);
    }
    
    /**
     * @dev Transfers ownership of the contract to a new owner
     * @param newOwner The address of the new owner
     */
    function transferOwnership(address payable newOwner) external onlyOwner {
        require(newOwner != address(0), "ValoraVault: New owner is zero address");
        address previousOwner = owner;
        owner = newOwner;
        emit OwnershipTransferred(previousOwner, newOwner);
    }
    
    /**
     * @dev Emergency withdrawal function for owner (use with caution)
     * @notice This function should only be used in emergency situations
     */
    function emergencyWithdraw() external onlyOwner noReentrant {
        uint256 contractBalance = address(this).balance;
        require(contractBalance > 0, "ValoraVault: No funds to withdraw");
        
        (bool success, ) = owner.call{value: contractBalance}("");
        require(success, "ValoraVault: Emergency withdrawal failed");
        
        emit EmergencyWithdrawal(owner, contractBalance);
    }
    
    /**
     * @dev Returns the total contract balance
     * @return The total Ether held by the contract
     */
    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }
    
    /**
     * @dev Returns user statistics
     * @param user The address to check
     * @return balance Current balance
     * @return totalDeposited Total amount ever deposited
     * @return unlockTime Timestamp when funds unlock
     */
    function getUserStats(address user) external view returns (
        uint256 balance,
        uint256 totalDeposited,
        uint256 unlockTime
    ) {
        balance = balances[user];
        totalDeposited = totalUserDeposits[user];
        unlockTime = depositTimestamps[user] + lockDuration;
    }
    
    /**
     * @dev Fallback function to receive Ether
     */
    receive() external payable {
        revert("ValoraVault: Use deposit() function to deposit funds");
    }
}
