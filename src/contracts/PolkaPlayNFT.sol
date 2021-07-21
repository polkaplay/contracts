// SPDX-License-Identifier: MIT
pragma solidity 0.7.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract PolkaPlayNFT is ERC721 {
    /*
     * NFT representing Polo Posts
     */

    using SafeMath for uint256;
    using Address for address;

    enum Category { Image, Video, Audio, Gif }

    struct PoloArt {
        string author;
        string title;
        uint256 publishedAt;
        Category category;
    }
    //hold all arts
    PoloArt[] private poloArts;

    event Mint(uint256 index, address creator);

    constructor() ERC721("PolkaPlay NFT", "POLO") public {}

    function _mintPost(address owner, string memory author, string memory title, Category category, string memory tokenURI) internal returns (uint256) {
        PoloArt memory pArt = PoloArt({
            author: author,
            title: title,
            publishedAt: block.timestamp,
            category: category
        });
        poloArts.push(pArt);
        uint256 index = poloArts.length;
        _mint(msg.sender, index);
        _setTokenURI(index, tokenURI);
        emit Mint(index, msg.sender);

         //TODO: transfer to owner
        // addTokenTo(owner, index);
        // emit Transfer(address(0), owner, index);

        return index;
    }

    function getTotalArts() public view returns (uint) { return poloArts.length; }
    function getAuthor(uint256 index) public view returns (string memory) { return poloArts[index].author; }
    function getTitle(uint256 index) public view returns (string memory) { return poloArts[index].title; }
    function getCategory(uint256 index) public view returns (Category) { return poloArts[index].category; }
}