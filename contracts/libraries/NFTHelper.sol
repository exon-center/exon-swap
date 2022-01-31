// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "../interfaces/ITRC721Enumerable.sol";

// a library for performing various math operations

library NFTHelper { 
      
      function getUpliner(address nftToken, uint nftId) internal view returns(uint) {
          uint _upliner = ITRC721(nftToken).Upliners(nftId);
          return _upliner;
      }

      function getNFTAddress(address nftToken, uint _tokenId) internal view returns(address) {
        ITRC721 _nft = ITRC721(nftToken);
        return _nft.ownerOf(_tokenId);
    }

    function tokenByIndex(address nftToken, uint _index) internal view returns(uint) {
        ITRC721Enumerable _nft = ITRC721Enumerable(nftToken);
        return _nft.tokenByIndex(_index);
    }

    function balanceOf(address nftToken, address _address) internal view returns(uint) {
        ITRC721 _nft = ITRC721(nftToken);
        return _nft.balanceOf(_address);
    }

    function tokenOfOwnerByIndex(address nftToken, address _address, uint _index) internal view returns(uint) {
        ITRC721Enumerable _nft = ITRC721Enumerable(nftToken);
        return _nft.tokenOfOwnerByIndex(_address, _index);
    }

} 