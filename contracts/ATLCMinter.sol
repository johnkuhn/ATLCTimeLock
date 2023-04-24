// SPDX-License-Identifier: ATLC
pragma solidity >=0.8.0;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';

/**
   * @title ERC20TokenLockAndVoteOut
   * @dev ATLC TokenLock Contract w/ Vote Out Wallet Capability.
   * @custom:dev-run-script contracts/TokenLockAndVoteOut.sol
   */
contract ATLCMinter is ERC20 {

    address public owner;

    /*
        The constructor will accept up to 10 initial wallets for our founders. 
        The maximum number of wallets that can be added to this contract is 10.
    */
    constructor() ERC20("TestIt1", "TST1") {

        //contract owner is set
        owner = msg.sender;

    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only the contract owner can call this function");
        _;
    }

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }
}
    