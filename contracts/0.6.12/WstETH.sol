// SPDX-FileCopyrightText: 2021 Lido <info@lido.fi>

// SPDX-License-Identifier: GPL-3.0

/* See contracts/COMPILERS.md */
pragma solidity 0.6.12;

import "@openzeppelin/contracts/drafts/ERC20Permit.sol";
import "./interfaces/IStETH.sol";

// wstETHはstETHを他のDeFiで使用できるようにするためのもの
// wstETHの残高は送金時にのみ変化する
// stETHトークンを受け入れ、その見返りとしてwstETH(ERC20トークン)をミントする
// ユーザーは普通のETH送金によってこのコントラクトにETHを送って、見返りとしてwstETHを受け取ることができる
// 送金されたETHは自動的にLidoのsubmitメソッドに転送され、そこで自動的にETHをステーキングしてstETHとなり、それも自動的にWrapされる
contract WstETH is ERC20Permit {
    IStETH public stETH;

    // デプロイ時にstETHのアドレスを指定する
    constructor(IStETH _stETH)
        public
        ERC20Permit("Wrapped liquid staked Ether 2.0")
        ERC20("Wrapped liquid staked Ether 2.0", "wstETH")
    {
        stETH = _stETH;
    }

    /**
     * @notice Exchanges stETH to wstETH
     * @param _stETHAmount amount of stETH to wrap in exchange for wstETH
     * @dev Requirements:
     *  - `_stETHAmount` must be non-zero
     *  - msg.sender must approve at least `_stETHAmount` stETH to this
     *    contract.
     *  - msg.sender must have at least `_stETHAmount` of stETH.
     * User should first approve _stETHAmount to the WstETH contract
     * @return Amount of wstETH user receives after wrap
     */
    function wrap(uint256 _stETHAmount) external returns (uint256) {
        require(_stETHAmount > 0, "wstETH: can't wrap zero stETH");
        uint256 wstETHAmount = stETH.getSharesByPooledEth(_stETHAmount);
        // stETH量に基づいてwstETHをミントする
        _mint(msg.sender, wstETHAmount);
        stETH.transferFrom(msg.sender, address(this), _stETHAmount);
        return wstETHAmount;
    }

    // wstETHをアンラップしてstETHにするメソッド
    function unwrap(uint256 _wstETHAmount) external returns (uint256) {
        require(_wstETHAmount > 0, "wstETH: zero amount unwrap not allowed");
        // 指定されたwstETHと同等のstETHの量を取得
        uint256 stETHAmount = stETH.getPooledEthByShares(_wstETHAmount);
        // アンラップする量のwstETHをバーンする
        _burn(msg.sender, _wstETHAmount);
        // アンラップした分のstETHを送金する
        stETH.transfer(msg.sender, stETHAmount);
        return stETHAmount;
    }

    /**
    * @notice Shortcut to stake ETH and auto-wrap returned stETH
    */
    receive() external payable {
        uint256 shares = stETH.submit{value: msg.value}(address(0));
        _mint(msg.sender, shares);
    }

    /**
     * @notice Get amount of wstETH for a given amount of stETH
     * @param _stETHAmount amount of stETH
     * @return Amount of wstETH for a given stETH amount
     */
    function getWstETHByStETH(uint256 _stETHAmount) external view returns (uint256) {
        return stETH.getSharesByPooledEth(_stETHAmount);
    }

    /**
     * @notice Get amount of stETH for a given amount of wstETH
     * @param _wstETHAmount amount of wstETH
     * @return Amount of stETH for a given wstETH amount
     */
    function getStETHByWstETH(uint256 _wstETHAmount) external view returns (uint256) {
        return stETH.getPooledEthByShares(_wstETHAmount);
    }

    // 1 wstETHあたりのstETHの量
    function stEthPerToken() external view returns (uint256) {
        return stETH.getPooledEthByShares(1 ether);
    }

    // 1 stETHあたりのwstETHの量
    function tokensPerStEth() external view returns (uint256) {
        return stETH.getSharesByPooledEth(1 ether);
    }
}
