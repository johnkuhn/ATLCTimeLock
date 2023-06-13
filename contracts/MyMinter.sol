// SPDX-License-Identifier: KuhnSoft LLC
pragma solidity >=0.8.0;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';

/**
   * @title MyMinter
   * @dev MyMinter will mint brand new tokens and can send them to a wallet or a contract address.
   * @custom:dev-run-script contracts/MyMinter.sol
   */
contract MyMinter is ERC20 {

    address public owner;

    /*
        The constructor will accept up to 10 initial wallets for our founders. 
        The maximum number of wallets that can be added to this contract is 10.
    */
    constructor() ERC20("TestToken4", "TES4") {

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