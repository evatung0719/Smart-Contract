// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract ShippingContract {
    // 定義貨物結構
    struct Cargo {
        uint256 id; // 貨物編號
        bool isOverseas; // 是否為海外貨物
        uint256 price; //貨物價錢
        uint256 InsurancePrice; //保險費用
        InsuranceType insurance; // 保險種類
        Status finalStatus; // 最終狀態
        uint256 date; //預計到貨日
        address buyerWallet; //買家錢包位址
    }

    // 保險種類
    enum InsuranceType {None, DelayInsurance, LossInsurance, DamageInsurance}

    // 貨物狀態
    enum Status {Normal, Delayed, Lost, Damaged, Delayed_Damaged}

    mapping(uint256 => Cargo) public cargos;
    mapping(address => uint256) public buyerWallets;
    mapping(address => uint256) public insuranceCompanyWallets;

    event CargoInfoUpdated(uint256 id, bool isOverseas, uint256 price);
    event InsuranceUpdated(uint256 id, InsuranceType insurance);
    event StatusUpdated(uint256 id, Status status);

    // 添加貨物基本資訊（包括賣家資訊和買家資訊）
    function addCargo(
        uint256 id,
        bool isOverseas,
        uint256 price,
        uint256 date
    ) external {
        cargos[id] = Cargo(
            id,
            isOverseas,
            price,
            0, //InsurancePrice,
            InsuranceType.None,
            Status.Normal,
            date,
            msg.sender // 記錄買家錢包位址
        );
        require(date > 20000000 && date < 21000000 && 
            (date % 10000) > 100 && (date % 10000) < 1300 &&
            (date % 100) > 0 && (date % 100) < 32);
        emit CargoInfoUpdated(id, isOverseas, 0);
    }

    // 更新保險資訊
    function updateInsurance(uint256 id, uint256[3] memory insuranceTypes) external {
        require(cargos[id].id != 0, "Cargo does not exist");
        require( cargos[id].price >= 250, "Cargo price cannot be insured" );
        require(insuranceTypes[0] != insuranceTypes[1] && insuranceTypes[1] != insuranceTypes[2] && insuranceTypes[2] != insuranceTypes[0], "Insurance cannot be purchased repeatedly");

        for (uint256 i = 0; i < insuranceTypes.length; i++) {
            uint256 insuranceTypeValue = insuranceTypes[i];
            require(insuranceTypeValue >= 0 && insuranceTypeValue <= 3, "Invalid insurance type");

            InsuranceType insurance = InsuranceType(insuranceTypeValue);

            if (insurance == InsuranceType.DelayInsurance) {
                uint256 insuranceFee = calculateDelayInsuranceFee(cargos[id].price, cargos[id].isOverseas);
                cargos[id].InsurancePrice += insuranceFee;
                //transferFromBuyerWallet(id);
            } else if (insurance == InsuranceType.LossInsurance) {
                uint256 insuranceFee = calculateLossInsuranceFee(cargos[id].price, cargos[id].isOverseas);
                cargos[id].InsurancePrice += insuranceFee;
                //transferFromBuyerWallet(id);
            } else if (insurance == InsuranceType.DamageInsurance) {
                uint256 insuranceFee = calculateDamageInsuranceFee(cargos[id].price);
                cargos[id].InsurancePrice += insuranceFee;
                //transferFromBuyerWallet(id);
            }

            cargos[id].insurance = insurance;
            emit InsuranceUpdated(id, insurance);
            emit CargoInfoUpdated(id, cargos[id].isOverseas, cargos[id].InsurancePrice);
        }
    }

    // 更新貨物狀態
    function updateStatus(uint256 id, Status status, uint256 checkDate) external {
        require(cargos[id].id != 0, "Cargo does not exist"); //0
        require(checkDate > 20000000 && checkDate < 21000000 && 
            (checkDate % 10000) > 100 && (checkDate % 10000) < 1300 &&
            (checkDate % 100) > 0 && (checkDate % 100) < 32);
        cargos[id].finalStatus = status;
        bool isDelayed = false;

        if (cargos[id].date < checkDate) {
            isDelayed = true;
        } else {
            isDelayed = false;
        }

        if (status == Status.Delayed) {
            if (cargos[id].insurance == InsuranceType.DelayInsurance) {
                if (isDelayed) {
                    cargos[id].finalStatus = status;
                } else {
                    cargos[id].finalStatus = Status.Normal;
                }
            }
        } else if (status == Status.Lost) {
            if (cargos[id].insurance == InsuranceType.LossInsurance) {
                cargos[id].finalStatus = status;
            }
        } else if (status == Status.Damaged) {
            if (cargos[id].insurance == InsuranceType.DamageInsurance) {
                cargos[id].finalStatus = status;
            }
        } else if (status == Status.Delayed_Damaged) {
            if (
                cargos[id].insurance == InsuranceType.DelayInsurance &&
                cargos[id].insurance == InsuranceType.DamageInsurance
            ) {
                if (isDelayed) {
                    cargos[id].finalStatus = status;
                } else {
                    cargos[id].finalStatus = Status.Damaged;
                }
            }
        } else {
            if (isDelayed) {
                cargos[id].finalStatus = Status.Delayed;
            } else {
                cargos[id].finalStatus = Status.Normal;
            }
        }
        emit StatusUpdated(id, cargos[id].finalStatus);
    }

    // 判斷包裹最終狀態是否符合保險賠償條件並計算賠償金額
    function checkAndCalculateCompensation(uint256 id, InsuranceType[3] memory insuranceTypes)
        external
        view
        returns (uint256)
    {
        require(cargos[id].id != 0, "Cargo does not exist");

        for (uint256 i = 0; i < insuranceTypes.length; i++) {
            InsuranceType insurance = insuranceTypes[i];
            if (cargos[id].finalStatus == Status.Delayed && insurance == InsuranceType.DelayInsurance) {
                if (cargos[id].isOverseas) {
                    return (cargos[id].price * 30) / 100;
                } else {
                    return (cargos[id].price * 16) / 100;
                }
            } else if (cargos[id].finalStatus == Status.Lost && insurance == InsuranceType.LossInsurance) {
                return cargos[id].price;
            } else if (cargos[id].finalStatus == Status.Damaged && insurance == InsuranceType.DamageInsurance) {
                return (cargos[id].price * 50) / 100;
            } else if (
                cargos[id].finalStatus == Status.Delayed_Damaged &&
                insurance == InsuranceType.DamageInsurance
            ) {
                if (cargos[id].isOverseas) {
                    return (cargos[id].price * 80) / 100;
                } else {
                    return (cargos[id].price * 66) / 100;
                }
            }
        }
        return 0;
    }

    // 計算龜速險費用
    function calculateDelayInsuranceFee(uint256 price, bool isOverseas) private pure returns (uint256) {
        if (isOverseas) {
            return (price * 15) / 100;
        } else {
            return (price * 8) / 100;
        }
    }

    // 計算遺失險費用
    function calculateLossInsuranceFee(uint256 price, bool isOverseas) private pure returns (uint256) {
        if (isOverseas) {
            return (price * 15) / 100;
        } else {
            return (price * 8) / 100;
        }
    }

    // 計算損毀險費用
    function calculateDamageInsuranceFee(uint256 price) private pure returns (uint256) {
        return (price * 15) / 100;
    }

    // 從買家錢包轉移金額到保險公司錢包
    function transferFromBuyerWallet(uint256 id) private {
        require(buyerWallets[cargos[id].buyerWallet] >= cargos[id].InsurancePrice, "Insufficient balance in buyer wallet");
        buyerWallets[cargos[id].buyerWallet] -= cargos[id].InsurancePrice;
        insuranceCompanyWallets[msg.sender] += cargos[id].InsurancePrice;
    }

    // 從保險公司錢包轉移賠償金額到買家錢包
    function transferFromInsuranceCompanyWallet(address buyerWallet, uint256 amount) private {
        require(insuranceCompanyWallets[msg.sender] >= amount, "Insufficient balance in insurance company wallet");
        insuranceCompanyWallets[msg.sender] -= amount;
        buyerWallets[buyerWallet] += amount;
    }
}
