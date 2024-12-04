// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "./ILPWrapper.sol";
import "./Launcher.sol";
import "./Funder.sol";
import "./Locker.sol";
import "./Staker.sol";

contract Token is ERC20Burnable, Ownable {
    address private constant REFI = 0x7dbdBF103Bb03c6bdc584c0699AA1800566f0F84;
    address private constant WETH = 0x4200000000000000000000000000000000000006;

    uint public constant TOKEN_UNIT = 10**18;
    uint public constant SUPPLY_MAX =           1000000000 * TOKEN_UNIT;
    uint public constant SUPPLY_LOOSE_LP =       500000000 * TOKEN_UNIT;
    uint public constant SUPPLY_LP_INCENTIVES =  250000000 * TOKEN_UNIT;
    uint public constant SUPPLY_TIGHT_LP =       125000000 * TOKEN_UNIT;
    uint public constant SUPPLY_HIRING =         125000000 * TOKEN_UNIT;

    ILPWrapper private constant _lpWrapper = ILPWrapper(0x80D25C6615BA03757619aB427c2D995D8B695162);
    Launcher private immutable _launcher;
    address private immutable _funderTemplate;
    address private immutable _lockerTemplate;
    address private immutable _stakerTemplate;

    uint private _nonce;
    Funder private _funder;
    Locker private _locker;
    Staker private _staker;

    mapping(string => string) private _record;

    constructor() ERC20("", "") {
        _launcher = Launcher(msg.sender);
        _funderTemplate = address(new Funder());
        _lockerTemplate = address(new Locker());
        _stakerTemplate = address(new Staker());
    }

    // 0x4133c79e575591b6c380c233fffb47a13348de86, "TESTv2", "TESTv2", "https://www.solodev.com/file/13466e21-dd2c-11ec-b9ad-0eaef3759f5f/Hardhat-Logo-Icon.png"
    function init(address creator, string memory title, string memory ticker, string memory icon) external payable {
        require(address(_funder) == address(0), "Already initialized");

        _record["name"] = title;
        _record["symbol"] = ticker;
        _record["image"] = icon;

        address token = address(this);
        _transferOwnership(token);
        _mint(token, SUPPLY_MAX);

        // Create the Hiring Fund
        Funder funder = Funder(Clones.cloneDeterministic(address(_funderTemplate), bytes32(_nonce++)));
        Locker locker = Locker(payable(Clones.cloneDeterministic(address(_lockerTemplate), bytes32(_nonce++))));
        Staker staker = Staker(Clones.cloneDeterministic(address(_stakerTemplate), bytes32(_nonce++)));

        _approve(token, address(funder), SUPPLY_HIRING);
        _approve(token, address(locker), SUPPLY_LOOSE_LP + SUPPLY_TIGHT_LP);
        _approve(token, address(staker), SUPPLY_LP_INCENTIVES);

        funder.init(token, SUPPLY_HIRING, creator, ticker);
        locker.init{value: msg.value}(token, SUPPLY_LOOSE_LP + SUPPLY_TIGHT_LP);
        staker.init(token);

        address LPT = _lpWrapper.createLPToken(token, WETH, 10000);
        staker.createStakePool(LPT, token, SUPPLY_LP_INCENTIVES * 24 / 25, 730 days);
        staker.createStakePool(REFI, token, SUPPLY_LP_INCENTIVES * 1 / 25, 30 days);

        _funder = funder;
        _locker = locker;
        _staker = staker;

        _transferOwnership(creator);
    }

    function collectFees() external {
        (uint amount0, uint amount1) = _locker.collectFees();
        address token = address(this);
        (uint eth, uint tokens) = WETH < token ? (amount0, amount1) : (amount1, amount0);

        if (eth > 0) {
            IERC20(WETH).transfer(getLauncher(), eth / 10);
            IERC20(WETH).transfer(owner(), eth * 9 / 10);
        }
        if (tokens > 0) {
            _transfer(token, getFunder(), tokens);
        }
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

    function image() public view returns (string memory) {
        return getRecord("image");
    }

    function getRecord(string memory key) public view returns (string memory) {
        return _record[key];
    }

    function getLPWrapper() external pure returns (address) {
        return address(_lpWrapper);
    }

    function getLauncher() public view returns (address) {
        return address(_launcher);
    }

    function getFunder() public view returns (address) {
        return address(_funder);
    }

    function getLocker() external view returns (address) {
        return address(_locker);
    }

    function getStaker() external view returns (address) {
        return address(_staker);
    }
}
