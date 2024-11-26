// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC721Receiver } from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import { INonfungiblePositionManager } from "./INonfungiblePositionManager.sol";
import { IUniswapV3Factory } from "./IUniswapV3Factory.sol";
import { IUniswapV3Pool } from "./IUniswapV3Pool.sol";
import { ISwapRouter } from "./ISwapRouter.sol";

contract Locker is IERC721Receiver, Ownable {
    uint24 public constant FEE_TIER = 10000;
    int24 public constant INITIAL_TICK = -184200;
    int24 public constant TICK_SPACING_10000 = 200;
    int24 public constant MAX_TICK = 887200;

    address public WETH = 0x4200000000000000000000000000000000000006;

    INonfungiblePositionManager public UNISWAP_V3_POSITION_MANAGER = INonfungiblePositionManager(0x03a520b32C04BF3bEEf7BEb72E919cf822Ed34f1);
    ISwapRouter public SWAP_ROUTER = ISwapRouter(0x2626664c2603336E57B271c5C0b26F421741e481);
    IUniswapV3Factory public UNISWAP_V3_FACTORY = IUniswapV3Factory(0x33128a8fC17869897dcE68Ed026d694621f6FDfD);

    mapping(address => uint) public lpTokenIds;
    address private immutable _launcher;

    constructor() {
        _launcher = msg.sender;
        _transferOwnership(tx.origin);
    }

    function createAndFundLP(address token, uint amount) public payable {
        require(_launcher == msg.sender, "Not allowed");

        IERC20(token).transferFrom(msg.sender, address(this), amount);

        (address token0, address token1) = WETH < token ? (WETH, token) : (token, WETH);
        (uint amount0, uint amount1) = WETH < token ? (uint(0), amount) : (amount, uint(0));
        (int24 tickLower, int24 tickUpper) = WETH < token ? (-1 * MAX_TICK, -1 * INITIAL_TICK) : (INITIAL_TICK, MAX_TICK);
        int24 initialTick = WETH < token ? (-1 * INITIAL_TICK) : INITIAL_TICK;

        uint160 sqrtPriceX96 = _getSqrtRatioAtTick(initialTick);
        address pool = UNISWAP_V3_FACTORY.createPool(address(token), WETH, FEE_TIER);
        IUniswapV3Pool(pool).initialize(sqrtPriceX96);

        INonfungiblePositionManager.MintParams memory mintParams = INonfungiblePositionManager.MintParams({
            token0: token0,
            token1: token1,
            fee: FEE_TIER,
            tickLower: tickLower,
            tickUpper: tickUpper,
            amount0Desired: amount0,
            amount1Desired: amount1,
            amount0Min: 0,
            amount1Min: 0,
            recipient: address(this),
            deadline: block.timestamp
        });

        IERC20(token).approve(address(UNISWAP_V3_POSITION_MANAGER), amount);
        (uint lpTokenId,,,) = UNISWAP_V3_POSITION_MANAGER.mint(mintParams);

        lpTokenIds[token] = lpTokenId;

        if (msg.value > 0) {
            ISwapRouter.ExactInputSingleParams memory swapParams = ISwapRouter.ExactInputSingleParams({
                tokenIn: WETH,
                tokenOut: address(token),
                fee: FEE_TIER,
                recipient: msg.sender,
                amountIn: msg.value,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            });

            // Execute the swap
            SWAP_ROUTER.exactInputSingle{ value: msg.value }(swapParams);
        }
    }

    /// @notice Collects fees from the LP position
    /// @return amount0 The amount of token0 collected
    /// @return amount1 The amount of token1 collected
    function collectFees(address token, address recipient) onlyOwner external returns (uint256 amount0, uint256 amount1) {
        uint lpTokenId = lpTokenIds[token];

        require(lpTokenId != 0, "No LP position");

        INonfungiblePositionManager.CollectParams memory collectParams = INonfungiblePositionManager.CollectParams({
            tokenId: lpTokenId,
            recipient: recipient,
            amount0Max: type(uint128).max,
            amount1Max: type(uint128).max
        });

        (amount0, amount1) = UNISWAP_V3_POSITION_MANAGER.collect(collectParams);
    }

    /// @notice Allows contract to receive refund from Uniswap's position manager
    receive() external payable {}

    /// @notice Allows receiving of LP NFT on contract
    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure override returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    /// @notice Calculates sqrt(1.0001^tick) * 2^96
    /// @dev Throws if |tick| > max tick
    /// @param tick The input tick for the above formula
    /// @return sqrtPriceX96 A Fixed point Q64.96 number representing the sqrt of the ratio of the two assets (token1/token0)
    /// at the given tick
    function _getSqrtRatioAtTick(int24 tick) internal pure returns (uint160 sqrtPriceX96) {
        uint256 absTick = tick < 0 ? uint256(-int256(tick)) : uint256(int256(tick));
        // require(absTick <= uint256(MAX_TICK), 'T');

        uint256 ratio = absTick & 0x1 != 0 ? 0xfffcb933bd6fad37aa2d162d1a594001 : 0x100000000000000000000000000000000;
        if (absTick & 0x2 != 0) ratio = (ratio * 0xfff97272373d413259a46990580e213a) >> 128;
        if (absTick & 0x4 != 0) ratio = (ratio * 0xfff2e50f5f656932ef12357cf3c7fdcc) >> 128;
        if (absTick & 0x8 != 0) ratio = (ratio * 0xffe5caca7e10e4e61c3624eaa0941cd0) >> 128;
        if (absTick & 0x10 != 0) ratio = (ratio * 0xffcb9843d60f6159c9db58835c926644) >> 128;
        if (absTick & 0x20 != 0) ratio = (ratio * 0xff973b41fa98c081472e6896dfb254c0) >> 128;
        if (absTick & 0x40 != 0) ratio = (ratio * 0xff2ea16466c96a3843ec78b326b52861) >> 128;
        if (absTick & 0x80 != 0) ratio = (ratio * 0xfe5dee046a99a2a811c461f1969c3053) >> 128;
        if (absTick & 0x100 != 0) ratio = (ratio * 0xfcbe86c7900a88aedcffc83b479aa3a4) >> 128;
        if (absTick & 0x200 != 0) ratio = (ratio * 0xf987a7253ac413176f2b074cf7815e54) >> 128;
        if (absTick & 0x400 != 0) ratio = (ratio * 0xf3392b0822b70005940c7a398e4b70f3) >> 128;
        if (absTick & 0x800 != 0) ratio = (ratio * 0xe7159475a2c29b7443b29c7fa6e889d9) >> 128;
        if (absTick & 0x1000 != 0) ratio = (ratio * 0xd097f3bdfd2022b8845ad8f792aa5825) >> 128;
        if (absTick & 0x2000 != 0) ratio = (ratio * 0xa9f746462d870fdf8a65dc1f90e061e5) >> 128;
        if (absTick & 0x4000 != 0) ratio = (ratio * 0x70d869a156d2a1b890bb3df62baf32f7) >> 128;
        if (absTick & 0x8000 != 0) ratio = (ratio * 0x31be135f97d08fd981231505542fcfa6) >> 128;
        if (absTick & 0x10000 != 0) ratio = (ratio * 0x9aa508b5b7a84e1c677de54f3e99bc9) >> 128;
        if (absTick & 0x20000 != 0) ratio = (ratio * 0x5d6af8dedb81196699c329225ee604) >> 128;
        if (absTick & 0x40000 != 0) ratio = (ratio * 0x2216e584f5fa1ea926041bedfe98) >> 128;
        if (absTick & 0x80000 != 0) ratio = (ratio * 0x48a170391f7dc42444e8fa2) >> 128;

        if (tick > 0) ratio = type(uint256).max / ratio;

        // this divides by 1<<32 rounding up to go from a Q128.128 to a Q128.96.
        // we then downcast because we know the result always fits within 160 bits due to our tick input constraint
        // we round up in the division so getTickAtSqrtRatio of the output price is always consistent
        sqrtPriceX96 = uint160((ratio >> 32) + (ratio % (1 << 32) == 0 ? 0 : 1));
    }
}
