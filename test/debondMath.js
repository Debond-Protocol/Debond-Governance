const DebondMath = artifacts.require("DebondMath");

const chai = require("chai");
const chaiAsPromised = require('chai-as-promised');

chai.use(chaiAsPromised);
const expect = chai.expect; 

contract("Debond Maths", async (accounts) => {
    beforeEach(async () => {
        math = await DebondMath.new();
    });

    it("Check the contract has been deployed", async () => {
        expect(math.address).not.to.equal("");
    });

    it("Check the sigmoid function", async () => {
        let s1 = await math.sigmoid(x1, c1);
        let s2 = await sigmoid(c2, x2);

        expect(
            (
                Number(
                    s1.toString()
                ) / 10**18
            ).toFixed(15)
        ).to.equal(
            s2.toFixed(15)
        );
    });

    it("Check multiple inputs of sigmoid function", async () => {
        await loadX1();
        await loadX2();

        for (let i = 0; i < tabX1.length; i++) {
            let s1 = await math.sigmoid(tabX1[i], c1);
            let s2 = await sigmoid(c2, tabX2[i]);
            
            expect(Math.trunc(Number(s1.toString()) / 10**4))
                .to.equal(Math.trunc(s2*10**14));
        }
    });

    it("Check floating interest rate", async () => {
        let floatingRate1 = await math.floatingInterestRate(fixRateBond1, floatingRateBond1, benchmarkIR1);
        let floatingRate2 = await floatingInterestRate(fixRateBond2, floatingRateBond2, benchmarkIR2);

        expect(
            (
                Number(
                    floatingRate1.toString()
                ) / 10**18
            ).toFixed(15)
        ).to.equal(
            floatingRate2.toFixed(15)
        );
    });

    it("Check fixed interest rate", async () => {
        let fixRate1 = await math.fixedInterestRate(fixRateBond1, floatingRateBond1, benchmarkIR1);
        let fixRate2 = await fixInterestRate(fixRateBond2, floatingRateBond2, benchmarkIR2);

        expect(
            (
                Number(
                    fixRate1.toString()
                ) / 10**18
            ).toFixed(15)
        ).to.equal(
            fixRate2.toFixed(15)
        );
        
    });

    it("Check floating interest rate with multiple inputs", async () => {
        await loadTabFixedRate1();
        await loadTabFixedRate2();
        await loadTabFloatingRate1();
        await loadTabFloatingRate2();
        await loadBenchmark1();
        await loadBenchmark2();

        for (let i = 0; i < tabFloatRate1.length; i++) {
            let s1 = await math.floatingInterestRate(
                tabFixedRate1[i],
                tabFloatRate1[i],
                tabBenchmark1[i]
            );

            let s2 = await floatingInterestRate(
                tabFixedRate2[i],
                tabFloatRate2[i],
                tabBenchmark2[i]
            );

            expect(
                (
                    Number(
                        s1.toString()
                    ) / 10**18
                ).toFixed(13)
            ).to.equal(
                s2.toFixed(13)
            );
        }
    });

    it("Check the interest rate for a given duration", async () => {
        let rate1 = await math.calculateInterestRate(
            duration1,
            interestRate1
        );

        let rate2 = await calculateInterestRate(
            duration2,
            interestRate2
        );

        expect(rate2)
        .to.equal(
            Number(rate1.toString()) / 10**18
        );
    });

    it("Check the interest earned for a given duration", async () => {
        let interest1 = await math.estimateInterestEarned(
            amount1,
            duration1,
            interestRate1
        );

        let interest2 = await estimateInterestEarned(
            amount2,
            duration2,
            interestRate2
        );

        expect(interest2)
        .to.equal(
            Number(interest1.toString()) / 10**18
        );
    });

    it("Check the interest rate for multiplme inputs", async () => {
        await loadDuration1();
        await loadDuration2();

        for (let i = 0; i < tabDuration1.length; i++) {
            let rate1 = await math.calculateInterestRate(
                tabDuration1[i],
                interestRate1
            );

            let rate2 = await calculateInterestRate(
                tabDuration2[i],
                interestRate2
            );
            
            expect(Math.trunc(Number(rate1.toString()) / 10**4))
                .to.equal(Math.trunc(rate2 * 10**14));
        }
    });

    it("Check the interest earned for multiple inputs", async () => {
        await loadDuration1();
        await loadDuration2();

        for (let i = 0; i < tabDuration1.length; i++) {
            let rate1 = await math.estimateInterestEarned(
                amount1,
                tabDuration1[i],
                interestRate1
            );

            let rate2 = await estimateInterestEarned(
                amount2,
                tabDuration2[i],
                interestRate2
            );
            
            expect(Math.trunc(Number(rate1.toString()) / 10**6))
                .to.equal(Math.trunc(rate2 * 10**12));
        }
    });
})


