// SPDX-License-Identifier: MIT LICENSE
pragma solidity ^0.8.0;

import "./Ownable.sol";
import "./ERC20.sol";

contract TICKET is Ownable,ERC20 {
    // a mapping from an address to whether or not it can mint / burn
    mapping(address => bool) controllers;

    constructor() ERC20("TICKET", "TICKET") {}

    /**
     * mints $TICKET to a recipient
     * @param to the recipient of the $TICKET
     * @param amount the amount of $TICKET to mint
     */
    function mint(address to, uint256 amount) external {
        // require(controllers[msg.sender], "Only controllers can mint");
        _mint(to, amount);
    }

    /**
     * burns $TICKET from a holder
     * @param from the holder of the $TICKET
     * @param amount the amount of $TICKET to burn
     */
    function burn(address from, uint256 amount) external {
        require(controllers[msg.sender], "Only controllers can burn");
        _burn(from, amount);
    }

    /**
     * enables an address to mint / burn
     * @param controller the address to enable
     */
    function addController(address controller) external onlyOwner {
        controllers[controller] = true;
    }

    /**
     * disables an address from minting / burning
     * @param controller the address to disbale
     */
    function removeController(address controller) external onlyOwner {
        controllers[controller] = false;
    }

    // mintCost doesn't need to be changed this way.
    function decimals() public view virtual override returns (uint8) {
        return 9;
    }
}