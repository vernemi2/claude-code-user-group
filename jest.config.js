const { jestConfig } = require("@salesforce/sfdx-lwc-jest/config");

module.exports = {
  ...jestConfig,
  modulePathIgnorePatterns: ["<rootDir>/.localdevserver"],
  moduleNameMapper: {
    ...jestConfig.moduleNameMapper,
    "^c/testUtils$": "<rootDir>/jest-utils/testUtils/testUtils"
  }
};
