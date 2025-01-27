# Shoyu: Sushi NFT Exchange and Launchpad

We are looking to create an NFT platform that focuses on artists and creators needs to push the space forward. Current NFTs are limited by file format and sizing for artist and their creative abilities. Design wise we want the platform to be beautiful, functional and have that Japanese sensibility and aesthetic. We want artists and creators to be able to create NFTs that they are unable to make on other platforms. For collectors a beautiful place to curate and showcase their digital art.

## Features
### 1 Social Token
`SocialToken`s are built around an “ownership economy” principle with the premise that a community will be more valuable tomorrow than today.
Creators can monetize their work as a non-fungible token (NFT) or social token, and supporters can give something back to show their loyalty.

### 1.1 Minting
Owner of the social token can mint a certain amount of tokens for an account, proportional to the contribution he's committed. The amount of the contribution will be observed off-chain by the owner. 

### 1.2 Burning
Any holder of the social token can burn his/her own balance with a memo(`bytes32`). This can be used for a variety of scenarios such as **a. burn-and-enter**, **b. burn-and-receive** or **c. burn-and-draw**.

* **burn-and-enter**: Users burn their tokens and get the entrance permission to a gallery, exhibition or a concert.
* **burn-and-receive**: Users burn their tokens and leave their address. Then the artist delivers the merch or the product to their front door.
* **burn-and-draw**: Users burn their tokens and get a lottery ticket. It can be designed such that the more he burns, the higher the chance to win the lottery.

### 1.3 Revenue Sharing
As an artist or a seller, the owner of the social token can make revenue and set the recipient to the holders of the social token. The revenue will then be distributed to the holders in proportion to the shares.

## 2 NFT-as-Exchange
Shoyu's `ERC-721` and `ERC-1155` contracts are equipped with NFT exchange functionality in themselves(`NFT721` and `NFT1155` respectively). This is the cheapest way to optimize gas and give the owner the full power to change configs needed for trades.

### 2.1 On-chain & Off-chain OrderBook
To optimize gas cost when submitting sell order, orders are kept off-chain basically. When an account wants to buy the nft, he can pick the order with the maker's signature(`ERC-712`) and execute it with a proper bid params such as the price.

It also supports on-chain order book, so you could submit ask orders. This feature was designed for contracts not EOAs. *e.g.) If you're running a dao for NFTs, then contracts should be able to submit orders.*

### 2.2 Variant Bidding Strategies
Strategies are separate from exchange contracts, so a variety of strategies can be plugged in to meet the seller's demand. Supported strategies are: a. `FixedPriceSale`, b. `EnglishAuction` and c. `DutchAuction`.

* Fixed Price Sale: The first buyer who pays for the fixed price gets the NFT.
  
* English Auction: An English auction is a process in which an asset is sold through a suggested opening bid reserve or a starting price that is set by the seller. Increasingly higher bids are accepted from the gamut of buyers. Ultimately, the price is adjusted in a direction that's unfavorable to the bidders.
  
* Dutch Auction: A Dutch auction is a market structure in which the price of something offered is determined after taking in all bids to arrive at the highest price at which the total offering can be sold. In this type of auction, investors place a bid for the amount they are willing to buy in terms of quantity and price.

### 2.3 Royalties Distribution
NFT royalties give the owner a percentage of the sale price each time their NFT creation is sold on Shoyu. They can choose their royalty percentage(0-25%).

### 2.4 Charity Fund
Among the royalties they get, they can decide how much will go to the charity fund vault. This vault is managed by a multisig wallet operated by Sushi team.

### 2.5 NFT Tagging
NFTs can be categorised and tagged to allow better searching capabilities.

## 3 Fractional NFT Ownership & Governance
Fractional ownership allows users who have been previously priced out of certain NFTs or artists (such as Beeple) to be able to buy a piece of their work.

### 3.1 Liquidation
If you're holding a `NFT721` token, you can call `liquidate()` function to turn your nft to a `NFT721GovernanceToken` (`ERC-20`) that's representing the value of your nft.

### 3.2 Governance
Token holders can vote for a sell proposal to run the NFT governance. If more than `minimumQuorum` balance power is for the proposal that were submitted, then it starts selling process; It could be an auction for a fixed price sale.

### 3.3 Profit Sharing
After the sale gets completed, the profit is shared by the owners in proportional to their balances.

## 4 Others

### 4.1 Protocol Fee
2.5% fee is charged for every trade and it goes to `xSUSHI` holders.

### 4.2 Exchange for non-Shoyu NFTs
Even though Shoyu's NFTs is equipped with exchange features, there could be a need to sell NFTs that were minted outside of Shoyu. In that case, you could use `NFT721Exchange` and `NFT1155Exchange` contracts.

### 4.3 Factories
To optimize the gas required for contract deployments, Shoyu utilizes factory patter at its maximum extent. Provided factories are: `NFT721GovernanceTokenFactory`, `NFTFactory`, `PaymentSplitterFactory`, and `SocialTokenFactory`.

## License

Distributed under the MIT License. See `LICENSE` for more information.

## Contact

* [LevX](https://twitter.com/LevxApp/)
