// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

library V3Encode {
    
    function encodePath(address[] memory path,uint24[] memory fees) internal pure returns (bytes memory ret ){
    for (uint256 i = 0; i < path.length; i++) {
      bytes memory a = AddressTobytes(path[i]);
      bytes memory u = Uint24ToBytes(fees[i]);
      
      if( i == path.length -1){
        ret = abi.encodePacked(ret,a);
      }else{
        ret = abi.encodePacked(ret,a,u);
      }
    }
  }

  function AddressTobytes(address a) internal pure returns(bytes memory b){
    assembly{
      let m := mload(0x40)
      a := and(a,0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF)
      mstore(
        add(m,20),
        xor(0x140000000000000000000000000000000000000000,a)
      )
      mstore(0x40,add(m,52))
      b := m
    }
  }

  function Uint24ToBytes(uint24 a) internal pure returns(bytes memory){
    bytes3 b3 = bytes3(a);
    return abi.encodePacked(b3);
  }
}
