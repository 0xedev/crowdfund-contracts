// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./Launcher.sol";

contract Token is ERC20Burnable, Ownable {
    Launcher private _launcher;

    uint private constant MAX_SUPPLY = 1000000000 * (10 ** 18);

    mapping(string => string) _record;

    constructor() ERC20("", "") { }

    function init(address creator, string memory title, string memory ticker, string memory icon, uint launcherSupply) external {
        require(address(_launcher) == address(0), "Already initialized");
        require(launcherSupply <= MAX_SUPPLY, "Invalid launcher supply");

        _launcher = Launcher(msg.sender);

        _record["name"] = title;
        _record["symbol"] = ticker;
        _record["icon"] = icon;

        _mint(address(this), MAX_SUPPLY);
        _transfer(address(this), address(_launcher), launcherSupply);
        _transferOwnership(creator);
    }

    function preapprove(address protocol, uint amount) external onlyOwner {
        require(_launcher.isProtocol(protocol), "Unsupported Protocol");
        this.approve(protocol, amount);
    }

    function preapprove(address protocol) external onlyOwner {
        require(_launcher.isProtocol(protocol), "Unsupported Protocol");
        this.approve(protocol, type(uint256).max);
    }

    function renounceOwnership() public override onlyOwner {
        _launcher.updateOwner(owner(), address(0));
        _transferOwnership(address(0));
    }

    function transferOwnership(address newOwner) public override onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _launcher.updateOwner(owner(), newOwner);
        _transferOwnership(newOwner);
    }

    function setRecord(string memory key, string memory value) external onlyOwner {
        bytes32 keyHash = keccak256(abi.encodePacked(key));

        require(
            keyHash != keccak256(abi.encodePacked("name")) &&
            keyHash != keccak256(abi.encodePacked("symbol")) &&
            validKey(key),
            "Invalid key"
        );
        _record[key] = value;
    }

    function validKey(string memory str) public pure returns (bool) {
        bytes memory b = bytes(str); // Convert string to bytes
        if (b.length == 0) {
            return false;
        }
        for (uint i = 0; i < b.length; i++) {
            bytes1 char = b[i];
            if (char < 0x61 || char > 0x7A) { // Check if char is outside 'a' to 'z'
                return false;
            }
        }
        return true;
    }

    function name() public view override returns (string memory) {
        return getRecord("name");
    }

    function symbol() public view override returns (string memory) {
        return getRecord("symbol");
    }

    function getRecord(string memory key) public view returns (string memory) {
        return _record[key];
    }
}
