# Protection Protocol Smart Contract

A decentralized protection protocol built on the Stacks blockchain that enables users to create coverage plans, pay contributions, and submit assessments for financial protection.

## Overview

The Protection Protocol is a smart contract that provides a framework for decentralized insurance-like services. Users can create protection coverages, make regular contributions, and submit assessments when they need to claim their protection benefits. The protocol is managed by an administrator who processes assessments and maintains the system.

## Features

- **Coverage Creation**: Users can create customized protection plans with specified amounts and durations
- **Contribution Management**: Secure payment system for coverage contributions using STX tokens
- **Assessment Processing**: Streamlined process for submitting and processing protection claims
- **Administrative Controls**: Protocol admin can manage assessments and system settings
- **Transparent Tracking**: All transactions and coverage details are recorded on-chain

## Core Functions

### Coverage Management

#### `create-coverage(protection-amount, contribution-amount, duration)`
Creates a new protection coverage plan.
- **Parameters**: 
  - `protection-amount`: Maximum protection amount (in microSTX)
  - `contribution-amount`: Required contribution amount (in microSTX)
  - `duration`: Coverage duration in blocks
- **Returns**: Coverage ID

#### `pay-contribution(coverage-id)`
Makes a contribution payment for an active coverage.
- **Parameters**: `coverage-id` - ID of the coverage to pay for
- **Requirements**: Coverage must be active and not expired

### Assessment Processing

#### `submit-assessment(coverage-id, requested-amount, details)`
Submits a new assessment request for coverage benefits.
- **Parameters**:
  - `coverage-id`: ID of the coverage
  - `requested-amount`: Amount being claimed (in microSTX)
  - `details`: Description of the assessment (max 256 characters)
- **Requirements**: Coverage must be active, amount must not exceed protection limit

#### `process-assessment(assessment-id, coverage-id, approved)`
Processes a pending assessment (admin only).
- **Parameters**:
  - `assessment-id`: ID of the assessment
  - `coverage-id`: ID of the associated coverage
  - `approved`: Boolean indicating approval status
- **Authorization**: Only protocol admin can call this function

### Read-Only Functions

- `get-coverage(coverage-id)`: Retrieves coverage details
- `get-assessment(assessment-id)`: Retrieves assessment details
- `get-coverage-holder(coverage-id)`: Gets the holder of a coverage
- `is-coverage-enabled(coverage-id)`: Checks if coverage is active

## Error Codes

| Code | Error | Description |
|------|-------|-------------|
| 100 | ERR-UNAUTHORIZED-ACCESS | Caller lacks required permissions |
| 101 | ERR-COVERAGE-EXISTS | Coverage already exists |
| 102 | ERR-COVERAGE-NOT-FOUND | Coverage does not exist |
| 103 | ERR-INSUFFICIENT-CONTRIBUTION | Contribution amount too low |
| 104 | ERR-COVERAGE-EXPIRED | Coverage has expired |
| 105 | ERR-INVALID-ASSESSMENT | Invalid assessment request |
| 106 | ERR-ASSESSMENT-ALREADY-PROCESSED | Assessment already processed |

## Data Structures

### Coverage Map
Stores coverage information indexed by coverage ID and holder principal.

### Assessment Map
Stores assessment requests indexed by assessment ID and coverage ID.

## Usage Example

```clarity
;; Create a protection coverage
(contract-call? .protection-protocol create-coverage u1000000 u10000 u144) ;; ~1 day coverage

;; Pay contribution
(contract-call? .protection-protocol pay-contribution u1)

;; Submit assessment
(contract-call? .protection-protocol submit-assessment u1 u500000 "Medical emergency claim")

;; Check coverage status
(contract-call? .protection-protocol is-coverage-enabled u1)
```

## Administrative Functions

### `set-protocol-admin(new-admin)`
Transfers administrative control to a new principal (current admin only).

## Security Considerations

- Only coverage holders can pay contributions for their own coverages
- Only the protocol admin can process assessments
- All STX transfers are validated and secured
- Coverage expiration is enforced at the block level
- Assessment amounts are validated against coverage limits

## Deployment Notes

- The deployer automatically becomes the initial protocol admin
- All monetary values are in microSTX (1 STX = 1,000,000 microSTX)
- Block heights are used for time-based functionality
- Contract maintains total contribution and payout statistics

