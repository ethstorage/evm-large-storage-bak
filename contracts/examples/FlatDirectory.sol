// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../W3RC3.sol";

contract FlatDirectory is W3RC3 {
    bytes public defaultFile = "";

    function resolveMode() external pure virtual returns (bytes32) {
        return "manual";
    }

    fallback(bytes calldata cdata) external returns (bytes memory)  {
        bytes memory content;
        if (cdata.length == 0) {
            // TODO: redirect to "/"?
            return bytes("");
        } else if (cdata[0] != 0x2f) {
            // Should not happen since manual mode will have prefix "/" like "/....."
            return bytes("incorrect path");
        }

        if (cdata.length == 1) {
            (content, ) = read(defaultFile);
        } else {
            (content, ) = read(cdata[1:]);
        }

        bytes memory returnData = abi.encode(content);
        return returnData;
    }

    function setDefault(bytes memory _defaultFile) public {
        require(msg.sender == owner, "must from owner");
        defaultFile = _defaultFile;
    }

    function refund() public {
        require(msg.sender == owner, "must from owner");
        payable(owner).transfer(address(this).balance);
    }

    function destruct() public {
        require(msg.sender == owner, "must from owner");
        selfdestruct(payable(owner));
    }
}
