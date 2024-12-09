// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

interface ILauncher {
    function launch(address owner, string memory name, string memory ticker, string memory icon) external payable returns (address);
}
contract FarcasterLauncher is Ownable {
    using EnumerableSet for EnumerableSet.AddressSet;
    using ECDSA for bytes32;

    mapping(bytes20 => address) _castToken;
    EnumerableSet.AddressSet private _signers;

    uint public FEE = (1 ether) / 1000;
    uint public MIN_BUY = (1 ether) / 1000;
    ILauncher private constant _launcher = ILauncher(0x521aE994ebdEa950e220dD3e0eEB94843B2c8F26);

    function launch(
        string memory name, 
        string memory ticker, 
        string memory icon, 
        bytes20 castHash, 
        address[] memory addresses, 
        bytes memory signature
    ) external payable {
        require(msg.value >= getLaunchCost(), "Insufficient value sent");
        require(_castToken[castHash] == address(0), "Token already created");
        require(_signers.contains(_recoverSigner(addresses, signature)), "Invalid Signer");

        bool matched = false;
        for (uint i = 0; i < addresses.length; i++) {
            if (msg.sender == addresses[i]) {
                matched = true;
                break;
            }
        }
        require(matched, "Address not linked to profile");
    
        _castToken[castHash] = _launcher.launch{value: msg.value - FEE}(msg.sender, name, ticker, icon);
    }

    function _recoverSigner(address[] memory addresses, bytes memory signature) internal pure returns (address) {
        // Compute the hash of the ABI-encoded array
        bytes32 hash = keccak256(abi.encode(addresses));
        
        // Recover the signer address
        return hash.toEthSignedMessageHash().recover(signature);
    }

    function updateFee(uint newFee) external onlyOwner {
        FEE = newFee;
    }

    function updateMinBuy(uint newMinBuy) external onlyOwner {
        MIN_BUY = newMinBuy;
    }

    function addSigner(address signer) external onlyOwner {
        _signers.add(signer);
    }

    function removeSigner(address signer) external onlyOwner {
        _signers.remove(signer);
    }

    function claimFees() external onlyOwner {
        (bool success, ) = msg.sender.call{value: address(this).balance}("");
        require(success, "Claim failed");
    }

    function getSigners() external view returns (address[] memory) {
        return _signers.values();
    }

    function getCastToken(bytes20 castHash) external view returns (address) {
        return _castToken[castHash];
    }

    function getLaunchCost() public view returns (uint) {
        return FEE + MIN_BUY;
    }
}
