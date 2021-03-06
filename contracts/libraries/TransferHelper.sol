// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

// helper methods for interacting with TRC20 tokens and sending TRX that do not consistently return true/false
library TransferHelper {
    function safeApprove(address token, address to, uint value) internal {
        // bytes4(keccak256(bytes('approve(address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0x095ea7b3, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), "TransferHelper: APPROVE_FAILED");
    }

    function safeTransfer(address token, address to, uint value) internal {
        // bytes4(keccak256(bytes("transfer(address,uint256)")));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0xa9059cbb, to, value));
        if ( token == 0xa614f803B6FD780986A42c78Ec9c7f77e6DeD13C) {
            require(success == true, "TransferHelper: USDT_TRANSFER_FAILED");
        } else {
            require(success && (data.length == 0 || abi.decode(data, (bool))), "TransferHelper: TRANSFER_FAILED");
        }
    }

    function safeTransferFrom(address token, address from, address to, uint value) internal {
        // bytes4(keccak256(bytes("transferFrom(address,address,uint256)")));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0x23b872dd, from, to, value));
        if ( token == 0xa614f803B6FD780986A42c78Ec9c7f77e6DeD13C) {
            require(success == true, "TransferHelper: USDT_TRANSFER_FAILED");
        } else {
        require(success && (data.length == 0 || abi.decode(data, (bool))), "TransferHelper: TRANSFER_FROM_FAILED");
        }
    }

    function safeTransferTRX(address to, uint value) internal {
        (bool success,) = to.call{value:value}(new bytes(0));
        require(success, "TransferHelper: TRX_TRANSFER_FAILED");
    }
}
