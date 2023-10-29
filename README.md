# ConcertTicket Smart Contract

## Description
This Ethereum smart contract, named `ConcertTicket`, is designed to handle the management and operations related to concert tickets, merchandise sales, event creation, and donations to event organizers. 

## React Frontend

For a React-based frontend implementation of this smart contract, check out the [tixo_react repository](https://github.com/KeithChan02/tixo_react).

## Features

- Price conversion between USD and FLR (or other cryptocurrencies).
- Buy and refund tickets.
- Merchandise addition, display, and purchase.
- Donations to event organizers. (WIP)
- Event details management including ticket availability.
- Unique token generation for ticket holders.
- Organizer following system for users.

## Prerequisites

To interact with this contract, the following interfaces and libraries from FlareNetwork are required:

- `IFtsoRegistry` from "@flarenetwork/flare-periphery-contracts/coston2/ftso/userInterfaces/IFtsoRegistry.sol".
- `FlareContractsRegistryLibrary` from "@flarenetwork/flare-periphery-contracts/coston2/util-contracts/ContractRegistryLibrary.sol".

## Functions

### Event Management

- `setEventDetails`: Set the details of an event.
- `checkEventDetails`: View the details of an event based on ticket ID.
  
### Ticket Management

- `buyTicket`: Purchase a ticket for a specific event.
- `ticketsAvailable`: Check the number of available tickets for an event.
- `refundTicket`: Refund a ticket before the refund window closes.
- `generateUniqueToken`: Generate a unique token for a ticket holder.
- `isValidToken`: Validate a user's ticket token.
  
### Merchandise Management

- `addMerchandise`: Add a new merchandise item.
- `purchaseMerchandise`: Purchase a specified quantity of a merchandise item.
  
### Donation Management (WIP)

- `donateToOrganizer`: Donate an amount to the event organizer.
  
### Organizer Management

- `followOrganizer`: Follow a specific organizer.
- `unfollowOrganizer`: Unfollow a specific organizer.

## Events

- `UniqueTokenGenerated`: Emitted when a unique token for a ticket is generated.
- `MerchandiseAdded`: Emitted when a new merchandise item is added.
- `MerchandisePurchased`: Emitted when merchandise is purchased.
- `TicketPurchased`: Emitted when a ticket is purchased.
- `DonationMade`: Emitted when a donation is made to an event organizer.
- `FollowedOrganizer`: Emitted when an organizer is followed.
- `UnfollowedOrganizer`: Emitted when an organizer is unfollowed.
- `NewEventNotified`: Emitted when a new event is notified.

## Modifiers

- `onlyOwner`: Ensures only the contract owner can call the marked function.

## Deployment

To deploy this contract, specify the `eventStartTime` during the contract creation.

### Deployment Script

- [`concertDeploy.ts`](scripts/concertDeploy.ts): This is a TypeScript file that handles the deployment of the `ContractTicket` smart contract.

## Disclaimer

Ensure to conduct proper security audits before deploying this contract in a production environment.

## License

This project is licensed under the MIT License.
