// SPDX-License-Identifier: MIT

pragma solidity ^0.8.6;

import {IFtsoRegistry} from "@flarenetwork/flare-periphery-contracts/coston2/ftso/userInterfaces/IFtsoRegistry.sol";

import {FlareContractsRegistryLibrary} from "@flarenetwork/flare-periphery-contracts/coston2/util-contracts/ContractRegistryLibrary.sol";

contract ConcertTicket{
    address public owner;
    function _getTicketPriceInToken(
        string memory foreignTokenSymbol,
        uint256 _usd_price
    )
        public
        view
        returns (uint256 _price, uint256 _decimals)
    {
        IFtsoRegistry ftsoRegistry = FlareContractsRegistryLibrary
            .getFtsoRegistry();

        (uint256 __price, uint256 _timestamp, uint256 _decimals) = ftsoRegistry
            .getCurrentPriceWithDecimals(foreignTokenSymbol);
        _price = __price / _usd_price;
    }

     function getTicketPriceInFLR(
        uint256 _usd_price
    )
        public
        view
        returns (uint256 _price, uint256 _decimals)
    {
        (_price, _decimals) = _getTicketPriceInToken('testFLR', _usd_price);
    }

    struct Ticket {
        address owner;
        uint256 ticketId;
        uint256 originalPrice;
        uint256 purchaseTime;
    }

    struct EventDetails {
        string name;
        string location;
        string description;
        uint256 startTime;
        uint256 endTime;
        uint256 totalTickets;
        uint256 ticketsSold;
    }

    struct Merchandise {
        uint256 merchandiseId;
        string name;
        uint256 price;
        uint256 stock;
    }

    Merchandise[] public merchandiseItems;

    mapping(address => Ticket) public tickets;
    EventDetails public eventInfo;
    mapping(address => bytes32) public ticketUniqueTokens;
    mapping(uint256 => address) public ticketOwners;
    mapping(address => address[]) public organizerFollowers;
    mapping(address => mapping(address => bool)) private hasFollowed;

    uint256 public nextTicketId = 1;
    uint256 constant REFUND_WINDOW = 7 days;
    uint256 public eventStartTime;
    uint256 constant TICKET_DISPLAY_WINDOW = 15 minutes;

    event UniqueTokenGenerated(address indexed user, uint256 indexed ticketId, bytes32 token);
    event MerchandiseAdded(uint256 merchandiseId, string name, uint256 price, uint256 stock);
    event MerchandisePurchased(address indexed buyer, uint256 merchandiseId, uint256 quantity);
    event TicketPurchased(address indexed buyer, uint256 ticketId);
    event DonationMade(uint256 indexed eventId, address indexed donator, uint256 amount);
    event FollowedOrganizer(address indexed follower, address indexed organizer);
    event UnfollowedOrganizer(address indexed follower, address indexed organizer);
    event NewEventNotified(address indexed organizer, string name, uint startTime, uint endTime, string location, string description);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only the contract owner can call this function.");
        _;
    }

    constructor(EventDetails memory _event) {
        owner = msg.sender;
        eventInfo = _event;
    }

    function setEventDetails(
        uint256 _ticketId, 
        string memory _name, 
        string memory _location, 
        string memory _description,
        uint256 _startTime, 
        uint256 _endTime, 
        uint256 _totalTickets) public onlyOwner {

            EventDetails memory newEvent = EventDetails({
                name: _name,
                location: _location,
                description: _description,
                startTime: _startTime,
                endTime: _endTime,
                totalTickets: _totalTickets,
                ticketsSold: 0
            });

            emit NewEventNotified(msg.sender, _name, _startTime, _endTime, _location, _description);
    
            eventInfo = newEvent;
    }

    function checkEventDetails(uint256 _ticketId) public view returns (EventDetails memory) {
        return eventInfo;
    }

    function buyTicket(uint _ticketId, uint256 _price, string memory _cryptocurrencyUsed) public {
        require(tickets[msg.sender].owner == address(0), "User has already bought a ticket!");

        require(eventInfo.ticketsSold < eventInfo.totalTickets, "No more tickets available.");

        // Hom much FLR user must pay to buy a ticket using FLR assuming ticket price is 60 usd
        //(uint256 FLRpriceofticket, uint256 decimals) = getTicketPriceInFLR(60);

        Ticket memory newTicket = Ticket({
            owner: msg.sender,
            ticketId: nextTicketId,
            originalPrice: _price,
            purchaseTime: block.timestamp
        });

        tickets[msg.sender] = newTicket;
        emit TicketPurchased(msg.sender, nextTicketId);
        nextTicketId++;
    }

    function ticketsAvailable(uint256 _ticketId) public view returns (uint256) {
        return eventInfo.totalTickets - eventInfo.ticketsSold;
    }

    function refundTicket(uint256 _ticketId) public {
        Ticket storage ticketToRefund = tickets[msg.sender];

        require(ticketToRefund.ticketId == _ticketId, "You don't own this ticket.");

        require(block.timestamp <= eventInfo.startTime - REFUND_WINDOW, "Refund window has passed.");
        
        uint256 refundAmount = ticketToRefund.originalPrice;

        delete tickets[msg.sender];
        
        payable(msg.sender).transfer(refundAmount);
    }

    function pseudoRandomNumber(uint256 modulus) internal view returns (uint256) {
        return uint256(keccak256(abi.encodePacked(block.difficulty, block.timestamp, msg.sender))) % modulus;
    }

    function generateUniqueToken(uint256 ticketId) external returns (bytes32) {
        require(ticketOwners[ticketId] == msg.sender, "Not the ticket owner");

        uint256 eventTime = eventInfo.startTime;
        require(block.timestamp >= eventTime - TICKET_DISPLAY_WINDOW && block.timestamp < eventTime, 
        "Token can only be generated 15 minutes before the event start.");

        uint256 randomNumber = pseudoRandomNumber(1000000);
        bytes32 uniqueToken = keccak256(abi.encodePacked(randomNumber, ticketId, msg.sender));

        ticketUniqueTokens[msg.sender] = uniqueToken;

        emit UniqueTokenGenerated(msg.sender, ticketId, uniqueToken);

        return uniqueToken;
    }

    function isValidToken(address _user, bytes32 _token) external view returns (bool) {
        return ticketUniqueTokens[_user] == _token;
    }

    function addMerchandise(string memory _name, uint256 _price, uint256 _stock) external onlyOwner {
        Merchandise memory newMerchandise = Merchandise({
            merchandiseId: merchandiseItems.length,
            name: _name,
            price: _price,
            stock: _stock
        });
        merchandiseItems.push(newMerchandise);
        emit MerchandiseAdded(newMerchandise.merchandiseId, _name, _price, _stock);
    }

    function purchaseMerchandise(uint256 _merchandiseId, uint256 _quantity) external payable {
        require(_merchandiseId < merchandiseItems.length, "Invalid merchandise item");
        require(merchandiseItems[_merchandiseId].stock >= _quantity, "Not enough stock");
        require(msg.value == merchandiseItems[_merchandiseId].price * _quantity, "Incorrect Ether sent");

        // Deduct stock and update the merchandise list
        merchandiseItems[_merchandiseId].stock -= _quantity;

        // This will send Ether to the contract owner (could also be a treasury address or similar)
        payable(owner).transfer(msg.value);

        emit MerchandisePurchased(msg.sender, _merchandiseId, _quantity);
    }

    function followOrganizer(address _organizer) public {
        require(!hasFollowed[msg.sender][_organizer], "You're already following this organizer");

        organizerFollowers[_organizer].push(msg.sender);
        hasFollowed[msg.sender][_organizer] = true;

        emit FollowedOrganizer(msg.sender, _organizer);
    }

    function unfollowOrganizer(address _organizer) public {
        require(hasFollowed[msg.sender][_organizer], "You're not following this organizer");

        address[] storage followers = organizerFollowers[_organizer];
        for (uint256 i = 0; i < followers.length; i++) {
            if (followers[i] == msg.sender) {
                followers[i] = followers[followers.length - 1];
                followers.pop();
                break;
            }
        }
        hasFollowed[msg.sender][_organizer] = false;

        emit UnfollowedOrganizer(msg.sender, _organizer);
    }
}


