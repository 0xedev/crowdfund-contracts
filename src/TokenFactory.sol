// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "./ILPWrapper.sol";
import "./Funder.sol";
import "./Locker.sol";
import "./Staker.sol";
import "./Token.sol";

contract TokenFactory {
    address private constant REFI = 0x7dbdBF103Bb03c6bdc584c0699AA1800566f0F84;
    address private constant WETH = 0x4200000000000000000000000000000000000006;

    uint public constant TOKEN_UNIT = 10**18;
    uint public constant SUPPLY_MAX =           1000000000 * TOKEN_UNIT;
    uint public constant SUPPLY_LOOSE_LP =       500000000 * TOKEN_UNIT;
    uint public constant SUPPLY_LP_INCENTIVES =  250000000 * TOKEN_UNIT;
    uint public constant SUPPLY_TIGHT_LP =       125000000 * TOKEN_UNIT;
    uint public constant SUPPLY_HIRING =         125000000 * TOKEN_UNIT;

    ILPWrapper private constant _lpWrapper = ILPWrapper(0x80D25C6615BA03757619aB427c2D995D8B695162);
    address private immutable _launcher;
    address private immutable _funderTemplate;
    address private immutable _lockerTemplate;
    address private immutable _stakerTemplate;

    uint private _nonce;
    mapping(address => address) private _funders;
    mapping(address => address) private _lockers;
    mapping(address => address) private _stakers;

    constructor() {
        _launcher = msg.sender;
        _funderTemplate = address(new Funder());
        _lockerTemplate = address(new Locker());
        _stakerTemplate = address(new Staker());
    }

    function create(address creator, string memory title, string memory ticker, string memory icon) external payable returns (address) {
        require(msg.sender == _launcher, "Not Authorized");

        Token token = new Token();

        // Create the Hiring Fund
        Funder funder = Funder(Clones.cloneDeterministic(address(_funderTemplate), bytes32(_nonce++)));
        Locker locker = Locker(payable(Clones.cloneDeterministic(address(_lockerTemplate), bytes32(_nonce++))));
        Staker staker = Staker(Clones.cloneDeterministic(address(_stakerTemplate), bytes32(_nonce++)));

        token.approve(address(funder), SUPPLY_HIRING);
        token.approve(address(locker), SUPPLY_LOOSE_LP + SUPPLY_TIGHT_LP);
        token.approve(address(staker), SUPPLY_LP_INCENTIVES);

        funder.init(address(token), SUPPLY_HIRING, creator, ticker, address(staker), _launcher);
        locker.init{value: msg.value}(address(token), SUPPLY_LOOSE_LP + SUPPLY_TIGHT_LP);
        staker.init(address(token));

        address LPT = _lpWrapper.createLPToken(address(token), WETH, 10000);
        staker.createStakePool(LPT, address(this), SUPPLY_LP_INCENTIVES * 24 / 25, 730 days);
        staker.createStakePool(REFI, address(this), SUPPLY_LP_INCENTIVES * 1 / 25, 30 days);

        _funders[address(token)] = address(funder);
        _lockers[address(token)] = address(locker);
        _stakers[address(token)] = address(staker);

        token.init(msg.sender, creator, title, ticker, icon);

        return address(token);
    }

    function getLPWrapper() external pure returns (address) {
        return address(_lpWrapper);
    }

    function getLauncher() public view returns (address) {
        return _launcher;
    }

    function getFunder(address token) public view returns (address) {
        return _funders[token];
    }

    function getLocker(address token) external view returns (address) {
        return _lockers[token];
    }

    function getStaker(address token) external view returns (address) {
        return _stakers[token];
    }
}
