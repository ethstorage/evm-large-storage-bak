// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../ERC5018ForBlob.sol";

contract FlatDirectoryForBlob is ERC5018ForBlob {
    bytes public defaultFile = "";

    function resolveMode() external pure virtual returns (bytes32) {
        return "manual";
    }

    fallback(bytes calldata pathinfo) external returns (bytes memory)  {
        bytes memory content;
        if (pathinfo.length == 0) {
            // TODO: redirect to "/"?
            return bytes("");
        } else if (pathinfo[0] != 0x2f) {
            // Should not happen since manual mode will have prefix "/" like "/....."
            return bytes("incorrect path");
        }

        if (pathinfo[pathinfo.length - 1] == 0x2f) {
            (content,) = read(bytes.concat(pathinfo[1 :], defaultFile));
        } else {
            (content,) = read(pathinfo[1 :]);
        }

        returnBytesInplace(content);
    }

    function returnBytesInplace(bytes memory content) internal pure {
        // equal to return abi.encode(content)
        uint256 size = content.length + 0x40; // pointer + size
        size = (size + 0x20 + 0x1f) & ~uint256(0x1f);
        assembly {
        // (DATA CORRUPTION): the caller method must be "external returns (bytes)", cannot be public!
            mstore(sub(content, 0x20), 0x20)
            return (sub(content, 0x20), size)
        }
    }

    function setDefault(bytes memory _defaultFile) public onlyOwner virtual {
        defaultFile = _defaultFile;
    }
}
