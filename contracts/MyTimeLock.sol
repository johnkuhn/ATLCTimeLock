// SPDX-License-Identifier: KuhnSoft LLC
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Strings.sol";


/// @title MyTimeLock
/// @author John Kuhn
/// @notice MyTimeLock Contract w/ Vote Out Wallet Capability. Accepts tokens of a specific type and holds them for 2 years before allowing release to up to 10 wallets.
/// @dev MyTimeLock Contract w/ Vote Out Wallet Capability. Accepts tokens of a specific type and holds them for 2 years before allowing release to up to 10 wallets.
///     1. Deploy contract as contract owner. 2. AddWallets until all founders have been added. 3. To hold a bad actor vote, contract owner must call 
///     setVotingStatusAndClearPreviousValuesWhenOpening(true) and all other wallets can then call voteOutWallet. If majority votes out a bad actor, they will immediately 
///     be removed and their wallet address will be set to 0x00000000... address. Contract owner should then call setVotingStatusAndClearPreviousValuesWhenOpening(false) 
///     to shut down voting capability again. 4. Once 2 years has been reached since contract deployment, releaseTokens can be called by contract owner to split all tokens
///     to remaining founder wallets evenly. Note: This contract can only be funded by the token address of the LIVE token's address when the constructor is called and this
///     is what is split out to founder wallets. It expects an ERC20 token as funding.
/// @custom:dev-run-script contracts/MyTimeLock.sol

