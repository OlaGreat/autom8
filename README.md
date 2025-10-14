#  Decentralized Event Ticketing Platform (Smart Contract Architecture)

This repository contains the **smart contract architecture** for a decentralized event ticketing platform.  
It uses a **Factory + Proxy (Upgradeable)** pattern to deploy and manage on-chain events with built-in **sponsorship funding**, **ticketing**, and **automated payroll disbursement** for workers.

---

##  Smart Contract Overview

### **Core Concept**
Each event deployed is its own **upgradeable proxy contract** with isolated state and logic.  
Sponsors, event owners, and workers interact transparently with the event instance, and all balances remain publicly viewable on-chain.

---

## ⚙️ Architecture Summary

| Contract | Responsibility |
|-----------|----------------|
| **EventFactory** | Deploys new event contracts using the upgradeable proxy pattern |
| **EventProxy** | Proxy contract that delegates calls to the event implementation |
| **EventImplementation** | Core logic for event funding, ticketing, sponsorship, and revenue distribution |
| **SponsorVault** | Handles sponsor deposits and calculates proportional revenue share |
| **Payroll** | Manages and disburses worker payments automatically post-event |
| **Ticketing** | Handles ticket minting, purchase, and refunds (ERC721/ERC1155 compatible) |

---

## 🧩 Smart Contract Flow

1. **EventFactory**
   - Creates new event instances using proxies.
   - Maps each event owner to their deployed contract.
   - Calls the `initialize()` function on each new proxy after deployment.

2. **EventImplementation**
   - Handles main logic: sponsor deposits, funding goals, ticket sales, and revenue tracking.
   - Prevents further sponsor deposits once the funding goal is met.
   - Integrates with `SponsorVault` for deposits and payouts.
   - Triggers payroll disbursement and sponsor distribution when the event ends.

3. **SponsorVault**
   - Maintains internal accounting for sponsor contributions.
   - Calculates each sponsor’s percentage of total deposits.
   - Distributes event revenue proportionally after event completion.

4. **Payroll**
   - Event owners can register workers and their payment amounts.
   - Disburses payments automatically after event completion.
   - Uses pull or automated payment model for safety.

5. **Ticketing**
   - Mints event tickets (ERC721 or ERC1155 standard).
   - Manages ticket sales, transfers, and revenue tracking.
   - Revenue automatically links to event balance for post-event distribution.

---

## 🧭 Upgradeable Architecture

This project uses **OpenZeppelin’s upgradeable contracts**.

- **Proxy Type:** UUPS or TransparentUpgradeableProxy  
- **Base Contracts:** `Initializable`, `OwnableUpgradeable`, `UUPSUpgradeable`
- **Storage Management:** Maintain a consistent variable order across upgrades.
- **Upgrade Flow:**
  1. Deploy new implementation contract.
  2. Call `upgradeTo()` through the proxy admin.
  3. Initialize any new state variables in an upgrade-safe initializer.

---

## 🧪 Testing Guidelines




## 👩🏽‍💻 Developer A – Contract Architecture & Core Logic Lead

### 1. 🏗️ Architecture Design
- Define the **overall architecture** of the DApp, including Factory and Proxy patterns.  
- Decide between **UUPSUpgradeable** or **TransparentUpgradeableProxy** (OpenZeppelin-based).  
- Document the **upgrade flow** and `initialize()` function patterns for all modules.

---

### 2. 🏭 EventFactory Contract
Responsible for deploying and managing event contracts.

**Key Responsibilities:**
- Deploy new event contracts via the **proxy pattern**.  
- Map **event owners** to their deployed event addresses.  
- Emit `EventCreated` events with details (owner, target funding, timestamps, etc.).  
- Handle **access control** to restrict who can deploy events.  
- Integrate the `initialize()` call post-deployment for each proxy.

---

### 3. 🎫 EventImplementation Contract (Core Logic)
Manages the main event and sponsorship lifecycle.

**Features:**
- Event parameters: `owner`, `fundingGoal`, `currentBalance`, `isFreeEvent`, `isActive`.  
- `deposit()` function for sponsor contributions.  
- Automatically blocks deposits once the funding goal is met.  
- Ticket sale logic with **revenue recording**.  
- `endEvent()` function triggers **revenue distribution**.  
- Visibility functions: `getBalance()` and `getSponsors()` for transparency.

---

### 4. 💰 SponsorVault Sub-Module
Handles internal accounting and revenue distribution.

**Responsibilities:**
- Mapping of `sponsorAddress → depositAmount`.  
- Revenue sharing at event completion:
  - Calculate % share per sponsor.  
  - Transfer revenue accordingly.  
- Support for both **paid** and **free** events.  
- Use **Pull Payment** or automated disbursement pattern for safety.

---

### 5. ⚙️ Proxy Integration
Ensures upgradeability and maintainability of contracts.

**Tasks:**
- Implement upgradeable pattern with `initialize()` and version tracking.  
- Inherit from:
  - `Initializable`  
  - `OwnableUpgradeable`  
  - `UUPSUpgradeable` or similar  
- Deploy via the upgradeable factory pattern.  
- Test **upgrading process** for state consistency.

---

### 6. 🧪 Testing & Quality Assurance
Comprehensive test coverage using Foundry or Hardhat.

**Test Scenarios:**
- Event creation and initialization flow.  
- Sponsor deposits and funding goal enforcement.  
- Event completion and sponsor payouts.  
- Proxy upgrades (ensuring **storage layout consistency**).  



