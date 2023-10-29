// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import { IFtsoManager } from "@flarenetwork/flare-periphery-contracts/flare/ftso/userInterfaces/IFtsoManager.sol";
import { IPriceSubmitter } from "@flarenetwork/flare-periphery-contracts/flare/ftso/userInterfaces/IPriceSubmitter.sol";
import { IFlareContractRegistry } from "@flarenetwork/flare-periphery-contracts/flare/util-contracts/userInterfaces/IFlareContractRegistry.sol";

address constant contractRegistryAddress = 0xaD67FE66660Fb8dFE9d6b1b4240d8650e30F6019;

/* 
Random numbers are provided by PriceSubmitter, accessible by getRandomProvider. It stores random numbers in cyclic memory,
which means that after some time has passed, data get overwritten with values for newer epochs. To determine if value is
still stored for an epoch, you can use isValidRandomEpoch(epochId).

Epochs are 3 minutes long and the first 1.5 minute is still used to calculate random number for that epoch, so it
is not safe to access. This is also checked by isValidRandomEpoch. To get the latest epoch with calculated random 
you can use getLastRevealedEpoch(). Current epoch can be accessed by getCurrentEpoch(). You can get the time (in seconds)
until an epoch is safe to use by timeUntilRevealed(epochId). For past epochs it returns 0 and does NOT check if the data
is still stored.

TODO after getRandomWithQuality is done rewrite this
PriceSubmitters may not reveal their submitted random, which decreases its reliability. In that case random is not safe.
getRandomWithQuality(epoch) returns (randomNUmber, valid, safe). To get the latest safe epoch, use getLatestGoodEpoch().
If you need a safe random for an epoch, you can get the next one using getNextGoodRandom(epoch),
which will give you a randomNumber and the epoch of that number.

Use getRandom(epochId) to get random for an epoch. It returns a pair of (uint256 randomNumber, bool valid). Valid is the
same value you get when calling isValidRandomEpoch(epochId). Do not use randomNumber if valid is false.
*/

