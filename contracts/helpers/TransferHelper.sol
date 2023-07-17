// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

// helper methods for interacting with TRC20 tokens  that do not consistently return true/false
library TransferHelper {
    //TODO: Replace in deloy script
    // nile:0xECa9bC828A3005B9a3b909f2cc5c2a54794DE05F  mainnet:0xa614f803B6FD780986A42c78Ec9c7f77e6DeD13C
    // address constant USDTAddr = 0xECa9bC828A3005B9a3b909f2cc5c2a54794DE05F;
    address constant USDTAddr = 0xa614f803B6FD780986A42c78Ec9c7f77e6DeD13C;
    function safeApprove(address token, address to, uint value) internal returns (bool){
        // bytes4(keccak256(bytes('approve(address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0x095ea7b3, to, value));
        return (success && (data.length == 0 || abi.decode(data, (bool))));
    }

    function safeTransfer(address token, address to, uint value) internal returns (bool){
        // bytes4(keccak256(bytes('transfer(address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0xa9059cbb, to, value));
        if (token == USDTAddr) {
            return success;
        }
        return (success && (data.length == 0 || abi.decode(data, (bool))));
    }

    function safeTransferFrom(address token, address from, address to, uint value) internal returns (bool){
        // bytes4(keccak256(bytes('transferFrom(address,address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0x23b872dd, from, to, value));
        return (success && (data.length == 0 || abi.decode(data, (bool))));
    }

    function safeTransferETH(address to, uint value) internal {
        (bool success,) = to.call.value(value)(new bytes(0));
        //(bool success,)  = to.call{value:value}(new bytes(0));
        require(success, 'TransferHelper: ETH_TRANSFER_FAILED');
    }

    function executeTransaction(address target, uint value, string memory signature, bytes memory data) internal returns (bool success, bytes memory returnData) {
        bytes memory callData;

        if (bytes(signature).length == 0) {
            callData = data;
        } else {
            callData = abi.encodePacked(bytes4(keccak256(bytes(signature))), data);
        }
        (success, returnData) = target.call.value(value)(callData);
    }
}
