// SPDX-License-Identifier: MIT

pragma solidity =0.8.3;

import "./interfaces/INFT1155.sol";
import "./base/BaseNFT1155.sol";
import "./base/BaseNFTExchange.sol";

contract NFT1155 is BaseNFT1155, BaseNFTExchange, INFT1155 {
    address internal _royaltyFeeRecipient;
    uint8 internal _royaltyFee; // out of 1000

    function initialize(
        string memory _uri,
        address _owner,
        address royaltyFeeRecipient,
        uint8 royaltyFee
    ) external override initializer {
        initialize(_uri, _owner);

        setRoyaltyFeeRecipient(royaltyFeeRecipient);
        setRoyaltyFee(royaltyFee);
    }

    function DOMAIN_SEPARATOR() public view override(BaseNFT1155, BaseNFTExchange, INFT1155) returns (bytes32) {
        return _DOMAIN_SEPARATOR;
    }

    function factory() public view override(BaseNFT1155, BaseNFTExchange, INFT1155) returns (address) {
        return _factory;
    }

    function royaltyFeeInfo()
        public
        view
        override(BaseNFTExchange, INFT1155)
        returns (address recipient, uint8 permil)
    {
        return (_royaltyFeeRecipient, _royaltyFee);
    }

    function canTrade(address nft) public view override(BaseNFTExchange, IBaseNFTExchange) returns (bool) {
        return nft == address(this);
    }

    function _transfer(
        address,
        address from,
        address to,
        uint256 tokenId,
        uint256 amount
    ) internal override {
        _transfer(from, to, tokenId, amount);
        emit TransferSingle(msg.sender, from, to, tokenId, amount);
    }

    function setRoyaltyFeeRecipient(address royaltyFeeRecipient) public override onlyOwner {
        require(royaltyFeeRecipient != address(0), "SHOYU: INVALID_FEE_RECIPIENT");

        _royaltyFeeRecipient = royaltyFeeRecipient;
    }

    function setRoyaltyFee(uint8 royaltyFee) public override onlyOwner {
        require(royaltyFee <= INFTFactory(_factory).MAX_ROYALTY_FEE(), "SHOYU: INVALID_FEE");

        _royaltyFee = royaltyFee;
    }
}
