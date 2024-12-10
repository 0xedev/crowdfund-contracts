// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface ILauncher {
    function updateOwner(address oldOwner, address newOwner) external;
}

interface IFactory {
    function getFunder(address token) external view returns (address);
    function getLocker(address token) external view returns (address);
    function getStaker(address token) external view returns (address);
}

interface ILocker {
    function collect() external returns (uint256, uint256);
}

contract Token is ERC20Votes, Ownable {
    IERC20 private constant WETH = IERC20(0x4200000000000000000000000000000000000006);

    uint public constant TOKEN_UNIT = 10**18;
    uint public constant SUPPLY_MAX = 1000000000 * TOKEN_UNIT;

    ILauncher private _launcher;
    IFactory private _factory;

    mapping(string => string) private _record;

    constructor() ERC20("","") ERC20Permit("") {
        _mint(msg.sender, SUPPLY_MAX);
        _transferOwnership(msg.sender);
    }

    function init(address launcher, address creator, string memory title, string memory ticker, string memory icon) external {
        require(address(_launcher) == address(0), "Already initialized");

        _launcher = ILauncher(launcher);
        _factory = IFactory(msg.sender);

        _record["name"] = title;
        _record["symbol"] = ticker;
        _record["image"] = icon;

        _transferOwnership(creator);
    }

    function collect() public {
        uint balanceBefore = WETH.balanceOf(address(this));
        ILocker(getLocker()).collect();
        uint balanceAfter = WETH.balanceOf(address(this));
        uint eth = balanceAfter - balanceBefore;
        if (eth > 0) {
            if (owner() == address(0)) {
                WETH.transfer(getLauncher(), eth);
            } else {
                WETH.transfer(getLauncher(), eth / 10);
            }
        }
        uint tokens = balanceOf(address(this));
        if (tokens > 0) {
            _transfer(address(this), getFunder(), tokens);
        }
    }

    function claimFeesTo(uint quantity, address recipient) external onlyOwner {
        collect();
        WETH.transfer(recipient, quantity);
    }

    function claimFeesTo(address recipient) external onlyOwner {
        collect();
        uint quantity = WETH.balanceOf(address(this));
        if (quantity > 0) {
            WETH.transfer(recipient, quantity);
        }
    }

    function claimFees() external onlyOwner {
        collect();
        uint quantity = WETH.balanceOf(address(this));
        if (quantity > 0) {
            WETH.transfer(msg.sender, quantity);
        }
    }

    function renounceOwnership() public override onlyOwner {
        _launcher.updateOwner(owner(), address(0));
        _transferOwnership(address(0));
        uint balance = WETH.balanceOf(address(this));
        if (balance > 0) {
            WETH.transfer(getLauncher(), balance);
        }
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

    function image() public view returns (string memory) {
        return getRecord("image");
    }

    function getRecord(string memory key) public view returns (string memory) {
        return _record[key];
    }

    function getLauncher() public view returns (address) {
        return address(_launcher);
    }

    function getFunder() public view returns (address) {
        return _factory.getFunder(address(this));
    }

    function getLocker() public view returns (address) {
        return _factory.getLocker(address(this));
    }

    function getStaker() external view returns (address) {
        return _factory.getStaker(address(this));
    }
}
