// SPDX-License-Identifier: MIT

pragma solidity =0.8.3;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Address.sol";

import "../interfaces/IERC1271.sol";
import "../interfaces/IBaseNFTExchange.sol";
import "../interfaces/INFTFactory.sol";
import "../interfaces/IStrategy.sol";
import "../libraries/Orders.sol";

abstract contract BaseNFTExchange is IBaseNFTExchange, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using Orders for Orders.Ask;
    using Orders for Orders.Bid;

    mapping(bytes32 => address) public override bestBidder;
    mapping(bytes32 => uint256) public override bestBidPrice;
    mapping(bytes32 => bool) public override isCancelled;
    mapping(bytes32 => uint256) public override amountFilled;

    mapping(bytes32 => Orders.Ask) public override orders;
    mapping(address => mapping(uint256 => bytes32[])) public override orderHashes;

    function DOMAIN_SEPARATOR() public view virtual override returns (bytes32);

    function factory() public view virtual override returns (address);

    function royaltyFeeInfo() public view virtual override returns (address, uint8) {
        return (address(0), uint8(0));
    }

    function _transfer(
        address nft,
        address from,
        address to,
        uint256 tokenId,
        uint256 amount
    ) internal virtual;

    function orderHashesLength(address nft, uint256 tokenId) external view override returns (uint256) {
        return orderHashes[nft][tokenId].length;
    }

    function _submitOrder(
        address nft,
        uint256 tokenId,
        uint256 amount,
        address strategy,
        address currency,
        uint256 deadline,
        bytes memory params
    ) internal returns (bytes32 hash) {
        Orders.Ask memory order =
            Orders.Ask(
                msg.sender,
                nft,
                tokenId,
                amount,
                strategy,
                currency,
                deadline,
                params,
                0,
                bytes32(0),
                bytes32(0)
            );
        hash = order.hash();
        orderHashes[nft][tokenId].push(hash);
        orders[hash] = order;
    }

    function cancel(Orders.Ask memory order) external override {
        require(order.maker == msg.sender, "SHOYU: FORBIDDEN");

        bytes32 hash = order.hash();
        isCancelled[hash] = true;

        emit Cancel(hash);
    }

    function bid(Orders.Ask memory askOrder, Orders.Bid memory bidOrder)
        external
        override
        nonReentrant
        returns (bool executed)
    {
        bytes32 askHash = askOrder.hash();
        require(askHash == bidOrder.askHash, "SHOYU: UNMATCHED_HASH");

        _verify(bidOrder.hash(), bidOrder.maker, bidOrder.v, bidOrder.r, bidOrder.s);

        return _bid(askOrder, askHash, bidOrder.maker, bidOrder.amount, bidOrder.price);
    }

    function bid(bytes32 askHash, Orders.Bid memory bidOrder) external override nonReentrant returns (bool executed) {
        require(askHash == bidOrder.askHash, "SHOYU: UNMATCHED_HASH");

        _verify(bidOrder.hash(), bidOrder.maker, bidOrder.v, bidOrder.r, bidOrder.s);

        return _bid(orders[askHash], askHash, bidOrder.maker, bidOrder.amount, bidOrder.price);
    }

    function bid(
        Orders.Ask memory askOrder,
        uint256 bidAmount,
        uint256 bidPrice
    ) external override nonReentrant returns (bool executed) {
        return _bid(askOrder, askOrder.hash(), msg.sender, bidAmount, bidPrice);
    }

    function bid(
        bytes32 askHash,
        uint256 bidAmount,
        uint256 bidPrice
    ) external override nonReentrant returns (bool executed) {
        return _bid(orders[askHash], askHash, msg.sender, bidAmount, bidPrice);
    }

    function _bid(
        Orders.Ask memory askOrder,
        bytes32 askHash,
        address bidder,
        uint256 bidAmount,
        uint256 bidPrice
    ) internal returns (bool executed) {
        _validate(askOrder, askHash);
        _verify(askHash, askOrder.maker, askOrder.v, askOrder.r, askOrder.s);

        bool expired = askOrder.deadline < block.number;
        bool canClaim = bidder == bestBidder[askHash];
        if ((expired && canClaim) || (!expired && IStrategy(askOrder.strategy).canExecute(askOrder.params, bidPrice))) {
            amountFilled[askHash] += bidAmount;

            _transfer(askOrder.nft, askOrder.maker, bidder, askOrder.tokenId, bidAmount);
            _transferFeesAndFunds(askOrder.maker, askOrder.currency, bidder, bidPrice);

            emit Execute(askHash, bidder, bidAmount, bidPrice);
            return true;
        } else if (!expired && IStrategy(askOrder.strategy).canBid(askOrder.params, bidPrice, bestBidPrice[askHash])) {
            bestBidder[askHash] = bidder;
            bestBidPrice[askHash] = bidPrice;

            emit Bid(askHash, bidder, bidAmount, bidPrice);
            return false;
        } else {
            revert("SHOYU: FAILURE");
        }
    }

    function _validate(Orders.Ask memory ask, bytes32 askHash) internal view {
        require(!isCancelled[askHash], "SHOYU: CANCELLED");
        require(amountFilled[askHash] < ask.amount, "SHOYU: FILLED");

        require(ask.maker != address(0), "SHOYU: INVALID_MAKER");
        require(ask.nft == address(this), "SHOYU: INVALID_NFT");
        require(ask.amount > 0, "SHOYU: INVALID_AMOUNT");
        require(ask.strategy != address(0), "SHOYU: INVALID_STRATEGY");
        require(ask.currency != address(0), "SHOYU: INVALID_CURRENCY");
        require(INFTFactory(factory()).isStrategyWhitelisted(ask.strategy), "SHOYU: STRATEGY_NOT_WHITELISTED");
    }

    function _verify(
        bytes32 hash,
        address signer,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal view {
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR(), hash));
        if (Address.isContract(signer)) {
            require(
                IERC1271(signer).isValidSignature(digest, abi.encodePacked(r, s, v)) == 0x1626ba7e,
                "SHOYU: UNAUTHORIZED"
            );
        } else {
            require(ecrecover(digest, v, r, s) == signer, "SHOYU: UNAUTHORIZED");
        }
    }

    function _transferFeesAndFunds(
        address maker,
        address currency,
        address bidder,
        uint256 bidPriceSum
    ) internal {
        address _factory = factory();
        uint256 remainder = bidPriceSum;
        {
            (address protocolFeeRecipient, uint8 protocolFeePermil) = INFTFactory(_factory).protocolFeeInfo();
            uint256 protocolFeeAmount = (bidPriceSum * protocolFeePermil) / 1000;
            IERC20(currency).safeTransferFrom(bidder, protocolFeeRecipient, protocolFeeAmount);
            remainder -= protocolFeeAmount;
        }

        {
            (address operationalFeeRecipient, uint8 operationalFeePermil) = INFTFactory(_factory).operationalFeeInfo();
            uint256 operationalFeeAmount = (bidPriceSum * operationalFeePermil) / 1000;
            IERC20(currency).safeTransferFrom(bidder, operationalFeeRecipient, operationalFeeAmount);
            remainder -= operationalFeeAmount;
        }

        (address royaltyFeeRecipient, uint8 royaltyFeePermil) = royaltyFeeInfo();
        uint256 royaltyFeeAmount = (remainder * royaltyFeePermil) / 1000;
        if (royaltyFeeAmount > 0) {
            remainder -= royaltyFeeAmount;
            IERC20(currency).safeTransferFrom(bidder, royaltyFeeRecipient, royaltyFeeAmount);
        }

        IERC20(currency).safeTransferFrom(bidder, maker, remainder);
    }
}