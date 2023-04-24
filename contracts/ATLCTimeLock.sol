// SPDX-License-Identifier: ATLC
pragma solidity >=0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";


/**
   * @title ATLCTimeLock
   * @dev ATLC TokenLock Contract w/ Vote Out Wallet Capability.
   * @custom:dev-run-script contracts/ATLCTimeLock.sol
   */
contract ATLCTimeLock {
    
    address public owner;
    address public ATLCToken;
    uint256 public availableForReleaseDateTime;
    uint256 public numTotalWallets; //total wallets (ie total elements in the walletAddresses variable because once they are added, they are never truly removed, but their address is set to 0 if they get votedOut)

    mapping(uint256 => address) public walletAddresses;
    mapping(address => uint256) public badActorVotesReceived;
    mapping(address => uint256) public walletLastVotedTimestamp;

    //JGK 4/13/23 - events added for logging to blockchain transaction log.
    event WalletAdded(address indexed wallet, uint256 amount);
    event TokensReleasedToWallet(address indexed ownerWallet, address indexed toWallet, uint256 amount);
    event WalletVotedOut(address indexed walletVotedOut);
    event ContractReceivedTokens(address indexed from, uint256 amount);
    event ContractFallbackReceivedTokens(address indexed from, uint256 amount);
  
    /*
        The constructor will accept up to 10 initial wallets for our founders. 
        The maximum number of wallets that can be added to this contract is 10.
    */
    constructor(address _ATLCToken) {

        //contract owner is set
        owner = msg.sender;

        //the location of the main ATLC Token that was minted
        ATLCToken = _ATLCToken;

        //the releaseTime is set to the current block timestamp plus 2 years.
        availableForReleaseDateTime = block.timestamp + 730 days; //approx 2 years

        //TODO: IMPORTANT, REMOVE THIS CODE AFTER TESTING AS THIS ALLOWS TOKENS TO BE RELEASED EARLY FOR TESTING.
        availableForReleaseDateTime = block.timestamp - 1 days;

    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only the contract owner can call this function");
        _;
    }


    /*
        The contractAddress function returns the public address of this time-locked contract.
    */
    function getContractAddress() public view returns (address){
        return address(this);
    }

    /*
        View-only function to return this contract's balance 
        NOTE: THIS IS VERY IMPORT BECAUSE IT'S GOING OUT TO THE LEDGE ESSENTIALLY OF THE ATLC TOKEN CONTRACT AND GETTING THE BALANCE OF THE ADDRESS 
        OF THE ATLC TOKEN ITSELF WHICH WAS PASSED INTO THE CONSTRUCTOR DURING THE DEPLOYMENT OF THIS ATLCTimeLocak SMART CONTRACT.
        Anyone can send any type of tokens to the address of a smart contract such as this. They essentially just recorded in a ledger somewhere
        of the token that is being transferred. So, this function goes out to the ATLCToken's smart contract address and gets the balance owned
        of ATLC tokens, and owned by THIS (ATLCTimeLock's) address.
    */
    function getContractBalance() public view returns(uint){
        return IERC20(ATLCToken).balanceOf(address(this)); 
    }

    /*
        The hasWalletVotedInLast24Hours will check the wallet that has voted last voted timestamp and add 24 hours to it
        and make sure that the current block.timestamp value is > than this value to allow them to vote again.
    */
    function hasWalletVotedInLast24Hours(uint256 lastVotedBlockTimestamp) private view returns (bool)
    {
        //lastVotedBlockTimestamp will be the block timestamp which is in seconds since 1970.
        //see if current block.timestamp > lastVotedBlockTimestamp + 24 hrs
        uint256 nextDay = lastVotedBlockTimestamp + (60*60*24); //60 seconds in a minute, 60 minutes in an hour, 24 hours in a day

        if(block.timestamp <= nextDay)
            return true;
        else 
            return false;
    }

    /*
        Loop through each wallet and only counts it if its address is still valid and hasn't been cleared/deleted by having it voted out.
        this is the count of wallets that we're going to actually pay out as valid founders.
    */
    function getTotalValidWallets() public view returns (uint256){
        
        uint256 validCount = 0;
        for (uint256 i = 0; i < numTotalWallets; i++) {
            
            address oneFounderWallet = walletAddresses[i];
            if(isValidWalletAddress(oneFounderWallet))
            {
                //there is a valid address in here that wasn't cleared.
                validCount++;
            }
            
        }

        return validCount;
    }

    /*
        The isValidWalletAddress checks to make sure the address has not be cleared/deleted by having a wallet voted out. When a wallet is voted out, the mapping
        element in walletAddresses will still exist but will have been set to the below hex 0 value.
    */
    function isValidWalletAddress(address walletToCheck) private pure returns (bool){
        if(walletToCheck != 0x0000000000000000000000000000000000000000)
            return true;
         else 
            return false;
    }

    /*
        The receive function must be in here in order for the contract to be able to receive tokens and hold onto them. 
    */
    //JGK 4/20/23 - removed this function since now the contract inherits from ERC20 and we will use its receive function.
    receive() external payable{
        
        //Just a note that I removed the onlyOwner modifier in the above receive() declaration because when we send our tokens to this
        //contract, they will most likely be coming from a master account rather than the owner of this contract which will be a different account.
        //Anyone can transfer tokens to the address of a smart contract.  However, in the releaseTokens function and in any calls to get
        //balances, it will always reach out using the Token Contract Address passed into the constructor of this smart contract. Therefore,
        //the balances and payouts will only ever operate on the ATLC Token itself, regardless of if this ATLCTimeLock smart contract has received
        //funds from other tokens.  
        
        //log
        emit ContractReceivedTokens(msg.sender, msg.value);
    }    
    
    fallback() external payable {
        
        emit ContractFallbackReceivedTokens(msg.sender, msg.value);
    }

    /*
        The addWallet function allows us to continue adding new wallets as new founders are added to the project. 
        However, only a maximum of 10 wallets (ie 10 founders) are allowed.
    */
    function addWallet(address walletToAdd) external onlyOwner {

        //Validation so that only contract owner can add wallets.
        require(msg.sender == owner, "Only contract owner can add a wallet");

        //Validation to prevent more than 10 wallets on this contract.
        require(getTotalValidWallets() < 10, "Max 10 valid wallets allowed");

        //Validation to prevent adding this wallet multiple times as this would continue incrementing the wallet count below.
        //require(sharesInWallet[walletToAdd] == 0, "Wallet already added");
    
        //loop through and see if this wallet is already in our walletAddresses list
        bool walletFound = false;
        for (uint256 i = 0; i < numTotalWallets; i++) {
            address wallet = walletAddresses[i];
            if(wallet == walletToAdd)
            {
                //error, wallet being added should not be found.
                walletFound = true;
                break;
            }
        }

        //Validation to prevent adding this wallet multiple times as this would continue incrementing the wallet count below.
        require(!walletFound, "Wallet already added");

        //Note: for the below, once we increment numTotalWallets, the value of this variable will never decrease because we can't ever truly remove a mapping index. 
        //However, if a vote-out occurs on a wallet, the walletAddress mapping value will be set to 0 and the getTotalValidWallets() will be used to cycle 
        //through and only pay out wallets with a valid address in the walletAddresses mapping variable.
        
        //add the wallet to the list of wallets.
        //then, recalculate the sharePerWallet and set this on each wallet accordingly.
        walletAddresses[numTotalWallets] = walletToAdd;
        numTotalWallets += 1; 

        //recalculate how many shares per each wallet.
        //now that a new wallet is being added, tokenShareEachWallet will have decreased.
        uint256 tokenShareEachWallet = getCurrentTokenShareForEachWallet();

        //JGK 4/13/23 - added emit event below
        emit WalletAdded(walletToAdd, tokenShareEachWallet);

    }

    /*
        This function gets the wei value shares per valid wallet. A valid wallet is a founder wallet that has been added and has not been voted out.
    */
    function getCurrentTokenShareForEachWallet() public view returns (uint256 tokenShareEachWallet){
        uint256 validWallets = getTotalValidWallets();
        if(validWallets > 0)
        {
            uint256 erc20Balance = getContractBalance(); // this.balanceOf(address(this));
            return erc20Balance / getTotalValidWallets();
        }
        else 
        {
            return 0;
        }
    }

    /*
        This function gets the whole values (converted from wei) shares per valid wallet. A valid wallet is a founder wallet that has been added and has not been voted out.
    */
    function getCurrentTokenShareForEachWalletWholeTokens() public view returns (uint256 tokenShareEachWallet){
        uint256 validWallets = getTotalValidWallets();
        if(validWallets > 0)
        {
            uint256 erc20Balance = getContractBalance() / (10**18); //this.balanceOf(address(this)) / (10**18);
            return erc20Balance / getTotalValidWallets();
        }
        else 
        {
            return 0;
        }
    }

    /*
        The voteOutWallet function will remove a wallet for a bad actor in the event they have not fulfilled their project duties.
        A majority vote will allow a wallet to be removed and not receive their founder tokens.
    */
    function voteOutWallet(address walletAddressOfBadActor) external {
        //make sure the wallet that is trying to cast this vote is in the walletAddresses list (ie, they are one of the founder wallets).
        bool founderWalletFound = false;
        for (uint256 i = 0; i < numTotalWallets; i++) {
            address wallet = walletAddresses[i];
            if(wallet == msg.sender)
            {
                //success in finding the wallet we want to try and vote out.
                founderWalletFound = true;
                break;
            }
        }
        //Validation to prevent any wallet on the internet from voting
        require(founderWalletFound, "Wallet casting vote was not found as being a founder wallet.");

        //Make sure the bad actor wallet being voted for is found in the list of founder wallets.   
        //loop through and see if this wallet is in our walletAddresses list
        bool badActorWalletFound = false;
        for (uint256 i = 0; i < numTotalWallets; i++) {
            address wallet = walletAddresses[i];
            if(wallet == walletAddressOfBadActor)
            {
                //success in finding the wallet we want to try and vote out.
                badActorWalletFound = true;
                break;
            }
        }
        //Validation to prevent adding this wallet multiple times as this would continue incrementing the wallet count below.
        require(badActorWalletFound, "Bad Actor Wallet not found or already voted out.");


        //Validate that the wallet casting a vote has not already voted within the last 24 hours.
        uint lastVotedTime = walletLastVotedTimestamp[msg.sender];
        bool walletVotedRecently = hasWalletVotedInLast24Hours(lastVotedTime);
        require(walletVotedRecently == false, "This Wallet already voted within last 24 hrs.");

        //store the current timestamp in the wallet who is voting
        walletLastVotedTimestamp[msg.sender] = block.timestamp;


        //increment the total number of vote-outs for the bad actor wallet passed in as a parameter to this function.
        uint256 votes = 0;
        badActorVotesReceived[walletAddressOfBadActor] += 1;

        votes = badActorVotesReceived[walletAddressOfBadActor];

        //Remove the wallet from our list of wallets if a majority has voted them out.
        //then, recalculate the sharePerWallet and set this on each wallet accordingly.

        //We want a majority share of votes from the remaining founders/wallets only. 
        //Divide by 2 to get the count of half of the remaning founders. If number of votes is greater, this means majority of remaining 
        //founders have voted this wallet OUT.
        if (votes > (getTotalValidWallets() / 2)) { 
            //JGK 4/13/23 - added emit event below
            emit WalletVotedOut(walletAddressOfBadActor);

            //loop through all remaining wallets (except the bad actor's wallet).
            uint256 badActorIndex;
            bool foundBadActorIndex = false;
            for (uint256 i = 0; i < numTotalWallets; i++) {
                
                //set current looping wallet
                address wallet = walletAddresses[i];
                
                if (wallet == walletAddressOfBadActor) {
                    foundBadActorIndex = true;
                    badActorIndex = i;
                    break;
                }
            }

            //Remove these elements from the mappings by calling deletes. Otherwise, the bad actor address will always be in the
            //mappings list.

            //perform delete using the key in the mappings. The key for walletAddress is an index.
            //since the badActorIndex could be 0 and the default value of a uint256 for badActorIndex would be 0, 
            //make sure foundBadActorIndex = true before trying to delete below.
            if(foundBadActorIndex)
            {
                //After voting out a wallet is there is now an empty value in the walletAddresses mapping and this particular element will still exist
                //and be included in the numTotalWallets count, but the value will be 0x0000000000000000000000000000000000000000.
                //The delete method below only clears the value and sets it to 0x0000000000000000000000000000000000000000.
                delete walletAddresses[badActorIndex];

            }
        }
    }

    /*
        The release function pays out equal amounts of all tokens to each wallet.
        Releasing of tokens is NOT permitted until a minimum of 2 years has passed.

        Below will be called to pay out wallets after 2 years has passed.
        addressOfThisContract parameter is the address of the contract that holds the erc20 token. 
        to parameter is the founder whose wallet we want to transfer the funds into.
        amount is number of tokens to transfer. when there are a total of 10 founders, the 100,000,000 will be split and each
        founder should receive 10,000,000 (10 million) tokens.  If there are less founder wallets, the 100 million tokens will
        be split evenly between the number of founder wallets. For example, if there are 8 founder wallets, each wallet will receive
        100,000,000 / 8 = 12.5 million per each wallet.
    */
    function releaseTokens() external payable onlyOwner {

        //validation to ensure only the contract owner can release tokens
        require(msg.sender == owner, "Only contract owner can release tokens");

        //validation to ensure at least 2 years has passed
        require(block.timestamp >= availableForReleaseDateTime, "Token release time not yet reached");

        //JGK 4/20/23 - changed below.
        uint256 erc20Balance = getContractBalance(); // this.balanceOf(address(this));

        //check to ensure there is a balance before doing math and trying to transfer tokens
        //uint256 contractBalance = address(this).balance;
        require(erc20Balance > 0, "0 token balance");

        uint256 totalShareEachWallet = getCurrentTokenShareForEachWallet();

        //loop through each wallet and disperse equal share funds to each one. if there are less than 10 wallets, then each
        //wallet will end up with more tokens dispersed to them. Note: numTotalWallets can include wallets already voted out as their element in the walletAddresses 
        //variable never fully disappears and is just set to 0 with a delete statement when a vote-out occurs.
        for (uint256 i = 0; i < numTotalWallets; i++) {
            
            address oneFounderWallet = walletAddresses[i];

            //check to make sure this wallet hasn't been voted out already and therefore is a valid wallet for a payout.
            if(isValidWalletAddress(oneFounderWallet))
            {
                bool success = transferTokens(oneFounderWallet, totalShareEachWallet);

                require(success, "Token transfer failed");

                //JGK 4/13/23 - added emit event below
                emit TokensReleasedToWallet(address(this), oneFounderWallet, totalShareEachWallet);
            }
        }
    }

    function transferTokens(address recipient, uint256 amount) private onlyOwner returns(bool)   {
        
        IERC20(ATLCToken).transfer(recipient, amount);
        return true;
    }
    
    
}