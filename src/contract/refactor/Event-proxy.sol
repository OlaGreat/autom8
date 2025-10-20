// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import {LibStorage} from "../libraries/ELibStorage.sol";
contract VerifiableProxy {
    /// @dev EIP-1967 implementation slot: keccak256("eip1967.proxy.implementation") - 1
    bytes32 internal constant _IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    /// @dev EIP-1967 admin slot: keccak256("eip1967.proxy.admin") - 1
    bytes32 internal constant _ADMIN_SLOT = 0xb53127684a568b3173ae13b9f8a6016e0b4f0c9f3d6c0a6a3f7e4b2f5a8f6e5b;

    event Upgraded(address indexed implementation);
    event AdminChanged(address indexed previousAdmin, address indexed newAdmin);

    /// @param _implementation address of initial implementation contract
    /// @param _admin address of the proxy admin (who may upgrade)
    /// @param _data optional initialization calldata to delegatecall to implementation
    constructor(address _implementation, address _admin, bytes memory _data) payable {
        require(_implementation != address(0), "implementation is zero");
        require(_admin != address(0), "admin is zero");

        // store implementation and admin in EIP-1967 slots
        _setImplementation(_implementation);
        _setAdmin(_admin);

        // optional initialize call (delegatecall into implementation)
        if (_data.length > 0) {
            (bool ok, bytes memory res) = _implementation.delegatecall(_data);
            require(ok, _getRevertMsg(res));
        }
    }

    /* ---------------------------------------------------------------------
       Admin / Implementation getters & setters (use EIP-1967 storage slots)
       --------------------------------------------------------------------- */

    function implementation() public view returns (address impl) {
        bytes32 slot = _IMPLEMENTATION_SLOT;
        assembly { impl := sload(slot) }
    }

    function admin() public view returns (address adm) {
        bytes32 slot = _ADMIN_SLOT;
        assembly { adm := sload(slot) }
    }

    function _setImplementation(address newImplementation) internal {
        bytes32 slot = _IMPLEMENTATION_SLOT;
        assembly { sstore(slot, newImplementation) }
    }

    function _setAdmin(address newAdmin) internal {
        bytes32 slot = _ADMIN_SLOT;
        assembly { sstore(slot, newAdmin) }
    }

    /* ---------------------------------------------------------------------
       Admin-only upgrade functions
       --------------------------------------------------------------------- */

    modifier onlyAdmin() {
        require(msg.sender == admin(), "VerifiableProxy: caller is not admin");
        _;
    }

    /// @notice Upgrade to `newImplementation`
    function upgradeTo(address newImplementation) external onlyAdmin {
        require(newImplementation != address(0), "VerifiableProxy: zero implementation");
        _setImplementation(newImplementation);
        emit Upgraded(newImplementation);
    }

    /// @notice Upgrade and then call function on new implementation (useful for initialize)
    function upgradeToAndCall(address newImplementation, bytes calldata data) external payable onlyAdmin {
        require(newImplementation != address(0), "VerifiableProxy: zero implementation");
        _setImplementation(newImplementation);
        emit Upgraded(newImplementation);

        if (data.length > 0) {
            (bool ok, bytes memory res) = newImplementation.delegatecall(data);
            require(ok, _getRevertMsg(res));
        }
    }

    /// @notice Change admin
    function changeAdmin(address newAdmin) external onlyAdmin {
        require(newAdmin != address(0), "VerifiableProxy: zero admin");
        address old = admin();
        _setAdmin(newAdmin);
        emit AdminChanged(old, newAdmin);
    }

    /* ---------------------------------------------------------------------
       Low-level delegate logic (fallback / receive)
       --------------------------------------------------------------------- */

    // fallback () external payable {
    //     _delegate(implementation());
    // }

    fallback() external payable {
        address impl = implementation();
        require(impl != address(0), "Proxy: implmentation does not exist");
        // Execute external function from facet using delegatecall and return any value.
        assembly {
            // copy function selector and any arguments
            calldatacopy(0, 0, calldatasize())
            // execute function call using the facet
            let result := delegatecall(gas(), impl, 0, calldatasize(), 0, 0)
            // get any return value
            returndatacopy(0, 0, returndatasize())
            // return any return value or error back to the caller
            switch result
            case 0 {
                revert(0, returndatasize())
            }
            default {
                return(0, returndatasize())
            }
        }
    }

    // receive() external payable {
    //     _delegate(implementation());
    // }

    /// @dev Internal delegate helper (bubbles revert reasons)
    function _delegate(address impl) internal {
        assembly {
            // copy msg.data
            calldatacopy(0x0, 0x0, calldatasize())
            // delegatecall to implementation
            let result := delegatecall(gas(), impl, 0x0, calldatasize(), 0x0, 0)
            // copy returned data
            returndatacopy(0x0, 0x0, returndatasize())
            // revert or return
            switch result
            case 0 { revert(0x0, returndatasize()) }
            default { return(0x0, returndatasize()) }
        }
    }

    /// @dev Decode revert reason or return generic message
    function _getRevertMsg(bytes memory _returnData) internal pure returns (string memory) {
        // If there's no return data, the revert reason is unknown
        if (_returnData.length < 68) return "VerifiableProxy: delegatecall reverted";
        assembly {
            // slice the sighash
            _returnData := add(_returnData, 0x04)
        }
        return abi.decode(_returnData, (string));
    }
}
