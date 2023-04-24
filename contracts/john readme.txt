(4) .sol solidity file exists.

Note: Even though I have VS Code installed locally, I did all the coding and debugging for this in my account at:
https://remix.ethereum.org  
My ATLC.TimeLockContract workspace contained all my files below.

1. ATLCMinter.sol - can test minting a new type of token and send it to an address such as the address of an account in metamask.


2. ATLCTimeLock.sol - this is my main smart contract for being able to be sent our ATLC tokens and holding them for 2 years and then releaseTokens will allow them to be released to founders.  This contract also allows founding wallets that have already been added to the list of wallets, to be able to vote-out a bad actor wallet. If majority of wallets vote for same bad actor, the bad actor wallet will not receive a token payout.

To use this smart contract, it must be deployed AFTER the main ATLC Token has been created. When deploying ATLCTimeLock, the ATLC Token's address must be passed into its constructor.

Then, get the address of the deployed ATLCTimeLock smart contract and go into a wallet that contains a bunch of the ATLC Tokens and send the ATLCTimeLock contract the tokens.

Call Add Wallet as the ATLCTimeLock contract's owner until all founding wallets have been added.  Can call getCurrentTokenShareForEachWalletWholeTokens as well as functions such as getTotalValidWallets to verify founder wallets contained in the contract.

Founders can use tool such as Remix and enter the ATLCTimeLock's contract address if they want to vote out a wallet. All voting will need to be coordinated and performed within a 24 hours period whereby it will prevent them from re-voting.
When a founding wallet connects to the contract, they will only be able to vote if their wallet itself is in the list of wallets already. They will need to pass in the wallet address of the bad actor. If > 50% of all wallets vote for the same bad actor, that bad actor wallet will be removed and their address will be set to all 0x000000000000's in their address. numTotalWallets will NOT be decremented, but getTotalValidWallets WILL be decremented.

Only valid wallets will be sent their tokens during the releaseTokens call. releaseTokens will get the contract's total balance of only the ATLC Token owned by the ATLCTimeLock contract and it will split out the shares evenly to remaining valid wallets.


3. TestReceive.sol - this is not used anywhere but I used it to prove out the sending of an outside-generated token INTO a smart contract to ensure the balance of the TestReceive smart contract went up.


4. ATLCMintAndTimeLockAndVoteOut.sol - this is not used anywhere but this was one of my versions of the time lock contract that required minting the token from it and transferring them either to an outside account or mint and send back into itself to hold them for 2 years. There is some invalid practices still in this contract due to the way the balances are tried to be called. It seemed to work in terms of being able to send tokens back into it, but only if they had been minted by this contract itself. It also inherited from ERC20 which in my opinion would've been more risky to us if we minted our token AND at the same time held a portion of them by this same contract. My preference was to have the minting of the ATLC Token itself be done using Colony or an outside application.  Then, transferring tokens back into a time lock contract so that its sole function was holding founding tokens and not necessarily our whole ATLC Token minting and operation of it. Therefore, I created the ATLCTimeLock contract and it replaced this one.



**********************************************************************************************
Testing that was performed has been placed below:
MetaMask Wallet (Test Account): 0x832F90cf5374DC89D7f8d2d2ECb94337f54Dd537
MetaMask Wallet (Test Account 2): 0xe8CE65fCe771bDe34fbB2Df57C3Cb15105DB8e75
MetaMask Wallet (Test Account 3): 0x643A87055213c3ce6d0BE9B1762A732e9E059536

	1. Ran ATLCMinter and deployed it using Test Account as owner into Chiado using metamask injected provider.  Token contract address: 0x922391bA650343C961DAa7EfdB7446071cD75cA4
	2. Minted 50 TST1 tokens to Test Account 3: 0x643A87055213c3ce6d0BE9B1762A732e9E059536, 50000000000000000000
	3. Go into Test Account 3 and Import Tokens:  0x922391bA650343C961DAa7EfdB7446071cD75cA4. 50 TST1 tokens appeared
	4. Compile and deploy ATLCTimeLock time locking smart contract using Token contract address for TST1 token during deployment: 0x922391bA650343C961DAa7EfdB7446071cD75cA4
		a. Test Account d537 was used in deployment and is the owner.
	5. ATLCTimeLock smart contract has contract address of: 0xCFCE3446D8446a8Fcf1355f9b34DB0d23A2100Ec
	6. Add Wallet of Test Account 2: 0xe8CE65fCe771bDe34fbB2Df57C3Cb15105DB8e75
	7. Go into metamask in Test Account 3 and send 12 TST1 tokens to ATLCTimeLock contract address: 0xe8CE65fCe771bDe34fbB2Df57C3Cb15105DB8e75
		a. getContractBalance: 12000000000000000000
		b. getTotalValidWallets: 1
		c. getCurrentTokenShareForEachWalletWholeTokens: 12
	8. Add Wallet of Test Account 3: 0x643A87055213c3ce6d0BE9B1762A732e9E059536
		a. getTotalValidWallets: 2
		b. getCurrentTokenShareForEachWalletWholeTokens: 6
	9. D537 owner account has .3756 xDAI
	10. releaseTokens called
		a. D537 owner account NOW has .3754 xDAI  (gas fees)
		b. Import Tokens on Test Account 2. Balance of 6 TST1 is displayed.
		c. Test Account 3 now has balance of 44 TST1 tokens.  50 initially minted and sent. 12 transferred to ATLCTimeLock.  6 transferred back over to Test Account 3. (50 - 12 + 6) = 44 
		d. ATLCTimeLock balance: 0
	11. In Test Account 3, tried sending 4 more TST1 tokens over to ATLCTimeLock contract: 0xCFCE3446D8446a8Fcf1355f9b34DB0d23A2100Ec
		a. SUCCESS
	12. releaseTokens called again.
		a. Test Account 2 new balance: 8 TST1
		b. Test Account 3 new balance is 42 TST1.  (44 - 4 + 2) = 42.

SUCCESS in everything above!!!
