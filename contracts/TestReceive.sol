// SPDX-License-Identifier: ATLC
pragma solidity >=0.8.0;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
//import '@openzeppelin/contracts/token/ERC20/ERC20.sol';

/**
   * @title TestReceive
   * @dev Test receiving an outside token.
   * @custom:dev-run-script contracts/TestReceive.sol
   */
contract TestReceive {

    address public owner;
    address public token;
    uint256 public counter;

    uint256 public receivedCount = 0;
    uint256 public receivedCountFallback = 0;

    //this is the address where the ATLC main token contract is contained... NOT where my custom ATLCTimeLocakAndVoteOut.sol contract is deployed.
    //address public tokenAddressOfContractToReceiveFrom = 0x82E806EC4C7E7e134AD88e28f328Bde2e31861F1; // 0x82E806EC4C7E7e134AD88e28f328Bde2e31861F1; 

    //JGK 4/23/23 - instead of hardcoding the address, pass it into the constructor.
    //address public tokenContractAddress = 0xe944E0f7867C7D3c32b24D52d9C6588854aB465E; 

    event Received(address indexed from, uint256 amount);
    event FallbackReceived(address indexed from, uint256 amount);

    /*
        pass in the token contract address of the main address where our ATLC token contract is deployed. 
    */
    constructor(address _token) {
        token = _token;

          //contract owner is set
        owner = msg.sender;

    }

/*
    receive() external payable{
        receivedCount = msg.value;       

        // Get the ERC20 token contract
        IERC20 token = IERC20(tokenContractAddress);


        // Transfer the tokens from the sender to the contract
        bool success = token.transferFrom(msg.sender, address(this), msg.value);

        // Check if the transfer was successful
        require(success, "Token transfer failed");
        
        //log
        emit Received(msg.sender, msg.value);
    } 

    fallback() external payable {
        
        receivedCountFallback = msg.value; 
        emit FallbackReceived(msg.sender, msg.value);
    }

    function getReceivedCount() public view returns(uint256){
        return receivedCount;
    }

    function getReceivedCountFallback() public view returns(uint256){
        return receivedCountFallback;
    }
    */

    //JGK 4/23/23 - THIS DOESN'T END UP GETTING CALLED WHEN TRANSFERRING TOKENS FROM TESTACCOUNT3 TO THE ADDRESS OF THIS DEPLOYED SMART CONTRACT.
    //HOWEVER, OUT IN THE LEDGE FOR THE BUTW CONTRACT, IT MUST KNOW THAT THIS CONTRACT OWNS XYZ AMOUNT. BECAUSE THE getContractBalance()
    //function further below does in fact pull back the balance owned by this contract.
    function deposit(uint _amount) public payable {
        // Set the minimum amount to 1 token (in this case I'm using LINK token)
        uint _minAmount = 1*(10**18);
        // Here we validate if sended USDT for example is higher than 50, and if so we increment the counter
        require(_amount >= _minAmount, "Amount less than minimum amount");
        // I call the function of IERC20 contract to transfer the token from the user (that he's interacting with the contract) to
        // the smart contract  
        IERC20(token).transferFrom(msg.sender, address(this), _amount);
        counter = counter + 1;
    }

    // This function allow you to see how many tokens have the smart contract 
    function getContractBalance() public view returns(uint){
        return IERC20(token).balanceOf(address(this)); //NOTE: THIS IS VERY IMPORT BECAUSE IT'S GOING OUT TO THE LEDGE ESSENTIALLY OF THE ATLC TOKEN CONTRACT AND GETTING THE BALANCE OF THE ADDRESS OF THIS TESTRECEIVE SMART CONTRACT.
    }

    //TODO: create a copy of the ATLCTimeLockAndVoteOut.sol file in case this doesn't work out.  But, in the new version
    //do NOT inherit from ERC20, however, continue to import that library into it.
    //May need to do some modifications to the releaseTokens function so that we can still transfer the founder tokens out.



/*
    function transferFrom(address someTokenAddress, address sender, uint256 amount) public virtual override returns (bool) {
        //I will call this myself using remix.
        //Note: sender coming in is Test Account 3 address or whoever currently possesses the tokens we want transferred in.


        //bool retVal = super.transferFrom(sender, recipient, amount);

        // Get the ERC20 token contract address for the SOBE token when deployed
        IERC20 token = IERC20(someTokenAddress);

        token.approve(sender, amount);
        super.approve(sender, amount);

        // Transfer the tokens from the sender to the contract
        bool success = token.transferFrom(sender, address(this), amount);

        return success;
    }
*/
}
    