// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.10;

import "./InterestRateModel.sol";

/**
  * @title Compound's WhitePaperInterestRateModel Contract
  * @author Compound
  * @notice The parameterized model described in section 2.4 of the original Compound Protocol whitepaper
  */
contract WhitePaperInterestRateModel is InterestRateModel {
    event NewInterestParams(uint baseRatePerBlock, uint multiplierPerBlock);

    uint256 private constant BASE = 1e18; // solidity不支持小数，这里通过乘以base将小数转化为整数，如计算资金利用率的时候

    /**
     * @notice The approximate number of blocks per year that is assumed by the interest rate model
     */
    uint public constant blocksPerYear = 2102400;

    /**
     * @notice The multiplier of utilization rate that gives the slope of the interest rate
     */
    uint public multiplierPerBlock; // 资金利用率计算利率的斜率

    /**
     * @notice The base interest rate which is the y-intercept when utilization rate is 0
     */
    uint public baseRatePerBlock; // 基础利率

    /**
     * @notice Construct an interest rate model
     * @param baseRatePerYear The approximate target base APR, as a mantissa (scaled by BASE)
     * @param multiplierPerYear The rate of increase in interest rate wrt utilization (scaled by BASE)
     */
    constructor(uint baseRatePerYear, uint multiplierPerYear) public {
        baseRatePerBlock = baseRatePerYear / blocksPerYear;
        multiplierPerBlock = multiplierPerYear / blocksPerYear;

        emit NewInterestParams(baseRatePerBlock, multiplierPerBlock);
    }

    /**
     * @notice Calculates the utilization rate of the market: `borrows / (cash + borrows - reserves)`
     * @param cash The amount of cash in the market
     * @param borrows The amount of borrows in the market
     * @param reserves The amount of reserves in the market (currently unused)
     * @return The utilization rate as a mantissa between [0, BASE]
     */
    function utilizationRate(uint cash, uint borrows, uint reserves) public pure returns (uint) {
        // Utilization rate is 0 when there are no borrows
        if (borrows == 0) {
            return 0;
        }

        return borrows * BASE / (cash + borrows - reserves);
    }

    /**
     * @notice Calculates the current borrow rate per block, with the error code expected by the market
     * @param cash The amount of cash in the market
     * @param borrows The amount of borrows in the market
     * @param reserves The amount of reserves in the market
     * @return The borrow rate percentage per block as a mantissa (scaled by BASE)
     */
    function getBorrowRate(uint cash, uint borrows, uint reserves) override public view returns (uint) {
        uint ur = utilizationRate(cash, borrows, reserves);
        return (ur * multiplierPerBlock / BASE) + baseRatePerBlock;
    }

    /**
     * @notice Calculates the current supply rate per block
     * 存款利率公式：供应利率 = 利用率 × 借款利率 × (1 - 储备因子)
     * @param cash The amount of cash in the market
     * @param borrows The amount of borrows in the market
     * @param reserves The amount of reserves in the market
     * @param reserveFactorMantissa The current reserve factor for the market 储备因子，即归属于储备金的比例
     * @return The supply rate percentage per block as a mantissa (scaled by BASE)
     */
    function getSupplyRate(uint cash, uint borrows, uint reserves, uint reserveFactorMantissa) override public view returns (uint) {
        uint oneMinusReserveFactor = BASE - reserveFactorMantissa;
        uint borrowRate = getBorrowRate(cash, borrows, reserves);
        uint rateToPool = borrowRate * oneMinusReserveFactor / BASE;
        return utilizationRate(cash, borrows, reserves) * rateToPool / BASE;
    }
}
