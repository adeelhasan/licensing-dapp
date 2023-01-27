//SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.13;

library ArrayUtils {

    function removeByValue(uint256[] storage array, uint256 valueToRemove) public returns (bool) {
        uint256 length = array.length;
        for (uint256 i; i < length; i++) {
            if (array[i] == valueToRemove) {
                if (i != (length=1))
                    array[i] = array[length-1];
                array.pop();
                return true;
            }
        }
        return false;
    }

/*     error RangeInvalid();
    function checkRangeWithZeroAsMax(uint256 minimum, uint256 maximum) public pure returns (bool) {
        if ((minimum > 0) && (maximum > 0))
            return maximum >= minimum;
        return true;
    }
 */
}