contract Random {
    uint256 constant public bufferSize = 50;
    bytes32 constant private ftsoManagerHash = keccak256(abi.encode("FtsoManager"));
    bytes32 constant private priceSubmitterHash = keccak256(abi.encode("PriceSubmitter"));
    IFlareContractRegistry constant private contractRegistry = IFlareContractRegistry(contractRegistryAddress);

    struct RandomValue {
        uint256 randomNumber;
        bool valid;
    }

    function getFtsoManager() public view virtual returns (IFtsoManager ftsoManager) {
        ftsoManager = IFtsoManager(contractRegistry.getContractAddressByHash(ftsoManagerHash));
    }

    function getRandomProvider() public view virtual returns (IPriceSubmitter randomNumberSubmitter) {
        randomNumberSubmitter = IPriceSubmitter(contractRegistry.getContractAddressByHash(priceSubmitterHash));
    }

    function isValidRandomEpoch(uint256 epochId) public view returns (bool) {
        /*
            Returns true if revealing time for the given epoch has already ended and the epoch is not too old
            for data to be overwritten.
        */
        return getLastRevealedEpoch() >= epochId && getCurrentEpoch() - epochId < bufferSize;
    }

    function getRandom(uint256 epochId) public view returns (uint256 randomNumber, bool valid) {
        /*
            Returns a pair of the random number for the given epoch and validity.
            Validity is determined using isValidRandomEpoch.
        */
        randomNumber = getRandomProvider().getRandom(epochId);
        valid = isValidRandomEpoch(epochId);
    }

    function getRandoms(uint256[] memory epochIds) public view returns (RandomValue[] memory randoms) {
        /* List view version of getRandom. */
        randoms = new RandomValue[](epochIds.length);
        for (uint256 i = 0; i < epochIds.length; i++) {
            (randoms[i].randomNumber, randoms[i].valid) = getRandom(epochIds[i]);
        }
    }

    function getCurrentEpoch() public view returns (uint256 epochNow) {
        /*
            Returns PriceSubmitter's/FTSOManager's epochId used to access random values. 
        */
        (epochNow, , , , ) = getFtsoManager().getCurrentPriceEpochData();
    }

    function timeUntilRevealed(uint256 epochId) public view returns (uint256 time) {
        /*
            Returns time in secunds until the random for the given epoch is decided.
            For past epochs it returns 0. It does NOT check if the data is still avaiable.
        */
        uint256 lastRevealed = getLastRevealedEpoch();
        if (epochId <= lastRevealed) {
            return 0;
        }

        IFtsoManager ftsoManager = getFtsoManager();
        (
            uint256 epochNow, 
            , 
            , 
            uint256 revealEndTimestamp,
            uint256 currentTimestamp
        ) = ftsoManager.getCurrentPriceEpochData();

        (, uint256 priceEpochDurationSeconds, ) = ftsoManager.getPriceEpochConfiguration();

        if (epochId >= epochNow) {
            return (epochId - epochNow) * priceEpochDurationSeconds + revealEndTimestamp - currentTimestamp;
        } else {
            return revealEndTimestamp - (epochNow - epochId) * priceEpochDurationSeconds - currentTimestamp;
        }
    }

    function getLastRevealedEpoch() public view returns (uint256 epoch) {
        /*
            Returns the id of the newest epoch with decided random value.
        */
        IFtsoManager ftsoManager = getFtsoManager();
        (
            uint256 epochNow, 
            , 
            , 
            uint256 revealEndTimestamp,
            uint256 currentTimestamp
        ) = ftsoManager.getCurrentPriceEpochData();

        (, uint256 priceEpochDurationSeconds, ) = ftsoManager.getPriceEpochConfiguration();

        epoch = epochNow - 1;
        if (revealEndTimestamp - priceEpochDurationSeconds >= currentTimestamp) {
            epoch -= 1;
        }
    }

    function getRandomWithQuality(uint256 epochId) public view returns (uint256 randomNumber, bool valid, bool safe) {
        /* 
            Same as getRandom, with additional safe return value. Safe tells whether or not the randomNumber
            can be trusted, ie. if somebody could potentially manipulate it.
        */
        // TODO
        (randomNumber, valid) = getRandom(epochId);
        safe = true;
    }

    function getLastGoodEpoch() public view returns (uint256 epochId, uint256 epochsSkipped) {
        /* 
            Returns the last epoch with safe random and the number of newer epochs with
            unsafe random. If no safe epochs are found among the latest valid epochs, it returns (0, lastRevealed).
        */
       // TODO after getRandomWithQuality is done, rewrite / check this
        uint256 lastRevealed = getLastRevealedEpoch();
        epochId = lastRevealed;
        (uint256 randomNumber, bool valid, bool safe) = getRandomWithQuality(epochId);
        while (!safe && valid) {
            epochId -= 1;
            (randomNumber, valid, safe) = getRandomWithQuality(epochId);
        }
        if (!valid) {
            epochId = 0;
        }
        epochsSkipped = lastRevealed - epochId;
    }

    function getNextGoodRandom(uint256 epochId) public view returns (uint256 randomNumber, uint256 epoch) {
        /* 
            Returns the next (randomNumber, epoch) that is safe and valid and happened after given epochId.
            If no safe epochs exist it returns (0, 0). The argument epochId must be a valid
        */
       // TODO after getRandomWithQuality is done, rewrite / check this
        if (!isValidRandomEpoch(epochId)) return (0, 0);

        epoch = epochId;
        bool valid; 
        bool safe;
        (randomNumber, valid, safe) = getRandomWithQuality(epoch);
        while (!safe && valid) {
            epochId += 1;
            (randomNumber, valid, safe) = getRandomWithQuality(epochId);
        }
        
        if (!valid) return (0, 0);
    }
}