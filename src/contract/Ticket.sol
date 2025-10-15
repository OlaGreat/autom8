// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Ticket is ERC721, Ownable {
    uint256 private _tokenIdCounter;

    struct TicketInfo {
        uint256 eventId;
        uint256 price;
        uint256 tierId;
        bool refunded;
    }

    mapping(uint256 => TicketInfo) public ticketInfo;

    event TicketMinted(address indexed to, uint256 indexed tokenId, uint256 eventId, uint256 price);

    constructor() ERC721("Event Ticket", "ETK") Ownable(msg.sender) {}

    function mint(address to) external onlyOwner returns (uint256) {
        uint256 tokenId = _tokenIdCounter;
        _tokenIdCounter++;
        _mint(to, tokenId);

        // Note: eventId and price should be passed or set separately
        // For now, defaulting to 0 - this should be updated when called from EventImplementation
        ticketInfo[tokenId] = TicketInfo(0, 0, 0, false);

        emit TicketMinted(to, tokenId, 0, 0);
        return tokenId;
    }

    function markTicketUsed(uint256 tokenId) external onlyOwner {
        require(_ownerOf(tokenId) != address(0), "Ticket does not exist");
        require(!ticketInfo[tokenId].refunded, "Ticket already refunded");

        // Add a used flag to the struct if needed, but for now, we can track usage externally
        // This function can be used to mark tickets as used at event entry
    }

    function mintWithDetails(address to, uint256 eventId, uint256 price, uint256 tierId) external onlyOwner returns (uint256) {
        uint256 tokenId = _tokenIdCounter;
        _tokenIdCounter++;
        _mint(to, tokenId);

        ticketInfo[tokenId] = TicketInfo(eventId, price, tierId, false);

        emit TicketMinted(to, tokenId, eventId, price);
        return tokenId;
    }

    function refundTicket(uint256 tokenId) external onlyOwner {
        require(_ownerOf(tokenId) != address(0), "Ticket does not exist");
        require(!ticketInfo[tokenId].refunded, "Ticket already refunded");

        ticketInfo[tokenId].refunded = true;
        _burn(tokenId);
    }

    function getTicketInfo(uint256 tokenId) external view returns (TicketInfo memory) {
        require(_ownerOf(tokenId) != address(0), "Ticket does not exist");
        return ticketInfo[tokenId];
    }
}