/*****************************************************************
*                       Debond Math functions
/****************************************************************/

// Sigmoid function
async function sigmoid(c, x) {
    let num = 2**(-1 / ((1-c) * x));
    let den = 2**(-1 / ((1 - c) * x)) + 2**(-1 / ((1 - x) * c));
  
    return num / den;
}

// floating interest rate
async function floatingInterestRate(_fixRateBond, _floatingRateBond, _benchmarkIR) {
    let x = _fixRateBond / (_fixRateBond + _floatingRateBond);
    let c = 0.2;
    let sig = await sigmoid(c, x);

    return 2 * _benchmarkIR * sig;
}

// fixed interest rate
async function fixInterestRate(_fixRateBond, _floatingRateBond, _benchmarkIR) {
    let floatingRate = await floatingInterestRate(_fixRateBond, _floatingRateBond, _benchmarkIR);

    return 2 * _benchmarkIR - floatingRate;
}

// interest rate for a given duration (the rater is for APR) - from staking dGoV
async function calculateInterestRate(_duration, _interestRate) {
    let interest = _interestRate * _duration / NUMBER_OF_SECONDS_IN_YEAR;

    return interest;
}

// interest earned for a given duration - from staking dGoV
async function estimateInterestEarned(_amount, _duration, _interestRate) {
    let rate = await calculateInterestRate(_duration, _interestRate);
    let interest = _amount * rate;

    return interest;
}


/*****************************************************************
*                   Data and DataData Generation
/****************************************************************/
let math;

let x1 = 500000000000000000n;
let c1 = 600000000000000000n;

let x2 = 0.5;
let c2 = 0.6;

let fixRateBond1 = 300000000000000000n;
let floatingRateBond1 = 500000000000000000n;
let benchmarkIR1 = 400000000000000000n;

let fixRateBond2 = 0.3;
let floatingRateBond2 = 0.5;
let benchmarkIR2 = (fixRateBond2 + floatingRateBond2) / 2;

let duration1 = 63072000n;
let interestRate1 = 10000000000000000000n;
let amount1 = 134000000000000000000n;

let NUMBER_OF_SECONDS_IN_YEAR = 31536000;
let duration2 = 63072000;
let interestRate2 = 10;
let amount2 = 134;

let tabX1 = [];
let tabX2 = [];
let tabFixedRate1 = [];
let tabFloatRate1 = [];
let tabBenchmark1 = [];
let tabFixedRate2 = [];
let tabFloatRate2 = [];
let tabBenchmark2 = [];

let tabDuration1 = [];
let tabDuration2 = [];

async function loadX1() {
    let tmp = 0;

    for (let i = 0; i < 19; i++) {
        tmp = tmp + 0.05;
    
        tabX1.push(Number(tmp.toFixed(2)) * 10**18 + '');
    }
}

async function loadX2() {
    let tmp = 0;

    for (let i = 0; i < 19; i++) {
        tmp = tmp + 0.05;

        tabX2.push(Number(tmp.toFixed(2)));
    }
}

async function loadTabFixedRate1() {
    let tmp = 0;

    for (let i = 0; i < 19; i++) {
        tmp = tmp + 0.5;
    
        tabFixedRate1.push(Number(tmp.toFixed(2)) * 10**18 + '');
    }
}

async function loadTabFloatingRate1() {
    let tmp = 0;

    for (let i = 0; i < 19; i++) {
        tmp = tmp + 0.3;
    
        tabFloatRate1.push(Number(tmp.toFixed(2)) * 10**18 + '');
    }
}

async function loadTabFixedRate2() {
    let tmp = 0;

    for (let i = 0; i < 19; i++) {
        tmp = tmp + 0.5;

        tabFixedRate2.push(Number(tmp.toFixed(3)));
    }
}

async function loadTabFloatingRate2() {
    let tmp = 0;

    for (let i = 0; i < 19; i++) {
        tmp = tmp + 0.3;

        tabFloatRate2.push(Number(tmp.toFixed(3)));
    }
}

async function loadBenchmark1() {
    for (let i = 0; i < 19; i++) {
        tabBenchmark1.push(
            (
                Number(tabFloatRate1[i]) + Number(tabFixedRate1[i])
            ) / 2 + ''
        );
    }
}

async function loadBenchmark2() {
    for (let i = 0; i < 19; i++) {
        tabBenchmark2.push(
            (
                Number(tabFloatRate2[i]) + Number(tabFixedRate2[i])
            ) / 2
        );
    }
}

async function loadDuration1() {
    let tmp = 0;

    for (let i = 0; i < 49; i++) {
        tmp = tmp + 136720;

        tabDuration1.push(tmp + '');
    }
}

async function loadDuration2() {
    let tmp = 0;

    for (let i = 0; i < 49; i++) {
        tmp = tmp + 136720;

        tabDuration2.push(tmp);
    }
}