contract MyTimeLock {
    
    address public owner;
    address public myToken;
    uint256 public availableForReleaseDateTime;
    uint256 public numTotalWallets; //total wallets (ie total elements in the walletAddresses variable because once they are added, they are never truly removed, but their address is set to 0 if they get votedOut)

    mapping(uint256 => address) public walletAddresses;
    mapping(address => uint256) public badActorVotesReceived;
    mapping(address => uint256) public walletLastVotedTimestamp;
    bool public isOpenForVoting;
    address public recentWalletVotedOut;

    //JGK 4/13/23 - events added for logging to blockchain transaction log.
    event WalletAdded(address indexed wallet, uint256 amount);
    event TokensReleasedToWallet(address indexed ownerWallet, address indexed toWallet, uint256 amount);
    event WalletVotedOut(address indexed walletVotedOut);
    event ContractReceivedTokens(address indexed from, uint256 amount);
    event ContractFallbackReceivedTokens(address indexed from, uint256 amount);
  
    
    /// @dev The constructor should be passed the address of the LIVE ERC20 deployed token.     
    constructor(address _myToken) {

        //contract owner is set
        owner = msg.sender;

        //the location of the main Token that was minted
        myToken = _myToken;

        //the releaseTime is set to the current block timestamp plus 2 years.
        availableForReleaseDateTime = block.timestamp + 730 days; //approx 2 years

        //TODO: IMPORTANT, REMOVE THIS CODE AFTER TESTING AS THIS ALLOWS TOKENS TO BE RELEASED EARLY FOR TESTING.
        //availableForReleaseDateTime = block.timestamp - 1 days;

    }

    /// @dev This is a function modifier to prevent anyone, except contract owner, from calling functions that use this modifier.
    modifier onlyOwner() {
        require(msg.sender == owner, "Only the contract owner may call.");
        _;
    }

    
    /// @dev The receive function must be in here in order for the contract to be able to receive tokens and hold onto them. 
    receive() external payable{
        
        //Just a note that I removed the onlyOwner modifier in the above receive() declaration because when we send our tokens to this
        //contract, they will most likely be coming from a master account rather than the owner of this contract which will be a different account.
        //Anyone can transfer tokens to the address of a smart contract.  However, in the releaseTokens function and in any calls to get
        //balances, it will always reach out using the Token Contract Address passed into the constructor of this smart contract. Therefore,
        //the balances and payouts will only ever operate on the MyToken itself, regardless of if this MyTimeLock smart contract has received
        //funds from other tokens.  
        
        //log
        emit ContractReceivedTokens(msg.sender, msg.value);
    }    
    
    /// @dev As per best practices, it is good to have a fallback receive function to allow the contract to receive tokens if an error occurs.
    fallback() external payable {
        
        emit ContractFallbackReceivedTokens(msg.sender, msg.value);
    }


    /// @dev The contractAddress function returns the public address of this time-locked contract.
    function getContractAddress() external view returns (address){
        return address(this);
    }

    
    /// @dev Function allows owner to open or close bad actor voteOutWallet voting. Upon opening, this will automatically clear any previous bad actor votes to start fresh and
    ///    will also reset the voting clock to 0 to allow everyone to begin voting again.
    ///    Once voting has been completed, this function will need to be called again to close out voting capability. Otherwise, a wallet could simply wait
    ///    24 hours and vote for another wallet until all wallets are removed.
    /// @param isOpen Whether you want to open (true) or close (false) off voting.
    /// @return Whether or not voting is now open or closed.
    function setVotingStatusAndClearPreviousValuesWhenOpening(bool isOpen) external onlyOwner returns (bool){

        isOpenForVoting = isOpen;

        //if we're opening up voting status, clear any previous results.
        if(isOpen)
        {
            clearOutAllPreviousVoting();
        }

        return isOpenForVoting;
    }

    
    /// @dev The voteOutWallet function will remove a wallet for a bad actor in the event they have not fulfilled their project duties.
    ///    A majority vote will allow a wallet to be removed and not receive their founder tokens.
    /// @param walletAddressOfBadActor Pass in the contract address of the bad actor you are trying to vote out.
    function voteOutWallet(address walletAddressOfBadActor) external {

        //make sure voting is open
        require(isOpenForVoting, "Voting is not open.");

        //don't let a wallet vote for themselves accidentally
        require(msg.sender != walletAddressOfBadActor, "Wallet cannot vote for themselves.");

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
        require(founderWalletFound, "Wallet casting vote not founder.");

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
        uint256 lastVotedTime = walletLastVotedTimestamp[msg.sender];
        bool walletVotedRecently = isWithin24Hours(lastVotedTime);
        require(walletVotedRecently == false, "This Wallet voted within last 24 hrs.");

        //store the current timestamp in the wallet who is voting
        walletLastVotedTimestamp[msg.sender] = block.timestamp;

        //increment the total number of vote-outs for the bad actor wallet passed in as a parameter to this function.
        uint256 votes = 0;
        badActorVotesReceived[walletAddressOfBadActor] = badActorVotesReceived[walletAddressOfBadActor] + 1;

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

                //set variable so we know who was most recently voted out
                recentWalletVotedOut = walletAddressOfBadActor;
            }
        }
    }

    /// @dev This functions returns a delimited list of founder wallets that have voted in the last 24 hours.
    ///    A majority vote will allow a wallet to be removed and not receive their founder tokens.
    /// @return list of delimited wallet address who HAVE voted for a bad actor.
    function getListOfWalletsWhoVotedInLast24Hrs() external view returns (string memory){

        string memory walletsRecentlyVoted;

        //Make sure the wallet that is trying to see voting information is in the walletAddresses list (ie, they are one of the founder wallets).
        //Note: if a founder wallet gets voted out, they will no longer be in this list and won't be able to see voting information as soon as they are voted out.
        bool ownerOrFounderWalletFound = false;

        if(msg.sender == owner)
        {
            //caller is the contract owner
            ownerOrFounderWalletFound = true;
        }
        else 
        {
            for (uint256 i = 0; i < numTotalWallets; i++) {
                address wallet = walletAddresses[i];
                if(wallet == msg.sender)
                {
                    //success in finding the caller in the list of founder wallets
                    ownerOrFounderWalletFound = true;
                    break;
                }
            }
        }

        //Validation to prevent any wallet on the internet from voting
        require(ownerOrFounderWalletFound, "Must be contract owner or Founder.");

        //loop through each valid founder wallet (that has not be voted out), and see if they have voted in last 24 hours. if so, add them to the comma delimited string
        //to be returned.
        for (uint256 i = 0; i < numTotalWallets; i++) {
            
            //get this founder wallet
            address oneFounderWallet = walletAddresses[i];

            //make sure this is a valid wallet address (don't interrogate any invalid or 0x0000000... addresses for wallets that may have been voted out).
            if(isValidWalletAddress(oneFounderWallet))
            {
                //Validate that the wallet casting a vote has not already voted within the last 24 hours.
                uint256 lastVotedTime = walletLastVotedTimestamp[oneFounderWallet];

                //see if this wallet has voted in last 24 hours
                bool walletVotedRecently = isWithin24Hours(lastVotedTime);

                string memory myDelimiter = "~";


                //add them to the list of strings to be returned if they've voted in last 24 hours.
                if(walletVotedRecently)
                {
                    //add delimiter on the end as long as we're not on the last address.
                    walletsRecentlyVoted = string.concat(walletsRecentlyVoted, myDelimiter);

                    //convert the wallet to a string
                    string memory oneFounderWalletString = Strings.toHexString(uint256(uint160(oneFounderWallet)), 20);
                    walletsRecentlyVoted = string.concat(walletsRecentlyVoted, oneFounderWalletString); //walletsRecentlyVoted + ", " + string(abi.encodePacked(walletVotedRecently));
                
                    
                }
            }
        }

        
        return walletsRecentlyVoted;

    }

    /// @dev The release function pays out equal amounts of all tokens to each valid wallet. A valid wallet is one that has NOT been voted out.
    ///    Releasing of tokens is NOT permitted until a minimum of 2 years has passed and only contract owner can release tokens.
    ///    Below will be called to pay out wallets after 2 years has passed.
    ///    When there are a total of 10 founders, the 100,000,000 will be split and each
    ///    founder should receive 10,000,000 (10 million) tokens.  If there are less founder wallets, the 100 million tokens will
    ///    be split evenly between the number of founder wallets. For example, if there are 8 founder wallets, each wallet will receive
    ///    100,000,000 / 8 = 12.5 million per each wallet.
    function releaseTokens() external payable onlyOwner {

        //validation to ensure only the contract owner can release tokens
        //require(msg.sender == owner, "Only contract owner can release tokens");

        //validation to ensure at least 2 years has passed
        require(block.timestamp >= availableForReleaseDateTime, "Token release time not reached");

        //JGK 4/20/23 - changed below.
        uint256 erc20Balance = getContractBalance(); // this.balanceOf(address(this));

        //check to ensure there is a balance before doing math and trying to transfer tokens
        //uint256 contractBalance = address(this).balance;
        require(erc20Balance > 0, "0 token balance");

        uint256 totalShareEachWallet = getCurrentTokenShareForEachWallet();

        //ensure token share to be transferred to each valid wallet > 0
        require(totalShareEachWallet > 0, "0 token share each wallet");

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

    /// @dev The addWallet function allows us to continue adding new wallets as new founders are added to the project. 
    ///     However, only a maximum of 10 wallets (ie 10 founders) are allowed.
    /// @param walletToAdd The wallet we want to add as a founder wallet. 
    function addWallet(address walletToAdd) external onlyOwner {

        //Validation so that only contract owner can add wallets.
        //require(msg.sender == owner, "Only contract owner can add a wallet");

        //Validation to prevent more than 10 wallets on this contract.
        require(getTotalValidWallets() < 10, "Max 10 valid wallets allowed");

        //ensure a 0 address wallet isn't being passed in.
        bool isValid = isValidWalletAddress(walletToAdd);
        require(isValid, "Invalid wallet being added.");


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
        numTotalWallets = numTotalWallets + 1; 

        //recalculate how many shares per each wallet.
        //now that a new wallet is being added, tokenShareEachWallet will have decreased.
        uint256 tokenShareEachWallet = getCurrentTokenShareForEachWallet();

        //JGK 4/13/23 - added emit event below
        emit WalletAdded(walletToAdd, tokenShareEachWallet);

    }

    /// @dev View-only function to return this contract's balance in WEI
    ///    NOTE: THIS IS VERY IMPORT BECAUSE IT'S GOING OUT TO THE LEDGE ESSENTIALLY OF THE MAIN TOKEN CONTRACT AND GETTING THE BALANCE OF THE ADDRESS 
    ///    OF THE MYTOKEN ITSELF WHICH WAS PASSED INTO THE CONSTRUCTOR DURING THE DEPLOYMENT OF THIS MyTimeLocak SMART CONTRACT.
    ///    Anyone can send any type of tokens to the address of a smart contract such as this. They essentially just recorded in a ledger somewhere
    ///    of the token that is being transferred. So, this function goes out to the myToken's smart contract address and gets the balance owned
    ///    of our specific token, and owned by THIS (MyTimeLock's) address.
    /// @return Full contract balance in WEI (with 18 0's after it). 
    function getContractBalance() public view returns(uint256){
        return IERC20(myToken).balanceOf(address(this)); 
    }

    /// @dev View-only function to return this contract's balance in whole tokens
    ///    NOTE: THIS IS VERY IMPORT BECAUSE IT'S GOING OUT TO THE LEDGE ESSENTIALLY OF THE MAIN TOKEN CONTRACT AND GETTING THE BALANCE OF THE ADDRESS 
    ///    OF THE MYTOKEN ITSELF WHICH WAS PASSED INTO THE CONSTRUCTOR DURING THE DEPLOYMENT OF THIS MyTimeLocak SMART CONTRACT.
    ///    Anyone can send any type of tokens to the address of a smart contract such as this. They essentially just recorded in a ledger somewhere
    ///    of the token that is being transferred. So, this function goes out to the myToken's smart contract address and gets the balance owned
    ///    of our specific token, and owned by THIS (MyTimeLock's) address.
    /// @return Full contract balance in ETH (whole tokens WITHOUT 18 0's after it). 
    function getContractBalanceWholeTokens() public view returns(uint256){
        uint256 fullBalance = getContractBalance(); 

        if(fullBalance > 0)
        {
            uint256 erc20BalanceWholeValue = getContractBalance() / (10**18);
            return erc20BalanceWholeValue;
        }
        else 
        {
            return 0;
        }
    }

    /// @dev Loop through each wallet and only counts it if its address is still valid and hasn't been cleared/deleted by having it voted out.
    ///    this is the count of wallets that we're going to actually pay out as valid founders.
    /// @return Count of valid wallets (these are wallets that HAVE NOT been voted out).
    function getTotalValidWallets() public view returns (uint8){
        
        uint8 validCount = 0;
        for (uint8 i = 0; i < numTotalWallets; i++) {
            
            address oneFounderWallet = walletAddresses[i];
            if(isValidWalletAddress(oneFounderWallet))
            {
                //there is a valid address in here that wasn't cleared.
                validCount++;
            }
            
        }

        return validCount;
    }

    /// @dev This function gets the wei value shares per valid wallet. A valid wallet is a founder wallet that has been added and has not been voted out.
    /// @return tokenShareEachWallet Count of tokens that will be paid out to each valid wallet (in WEI format with 18 0's).
    function getCurrentTokenShareForEachWallet() public view returns (uint256 tokenShareEachWallet){
        uint8 validWallets = getTotalValidWallets();
        if(validWallets > 0)
        {
            uint256 erc20Balance = getContractBalance(); // this.balanceOf(address(this));
            return erc20Balance / validWallets;
        }
        else 
        {
            return 0;
        }
    }

    /// @dev This function gets the whole values (converted from wei) shares per valid wallet. A valid wallet is a founder wallet that has been added and has not been voted out.
    /// @return tokenShareEachWallet Count of tokens that will be paid out to each valid wallet (in ETH whole token format WITHOUT 18 0's).
    function getCurrentTokenShareForEachWalletWholeTokens() public view returns (uint256 tokenShareEachWallet){
        uint8 validWallets = getTotalValidWallets();
        if(validWallets > 0)
        {
            uint256 erc20Balance = getContractBalance() / (10**18); //this.balanceOf(address(this)) / (10**18);
            return erc20Balance / validWallets;
        }
        else 
        {
            return 0;
        }
    }

    /// @dev This function is a private function that is used to perform the ERC20 token transfer.
    /// @param recipient The founder wallet address we want to send amount of our ERC20 token to.
    /// @param amount The amount of tokens (in WEI w/ 18 0's) to send to the recipient.
    /// @return true or false (success or failure) 
    function transferTokens(address recipient, uint256 amount) private onlyOwner returns(bool)   {
        
        if(isValidWalletAddress(recipient) && amount > 0)
        {
            IERC20(myToken).transfer(recipient, amount);
                return true;
        }
        else 
        {
            //invalid 0 address wallet was passed in or amount <= 0..
            return false;
        }
    }

    /// @dev Allows owner to clear out all previous voting information to start again. It removes any current vote tallies already given to any bad actors and
    ///     resets them to 0. It removes the timestamps from any founders who have already voted in last 24 hours so they can begin voting again even if 
    ///     they had voted within the last 24 hours.
    function clearOutAllPreviousVoting() private onlyOwner{

        for (uint8 i = 0; i < numTotalWallets; i++) {
            
            address oneFounderWallet = walletAddresses[i];
            if(isValidWalletAddress(oneFounderWallet))
            {
                //this wallet is valid. It may or may not be in the array. try to set the vote count back to 0 if it's found.
                badActorVotesReceived[oneFounderWallet] = 0;

                walletLastVotedTimestamp[oneFounderWallet] = 0;
            }
            
        }
    }
    
    /// @dev The isWithin24Hours will check the wallet that has voted last voted timestamp and add 24 hours to it
    ///    and make sure that the current block.timestamp value is > than this value to allow them to vote again.
    ///    This function is necessary to prevent a wallet from voting more than once in a voting session. 
    ///    It is expected that the contract owner will call setVotingStatus to either open up or close voting and that all voting
    ///    should occur within a 24 hour period. When setVotingStatus is set to isOpen (true), this will clear any previous voting tally's 
    ///    of bad actor's to start again.
    /// @param lastVotedBlockTimestamp The last time a founder wallet has voted.
    /// @return true or false for whether or not the passed in timestamp is within 24 hours to the current block.timestamp.
    function isWithin24Hours(uint256 lastVotedBlockTimestamp) private view returns (bool)
    {
        //lastVotedBlockTimestamp will be the block timestamp which is in seconds since 1970.
        //see if current block.timestamp > lastVotedBlockTimestamp + 24 hrs
        uint256 nextDay = lastVotedBlockTimestamp + (60*60*24); //60 seconds in a minute, 60 minutes in an hour, 24 hours in a day

        if(block.timestamp <= nextDay)
            return true;
        else 
            return false;
    }

    /// @dev The isValidWalletAddress checks to make sure the address has not be cleared/deleted by having a wallet voted out. When a wallet is voted out, the mapping
    ///    element in walletAddresses will still exist but will have been set to the below hex 0 value.
    /// @param walletToCheck The wallet address to check whether or not it is valid.
    /// @return true or false for whether or not the passed in wallet address is valid. 
    function isValidWalletAddress(address walletToCheck) private pure returns (bool){
        if(walletToCheck == 0x0000000000000000000000000000000000000000 ||
            walletToCheck == address(0) || 
             walletToCheck == address(0x0)) 
            return false;
         else 
            return true;
    }


}
