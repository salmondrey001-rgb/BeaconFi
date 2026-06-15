//SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract BeaconFiToken is ERC20, Ownable{
    constructor(address _owner) ERC20("BeaconFi", "BCON") 
    Ownable(_owner){}
    
    function mintReward(address to, uint256 amount) 
    external onlyOwner {
        _mint(to, amount);
    }

    function burn(uint256 amount) external{
        _burn(msg.sender, amount);
    }
}
